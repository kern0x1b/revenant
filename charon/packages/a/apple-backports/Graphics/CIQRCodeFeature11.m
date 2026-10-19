// CIQRCodeFeature's symbolDescriptor, which iOS 11 added (CIFeature.h: NS_AVAILABLE(10_13, 11_0)).
//
// This is a category and not a member of CIFeature8.m, the way the house carries a member a later release
// added: the 8.0 object has no storage for it, and the 11.0 split is the only file that names the selector.
//
// The port makes no QR feature with a descriptor. The descriptor is the symbol's codewords after error
// correction, and the decoder that would read them is not in the port (facts/CoreImage/Features.md), so every
// feature the port makes answers nil. A feature a host detector makes carries a CIQRCodeDescriptor; that
// difference is the open item in the facts file, not something this file measures.

#import <CoreImage/CoreImage.h>

@implementation CIQRCodeFeature (CharonSymbolDescriptor)

- (CIQRCodeDescriptor *)symbolDescriptor
{
    return nil;
}

@end
