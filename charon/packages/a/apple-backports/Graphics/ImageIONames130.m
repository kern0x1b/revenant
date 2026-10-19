#import <ImageIO/ImageIO.h>

// The iOS 13.0 band's ImageIO name constants, 22 of them.
//
// EVERY VALUE WAS READ FROM THE HOST'S OWN ImageIO, with dlsym, and printed as text and as bytes by
// tests/backports/host/imageio-names, which runs one symbol per process on purpose. The port's own
// convention would have been wrong for 50 of these 22: the value is not the symbol's name and not
// its trailing component either. kCGImagePropertyAPNGFrameInfoArray is "FrameInfo" and not
// "FrameInfoArray"; kCGImagePropertyGroupTypeAlternate is "Alternate"; kCGImagePropertyHEICSDictionary is
// "{HEICS}"; and kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte is its own full name, so the same
// group holds both shapes and neither rule picks the right one.
//
// A name is plain data - a caller looks a key up with it - so the port answers it itself and the release
// is never asked. They are const CFStringRef like every other in this family.

// A control of the same shape is in the harness: a name the host does not export must be reported, and a
// run that compared nothing must fail.

extern CFStringRef const kCGImageAnimationDelayTime;
extern CFStringRef const kCGImageAnimationLoopCount;
extern CFStringRef const kCGImageAnimationStartIndex;
extern CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte;
extern CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte;
extern CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte;
extern CFStringRef const kCGImagePropertyAPNGCanvasPixelHeight;
extern CFStringRef const kCGImagePropertyAPNGCanvasPixelWidth;
extern CFStringRef const kCGImagePropertyAPNGFrameInfoArray;
extern CFStringRef const kCGImagePropertyExifOffsetTime;
extern CFStringRef const kCGImagePropertyExifOffsetTimeDigitized;
extern CFStringRef const kCGImagePropertyExifOffsetTimeOriginal;
extern CFStringRef const kCGImagePropertyGIFCanvasPixelHeight;
extern CFStringRef const kCGImagePropertyGIFCanvasPixelWidth;
extern CFStringRef const kCGImagePropertyGIFFrameInfoArray;
extern CFStringRef const kCGImagePropertyHEICSCanvasPixelHeight;
extern CFStringRef const kCGImagePropertyHEICSCanvasPixelWidth;
extern CFStringRef const kCGImagePropertyHEICSDelayTime;
extern CFStringRef const kCGImagePropertyHEICSDictionary;
extern CFStringRef const kCGImagePropertyHEICSFrameInfoArray;
extern CFStringRef const kCGImagePropertyHEICSLoopCount;
extern CFStringRef const kCGImagePropertyHEICSUnclampedDelayTime;

CFStringRef const kCGImageAnimationDelayTime = CFSTR("DelayTime");
CFStringRef const kCGImageAnimationLoopCount = CFSTR("LoopCount");
CFStringRef const kCGImageAnimationStartIndex = CFSTR("StartIndex");
CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte");
CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte");
CFStringRef const kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte");
CFStringRef const kCGImagePropertyAPNGCanvasPixelHeight = CFSTR("CanvasPixelHeight");
CFStringRef const kCGImagePropertyAPNGCanvasPixelWidth = CFSTR("CanvasPixelWidth");
CFStringRef const kCGImagePropertyAPNGFrameInfoArray = CFSTR("FrameInfo");
CFStringRef const kCGImagePropertyExifOffsetTime = CFSTR("OffsetTime");
CFStringRef const kCGImagePropertyExifOffsetTimeDigitized = CFSTR("OffsetTimeDigitized");
CFStringRef const kCGImagePropertyExifOffsetTimeOriginal = CFSTR("OffsetTimeOriginal");
CFStringRef const kCGImagePropertyGIFCanvasPixelHeight = CFSTR("CanvasPixelHeight");
CFStringRef const kCGImagePropertyGIFCanvasPixelWidth = CFSTR("CanvasPixelWidth");
CFStringRef const kCGImagePropertyGIFFrameInfoArray = CFSTR("FrameInfo");
CFStringRef const kCGImagePropertyHEICSCanvasPixelHeight = CFSTR("CanvasPixelHeight");
CFStringRef const kCGImagePropertyHEICSCanvasPixelWidth = CFSTR("CanvasPixelWidth");
CFStringRef const kCGImagePropertyHEICSDelayTime = CFSTR("DelayTime");
CFStringRef const kCGImagePropertyHEICSDictionary = CFSTR("{HEICS}");
CFStringRef const kCGImagePropertyHEICSFrameInfoArray = CFSTR("FrameInfo");
CFStringRef const kCGImagePropertyHEICSLoopCount = CFSTR("LoopCount");
CFStringRef const kCGImagePropertyHEICSUnclampedDelayTime = CFSTR("UnclampedDelayTime");
