#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const char RevenantTextStackKey;
static const char RevenantSelectableKey;
static const char RevenantLinkAttributesKey;

@interface RevenantTextStack : NSObject <NSTextStorageDelegate> {
@public
    NSTextStorage *storage;
    NSLayoutManager *layout;
    NSTextContainer *container;
    __weak UITextView *textView;
    BOOL syncing;
}
@end

@implementation RevenantTextStack

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
    [self revenant_pushToView];
}

- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
    [self revenant_pushToView];
}

- (void)revenant_pushToView
{
    UITextView *view = textView;
    if (syncing || !view)
        return;
    syncing = YES;
    NSRange selection = view.selectedRange;
    view.attributedText = [[NSAttributedString alloc] initWithAttributedString:storage];
    NSUInteger length = view.text.length;
    view.selectedRange = NSMakeRange(MIN(selection.location, length), MIN(selection.length, length - MIN(selection.location, length)));
    syncing = NO;
}

@end

static RevenantTextStack *revenant_text_stack(UITextView *view)
{
    RevenantTextStack *stack = objc_getAssociatedObject(view, &RevenantTextStackKey);
    if (!stack) {
        stack = [[RevenantTextStack alloc] init];
        stack->textView = view;
        stack->storage = [[NSTextStorage alloc] initWithAttributedString:view.attributedText ?: [[NSAttributedString alloc] initWithString:@""]];
        stack->layout = [[NSLayoutManager alloc] init];
        [stack->storage addLayoutManager:stack->layout];
        UIEdgeInsets inset = view.textContainerInset;
        stack->container = [[NSTextContainer alloc] initWithSize:CGSizeMake(MAX(view.bounds.size.width - inset.left - inset.right, 0), CGFLOAT_MAX)];
        stack->container.widthTracksTextView = YES;
        [stack->layout addTextContainer:stack->container];
        [stack->storage setDelegate:stack];
        objc_setAssociatedObject(view, &RevenantTextStackKey, stack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return stack;
}

static RevenantTextStack *revenant_synced_stack(UITextView *view)
{
    RevenantTextStack *stack = revenant_text_stack(view);
    NSAttributedString *shown = view.attributedText ?: [[NSAttributedString alloc] initWithString:@""];
    if (!stack->syncing && ![stack->storage isEqualToAttributedString:shown]) {
        stack->syncing = YES;
        [stack->storage setAttributedString:shown];
        stack->syncing = NO;
    }
    if (stack->container.widthTracksTextView) {
        UIEdgeInsets inset = view.textContainerInset;
        CGFloat width = MAX(view.bounds.size.width - inset.left - inset.right, 0);
        if (stack->container.size.width != width)
            stack->container.size = CGSizeMake(width, stack->container.size.height);
    }
    return stack;
}

static BOOL (*revenant_original_can_become)(id, SEL);
static BOOL (*revenant_original_can_perform)(id, SEL, SEL, id);

@interface RevenantTextViewSelectable7 : NSObject
@end

@implementation RevenantTextViewSelectable7

+ (void)load
{
    if ([UITextView instancesRespondToSelector:@selector(isSelectable)])
        return;
    Method become = class_getInstanceMethod([UITextView class], @selector(canBecomeFirstResponder));
    Method perform = class_getInstanceMethod([UITextView class], @selector(canPerformAction:withSender:));
    if (!become || !perform)
        return;
    revenant_original_can_become = (BOOL (*)(id, SEL))method_getImplementation(become);
    revenant_original_can_perform = (BOOL (*)(id, SEL, SEL, id))method_getImplementation(perform);
    method_setImplementation(become, imp_implementationWithBlock(^BOOL(UITextView *view) {
        if (!view.isEditable && ![view isSelectable])
            return NO;
        return revenant_original_can_become(view, @selector(canBecomeFirstResponder));
    }));
    method_setImplementation(perform, imp_implementationWithBlock(^BOOL(UITextView *view, SEL action, id sender) {
        if (!view.isEditable && ![view isSelectable])
            return NO;
        return revenant_original_can_perform(view, @selector(canPerformAction:withSender:), action, sender);
    }));
}

@end

@implementation UITextView (RevenantTextKit7)

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    if ((self = [self initWithFrame:frame]) && textContainer) {
        RevenantTextStack *stack = [[RevenantTextStack alloc] init];
        stack->textView = self;
        stack->container = textContainer;
        stack->layout = textContainer.layoutManager;
        stack->storage = stack->layout.textStorage;
        if (stack->storage) {
            [stack->storage setDelegate:stack];
            objc_setAssociatedObject(self, &RevenantTextStackKey, stack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            stack->syncing = YES;
            self.attributedText = [[NSAttributedString alloc] initWithAttributedString:stack->storage];
            stack->syncing = NO;
        }
    }
    return self;
}

- (NSTextStorage *)textStorage
{
    return revenant_synced_stack(self)->storage;
}

- (NSLayoutManager *)layoutManager
{
    return revenant_synced_stack(self)->layout;
}

- (NSTextContainer *)textContainer
{
    return revenant_synced_stack(self)->container;
}

- (BOOL)isSelectable
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantSelectableKey);
    return stored ? stored.boolValue : YES;
}

- (BOOL)selectable
{
    return [self isSelectable];
}

- (void)setSelectable:(BOOL)selectable
{
    objc_setAssociatedObject(self, &RevenantSelectableKey, @(selectable), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!selectable && !self.isEditable && self.isFirstResponder)
        [self resignFirstResponder];
}

- (NSDictionary<NSString *, id> *)linkTextAttributes
{
    return objc_getAssociatedObject(self, &RevenantLinkAttributesKey) ?: @{NSForegroundColorAttributeName: self.tintColor};
}

- (void)setLinkTextAttributes:(NSDictionary<NSString *, id> *)linkTextAttributes
{
    if (linkTextAttributes)
        revenant_menus_say_once(@"textview-link-attributes", @"UITextView.linkTextAttributes: the iOS 6 text view draws links with its web view's own style, so the attributes are kept and read back and the links are drawn as before");
    objc_setAssociatedObject(self, &RevenantLinkAttributesKey, [linkTextAttributes copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
