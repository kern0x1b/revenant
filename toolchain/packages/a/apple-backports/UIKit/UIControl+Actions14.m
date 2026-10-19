#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation RevenantControlProxy {
@private
    __weak UIControl *_control;
    UIAction *_action;
}

- (instancetype)initWithControl:(UIControl *)control action:(UIAction *)action
{
    if ((self = [super init])) {
        _control = control;
        _action = action;
    }
    return self;
}

- (UIControl *)control
{
    return _control;
}

- (void)setControl:(UIControl *)control
{
    _control = control;
}

- (UIAction *)action
{
    return _action;
}

- (void)setAction:(UIAction *)action
{
    _action = action;
}

- (void)revenant_fire:(id)sender
{
    [_action revenant_performWithSender:sender ? sender : _control];
}

@end

@interface RevenantActionEntry : NSObject {
@public
    UIAction *action;
    NSUInteger mask;
    RevenantControlProxy *proxy;
}
@end

@implementation RevenantActionEntry
@end

static const char revenant_entries_key;

static NSMutableArray *revenant_entries(UIControl *control, BOOL create)
{
    NSMutableArray *entries = objc_getAssociatedObject(control, &revenant_entries_key);
    if (!entries && create) {
        entries = [NSMutableArray array];
        objc_setAssociatedObject(control, &revenant_entries_key, entries, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return entries;
}

static UIControlEvents revenant_primary_event(UIControl *control)
{
    if ([control isKindOfClass:[UIButton class]])
        return UIControlEventTouchUpInside;
    if ([control isKindOfClass:[UITextField class]])
        return UIControlEventEditingDidEndOnExit;
    if ([control isKindOfClass:[UISwitch class]] || [control isKindOfClass:[UISlider class]] || [control isKindOfClass:[UIStepper class]] ||
        [control isKindOfClass:[UISegmentedControl class]] || [control isKindOfClass:[UIPageControl class]] || [control isKindOfClass:[UIDatePicker class]])
        return UIControlEventValueChanged;
    return 0;
}

static UIControlEvents revenant_effective(UIControl *control, NSUInteger mask)
{
    if (mask & UIControlEventPrimaryActionTriggered)
        mask |= revenant_primary_event(control);
    return (UIControlEvents)mask;
}

static void revenant_register(UIControl *control, RevenantActionEntry *entry)
{
    [control addTarget:entry->proxy action:@selector(revenant_fire:) forControlEvents:revenant_effective(control, entry->mask)];
}

static void revenant_unregister(UIControl *control, RevenantActionEntry *entry)
{
    [control removeTarget:entry->proxy action:NULL forControlEvents:UIControlEventAllEvents];
}

static void revenant_sync(UIControl *control)
{
    NSMutableArray *entries = revenant_entries(control, NO);
    NSSet *targets = [control allTargets];
    for (RevenantActionEntry *entry in [entries copy]) {
        if (![targets containsObject:entry->proxy]) {
            [entries removeObjectIdenticalTo:entry];
            continue;
        }
        NSUInteger kept = 0;
        for (NSUInteger bit = 0; bit < 32; bit++) {
            NSUInteger single = (NSUInteger)1 << bit;
            if (!(entry->mask & single))
                continue;
            UIControlEvents check = single == UIControlEventPrimaryActionTriggered ? UIControlEventPrimaryActionTriggered : (UIControlEvents)single;
            if ([control actionsForTarget:entry->proxy forControlEvent:check])
                kept |= single;
        }
        if (!kept)
            [entries removeObjectIdenticalTo:entry];
        else
            entry->mask = kept;
    }
}

static void revenant_require(BOOL condition, NSString *format, ...)
{
    if (condition)
        return;
    va_list arguments;
    va_start(arguments, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [NSException raise:NSInternalInconsistencyException format:@"%@", reason];
}

@implementation UIControl (RevenantActions14)

- (instancetype)initWithFrame:(CGRect)frame primaryAction:(UIAction *)primaryAction
{
    if ((self = [self initWithFrame:frame]) && primaryAction)
        [self addAction:primaryAction forControlEvents:UIControlEventPrimaryActionTriggered];
    return self;
}

- (void)addAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents
{
    revenant_require(action != nil, @"Attempt to set nil action with event mask:%08lx", (unsigned long)controlEvents);
    revenant_require(controlEvents != 0, @"Attempt to set action '%@' with no event mask set", action);
    revenant_sync(self);
    NSMutableArray *entries = revenant_entries(self, YES);
    NSUInteger mask = (NSUInteger)controlEvents;
    for (RevenantActionEntry *entry in [entries copy]) {
        if ([entry->action.identifier isEqual:action.identifier]) {
            mask |= entry->mask;
            revenant_unregister(self, entry);
            [entries removeObjectIdenticalTo:entry];
        }
    }
    RevenantActionEntry *added = [[RevenantActionEntry alloc] init];
    added->action = action;
    added->mask = mask;
    added->proxy = [[RevenantControlProxy alloc] initWithControl:self action:action];
    [entries addObject:added];
    revenant_register(self, added);
}

- (void)revenant_removeIdentifier:(UIActionIdentifier)identifier forControlEvents:(UIControlEvents)controlEvents
{
    revenant_sync(self);
    NSMutableArray *entries = revenant_entries(self, NO);
    for (RevenantActionEntry *entry in [entries copy]) {
        if (![entry->action.identifier isEqual:identifier])
            continue;
        revenant_unregister(self, entry);
        entry->mask &= ~(NSUInteger)controlEvents;
        if (entry->mask)
            revenant_register(self, entry);
        else
            [entries removeObjectIdenticalTo:entry];
    }
}

- (void)removeAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents
{
    if (action)
        [self revenant_removeIdentifier:action.identifier forControlEvents:controlEvents];
}

- (void)removeActionForIdentifier:(UIActionIdentifier)actionIdentifier forControlEvents:(UIControlEvents)controlEvents
{
    if (actionIdentifier)
        [self revenant_removeIdentifier:actionIdentifier forControlEvents:controlEvents];
}

- (void)enumerateEventHandlers:(void (NS_NOESCAPE ^)(UIAction *actionHandler, id target, SEL action, UIControlEvents controlEvents, BOOL *stop))iterator
{
    revenant_sync(self);
    BOOL stop = NO;
    for (id target in [self allTargets]) {
        if ([target isKindOfClass:[RevenantControlProxy class]])
            continue;
        id real = [target isKindOfClass:[NSNull class]] ? nil : target;
        NSMutableArray *order = [NSMutableArray array];
        NSMutableDictionary *masks = [NSMutableDictionary dictionary];
        for (NSUInteger bit = 0; bit < 32; bit++) {
            NSUInteger single = (NSUInteger)1 << bit;
            for (NSString *name in [self actionsForTarget:real forControlEvent:(UIControlEvents)single]) {
                if (!masks[name])
                    [order addObject:name];
                masks[name] = @([masks[name] unsignedIntegerValue] | single);
            }
        }
        for (NSString *name in order) {
            iterator(nil, real, NSSelectorFromString(name), (UIControlEvents)[masks[name] unsignedIntegerValue], &stop);
            if (stop)
                return;
        }
    }
    for (RevenantActionEntry *entry in [revenant_entries(self, NO) copy]) {
        iterator(entry->action, nil, NULL, (UIControlEvents)entry->mask, &stop);
        if (stop)
            return;
    }
}

- (void)sendAction:(UIAction *)action
{
    [action revenant_performWithSender:self];
}

@end
