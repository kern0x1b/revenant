#import "CharonAVCapturePhoto.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// AVCapturePhotoBracketSettings, iOS 10.0: the settings of a bracketed capture, a concrete AVCapturePhotoSettings with an
// array of AVCaptureBracketedStillImageSettings, one per photo of the bracket. Its factories and properties are what the
// SDK 16.4 header documents (AVCapturePhoto.h, "AVCapturePhotoBracketSettings"); the host's macOS build is a stub that
// raises from every factory (API_UNAVAILABLE(macos)), so there is no host oracle. The checks are the header's own rules:
// the bracketed settings are nil, empty or mixed, which raise NSInvalidArgumentException, and the bracket never reads back
// nil. The count against the output's maxBracketedCapturePhotoCount is the output's check at capture, not this class's.
//
// The capture of a bracket is AVCapturePhotoOutput's: one still per member, in order, each member's exposure applied as 6.1.3
// allows it (facts/AVFoundation/AVCapturePhotoBracketSettings.md). This class is the settings value; the emulator test
// (tests/backports/emulate/photobracket) checks every factory, property and refusal the header states, and the sequence of
// callbacks a bracket capture delivers.

@implementation AVCapturePhotoBracketSettings {
    NSArray<AVCaptureBracketedStillImageSettings *> *_charonBracketedSettings;
    BOOL _charonLensStabilizationEnabled;
}

// The bracketed settings the header requires: a non-empty array of one bracket class. A mix of the manual and auto classes
// is refused, since the header says all must be of one type. Returns a copy, so the caller's array cannot change the bracket.
static NSArray<AVCaptureBracketedStillImageSettings *> *CharonCheckedBracketedSettings(NSArray<AVCaptureBracketedStillImageSettings *> *bracketedSettings,
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

// The constructor the two factories come to. The base constructor allocates through [self alloc], so the bracket is made
// as an AVCapturePhotoBracketSettings with the same processed and RAW checks as a single photo's settings.
+ (instancetype)charon_bracketSettingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                            processedFileType:(NSString *)processedFileType bracketedSettings:(NSArray<AVCaptureBracketedStillImageSettings *> *)bracketedSettings
                                       method:(NSString *)method
{
    NSArray<AVCaptureBracketedStillImageSettings *> *checked = CharonCheckedBracketedSettings(bracketedSettings, method);
    AVCapturePhotoBracketSettings *settings = [self charon_settingsWithRaw:raw rawFileType:rawFileType format:format
                                                         processedFileType:processedFileType method:method];
    settings->_charonBracketedSettings = checked;
    return settings;
}

// iOS 10.0: no file type for the RAW or the processed image; each takes the container the constructor chooses.
+ (instancetype)photoBracketSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType processedFormat:(NSDictionary<NSString *, id> *)processedFormat
                                         bracketedSettings:(NSArray<__kindof AVCaptureBracketedStillImageSettings *> *)bracketedSettings
{
    return [self charon_bracketSettingsWithRaw:rawPixelFormatType rawFileType:nil format:processedFormat processedFileType:nil
                             bracketedSettings:bracketedSettings
                                        method:@"+[AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:processedFormat:bracketedSettings:]"];
}

// iOS 11.0: the containers of the RAW and the processed image may be named; nil takes the default of the constructor.
+ (instancetype)photoBracketSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType rawFileType:(AVFileType)rawFileType
                                           processedFormat:(NSDictionary<NSString *, id> *)processedFormat processedFileType:(AVFileType)processedFileType
                                         bracketedSettings:(NSArray<AVCaptureBracketedStillImageSettings *> *)bracketedSettings
{
    return [self charon_bracketSettingsWithRaw:rawPixelFormatType rawFileType:rawFileType format:processedFormat
                             processedFileType:processedFileType bracketedSettings:bracketedSettings
                                        method:@"+[AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:rawFileType:processedFormat:processedFileType:bracketedSettings:]"];
}

// Never nil: a bracket is made only with its settings, so the array is the one the factory checked.
- (NSArray<__kindof AVCaptureBracketedStillImageSettings *> *)bracketedSettings
{
    return _charonBracketedSettings ?: @[];
}

// Default NO, the header's default. Setting it YES is the output's check at capture (the output's lens stabilization
// support), not this settings object's.
- (BOOL)isLensStabilizationEnabled
{
    return _charonLensStabilizationEnabled;
}

- (void)setLensStabilizationEnabled:(BOOL)lensStabilizationEnabled
{
    _charonLensStabilizationEnabled = lensStabilizationEnabled;
}

// A copy is a bracket too, with its own array and lens setting; the base copy keeps the photo's values.
- (id)copyWithZone:(NSZone *)zone
{
    AVCapturePhotoBracketSettings *copy = [super copyWithZone:zone];
    copy->_charonBracketedSettings = _charonBracketedSettings;
    copy->_charonLensStabilizationEnabled = _charonLensStabilizationEnabled;
    return copy;
}

@end
