# HTTPS on a system whose TLS stopped working

iOS 6 ships SecureTransport from 2012 and OpenSSL 0.9.8. Neither can complete a
handshake with a current server: measured against a live host, every CBC/SHA-1
suite is refused and only AEAD suites — AES-GCM, ChaCha20-Poly1305 — are
offered, none of which this system speaks. The certificate side is fine, the
device already trusts ISRG Root X1 and X2; the connection never gets that far.
Those roots were issued after this firmware, so the device trusts more than its
root filesystem shows: judge trust on the device, with `SecTrustEvaluate` on a
real chain, never from the anchors of an extracted root filesystem.

So the port brings its own protocol, over OpenSSL built for armv7, in two
places. `platform/safari/tls-openssl.c` becomes `rev-TLS.dylib`, which the
Safari package installs and the loader inserts; `app/ModernTLSURLProtocol.m` is
compiled into the standalone application.

| | `platform/safari/tls-openssl.c` | `app/ModernTLSURLProtocol.m` |
| --- | --- | --- |
| Takes over | the 25 SecureTransport entry points CFNetwork imports | every request that goes through `NSURLConnection` |
| Leaves alone | the socket, its timeouts and proxy handling, the `SecTrust` evaluation — all still CFNetwork's | nothing above the socket: the exchange is made here and handed back as an ordinary `NSURLResponse` |
| Why both | anything that reaches the network below `NSURLConnection` — a WebSocket, CFNetwork's own fetches — is served here | a page is a hundred requests, and the pool, the cache and the app-shell policy all need the whole exchange |

## Interposing SecureTransport

CFNetwork records which library each symbol came from, so exporting the same
names is not enough. The replacements are registered the way dyld supports:
pairs of (replacement, original) in `__DATA,__interpose`. Three of the
twenty-five are gone from the modern SDK's headers — deprecated long after this
device shipped — and are re-declared locally, because iOS 6's CFNetwork still
calls them.

Nothing here weakens verification. The peer chain is handed back as a real
`SecTrustRef` built from the certificates the server sent, and the system
evaluates it against its own trust store. The evaluation is bound to the host
that was asked for: a basic X.509 policy asks only whether a chain is valid, not
whether it was issued for this site, so without the host binding any
certificate a trusted CA ever signed would be accepted for any domain.

Two rules this layer learned:

- **One `SSL_CTX` for the process, built under a lock.** The session cache lives
  in the context, so a context per connection makes resumption impossible by
  construction. CFNetwork opens connections from several threads, and two
  arriving together would each build a context and each get a cache of its own.
- **Answer `SSLGetBufferedReadSize` from `SSL_pending`.** CFNetwork asks it
  before deciding to wait on the socket. OpenSSL has already taken those bytes
  off the socket and holds them decrypted, so a socket that will never be
  readable again is exactly the state a large response ends in — everything
  delivered, the last record still buffered, and the load never finishing.

Sessions are kept per host, because OpenSSL's client cache stores what a server
hands out but never looks anything up. Measured before that was added: one tab
change did twenty-four full handshakes. On TLS 1.3 the ticket arrives after the
handshake, so the session is taken again on the first read — without that,
nothing resumes.

## The protocol that owns the exchange

`NSURLProtocol` is the documented place to take `NSURLConnection` requests over,
and `ModernTLSURLProtocol` takes every `https` one. A page is a hundred requests
or more, so what a request avoids doing matters as much as what it does:

- Connections are pooled per `host:port`, newest first, and handed to the next
  request. Whether a connection is worth keeping cannot be known for certain —
  the server may close it between the answer and the next write — so a request
  that fails before a byte has been read or handed on is simply sent again on a
  connection of its own making. Leftover bytes from the last response mean the
  framing is lost and the connection is dropped instead.
- A read on a quiet pooled connection lets OpenSSL take the TLS 1.3 session
  ticket while the connection is still ours, so a host's first parallel
  connections resume rather than each paying a full handshake.
- The certificate store is parsed once per process, not once per request.
- DNS answers are cached for two minutes, sixteen hosts, six addresses each.
- Bodies stream. Content-Encoding is undone as bytes arrive, each chunk is
  released inside its own pool, and nothing is ever held whole. On a 512 MB
  device that is a memory measure as much as a speed one: jetsam is the other
  way a page load ends here.

`-[NSURL path]` is percent-decoded, so the request line is built from the
escaped form in the absolute string. Header field values are read as UTF-8 and
fall back to ISO-8859-1, which is what RFC 7230 gives and where a
`Content-Disposition` filename still shows up. Header lookups are
case-insensitive everywhere, because HTTP/2 origins answer in lower case even
over HTTP/1.1, and because `-rangeOfString:` on a nil header answers `{0, 0}`,
which reads as a match.

## The disk cache

Nothing else in this process remembers anything between runs. WebCore's memory
cache is eight megabytes that die with the process, its back-forward cache holds
zero pages under the defaults this port keeps, and `+[WebView _setCacheModel:]`
runs only off a notification `+[WebPreferences standardPreferences]` never
posts.

`NSURLCache` looks like the answer and is not. A request answered by an
`NSURLProtocol` subclass is never read from it: with an entry demonstrably
present in the shared cache, `-startLoading` was still called, `-cachedResponse`
was still nil, and the bytes the protocol produced were the ones returned.
Asking for `NSURLCacheStorageAllowed` does not change it — that is a request
addressed to a loader which is not in the path. The read is the half a cache is
for, so all of it is here instead, and nothing downstream catches a mistake in
it.

The rules are RFC 9111's, for a private cache. **Stale responses are never
served** (outside the app-shell policy below), which is why `must-revalidate`,
`stale-while-revalidate` and `stale-if-error` decide nothing and are not read.
What else is deliberately left out:

- GET only. A HEAD carries the headers a GET would have had, including a
  `Content-Length` for a body it does not have, so storing one under the key a
  GET reads would put a length against no bytes.
- No ranges. A request carrying one is not answered from the cache and a 206 is
  never stored: writing a partial representation into a slot that reads back as
  a whole one is the exact failure this file is not allowed to have.
- `s-maxage`, `public`-as-permission and `proxy-revalidate` address shared
  caches. `private` is honoured by storing rather than by refusing to.
- Of the request directives, `no-store`, `no-cache` and `max-age` are honoured.
  `min-fresh`, `max-stale` and `only-if-cached` are not read — WebKit sends none
  of them as headers, and a directive read but not obeyed is worse than one not
  read. `only-if-cached` reaches this code as
  `NSURLRequestReturnCacheDataDontLoad` instead, which is honoured, and where
  that policy has no entry a failure is the correct answer.
- The qualified forms, `no-cache="field"` and `private="field"`, are read as the
  unqualified ones: stricter than asked, never looser.
- One variant per key. RFC 9111 allows several representations chosen by `Vary`;
  this keeps the most recent and treats a mismatch as a miss, which is a subset
  of the allowed behaviour because a cache may always evict.
- Bodies are stored decoded, exactly as WebKit was handed them, so a replay is
  byte-for-byte the original delivery. The encoded bytes no longer exist by the
  time storing is possible.
- `Set-Cookie` is not stored. It was applied to `NSHTTPCookieStorage` when the
  response arrived and that persists on its own; replaying a weeks-old
  `Set-Cookie` on every hit would resurrect cookies the server has expired.
  Keeping session cookies out of a file is worth having besides, on a device
  where every application runs as the same user.
- No digest is kept of a stored body: hashing a hundred kilobytes on this
  processor is several milliseconds on exactly the path the cache exists to
  shorten. What is defended against is the corruption that is actually likely —
  a truncated or half-written file, which the recorded lengths catch, and a body
  reaching the disk after the rename that published it, which one `fsync`
  orders against. Not `F_FULLFSYNC`: the point is to order the two writes
  against each other, not to promise the entry survives a power cut. A lost
  entry is only a miss.

Dates are parsed here rather than through `strptime`, which would read month
names through the process locale — and WebKit and ICU are both in this address
space, both setting locales. All three formats RFC 9110 §5.6.7 requires are
accepted, including the obsolete RFC 850 two-digit year.

### The entry file, and what it costs

    magic | metadata length | body length | metadata | body

The two lengths are in the fixed part because the body length is only known when
the body ends, and a fixed field can be written back over without its encoding
changing size. A body is written as it streams, under a name nothing reads; the
rename at the end is what makes it visible, so a reader arriving at any moment
sees the whole of one version or the whole of another. Files are `0600` rather
than the umask — a cache of a logged-in site's pages is worth as much as the
session that fetched it.

The store lives in `Library/Caches` under the bundle identifier, because that is
the directory the system is entitled to empty when the device runs short of
space, which is exactly the licence an HTTP cache wants.

| Bound | Value | Why |
| --- | --- | --- |
| Cache size | 20 MB, swept to a low-water mark | A site's shell is two to five megabytes decoded, so this holds several applications' interfaces with room for the images around them. Not measured on the device; wrong in the direction of too small, which costs a request rather than correctness |
| One entry | ⅛ of the cache | Admission control, not an RFC rule: one blob big enough to push the whole shell out makes the next launch slower, which is the one thing the cache prevents |
| Entry count | bounded | Twenty megabytes of two-hundred-byte responses is a hundred thousand files, and it is the sweep that pays for that, not the lookup |
| Heuristic freshness | a tenth of the age since `Last-Modified`, one day maximum | RFC 9111 §4.2.2 leaves the heuristic to the cache; no `Last-Modified` means no guess and a revalidation |

Eviction is least-recently-used by file modification time, kept current with one
`utimes()` against a file that is never rewritten, so ordering costs nothing on
the fast path. A sweep runs on the thread that committed the write rather than
on a queue: measured before that changed, thirteen launches storing two
megabytes each left twenty-seven megabytes on disk under a twenty megabyte cap,
because only one of the thirteen lived long enough for a queued sweep to run.
Until a walk has finished, the byte total is not a number — it is a zero
standing in for a directory nobody has looked at, and treating that as plenty of
room is how a cache grows every launch.

## The app-shell policy, which is not RFC 9111

Everything above serves nothing stale. This does, and it is a policy rather
than a bug: **off by default**, turned on by an embedder for its own hosts.

A wrapped application is two things that age at very different speeds. There is
a shell — the document, and the scripts, styles and fonts that draw the
interface — which changes when the operator ships a release, and there is data,
which changes every minute. HTTP has one freshness model for both, so in
practice the shell arrives `no-cache` or with a max-age of minutes, and every
launch pays a revalidation round trip before the first pixel — a round trip that
almost always ends in a 304. On this device, over a phone network, that is most
of the time to first paint.

The web's answer is a Service Worker running cache-first. WebKitLegacy has no
Service Worker, so the strategy lives in the one place that sees every request:
a stored shell response is handed over immediately, however stale HTTP considers
it, and a revalidation is queued behind the page.

Four things keep it from being a cache that is simply wrong:

- **It is off**, and enabling it requires naming the hosts. There is no sensible
  reading of "cache-first, everywhere".
- **It is narrow.** Only requests classified as shell are served this way, and
  the classifier refuses anything it cannot positively identify. Data is never
  served stale: a chat client showing yesterday's messages instantly is worse
  than one that waits.
- **It is bounded** — one week. The steady state is not a week behind but one
  launch behind, because every hit queues a revalidation; the bound describes
  the worst case, the application nobody has opened in a long time. It is also
  how long a bad release can keep painting, which is why it is not a month.
- **It says so.** Every response it serves is logged as a policy decision,
  under `[shell]` rather than `[cache]`.

What is *stored* is untouched by any of this. Storage stays RFC 9111 throughout,
so turning the policy off restores standard behaviour on the spot — there is no
separate store to flush, only a rule that stops being applied.

### Telling a shell from data

`Sec-Fetch-Dest` is WebKit's own word for what a request is for, set by
`CachedResourceLoader::updateHTTPRequestHeaders` from the Fetch destination:
`document`, `iframe`, `style`, `script`, `font`, `image`, `json`, and `empty`
for `XMLHttpRequest` and `fetch()`. That is the distinction this policy needs,
made by the code that knows the answer. It can be missing — a site on the quirks
list has it suppressed, a frame with no document yet is not given one — and then
`Accept` stands in for the two cases where it is unambiguous, a document and a
stylesheet. Scripts and XHR share a catch-all `Accept` and are never guessed at.

Both halves have to agree before anything stale is served: a `script` whose
stored response is `application/json` is not a script, and an `XMLHttpRequest`
is `empty` and matches nothing whatever it fetched. Images are excluded on
purpose — an avatar or a piece of album art is data wearing a picture's clothes,
and the ones that really are shell are almost always served under a versioned
URL, where RFC 9111 already answers them from disk.

### When the revalidations run

Not while the page is loading. The device has two slow cores and a hard memory
ceiling, and a burst of background requests during the load would spend exactly
the time the policy just saved — the round trip would not be off the critical
path, it would be next to it, competing for the same cores, sockets and jetsam
budget.

So a hit queues its revalidation and nothing else. The queue drains on one
serial background queue, one request at a time, once the foreground has been
quiet for two seconds — no request started, finished or failed. That is long
enough for a normal subresource chain to have ended and short enough to still
be inside the launch, which is the only time a wrapped application is reliably
running. A page that never goes quiet gets its queue drained anyway after a
longer deadline, still one at a time, still at background priority.

A background revalidation runs the whole ordinary path — the pool, the
handshake, the conditional, the 304 merge, the store — and throws away only the
delivery, so it cannot drift from a foreground load the way a second
implementation would. `+precache:` warms the store the same way, on the same
serial queue, so a packaged application can fetch its shell at install time and
be instant on the first launch rather than the second.

## Trust is not allowed to be a stub

`SecTrustGetTrustResult` (iOS 7) and `SecTrustEvaluateWithError` (iOS 12) do not
exist here and are implemented in `compat/ios6_compat.c` in terms of
`SecTrustEvaluate`, which has been present since iOS 2. They are load-bearing:
they are the accept/reject decision for every WebSocket connection and for
`ResourceResponseCocoa.mm`'s certificate metadata. As stubs answering success —
which is what they were — that step never ran at all. See
[compatibility.md](compatibility.md) for the rule that produced that fix.

## Reading what happened

The protocol logs a line per request when logging is on, tagged by what decided
the answer: `[cache]` for RFC 9111, `[shell]` for the policy, `[net]` for a
round trip. The TLS layer records the gap between a request going out and its
first byte coming back, which is the only place that gap can be measured — while
the page is waiting, nothing in the page runs to measure anything — and the gap
between reads while decrypted bytes are still buffered, which is the shape of a
stall this port spent a long time chasing.

## Related

- [architecture.md](architecture.md) — how the engine gets underneath Safari
- [compatibility.md](compatibility.md) — what this OS does not have, and the
  rule every shim answers to
- [building.md](building.md) — building and deploying the compat package
