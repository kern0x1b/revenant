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
