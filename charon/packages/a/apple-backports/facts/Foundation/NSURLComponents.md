# NSURLComponents, the API of iOS 11.0

Introduced in iOS 11.0: `percentEncodedQueryItems`, the query items without the
decoding `queryItems` does.

Source: Foundation of the arm64 shared cache of iOS 11.0, where `NSURLComponents`
itself is abstract and the work sits in `__NSConcreteURLComponents`
(`-percentEncodedQueryItems` at `0x1815af674`,
`-setPercentEncodedQueryItems:` at `0x1815af830`), which hands the query to
CoreFoundation; the observable behaviour from the differential test against the
host's Foundation (`tests/backports/host/foundation11`).

## Reading

Built from `percentEncodedQuery` without touching the escapes:

| query | items |
|---|---|
| no query at all | `nil` |
| `?` (an empty query) | an empty array |
| `?a=1` | `a` = `1` |
| `?a` | `a` with a `nil` value |
| `?a=` | `a` with an empty value |
| `?=v` | an empty name with `v` |
| `?a=1&&b=2` | `a` = `1`, an empty name with `nil`, `b` = `2` |
| `?a=b=c` | `a` = `b=c`: only the first `=` splits |
| `?a=%E2%82%AC` | `a` = `%E2%82%AC`, still escaped |
| `?a=1&a=2` | both, in order |
| `?a+b=c+d` | `a+b` = `c+d`: a plus is not a space here |

## Writing

The items are joined with `&`, each as `name=value`, or as the bare name when
the value is `nil`; the result goes to `percentEncodedQuery`. An empty array
leaves an empty query, and `nil` removes the query altogether.

Apple checks the joined query for characters that do not belong in one and
raises `NSInvalidArgumentException` with
`invalid characters in percentEncodedQueryItems`. The port leaves that check to
`-setPercentEncodedQuery:` of the `NSURLComponents` backport, which raises the
same exception naming `percentEncodedQuery` instead of
`percentEncodedQueryItems`. The refusal happens either way; only the word in the
message differs.
