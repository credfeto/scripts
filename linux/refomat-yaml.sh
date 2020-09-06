#! /bin/sh

find ./ -iname *.yml -type f -exec bash -c expand -t 4 "$0" | sed -e "s/ \{1,\}$//" | sponge "$0" {} ;
