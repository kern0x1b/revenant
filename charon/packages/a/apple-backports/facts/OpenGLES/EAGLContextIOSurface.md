# EAGLContext and an IOSurface, on the release's own nine-argument call

`-[EAGLContext texImageIOSurface:target:internalFormat:width:height:format:type:plane:]` is the
public form of a call the release already has. Measured on the armv7 6.1.3 cache with
`objc.binary_inventory`, `EAGLContext` carries

    -texImageIOSurface:target:internalFormat:width:height:format:type:plane:invert:

and no eight-argument form, so what the port adds is a forward and not a second implementation.
The public API has no way to ask for a Y flip and its documented behaviour is a straight upload of
the surface into the target texture, so the flip goes off. The release's own answer is returned as
it is: whether the surface's pixel format matches the `format`/`type` the caller asked for, and
whether the plane index is one the surface has, are the release's business, and the port does not
second-guess either.

The `if (![self respondsToSelector:flipping]) return NO;` guard is there for a release whose EAGL
does not have the call at all: the port's job then is to say the upload did not happen, not to
report a success it cannot back.

Why a forward through `objc_msgSend` and not `performSelector:withObject:withObject:`: the call has
nine arguments, and `performSelector:` families stop at two objects.
