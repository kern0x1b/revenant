#import <ImageIO/ImageIO.h>

// The iOS 16.0 band's ImageIO name constants, 11 of them (kCGImagePropertyHEIFDictionary, the twelfth, is ImageIONames110b.m: its release is 11.0), one object per release band because
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

extern CFStringRef const kCGImagePropertyGroupImageBaseline;
extern CFStringRef const kCGImagePropertyGroupImageDisparityAdjustment;
extern CFStringRef const kIIOCameraExtrinsics_CoordinateSystemID;
extern CFStringRef const kIIOCameraExtrinsics_Position;
extern CFStringRef const kIIOCameraExtrinsics_Rotation;
extern CFStringRef const kIIOCameraModelType_GenericPinhole;
extern CFStringRef const kIIOCameraModelType_SimplifiedPinhole;
extern CFStringRef const kIIOCameraModel_Intrinsics;
extern CFStringRef const kIIOCameraModel_ModelType;
extern CFStringRef const kIIOMetadata_CameraExtrinsicsKey;
extern CFStringRef const kIIOMetadata_CameraModelKey;

CFStringRef const kCGImagePropertyGroupImageBaseline = CFSTR("GroupImageBaseline");
CFStringRef const kCGImagePropertyGroupImageDisparityAdjustment = CFSTR("GroupImageDisparityAdjustment");
CFStringRef const kIIOCameraExtrinsics_CoordinateSystemID = CFSTR("CoordinateSystemID");
CFStringRef const kIIOCameraExtrinsics_Position = CFSTR("Position");
CFStringRef const kIIOCameraExtrinsics_Rotation = CFSTR("Rotation");
CFStringRef const kIIOCameraModelType_GenericPinhole = CFSTR("GenericPinhole");
CFStringRef const kIIOCameraModelType_SimplifiedPinhole = CFSTR("SimplifiedPinhole");
CFStringRef const kIIOCameraModel_Intrinsics = CFSTR("Intrinsics");
CFStringRef const kIIOCameraModel_ModelType = CFSTR("ModelType");
CFStringRef const kIIOMetadata_CameraExtrinsicsKey = CFSTR("CameraExtrinsics");
CFStringRef const kIIOMetadata_CameraModelKey = CFSTR("CameraModel");
