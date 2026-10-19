// MPChangeLanguageOptionCommandEvent, the 9.0 command event, and the two properties its header declares.
//
// Measured before this file was written, at class level, with tools/mach32_methods.py against the 6.1.3
// cache and a negative control: 6.1.3 has no class whose name holds 'CommandEvent' in any of its 236
// classes, none of its 41 categories, and a nonsense selector is absent. So this is a class the release
// does not have - new code, which cannot shadow anything, so there is nothing native for it to be - and
// the decision is carried, not absent. `absent` is for a member whose answer needs hardware the device
// lacks, and none of this family needs any.
//
// It is new code over the base MPRemoteCommandCenter71.m already carries: MPRemoteCommandEvent, with
// command and initWithCommand:. The two header lines it implements, quoted:
//
//   @property (nonatomic, readonly) MPNowPlayingInfoLanguageOption *languageOption;
//   @property (nonatomic, readonly) MPChangeLanguageOptionSetting setting;
//
// The AST says the header declares exactly languageOption and setting for this class, and the port
// declares exactly those and their setters, so a header member the port would not have is none.
//
// Readwrite in the port where the header has them readonly: an event the port builds has to be able to
// carry the option it is an event *about*, and a new class shadows nothing. The readonly accessors the
// header declares are what a caller reads, and they read what the port set.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPChangeLanguageOptionCommandEvent : MPRemoteCommandEvent
@property (nonatomic, strong, readwrite) MPNowPlayingInfoLanguageOption *languageOption;
@property (nonatomic, assign, readwrite) MPChangeLanguageOptionSetting setting;
@end
#else
// The SDK declares this class with its property readonly; the port's events have to be built carrying
// theirs, so it is made writable here, in an extension, and not declared a second time.
@interface MPChangeLanguageOptionCommandEvent ()
@property (nonatomic, strong, readwrite) MPNowPlayingInfoLanguageOption *languageOption;
@property (nonatomic, assign, readwrite) MPChangeLanguageOptionSetting setting;
@end
#endif

@implementation MPChangeLanguageOptionCommandEvent
@synthesize languageOption = _languageOption;
@synthesize setting = _setting;

// The header's readonly accessors, written out rather than left to the synthesiser, so what a caller
// reads is the port's own code and a mutation of it is a change of behaviour - removing the
// @synthesize is not, because ARC then synthesises exactly the same thing.
- (MPNowPlayingInfoLanguageOption *)languageOption {
    return _languageOption;
}

- (MPChangeLanguageOptionSetting)setting {
    return _setting;
}

@end
