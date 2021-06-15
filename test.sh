#! /bin/sh

git diff -s --exit-code
if [ $? -ne 0 ] ; then
   echo Has Changes
fi

