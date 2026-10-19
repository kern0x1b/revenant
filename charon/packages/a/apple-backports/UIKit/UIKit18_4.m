// UIKit18_4.m - the 18.4 band: eight conversation and suggestion classes, and the accessor for the
// context property a text input's traits carry from this release on.
//
// ONE OBJECT, ONE RELEASE: 18.4, on its own.  Its siblings UIKit18_1.m (18.1) and UIKit18_2.m (18.2)
// are their own objects and their own releases, and tools/release-split.lua walks the held ladder
// symbol by symbol and refuses a file whose symbols first appear in more than one release.  A reader is
// the only thing that would notice a 26.0 class in this file, because that check reads band points only
// for a category method.
//
// --- (a) THE EIGHT CLASSES ---------------------------------------------------------------------
//
// The abstract pair (UIConversationContext, UIConversationEntry), the two concrete pairs that
// specialise it for Mail and for Messages, and the two suggestion names (UIInputSuggestion,
// UISmartReplySuggestion).  They are declared in CharonUIKit18.h and implemented empty, and the header
// says why an empty class is the whole answer: a class is a DYLD SYMBOL, an application that links
// strongly against it names _OBJC_CLASS_$_X and dyld has to find it.  What a 6.1.3 text input could do
// with a conversation context is nothing - the feature needs a mail or messages service and a revision
// tracker, and this release has neither - so an empty class is the complete honest answer and invented
// members would answer for behaviour nobody measured.
//
// NOTHING HERE INHERITS FROM EACH OTHER.  It is tempting to make UIMailConversationEntry a
// UIConversationEntry and UISmartReplySuggestion a UIInputSuggestion, because the names read that way.
// No declaration in this tree says so - the 26.2 sysroot is not in the store (only iPhoneOS16.4.sdk is,
// under ~/.xmake/packages/i/iphoneos-sdk/16.4/) - and a wrong superclass is a wrong answer at runtime,
// not a missing one: a caller casting down to a parent the port invented would get a class whose
// instance layout is not the one the release's is.  So all eight inherit NSObject and the registry row
// for each states the choice.
//
// --- (b) THE UITEXTINPUTTRAITS CONTEXT PROPERTY ---------------------------------------------------
//
// UITextInputTraits.conversationContext is a @protocol member, and A CATEGORY CANNOT BE ON A PROTOCOL,
// so the port builds the accessor on NSObject - the only class every conforming object inherits - under
// a row of its own, -[NSObject conversationContext], exactly as the 26.0 band did for
// -[NSObject allowsNumberPadPopover].  That is also the answer that works: the release's own
// UITextInputTraits is a @protocol in 6.1.3, 12.0 and 16.0, and at 18.0 only the class of that name
// survives (measured, and the facts page carries
// the command), and declaring a class of that name in the port would shadow the class the release's own
// dylib already carries under that name.
//
// THE COST IS STATED, NOT HIDDEN: an unrelated object also answers YES to -[NSObject conversationContext].
// That is the price of a selector the port does not own a class for, and the registry row says the same
// rather than implying a conformance the port does not have.
//
// A CATEGORY HAS NO IVARS - the compiler says "expected identifier or '('" at the opening brace - so the
// storage is an associated object and the getter returns nil when nothing was ever stored.

#import "CharonUIKit18.h"
#import <objc/runtime.h>

// =====================================================================================
// (a) THE EIGHT CLASSES.  No members: see the note above.
// =====================================================================================

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

// =====================================================================================
// (b) THE PROPERTY THE PORT PUTS ON NSObject, FOR THE PROTICOL THAT CANNOT CARRY IT.
// =====================================================================================

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
