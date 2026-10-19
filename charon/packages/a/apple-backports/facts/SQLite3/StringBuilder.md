# sqlite3_str builder (iOS 12.0)

Eleven functions of the sqlite3 string builder, in `SQLite3/StringBuilder.c` of `libSQLite3Backports.dylib`
(`SQLite3Backports` in `modules/apple/backports.lua`, linked against the system's `libsqlite3`).
Declared by the 26.2 SDK's `sqlite3.h`, availability `ios=12.0` (`spec/SQLite3/declarations.tsv`).

## Arrival

The functions are absent from the 6.1.3 libsqlite3 (`.agent-work/runs/v-impl-darwin/sqlite-613.txt`: NOT EXPORTED)
and from the 11.0 arm64 libsqlite3 (`arm64/sqlite-11.0.txt`: none of the 14 names). The 12.0 arm64 libsqlite3 exports
all fourteen (`arm64/sqlite-12.0.txt`). The registry rows say 12.0.

The four functions the port calls into the system's libsqlite3 are exported by 6.1.3 (`sqlite3_malloc`,
`sqlite3_realloc`, `sqlite3_free`, `sqlite3_vmprintf`, `sqlite3_limit`): the port needs nothing newer.

## What the port does

The struct behind the opaque `sqlite3_str` holds the database, the buffer, its allocated capacity, the length limit,
the length, and the error. With no database the limit is sqlite's compile-time default, 1000000000; with one it is
`sqlite3_limit(db, SQLITE_LIMIT_LENGTH, -1)`.

`sqlite3_str_vappendf` formats with `sqlite3_vmprintf`, so the formats are sqlite's printf dialect (`%q`, `%Q`, `%w`).

## The limit, measured

The host's libsqlite3 (3.54.0) is the oracle. `sqlite3_limit` clamps a length limit to at least 30 bytes, so the
smallest limit a database can carry is 30. Under that limit, measured with `probe-boundary.c` (scratch):

- 30 bytes appended to an empty builder: TOOBIG, the text is dropped (length 0, `finish` NULL).
- 29 bytes: kept. 29 then 1: kept, length 30. 31 single bytes: all kept, length 31, no error.
- 25 then 10: TOOBIG on the 10. 20 then 10: kept, length 30. 5 times 6: kept, length 30.

The boundary is not a length threshold: the 1-byte run keeps 31 bytes under a 30-byte limit. The sqlite source is
not on this machine, so the rule below is inferred from those measurements, not read from it. It is the rule the
measurements fit, and the differential holds the port to the sequences above:

- the capacity of the buffer is the usable size the allocator reports for it (`malloc_size`), not the size asked for;
- an append fits while `length + n + 1` is within that capacity;
- only when the buffer must grow is the new size compared with the limit, and TOOBIG is set when that size,
  `length + n + 1`, is past the limit.

The port does the same:

- `reserve()` checks `needed = length + extra + 1` against `allocated`, which is `malloc_size` of the buffer
  after the last `sqlite3_realloc`. It fits when `needed <= allocated`.
- Otherwise it grows: TOOBIG when `needed > limit`, else `sqlite3_realloc` to `needed`, plus `length` again when
  that stays within the limit. The growth size is not measured on its own: it matters only through the capacity
  it leaves, and the sequences above are the check.

`malloc_size` is declared in the iPhoneOS 16.4 SDK's `malloc/malloc.h` with no availability guard, so it is on
every iOS release this port runs on. The rounding is the allocator's, so the boundary depends on it: the host and the
port on the same allocator agree, and that is what the differential checks.

## Errors and NULL

- An error (TOOBIG or NOMEM) is sticky: later appends do nothing, the length stays 0, the text is gone.
- `sqlite3_str_finish` returns NULL on an error and frees the builder; `sqlite3_str_errcode(NULL)` is SQLITE_NOMEM,
  `sqlite3_str_length(NULL)` is 0, `sqlite3_str_value(NULL)` is NULL.
- `sqlite3_str_append` with a negative length, and `sqlite3_str_appendchar` with a count of 0 or less, append nothing.

## The test

`tests/backports/host/sqlite3/run.sh` links `StringBuilder.c` with each name renamed to `charon_port_*`, and
`differential-str.c` calls the host's builder and the port's with the same steps, comparing length, error, text and
the finished string after every step. Scenarios: the empty builder, appends, formats, reset, the limit (TOOBIG and
the calls after it), just under the limit, the boundary sequences above, and NULL. The control adds one to the port's
length, and the run fails unless the control is caught.
