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

// The caller: a text view that can be dragged from and dropped onto, through the port's own drag
// and drop interactions.
//
// The release has a text view and neither of these, so the port supplies the three properties
// `UITextDraggable` and `UITextDroppable` declare on a text control, and the interactions that ask
// the two text delegates' questions in the order their headers give. A drag begins by asking the
// drag delegate what the text is; a drop asks the drop delegate whether the control will take it,
// what it proposes, and then performs it.
//
// The order is Apple's, from the headers, as a fact rather than a copy:
//   * `itemsForDrag:` is what a drag is, asked first, and a delegate that answers nothing is a drag
//     that does not begin;
//   * `dragPreviewForLiftingItem:session:` is the picture the lift animates, and
//     `willAnimateLiftWithAnimator:session:` is where an application animates alongside it, so the
//     preview comes before the animator and both before the session begins;
//   * `dragSessionWillBegin:` is once the items exist and the lift is about to run;
//   * on the drop side `willBecomeEditableForDrop:` is the gate -- a delegate that says no is a drop
//     that is not allowed, and then nothing else is asked -- so it comes before `proposalForDrop:`,
//     which is what the drop would do where it is now, and both before `willPerformDrop:` and the
//     preview for dropping all the items;
//   * the four session messages then report the drag as it moves over this control: enter, update,
//     exit, end.

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

// One adaptor per control, made once, so a control that is asked twice has one delegate and the
// interaction's is not replaced under itself.
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

// -------------------------------------------------------------------------------------------
// The bodies, once. A text view and a text field are unrelated classes, so a category on one
// cannot be called from the other; the seven members are the SDK's two protocols' members and
// they are written once here, against the protocols, and both categories below forward to them.
// The one place the two delegates are stored, and it is the reason this class exists. Both headers
// declare their delegate weak (UITextDragging.h:35, UITextDropping.h:24), and an associated object
// held with OBJC_ASSOCIATION_ASSIGN does not zero: a delegate deallocated before the control leaves
// a dangling slot that the adaptors then message, which is a crash and a wrong answer to what the
// header says. The library is built with ARC and the port's minimum for these members is 6.0, so
// weak references exist, and a box is what holds one: the association retains the box, the box's
// target is weak, and reading target after the delegate is gone is nil rather than a stale address.
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
    // A fresh box each time, so a replaced or cleared delegate leaves nothing pointing at the old
    // one; nil clears the slot outright rather than storing an empty box.
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
    // The adaptor accessors are the port's own and are declared on UIView, which both
    // UITextView and UITextField are; the protocols do not carry them and do not need to.
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

// The forwarders, twice. Each category is the SDK's class adopting the SDK's protocol, and each
// body is the one above with the class's own type.
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

// UITextDraggable and UITextDroppable are adopted by UITextView in the SDK's class extension.
@implementation UITextView (CharonTextDragDrop11)
CHARON_TEXT_DRAG_DROP_MEMBERS(UITextView)
@end

// And by UITextField, in its own class extension, which is why a text field is a drag and drop
// surface in exactly the way a text view is and gets the same members from the same bodies.
@implementation UITextField (CharonTextDragDrop11)
CHARON_TEXT_DRAG_DROP_MEMBERS(UITextField)
@end

// The two adaptors, and the questions they ask in the order the two headers give.
@implementation CharonTextDragAdaptor
@synthesize control = _control;

- (instancetype)initWithControl:(UIView<UITextDraggable, UITextDroppable> *)control
{
    if ((self = [super init]))
        _control = control;
    return self;
}

// The interaction asks the adaptor what is being dragged, and the adaptor asks the text's own drag
// delegate, which is the answer the SDK's protocol wants. Nothing is dragged when there is no
// delegate, which is why the session this receives may be nil and is never relied on here.
- (NSArray<UIDragItem *> *)dragInteraction:(UIDragInteraction *)interaction
                   itemsForBeginningSession:(id<UIDragSession>)session
{
    return [self charon_itemsForDragSession:session];
}

// What the text is: the drag delegate's own answer, and nothing is dragged when it gives none.
- (NSArray<UIDragItem *> *)charon_itemsForDragSession:(id<UIDragSession>)session
{
    id<UITextDragDelegate> delegate = self.control.textDragDelegate;
    SEL ask = @selector(textDraggableView:itemsForDrag:);
    if (![delegate respondsToSelector:ask])
        return nil;
    CharonTextDragRequest *request = [[CharonTextDragRequest alloc] initWithSession:session];
    if ([self.control isKindOfClass:[UITextView class]]) {
        // The text range the selection covers, which is what the protocol calls the drag range: a
        // range in the text, not an NSRange into a string.
        UITextView *text = (UITextView *)self.control;
        UITextPosition *start = [text positionFromPosition:text.beginningOfDocument offset:0];
        request.range = [text textRangeFromPosition:start toPosition:[text positionFromPosition:start offset:text.selectedRange.length]];
    }
    request.selected = request.range != nil;
    NSArray<UIDragItem *> *items = ((NSArray<UIDragItem *> * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self.control, request);
    request.suggested = items;
    return items.count ? items : nil;
}

// The picture the lift animates, from the drag delegate, and from the text itself when it has none:
// the release's own text is drawn into an image of the range, which is what a text drag shows.
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
    // A view is the preview and the control is the target, so the picture is the text and it is
    // aimed at the control it came from: the preview's view and its target are the same control, and
    // the lift animates from the range's own place because the parameters carry the visible path.
    UIDragPreviewParameters *parameters = [[UIDragPreviewParameters alloc] init];
    parameters.visiblePath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImageView *picture = [[UIImageView alloc] initWithImage:image];
    // A picture of the text, aimed at the control it came from: the picture is what travels and the
    // control is where it goes back to, and the parameters carry the visible path so the lift
    // animates from the range's own place.
    return [[UITargetedDragPreview alloc] initWithView:picture
                                       parameters:parameters
                                            target:[[UIDragPreviewTarget alloc] initWithContainer:text
                                                                                        center:CGPointMake(CGRectGetMidX([text bounds]),
                                                                                                          CGRectGetMidY([text bounds]))]];
}

// The lift, in the header's order: the preview, then the animator, then the session beginning.
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

// Whether this control will take the drop at all. A delegate that says no ends the sequence here,
// which is the header's own rule and why the gate comes first.
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

// What the drop would do where it is now, asked on every move, and then the drop itself.
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

// The two request objects.
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
