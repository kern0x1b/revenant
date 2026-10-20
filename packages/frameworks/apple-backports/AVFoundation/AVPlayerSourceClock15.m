#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

@interface AVPlayer (RevenantSourceClock)
@end

@implementation AVPlayer (RevenantSourceClock)

- (id)sourceClock
{
    return ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("masterClock"));
}

- (void)setSourceClock:(id)sourceClock
{
    ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("setMasterClock:"), sourceClock);
}

@end
