# The names CFNetwork added from iOS 8.0 to 13.0

Seven names of CFNetwork, none of which iOS 6.1.3 exports: the two HTTP versions of 8.0 and 13.0,
the call-signalling network service type of 10.0, and the four stream properties of 9.0 and 13.0.

They are carried because of what a missing name does: `CFNetwork.framework` is on the release, so an
application that names one of these links a strong reference to a symbol nothing provides, and dyld
kills it before `main`. Measured on the release: the `CFNetwork` image of the armv7 shared cache of
iOS 6.1.3 exports `kCFHTTPVersion1_1` and 225 `kCF*` names, and none of these seven.

The values are Apple's own, read out of a real cache with `tools/corpus/cache-value.lua` through the symbols of
`CFNetwork` in the arm64e shared cache of iOS 18.0:

| symbol | value |
| --- | --- |
| `_kCFHTTPVersion2_0` | `HTTP/2.0` |
| `_kCFHTTPVersion3_0` | `HTTP/3.0` |
| `_kCFStreamNetworkServiceTypeCallSignaling` | `kCFStreamNetworkServiceTypeCallSignaling` |
| `_kCFStreamPropertyAllowConstrainedNetworkAccess` | `kCFStreamPropertyAllowConstrainedNetworkAccess` |
| `_kCFStreamPropertyAllowExpensiveNetworkAccess` | `kCFStreamPropertyAllowExpensiveNetworkAccess` |
| `_kCFStreamPropertyConnectionIsExpensive` | `kCFStreamPropertyConnectionIsExpensive` |
| `_kCFStreamPropertySocketExtendedBackgroundIdleMode` | `kCFStreamPropertySocketExtendedBackgroundIdleMode` |

The two version names are the ones a protocol line is written with (`HTTPMessage.h` of the SDK 16.4
lists them under `kCFHTTPVersion1_1`), and the other five are the constant names themselves, which is
what CFNetwork does: a stream property key is the symbol's own text, so a key and its documentation
cannot drift apart. Nothing here is invented and nothing is shortened.

## What the ladder measures, and where it differs from the headers

The objects these constants are compiled in are placed by the release the armv7 cache ladder measures
each symbol first appearing in, not by the header's annotation, and the two do not always agree. Read
with `dyld.first_releases` over the held ladder:

| symbol | the header annotates | the ladder measures |
| --- | --- | --- |
| `kCFHTTPVersion2_0` | 8.0 | **9.0** — the armv7 cache of 8.0 exports no such symbol |
| `kCFStreamPropertySocketExtendedBackgroundIdleMode` | 9.0 | 9.0 |
| `kCFStreamNetworkServiceTypeCallSignaling` | 10.0 | **10.0.1** — the first rung of 10.0 held, so an upper bound |
| `kCFStreamPropertyAllowConstrainedNetworkAccess`, `kCFStreamPropertyAllowExpensiveNetworkAccess`, `kCFStreamPropertyConnectionIsExpensive` | 13.0 | **13.4** - the held 13.4 cache (arm64) is the first held rung that exports them |
| `kCFHTTPVersion3_0` | 13.0 | **16.0** - the first held rung after 13.4 that exports it |

So the seven names live in four objects, one release each: `CFNetworkNames9.m` carries the two the
ladder puts at 9.0, `CFNetworkNames10.m` the one at 10.0.1, `CFNetworkNames134.m` the three it puts at
13.4, and `CFNetworkNames160.m` the one it puts at 16.0. An object carries the API of a single release,
and the release it is carried from is the one the ladder measured.

## What the release does with them

The keys are carried; the behaviour behind them is the release's own CFNetwork, and the release has
none of the systems those keys describe:

- `kCFStreamPropertyAllowConstrainedNetworkAccess` and `kCFStreamPropertyAllowExpensiveNetworkAccess`
  are how an application asks to be kept off a metered or cellular network. iOS 6 has no per-app
  cellular limit and no Low Data Mode, so a stream set to honour them is set to a preference nothing
  enforces — which is the same answer the release gives to every property it has no reader for.
- `kCFStreamPropertyConnectionIsExpensive` is a *copy* key: it tells the application whether the
  connection it is reading runs over a priced interface. On this release the streams are the ones of
  iOS 6 and answer for a key they do not know. The port does not compute an answer of its own: a
  made-up YES or NO about a price the release does not charge would be worse than the release's own
  answer.
- `kCFStreamNetworkServiceTypeCallSignaling` names the socket type CallKit uses for signalling. The
  name is here for an application that sets it; the release's socket layer is what decides what a
  stream of that service type can be, and it is not this package's business to answer for it.
- `kCFStreamPropertySocketExtendedBackgroundIdleMode` asks for the socket to be held open while the
  application is suspended in the background. iOS 6 suspends an application and closes what it was
  using; the property is stored and read by nothing, as the release stores and reads nothing for it.
- The two version names are strings a caller sets on an HTTP message. The release's HTTP stack speaks
  HTTP/1.1; the string is carried so the code that sets it runs, and the wire protocol is still the
  release's.

## What was measured

The values (the 18.0 arm64e cache, through the symbols, with `tools/corpus/cache-value.lua`), the absence on the
release (the 6.1.3 armv7 cache), and the types and the release each name arrived in (the headers of
the SDK 16.4). The behaviour of a stream asked for these keys is the release's own and was not
measured here: it is a property of iOS 6's CFNetwork, not of this package, and no answer of this
port's is claimed for it.
