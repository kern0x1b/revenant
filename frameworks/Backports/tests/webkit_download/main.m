#define WKDownload WKDownloadRevenant

#import <Foundation/Foundation.h>

@interface WKDownloadRevenant : NSObject
@property (nonatomic, weak) id delegate;
@property (nonatomic, readonly) NSURLRequest *originalRequest;
@property (nonatomic, readonly) NSProgress *progress;
+ (instancetype)revenant_downloadWithRequest:(NSURLRequest *)request webView:(id)webView;
+ (instancetype)revenant_resumeWithData:(NSData *)data webView:(id)webView;
- (void)revenant_start;
- (void)cancel:(void (^)(NSData *resumeData))completionHandler;
@end

@interface DownloadRecorder : NSObject
@property (nonatomic, strong) NSURL *destination;
@property (nonatomic, assign) int decisions;
@property (nonatomic, assign) int finishes;
@property (nonatomic, assign) int failures;
@property (nonatomic, assign) NSInteger failureCode;
@property (nonatomic, assign) BOOL failureHadResumeData;
@end

@implementation DownloadRecorder

- (void)download:(id)download decideDestinationUsingResponse:(id)response suggestedFilename:(NSString *)suggestedFilename completionHandler:(void (^)(NSURL *destination))completionHandler
{
    self.decisions++;
    completionHandler(self.destination);
}

- (void)downloadDidFinish:(id)download
{
    self.finishes++;
}

- (void)download:(id)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData
{
    self.failures++;
    self.failureCode = error.code;
    self.failureHadResumeData = resumeData != nil;
}

@end

static int reported(int value)
{
#ifdef WEBKIT_DOWNLOAD_NEGATIVE_CONTROL
    return !value;
#else
    return value;
#endif
}

static BOOL WaitFor(BOOL (^done)(void))
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done()) {
        if ([deadline timeIntervalSinceNow] < 0)
            return NO;
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return YES;
}

int main(void)
{
    @autoreleasepool {
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"revenant-download-%d", getpid()]];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];

        NSMutableData *payload = [NSMutableData dataWithLength:300000];
        uint8_t *bytes = payload.mutableBytes;
        for (NSUInteger index = 0; index < payload.length; index++)
            bytes[index] = (uint8_t)(index * 7);

        NSString *source = [directory stringByAppendingPathComponent:@"source.bin"];
        [payload writeToFile:source atomically:NO];
        NSURL *sourceURL = [NSURL fileURLWithPath:source];

        NSString *destination = [directory stringByAppendingPathComponent:@"destination.bin"];
        DownloadRecorder *recorder = [[DownloadRecorder alloc] init];
        recorder.destination = [NSURL fileURLWithPath:destination];
        WKDownloadRevenant *download = [WKDownloadRevenant revenant_downloadWithRequest:[NSURLRequest requestWithURL:sourceURL] webView:nil];
        download.delegate = recorder;
        [download revenant_start];
        BOOL completed = WaitFor(^BOOL{
            return recorder.finishes + recorder.failures > 0;
        });

        NSData *written = [NSData dataWithContentsOfFile:destination];
        printf("download finished in time: %d\n", reported(completed));
        printf("download bytes match: %d\n", reported([written isEqualToData:payload]));
        printf("download progress complete: %d\n",
               reported(download.progress.totalUnitCount == (int64_t)payload.length && download.progress.completedUnitCount == (int64_t)payload.length));
        printf("download finished once: %d\n", reported(recorder.finishes == 1 && recorder.failures == 0));

        DownloadRecorder *refused = [[DownloadRecorder alloc] init];
        WKDownloadRevenant *declined = [WKDownloadRevenant revenant_downloadWithRequest:[NSURLRequest requestWithURL:sourceURL] webView:nil];
        declined.delegate = refused;
        [declined revenant_start];
        WaitFor(^BOOL{
            return refused.decisions > 0;
        });
        NSDate *settled = [NSDate dateWithTimeIntervalSinceNow:1];
        while ([settled timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        printf("download without destination sends no failure: %d\n", reported(refused.failures == 0 && refused.finishes == 0));
        printf("download without destination writes nothing: %d\n", reported(refused.finishes == 0 && refused.decisions == 1));

        printf("download original request set: %d\n", reported([download.originalRequest.URL isEqual:sourceURL]));

        printf("resume data nil: %d\n", reported([WKDownloadRevenant revenant_resumeWithData:nil webView:nil] == nil));
        printf("resume data garbage: %d\n", reported([WKDownloadRevenant revenant_resumeWithData:[@"not a plist" dataUsingEncoding:NSUTF8StringEncoding] webView:nil] == nil));

        NSDictionary *zero = @{@"URL": sourceURL.absoluteString, @"Offset": @0, @"Path": destination};
        NSData *zeroData = [NSPropertyListSerialization dataWithPropertyList:zero format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        printf("resume data offset zero: %d\n", reported([WKDownloadRevenant revenant_resumeWithData:zeroData webView:nil] == nil));

        NSDictionary *state = @{@"URL": sourceURL.absoluteString, @"Offset": @5, @"Path": destination};
        NSData *stateData = [NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        WKDownloadRevenant *resumed = [WKDownloadRevenant revenant_resumeWithData:stateData webView:nil];
        printf("resume data range header: %d\n", reported([[resumed.originalRequest valueForHTTPHeaderField:@"Range"] isEqualToString:@"bytes=5-"]));
        printf("resume data url: %d\n", reported([resumed.originalRequest.URL isEqual:sourceURL]));

        [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    }
    return 0;
}
