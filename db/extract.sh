#!/bin/bash

PROG=$0

function error_exit {
    echo
    echo "$@"
    exit 1
}
#Trap the killer signals so that we can exit with a good message.
trap "error_exit 'Received signal SIGHUP'" SIGHUP
trap "error_exit 'Received signal SIGINT'" SIGINT
trap "error_exit 'Received signal SIGTERM'" SIGTERM

shopt -s expand_aliases
alias die='error_exit "Error $PROG (@`echo $(( $LINENO - 1 ))`):"'

SERVER=
DB=
AUTH=

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -U|--user)
      USER="$2"
      shift # past argument
      shift # past value
      ;;
    -P|--password)
      PASSWORD="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--server)
      SERVER="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--database)
      DB="$2"
      shift # past argument
      shift # past value
      ;;
    -o|--output)
      OUTPUT="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      die "unknown argument $1"
      ;;
  esac
done

[ -z "$SERVER" ] && die "--server not specified"
[ -z "$DB" ] && die "--database not specified"
[ -z "$USER" ] && die "--user not specified"
[ -z "$PASSWORD" ] && die "--password not specified"
[ -z "$OUTPUT" ] && die "--output not specified"

FILTER=$OUTPUT/Filter.scpf

DBXML=$TMP/db.xml
HOOKSXML=$TMP/hooks.xml

echo "<?xml version=\"1.0\" encoding=\"utf-16\" standalone=\"yes\"?>" > $HOOKSXML
echo "<HooksConfig version=\"1\" type=\"HooksConfig\">" >> $HOOKSXML
echo " <Name>Working Folder<^/Name>" >> $HOOKSXML
echo " <Commands type=\"Commands\" version=\"2\">" >> $HOOKSXML
echo "   <element>" >> $HOOKSXML
echo "     <key type=\"string\">GetLatest</key>" >> $HOOKSXML
echo "     <value version=\"1\" type=\"GenericHookCommand\">" >> $HOOKSXML
echo "       <CommandLine></CommandLine>" >> $HOOKSXML
echo "       <Verify>exitCode == 0</Verify>" >> $HOOKSXML
echo "     </value>" >> $HOOKSXML
echo "   </element>" >> $HOOKSXML
echo "   <element>" >> $HOOKSXML
echo "     <key type=\"string\">Add</key>" >> $HOOKSXML
echo "     <value version=\"1\" type=\"GenericHookCommand\">" >> $HOOKSXML
echo "       <CommandLine></CommandLine>" >> $HOOKSXML
echo "       <Verify>exitCode == 0</Verify>" >> $HOOKSXML
echo "     </value>" >> $HOOKSXML
echo "   </element>" >> $HOOKSXML
echo "   <element>" >> $HOOKSXML
echo "     <^key type=\"string\">Edit<^/key>" >> $HOOKSXML
echo "     <^value version=\"1\" type=\"GenericHookCommand\">" >> $HOOKSXML
echo "       <CommandLine></CommandLine>" >> $HOOKSXML
echo "       <Verify>exitCode == 0</Verify>" >> $HOOKSXML
echo "     </value>" >> $HOOKSXML
echo "   </element>" >> $HOOKSXML
echo "   <element>" >> $HOOKSXML
echo "     <key type=\"string\">Delete</key>" >> $HOOKSXML
echo "     <value version=\"1\" type=\"GenericHookCommand\">" >> $HOOKSXML
echo "       <CommandLine></CommandLine>" >> $HOOKSXML
echo "       <Verify>exitCode == 0</Verify>" >> $HOOKSXML
echo "     </value>" >> $HOOKSXML
echo "   </element>" >> $HOOKSXML
echo "   <element>" >> $HOOKSXML
echo "     <key type=\"string\">Commit</key>" >> $HOOKSXML
echo "     <value version=\"1\" type=\"GenericHookCommand\">" >> $HOOKSXML
echo "       <CommandLine></CommandLine>" >> $HOOKSXML
echo "       <Verify>exitCode == 0</Verify>" >> $HOOKSXML
echo "     </value>" >> $HOOKSXML
echo "   </element>" >> $HOOKSXML
echo "   <element>" >> $HOOKSXML
echo "     <key type=\"string\">Revert</key>" >> $HOOKSXML
echo "     <value version=\"1\" type=\"GenericHookCommand\">" >> $HOOKSXML
echo "       <CommandLine></CommandLine>" >> $HOOKSXML
echo "       <Verify>exitCode == 0</Verify>" >> $HOOKSXML
echo "     </value>" >> $HOOKSXML
echo "   </element>" >> $HOOKSXML
echo " </Commands>" >> $HOOKSXML
echo "</HooksConfig>" >> $HOOKSXML


echo "<?xml version=\"1.0\" encoding=\"utf-16\" standalone=\"yes\"?>" > $DBXML
echo "<!-- -->" >> $DBXML
echo "<ISOCCompareLocation version=\"2\" type=\"WorkingFolderGenericLocation\" >" >> $DBXML
echo "  <LocalRepositoryFolder>%SOURCE%</LocalRepositoryFolder>" >> $DBXML
echo "  <HooksConfigFile>$HOOKSXML</HooksConfigFile>" >> $DBXML
echo "  <HooksFileInRepositoryFolder>False</HooksFileInRepositoryFolder>" >> $DBXML
echo "</ISOCCompareLocation>" >> $DBXML

~/sqlcompare /filter:"$FILTER" \
  /options:ConsiderNextFilegroupInPartitionSchemes,DecryptPost2kEncryptedObjects,DoNotOutputCommentHeader,ForceColumnOrder,IgnoreCertificatesAndCryptoKeys,IgnoreDatabaseAndServerName,IgnoreUserProperties,IgnoreUsersPermissionsAndRoleMemberships,IgnoreWhiteSpace,IgnoreWithElementOrder,IncludeDependencies,NoDeploymentLogging,ThrowOnFileParseFailed,UseCompatibilityLevel \
  /transactionIsolationLevel:SERIALIZABLE \
  /makescripts:"$OUTPUT" \
  /force \
  /OutputWidth:1024 \
  /server1:"$SERVER" \
  /database1:"$DB" \
  /username1:"$USER" \
  /password1:"$PASSWORD"
#  /sourcecontrol2 \
#  /revision2:latest \
#  /sfx:"$DBXML"
  
  # /out:"$LOG" \
  