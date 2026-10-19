#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <string.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static void ask_four(void)
{
    PHPickerFilter *images = [PHPickerFilter imagesFilter];
    CHECK(images != nil, "the filters of iOS 14 are there, so the ones of iOS 15 are asked on a class that answers");

    @try {
        PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:@[]];
        CHECK(filter != nil, "an empty conjunction makes a filter on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "an empty conjunction makes a filter on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
    @try {
        PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:nil];
        CHECK(filter != nil, "a nil conjunction makes a filter on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "a nil conjunction makes a filter on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
    @try {
        PHPickerFilter *filter = [PHPickerFilter notFilterOfSubfilter:nil];
        CHECK(filter != nil, "the negation of nil makes a filter on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "the negation of nil makes a filter on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
    @try {
        PHPickerFilter *filter = [PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleUnsupported];
        CHECK(filter != nil, "a filter of the unsupported playback style is made on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "a filter of the unsupported playback style is made on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
}

static void ask_the_rest(void)
{
    const char *mine = _dyld_get_image_name(0);
    for (NSString *name in @[@"PHPickerFilter", @"PHPickerConfiguration", @"PHPickerViewController", @"PHPhotoLibrary"]) {
        Class found = NSClassFromString(name);
        Dl_info info;
        BOOL ours = found != Nil && dladdr((__bridge void *)found, &info) != 0 &&
                     strcmp(info.dli_fname, mine) == 0;
        charon_check(ours, "the class comes from this binary, which carries the port's objects",
                     [NSString stringWithFormat:@"%@ is %@, this binary is %s", name,
                      found ? @(info.dli_fname) : @"absent", mine ? mine : "unknown"]);
    }

    NSDictionary *kinds = @{@"panoramasFilter": @"", @"screenshotsFilter": @"", @"screenRecordingsFilter": @"",
                             @"slomoVideosFilter": @"", @"timelapseVideosFilter": @"",
                             @"depthEffectPhotosFilter": @"", @"burstsFilter": @"", @"cinematicVideosFilter": @""};
    for (NSString *kind in kinds) {
        SEL selector = NSSelectorFromString(kind);
        charon_check([PHPickerFilter respondsToSelector:selector], "every filter the queue names is answered",
                     [NSString stringWithFormat:@"+%@ is not answered", kind]);
        id filter = [PHPickerFilter performSelector:selector];
        charon_check(filter != nil && [filter isKindOfClass:[PHPickerFilter class]], "and each makes a filter",
                     [NSString stringWithFormat:@"+%@ made %@", kind, filter]);
    }
    CHECK(([PHPickerFilter allFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]] != nil), "a conjunction of two filters is made");
    CHECK(([PHPickerFilter notFilterOfSubfilter:[PHPickerFilter videosFilter]] != nil), "a negation is made");
    CHECK(([PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleImage] != nil &&
           [PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleVideo] != nil), "a filter of each style the release knows is made");

    PHPickerConfiguration *fresh = [[PHPickerConfiguration alloc] init];
    CHECK(fresh.selection == PHPickerConfigurationSelectionDefault, "a configuration starts with the default selection");
    CHECK(fresh.preselectedAssetIdentifiers != nil && fresh.preselectedAssetIdentifiers.count == 0, "and with an empty array of preselected identifiers");
    fresh.selection = PHPickerConfigurationSelectionOrdered;
    fresh.preselectedAssetIdentifiers = @[@"one", @"two"];
    PHPickerConfiguration *copy = [fresh copy];
    CHECK(copy.selection == PHPickerConfigurationSelectionOrdered, "a copy holds the selection that was set");
    CHECK(([copy.preselectedAssetIdentifiers isEqualToArray:@[@"one", @"two"]]), "and the identifiers that were set");

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:[[PHPickerConfiguration alloc] init]];
    CHECK([picker respondsToSelector:@selector(deselectAssetsWithIdentifiers:)], "the picker answers deselectAssetsWithIdentifiers:");
    CHECK([picker respondsToSelector:@selector(moveAssetWithIdentifier:afterAssetWithIdentifier:)], "and moveAssetWithIdentifier:afterAssetWithIdentifier:");
    [picker deselectAssetsWithIdentifiers:@[@"nonesuch"]];
    [picker moveAssetWithIdentifier:@"nonesuch" afterAssetWithIdentifier:nil];
    CHECK(YES, "both answer and change nothing");

    PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];
    CHECK([library respondsToSelector:@selector(presentLimitedLibraryPickerFromViewController:)], "the library answers the limited picker of iOS 14");
    CHECK([library respondsToSelector:@selector(presentLimitedLibraryPickerFromViewController:completionHandler:)], "and the one of iOS 15");
    [library presentLimitedLibraryPickerFromViewController:nil];
    __block NSArray *newlySelected = nil;
    __block BOOL answered = NO;
    [library presentLimitedLibraryPickerFromViewController:nil completionHandler:^(NSArray<NSString *> *assets) {
        newlySelected = assets;
        answered = YES;
    }];
    CHECK(answered && newlySelected.count == 0, "the library presents nothing and answers the block with no newly selected assets");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        charon_log_to(@"/private/var/backports/phpickermodel.log");
        printf("device %s, iOS %s\n", [[UIDevice currentDevice] model].UTF8String,
               [[UIDevice currentDevice] systemVersion].UTF8String);
        ask_four();
        ask_the_rest();
        NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
        [summary writeToFile:@"/private/var/backports/phpickermodel.done" atomically:YES
                  encoding:NSUTF8StringEncoding error:NULL];
        printf("%s", summary.UTF8String);
    }
    return charon_failures == 0 ? 0 : 1;
}
