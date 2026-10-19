# The iOS 13.0 band's ImageIO name constants

Twenty-two `kCGImage*` string constants, plain data a caller looks a metadata key up with. The port
answers them itself and the release is never asked.

## Every value was read, and the convention would have been wrong

Each value came from the host's own ImageIO with `dlsym`, printed as text and as bytes by
`tests/backports/host/imageio-names`, which runs **one symbol per process** on purpose. Across the whole
family's 64 absent names, the value equals the symbol's own name in 7 cases and its trailing component in
7, so **50 of 64 match neither** and no rule picks the right one. The same group holds both shapes:
`kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte` is its own full name, while its neighbour
`kCGImagePropertyAPNGFrameInfoArray` is `FrameInfo` and not `FrameInfoArray`.

Others that defeat a rule: `kCGImagePropertyGroupTypeAlternate` is `Alternate`;
`kCGImagePropertyHEICSDictionary` is `{HEICS}`; `kIIOMetadata_CameraExtrinsicsKey` is `CameraExtrinsics`.

## The control, on merged rows as well as on this one

A 40-name sample of the 328 already-implemented constants, drawn with seed 20260929, was read with the
same harness and compared with the port's own `ImageIONames*.m`: **40 match, 0 mismatch, 0 host-missing,
0 crash.** The merged values are correct, and they are measured text, not a symbol-name rule -
`kCGImagePropertyHeight` is `Height`. Forty of 328, so a defect confined to the other 288 would not show.

## Two defects in the harness, kept in its header

`dlsym` on a `kCGImage*` name returns **the address of the variable**, not the object: these are
`const CFStringRef` globals, so the object is `*s`. Calling `CFGetTypeID` on the address faulted with
SIGBUS before the program printed anything, in every batch, with and without Foundation linked - which is
what made it look like a dyld problem rather than a missing dereference. And one process per symbol, so a
fault names its own name instead of ending a run unexplained.
