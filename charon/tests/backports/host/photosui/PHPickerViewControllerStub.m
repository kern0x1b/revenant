// The class of the 14.0 object, in the four lines an application needs to make one, so that the
// category of iOS 16 in PHPickerViewController16.m has a class to attach to and a picker to be asked
// about. The host's binary has the real class from the framework and this file is not in it.
//
// PHPickerViewController14.m is deliberately not compiled here: it is UIKit's UIViewController and
// this harness has no UIKit. The two methods the differential asks about are the category's and not
// this file's, and no answer this file gives is compared - the only line compared is whether the two
// methods of iOS 16 raise.
#import "PhotosUI/PhotosUI.h"

@implementation PHPickerViewController {
    PHPickerConfiguration *_configuration;
}

- (instancetype)initWithConfiguration:(PHPickerConfiguration *)configuration
{
    if ((self = [super init]))
        _configuration = [configuration copy];
    return self;
}

- (PHPickerConfiguration *)configuration
{
    return [_configuration copy];
}

@end
