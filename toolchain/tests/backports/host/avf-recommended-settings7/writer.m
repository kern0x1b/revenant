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

static id revenant_audio_settings(AVCaptureAudioDataOutput *output, AVFileType fileType)
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

static id revenant_video_settings(AVCaptureVideoDataOutput *output, AVFileType fileType)
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

        section = @"unattached: ";
        {
            AVCaptureAudioDataOutput *audio = [[AVCaptureAudioDataOutput alloc] init];
            AVCaptureVideoDataOutput *video = [[AVCaptureVideoDataOutput alloc] init];
            report(@"audio MPEG-4", revenant_audio_settings(audio, AVFileTypeMPEG4));
            report(@"video MPEG-4", revenant_video_settings(video, AVFileTypeMPEG4));
            row(@"audio connections", [NSString stringWithFormat:@"%lu", (unsigned long)audio.connections.count]);
            row(@"video connections", [NSString stringWithFormat:@"%lu", (unsigned long)video.connections.count]);
        }

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

            CMFormatDescriptionRef format = NULL;
            for (AVCaptureConnection *connection in output.connections)
                for (AVCaptureInputPort *port in connection.inputPorts)
                    if (port.formatDescription) format = port.formatDescription;
            row(@"live format present", format ? @"YES" : @"NO");
            const AudioStreamBasicDescription *asbd = format ? CMAudioFormatDescriptionGetStreamBasicDescription(format) : NULL;
            row(@"live sample rate", asbd ? [NSString stringWithFormat:@"%.0f", asbd->mSampleRate] : @"nil");
            row(@"live channels", asbd ? [NSString stringWithFormat:@"%u", asbd->mChannelsPerFrame] : @"nil");
            row(@"live format ID", asbd ? [NSString stringWithFormat:@"%u", (unsigned)asbd->mFormatID] : @"nil");

            report(@"MPEG-4", revenant_audio_settings(output, AVFileTypeMPEG4));
            report(@"QuickTime", revenant_audio_settings(output, AVFileTypeQuickTimeMovie));
            [session stopRunning];
        }

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

            report(@"MPEG-4", revenant_video_settings(output, AVFileTypeMPEG4));
            report(@"QuickTime", revenant_video_settings(output, AVFileTypeQuickTimeMovie));
            [session stopRunning];
        }

        section = @"";
        row(@"rows", [NSString stringWithFormat:@"%d", rowIndex]);
    }
    return 0;
}
