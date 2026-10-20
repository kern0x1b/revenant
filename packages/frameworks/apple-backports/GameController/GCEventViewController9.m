#import <GameController/GameController.h>
#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation GCEventViewController {
    BOOL _controllerUserInteractionEnabled;
}

- (BOOL)controllerUserInteractionEnabled
{
    return _controllerUserInteractionEnabled;
}

- (void)setControllerUserInteractionEnabled:(BOOL)enabled
{
    _controllerUserInteractionEnabled = enabled;
}

@end
