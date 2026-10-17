#import <ImageIO/ImageIO.h>

// The iOS 16.0 band's ImageIO name constants, 1 of them that the port did not carry, one object per
// release band because release-split refuses an object whose symbols first appear in more than one release.
//
// The AVIS name, kCGImagePropertyAVISDictionary, is in no held rung at all, so its own annotation of iOS 16.0 places it.
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

extern CFStringRef const kCGImagePropertyAVISDictionary;

CFStringRef const kCGImagePropertyAVISDictionary = CFSTR("{AVIS}");
