#import <AVFAudio/AVFAudio.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static BOOL RevenantIsCurrentInput(AVAudioSessionPortDescription *port)
{
    for (AVAudioSessionPortDescription *input in [AVAudioSession sharedInstance].currentRoute.inputs) {
        if ([input.UID isEqualToString:port.UID])
            return YES;
    }
    return NO;
}

@implementation AVAudioSessionPortDescription (RevenantDataSources7)

- (NSArray<AVAudioSessionDataSourceDescription *> *)dataSources
{
    return RevenantIsCurrentInput(self) ? [AVAudioSession sharedInstance].inputDataSources : nil;
}

- (AVAudioSessionDataSourceDescription *)selectedDataSource
{
    return RevenantIsCurrentInput(self) ? [AVAudioSession sharedInstance].inputDataSource : nil;
}

- (BOOL)setPreferredDataSource:(AVAudioSessionDataSourceDescription *)dataSource error:(NSError **)outError
{
    if (RevenantIsCurrentInput(self))
        return [[AVAudioSession sharedInstance] setInputDataSource:dataSource error:outError];
    if (!dataSource)
        return YES;
    if (outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:AVAudioSessionErrorCodeResourceNotAvailable
                                    userInfo:@{NSLocalizedDescriptionKey: @"The port is not an input of the current route, and iOS 6 selects a data source only on the current input"}];
    return NO;
}

@end
