#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

// The two asset-writer recommendations iOS 7.0 added to the capture data outputs, ONE object, the API of
// the 7.0 release only.
//
// **What the release the port runs on has to offer.** 6.1.3's AVCaptureAudioDataOutput carries 13 own
// instance methods and none of them recommends anything - they are -sampleBufferDelegate and its queue,
// -sampleBufferCallbackQueue, -connectionMediaTypes and the session hooks - and
// -recommendedAudioSettingsForAssetWriterWithOutputFileType: is 7.0's. 6.1.3's AVCaptureVideoDataOutput
// carries 26 own instance methods among which are -videoSettings/-setVideoSettings:,
// -availableVideoCodecTypes (5.0's, and this file uses it), -availableVideoCVPixelFormatTypes and
// -vettedVideoSettingsForSettingsDictionary: - the settings are all reachable there, one member at a time.
// What 7.0 added is the single call that picks them, and both methods are declared `nullable`.
//
// **The values come from the live capture, not from this file.** Both headers say the settings depend on the receiver's
// AVCaptureSession and its inputs, may change when that configuration changes, and so the session is configured first and
// then queried (AVCaptureAudioDataOutput.h:115, and AVCaptureVideoDataOutput.h:109). So both dictionaries here are built
// out of what the receiver's own connections carry at the moment of the call:
//
//   audio  AVSampleRateKey and AVNumberOfChannelsKey out of the AudioStreamBasicDescription of the
//          connection's own input port's format description - the release's own member, 6.0's.
//   video  AVVideoWidthKey and AVVideoHeightKey out of the dimensions of the same format description, and
//          AVVideoCodecKey out of the release's own -availableVideoCodecTypes, which is the list the
//          header ties this call to: for QuickTime and ISO files its output is comparable to AVCaptureMovieFileOutput's
//          (:107), and
//          -availableVideoCodecTypes is that output's own codec list.
//
// **No bit rate, because Apple's own answer has none.** Measured on this machine's AVFoundation against a
// running session and a live input, for both file types the headers name
// (public.mpeg-4 and com.apple.quicktime-movie):
//
//   audio  AVFormatIDKey 1633772320 ('aac '), AVNumberOfChannelsKey 1, AVSampleRateKey 48000. Three keys.
//   video  AVVideoCodecKey avc1, AVVideoHeightKey 1080, AVVideoWidthKey 1920. Three keys.
//
// Neither carries AVEncoderBitRateKey or AVVideoCompressionPropertiesKey, and the left-over band this file
// replaces answered a fourth key, AVEncoderBitRateKey of `channels * 64000`, with nothing behind it. The
// encoder on the release these settings go to chooses its own rate when the dictionary does not name one,
// which is what Apple's own recommendation asks it to do; a number invented here would be a number the
// file cannot account for. The tables and the reading of them are in
// facts/AVFoundation/RecommendedSettings7.md, and the check is
// tests/backports/host/avf-recommended-settings7: one source, compiled twice, Apple's own answers and
// the port's joined key by key on the same live input.
//
// **A receiver with no session to describe answers nil**, which is what `nullable` is for and what both
// headers allow: the settings depend on the configuration of the session and its inputs, and with no
// connection there is no sample rate, no channel count and no frame size to report. The left-over
// returned nil for the video case only, on the dimensions it had read; the audio case answered a made-up
// 44100 Hz mono and a made-up bit rate for an output attached to nothing.

// 'aac ' (1633772320) for both, and AVCaptureAudioDataOutput.h:113 says the audio settings always give output
// comparable to AVCaptureMovieFileOutput's for QuickTime and ISO files. An asset writer's audio input takes the codec the container carries, and
// AAC is the one both of these carry.
static BOOL charon_recommends_aac(AVFileType outputFileType)
{
    return [outputFileType isEqualToString:AVFileTypeMPEG4] || [outputFileType isEqualToString:AVFileTypeQuickTimeMovie];
}

// The one input port's format the receiver is really capturing, or NULL. A connection of a data output
// has exactly one input port carrying its media, and the port description is the release's own member.
static CMFormatDescriptionRef charon_live_format(AVCaptureOutput *output)
{
    for (AVCaptureConnection *connection in output.connections) {
        for (AVCaptureInputPort *port in connection.inputPorts) {
            CMFormatDescriptionRef format = port.formatDescription;
            if (format)
                return format;
        }
    }
    return NULL;
}

@interface AVCaptureAudioDataOutput (CharonRecommendedAssetWriterSettings7)
- (NSDictionary *)recommendedAudioSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType;
@end

@implementation AVCaptureAudioDataOutput (CharonRecommendedAssetWriterSettings7)

- (NSDictionary *)recommendedAudioSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType
{
    if (!charon_recommends_aac(outputFileType))
        return nil;
    CMFormatDescriptionRef format = charon_live_format(self);
    const AudioStreamBasicDescription *asbd = format ? CMAudioFormatDescriptionGetStreamBasicDescription(format) : NULL;
    if (!asbd || asbd->mChannelsPerFrame == 0 || asbd->mSampleRate <= 0)
        return nil;
    return @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: @(asbd->mChannelsPerFrame),
        AVSampleRateKey: @(asbd->mSampleRate),
    };
}

@end

@interface AVCaptureVideoDataOutput (CharonRecommendedAssetWriterSettings7)
- (NSDictionary *)recommendedVideoSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType;
@end

@implementation AVCaptureVideoDataOutput (CharonRecommendedAssetWriterSettings7)

- (NSDictionary *)recommendedVideoSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType
{
    CMFormatDescriptionRef format = charon_live_format(self);
    if (!format)
        return nil;
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format);
    if (size.width <= 0 || size.height <= 0)
        return nil;
    // The release's own codec list, first entry: the header ties the recommendation to
    // AVCaptureMovieFileOutput's codecs and this is that list, so the codec is the release's answer and
    // not a constant written here. Measured on this machine, with a live session, the first entry is
    // avc1 and it is the codec Apple's own recommendation answers.
    NSString *codec = self.availableVideoCodecTypes.firstObject;
    if (!codec)
        return nil;
    return @{
        AVVideoCodecKey: codec,
        AVVideoWidthKey: @(size.width),
        AVVideoHeightKey: @(size.height),
    };
}

@end