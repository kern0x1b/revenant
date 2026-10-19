#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

@implementation PHPickerViewController (CharonSelection16)

- (void)deselectAssetsWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    (void)identifiers;
}

- (void)moveAssetWithIdentifier:(NSString *)identifier afterAssetWithIdentifier:(NSString *)afterIdentifier
{
    (void)identifier;
    (void)afterIdentifier;
}

@end
