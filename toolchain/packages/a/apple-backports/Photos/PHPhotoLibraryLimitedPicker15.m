#import "RevenantPhotosPicker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

@implementation PHPhotoLibrary (RevenantLimitedLibrary15)

- (void)presentLimitedLibraryPickerFromViewController:(UIViewController *)controller
                                   completionHandler:(void (^)(NSArray<NSString *> *))completionHandler
{
    (void)controller;
    if (completionHandler)
        completionHandler(@[]);
}

@end
