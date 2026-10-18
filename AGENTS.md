# Project instructions

- Use synthetic schema dumps. Do not connect to production databases or execute generated DDL merely for validation.
- Follow the repository's documented setup and pinned tooling. Validate code changes with:

```sh
bash -n SqlCompare.sh tests/test-sql-compare.sh
shellcheck SqlCompare.sh tests/test-sql-compare.sh
bash tests/test-sql-compare.sh
```
