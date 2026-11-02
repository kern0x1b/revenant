#include "../revenant_impl.h"
#import <ImageIO/ImageIO.h>

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

CFStringRef const BACKPORT_IMPL(kCGImageAnimationDelayTime) = CFSTR("DelayTime");
CFStringRef const BACKPORT_IMPL(kCGImageAnimationLoopCount) = CFSTR("LoopCount");
CFStringRef const BACKPORT_IMPL(kCGImageAnimationStartIndex) = CFSTR("StartIndex");
CFStringRef const BACKPORT_IMPL(kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte) = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte");
CFStringRef const BACKPORT_IMPL(kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte) = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte");
CFStringRef const BACKPORT_IMPL(kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte) = CFSTR("kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyAPNGCanvasPixelHeight) = CFSTR("CanvasPixelHeight");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyAPNGCanvasPixelWidth) = CFSTR("CanvasPixelWidth");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyAPNGFrameInfoArray) = CFSTR("FrameInfo");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyExifOffsetTime) = CFSTR("OffsetTime");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyExifOffsetTimeDigitized) = CFSTR("OffsetTimeDigitized");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyExifOffsetTimeOriginal) = CFSTR("OffsetTimeOriginal");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGIFCanvasPixelHeight) = CFSTR("CanvasPixelHeight");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGIFCanvasPixelWidth) = CFSTR("CanvasPixelWidth");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyGIFFrameInfoArray) = CFSTR("FrameInfo");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSCanvasPixelHeight) = CFSTR("CanvasPixelHeight");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSCanvasPixelWidth) = CFSTR("CanvasPixelWidth");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSDelayTime) = CFSTR("DelayTime");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSDictionary) = CFSTR("{HEICS}");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSFrameInfoArray) = CFSTR("FrameInfo");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSLoopCount) = CFSTR("LoopCount");
CFStringRef const BACKPORT_IMPL(kCGImagePropertyHEICSUnclampedDelayTime) = CFSTR("UnclampedDelayTime");
