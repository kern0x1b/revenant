# URL on iOS 6: the percent-encoded accessors and the file path initialiser

The Foundation of iOS 16 added `URL.host(percentEncoded:)`, `user(percentEncoded:)`, `password(percentEncoded:)`,
`path(percentEncoded:)`, `query(percentEncoded:)` and `fragment(percentEncoded:)`, and `URL(filePath:directoryHint:relativeTo:)` with
`URL.DirectoryHint`. The Foundation overlay of this port is the Swift 5.4 one plus
`toolchain/src/swift-runtime/overlay/Foundation/URLPercentEncoded.swift`, which adds them. Telegram's `UrlHandling.swift`
(`parsedUrl.host(percentEncoded: true)`) and `DrawingScreen.swift` (`URL(filePath:)`) call them under `#available(iOS 16.0, *)`.

The accessors split `absoluteURL.absoluteString` as RFC 3986 does (scheme, authority with user information, host and port, path,
query, fragment) and decode percent-escapes themselves. They do not go through `URLComponents`: the host's `URLComponents`
keeps the brackets of an IPv6 host and decodes punycode, which `URL.host` does not, and the NSURLComponents of iOS 6 is a backport
with a behaviour of its own. `percentEncoded: true` returns the component as written (an IP literal without its brackets);
`false` returns it percent-decoded, nil for an invalid UTF-8 sequence and an empty path for `path`. An empty host is nil unless user
information or a port is present. The initialiser decides whether the path is a directory itself, as the system's does (`isDirectory` and `notDirectory` as
named, `inferFromPath` by the trailing slash, `checkFileSystem` by `lstat` and the trailing slash for a path that is not there; an empty path is
the current directory), strips trailing slashes, and calls `NSURL(fileURLWithPath:isDirectory:relativeTo:)`, which the backports implement,
anchored at the current directory for a relative path. It does not call the Swift `URL(fileURLWithPath:isDirectory:relativeTo:)`, whose
Swift availability is iOS 9 and which the lowering does not touch.

## Checked

Measured: `frameworks/Backports/tests/url_percent_encoded_test.lua` compiles the overlay with its names changed on the host,
runs the same program against the host's `URL` and against ours, and requires identical output for 692 URLs of
`tests/url_components/corpus.txt` that are ASCII and have a scheme (the set a CoreFoundation `NSURL` can represent) plus
eleven percent-encoded hosts and credentials, and for the initialiser with the default, the four hints and a base directory, over thirteen paths.

Not covered: a URL string with non-ASCII characters. An iOS 6 `NSURL` cannot be made from one, so the accessors never see one there;
the host's `URL` converts such a host to punycode when it is parsed, which has no counterpart in the accessors. Not measured on a device.
