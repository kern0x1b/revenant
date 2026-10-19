#import <CarPlay/CarPlay.h>
#import "CharonCarPlaySessionConfiguration.h"

@implementation CPSessionConfiguration (CharonContentStyle13)

- (CPContentStyle)contentStyle
{
    return [self charon_contentStyle];
}

@end
