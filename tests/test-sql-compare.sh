#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

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

output="$(cd "$temporary_directory" && bash "$repo_root/SqlCompare.sh" old.sql new.sql)"
[[ "$output" == *"same (clean) content, nothing to show"* ]]
cmp "$temporary_directory/clean_old.sql" "$temporary_directory/clean_new.sql"
