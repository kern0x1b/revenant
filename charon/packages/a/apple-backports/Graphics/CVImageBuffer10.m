// The colour space a set of image buffer attachments describes, which arrived in iOS 10.
//
// The header scopes the answer to two cases: an ICC profile under kCVImageBufferICCProfileKey, or
// the three code points kCVImageBufferColorPrimariesKey, kCVImageBufferTransferFunctionKey and
// kCVImageBufferYCbCrMatrixKey. Measured against the host's own CoreVideo (macOS 27) over nine
// dictionaries, of which the code-point triples are the four combinations the port's own names spell
// (ITU_R_709, ITU_R_2020, DCI_P3, and ITU_R_601 with SMPTE_ST_428_1) plus a nonsense triple and a
// partial one:
//
//   ICC profile present                      -> kCGColorSpaceSRGB
//   three code points, any combination       -> NULL
//   three code points and kCVImageBufferGammaLevelKey  -> NULL
//   ICC profile and three code points        -> kCGColorSpaceSRGB
//   nothing, or one unknown key              -> NULL
//
// So the profile is the case the release answers, and the code points are a case the release declines
// to answer from the attachments alone. This follows that: the profile becomes the colour space the
// profile says it is, and every other dictionary answers NULL, which is the header's own stated
// answer for a dictionary that does not carry the information required.
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>

CGColorSpaceRef CVImageBufferCreateColorSpaceFromAttachments(CFDictionaryRef attachments)
{
    if (!attachments) return NULL;
    CFTypeRef profile = CFDictionaryGetValue(attachments, kCVImageBufferICCProfileKey);
    if (!profile || CFGetTypeID(profile) != CFDataGetTypeID()) return NULL;
    return CGColorSpaceCreateWithICCData((CFDataRef)profile);
}
