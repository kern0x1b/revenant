#import <Foundation/Foundation.h>

// The iOS 9.0 band's MediaPlayer constants, TWELVE of them.
//
// MPMediaPlaylistPropertyCloudGlobalID was in this file and is not: release-split found it
// first appears at 8.2, and it now has its own object. The corpus filed all thirteen under
// 9.0 and the tool - which decides a ladder - disagreed for that one.
//
// The values are APPLE'S, measured from the host's own MediaPlayer by dlsym and printed as text and as
// bytes by tests/backports/host/mediaplayer-constants. They are not this symbol's name: ten of the
// thirteen are dotted public.* strings with no relation to their symbol, and
// MPNowPlayingInfoPropertyCurrentLanguageOptions holds the SINGULAR MPNowPlayingInfoPropertyCurrentLanguageOption,
// so writing the convention would have been wrong for twelve of the thirteen.
//
// iOS 6.1.3 exports NONE of these thirteen: its Security-independent export trie, read with the tools in
// charon/tools, has zero of them, so the port carries all of them. They are plain data - a caller compares
// or passes a string - so the port answers them itself and the release is never asked.
//
// The thirteen are declared HERE, with the plain extern, and MediaPlayer.h is deliberately NOT
// imported: with -I on the port's own tree that import resolves to the PORT's UIKit shim rather than the
// SDK's, and the shim does not compile against these headers. That is a real error and it is the reason.
//
// A constant is READ, never CALLED. Nothing here touches MPMediaLibrary, MPMediaQuery or a library.


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

NSString *const MPLanguageOptionCharacteristicContainsOnlyForcedSubtitles = @"public.subtitles.forced-only";
NSString *const MPLanguageOptionCharacteristicDescribesMusicAndSound = @"public.accessibility.describes-music-and-sound";
NSString *const MPLanguageOptionCharacteristicDescribesVideo = @"public.accessibility.describes-video";
NSString *const MPLanguageOptionCharacteristicDubbedTranslation = @"public.translation.dubbed";
NSString *const MPLanguageOptionCharacteristicEasyToRead = @"public.easy-to-read";
NSString *const MPLanguageOptionCharacteristicIsAuxiliaryContent = @"public.auxiliary-content";
NSString *const MPLanguageOptionCharacteristicIsMainProgramContent = @"public.main-program-content";
NSString *const MPLanguageOptionCharacteristicLanguageTranslation = @"public.translation";
NSString *const MPLanguageOptionCharacteristicTranscribesSpokenDialog = @"public.accessibility.transcribes-spoken-dialog";
NSString *const MPLanguageOptionCharacteristicVoiceOverTranslation = @"public.translation.voice-over";
NSString *const MPNowPlayingInfoPropertyAvailableLanguageOptions = @"MPNowPlayingInfoPropertyAvailableLanguageOptions";
NSString *const MPNowPlayingInfoPropertyCurrentLanguageOptions = @"MPNowPlayingInfoPropertyCurrentLanguageOption";
