#import "RevenantAVCapturePhoto.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@implementation AVCapturePhotoBracketSettings {
    NSArray<AVCaptureBracketedStillImageSettings *> *_revenantBracketedSettings;
    BOOL _revenantLensStabilizationEnabled;
}

static NSArray<AVCaptureBracketedStillImageSettings *> *RevenantCheckedBracketedSettings(NSArray<AVCaptureBracketedStillImageSettings *> *bracketedSettings,
                                                                                       NSString *method)
{
    if (!bracketedSettings || bracketedSettings.count == 0)
        [NSException raise:NSInvalidArgumentException format:@"*** %@ bracketedSettings must hold at least one AVCaptureBracketedStillImageSettings", method];
    Class bracketClass = [bracketedSettings.firstObject class];
    for (id settings in bracketedSettings) {
        if (![settings isKindOfClass:[AVCaptureBracketedStillImageSettings class]] || [settings class] != bracketClass)
            [NSException raise:NSInvalidArgumentException format:@"*** %@ bracketedSettings mixes classes: all must be AVCaptureManualExposureBracketedStillImageSettings or all AVCaptureAutoExposureBracketedStillImageSettings", method];
    }
    return [bracketedSettings copy];
}

+ (instancetype)revenant_bracketSettingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                            processedFileType:(NSString *)processedFileType bracketedSettings:(NSArray<AVCaptureBracketedStillImageSettings *> *)bracketedSettings
                                       method:(NSString *)method
{
    NSArray<AVCaptureBracketedStillImageSettings *> *checked = RevenantCheckedBracketedSettings(bracketedSettings, method);
    AVCapturePhotoBracketSettings *settings = [self revenant_settingsWithRaw:raw rawFileType:rawFileType format:format
                                                         processedFileType:processedFileType method:method];
    settings->_revenantBracketedSettings = checked;
    return settings;
}

+ (instancetype)photoBracketSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType processedFormat:(NSDictionary<NSString *, id> *)processedFormat
                                         bracketedSettings:(NSArray<__kindof AVCaptureBracketedStillImageSettings *> *)bracketedSettings
{
    return [self revenant_bracketSettingsWithRaw:rawPixelFormatType rawFileType:nil format:processedFormat processedFileType:nil
                             bracketedSettings:bracketedSettings
                                        method:@"+[AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:processedFormat:bracketedSettings:]"];
}

+ (instancetype)photoBracketSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType rawFileType:(AVFileType)rawFileType
                                           processedFormat:(NSDictionary<NSString *, id> *)processedFormat processedFileType:(AVFileType)processedFileType
                                         bracketedSettings:(NSArray<AVCaptureBracketedStillImageSettings *> *)bracketedSettings
{
    return [self revenant_bracketSettingsWithRaw:rawPixelFormatType rawFileType:rawFileType format:processedFormat
                             processedFileType:processedFileType bracketedSettings:bracketedSettings
                                        method:@"+[AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:rawFileType:processedFormat:processedFileType:bracketedSettings:]"];
}

- (NSArray<__kindof AVCaptureBracketedStillImageSettings *> *)bracketedSettings
{
    return _revenantBracketedSettings ?: @[];
}

- (BOOL)isLensStabilizationEnabled
{
    return _revenantLensStabilizationEnabled;
}

- (void)setLensStabilizationEnabled:(BOOL)lensStabilizationEnabled
{
    _revenantLensStabilizationEnabled = lensStabilizationEnabled;
}

- (id)copyWithZone:(NSZone *)zone
{
    AVCapturePhotoBracketSettings *copy = [super copyWithZone:zone];
    copy->_revenantBracketedSettings = _revenantBracketedSettings;
    copy->_revenantLensStabilizationEnabled = _revenantLensStabilizationEnabled;
    return copy;
}

@end
