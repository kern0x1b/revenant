// CarPlayAlertAction160.m - the 16.0 initialiser of CPAlertAction, in a 16.0 object of its own.
//
// CPAlertAction.h:53 declares
//     - (instancetype)initWithTitle:(NSString *)title color:(UIColor *)color handler:(CPAlertActionHandler)handler
//         API_AVAILABLE(ios(16.0))
// and it is the only CPAlertAction member of 16.0. The class is 12.0 and its @implementation is
// CarPlayTemplates12.m, so this is the same split CarPlayButtons16.m makes for CPButton and CPTextButton
// and CarPlayLane174.m/CarPlayLane18.m make for CPLane: an object holds API of exactly one release
// (modules/apple/backports.lua's releases_in, read by tools/release-split.lua), and this one holds 16.0.
//
// The header's own words are what this answers, and they are why it is not the same call as the 12.0
// initialiser. The header says the system decides whether the provided color meets contrast requirements,
// and falls back to its default when it does not. Font color is adjusted by the system to match this color, and
// alpha values are ignored. So the style is not an argument here - the action is the default one, and
// CPAlertAction.h:12 numbers CPAlertActionStyleDefault = 0, which is the value this passes.

#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

@implementation CPAlertAction (CharonCarPlay160)

- (instancetype)initWithTitle:(NSString *)title
                        color:(UIColor *)color
                      handler:(CPAlertActionHandler)handler
{
    // The header's own 12.0 initialiser with CPAlertActionStyleDefault, which is the header's own zero
    // (CPAlertAction.h:12) and the style the colour overload leaves the action in: this declaration takes
    // no style, so the action is the default one. The colour goes through the class's own seam because
    // CPAlertAction.h:60 declares it readonly, and a nil in stays nil, which is what `nullable` means.
    self = [self initWithTitle:title style:CPAlertActionStyleDefault handler:handler];
    if (self) {
        [self charon_setColor:color];
    }
    return self;
}

@end