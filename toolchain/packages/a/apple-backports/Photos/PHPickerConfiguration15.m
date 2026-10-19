#import "RevenantPhotosPicker.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

static const void *revenant_selection_key = &revenant_selection_key;
static const void *revenant_preselected_key = &revenant_preselected_key;

@implementation PHPickerConfiguration (RevenantSelection15)

- (PHPickerConfigurationSelection)selection
{
    NSNumber *value = objc_getAssociatedObject(self, revenant_selection_key);
    return (PHPickerConfigurationSelection)(value ? value.integerValue : PHPickerConfigurationSelectionDefault);
}

- (void)setSelection:(PHPickerConfigurationSelection)selection
{
    objc_setAssociatedObject(self, revenant_selection_key, @(selection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSString *> *)preselectedAssetIdentifiers
{
    return objc_getAssociatedObject(self, revenant_preselected_key) ?: @[];
}

- (void)setPreselectedAssetIdentifiers:(NSArray<NSString *> *)preselectedAssetIdentifiers
{
    objc_setAssociatedObject(self, revenant_preselected_key, [preselectedAssetIdentifiers copy] ?: @[],
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
