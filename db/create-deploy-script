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

#SET SOURCE=D:\Work\funfair-ethereum-proxy-server\db
#SET FILTER=%SOURCE%\Filter.scpf
#SET SERVER2=localhost
#SET SERVER2DB=MTRTest
#SET OUTPUT=D:\DB.sql
#SET REPORT=D:\DB.xml
#SET LOG=D:\DB.log

SOURCE=
#SERVER=
#DATABASE=
OUTPUT=
REPORT=
LOG=

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -f|--files)
      SOURCE="$2"
      shift # past argument
      shift # past value
      ;;
#    -s|--server)
#      SERVER="$2"
#      shift # past argument
#      shift # past value
#      ;;
#    -d|--database)
#      DATABASE="$2"
#      shift # past argument
#      shift # past value
#      ;;
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

[ -z "$SOURCE" ] && die "--files not specified"
[ -z "$OUTPUT" ] && die "--output not specified"

FILTER=$SOURCE/Filter.scpf
LOG=$OUTPUT.log
REPORT=$OUTPUT.xml

~/sqlcompare \
  /filter:"$FILTER" \
  /options:ConsiderNextFilegroupInPartitionSchemes,DecryptPost2kEncryptedObjects,DoNotOutputCommentHeader,ForceColumnOrder,IgnoreCertificatesAndCryptoKeys,IgnoreDatabaseAndServerName,IgnoreUserProperties,IgnoreUsersPermissionsAndRoleMemberships,IgnoreWhiteSpace,IgnoreWithElementOrder,IncludeDependencies,NoDeploymentLogging,ThrowOnFileParseFailed,UseCompatibilityLevel \
  /transactionIsolationLevel:SERIALIZABLE \
  /include:staticData \
  /scriptFile:"$OUTPUT" \
  /showWarnings \
  /include:Identical \
  /report:"$REPORT" \
  /reportType:Xml \
  /force \
  /OutputWidth:1024 \
  /scripts1:"$SOURCE" \
  /out:"$LOG" \
  /empty2 \
  /assertidentical

#  /Synchronise
#  /server2:$SERVER \
#  /database2:$DATABASE \