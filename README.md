# MySQL Schema Diff

Normalize and compare two MySQL `CREATE TABLE` dumps from the command line.

## Requirements

- Bash
- `diff` (or optionally `icdiff` / Meld for the corresponding output modes)

## Usage

```sh
git clone https://github.com/alsd4git/mysql-schema-diff.git
cd mysql-schema-diff
chmod +x SqlCompare.sh
./SqlCompare.sh old_db.sql new_db.sql 1
```

Run `./SqlCompare.sh -h` for the supported comparison modes. The script was
originally written with Git Bash on Windows and should also work with a regular
Bash environment.

## License

MIT. See [LICENSE](LICENSE).
