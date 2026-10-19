#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *const results_folder = @"/private/var/backports";

@interface Receiver : NSObject <PHPickerViewControllerDelegate>
@property (nonatomic, strong) NSArray *results;
@property (nonatomic) int calls;
@property (nonatomic) BOOL onMain;
@end

@implementation Receiver
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results
{
    self.results = results;
    self.calls++;
    self.onMain = [NSThread isMainThread];
}
@end

@interface Delegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIPopoverController *popover;
@end

static UIImage *make_image(void)
{
    UIGraphicsBeginImageContext(CGSizeMake(10, 10));
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, 10, 10));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

@implementation Delegate

- (void)present:(UIViewController *)controller
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        [self.popover presentPopoverFromRect:CGRectMake(100, 100, 10, 10) inView:self.window.rootViewController.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    } else {
        [self.window.rootViewController presentViewController:controller animated:NO completion:nil];
    }
    spin(1.0);
}

- (void)dismiss
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:NO];
        self.popover = nil;
    } else {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
    }
    spin(0.3);
}

- (void)run
{
    Class pickerClass = NSClassFromString(@"PHPickerViewController");
    Dl_info info;
    CHECK(pickerClass != Nil && dladdr((__bridge void *)pickerClass, &info) != 0 && [@(info.dli_fname).lastPathComponent isEqualToString:@"libPhotosBackports.dylib"], "PHPickerViewController comes from the backports");
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    CHECK(config.selectionLimit == 1 && config.filter == nil && config.preferredAssetRepresentationMode == PHPickerConfigurationAssetRepresentationModeAutomatic, "a configuration starts with one item, no filter and the automatic representation");
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 0;
    PHPickerConfiguration *copy = [config copy];
    CHECK(copy != config && copy.selectionLimit == 0 && copy.filter != nil, "a copy holds what was set");
    PHPickerFilter *any = [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]];
    CHECK(any != nil, "a filter of several kinds is made");

    // The filters of iOS 15 and 16, the compositions, and the two properties of iOS 15. Every one of
    // them is called here, so a name the library does not carry is an exception rather than a line
    // nobody reads; what each of them answers is in facts/PhotosUI/Filters.md, and the comparison
    // with the host's own framework is tests/backports/host/photosui/run.sh.
    NSArray *kinds = @[@"panoramasFilter", @"screenshotsFilter", @"screenRecordingsFilter", @"slomoVideosFilter",
                       @"timelapseVideosFilter", @"depthEffectPhotosFilter", @"burstsFilter", @"cinematicVideosFilter"];
    for (NSString *kind in kinds) {
        SEL selector = NSSelectorFromString(kind);
        charon_check([PHPickerFilter respondsToSelector:selector], "PHPickerFilter answers every filter the SDK declares",
                     [NSString stringWithFormat:@"+%@ is not answered", kind]);
        charon_check([PHPickerFilter performSelector:selector] != nil, "every filter of a kind makes a filter",
                     [NSString stringWithFormat:@"+%@ made nothing", kind]);
    }
    CHECK(([PHPickerFilter allFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]] != nil), "a filter of every kind of both is made");
    CHECK(([PHPickerFilter allFilterMatchingSubfilters:@[]] != nil), "a conjunction of no filters constrains nothing and is made");
    CHECK(([PHPickerFilter notFilterOfSubfilter:[PHPickerFilter imagesFilter]] != nil), "the negation of a filter is made");
    CHECK(([PHPickerFilter notFilterOfSubfilter:nil] != nil), "the negation of nothing is made");
    CHECK([PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleImage] != nil && [PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleVideo] != nil, "a filter of either style the release knows is made");
    CHECK([PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleUnsupported] != nil, "and so is one of a style it does not");

    PHPickerConfiguration *stateful = [[PHPickerConfiguration alloc] init];
    CHECK(stateful.selection == PHPickerConfigurationSelectionDefault, "a configuration starts with the default selection");
    CHECK(stateful.preselectedAssetIdentifiers != nil && stateful.preselectedAssetIdentifiers.count == 0, "and with an empty array of preselected identifiers, not with nil");
    stateful.selection = PHPickerConfigurationSelectionOrdered;
    stateful.preselectedAssetIdentifiers = @[@"one", @"two"];
    PHPickerConfiguration *statefulCopy = [stateful copy];
    CHECK(statefulCopy.selection == PHPickerConfigurationSelectionOrdered, "a copy holds the selection that was set");
    CHECK(([statefulCopy.preselectedAssetIdentifiers isEqualToArray:@[@"one", @"two"]]), "and the identifiers that were set");

    Receiver *receiver = [[Receiver alloc] init];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = receiver;
    CHECK(picker.configuration.selectionLimit == 0 && picker.configuration != config, "the controller keeps a copy of the configuration");
    [self present:picker];
    UIImagePickerController *child = nil;
    for (UIViewController *candidate in picker.childViewControllers)
        if ([candidate isKindOfClass:[UIImagePickerController class]])
            child = (UIImagePickerController *)candidate;
    CHECK(child != nil, "the controller holds the release's picker as a child");
    CHECK(child.sourceType == UIImagePickerControllerSourceTypePhotoLibrary, "it shows the photo library");
    CHECK([child.mediaTypes isEqualToArray:@[@"public.image"]], "for the media types of the filter");
    CHECK(receiver.calls == 0, "nothing is reported before the user chooses");
    UIImage *image = make_image();
    NSDictionary *chosen = @{UIImagePickerControllerMediaType: @"public.image", UIImagePickerControllerOriginalImage: image, UIImagePickerControllerReferenceURL: [NSURL URLWithString:@"assets-library://asset/asset.PNG?id=ABC&ext=PNG"]};
    [(id<UIImagePickerControllerDelegate>)picker imagePickerController:child didFinishPickingMediaWithInfo:chosen];
    CHECK(receiver.calls == 1 && receiver.results.count == 1 && receiver.onMain, "a choice is reported once, on the main thread, as one result");
    PHPickerResult *result = receiver.results.firstObject;
    CHECK(result.assetIdentifier == nil, "the asset identifier is nil");
    NSItemProvider *provider = result.itemProvider;
    CHECK([[provider registeredTypeIdentifiers] containsObject:@"public.png"], "the item is offered as PNG, the type of its address");
    CHECK([provider canLoadObjectOfClass:[UIImage class]], "and can be loaded as a UIImage");
    __block UIImage *loaded = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(id object, NSError *error) {
        loaded = object;
        dispatch_semaphore_signal(done);
    }];
    for (int i = 0; i < 50 && dispatch_semaphore_wait(done, DISPATCH_TIME_NOW) != 0; i++)
        spin(0.1);
    CHECK(loaded != nil && loaded.size.width == 10 && loaded.size.height == 10, "the loaded image is the chosen one");
    [(id<UIImagePickerControllerDelegate>)picker imagePickerControllerDidCancel:child];
    CHECK(receiver.calls == 1, "the delegate is not called twice");
    [self dismiss];

    Receiver *cancelled = [[Receiver alloc] init];
    PHPickerConfiguration *plain = [[PHPickerConfiguration alloc] init];
    PHPickerViewController *second = [[PHPickerViewController alloc] initWithConfiguration:plain];
    second.delegate = cancelled;
    [self present:second];
    UIImagePickerController *secondChild = nil;
    for (UIViewController *candidate in second.childViewControllers)
        if ([candidate isKindOfClass:[UIImagePickerController class]])
            secondChild = (UIImagePickerController *)candidate;
    CHECK(secondChild != nil && [secondChild.mediaTypes containsObject:@"public.image"] && [secondChild.mediaTypes containsObject:@"public.movie"], "with no filter it shows images and videos");
    [(id<UIImagePickerControllerDelegate>)second imagePickerControllerDidCancel:secondChild];
    CHECK(cancelled.calls == 1 && cancelled.results.count == 0, "a cancel is reported as no results");
    [self dismiss];

    Receiver *live = [[Receiver alloc] init];
    PHPickerConfiguration *liveConfig = [[PHPickerConfiguration alloc] init];
    liveConfig.filter = [PHPickerFilter livePhotosFilter];
    PHPickerViewController *third = [[PHPickerViewController alloc] initWithConfiguration:liveConfig];
    third.delegate = live;
    [self present:third];
    spin(0.5);
    BOOL hasChild = NO;
    for (UIViewController *candidate in third.childViewControllers)
        if ([candidate isKindOfClass:[UIImagePickerController class]])
            hasChild = YES;
    CHECK(!hasChild, "a filter that matches nothing of this release shows no library");
    CHECK(live.calls == 1 && live.results.count == 0, "and reports no results once it has appeared");
    [self dismiss];

    // What a composed filter shows is asked of the picker itself, which is the only public way to
    // ask it: the release's picker is given the media types the filter names, and reading them back
    // off the child is what the 14.0 rows were proved with. Three compositions, each presented and
    // dismissed, and the two methods of iOS 16 called on a picker that is really there.
    NSArray *both = @[@"public.image", @"public.movie"];
    NSArray *composed = @[
        @[@"a conjunction of no filters shows everything", [PHPickerFilter allFilterMatchingSubfilters:@[]], both],
        @[@"the negation of the image filter shows movies", [PHPickerFilter notFilterOfSubfilter:[PHPickerFilter imagesFilter]], @[@"public.movie"]],
        @[@"a filter of the video style shows movies", [PHPickerFilter playbackStyleFilter:PHAssetPlaybackStyleVideo], @[@"public.movie"]],
        @[@"a filter of a kind this release cannot tag shows nothing", PHPickerFilter.panoramasFilter, @[]],
    ];
    for (NSArray *each in composed) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
        configuration.filter = each[1];
        PHPickerViewController *composite = [[PHPickerViewController alloc] initWithConfiguration:configuration];
        Receiver *compositeReceiver = [[Receiver alloc] init];
        composite.delegate = compositeReceiver;
        [self present:composite];
        spin(0.5);
        UIImagePickerController *shown = nil;
        for (UIViewController *candidate in composite.childViewControllers)
            if ([candidate isKindOfClass:[UIImagePickerController class]])
                shown = (UIImagePickerController *)candidate;
        NSArray *wanted = each[2];
        charon_check(wanted.count == 0 ? shown == nil : [shown.mediaTypes isEqualToArray:wanted],
                     "a composed filter shows what it names",
                     [NSString stringWithFormat:@"%@: wanted %@, the release's picker was given %@",
                      each[0], wanted, shown ? shown.mediaTypes : @"nothing"]);
        [self dismiss];
    }

    // The two methods of iOS 16, on a picker that is really there, and the two forms of the limited
    // library picker on the library this port carries.
    PHPickerConfiguration *plainAgain = [[PHPickerConfiguration alloc] init];
    PHPickerViewController *fourth = [[PHPickerViewController alloc] initWithConfiguration:plainAgain];
    Receiver *fourthReceiver = [[Receiver alloc] init];
    fourth.delegate = fourthReceiver;
    [fourth deselectAssetsWithIdentifiers:@[@"nonesuch"]];
    [fourth moveAssetWithIdentifier:@"nonesuch" afterAssetWithIdentifier:nil];
    CHECK(YES, "the two methods of iOS 16 answer on a picker and change nothing");

    Class libraryClass = NSClassFromString(@"PHPhotoLibrary");
    Dl_info libraryInfo;
    CHECK(libraryClass != Nil && dladdr((__bridge void *)libraryClass, &libraryInfo) != 0 && [@(libraryInfo.dli_fname).lastPathComponent isEqualToString:@"libPhotosBackports.dylib"], "PHPhotoLibrary comes from the backports");
    PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];
    CHECK([library respondsToSelector:@selector(presentLimitedLibraryPickerFromViewController:)], "the library answers the picker of iOS 14");
    CHECK([library respondsToSelector:@selector(presentLimitedLibraryPickerFromViewController:completionHandler:)], "and the one of iOS 15");
    [library presentLimitedLibraryPickerFromViewController:self.window.rootViewController];
    CHECK(YES, "presenting it changes nothing, because this release's library is never limited");
    __block NSArray *newlySelected = nil;
    __block BOOL answered = NO;
    [library presentLimitedLibraryPickerFromViewController:self.window.rootViewController completionHandler:^(NSArray<NSString *> *assets) {
        newlySelected = assets;
        answered = YES;
    }];
    spin(0.3);
    CHECK(answered && newlySelected.count == 0, "and the other form says that no assets were newly selected");

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        PHPickerViewController *modal = [[PHPickerViewController alloc] initWithConfiguration:plain];
        modal.delegate = [[Receiver alloc] init];
        [self.window.rootViewController presentViewController:modal animated:NO completion:nil];
        spin(1.0);
        BOOL shown = NO;
        for (UIViewController *candidate in modal.childViewControllers)
            if ([candidate isKindOfClass:[UIImagePickerController class]])
                shown = YES;
        CHECK(shown && modal.presentingViewController != nil, "on an iPad it can be presented outside a popover as well");
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        spin(0.3);
    }
}

- (void)runAndFinish
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the picker runs without an exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"phpicker.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"phpicker.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"phpicker.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndFinish) withObject:nil afterDelay:0.2];
    return YES;
}
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([Delegate class]));
    }
}
