#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
// The two methods below are declared by PHPickerViewController's own @interface, and its primary
// implementation is PHPickerViewController14.m, which is iOS 14.0's object and must not carry a
// 16.0 name. Clang's note that a category implements a method its primary class also declares is
// that arrangement, silenced for the reason PHPickerFilter15.m gives.

// The two methods of iOS 16 that change a picker's own selection, on the class the 14.0 object
// implements, so a category and not the class itself: an object carries the API of one release only.
//
// Both are the case the header itself names. Each says it does nothing when the identifiers given are
// missing or unselected, or when photoLibrary is not in the configuration, and on this port
// the last of those three is always true and the middle one always is too:
//
//   - the configuration of this port never names a photo library. -initWithPhotoLibrary: takes one
//     and does not keep it (PHPickerConfiguration14.m:21), because iOS 6's library is not an
//     application's own to name, and -[PHPickerResult assetIdentifier] is nil for the same reason;
//   - the picker holds no selection to change. -[UIImagePickerController imagePickerController:
//     didFinishPickingMediaWithInfo:] is answered at once, with the one item the release's picker
//     chose, and the delegate is called with it (PHPickerViewController14.m:132), so what the user
//     had chosen is the delegate call and not a state the picker keeps.
//
// So the arguments are read and nothing is changed, which is the answer and not a stub: the state
// the two calls would change does not exist on this port, and the header says what a call does when
// it does not. An invalid or unknown identifier is in the same case, and is not answered separately.
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
