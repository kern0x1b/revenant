#include "../revenant_impl.h"
#import <CoreText/CoreText.h>
#import <MobileCoreServices/MobileCoreServices.h>

const CFStringRef BACKPORT_IMPL(kCTRubyAnnotationAttributeName) = CFSTR("CTRubyAnnotation");
const CFStringRef BACKPORT_IMPL(kUTTypeAudioInterchangeFileFormat) = CFSTR("public.aiff-audio");
const CFStringRef BACKPORT_IMPL(kUTTypeFont) = CFSTR("public.font");
const CFStringRef BACKPORT_IMPL(kUTTypeUTF8TabSeparatedText) = CFSTR("public.utf8-tab-separated-values-text");
const CFStringRef BACKPORT_IMPL(kUTTypeWaveformAudio) = CFSTR("com.microsoft.waveform-audio");
const CFStringRef BACKPORT_IMPL(kUTTypeZipArchive) = CFSTR("public.zip-archive");
