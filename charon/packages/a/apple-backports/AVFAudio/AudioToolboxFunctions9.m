#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioComponent.h>
#import <dispatch/dispatch.h>

// AudioToolbox functions of iOS 9, which the release this port runs on does not export.

// The completion blocks of the sound functions that the release has no way to deliver. The release's
// AudioServicesAddSystemSoundCompletion calls back when a sound ends, on the run loop it is given. The host does not
// take that registration: it answers -1500 for every sound ID, valid or not, before or after the sound is played (measured,
// facts/AVFAudio/AudioToolboxFunctions.md). The host runs the block on a background queue, about a millisecond after the
// play call returns, whatever the sound ID. So a registration the release takes waits for the sound to end on the device,
// and a registration it refuses runs the block on the background queue at once.
static NSObject *CharonSoundCompletionLock(void)
{
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lock = [[NSObject alloc] init];
    });
    return lock;
}

// The blocks waiting on the registration of each sound ID. A sound ID has at most one registration with the release at a time.
static NSMutableDictionary<NSNumber *, NSMutableArray<void (^)(void)> *> *CharonPendingSoundCompletions(void)
{
    static NSMutableDictionary *pending;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pending = [NSMutableDictionary dictionary];
    });
    return pending;
}

static void CharonSoundDidFinish(SystemSoundID sound, void *context)
{
    NSArray<void (^)(void)> *blocks;
    @synchronized (CharonSoundCompletionLock()) {
        blocks = CharonPendingSoundCompletions()[@(sound)];
        [CharonPendingSoundCompletions() removeObjectForKey:@(sound)];
    }
    AudioServicesRemoveSystemSoundCompletion(sound);
    for (void (^block)(void) in blocks) {
        block();
    }
}

static void CharonPlaySoundWithCompletion(SystemSoundID sound, void (^completion)(void), void (*play)(SystemSoundID))
{
    if (completion == nil) {
        play(sound);
        return;
    }
    BOOL registered = NO;
    @synchronized (CharonSoundCompletionLock()) {
        NSMutableArray<void (^)(void)> *blocks = CharonPendingSoundCompletions()[@(sound)];
        if (blocks != nil) {
            [blocks addObject:[completion copy]];
            registered = YES;
        } else if (AudioServicesAddSystemSoundCompletion(sound, CFRunLoopGetMain(), kCFRunLoopDefaultMode,
                                                         CharonSoundDidFinish, NULL) == noErr) {
            CharonPendingSoundCompletions()[@(sound)] = [NSMutableArray arrayWithObject:[completion copy]];
            registered = YES;
        }
    }
    play(sound);
    if (!registered) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), completion);
    }
}

void AudioServicesPlaySystemSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void))
{
    CharonPlaySoundWithCompletion(inSystemSoundID, inCompletionBlock, AudioServicesPlaySystemSound);
}

void AudioServicesPlayAlertSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void))
{
    CharonPlaySoundWithCompletion(inSystemSoundID, inCompletionBlock, AudioServicesPlayAlertSound);
}

// The status the host answers for no component: -3000 (measured; the iOS SDK names no constant for it).
#define CharonAudioComponentNoComponentStatus ((OSStatus)-3000)

// AudioComponentInstantiate. The release's instance is made on the calling thread, and the handler is called with it before
// this returns, on that same thread: the host's answer for a component (instance, status 0, the main thread when called from
// the main thread) and for no component (no instance, status -3000). The options choose out-of-process loading on the
// host; this port loads every unit in the process, so they are not used.
void AudioComponentInstantiate(AudioComponent inComponent, AudioComponentInstantiationOptions inOptions,
                               void (^inCompletionHandler)(AudioComponentInstance _Nullable, OSStatus))
{
    AudioComponentInstance instance = NULL;
    OSStatus status = CharonAudioComponentNoComponentStatus;
    if (inComponent != NULL) {
        status = AudioComponentInstanceNew(inComponent, &instance);
    }
    if (inCompletionHandler != nil) {
        inCompletionHandler(status == noErr ? instance : NULL, status);
    }
}
