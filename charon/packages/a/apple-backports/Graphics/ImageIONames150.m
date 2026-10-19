#import <ImageIO/ImageIO.h>

// The iOS 15.0 band's ImageIO name constants, 12 of them, one object per release band because
// release-split refuses an object whose symbols first appear in more than one release.
//
// EVERY VALUE WAS READ FROM THE HOST S OWN ImageIO with dlsym, as text and as bytes, and the harness reads
// the PORT S values by linking this object into a pure C reader and comparing the two, so what is compared
// is the port s own and not a string the harness already had.
//
// A CONVENTION WOULD HAVE BEEN WRONG FOR SEVERAL OF THESE, in both directions at once. The trailing
// component is right for most: kCGImagePropertyGroupImageIndexLeft is GroupImageIndexLeft. It is wrong for
// the rest: kCGImagePropertyGroupTypeAlternate is "Alternate" and not "GroupTypeAlternate",
// kCGImagePropertyGroupImagesAlternate is "GroupImages" and not "GroupImagesAlternate", and
// kCGImagePropertyGroups is "{Groups}" with braces. Across the family s 64 absent names the value equals
// the symbol s own name in 7 cases and its trailing component in 7, so 50 match neither.
//
// A name is plain data - a caller looks a metadata key up with it - so the port answers it itself and the
// release is never asked. They are const CFStringRef like every other in this family.

extern CFStringRef const kCGImagePropertyGroupImageIndexLeft;
extern CFStringRef const kCGImagePropertyGroupImageIndexRight;
extern CFStringRef const kCGImagePropertyGroupImageIsAlternateImage;
extern CFStringRef const kCGImagePropertyGroupImageIsLeftImage;
extern CFStringRef const kCGImagePropertyGroupImageIsRightImage;
extern CFStringRef const kCGImagePropertyGroupImagesAlternate;
extern CFStringRef const kCGImagePropertyGroupIndex;
extern CFStringRef const kCGImagePropertyGroupType;
extern CFStringRef const kCGImagePropertyGroupTypeAlternate;
extern CFStringRef const kCGImagePropertyGroupTypeStereoPair;
extern CFStringRef const kCGImagePropertyGroups;
extern CFStringRef const kCGImagePropertyImageIndex;

CFStringRef const kCGImagePropertyGroupImageIndexLeft = CFSTR("GroupImageIndexLeft");
CFStringRef const kCGImagePropertyGroupImageIndexRight = CFSTR("GroupImageIndexRight");
CFStringRef const kCGImagePropertyGroupImageIsAlternateImage = CFSTR("GroupImageIsAlternateImage");
CFStringRef const kCGImagePropertyGroupImageIsLeftImage = CFSTR("GroupImageIsLeftImage");
CFStringRef const kCGImagePropertyGroupImageIsRightImage = CFSTR("GroupImageIsRightImage");
CFStringRef const kCGImagePropertyGroupImagesAlternate = CFSTR("GroupImages");
CFStringRef const kCGImagePropertyGroupIndex = CFSTR("GroupIndex");
CFStringRef const kCGImagePropertyGroupType = CFSTR("GroupType");
CFStringRef const kCGImagePropertyGroupTypeAlternate = CFSTR("Alternate");
CFStringRef const kCGImagePropertyGroupTypeStereoPair = CFSTR("StereoPair");
CFStringRef const kCGImagePropertyGroups = CFSTR("{Groups}");
CFStringRef const kCGImagePropertyImageIndex = CFSTR("ImageIndex");
