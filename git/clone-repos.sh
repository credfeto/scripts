#! /bin/bash

while read line; do


  echo $line;
  git clone $line;

done < "$1"
