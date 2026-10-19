//  writer.m
//  What Apple's own AVFoundation recommends to an asset writer input, measured against a live capture, and
//  what the port recommends for the same live capture. ONE file, compiled twice.
//
//  THIS ONE FILE, TWICE:
//
//    -DCHARN_PORT_HALF=0   no port object in the link. Every call is a plain message send to this
//                          machine's own AVFoundation and every answer is Apple's. This half is the ORACLE
//                          and every expectation comes from it.
//    -DCHARN_PORT_HALF=1   the port's own packages/a/apple-backports/AVFoundation/
//                          AVCaptureDataOutputRecommendedSettings7.m in the link, and each call goes to the
//                          PORT's implementation of that method.
//
//  **Why the port half calls an IMP and not a message.** The concrete class of a capture output on this
//  machine is `AVCaptureVideoDataOutput_Tundra` - a SUBCLASS of AVCaptureVideoDataOutput that carries its
//  own implementation of both methods (measured: `[out class]` answers that name, and
//  `-methodForSelector:` answers an address inside the framework). The port's work is a CATEGORY on the
//  public class, so a message send reaches the subclass's implementation and never the port's. The port's
//  own IMP is fetched with class_getInstanceMethod, which finds the category's method on the public class
//  before the subclass's, and the CONTROL row prints both addresses: a run where they are the same
//  pointer measured nothing about the port, and the run says so rather than passing.
//
//  Both halves ask the same questions of the same live input, so the join is per KEY: a key the host
//  carries and the port does not is a row on one side only, and a key both carry must agree.
//
//  The live input is this machine's own microphone and camera on a real AVCaptureSession which is really
//  started - both headers ask for exactly that (AVCaptureAudioDataOutput.h:115 says the session must be configured
//  before the recommended settings are queried), and a probe that asked an output attached to
//  nothing would measure the answer for no configuration rather than the answer for this one.
//
//  Every row is printed as `key | value`. The controls come first.
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <stdio.h>

#ifndef CHARN_PORT_HALF
#define CHARN_PORT_HALF 0
#endif

static int rowIndex;
static NSString *section = @"";

static void row(NSString *key, NSString *value)
{
    rowIndex++;
    printf("%s\n", [[NSString stringWithFormat:@"%@%@ | %@", section, key, value] UTF8String]);
    fflush(stdout);
}

// A dictionary, one row per key, sorted, so the join compares values and not a description's ordering.
// A nil dictionary is one row and not a crash: "nullable" is what both headers declare.
static void report(NSString *label, NSDictionary *dictionary)
{
    if (!dictionary) {
        row(label, @"nil");
        return;
    }
    NSArray *keys = [[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys)
        row([NSString stringWithFormat:@"%@ %@", label, key], [dictionary[key] description]);
}

static NSString *describe(NSArray *values)
{
    return values.count ? [values componentsJoinedByString:@","] : @"(empty)";
}

// The two calls, through the port's own implementation on the port half and through a message send
// otherwise. Both take the receiver the release gave us, so both read the same live format.
static id charon_audio_settings(AVCaptureAudioDataOutput *output, AVFileType fileType)
{
    SEL selector = @selector(recommendedAudioSettingsForAssetWriterWithOutputFileType:);
#if CHARN_PORT_HALF
    IMP port = method_getImplementation(class_getInstanceMethod([AVCaptureAudioDataOutput class], selector));
    return ((id (*)(id, SEL, id))port)(output, selector, fileType);
#else
    (void)selector;
    return [output recommendedAudioSettingsForAssetWriterWithOutputFileType:fileType];
#endif
}

static id charon_video_settings(AVCaptureVideoDataOutput *output, AVFileType fileType)
{
    SEL selector = @selector(recommendedVideoSettingsForAssetWriterWithOutputFileType:);
#if CHARN_PORT_HALF
    IMP port = method_getImplementation(class_getInstanceMethod([AVCaptureVideoDataOutput class], selector));
    return ((id (*)(id, SEL, id))port)(output, selector, fileType);
#else
    (void)selector;
    return [output recommendedVideoSettingsForAssetWriterWithOutputFileType:fileType];
#endif
}

int main(void)
{
    @autoreleasepool {
        section = @"";
        AVCaptureDevice *mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        row(@"CONTROL audio device", mic ? mic.localizedName : @"NONE");
        row(@"CONTROL video device", camera ? camera.localizedName : @"NONE");
        if (!mic || !camera) {
            row(@"RUN", @"no capture device on this machine, so nothing below was measured");
            row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
            return 0;
        }

        // Which implementation each half is about to ask. Read on its own, before anything is measured.
        {
            SEL audio = @selector(recommendedAudioSettingsForAssetWriterWithOutputFileType:);
            SEL video = @selector(recommendedVideoSettingsForAssetWriterWithOutputFileType:);
            AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
            AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
            row(@"CONTROL concrete audio output class",
                NSStringFromClass([(NSObject *)audioOutput class]));
            row(@"CONTROL concrete video output class",
                NSStringFromClass([(NSObject *)videoOutput class]));
            row(@"CONTROL audio dispatched IMP",
                [NSString stringWithFormat:@"%p", (void *)[audioOutput methodForSelector:audio]]);
            row(@"CONTROL video dispatched IMP",
                [NSString stringWithFormat:@"%p", (void *)[videoOutput methodForSelector:video]]);
            row(@"CONTROL audio class IMP",
                [NSString stringWithFormat:@"%p",
                 (void *)method_getImplementation(class_getInstanceMethod([AVCaptureAudioDataOutput class], audio))]);
            row(@"CONTROL video class IMP",
                [NSString stringWithFormat:@"%p",
                 (void *)method_getImplementation(class_getInstanceMethod([AVCaptureVideoDataOutput class], video))]);
        }

        // ---- the empty case first: an output that belongs to no session has no configuration to report,
        //      and both headers declare the methods nullable.
        section = @"unattached: ";
        {
            AVCaptureAudioDataOutput *audio = [[AVCaptureAudioDataOutput alloc] init];
            AVCaptureVideoDataOutput *video = [[AVCaptureVideoDataOutput alloc] init];
            report(@"audio MPEG-4", charon_audio_settings(audio, AVFileTypeMPEG4));
            report(@"video MPEG-4", charon_video_settings(video, AVFileTypeMPEG4));
            row(@"audio connections", [NSString stringWithFormat:@"%lu", (unsigned long)audio.connections.count]);
            row(@"video connections", [NSString stringWithFormat:@"%lu", (unsigned long)video.connections.count]);
        }

        // ---- the live session, audio
        section = @"audio: ";
        {
            AVCaptureSession *session = [[AVCaptureSession alloc] init];
            AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:mic error:NULL];
            if (!input || ![session canAddInput:input]) {
                row(@"RUN", @"this machine refused the microphone as a session input");
                row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
                return 0;
            }
            [session addInput:input];
            AVCaptureAudioDataOutput *output = [[AVCaptureAudioDataOutput alloc] init];
            if (![session canAddOutput:output]) {
                row(@"RUN", @"this machine refused an audio data output on the session");
                row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
                return 0;
            }
            [session addOutput:output];
            [session startRunning];
            row(@"running", session.isRunning ? @"YES" : @"NO");

            // the live format the port reads its values out of, printed so the derivation is checked
            // against its own source rather than against the answer it produced
            CMFormatDescriptionRef format = NULL;
            for (AVCaptureConnection *connection in output.connections)
                for (AVCaptureInputPort *port in connection.inputPorts)
                    if (port.formatDescription) format = port.formatDescription;
            row(@"live format present", format ? @"YES" : @"NO");
            const AudioStreamBasicDescription *asbd = format ? CMAudioFormatDescriptionGetStreamBasicDescription(format) : NULL;
            row(@"live sample rate", asbd ? [NSString stringWithFormat:@"%.0f", asbd->mSampleRate] : @"nil");
            row(@"live channels", asbd ? [NSString stringWithFormat:@"%u", asbd->mChannelsPerFrame] : @"nil");
            row(@"live format ID", asbd ? [NSString stringWithFormat:@"%u", (unsigned)asbd->mFormatID] : @"nil");

            report(@"MPEG-4", charon_audio_settings(output, AVFileTypeMPEG4));
            report(@"QuickTime", charon_audio_settings(output, AVFileTypeQuickTimeMovie));
            [session stopRunning];
        }

        // ---- the live session, video
        section = @"video: ";
        {
            AVCaptureSession *session = [[AVCaptureSession alloc] init];
            AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:NULL];
            if (!input || ![session canAddInput:input]) {
                row(@"RUN", @"this machine refused the camera as a session input");
                row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
                return 0;
            }
            [session addInput:input];
            AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
            if (![session canAddOutput:output]) {
                row(@"RUN", @"this machine refused a video data output on the session");
                row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
                return 0;
            }
            [session addOutput:output];
            [session startRunning];
            row(@"running", session.isRunning ? @"YES" : @"NO");

            // the release's own codec list, which is where the port takes its codec from, and the live
            // dimensions, which is where it takes the frame size from
            row(@"availableVideoCodecTypes", describe(output.availableVideoCodecTypes));
            CMFormatDescriptionRef format = NULL;
            for (AVCaptureConnection *connection in output.connections)
                for (AVCaptureInputPort *port in connection.inputPorts)
                    if (port.formatDescription) format = port.formatDescription;
            row(@"live format present", format ? @"YES" : @"NO");
            if (format) {
                CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format);
                row(@"live dimensions", [NSString stringWithFormat:@"%dx%d", (int)size.width, (int)size.height]);
            } else {
                row(@"live dimensions", @"nil");
            }

            report(@"MPEG-4", charon_video_settings(output, AVFileTypeMPEG4));
            report(@"QuickTime", charon_video_settings(output, AVFileTypeQuickTimeMovie));
            [session stopRunning];
        }

        section = @"";
        row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
    }
    return 0;
}