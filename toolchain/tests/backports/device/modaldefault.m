#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "check.h"

#ifndef MODALDEFAULT_LINKED_ON_13
#error build with -DMODALDEFAULT_LINKED_ON_13=1 (SDK 13 or later) or 0 (an older SDK in the load command)
#endif

static NSNumber *style_of(UIViewController *controller)
{
    return @(controller.modalPresentationStyle);
}

static NSKeyedUnarchiver *archive_with(void (^encode)(NSKeyedArchiver *archiver))
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    encode(archiver);
    [archiver finishEncoding];
    return [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
}

int main(void)
{
    @autoreleasepool {
        NSNumber *automatic = @(MODALDEFAULT_LINKED_ON_13 ? UIModalPresentationPageSheet : UIModalPresentationFullScreen);
        CHECK_EQUAL(style_of([[UIViewController alloc] init]), automatic, "init");
        CHECK_EQUAL(style_of([[UIViewController alloc] initWithNibName:nil bundle:nil]), automatic, "initWithNibName:bundle:");
        CHECK_EQUAL(style_of([[UINavigationController alloc] initWithRootViewController:[[UIViewController alloc] init]]), automatic, "a navigation controller");

        NSKeyedUnarchiver *bare = archive_with(^(NSKeyedArchiver *archiver) {
            [archiver encodeObject:@"value" forKey:@"other"];
        });
        CHECK_EQUAL(style_of([[UIViewController alloc] initWithCoder:bare]), automatic, "initWithCoder: of an archive without the key");
        NSKeyedUnarchiver *keyed = archive_with(^(NSKeyedArchiver *archiver) {
            [archiver encodeInteger:UIModalPresentationFormSheet forKey:@"UIModalPresentationStyle"];
        });
        CHECK_EQUAL(style_of([[UIViewController alloc] initWithCoder:keyed]), @(UIModalPresentationFormSheet), "initWithCoder: of an archive with the key");

        UIViewController *explicit = [[UIViewController alloc] init];
        explicit.modalPresentationStyle = UIModalPresentationFormSheet;
        CHECK_EQUAL(style_of(explicit), @(UIModalPresentationFormSheet), "a style set");
        explicit.modalPresentationStyle = UIModalPresentationFullScreen;
        CHECK_EQUAL(style_of(explicit), @(UIModalPresentationFullScreen), "full screen set");

#if MODALDEFAULT_LINKED_ON_13
        explicit.modalPresentationStyle = UIModalPresentationAutomatic;
        CHECK_EQUAL(style_of(explicit), @(UIModalPresentationPageSheet), "Automatic set");
        UIViewController *archived = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:[[UIViewController alloc] init]]];
        CHECK_EQUAL(style_of(archived), @(UIModalPresentationPageSheet), "Automatic archived and read back");

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        CHECK_EQUAL(style_of(picker), @(UIModalPresentationPageSheet), "an image picker of the photo library");
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;
            CHECK_EQUAL(style_of(picker), @(UIModalPresentationFullScreen), "an image picker of the camera");
        } else {
            printf("no camera here: the camera's full screen is not checked\n");
        }
        CHECK_EQUAL(style_of([[AVPlayerViewController alloc] init]), @(UIModalPresentationFullScreen), "a player view controller");
        CHECK_EQUAL(style_of([[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio]), @(UIModalPresentationPageSheet), "a media picker");
        CHECK_EQUAL(style_of([[UISplitViewController alloc] init]), @(UIModalPresentationCustom), "a split view controller");
#endif
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
