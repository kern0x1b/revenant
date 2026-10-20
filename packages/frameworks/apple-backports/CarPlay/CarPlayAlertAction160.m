#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlayTemplate.h"

@implementation CPAlertAction (RevenantCarPlay160)

- (instancetype)initWithTitle:(NSString *)title
                        color:(UIColor *)color
                      handler:(CPAlertActionHandler)handler
{
    self = [self initWithTitle:title style:CPAlertActionStyleDefault handler:handler];
    if (self) {
        [self revenant_setColor:color];
    }
    return self;
}

@end
