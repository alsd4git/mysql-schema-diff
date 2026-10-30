#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
mkdir "$temporary_directory/temp" "$temporary_directory/paths with spaces" "$temporary_directory/bin"
export TMPDIR="$temporary_directory/temp"

run_status() {
    expected=$1
    shift
    status=0
    bash "$repo_root/SqlCompare.sh" "$@" >"$temporary_directory/stdout" 2>"$temporary_directory/stderr" || status=$?
    if [[ $status != "$expected" ]]; then
        printf 'Expected status %s, got %s\n' "$expected" "$status" >&2
        cat "$temporary_directory/stderr" >&2
        exit 1
    fi
    [[ -z $(ls -A "$TMPDIR") ]] || { printf 'Temporary files leaked\n' >&2; exit 1; }
}

cat >"$temporary_directory/old.sql" <<'SQL'
CREATE TABLE `example` (
  `id` int NOT NULL,
  `label` varchar(32) COMMENT 'legacy label'
) ENGINE=InnoDB;
SQL

cat >"$temporary_directory/new.sql" <<'SQL'
CREATE TABLE `example` (
  `id` int NOT NULL,
  `label` varchar(32) COMMENT 'current label'
) ENGINE=InnoDB;
SQL

old="$temporary_directory/paths with spaces/-old=one.sql"
new="$temporary_directory/paths with spaces/new.sql"
cp "$temporary_directory/old.sql" "$old"
cp "$temporary_directory/new.sql" "$new"
run_status 0 -h
run_status 0 --help
run_status 2
run_status 2 "$old"
run_status 2 "$old" "$new" 9
run_status 2 "$old" "$new" 3 extra
run_status 2 "$old" "$temporary_directory/missing.sql"
run_status 0 "$old" "$new"
grep -q 'same (clean) content' "$temporary_directory/stdout"
cmp "$temporary_directory/old.sql" "$old"
cmp "$temporary_directory/new.sql" "$new"
[[ ! -e "$temporary_directory/clean_old.sql" ]]
[[ ! -e "$temporary_directory/paths with spaces/clean_-old=one.sql" ]]

# A real structural difference, with input paths that are safe awk operands.
printf '\nCREATE TABLE second_table (id int);\n' >>"$new"
run_status 1 "$old" "$new"
grep -q second_table "$temporary_directory/stdout"
run_status 1 "$old" "$new" 4
grep -q second_table "$temporary_directory/stdout"
(
    cd "$temporary_directory/paths with spaces"
    run_status 1 -old=one.sql new.sql 3
)

# Optional tools are isolated stubs; never open a real GUI in regression tests.
printf '#!/usr/bin/env bash\nexit 0\n' >"$temporary_directory/bin/icdiff"
# shellcheck disable=SC2016 # The generated stub expands its own arguments.
printf '#!/usr/bin/env bash\n[[ -f $1 && -f $2 ]]\n' >"$temporary_directory/bin/meld"
chmod +x "$temporary_directory/bin/icdiff" "$temporary_directory/bin/meld"
export PATH="$temporary_directory/bin:$PATH"
run_status 1 "$old" "$new" 1
run_status 1 "$old" "$new" 2
printf '#!/usr/bin/env bash\nexit 7\n' >"$temporary_directory/bin/icdiff"
run_status 2 "$old" "$new" 1
printf '#!/usr/bin/env bash\nexit 7\n' >"$temporary_directory/bin/meld"
run_status 2 "$old" "$new" 2
printf '#!/usr/bin/env bash\nexit 7\n' >"$temporary_directory/bin/diff"
chmod +x "$temporary_directory/bin/diff"
run_status 2 "$old" "$new" 3
printf '#!/usr/bin/env bash\nexit 7\n' >"$temporary_directory/bin/awk"
chmod +x "$temporary_directory/bin/awk"
run_status 2 "$old" "$new" 3
printf 'All CLI regression tests passed.\n'
