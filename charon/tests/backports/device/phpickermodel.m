// The PhotosUI model questions, asked on the device, as a command-line test.
//
// phpicker.m is an application, because it presents a picker and reads the media types off the
// release's own UIImagePickerController. This one asks the same family the four questions the
// Mac Catalyst host will not answer at all - an empty array and a nil one to
// +[PHPickerFilter allFilterMatchingSubfilters:], a nil one to +notFilterOfSubfilter:, and
// PHAssetPlaybackStyleUnsupported to +playbackStyleFilter: - and it is a command-line test for one
// reason: this device has no /private/var/tmp/sblaunch, and a bundle SpringBoard will not start is
// a test that measures nothing. A command-line test needs no window server, so the device answers.
//
// The port's own objects are linked into this binary, exactly as the package links them, attach.c
// included: the filters of iOS 15 and 16 are categories, and without the attach constructor they
// are linked and never installed, which would make every question below answer "unrecognized
// selector" and look like a defect in the port.
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

// The four, asked one at a time and each behind its own guard, because the question is which of
// them the device answers and which kills the process - a test that lets one of them end the run
// cannot report the rest.
static void ask_four(void)
{
    PHPickerFilter *images = [PHPickerFilter imagesFilter];
    CHECK(images != nil, "the filters of iOS 14 are there, so the ones of iOS 15 are asked on a class that answers");

    // 1. an empty array
    @try {
        PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:@[]];
        CHECK(filter != nil, "an empty conjunction makes a filter on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "an empty conjunction makes a filter on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
    // 2. a nil array
    @try {
        PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:nil];
        CHECK(filter != nil, "a nil conjunction makes a filter on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "a nil conjunction makes a filter on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
    // 3. the negation of nil
    @try {
        PHPickerFilter *filter = [PHPickerFilter notFilterOfSubfilter:nil];
        CHECK(filter != nil, "the negation of nil makes a filter on the device");
    } @catch (NSException *exception) {
        charon_check(NO, "the negation of nil makes a filter on the device",
                     [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
    }
    // 4. the unsupported playback style
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
    // Where the classes come from: this binary, which carries the port's own objects, and not a
    // system framework - the release has no Photos or PhotosUI of its own at this version. The image
    // is read as the main executable's own rather than as a name written here, because a name
    // written here is wrong the moment the rule builds a library instead of an executable, which is
    // what the first version of this check did and what made it report four failures on a run where
    // every answer was right.
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

    // Every filter the queue names answers, and the compositions answer over the inputs the header
    // allows. What each answers is facts/PhotosUI/Filters.md; this is the call test for the names.
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

    // The configuration: its defaults, and what a copy holds.
    PHPickerConfiguration *fresh = [[PHPickerConfiguration alloc] init];
    CHECK(fresh.selection == PHPickerConfigurationSelectionDefault, "a configuration starts with the default selection");
    CHECK(fresh.preselectedAssetIdentifiers != nil && fresh.preselectedAssetIdentifiers.count == 0, "and with an empty array of preselected identifiers");
    fresh.selection = PHPickerConfigurationSelectionOrdered;
    fresh.preselectedAssetIdentifiers = @[@"one", @"two"];
    PHPickerConfiguration *copy = [fresh copy];
    CHECK(copy.selection == PHPickerConfigurationSelectionOrdered, "a copy holds the selection that was set");
    CHECK(([copy.preselectedAssetIdentifiers isEqualToArray:@[@"one", @"two"]]), "and the identifiers that were set");

    // The two methods of iOS 16, and the two forms of the limited library picker: the names answer
    // and nothing raises. What they do is facts/PhotosUI/PickerState.md and LimitedLibrary.md.
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
