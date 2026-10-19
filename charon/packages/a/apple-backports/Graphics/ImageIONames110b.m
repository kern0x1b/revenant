#import <ImageIO/ImageIO.h>

// kCGImagePropertyHEIFDictionary, on its own. The SDK annotates it IMAGEIO_AVAILABLE_STARTING(13.0, 16.0) and
// the rest of the 16.0 band lives in ImageIONames160.m, but the release's own caches export this symbol from
// iOS 11.0, so the object that defines it is a release-11.0 object: an object carries API that arrived in one
// release, and the gate places one by the release its caches show. Value {HEIF}, the same shape as the {TGA}
// and {WebP} of the 14.0 band; plain data, answered by the port itself.

extern CFStringRef const kCGImagePropertyHEIFDictionary;

CFStringRef const kCGImagePropertyHEIFDictionary = CFSTR("{HEIF}");
