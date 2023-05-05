#! /bin/sh

find . -type f -iname '*.cs' -print0 | xargs -I {} -0 grep --no-filename '// ReSharper disable once ' "{}" | sed -e 's/^\s*//' -e '/^$/d' | sort -b | uniq > suppressions.txt
