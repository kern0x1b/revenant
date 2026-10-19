#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

@implementation CPAlertAction (CharonCarPlay160)

- (instancetype)initWithTitle:(NSString *)title
                        color:(UIColor *)color
                      handler:(CPAlertActionHandler)handler
{
    self = [self initWithTitle:title style:CPAlertActionStyleDefault handler:handler];
    if (self) {
        [self charon_setColor:color];
    }
    return self;
}

@end
