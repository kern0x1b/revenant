#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPChangeRepeatModeCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) MPRepeatType repeatType;
@property (nonatomic, assign, readwrite) BOOL preservesRepeatMode;
@end
#else
@interface MPChangeRepeatModeCommandEvent ()
@property (nonatomic, assign, readwrite) MPRepeatType repeatType;
@property (nonatomic, assign, readwrite) BOOL preservesRepeatMode;
@end
#endif

@implementation MPChangeRepeatModeCommandEvent
@synthesize repeatType = _repeatType;
@synthesize preservesRepeatMode = _preservesRepeatMode;

- (MPRepeatType)repeatType {
    return _repeatType;
}

- (BOOL)preservesRepeatMode {
    return _preservesRepeatMode;
}

@end
