# Forcing a decoded predicate or sort descriptor to be evaluated, iOS 7.0

Source: the SDK 26.2 headers, whose own comment is "Force a predicate which was securely decoded to
allow evaluation" (and the same for `NSSortDescriptor` and `NSExpression`).

The restriction is that an object read out of a secure archive must not be evaluated until the
application says so. **iOS 6.1.3 has no such restriction**: its `NSCoder` carries no allow-evaluation
flag, and a predicate decoded from an archive is evaluable the moment it exists. So on this release the
state the method promises is the state that already holds, and calling it changes nothing -- which is
the answer iOS 6 itself gives, and not a stub.

The flag is kept beside the object rather than dropped, and it is read back through
`-allowsEvaluation`, so it travels with the object as long as the object lives. **No archive carries
it**: the flag is an associated object, and the release's own `NSPredicate` coding writes no
allow-evaluation flag, so a predicate read back from any archive answers YES whatever it said --
which on this release is right, because nothing here ever makes one that is not evaluable. What the
port does not have is a way to make an object that is *not* evaluable, and until it does, the honest
description of this property is "always YES", not "the flag travels".
