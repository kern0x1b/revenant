#import <CarPlay/CarPlay.h>
#import "RevenantCarPlaySessionConfiguration.h"

@implementation CPSessionConfiguration (RevenantContentStyle13)

- (CPContentStyle)contentStyle
{
    return [self revenant_contentStyle];
}

@end
