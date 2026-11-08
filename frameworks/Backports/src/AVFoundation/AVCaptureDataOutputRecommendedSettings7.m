#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

static BOOL revenant_recommends_aac(AVFileType outputFileType)
{
    return [outputFileType isEqualToString:AVFileTypeMPEG4] || [outputFileType isEqualToString:AVFileTypeQuickTimeMovie];
}

static CMFormatDescriptionRef revenant_live_format(AVCaptureOutput *output)
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

@interface AVCaptureAudioDataOutput (RevenantRecommendedAssetWriterSettings7)
- (NSDictionary *)recommendedAudioSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType;
@end

@implementation AVCaptureAudioDataOutput (RevenantRecommendedAssetWriterSettings7)

- (NSDictionary *)recommendedAudioSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType
{
    if (!revenant_recommends_aac(outputFileType))
        return nil;
    CMFormatDescriptionRef format = revenant_live_format(self);
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

static NSDictionary *revenant_recommended_video_settings(AVCaptureVideoDataOutput *output, NSString *codec)
{
    CMFormatDescriptionRef format = revenant_live_format(output);
    if (!format || !codec)
        return nil;
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format);
    if (size.width <= 0 || size.height <= 0)
        return nil;
    return @{
        AVVideoCodecKey: codec,
        AVVideoWidthKey: @(size.width),
        AVVideoHeightKey: @(size.height),
    };
}

@interface AVCaptureVideoDataOutput (RevenantRecommendedAssetWriterSettings7)
- (NSDictionary *)recommendedVideoSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType;
- (NSArray *)availableVideoCodecTypesForAssetWriterWithOutputFileType:(AVFileType)outputFileType;
- (NSDictionary *)recommendedVideoSettingsForVideoCodecType:(NSString *)videoCodecType assetWriterOutputFileType:(AVFileType)outputFileType;
@end

@implementation AVCaptureVideoDataOutput (RevenantRecommendedAssetWriterSettings7)

- (NSDictionary *)recommendedVideoSettingsForAssetWriterWithOutputFileType:(AVFileType)outputFileType
{
    return revenant_recommended_video_settings(self, self.availableVideoCodecTypes.firstObject);
}

- (NSArray *)availableVideoCodecTypesForAssetWriterWithOutputFileType:(AVFileType)outputFileType
{
    if (!revenant_recommends_aac(outputFileType))
        return @[];
    NSMutableArray *codecs = [self.availableVideoCodecTypes mutableCopy];
    if ([outputFileType isEqualToString:AVFileTypeMPEG4])
        [codecs removeObject:AVVideoCodecJPEG];
    return codecs;
}

- (NSDictionary *)recommendedVideoSettingsForVideoCodecType:(NSString *)videoCodecType assetWriterOutputFileType:(AVFileType)outputFileType
{
    if (![[self availableVideoCodecTypesForAssetWriterWithOutputFileType:outputFileType] containsObject:videoCodecType])
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:[NSString stringWithFormat:@"*** -[AVCaptureVideoDataOutput recommendedVideoSettingsForVideoCodecType:assetWriterOutputFileType:] Video codec type %@ is not available for output file type %@", videoCodecType, outputFileType]
                                     userInfo:nil];
    return revenant_recommended_video_settings(self, videoCodecType);
}

@end
