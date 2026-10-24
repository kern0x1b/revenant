#import "../Foundation/check.h"
#import "RevenantPhotosImageSource.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);
        RevenantPhotosImageSource small = RevenantPhotosImageSourceForRequest(120, 150, 1024, YES, YES, YES, NO);
        revenant_check(small == (revenant_negative ? RevenantPhotosImageSourceFullResolution : RevenantPhotosImageSourceThumbnail),
                       "a small request uses the adequate thumbnail", @"another source was selected");
        revenant_check(RevenantPhotosImageSourceForRequest(300, 150, 1024, YES, YES, YES, NO) == RevenantPhotosImageSourceFullScreen,
                       "a larger request uses the adequate screen image", @"another source was selected");
        revenant_check(RevenantPhotosImageSourceForRequest(2048, 150, 1024, YES, YES, YES, NO) == RevenantPhotosImageSourceFullResolution,
                       "a request larger than the screen image uses full resolution", @"another source was selected");
        revenant_check(RevenantPhotosImageSourceForRequest(0, 150, 1024, YES, YES, YES, YES) == RevenantPhotosImageSourceFullResolution,
                       "a maximum request uses full resolution", @"another source was selected");
        revenant_check(RevenantPhotosImageSourceForRequest(300, 150, 0, YES, NO, NO, NO) == RevenantPhotosImageSourceThumbnail,
                       "an unavailable screen image falls back to the thumbnail", @"another source was selected");
        revenant_check(RevenantPhotosImageSourceForRequest(64, 0, 0, NO, NO, YES, NO) == RevenantPhotosImageSourceNone,
                       "a small request never falls back to full resolution", @"full resolution was selected");
    }
    return revenant_finish();
}
