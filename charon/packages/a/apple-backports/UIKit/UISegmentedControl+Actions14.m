#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_actions_key, charon_trigger_key;

static Class charon_action_class(void)
{
    Class host = objc_getClass("UIAction");
    return host ?: [UIAction class];
}

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
        while (actions.count < control.numberOfSegments)
            [actions addObject:[NSNull null]];
    }
    if (!actions && create) {
        actions = [NSMutableArray array];
        for (NSInteger index = 0; index < control.numberOfSegments; index++)
            [actions addObject:[NSNull null]];
        objc_setAssociatedObject(control, &charon_actions_key, actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    for (NSUInteger index = 0; index < actions.count; index++) {
        UIAction *held = actions[index];
        if (index == segment || !charon_is_action(held))
            continue;
        if ([held.identifier isEqualToString:action.identifier])
            return;
    }
    NSUInteger before = self.numberOfSegments;
    [self insertSegmentWithTitle:action.image ? nil : action.title atIndex:segment animated:animated];
    NSUInteger added = self.numberOfSegments - before;
    if (!added)
        return;
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
