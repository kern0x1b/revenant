#if defined(REVENANT_HOST_BUILD)
#define WKSnapshotConfiguration WKSnapshotConfigurationRevenant
#define WKDownload WKDownloadRevenant
#define WKOpenPanelParameters WKOpenPanelParametersRevenant
#define WKWindowFeatures WKWindowFeaturesRevenant
#endif

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>

static int reported(int value)
{
#ifdef WEBKIT_VALUES_NEGATIVE_CONTROL
    return !value;
#else
    return value;
#endif
}

static void print_shared(void)
{
    WKSnapshotConfiguration *configuration = [[WKSnapshotConfiguration alloc] init];
    printf("snapshot rect is null: %d\n", CGRectIsNull(configuration.rect));
    printf("snapshot after screen updates: %d\n", reported(configuration.afterScreenUpdates));
    printf("snapshot width is nil: %d\n", configuration.snapshotWidth == nil);
    WKSnapshotConfiguration *copy = [configuration copy];
    printf("snapshot copy after screen updates: %d\n", copy.afterScreenUpdates);
}

#ifdef REVENANT_BACKPORT
static void print_engine(void)
{
    WKDownload *download = [[WKDownload alloc] init];
    printf("engine download original request nil: %d\n", download.originalRequest == nil);
    printf("engine download web view nil: %d\n", download.webView == nil);
    printf("engine download user initiated: %d\n", download.userInitiated);
    printf("engine download originating frame nil: %d\n", download.originatingFrame == nil);
    printf("engine download progress nil: %d\n", [download progress] == nil);
    __block int noResumeData = -1;
    [download cancel:^(NSData *resumeData) {
        noResumeData = resumeData == nil;
    }];
    printf("engine download cancel reports no resume data: %d\n", noResumeData);

    WKOpenPanelParameters *panel = [[WKOpenPanelParameters alloc] init];
    printf("engine open panel multiple selection: %d\n", panel.allowsMultipleSelection);
    printf("engine open panel directories: %d\n", panel.allowsDirectories);

    WKWindowFeatures *features = [[WKWindowFeatures alloc] init];
    printf("engine window features unset: %d\n",
           features.menuBarVisibility == nil && features.statusBarVisibility == nil && features.toolbarsVisibility == nil &&
           features.allowsResizing == nil && features.x == nil && features.y == nil && features.width == nil &&
           features.height == nil);
}
#endif

int main(void)
{
    @autoreleasepool {
        print_shared();
#ifdef REVENANT_BACKPORT
        print_engine();
#endif
    }
    return 0;
}
