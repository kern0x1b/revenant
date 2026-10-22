#import <Foundation/Foundation.h>

@class AVAudioSession, CXAction, CXAnswerCallAction, CXEndCallAction, CXPlayDTMFCallAction, CXProvider, CXSetGroupCallAction, CXSetHeldCallAction, CXSetMutedCallAction, CXSetTranslatingCallAction, CXStartCallAction, CXTransaction;

@protocol CXProviderDelegate <NSObject>
@required
- (void)providerDidReset:(CXProvider *)provider;
@optional
- (void)providerDidBegin:(CXProvider *)provider;
- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction;
- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action;
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action;
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action;
- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action;
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action;
- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action;
- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action;
- (void)provider:(CXProvider *)provider performSetTranslatingCallAction:(CXSetTranslatingCallAction *)action;
- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action;
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession;
- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(CXProviderDelegate);
}
