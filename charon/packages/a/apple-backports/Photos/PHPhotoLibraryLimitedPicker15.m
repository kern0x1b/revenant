#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

@implementation PHPhotoLibrary (CharonLimitedLibrary15)

- (void)presentLimitedLibraryPickerFromViewController:(UIViewController *)controller
                                   completionHandler:(void (^)(NSArray<NSString *> *))completionHandler
{
    (void)controller;
    if (completionHandler)
        completionHandler(@[]);
}

@end
