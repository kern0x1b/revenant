#import <ImageIO/ImageIO.h>

// The iOS 13.4 band's ImageIO name constants, 2 of them that the port did not carry, one object per
// release band because release-split refuses an object whose symbols first appear in more than one release.
//
// The two BC names, kCGImagePropertyBCEncoder and kCGImagePropertyBCFormat, are annotated iOS 12.0, and the first held rung that exports their symbols is iOS 13.4, the release the cache index answers for both.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN ImageIO with dlsym, one process per symbol, and printed as
// text and as bytes by tests/backports/host/imageio-names, which reads this object s values by LINKING it
// into a pure C reader so the value compared against Apple s is the port s own. A convention would have
// been wrong for eleven of these forty-six: kCGImagePropertyAVISDictionary is "{AVIS}", the two TIFF
// position names are "XPosition" and "YPosition", kCGImagePropertyGroupMonoscopicImageLocation is
// "GroupImageIndexMonoscopicImageLocation", and the four monoscopic locations and the three stereo
// aggressor keys are "Center", "Left", "Right", "Unspecified", "Severity", "SubTypeURI" and "Type".
// The same family holds both shapes, so no rule picks the right one and the measurement is the only thing
// that does.
//
// A name is plain data - a caller looks a metadata key up with it - so the port answers it itself and the
// release is never asked. They are const CFStringRef like every other in this family.

extern CFStringRef const kCGImagePropertyBCEncoder;
extern CFStringRef const kCGImagePropertyBCFormat;

CFStringRef const kCGImagePropertyBCEncoder = CFSTR("kCGImagePropertyBCEncoder");
CFStringRef const kCGImagePropertyBCFormat = CFSTR("kCGImagePropertyBCFormat");
