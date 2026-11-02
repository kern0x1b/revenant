#include "../revenant_impl.h"
#import <Foundation/Foundation.h>


extern NSString *const MPLanguageOptionCharacteristicContainsOnlyForcedSubtitles;
extern NSString *const MPLanguageOptionCharacteristicDescribesMusicAndSound;
extern NSString *const MPLanguageOptionCharacteristicDescribesVideo;
extern NSString *const MPLanguageOptionCharacteristicDubbedTranslation;
extern NSString *const MPLanguageOptionCharacteristicEasyToRead;
extern NSString *const MPLanguageOptionCharacteristicIsAuxiliaryContent;
extern NSString *const MPLanguageOptionCharacteristicIsMainProgramContent;
extern NSString *const MPLanguageOptionCharacteristicLanguageTranslation;
extern NSString *const MPLanguageOptionCharacteristicTranscribesSpokenDialog;
extern NSString *const MPLanguageOptionCharacteristicVoiceOverTranslation;
extern NSString *const MPNowPlayingInfoPropertyAvailableLanguageOptions;
extern NSString *const MPNowPlayingInfoPropertyCurrentLanguageOptions;

NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicContainsOnlyForcedSubtitles) = @"public.subtitles.forced-only";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicDescribesMusicAndSound) = @"public.accessibility.describes-music-and-sound";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicDescribesVideo) = @"public.accessibility.describes-video";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicDubbedTranslation) = @"public.translation.dubbed";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicEasyToRead) = @"public.easy-to-read";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicIsAuxiliaryContent) = @"public.auxiliary-content";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicIsMainProgramContent) = @"public.main-program-content";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicLanguageTranslation) = @"public.translation";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicTranscribesSpokenDialog) = @"public.accessibility.transcribes-spoken-dialog";
NSString *const BACKPORT_IMPL(MPLanguageOptionCharacteristicVoiceOverTranslation) = @"public.translation.voice-over";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyAvailableLanguageOptions) = @"MPNowPlayingInfoPropertyAvailableLanguageOptions";
NSString *const BACKPORT_IMPL(MPNowPlayingInfoPropertyCurrentLanguageOptions) = @"MPNowPlayingInfoPropertyCurrentLanguageOption";
