#!/usr/bin/env bash
set -euo pipefail

#thanks to https://www.shellcheck.net/ for spell checking

usage="
$(basename "$0") [-h] [oldFile newFile diffType] -- program to clean and compare two SQL create table

where:
	-h  show this help text
	oldFile: name of the old SQL create table
	newFile: name of the new SQL create table
	diffType: value between 1 and 4 where:
		1) use icdiff (python) if installed, can get with 'pip install git+https://github.com/jeffkaufman/icdiff.git'
		2) use meld (windows) if used with git bash, you need windows version of meld installed in x86 program folder
		3) use standard diff with default coloring
		4) use standard diff with some grep colors
"

if [ "$1" = "-h" ]; then
  echo "$usage"
  exit 0
fi

if [ -z "$1" ]; then
    echo "Warn: missing old file name, will use 'old_DB.sql'"
	#$1='old_DB.sql'
	#to edit passed value you need to set them all
	set -- 'old_DB.sql' "${@:2:3}"
fi

if [ -z "$2" ]; then
    echo "Warn: missing new file name, will use 'new_DB.sql'"
	#$2='new_DB.sql'
	#to edit passed value you need to set them all
	set -- "${@:1}" 'new_DB.sql' "${@:3}"
fi

if [ ! -f "$1" ]; then
    echo "File $1 not found! use \"$(basename "$0") -h\" for script usage"
	exit 1
fi

if [ ! -f "$2" ]; then
    echo "File $2 not found! use \"$(basename "$0") -h\" for script usage"
	exit 1
fi

# Clean SQL dumps with POSIX awk so the same normalization works with GNU and
# BSD userlands.
clean_dump() {
    awk '
        !/^\/\*/ && NF && !/^-- / && !/^  CONSTRAINT/ {
            if (/ENGINE=/) {
                print ");"
                next
            }
            sub(/ COMMENT.*$/, "")
            if (NF) print
        }
    ' "$1"
}

clean_dump "$1" >"clean_$1"
clean_dump "$2" >"clean_$2"


if  ! cmp -s clean_"$1" clean_"$2" ; then
	#files are different
	case $3 in
		1)
			echo '1 - will use icdiff (python)'
			icdiff clean_"$1" clean_"$2" --cols=160 -W
			;;
		2)
			echo '2 - will use meld (windows)'
			'C:\Program Files (x86)\Meld\meld.exe' clean_"$1" clean_"$2" &
			;;
		3)
			echo '3 - will use basic diff'
			diff clean_"$1" clean_"$2" --color=always
			;;
		4)
			echo '4 - will use diff with colored grep'
			diff -y clean_"$1" clean_"$2" | GREP_COLOR='01;32' grep -E --color=always '.*>.*|$' | GREP_COLOR='01;31' grep -E --color=always '.*<.*|$' | GREP_COLOR='01;36' grep -E --color=always '.*\|.*|$' | less -R
			;;
		*)
			echo 'no option/invalid option provided will use diff with colored grep'
			diff -y clean_"$1" clean_"$2" | GREP_COLOR='01;32' grep -E --color=always '.*>.*|$' | GREP_COLOR='01;31' grep -E --color=always '.*<.*|$' | GREP_COLOR='01;36' grep -E --color=always '.*\|.*|$' | less -R
			;;
	esac
else
	printf '\n\tsame (clean) content, nothing to show\n'
fi
