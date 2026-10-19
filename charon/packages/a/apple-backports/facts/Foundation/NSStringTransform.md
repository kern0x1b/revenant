# Transforming a string, iOS 9

Source: the host's own Foundation and the differential run of
`tests/backports/host/foundation2/run.sh`, which applies each of the sixteen named transforms, a compound
one and an invented one to nine texts, forwards and in reverse, through both methods.

`-stringByApplyingTransform:reverse:` answers the transformed string, and the sixteen names of the SDK
are the `kCFStringTransform…` identifiers, which is why a transform that CoreFoundation knows by a name
of its own - a compound like `Any-Latin; Latin-ASCII`, or `Hex-Any` - works just as well: the name is
handed to the transform engine as it stands. Each of the sixteen constants is the very string of its
CoreFoundation counterpart, a closing parenthesis and the identifier's name: `NSStringTransformLatinToKatakana`
is `)kCFStringTransformLatinKatakana`, `NSStringTransformToXMLHex` is `)kCFStringTransformToXMLHex`. The
backport carries those strings, and the device test records all sixteen and holds iOS 6 to the host's.

A name the engine does not know answers nil, and it is the only way these methods fail.

`-[NSMutableString applyTransform:reverse:range:updatedRange:]` transforms the given range in place and
answers whether it did. When it did, it writes into `updatedRange` the range the transformed text now
occupies, which is not the range it was given when the transform changed the length: `héllo wörld` at
(2, 11) becomes eleven characters of Katakana at (2, 10). When the name is unknown it answers NO, leaves
the string exactly as it was, and does not write to `updatedRange` at all - a caller that passed a range
of its own gets it back untouched.

Reversing is the transform's own inverse, and for a transform that has none it is the identity: the
reverse of `Hex-Any` turns `héllo wörld` into `hé…`, and the forward direction turns that back.
