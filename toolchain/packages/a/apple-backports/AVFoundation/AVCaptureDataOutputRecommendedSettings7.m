#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

static BOOL charon_recommends_aac(AVFileType outputFileType)
{
    return [outputFileType isEqualToString:AVFileTypeMPEG4] || [outputFileType isEqualToString:AVFileTypeQuickTimeMovie];
}

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
