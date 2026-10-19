#import <ImageIO/ImageIO.h>

// The iOS 16.3 band's ImageIO name constants, 1 of them, one object per release band because
// release-split refuses an object whose symbols first appear in more than one release.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN ImageIO with dlsym, and printed as text and as bytes by
// tests/backports/host/imageio-names, which reads this object s values by LINKING it into a pure C reader
// so the value compared against Apple s is the port s own. A convention would have been wrong for most of
// these: in the 14.0 band alone kCGImagePropertyWebPFrameInfoArray is "FrameInfo" and not
// "FrameInfoArray", and kCGImagePropertyWebPDictionary is "{WebP}", while in the 14.1 band
// kCGImageAuxiliaryDataTypeHDRGainMap is its OWN full name. The same family holds both shapes, so no rule
// picks the right one and the measurement is the only thing that does.
//
// A name is plain data - a caller looks a metadata key up with it - so the port answers it itself and the
// release is never asked. They are const CFStringRef like every other in this family.

extern CFStringRef const kCGImagePropertyOpenEXRCompression;

CFStringRef const kCGImagePropertyOpenEXRCompression = CFSTR("Compression");
