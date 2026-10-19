#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSTextList (CharonInit16)

- (instancetype)initWithMarkerFormat:(NSTextListMarkerFormat)markerFormat options:(NSTextListOptions)options startingItemNumber:(NSInteger)startingItemNumber
{
    if ((self = [self initWithMarkerFormat:markerFormat options:options]))
        self.startingItemNumber = startingItemNumber;
    return self;
}

@end
