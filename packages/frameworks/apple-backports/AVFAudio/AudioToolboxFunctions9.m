#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioComponent.h>
#import <dispatch/dispatch.h>

static NSObject *RevenantSoundCompletionLock(void)
{
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lock = [[NSObject alloc] init];
    });
    return lock;
}

static NSMutableDictionary<NSNumber *, NSMutableArray<void (^)(void)> *> *RevenantPendingSoundCompletions(void)
{
    static NSMutableDictionary *pending;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pending = [NSMutableDictionary dictionary];
    });
    return pending;
}

static void RevenantSoundDidFinish(SystemSoundID sound, void *context)
{
    NSArray<void (^)(void)> *blocks;
    @synchronized (RevenantSoundCompletionLock()) {
        blocks = RevenantPendingSoundCompletions()[@(sound)];
        [RevenantPendingSoundCompletions() removeObjectForKey:@(sound)];
    }
    AudioServicesRemoveSystemSoundCompletion(sound);
    for (void (^block)(void) in blocks) {
        block();
    }
}

static void RevenantPlaySoundWithCompletion(SystemSoundID sound, void (^completion)(void), void (*play)(SystemSoundID))
{
    if (completion == nil) {
        play(sound);
        return;
    }
    BOOL registered = NO;
    @synchronized (RevenantSoundCompletionLock()) {
        NSMutableArray<void (^)(void)> *blocks = RevenantPendingSoundCompletions()[@(sound)];
        if (blocks != nil) {
            [blocks addObject:[completion copy]];
            registered = YES;
        } else if (AudioServicesAddSystemSoundCompletion(sound, CFRunLoopGetMain(), kCFRunLoopDefaultMode,
                                                         RevenantSoundDidFinish, NULL) == noErr) {
            RevenantPendingSoundCompletions()[@(sound)] = [NSMutableArray arrayWithObject:[completion copy]];
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
    RevenantPlaySoundWithCompletion(inSystemSoundID, inCompletionBlock, AudioServicesPlaySystemSound);
}

void AudioServicesPlayAlertSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void))
{
    RevenantPlaySoundWithCompletion(inSystemSoundID, inCompletionBlock, AudioServicesPlayAlertSound);
}

#define RevenantAudioComponentNoComponentStatus ((OSStatus)-3000)

void AudioComponentInstantiate(AudioComponent inComponent, AudioComponentInstantiationOptions inOptions,
                               void (^inCompletionHandler)(AudioComponentInstance _Nullable, OSStatus))
{
    AudioComponentInstance instance = NULL;
    OSStatus status = RevenantAudioComponentNoComponentStatus;
    if (inComponent != NULL) {
        status = AudioComponentInstanceNew(inComponent, &instance);
    }
    if (inCompletionHandler != nil) {
        inCompletionHandler(status == noErr ? instance : NULL, status);
    }
}
