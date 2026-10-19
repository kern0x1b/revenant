#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation PHPickerResult {
    NSItemProvider *_itemProvider;
}

- (instancetype)initWithCharonItemProvider:(NSItemProvider *)itemProvider
{
    if ((self = [super init]))
        _itemProvider = itemProvider;
    return self;
}

- (NSItemProvider *)itemProvider
{
    return _itemProvider;
}

- (NSString *)assetIdentifier
{
    return nil;
}

@end
