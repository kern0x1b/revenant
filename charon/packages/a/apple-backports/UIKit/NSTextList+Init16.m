#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSTextList (CharonInit16)

// The release's own list, through its own initializer and starting number.
- (instancetype)initWithMarkerFormat:(NSTextListMarkerFormat)markerFormat options:(NSTextListOptions)options startingItemNumber:(NSInteger)startingItemNumber
{
    if ((self = [self initWithMarkerFormat:markerFormat options:options]))
        self.startingItemNumber = startingItemNumber;
    return self;
}

@end
