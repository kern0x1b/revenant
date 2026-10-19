# sqlite3 keyword functions (iOS 12.0)

Three functions, in `SQLite3/Keywords.c` of `libSQLite3Backports.dylib`: `sqlite3_keyword_count`, `sqlite3_keyword_name`
and `sqlite3_keyword_check`. Declared by the 26.2 SDK's `sqlite3.h`, availability `ios=12.0`
(`spec/SQLite3/declarations.tsv`).

## Arrival

Absent from the 6.1.3 libsqlite3 (`sqlite-613.txt`: NOT EXPORTED) and from the 11.0 arm64 libsqlite3; present in the
12.0 arm64 libsqlite3 (`arm64/sqlite-12.0.txt`). The registry rows say 12.0.

## The table

The table is the 147 names the host's sqlite3 (3.54.0) answers from `sqlite3_keyword_name`, in its order. The order is
the API: `sqlite3_keyword_name(i)` answers the i-th name. The table is generated from the host's dump, not typed:

    awk 'NR>=3 && $1 == 0 { print "    \"" $3 "\"," }' keywords-host.txt

where `keywords-host.txt` is the output of `tests/backports/host/sqlite3/dump-keywords.c` on the host. The dump has 147
rows, every one with return code 0, and the names include the three underscore names (CURRENT_DATE, CURRENT_TIME,
CURRENT_TIMESTAMP).

**Not measured:** the keyword list of the 12.0 release's own libsqlite3. The 12.0 arm64 dump lists symbols only, and no
held cache was dumped for its keyword table. The table here is sqlite 3.54.0's. If the release's list differs, the
registry row and this file must say so; they do not yet, because nothing measured it.

## Behaviour, measured against the host

- `sqlite3_keyword_count()` is 147.
- `sqlite3_keyword_name(i, &z, &n)` for 0 <= i < 147 returns SQLITE_OK and sets `z` and `n`. The host's names are
  not NUL-terminated (they are slices of one table), so a caller must use `n`; the port's are NUL-terminated and
  agree with `n`.
- Out of range (i < 0 or i >= 147, including -2 and 1000) returns 1 (SQLITE_ERROR), sets `z` to NULL, and leaves `n`
  as it was.
- `sqlite3_keyword_check(z, n)` takes `n` as the exact byte length of `z`. It returns 1 when those `n` bytes are a
  keyword, compared with ASCII letters folded (sqlite folds ASCII only), and 0 otherwise. A negative `n` returns 0
  (measured: `n = -1` on "SELECT" is 0), and so does `n = 0`.

## The test

`tests/backports/host/sqlite3/run.sh` builds `Keywords.c` with each name renamed to `charon_port_*` and
`differential-keywords.c` calls both. It checks the count, every index from -2 to 148 (the return code, the name and
its length, and that a failure leaves `n` alone and sets `z` NULL), and `sqlite3_keyword_check` on every keyword in
upper, lower and mixed case, with the exact length, a short and a long length, a zero length, a changed last letter,
a keyword with a letter added, and a list of non-keywords with the lengths -1, 0 and 1. The control changes the
port's count by one, and the run fails unless the control is caught.
