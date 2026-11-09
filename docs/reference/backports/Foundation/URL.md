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

## URLComponents.encodedHost and the encodingInvalidCharacters initialisers

The Foundation of iOS 16 added `URLComponents.encodedHost` (`NSURLComponents.encodedHost`), and the Foundation of iOS 17 added
`URL(string:encodingInvalidCharacters:)` and `URLComponents(string:encodingInvalidCharacters:)`. Telegram's `ListMessageSnippetItemNode.swift`
reads `components.encodedHost` under `#available(iOS 16.0, *)` in three places, and the Swift 5.4 overlay has no such member, so it did not compile.

`toolchain/src/swift-runtime/overlay/Foundation/URLComponentsEncoded.swift` adds the Swift members as thin calls: `encodedHost` reads and writes the
`NSURLComponents` property through the struct's own handle, and the two initialisers call the Objective-C ones. The Objective-C side is in
`frameworks/Backports/src/Foundation`: `NSURLComponents.m` gives `encodedHost` (the host as the components hold it: the IDNA form of an international host,
the percent-encoded text otherwise) and a setter that validates the host the way `setPercentEncodedHost:` does, and `NSURLComponents+Encoding17.m` gives the
initialisers. Both initialisers run `RevenantURLParser.m`, which is the RFC 3986 parser of swift-foundation: `RFC3986Parser.parse` with the allowed-character masks of the
components for `encodingInvalidCharacters:YES`, with its `compatibilityParse` fallback (the heuristics of the old parser) for `NO`. The scheme decides how the
host is written: the schemes that the Foundation of iOS 17 lists (`tel`, `facetime`, `imap`, `addressbook` and the others) keep a percent-encoded host, every other
scheme converts a non-ASCII host through ICU's UTS 46 (`uidna_nameToASCII`, read with `dlopen` and `dlsym` from `/usr/lib/libicucore.dylib`, present on iOS 6.1.3),
and an ASCII character that a host cannot hold gives nil. With `NO` a stray `%`, a `#` in a fragment and a second colon in the user information are rejected;
with `YES` they are escaped (an existing `%XX` stays). The port is read as swift-foundation reads it: digits, or for `addressbook` the text up to the path.
`NSURLComponents.string` returns the string the parser accepted until a setter changes the components. `NSURL+Encoding17.m` runs the layer of the NSURL initialiser
(`revenant_url_nsurl`), which is a different algorithm over the same masks: a user information with a colon, a scheme that is not valid is read as a relative path,
a host with `[` is rejected, and a non-ASCII host of a web scheme is converted by ICU with its output taken as it comes (a no-break space becomes a space, a
fullwidth `@` an `@`), the ASCII characters as written being the ones that are checked. The object is made with `CFURLCreateWithBytes`, the one system call that
accepts a host with a space; `revenant_url_reference(string, base)` is the form with a base URL that the markdown backport uses.

## URL's directory properties

`URLDirectories.swift` adds `URL.homeDirectory`, `homeDirectory(forUser:)`, `temporaryDirectory`, `cachesDirectory`, `applicationSupportDirectory`,
`libraryDirectory`, `documentsDirectory`, `desktopDirectory`, `downloadsDirectory`, `moviesDirectory`, `musicDirectory`, `picturesDirectory`,
`sharedPublicDirectory`, `applicationDirectory`, `userDirectory` and `currentDirectory()` (iOS 16), which Telegram's `WebAppController.swift` uses
(`URL.documentsDirectory.path(percentEncoded: false)`). Each is `NSSearchPathForDirectoriesInDomains` for the user domain (the local domain for the application
and user directories), `NSHomeDirectory`, `NSTemporaryDirectory` or the current directory path, as a directory URL.

## Checked

Measured on the host: `url_components_oracle_test.lua` runs the backport's `NSURLComponents` and `NSURL` and macOS's on the 705 lines of `tests/url_components/corpus.txt` and
on 60000 lines from `tests/url_components/fuzz.lua` (three seeds of 20000) and compares `encodedHost`, both values of `encodingInvalidCharacters:` and the earlier
accessors, and the URL string of the `NSURL` form: no differences, and its negative control (every line changed) differs on 672 and 675. Measured on an iPhone 4S
(iOS 6.1.3, `UrlDumpProbe`): 705 corpus lines, 0 differences in either form; 4000 generated lines, 0 differences in the components and 80 in the `NSURL` form,
every one equal to the host's once the percent escapes are decoded: the iOS 6 `NSURL` escapes a space, `|`, `[`, `]` and `%` in a host or port, and holds the `#`
of a URL without an authority as `%23` (C56). `url_percent_encoded_test.lua` also compares the directory properties and `homeDirectory(forUser:)` for the current user, `root` and a
name that does not exist (18 lines, identical to the host's). `lowering_test.lua` and the Telegram replay below check that the Swift members typecheck.

Measured on the Telegram sources: with the rebuilt `swift-runtime` and the lowered headers of this change, the real Bazel arguments of `//submodules/ListMessageItem`
typecheck with no error where they gave `value of type 'URLComponents' has no member 'encodedHost'`.

Not covered: the Swift members were compiled with the runtime and typechecked in Telegram's module, but no Swift program that calls them has run, on the host or
on a device. The `URL.appending(path:)`, `appending(component:)`, `appending(components:)`, `appending(queryItems:)` and `append(...)` family (iOS 16) is not
provided; Telegram 13.0.0 does not call it, and a probe shows each is "has no member".
