#import <Foundation/Foundation.h>

@class PKPushRegistry, PKPushCredentials, PKPushPayload;
typedef NSString *PKPushType;

@protocol PKPushRegistryDelegate <NSObject>
@required
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)pushCredentials forType:(PKPushType)type;
@optional
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type;
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion;
- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type;
@end

__attribute__((used)) static void revenantEmitProtocols(void)
{
    (void)@protocol(PKPushRegistryDelegate);
}
