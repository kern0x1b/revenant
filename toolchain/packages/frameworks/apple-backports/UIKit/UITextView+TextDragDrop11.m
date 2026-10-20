#import <UIKit/UIKit.h>
#import <UIKit/UIDragSession.h>
#import <UIKit/UIDragInteraction.h>
#import <UIKit/UIDropInteraction.h>
#import <UIKit/UITextDragging.h>
#import <UIKit/UITextDropping.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantDragSession.h"
#import "RevenantTextDragDrop11.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const char kRevenantFieldTextDragDelegate;
static const char kRevenantFieldTextDropDelegate;

static const char RevenantTextDragDelegateKey;
static const char RevenantTextDropDelegateKey;
static const char RevenantTextDragOptionsKey;
static const char RevenantTextDragInteractionKey;
static const char RevenantTextDropInteractionKey;

@implementation UITextView (RevenantTextDragDropAdaptors)

- (RevenantTextDragAdaptor *)revenant_textDragDelegateAdaptor
{
    static const char key;
    RevenantTextDragAdaptor *adaptor = objc_getAssociatedObject(self, &key);
    if (adaptor)
        return adaptor;
    adaptor = [[RevenantTextDragAdaptor alloc] initWithControl:self];
    objc_setAssociatedObject(self, &key, adaptor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return adaptor;
}

- (RevenantTextDropAdaptor *)revenant_textDropDelegateAdaptor
{
    static const char key;
    RevenantTextDropAdaptor *adaptor = objc_getAssociatedObject(self, &key);
    if (adaptor)
        return adaptor;
    adaptor = [[RevenantTextDropAdaptor alloc] initWithControl:self];
    objc_setAssociatedObject(self, &key, adaptor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return adaptor;
}

@end

@interface RevenantWeakDelegateBox : NSObject
@property (nonatomic, weak) id target;
@end

@implementation RevenantWeakDelegateBox
@synthesize target = _target;
@end

static id RevenantTextDragDelegateOf(id<UITextDraggable> control)
{
    RevenantWeakDelegateBox *box = objc_getAssociatedObject(control, &RevenantTextDragDelegateKey);
    return box.target;
}

static void RevenantSetTextDragDelegate(id<UITextDraggable> control, id<UITextDragDelegate> delegate)
{
    if (!delegate) {
        objc_setAssociatedObject(control, &RevenantTextDragDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    RevenantWeakDelegateBox *box = [[RevenantWeakDelegateBox alloc] init];
    box.target = delegate;
    objc_setAssociatedObject(control, &RevenantTextDragDelegateKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIDragInteraction *RevenantTextDragInteraction(id<UITextDraggable> control)
{
    UIDragInteraction *interaction = objc_getAssociatedObject(control, &RevenantTextDragInteractionKey);
    if (interaction)
        return interaction;
    id<UIDragInteractionDelegate> delegate =
        (id<UIDragInteractionDelegate>)[(UIView *)control revenant_textDragDelegateAdaptor];
    interaction = [[UIDragInteraction alloc] initWithDelegate:delegate];
    objc_setAssociatedObject(control, &RevenantTextDragInteractionKey, interaction,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return interaction;
}

static BOOL RevenantIsTextDragActive(id<UITextDraggable> control)
{
    UIDragInteraction *interaction = objc_getAssociatedObject(control, &RevenantTextDragInteractionKey);
    return interaction ? interaction.session != nil : NO;
}

static UITextDragOptions RevenantTextDragOptionsOf(id<UITextDraggable> control)
{
    NSNumber *options = objc_getAssociatedObject(control, &RevenantTextDragOptionsKey);
    return (UITextDragOptions)(options ? options.unsignedIntegerValue : UITextDragOptionsNone);
}

static void RevenantSetTextDragOptions(id<UITextDraggable> control, UITextDragOptions options)
{
    objc_setAssociatedObject(control, &RevenantTextDragOptionsKey, @(options),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id RevenantTextDropDelegateOf(id<UITextDroppable> control)
{
    RevenantWeakDelegateBox *box = objc_getAssociatedObject(control, &RevenantTextDropDelegateKey);
    return box.target;
}

static void RevenantSetTextDropDelegate(id<UITextDroppable> control, id<UITextDropDelegate> delegate)
{
    if (!delegate) {
        objc_setAssociatedObject(control, &RevenantTextDropDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    RevenantWeakDelegateBox *box = [[RevenantWeakDelegateBox alloc] init];
    box.target = delegate;
    objc_setAssociatedObject(control, &RevenantTextDropDelegateKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIDropInteraction *RevenantTextDropInteraction(id<UITextDroppable> control)
{
    UIDropInteraction *interaction = objc_getAssociatedObject(control, &RevenantTextDropInteractionKey);
    if (interaction)
        return interaction;
    id<UIDropInteractionDelegate> delegate =
        (id<UIDropInteractionDelegate>)[(UIView *)control revenant_textDropDelegateAdaptor];
    interaction = [[UIDropInteraction alloc] initWithDelegate:delegate];
    objc_setAssociatedObject(control, &RevenantTextDropInteractionKey, interaction,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return interaction;
}

static BOOL RevenantIsTextDropActive(id<UITextDroppable> control)
{
    UIDropInteraction *interaction = objc_getAssociatedObject(control, &RevenantTextDropInteractionKey);
    return interaction ? interaction.currentDrop != nil : NO;
}

#define REVENANT_TEXT_DRAG_DROP_MEMBERS(ControlType)                                                              \
    - (id<UITextDragDelegate>)textDragDelegate { return RevenantTextDragDelegateOf(self); }                        \
    - (void)setTextDragDelegate:(id<UITextDragDelegate>)d { RevenantSetTextDragDelegate(self, d); }                  \
    - (UIDragInteraction *)textDragInteraction { return RevenantTextDragInteraction(self); }                         \
    - (BOOL)isTextDragActive { return RevenantIsTextDragActive(self); }                                             \
    - (UITextDragOptions)textDragOptions { return RevenantTextDragOptionsOf(self); }                                \
    - (void)setTextDragOptions:(UITextDragOptions)o { RevenantSetTextDragOptions(self, o); }                        \
    - (id<UITextDropDelegate>)textDropDelegate { return RevenantTextDropDelegateOf(self); }                          \
    - (void)setTextDropDelegate:(id<UITextDropDelegate>)d { RevenantSetTextDropDelegate(self, d); }                  \
    - (UIDropInteraction *)textDropInteraction { return RevenantTextDropInteraction(self); }                         \
    - (BOOL)isTextDropActive { return RevenantIsTextDropActive(self); }

@implementation UITextView (RevenantTextDragDrop11)
REVENANT_TEXT_DRAG_DROP_MEMBERS(UITextView)
@end

@implementation UITextField (RevenantTextDragDrop11)
REVENANT_TEXT_DRAG_DROP_MEMBERS(UITextField)
@end

@implementation RevenantTextDragAdaptor
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
    return [self revenant_itemsForDragSession:session];
}

- (NSArray<UIDragItem *> *)revenant_itemsForDragSession:(id<UIDragSession>)session
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL ask = @selector(textDraggableView:itemsForDrag:);
    if (![delegate respondsToSelector:ask])
        return nil;
    RevenantTextDragRequest *request = [[RevenantTextDragRequest alloc] initWithSession:session];
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

- (UITargetedDragPreview *)revenant_previewForLiftingItem:(UIDragItem *)item session:(id<UIDragSession>)session
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

- (void)revenant_willAnimateLiftWithSession:(id<UIDragSession>)session
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

- (void)revenant_dragSessionDidEnd:(id<UIDragSession>)session withOperation:(UIDropOperation)operation
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL ask = @selector(textDraggableView:dragSessionDidEnd:withOperation:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(delegate, ask, self.control, session, (NSInteger)operation);
}

@end

@implementation RevenantTextDropAdaptor
@synthesize control = _control;

- (instancetype)initWithControl:(UIView<UITextDraggable, UITextDroppable> *)control
{
    if ((self = [super init]))
        _control = control;
    return self;
}

- (BOOL)revenant_canHandleSession:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:willBecomeEditableForDrop:);
    if (![delegate respondsToSelector:ask])
        return NO;
    RevenantTextDropRequest *request = [[RevenantTextDropRequest alloc] initWithSession:session];
    UITextDropEditability editability = ((UITextDropEditability (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, request);
    return editability == UITextDropEditabilityYes;
}

- (void)revenant_updateForSession:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL proposal = @selector(textDroppableView:proposalForDrop:);
    SEL perform = @selector(textDroppableView:willPerformDrop:);
    SEL preview = @selector(textDroppableView:previewForDroppingAllItemsWithDefault:);
    RevenantTextDropRequest *request = [[RevenantTextDropRequest alloc] initWithSession:session];
    if ([delegate respondsToSelector:proposal]) {
        UITextDropProposal *answer = ((UITextDropProposal * (*)(id, SEL, id, id))objc_msgSend)(delegate, proposal, self.control, request);
        request.proposal = answer;
    }
    if ([delegate respondsToSelector:perform])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, perform, self.control, request);
    if ([delegate respondsToSelector:preview])
        ((UITargetedDragPreview * (*)(id, SEL, id, id))objc_msgSend)(delegate, preview, self.control, (id)[UITargetedDragPreview class]);
}

- (void)revenant_sessionDidEnter:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:dropSessionDidEnter:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, session);
}

- (void)revenant_sessionDidExit:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:dropSessionDidExit:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, session);
}

- (void)revenant_sessionDidEnd:(id<UIDropSession>)session
{
    id<UITextDropDelegate> delegate = self.control.textDropDelegate;
    SEL ask = @selector(textDroppableView:dropSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, session);
}

@end

@implementation RevenantTextDragRequest
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

@implementation RevenantTextDropRequest
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
