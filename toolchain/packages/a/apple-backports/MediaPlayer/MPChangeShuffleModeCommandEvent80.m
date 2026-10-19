#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPChangeShuffleModeCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) MPShuffleType shuffleType;
@property (nonatomic, assign, readwrite) BOOL preservesShuffleMode;
@end
#else
@interface MPChangeShuffleModeCommandEvent ()
@property (nonatomic, assign, readwrite) MPShuffleType shuffleType;
@property (nonatomic, assign, readwrite) BOOL preservesShuffleMode;
@end
#endif

@implementation MPChangeShuffleModeCommandEvent
@synthesize shuffleType = _shuffleType;
@synthesize preservesShuffleMode = _preservesShuffleMode;

- (MPShuffleType)shuffleType {
    return _shuffleType;
}

- (BOOL)preservesShuffleMode {
    return _preservesShuffleMode;
}

@end
