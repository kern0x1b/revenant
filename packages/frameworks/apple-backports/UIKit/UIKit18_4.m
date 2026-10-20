#import "RevenantUIKit18.h"
#import <objc/runtime.h>

@implementation UIConversationContext
@end

@implementation UIConversationEntry
@end

@implementation UIMailConversationContext
@end

@implementation UIMailConversationEntry
@end

@implementation UIMessageConversationContext
@end

@implementation UIMessageConversationEntry
@end

@implementation UIInputSuggestion
@end

@implementation UISmartReplySuggestion
@end

@implementation NSObject (RevenantUIKit18_ConversationContext)

static char RevenantTextInputTraitsConversationContextKey;

- (id)conversationContext
{
    return objc_getAssociatedObject(self, &RevenantTextInputTraitsConversationContextKey);
}
- (void)setConversationContext:(id)context
{
    objc_setAssociatedObject(self, &RevenantTextInputTraitsConversationContextKey, context,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
