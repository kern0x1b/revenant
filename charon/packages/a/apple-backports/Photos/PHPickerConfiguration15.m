#import "CharonPhotosPicker.h"
#import <objc/runtime.h>

// The two properties of iOS 15, on the class the 14.0 object implements, which is why they are a
// category: an object carries the API of one release only, and PHPickerConfiguration14.m says so
// itself with its @dynamic selection, preselectedAssetIdentifiers. The two values are held beside
// the object rather than in it, the way CAMetalLayer+Timeout11.m holds the layer's own property of
// iOS 11, because a category cannot add an ivar to a class another object implements.
//
// The copy is the part that needs saying. -[PHPickerConfiguration copyWithZone:] in the 14.0 object
// builds a new configuration and carries the three properties of iOS 14 across, so a copy made
// before this file existed would drop the two of iOS 15 - and NSCopying is a conformance the class
// declares, and -[PHPickerViewController initWithConfiguration:] copies what it is given
// (PHPickerViewController14.m:20). The copy below therefore replaces that one, and it carries every
// property the class has through its own accessors, so it stays true as the class grows. Clang's
// note that a category is implementing a method its primary class also implements is that
// arrangement, and is silenced for the same reason as in PHPickerFilter15.m.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

static const void *charon_selection_key = &charon_selection_key;
static const void *charon_preselected_key = &charon_preselected_key;

@implementation PHPickerConfiguration (CharonSelection15)

// "The selection behavior of the picker. Default is PHPickerConfigurationSelectionDefault." The
// value is kept and read back, and the picker of this port delivers its one result when the user
// chooses, which is the behaviour of the default and of the ordered selection alike: a release
// picker chooses one item, so there is no order to keep and nothing to deliver continuously. The
// two cases of iOS 17, Continuous and ContinuousAndOrdered, are not in the 16.4 header this package
// compiles against and are not named here; a value outside the two the header knows is kept as
// given, the way selectionLimit keeps a limit the release cannot honour.
- (PHPickerConfigurationSelection)selection
{
    NSNumber *value = objc_getAssociatedObject(self, charon_selection_key);
    return (PHPickerConfigurationSelection)(value ? value.integerValue : PHPickerConfigurationSelectionDefault);
}

- (void)setSelection:(PHPickerConfigurationSelection)selection
{
    objc_setAssociatedObject(self, charon_selection_key, @(selection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// The local identifiers of the assets to preselect when the picker is presented; the default is an
// empty array, and the header's rule beside it says the array should be empty if selectionLimit
// is 1 or photoLibrary is not specified. The second half of that rule is always true on this port
// and the first is true of the configuration as it is built, so the value is kept and read back
// while the picker preselects nothing: -[PHPickerResult assetIdentifier] is nil whatever the
// configuration was made with (PHPickerResult14.m:21), so a preselected asset could not be
// recognized when the user chose it, and the header says the item providers of a preselected asset
// are empty anyway.
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
