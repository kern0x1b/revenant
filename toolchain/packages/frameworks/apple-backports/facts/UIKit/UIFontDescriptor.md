# UIFontDescriptor, iOS 7

Introduced in iOS 7.0: the description of a font by its attributes - name, family, face, size, matrix, symbolic traits - that can
be changed into another description and resolved to a font, with `-[UIFont fontDescriptor]` and `+[UIFont fontWithDescriptor:size:]`
taking one.

Source: the host's own UIKit under Mac Catalyst (`host/fontdesc/run.sh`): 51 answers over descriptors of Helvetica, Courier and
Times New Roman by name and by family - the attributes each answers, the postscript name, size and symbolic traits, every change
(`withSymbolicTraits` for bold, italic, both, none, condensed, expanded, monospace and the traits the release does not know, on a
bold italic face and on a face with no size, `withSize`, `withFamily`, `withFace`, `byAddingAttributes`), the matching
descriptors of a family, the fonts `+fontWithDescriptor:size:` resolves (size zero, a size, a family, a name that is not there),
equality, copying, archiving; UIFoundation and CoreText of iOS 6.0 armv7 for the release's own calls. `device/fontdesc.m` holds
iOS 6 to the recorded answers on the iPhone 4S and the iPad 2.

## How the port carries it

On iOS 7 `UIFontDescriptor` is a wrapper of a CoreText font descriptor and its keys are CoreText's (`UIFontDescriptorKeys.md`). The
port's class keeps the attributes it was made with - `fontAttributes` answers them as they were given, so a descriptor of a name and
a size has those two - and makes the CoreText descriptor when it is asked something that needs the font: the postscript name of a
descriptor that has none, its symbolic traits, an attribute it was not given (`objectForKey:` asks CoreText for the family or the face
of a named descriptor), and the matching descriptors. `-[UIFont fontDescriptor]` is a descriptor of the font's name and size.

`-fontDescriptorWithSymbolicTraits:` replaces the bold, italic, expanded and condensed traits of the font - a bold italic face
asked for bold is bold, asked for none is the regular face - through `CTFontCreateCopyWithSymbolicTraits`, and answers nil where CoreText
finds no such face (condensed and expanded Helvetica); the other traits are not changed, as the release leaves them. The result is a
descriptor of the face's postscript name, and of the size when the original had one. `-fontDescriptorWithFamily:` and `-WithFace:` drop
the name, which would win over them, and keep the rest, as the release does.

`+[UIFont fontWithDescriptor:size:]` of the release takes a `CTFontDescriptorRef` and crashes on an object of another class. The
port replaces it: a `UIFontDescriptor` goes to CoreText, whose font's name gives the `UIFont`, at the size asked or, for zero, at the
descriptor's, or twelve points; a `CTFontDescriptorRef` goes to the release's method as before. A name that is not on the device gives
the release's default font, as the host's does. The earlier answer that the class was absent for this reason is withdrawn.

## What differs

The host's descriptor is a private subclass and its `description` is that class's; the port's class is `UIFontDescriptor` itself. The
symbolic traits the host answers include the font's class in the upper four bits, which iOS 6's CoreText gives its own way, so the tests
compare the lower bits. The text style descriptors have the attributes of the port's own `preferredFontForTextStyle:` fonts. The
matrix is kept as an `NSValue` under `UIFontDescriptorMatrixAttribute` and applied when the font is made; the host's Mac Catalyst
does not offer it, so it is not compared.
