#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

static void line(NSString *s)
{
    printf("%s\n", [s UTF8String]);
    fflush(stdout);
}

static void spin(double seconds)
{
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false);
}

static NSString *errText(NSError *error)
{
    if (!error) return @"nil";
    return [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code];
}

static NSString *plain(NSString *name)
{
    return [name hasPrefix:@"Revenant"] ? [name substringFromIndex:8] : name;
}

static NSString *className(id object)
{
    return object ? plain(NSStringFromClass([object class])) : @"(nil)";
}

static void tree(UIView *view, int depth)
{
    line([NSString stringWithFormat:@"%*s%@", depth * 2, "", className(view)]);
    for (UIView *child in view.subviews) tree(child, depth + 1);
}

static void caseConstants(void)
{
    line(RPApplicationInfoBundleIdentifierKey);
    line(RPVideoSampleOrientationKey);
    line(RPRecordingErrorDomain);
    line([NSString stringWithFormat:@"codes %ld %ld %ld %ld %ld", (long)RPRecordingErrorUnknown, (long)RPRecordingErrorUserDeclined,
          (long)RPRecordingErrorInterrupted, (long)RPRecordingErrorBroadcastInvalidSession, (long)RPRecordingErrorAttemptToStopNonRecording]);
    line([NSString stringWithFormat:@"buffers %ld %ld %ld", (long)RPSampleBufferTypeVideo, (long)RPSampleBufferTypeAudioApp, (long)RPSampleBufferTypeAudioMic]);
}

static void caseActivity(NSString *preferred)
{
    __block int calls = 0;
    __block BOOL onMain = NO;
    __block RPBroadcastActivityViewController *got = nil;
    __block NSError *gotError = nil;
    void (^handler)(RPBroadcastActivityViewController *, NSError *) = ^(RPBroadcastActivityViewController *vc, NSError *error) {
        calls++;
        onMain = [NSThread isMainThread];
        got = vc;
        gotError = error;
    };
    if (preferred) {
        [RPBroadcastActivityViewController loadBroadcastActivityViewControllerWithPreferredExtension:preferred handler:handler];
    } else {
        [RPBroadcastActivityViewController loadBroadcastActivityViewControllerWithHandler:handler];
    }
    line([NSString stringWithFormat:@"calls_at_return=%d", calls]);
    spin(0.1);
    line([NSString stringWithFormat:@"calls=%d main=%d class=%@ error=%@", calls, onMain, className(got), errText(gotError)]);
    tree(got.view, 0);
}

static void caseController(void)
{
    RPBroadcastController *c = [[RPBroadcastController alloc] init];
    line([NSString stringWithFormat:@"broadcasting=%d paused=%d url=%@ info=%@ delegate=%@ bundle=%@",
          c.broadcasting, c.paused, c.broadcastURL, c.serviceInfo, c.delegate, c.broadcastExtensionBundleID]);
    [c pauseBroadcast];
    [c resumeBroadcast];
    line([NSString stringWithFormat:@"after pause and resume broadcasting=%d paused=%d", c.broadcasting, c.paused]);
    __block int calls = 0;
    __block BOOL onMain = NO;
    __block NSError *gotError = nil;
    [c finishBroadcastWithHandler:^(NSError *error) {
        calls++;
        onMain = [NSThread isMainThread];
        gotError = error;
    }];
    spin(0.1);
    line([NSString stringWithFormat:@"finish calls=%d main=%d error=%@", calls, onMain, errText(gotError)]);
}

static void caseConfiguration(void)
{
    RPBroadcastConfiguration *c = [[RPBroadcastConfiguration alloc] init];
    line([NSString stringWithFormat:@"fresh clipDuration=%.1f compression=%@", c.clipDuration, c.videoCompressionProperties]);
    c.clipDuration = 2.5;
    c.videoCompressionProperties = @{@"AVVideoAverageBitRateKey": @1000};
    line([NSString stringWithFormat:@"set clipDuration=%.1f compression=%@", c.clipDuration, c.videoCompressionProperties]);
    line([NSString stringWithFormat:@"secure=%d", [RPBroadcastConfiguration supportsSecureCoding]]);
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:c];
    RPBroadcastConfiguration *back = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    line([NSString stringWithFormat:@"round trip class=%@ clipDuration=%.1f", className(back), back.clipDuration]);
}

static void caseConfigurationCopy(void)
{
    RPBroadcastConfiguration *c = [[RPBroadcastConfiguration alloc] init];
    id copy = [c copy];
    line([NSString stringWithFormat:@"copy=%@", className(copy)]);
}

static void casePicker(void)
{
    RPSystemBroadcastPickerView *p = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    line([NSString stringWithFormat:@"preferred=%@ microphone=%d", p.preferredExtension, p.showsMicrophoneButton]);
    p.showsMicrophoneButton = NO;
    line([NSString stringWithFormat:@"microphone after NO=%d", p.showsMicrophoneButton]);
    tree(p, 0);
    for (UIView *child in p.subviews) {
        if ([child isKindOfClass:[UIButton class]]) {
            line([NSString stringWithFormat:@"button title=%@", [(UIButton *)child titleForState:UIControlStateNormal]]);
        }
    }
}

static void caseSuperclasses(void)
{
    line([NSString stringWithFormat:@"sample super=%@ handler super=%@ mp4 super=%@",
          plain(NSStringFromClass(class_getSuperclass([RPBroadcastSampleHandler class]))),
          plain(NSStringFromClass(class_getSuperclass([RPBroadcastHandler class]))),
          plain(NSStringFromClass(class_getSuperclass([RPBroadcastMP4ClipHandler class])))]);
}

static void caseHandlerCalls(void)
{
    RPBroadcastSampleHandler *h = [[RPBroadcastSampleHandler alloc] init];
    [h broadcastStartedWithSetupInfo:nil];
    line(@"returned broadcastStartedWithSetupInfo");
    [h broadcastPaused];
    [h broadcastResumed];
    [h updateServiceInfo:@{}];
    [h updateBroadcastURL:[NSURL URLWithString:@"http://example.invalid/broadcast"]];
    [h broadcastAnnotatedWithApplicationInfo:@{}];
    [h processSampleBuffer:NULL withType:RPSampleBufferTypeVideo];
    [h finishBroadcastWithError:nil];
    [h broadcastFinished];
    line(@"returned the lifecycle calls and samples");
}

static void caseClipHandler(void)
{
    RPBroadcastMP4ClipHandler *h = [[RPBroadcastMP4ClipHandler alloc] init];
    [h processMP4ClipWithURL:nil setupInfo:nil finished:YES];
    [h finishedProcessingMP4ClipWithUpdatedBroadcastConfiguration:nil error:nil];
    line(@"returned the clip calls");
}

static void caseRequestContext(void)
{
    RPBroadcastSampleHandler *h = [[RPBroadcastSampleHandler alloc] init];
    NSExtensionContext *context = [[NSExtensionContext alloc] init];
    [h beginRequestWithExtensionContext:context];
    line(@"returned beginRequestWithExtensionContext");
}

static void caseExtensionContext(void)
{
    NSExtensionContext *context = [[NSExtensionContext alloc] init];
    __block BOOL called = NO;
    [context loadBroadcastingApplicationInfoWithCompletion:^(NSString *bundleID, NSString *displayName, UIImage *icon) {
        called = YES;
    }];
    spin(1.0);
    line([NSString stringWithFormat:@"app info completion called=%d within 1 s", called]);
    [context completeRequestWithBroadcastURL:[NSURL URLWithString:@"http://example.invalid/broadcast"] setupInfo:nil];
    line(@"returned completeRequestWithBroadcastURL:setupInfo:");
    [context completeRequestWithBroadcastURL:[NSURL URLWithString:@"http://example.invalid/broadcast"]
                      broadcastConfiguration:[[RPBroadcastConfiguration alloc] init] setupInfo:nil];
    line(@"returned completeRequestWithBroadcastURL:broadcastConfiguration:setupInfo:");
}

static void caseRecorder(void)
{
    RPScreenRecorder *r = [RPScreenRecorder sharedRecorder];
    line([NSString stringWithFormat:@"class=%@ same=%d", className(r), r == [RPScreenRecorder sharedRecorder]]);
    line([NSString stringWithFormat:@"recording=%d microphone=%d camera=%d position=%ld preview=%@ delegate=%@",
          r.recording, r.microphoneEnabled, r.cameraEnabled, (long)r.cameraPosition, className(r.cameraPreviewView), className(r.delegate)]);
    r.microphoneEnabled = YES;
    r.cameraPosition = RPCameraPositionBack;
    line([NSString stringWithFormat:@"after set microphone=%d position=%ld", r.microphoneEnabled, (long)r.cameraPosition]);
    __block int calls = 0;
    __block BOOL onMain = NO;
    __block BOOL beforeReturn = NO;
    __block BOOL returned = NO;
    __block RPPreviewViewController *gotPreview = nil;
    __block NSError *gotError = nil;
    [r stopRecordingWithHandler:^(RPPreviewViewController *preview, NSError *error) {
        calls++;
        onMain = [NSThread isMainThread];
        beforeReturn = !returned;
        gotPreview = preview;
        gotError = error;
    }];
    returned = YES;
    spin(0.1);
    line([NSString stringWithFormat:@"stop calls=%d main=%d before-return=%d preview=%@ error=%@", calls, onMain, beforeReturn,
          className(gotPreview), errText(gotError)]);
    __block int discards = 0;
    [r discardRecordingWithHandler:^{
        discards++;
    }];
    spin(2.0);
    line([NSString stringWithFormat:@"discard calls=%d within 2 s", discards]);
}

static void caseRecorderAvailable(void)
{
    line([NSString stringWithFormat:@"available=%d", [RPScreenRecorder sharedRecorder].available]);
}

static void casePreview(void)
{
    RPPreviewViewController *p = [[RPPreviewViewController alloc] init];
    line([NSString stringWithFormat:@"class=%@ super=%@ delegate=%@ loaded=%d", className(p), NSStringFromClass([p superclass]),
          className(p.previewControllerDelegate), p.isViewLoaded]);
}

void revenant_windowed_run(UIWindow *window)
{
    const char *name = getenv("DIFF_CASE");
    NSString *which = name ? [NSString stringWithUTF8String:name] : @"constants";
    line([NSString stringWithFormat:@"case=%@", which]);
    if ([which isEqualToString:@"constants"]) caseConstants();
    else if ([which isEqualToString:@"activity-nil"]) caseActivity(nil);
    else if ([which isEqualToString:@"activity-named"]) caseActivity(@"local.revenant.nonexistent");
    else if ([which isEqualToString:@"controller"]) caseController();
    else if ([which isEqualToString:@"configuration"]) caseConfiguration();
    else if ([which isEqualToString:@"configuration-copy"]) caseConfigurationCopy();
    else if ([which isEqualToString:@"picker"]) casePicker();
    else if ([which isEqualToString:@"superclasses"]) caseSuperclasses();
    else if ([which isEqualToString:@"handler-calls"]) caseHandlerCalls();
    else if ([which isEqualToString:@"clip-handler"]) caseClipHandler();
    else if ([which isEqualToString:@"request-context"]) caseRequestContext();
    else if ([which isEqualToString:@"extension-context"]) caseExtensionContext();
    else if ([which isEqualToString:@"recorder"]) caseRecorder();
    else if ([which isEqualToString:@"recorder-available"]) caseRecorderAvailable();
    else if ([which isEqualToString:@"preview"]) casePreview();
    else line(@"unknown case");
}
