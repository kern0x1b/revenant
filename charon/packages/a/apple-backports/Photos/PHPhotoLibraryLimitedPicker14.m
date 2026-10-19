#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// The limited library picker of iOS 14, as a category on the port's PHPhotoLibrary, which is the
// direction the SDK's own header takes: PHPhotoLibrary+PhotosUISupport.h declares this method in a
// category of the class, and the class itself is the port's (PHPhotoLibrary.m).
//
// Nothing is presented, and that is the whole answer rather than a gap in it. The header says that when
// the picker's access mode is not enabled for this application, nothing is done. On this port the
// application can never have enabled it. The release's
// library authorization is ALAuthorizationStatus, which has exactly four values - not determined,
// restricted, denied, authorized (ALAssetsLibrary.h:45-52) - and PHAuthorizationStatus is that enum
// plus the three cases of iOS 8 and the limited case of iOS 14 (PHPhotoLibrary.h:26).
// +[PHPhotoLibrary authorizationStatus] is the release's value cast (PHPhotoLibrary.m:34), so it
// answers one of the four and never PHAuthorizationStatusLimited: there is no limited selection on
// this port, and so nothing to present a picker for. The iOS 15 form of the same call, which also
// takes a completion handler, is in PHPhotoLibraryLimitedPicker15.m.
@implementation PHPhotoLibrary (CharonLimitedLibrary14)

- (void)presentLimitedLibraryPickerFromViewController:(UIViewController *)controller
{
    (void)controller;
}

@end
