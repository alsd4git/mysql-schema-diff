# MySQL Schema Diff

[![CI](https://github.com/alsd4git/mysql-schema-diff/actions/workflows/ci.yml/badge.svg)](https://github.com/alsd4git/mysql-schema-diff/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

Normalize and compare two MySQL `CREATE TABLE` dumps from the command line.

The script removes dump comments, blank lines, table constraints, and selected
storage-engine details before sending the normalized files to `diff`, `icdiff`,
or Meld. It does not connect to MySQL or modify the input files.

## Requirements

- Bash
- `awk`, `sed`, and `diff`
- optional: `icdiff` or Meld for the corresponding output mode

The script works in a regular Linux or macOS Bash environment and in Git Bash
on Windows.

## Usage

```bash
git clone https://github.com/alsd4git/mysql-schema-diff.git
cd mysql-schema-diff
./SqlCompare.sh old-schema.sql new-schema.sql MODE
```

`MODE` selects the comparison program. Run `./SqlCompare.sh -h` for the current
command syntax.

| Mode | Output |
| --- | --- |
| `1` | colored terminal output through `icdiff` |
| `2` | Windows Meld installed under `Program Files (x86)` |
| `3` | standard `diff` with color |
| `4` | side-by-side `diff` filtered through colored `grep` |

## Example

```bash
mysqldump --no-data app_before > before.sql
mysqldump --no-data app_after > after.sql
./SqlCompare.sh before.sql after.sql 1
```

The command writes `clean_before.sql` and `clean_after.sql` beside the inputs.
Review and remove those generated files after the comparison. Normalization does
not prove that a migration is safe or reversible.

## Development

```bash
shellcheck SqlCompare.sh tests/test-sql-compare.sh
./tests/test-sql-compare.sh
```

GitHub Actions runs the smoke tests on Linux and macOS.

## License

MIT. See [LICENSE](LICENSE).
