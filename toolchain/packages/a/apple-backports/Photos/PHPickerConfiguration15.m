#import "CharonPhotosPicker.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

static const void *charon_selection_key = &charon_selection_key;
static const void *charon_preselected_key = &charon_preselected_key;

@implementation PHPickerConfiguration (CharonSelection15)

- (PHPickerConfigurationSelection)selection
{
    NSNumber *value = objc_getAssociatedObject(self, charon_selection_key);
    return (PHPickerConfigurationSelection)(value ? value.integerValue : PHPickerConfigurationSelectionDefault);
}

- (void)setSelection:(PHPickerConfigurationSelection)selection
{
    objc_setAssociatedObject(self, charon_selection_key, @(selection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSString *> *)preselectedAssetIdentifiers
{
    return objc_getAssociatedObject(self, charon_preselected_key) ?: @[];
}

- (void)setPreselectedAssetIdentifiers:(NSArray<NSString *> *)preselectedAssetIdentifiers
{
    objc_setAssociatedObject(self, charon_preselected_key, [preselectedAssetIdentifiers copy] ?: @[],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)copyWithZone:(NSZone *)zone
{
    PHPickerConfiguration *copy = [[PHPickerConfiguration allocWithZone:zone] init];
    copy.preferredAssetRepresentationMode = self.preferredAssetRepresentationMode;
    copy.selectionLimit = self.selectionLimit;
    copy.filter = self.filter;
    copy.selection = self.selection;
    copy.preselectedAssetIdentifiers = self.preselectedAssetIdentifiers;
    return copy;
}

@end
