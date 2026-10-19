#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_actions_key, charon_trigger_key;

// The class an action has to be a kind of, which is **not** always the name in this file.
//
// Where the host has UIAction of its own - iOS 13 and up - the port's own class is CharonHostUIAction, and a
// host action is not a kind of it, so a comparison against `[UIAction class]` written here would reject every
// action the host hands this control, and the host hands it host actions freely: its own
// -initWithFrame:actions: builds them. Where the host has no UIAction the name in this file is the port's own
// class, and the runtime lookup finds it under its own name because the band's flags are not in play on a
// device. So the class is asked for at run time, and both a host action and a port action pass.
// YES between the host's -initWithFrame:actions: entering and leaving. The host's initialiser calls the
// port's -insertSegmentWithAction: from inside itself, and anything the port does to the control then lands in
// the middle of the host's own construction of it.
static Class charon_action_class(void)
{
    Class host = objc_getClass("UIAction");
    return host ?: [UIAction class];
}

// Whether something is an action at all, on **either** side. `charon_action_class()` is the host's class where
// the host has one, and the port's own action is CharonHostUIAction and is not a kind of it - so a comparison
// against that one class alone never recognised a port action, and the identifier lookup answered NSNotFound for
// an action the control was holding. `[UIAction class]` written here is the port's own class, so the two together
// cover both.
static BOOL charon_is_action(id object)
{
    return [object isKindOfClass:charon_action_class()] || [object isKindOfClass:[UIAction class]];
}

@interface CharonSegmentTrigger : NSObject
- (instancetype)initWithControl:(UISegmentedControl *)control;
- (void)charon_changed:(UISegmentedControl *)sender;
@end

@implementation CharonSegmentTrigger {
@private
    __weak UISegmentedControl *_control;
}

- (instancetype)initWithControl:(UISegmentedControl *)control
{
    if ((self = [super init]))
        _control = control;
    return self;
}

- (void)charon_changed:(UISegmentedControl *)sender
{
    UISegmentedControl *control = _control;
    NSInteger index = control.selectedSegmentIndex;
    NSMutableArray *actions = objc_getAssociatedObject(control, &charon_actions_key);
    if (index < 0 || (NSUInteger)index >= actions.count)
        return;
    id held = actions[(NSUInteger)index];
    if (charon_is_action(held))
        [(UIAction *)held charon_performWithSender:control];
}

@end

static NSMutableArray *charon_segment_actions(UISegmentedControl *control, BOOL create, BOOL bind)
{
    NSMutableArray *actions = objc_getAssociatedObject(control, &charon_actions_key);
    if (actions) {
        // One slot per segment, always. The array is created once and the +load guard stops the swizzles that
        // used to keep it in step, so without this a control only ever remembers the first action it was given -
        // which is what the per-slot dump showed, and why the port's identifier lookup answered NSNotFound for
        // actions the control was plainly holding.
        while (actions.count < control.numberOfSegments)
            [actions addObject:[NSNull null]];
    }
    if (!actions && create) {
        actions = [NSMutableArray array];
        for (NSInteger index = 0; index < control.numberOfSegments; index++)
            [actions addObject:[NSNull null]];
        objc_setAssociatedObject(control, &charon_actions_key, actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // The target is bound only where the port owns the control, and **never** from
        // -insertSegmentWithAction: - because the host's -initWithFrame:actions: calls that while it is still
        // building the control, and a control given a target in the middle of its own initialisation is a control
        // the host is still writing. A control the host builds with its own initializer therefore carries no
        // port target at all, and the host's own value-changed handling is what fires for it.
        if (bind) {
            CharonSegmentTrigger *trigger = [[CharonSegmentTrigger alloc] initWithControl:control];
            objc_setAssociatedObject(control, &charon_trigger_key, trigger, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [control addTarget:trigger action:@selector(charon_changed:) forControlEvents:UIControlEventValueChanged];
        }
    }
    return actions;
}

static void charon_check_identifier(NSMutableArray *actions, UIAction *action, NSUInteger except)
{
    for (NSUInteger index = 0; index < actions.count; index++) {
        UIAction *held = actions[index];
        if (index != except && charon_is_action(held) && [held.identifier isEqual:action.identifier])
            [NSException raise:NSInternalInconsistencyException
                        format:@"Attempting to set the action of segment at index %lu with an action whose identifier is the same as the segment at index %lu (action=%@). Identifiers are required to be unique.",
                               (unsigned long)except, (unsigned long)index, action];
    }
}

static void charon_apply(UISegmentedControl *control, UIAction *action, NSUInteger index)
{
    if (action.image) {
        [control setImage:action.image forSegmentAtIndex:(NSUInteger)index];
    } else {
        [control setTitle:action.title forSegmentAtIndex:(NSUInteger)index];
    }
}

static void (*charon_insert_title)(id, SEL, NSString *, NSUInteger, BOOL);
static void (*charon_insert_image)(id, SEL, UIImage *, NSUInteger, BOOL);
static void (*charon_remove)(id, SEL, NSUInteger, BOOL);
static void (*charon_remove_all)(id, SEL);

static void charon_shift_in(UISegmentedControl *control, NSUInteger index)
{
    NSMutableArray *actions = charon_segment_actions(control, NO, NO);
    if (actions)
        [actions insertObject:[NSNull null] atIndex:MIN(index, actions.count)];
}

@interface CharonSegmentedHooks : NSObject
@end

@implementation CharonSegmentedHooks

+ (void)load
{
    // These hooks replace four of the host's own public methods, and they install **always**, on every release.
    // They are not a step-in for the host's API: they are the port's only way of learning that the control
    // gained or lost a segment, and its bookkeeping of which action is in which slot is positional. A plain title
    // segment inserted at 0 shifts every action along on the host, and without this the port's array does not
    // shift with it - which is what the differential's last disagreement was, in a line the port's own lookups
    // now answer.
    //
    // What is release-dependent is the *public initializer*, not these: on a release that has
    // -initWithFrame:actions: the host's own must run, with a real UIAction, and the port's must not replace it.
    // That check is in -initWithFrame:actions: itself, where it belongs.
    Class cls = [UISegmentedControl class];
    Method title = class_getInstanceMethod(cls, @selector(insertSegmentWithTitle:atIndex:animated:));
    Method image = class_getInstanceMethod(cls, @selector(insertSegmentWithImage:atIndex:animated:));
    Method remove = class_getInstanceMethod(cls, @selector(removeSegmentAtIndex:animated:));
    Method removeAll = class_getInstanceMethod(cls, @selector(removeAllSegments));
    if (!title || !image || !remove || !removeAll)
        return;
    charon_insert_title = (void *)method_getImplementation(title);
    charon_insert_image = (void *)method_getImplementation(image);
    charon_remove = (void *)method_getImplementation(remove);
    charon_remove_all = (void *)method_getImplementation(removeAll);
    method_setImplementation(title, imp_implementationWithBlock(^(UISegmentedControl *control, NSString *text, NSUInteger index, BOOL animated) {
        NSInteger before = control.numberOfSegments;
        charon_insert_title(control, @selector(insertSegmentWithTitle:atIndex:animated:), text, index, animated);
        if (control.numberOfSegments > before)
            charon_shift_in(control, index);
    }));
    method_setImplementation(image, imp_implementationWithBlock(^(UISegmentedControl *control, UIImage *picture, NSUInteger index, BOOL animated) {
        NSInteger before = control.numberOfSegments;
        charon_insert_image(control, @selector(insertSegmentWithImage:atIndex:animated:), picture, index, animated);
        if (control.numberOfSegments > before)
            charon_shift_in(control, index);
    }));
    method_setImplementation(remove, imp_implementationWithBlock(^(UISegmentedControl *control, NSUInteger index, BOOL animated) {
        NSInteger before = control.numberOfSegments;
        charon_remove(control, @selector(removeSegmentAtIndex:animated:), index, animated);
        NSMutableArray *actions = charon_segment_actions(control, NO, NO);
        if (actions && control.numberOfSegments < before && index < actions.count)
            [actions removeObjectAtIndex:index];
    }));
    method_setImplementation(removeAll, imp_implementationWithBlock(^(UISegmentedControl *control) {
        charon_remove_all(control, @selector(removeAllSegments));
        [charon_segment_actions(control, NO, NO) removeAllObjects];
    }));
}

@end

@implementation UISegmentedControl (CharonActions14)

// The port's own implementation of a control made of actions, as a name of its own.
//
// Two callers, and the difference between them is the whole of it. On a release with no
// -initWithFrame:actions: of its own, the method below calls this after -initWithFrame: has returned, and it is
// how a control is built there. Where the host has one, that method is the one that must run - its own, with its
// own UIAction - and this is reachable only by name, which is what a differential needs: there the port's classes
// and the host's are in one process, and the public name is the host's.
//
// It is exported so that the harness can reach it. The package builds with hidden visibility, and a differential
// is a caller in the same process, not a linker of the package.
__attribute__((visibility("default"))) UISegmentedControl *charon_control_init_with_actions(UISegmentedControl *control, CGRect frame, NSArray<UIAction *> *actions)
{
    if (!(control = [control initWithFrame:frame]))
        return nil;
    control.selectedSegmentIndex = UISegmentedControlNoSegment;
    for (UIAction *action in actions)
        [control insertSegmentWithAction:action atIndex:(NSUInteger)control.numberOfSegments animated:NO];
    return control;
}

- (instancetype)initWithFrame:(CGRect)frame actions:(NSArray<UIAction *> *)actions
{
    // Where the host has an initialiser of its own, the port does not step in at all: the host's is the one the
    // release intends, and on 13 and up that is the path an application takes, with a real UIAction.
    if ([UISegmentedControl instancesRespondToSelector:@selector(initWithFrame:actions:)])
        return [self initWithFrame:frame];
    return charon_control_init_with_actions(self, frame, actions);
}

- (UIAction *)actionForSegmentAtIndex:(NSUInteger)segment
{
    NSMutableArray *actions = charon_segment_actions(self, NO, NO);
    if (segment >= actions.count)
        return nil;
    id held = actions[segment];
    return charon_is_action(held) ? held : nil;
}

- (void)setAction:(UIAction *)action forSegmentAtIndex:(NSUInteger)segment
{
    NSMutableArray *actions = charon_segment_actions(self, YES, YES);
    charon_check_identifier(actions, action, segment);
    if (segment >= actions.count)
        return;
    actions[segment] = [action copy];
    charon_apply(self, action, segment);
}

- (void)insertSegmentWithAction:(UIAction *)action atIndex:(NSUInteger)segment animated:(BOOL)animated
{
    NSMutableArray *actions = charon_segment_actions(self, YES, NO);
    charon_check_identifier(actions, action, segment);
    // Measured on the host, in probe-setaction.m: inserting an action whose identifier is **already** in the
    // control does nothing at all - the segment count does not change and neither action moves. A segment with
    // that identifier is already there, and the host does not add a second.
    for (NSUInteger index = 0; index < actions.count; index++) {
        UIAction *held = actions[index];
        if (index == segment || !charon_is_action(held))
            continue;
        if ([held.identifier isEqualToString:action.identifier])
            return;
    }
    // **The segment goes in first, and the bookkeeping second.** The other order loses the action: the array is
    // sized from the segment count, so before the insert the first one has none, the index clamps to -1, and the
    // action never lands in a slot - which is what the per-slot dump showed, every slot but one reading "not an
    // action", and the identifier the host still resolves the port could not.
    NSUInteger before = self.numberOfSegments;
    [self insertSegmentWithTitle:action.image ? nil : action.title atIndex:segment animated:animated];
    NSUInteger added = self.numberOfSegments - before;
    if (!added)
        return;
    // One slot per segment, brought up **here**: the ask that started this method saw the control's old length,
    // so growing there left the array one short and every index clamped down into the previous slot.
    while (actions.count < self.numberOfSegments)
        [actions addObject:[NSNull null]];
    NSUInteger written = MIN(segment, actions.count - 1);
    actions[written] = [action copy];
    if (action.image)
        [self setImage:action.image forSegmentAtIndex:written];
}

- (NSInteger)segmentIndexForActionIdentifier:(UIActionIdentifier)identifier
{
    NSMutableArray *actions = charon_segment_actions(self, NO, NO);
    for (NSUInteger index = 0; index < actions.count; index++) {
        UIAction *held = actions[index];
        if (charon_is_action(held) && [held.identifier isEqual:identifier])
            return (NSInteger)index;
    }
    return NSNotFound;
}

@end
