#import "CharonUIKit18.h"
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

@implementation NSObject (CharonUIKit18_ConversationContext)

static char CharonTextInputTraitsConversationContextKey;

- (id)conversationContext
{
    return objc_getAssociatedObject(self, &CharonTextInputTraitsConversationContextKey);
}
- (void)setConversationContext:(id)context
{
    objc_setAssociatedObject(self, &CharonTextInputTraitsConversationContextKey, context,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
