#import <AVFAudio/AVFAudio.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static BOOL RevenantAcceptChannelCount(NSInteger preferred, NSInteger current, NSString *direction, NSError **outError)
{
    if (preferred == current)
        return YES;
    if (outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:AVAudioSessionErrorCodeBadParam
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"iOS 6 has one %@ channel count, the route's current %ld, and it cannot be changed to %ld",
                                                                           direction, (long)current, (long)preferred]}];
    return NO;
}

@implementation AVAudioSession (RevenantChannels7)

- (NSInteger)maximumInputNumberOfChannels
{
    return self.inputNumberOfChannels;
}

- (NSInteger)maximumOutputNumberOfChannels
{
    return self.outputNumberOfChannels;
}

- (BOOL)setPreferredInputNumberOfChannels:(NSInteger)count error:(NSError **)outError
{
    return RevenantAcceptChannelCount(count, self.inputNumberOfChannels, @"input", outError);
}

- (BOOL)setPreferredOutputNumberOfChannels:(NSInteger)count error:(NSError **)outError
{
    return RevenantAcceptChannelCount(count, self.outputNumberOfChannels, @"output", outError);
}

@end
