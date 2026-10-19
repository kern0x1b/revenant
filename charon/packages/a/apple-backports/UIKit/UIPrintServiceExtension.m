#import <UIKit/UIKit.h>

// The base class of a print service extension. The system asks an extension's principal object for printer
// destinations on iOS 14.5 and later; this release has no extension system, so nothing asks, and the base class
// answers no destinations, as the host does for a print info it is given (facts/UIKit/UIPrintServiceExtension.md).

@implementation UIPrintServiceExtension

- (NSArray *)printerDestinationsForPrintInfo:(UIPrintInfo *)printInfo
{
    return [NSArray array];
}

@end
