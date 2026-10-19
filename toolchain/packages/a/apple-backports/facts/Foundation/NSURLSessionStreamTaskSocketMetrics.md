# What it takes to close the eight, measured against the release

The eight rows that stay `absent` are the socket's and the TLS session's: the two header byte counts,
the two addresses, the two ports, the two negotiated TLS values. This is the work that closes six of
them, measured so that nothing here has to be re-derived.

## Every entry point is the release's own, and all eight of them are there

Measured with `tools/corpus/cache-value.lua` over the 6.1.3 armv7 cache
(`.agent-work/scope/tls-symbols.txt`):

| symbol | the image of 6.1.3 that exports it |
| --- | --- |
| `kCFStreamPropertySocketNativeHandle` | CoreFoundation |
| `kCFStreamPropertySSLContext` | CFNetwork |
| `SSLGetNegotiatedProtocolVersion` | Security |
| `SSLGetNegotiatedCipher` | Security |
| `SSLCreateContext`, `SSLSetIOFuncs`, `SSLHandshake` | Security |

So there is no wall on either half: the handle is a property of the release's own stream, and the
negotiated version and cipher are read out of the release's own TLS session through public
SecureTransport. The same measurement is what made the stream task itself possible
(`facts/Foundation/NSURLSessionStreamTask.md`).

## The work, in the order that can be verified cheapest first

1. **The socket half, four rows, no certificate needed.** In `NSURLSessionStreamTask9.m`, once
   `-[NSURLSessionStreamTask charon_open]` has opened the pair, read
   `kCFStreamPropertySocketNativeHandle` off the *input* stream (`CFReadStreamCopyProperty` /
   `kCFStreamGetProperty`) and call `getsockname` and `getpeername` on the descriptor. Four rows
   become answerable and the test is cheap: a plain TCP listener the test opens, one stream task to it,
   and the port's answers against the host's own stream task's for the same connection.
2. **The delivery, which is the part that is real work.** Those numbers reach an application through
   `-[NSURLSessionTaskDelegate URLSession:task:didFinishCollectingMetrics:]`, and a stream task runs no
   loader, so nothing would call that method for it. The port's session already has the call site for
   a data task; a stream task needs the session to build an `NSURLSessionTaskMetrics` with **one**
   transaction when the task finishes -- both halves closed, or the task cancelled or invalidated -- and
   hand it to the delegate on the delegate queue, the way a data task's metrics arrive.
3. **The TLS half, two rows, needs a certificate in the test.** `-startSecureConnection` is what makes
   the release's stream carry an `SSLContext`; the two values are then `SSLGetNegotiatedProtocolVersion`
   and `SSLGetNegotiatedCipher` on it. A host test for this needs a TLS listener the test owns, which
   means a certificate, and a comparison against the host's own stream task over the same TLS
   connection.
4. **The two header byte counts stay `absent`, and the reason is the true one.** A stream task is a raw
   TCP connection: it sends no request and receives no response, so there is no HTTP header to count and
   the honest answer is 0 for a stream. The wall is not the socket -- it is that the *data* task's
   transaction is the release's connection, whose header bytes reach the release's parser and stop there.
   Those two rows are therefore a different row each from the six above, and they stay as they are.

## 5. The two header byte counts: what the release's own CFNetwork does with them, measured

Section 4 above says the two rows stay `absent` and that the wall is the data task's connection. The
row's own `source` used to add that "there is no dyld_shared_cache here to read a 10.x inventory
from" - **which was wrong, and this is the measurement that replaces it.** The ladder has the whole
10.x and 11.x range, so "does the release's own class answer this getter between 10.0 and 13.0" is
answerable here.

The reading is the cache index `tools/cache-index/build.lua` writes, one file per held rung: every
registered selector (`__TEXT,__objc_methname`), every class name (`__TEXT,__objc_classname`), every C
string literal (`__TEXT,__cstring`), the export trie and the whole symbol table. Every number below is
`tools/cache-index/first-rung.lua`'s own `_names_of()` over those files - names as **bytes**, the header
line skipped, a whitespace-only line not a name - so the name count is that reader's and the queries are
the same bytes it searches.

| held rung | arch | `NSURLSessionTaskTransactionMetrics` | `countOfRequestHeaderBytesSent` | `countOfResponseHeaderBytesReceived` | names in that rung's index |
| --- | --- | --- | --- | --- | --- |
| 8.0, 9.0, 9.3.6 and every older rung | armv7 | **no class** | - | - | 1,288,265 at 9.3.6 |
| 10.0.1, 10.1.1, 10.2, 10.2.1, 10.3, 10.3.1, 10.3.2, 10.3.3, 10.3.4 | armv7s | present | no | no | 1,486,384 at 10.0.1 |
| 11.0, 12.0 | arm64 | present | no | no | 1,964,780 at 11.0, 2,265,101 at 12.0 |
| 13.0 - 15.x | - | **no held rung** | - | - | - |
| 16.0 | arm64e | present | **yes** | **yes** | 5,104,177 |
| 18.0 | arm64e | present | **yes** | **yes** | 6,919,864 |

    $ xmake l tools/cache-index/first-rung.lua NSURLSessionTaskTransactionMetrics \
        countOfRequestHeaderBytesSent countOfResponseHeaderBytesReceived
    NSURLSessionTaskTransactionMetrics       10.0.1
    countOfRequestHeaderBytesSent            16.0
    countOfResponseHeaderBytesReceived       16.0

`first-rung.lua` answers "the oldest held rung carrying the name", which is what the class column above
rests on; the per-release answers come from the per-rung index files it reads, and one reader a reader can
run over any subset is:

    $ python3 -c 'import gzip,os,sys                       # first-rung.lua _names_of(), inlined
    p=os.path.expanduser("~/.charon/cache-index/"+sys.argv[1]+".names.gz")
    with gzip.open(p,"rb") as h:
        h.readline(); body={l.rstrip(b"\n") for l in h if l.strip()}
    for n in sys.argv[2:]:
        print(n, "PRESENT" if n.encode() in body else "absent")' 12.0 \
        countOfRequestHeaderBytesSent NSURLSessionTaskTransactionMetrics UIView
    # (the header line the reader skips names the release, arch, cache, mtime, size and name count)
    countOfRequestHeaderBytesSent absent
    NSURLSessionTaskTransactionMetrics PRESENT
    UIView PRESENT

**One hole in the index, so a reader is not sent into it.** `--rungs` cannot answer over the whole
ladder yet: 8.4 has no index file, so the query stops there with a `FileNotFoundError` on
`8.4.names.gz` (`xmake l tools/cache-index/build.lua --only 8.4` builds that one rung). Every rung this
table names has its file, so the table stands without it.

**What this reading does and does not decide.** It does not report any one class's own method list, so
it cannot say how many selectors `NSURLSessionTaskTransactionMetrics` carries - only which names the
release has at all. That is enough for these two rows, because a method in a cache must have its
selector name in that cache: either in `__TEXT,__objc_methname`, or as a `__cstring` literal it is
registered from. Neither name is anywhere in the held rungs 10.0.1 through 12.0, so the release's own
class cannot answer either getter there; both are present at 16.0 and 18.0, so it can there.

Note what a whole-cache count is not. `countOfRequestBodyBytesSent` is in the cache from 8.0, while
`NSURLSessionTaskTransactionMetrics` only appears at 10.0.1, so both of those facts are true at once and
neither says which class owns that name - a count over the whole cache is not a statement about one
class's method list. That is the trap a per-class reading exists to avoid, and it is why this section
claims what it claims and no more: which names the release has, not how many methods one class has.

Three things follow, and only the first two were known before:

1. **`maximum: 10.0` is right, and now for a measured reason.** From 10.0.1 the release's own class is
   the one in charge, and the port's implementation could not be reached even if it existed. The row
   leaves the bands there.
2. **The release does not have the getter in any release the ladder holds between 10.0.1 and 12.0** -
   which is the measurement the row's old `source` said was unavailable, and which the 16.4 header
   agrees with: `Foundation/NSURLSession.h:1327` and `:1343` annotate both properties `ios(13.0)`.
3. **The gap the port leaves is 10.0 to 15.x, and 13.0 to 15.x of it is not measurable on this
   machine**: the held ladder has no rung between 12.0 and 16.0. Stated as a limit rather than rounded
   off.

The reason the two rows stay `absent` is therefore narrower than "the port cannot see the header
bytes", and it is the part that is true in every band: the port *could* count the header block it
composed, and CFNetwork's own additions to that block - `Host`, `Connection`, `User-Agent` - are not
observable from the port, so the number would differ from the release's instead of matching it. A
count that is close is not a count that answers.
