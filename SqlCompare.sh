#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s OLD.sql NEW.sql [MODE]\n' "${0##*/}"
    printf '%s\n' \
        'Normalize and compare MySQL CREATE TABLE dumps without changing inputs.' \
        'Modes: 1 = icdiff, 2 = Meld, 3 = diff (default), 4 = side-by-side diff.' \
        'Exit codes: 0 = equal, 1 = different, 2 = invalid input or command failure.'
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 2
}

if [[ $# == 1 && ( $1 == -h || $1 == --help ) ]]; then
    usage
    exit 0
fi
if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage >&2
    exit 2
fi
mode=${3:-3}
case "$mode" in
    1|2|3|4) ;;
    *) die 'Mode must be 1, 2, 3 or 4' ;;
esac

# Absolute paths prevent leading dashes and awk name=value operands from
# being interpreted as options or assignments instead of input filenames.
old_file=$1
new_file=$2
[[ $old_file == /* ]] || old_file="$PWD/$old_file"
[[ $new_file == /* ]] || new_file="$PWD/$new_file"
for input in "$old_file" "$new_file"; do
    [[ -f $input && -r $input ]] || die "Input must be a readable file: $input"
done
for tool in awk cmp diff mktemp; do
    command -v "$tool" >/dev/null 2>&1 || die "Required command not found: $tool"
done
if [[ $mode == 1 ]]; then
    command -v icdiff >/dev/null 2>&1 || die 'Mode 1 requires icdiff'
elif [[ $mode == 2 ]]; then
    if command -v meld >/dev/null 2>&1; then
        meld_command=meld
    else
        meld_command='/c/Program Files (x86)/Meld/Meld.exe'
        [[ -x $meld_command ]] || die 'Mode 2 requires meld on PATH or the Windows Meld installation'
    fi
fi

umask 077
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/mysql-schema-diff.XXXXXXXX") || die 'Cannot create temporary directory'
trap 'rm -rf -- "$temporary_directory"' EXIT
trap 'exit 2' HUP INT TERM
normalized_old="$temporary_directory/old.sql"
normalized_new="$temporary_directory/new.sql"

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
clean_dump "$old_file" >"$normalized_old" || die 'Cannot normalize old dump'
clean_dump "$new_file" >"$normalized_new" || die 'Cannot normalize new dump'

if cmp -s "$normalized_old" "$normalized_new"; then
    printf '\n\tsame (clean) content, nothing to show\n'
    exit 0
else
    status=$?
    [[ $status == 1 ]] || die 'Cannot compare normalized dumps'
fi

case "$mode" in
    1)
        if icdiff --cols=160 -W "$normalized_old" "$normalized_new"; then
            status=0
        else
            status=$?
        fi
        [[ $status -le 1 ]] || die 'icdiff failed'
        ;;
    2)
        # Wait for the GUI to close before removing its input files.
        "$meld_command" "$normalized_old" "$normalized_new" || die 'Meld failed'
        ;;
    3|4)
        diff_options=(-a)
        if diff --color=never /dev/null /dev/null >/dev/null 2>&1; then
            diff_options+=(--color=always)
        fi
        [[ $mode != 4 ]] || diff_options+=(-y)
        if diff "${diff_options[@]}" "$normalized_old" "$normalized_new"; then
            status=0
        else
            status=$?
        fi
        [[ $status -le 1 ]] || die 'diff failed'
        ;;
esac
exit 1
