#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// The same call with the block of iOS 15, and the one place in this family where the port answers
// something Apple leaves to the application. The reasoning is PHPhotoLibraryLimitedPicker14.m's: this
// port's library is never limited - ALAuthorizationStatus has four values and none of them is
// PHAuthorizationStatusLimited - so no user is asked and no picker is presented.
//
// The block is still called, with no newly selected assets, which is the truth about the selection:
// there is none. The header says the block "will be called upon the user finishing their selection"
// and does not say what happens when there is no selection to finish, and on this port the caller
// would otherwise wait for a user who is never asked - an application that presents the picker and
// dismisses itself from the block would sit there for good. So the port answers the block and says
// so in its row: the array of newly selected assets is empty because none were selected, and this is
// a choice the port made, not a reading of the header. The iOS 14 form has no block to call and
// returns without presenting.
@implementation PHPhotoLibrary (CharonLimitedLibrary15)

- (void)presentLimitedLibraryPickerFromViewController:(UIViewController *)controller
                                   completionHandler:(void (^)(NSArray<NSString *> *))completionHandler
{
    (void)controller;
    if (completionHandler)
        completionHandler(@[]);
}

@end
