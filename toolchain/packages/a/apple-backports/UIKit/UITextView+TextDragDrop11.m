#import <UIKit/UIKit.h>
#import <UIKit/UIDragSession.h>
#import <UIKit/UIDragInteraction.h>
#import <UIKit/UIDropInteraction.h>
#import <UIKit/UITextDragging.h>
#import <UIKit/UITextDropping.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonDragSession.h"
#import "CharonTextDragDrop11.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const char kCharonFieldTextDragDelegate;
static const char kCharonFieldTextDropDelegate;

static const char CharonTextDragDelegateKey;
static const char CharonTextDropDelegateKey;
static const char CharonTextDragOptionsKey;
static const char CharonTextDragInteractionKey;
static const char CharonTextDropInteractionKey;

@implementation UITextView (CharonTextDragDropAdaptors)

- (CharonTextDragAdaptor *)charon_textDragDelegateAdaptor
{
    static const char key;
    CharonTextDragAdaptor *adaptor = objc_getAssociatedObject(self, &key);
    if (adaptor)
        return adaptor;
    adaptor = [[CharonTextDragAdaptor alloc] initWithControl:self];
    objc_setAssociatedObject(self, &key, adaptor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return adaptor;
}

- (CharonTextDropAdaptor *)charon_textDropDelegateAdaptor
{
    static const char key;
    CharonTextDropAdaptor *adaptor = objc_getAssociatedObject(self, &key);
    if (adaptor)
        return adaptor;
    adaptor = [[CharonTextDropAdaptor alloc] initWithControl:self];
    objc_setAssociatedObject(self, &key, adaptor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return adaptor;
}

@end

@interface CharonWeakDelegateBox : NSObject
@property (nonatomic, weak) id target;
@end

@implementation CharonWeakDelegateBox
@synthesize target = _target;
@end

static id CharonTextDragDelegateOf(id<UITextDraggable> control)
{
    CharonWeakDelegateBox *box = objc_getAssociatedObject(control, &CharonTextDragDelegateKey);
    return box.target;
}

static void CharonSetTextDragDelegate(id<UITextDraggable> control, id<UITextDragDelegate> delegate)
{
    if (!delegate) {
        objc_setAssociatedObject(control, &CharonTextDragDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    CharonWeakDelegateBox *box = [[CharonWeakDelegateBox alloc] init];
    box.target = delegate;
    objc_setAssociatedObject(control, &CharonTextDragDelegateKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIDragInteraction *CharonTextDragInteraction(id<UITextDraggable> control)
{
    UIDragInteraction *interaction = objc_getAssociatedObject(control, &CharonTextDragInteractionKey);
    if (interaction)
        return interaction;
    id<UIDragInteractionDelegate> delegate =
        (id<UIDragInteractionDelegate>)[(UIView *)control charon_textDragDelegateAdaptor];
    interaction = [[UIDragInteraction alloc] initWithDelegate:delegate];
    objc_setAssociatedObject(control, &CharonTextDragInteractionKey, interaction,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return interaction;
}

static BOOL CharonIsTextDragActive(id<UITextDraggable> control)
{
    UIDragInteraction *interaction = objc_getAssociatedObject(control, &CharonTextDragInteractionKey);
    return interaction ? interaction.session != nil : NO;
}

static UITextDragOptions CharonTextDragOptionsOf(id<UITextDraggable> control)
{
    NSNumber *options = objc_getAssociatedObject(control, &CharonTextDragOptionsKey);
    return (UITextDragOptions)(options ? options.unsignedIntegerValue : UITextDragOptionsNone);
}

static void CharonSetTextDragOptions(id<UITextDraggable> control, UITextDragOptions options)
{
    objc_setAssociatedObject(control, &CharonTextDragOptionsKey, @(options),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id CharonTextDropDelegateOf(id<UITextDroppable> control)
{
    CharonWeakDelegateBox *box = objc_getAssociatedObject(control, &CharonTextDropDelegateKey);
    return box.target;
}

static void CharonSetTextDropDelegate(id<UITextDroppable> control, id<UITextDropDelegate> delegate)
{
    if (!delegate) {
        objc_setAssociatedObject(control, &CharonTextDropDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    CharonWeakDelegateBox *box = [[CharonWeakDelegateBox alloc] init];
    box.target = delegate;
    objc_setAssociatedObject(control, &CharonTextDropDelegateKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIDropInteraction *CharonTextDropInteraction(id<UITextDroppable> control)
{
    UIDropInteraction *interaction = objc_getAssociatedObject(control, &CharonTextDropInteractionKey);
    if (interaction)
        return interaction;
    id<UIDropInteractionDelegate> delegate =
        (id<UIDropInteractionDelegate>)[(UIView *)control charon_textDropDelegateAdaptor];
    interaction = [[UIDropInteraction alloc] initWithDelegate:delegate];
    objc_setAssociatedObject(control, &CharonTextDropInteractionKey, interaction,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return interaction;
}

static BOOL CharonIsTextDropActive(id<UITextDroppable> control)
{
    UIDropInteraction *interaction = objc_getAssociatedObject(control, &CharonTextDropInteractionKey);
    return interaction ? interaction.currentDrop != nil : NO;
}

#define CHARON_TEXT_DRAG_DROP_MEMBERS(ControlType)                                                              \
    - (id<UITextDragDelegate>)textDragDelegate { return CharonTextDragDelegateOf(self); }                        \
    - (void)setTextDragDelegate:(id<UITextDragDelegate>)d { CharonSetTextDragDelegate(self, d); }                  \
    - (UIDragInteraction *)textDragInteraction { return CharonTextDragInteraction(self); }                         \
    - (BOOL)isTextDragActive { return CharonIsTextDragActive(self); }                                             \
    - (UITextDragOptions)textDragOptions { return CharonTextDragOptionsOf(self); }                                \
    - (void)setTextDragOptions:(UITextDragOptions)o { CharonSetTextDragOptions(self, o); }                        \
    - (id<UITextDropDelegate>)textDropDelegate { return CharonTextDropDelegateOf(self); }                          \
    - (void)setTextDropDelegate:(id<UITextDropDelegate>)d { CharonSetTextDropDelegate(self, d); }                  \
    - (UIDropInteraction *)textDropInteraction { return CharonTextDropInteraction(self); }                         \
    - (BOOL)isTextDropActive { return CharonIsTextDropActive(self); }

@implementation UITextView (CharonTextDragDrop11)
CHARON_TEXT_DRAG_DROP_MEMBERS(UITextView)
@end

@implementation UITextField (CharonTextDragDrop11)
CHARON_TEXT_DRAG_DROP_MEMBERS(UITextField)
@end

@implementation CharonTextDragAdaptor
@synthesize control = _control;

- (instancetype)initWithControl:(UIView<UITextDraggable, UITextDroppable> *)control
{
    if ((self = [super init]))
        _control = control;
    return self;
}

- (NSArray<UIDragItem *> *)dragInteraction:(UIDragInteraction *)interaction
                   itemsForBeginningSession:(id<UIDragSession>)session
{
    return [self charon_itemsForDragSession:session];
}

- (NSArray<UIDragItem *> *)charon_itemsForDragSession:(id<UIDragSession>)session
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL ask = @selector(textDraggableView:itemsForDrag:);
    if (![delegate respondsToSelector:ask])
        return nil;
    CharonTextDragRequest *request = [[CharonTextDragRequest alloc] initWithSession:session];
    if ([self.control isKindOfClass:[UITextView class]]) {
        UITextView *text = (UITextView *)self.control;
        UITextPosition *start = [text positionFromPosition:text.beginningOfDocument offset:0];
        request.range = [text textRangeFromPosition:start toPosition:[text positionFromPosition:start offset:text.selectedRange.length]];
    }
    request.selected = request.range != nil;
    NSArray<UIDragItem *> *items = ((NSArray<UIDragItem *> * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, request);
    request.suggested = items;
    return items.count ? items : nil;
}

- (UITargetedDragPreview *)charon_previewForLiftingItem:(UIDragItem *)item session:(id<UIDragSession>)session
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL ask = @selector(textDraggableView:dragPreviewForLiftingItem:session:);
    if ([delegate respondsToSelector:ask])
        return ((UITargetedDragPreview * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self.control, item, session);
    UIView *control = self.control;
    if (![control isKindOfClass:[UITextView class]])
        return nil;
    UITextView *text = (UITextView *)control;
    NSRange range = text.selectedRange;
    if (!range.length)
        return nil;
    NSLayoutManager *layout = text.layoutManager;
    if (!layout)
        return nil;
    UITextDragPreviewRenderer *renderer = [[UITextDragPreviewRenderer alloc] initWithLayoutManager:layout range:range];
    UIImage *image = renderer.image;
    if (!image)
        return nil;
    UIDragPreviewParameters *parameters = [[UIDragPreviewParameters alloc] init];
    parameters.visiblePath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImageView *picture = [[UIImageView alloc] initWithImage:image];
    return [[UITargetedDragPreview alloc] initWithView:picture
                                       parameters:parameters
                                            target:[[UIDragPreviewTarget alloc] initWithContainer:text
                                                                                        center:CGPointMake(CGRectGetMidX([text bounds]),
                                                                                                          CGRectGetMidY([text bounds]))]];
}

- (void)charon_willAnimateLiftWithSession:(id<UIDragSession>)session
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL preview = @selector(textDraggableView:dragPreviewForLiftingItem:session:);
    SEL animate = @selector(textDraggableView:willAnimateLiftWithAnimator:session:);
    SEL willBegin = @selector(textDraggableView:dragSessionWillBegin:);
    UIDragItem *item = session.items.firstObject;
    if ([delegate respondsToSelector:preview] && item)
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, preview, self.control, item, session);
    if ([delegate respondsToSelector:animate])
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, animate, self.control, (id)self, session);
    if ([delegate respondsToSelector:willBegin])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, willBegin, self.control, session);
}

- (void)charon_dragSessionDidEnd:(id<UIDragSession>)session withOperation:(UIDropOperation)operation
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL ask = @selector(textDraggableView:dragSessionDidEnd:withOperation:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(delegate, ask, self.control, session, (NSInteger)operation);
}

@end

@implementation CharonTextDropAdaptor
@synthesize control = _control;

- (instancetype)initWithControl:(UIView<UITextDraggable, UITextDroppable> *)control
{
    if ((self = [super init]))
        _control = control;
    return self;
}

- (BOOL)charon_canHandleSession:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:willBecomeEditableForDrop:);
    if (![delegate respondsToSelector:ask])
        return NO;
    CharonTextDropRequest *request = [[CharonTextDropRequest alloc] initWithSession:session];
    UITextDropEditability editability = ((UITextDropEditability (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, request);
    return editability == UITextDropEditabilityYes;
}

- (void)charon_updateForSession:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL proposal = @selector(textDroppableView:proposalForDrop:);
    SEL perform = @selector(textDroppableView:willPerformDrop:);
    SEL preview = @selector(textDroppableView:previewForDroppingAllItemsWithDefault:);
    CharonTextDropRequest *request = [[CharonTextDropRequest alloc] initWithSession:session];
    if ([delegate respondsToSelector:proposal]) {
        UITextDropProposal *answer = ((UITextDropProposal * (*)(id, SEL, id, id))objc_msgSend)(delegate, proposal, self.control, request);
        request.proposal = answer;
    }
    if ([delegate respondsToSelector:perform])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, perform, self.control, request);
    if ([delegate respondsToSelector:preview])
        ((UITargetedDragPreview * (*)(id, SEL, id, id))objc_msgSend)(delegate, preview, self.control, (id)[UITargetedDragPreview class]);
}

- (void)charon_sessionDidEnter:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:dropSessionDidEnter:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, session);
}

- (void)charon_sessionDidExit:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:dropSessionDidExit:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, session);
}

- (void)charon_sessionDidEnd:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:dropSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, session);
}

@end

@implementation CharonTextDragRequest
@synthesize session = _session;
@synthesize range = _range;
@synthesize suggested = _suggested;
@synthesize existing = _existing;
@synthesize selected = _selected;

- (instancetype)initWithSession:(id<UIDragSession>)session
{
    if ((self = [super init])) {
        _session = session;
    }
    return self;
}

- (id<UIDragSession>)dragSession
{
    return _session;
}

- (UITextRange *)dragRange
{
    return _range;
}

- (NSArray<UIDragItem *> *)suggestedItems
{
    return _suggested ?: @[];
}

- (NSArray<UIDragItem *> *)existingItems
{
    return _existing ?: @[];
}

- (BOOL)isSelected
{
    return _selected;
}

@end

@implementation CharonTextDropRequest
@synthesize session = _session;
@synthesize position = _position;
@synthesize proposal = _proposal;
@synthesize sameView = _sameView;

- (instancetype)initWithSession:(id<UIDropSession>)session
{
    if ((self = [super init]))
        _session = session;
    return self;
}

- (id<UIDropSession>)dropSession
{
    return _session;
}

- (UITextPosition *)dropPosition
{
    return _position;
}

- (UITextDropProposal *)suggestedProposal
{
    return _proposal;
}

- (BOOL)isSameView
{
    return _sameView;
}

@end
