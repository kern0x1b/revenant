#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation PHPickerConfiguration {
    PHPickerConfigurationAssetRepresentationMode _preferredAssetRepresentationMode;
    NSInteger _selectionLimit;
    PHPickerFilter *_filter;
}

@dynamic selection, preselectedAssetIdentifiers;

- (instancetype)init
{
    if ((self = [super init]))
        _selectionLimit = 1;
    return self;
}

- (instancetype)initWithPhotoLibrary:(PHPhotoLibrary *)photoLibrary
{
    return [self init];
}

- (id)copyWithZone:(NSZone *)zone
{
    PHPickerConfiguration *copy = [[PHPickerConfiguration allocWithZone:zone] init];
    copy->_preferredAssetRepresentationMode = _preferredAssetRepresentationMode;
    copy->_selectionLimit = _selectionLimit;
    copy->_filter = [_filter copy];
    return copy;
}

- (PHPickerConfigurationAssetRepresentationMode)preferredAssetRepresentationMode
{
    return _preferredAssetRepresentationMode;
}

- (void)setPreferredAssetRepresentationMode:(PHPickerConfigurationAssetRepresentationMode)mode
{
    _preferredAssetRepresentationMode = mode;
}

- (NSInteger)selectionLimit
{
    return _selectionLimit;
}

- (void)setSelectionLimit:(NSInteger)limit
{
    _selectionLimit = limit;
}

- (PHPickerFilter *)filter
{
    return _filter;
}

- (void)setFilter:(PHPickerFilter *)filter
{
    _filter = [filter copy];
}

@end
