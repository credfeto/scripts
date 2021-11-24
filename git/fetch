#! /bin/bash

for d in */; do

  CURRENTDIR=${d::-1}
  echo ""
  echo "Retrieving $CURRENTDIR..."
  git -C "$CURRENTDIR" remote get-url origin
  git -C "$CURRENTDIR" fetch 
  git -C "$CURRENTDIR" remote update origin --prune
  
  git -C "$CURRENTDIR" status
  if [ $? -eq 0 ]
  then
    echo " + No pending changes in working folder. Rebasing..."
    git -C "$CURRENTDIR" rebase
    git -C "$CURRENTDIR" rebase --abort 2> /dev/null
  fi 

  echo " * done"
done