#import <CoreGraphics/CoreGraphics.h>

// The PDF names that iOS 11.0 adds: the outline keys and the access permissions key. The strings are the ones the
// release's CoreGraphics holds, as the host's CoreGraphics does (facts/CoreGraphics/PDFNames.md).
const CFStringRef kCGPDFOutlineChildren = CFSTR("Children");
const CFStringRef kCGPDFOutlineDestination = CFSTR("Destination");
const CFStringRef kCGPDFOutlineDestinationRect = CFSTR("DestinationRect");
const CFStringRef kCGPDFOutlineTitle = CFSTR("Title");
const CFStringRef kCGPDFContextAccessPermissions = CFSTR("kCGPDFContextAccessPermissions");
