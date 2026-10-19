#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CharonControlProxy {
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

- (void)charon_fire:(id)sender
{
    [_action charon_performWithSender:sender ? sender : _control];
}

@end

@interface CharonActionEntry : NSObject {
@public
    UIAction *action;
    NSUInteger mask;
    CharonControlProxy *proxy;
}
@end

@implementation CharonActionEntry
@end

static const char charon_entries_key;

static NSMutableArray *charon_entries(UIControl *control, BOOL create)
{
    NSMutableArray *entries = objc_getAssociatedObject(control, &charon_entries_key);
    if (!entries && create) {
        entries = [NSMutableArray array];
        objc_setAssociatedObject(control, &charon_entries_key, entries, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return entries;
}

static UIControlEvents charon_primary_event(UIControl *control)
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

static UIControlEvents charon_effective(UIControl *control, NSUInteger mask)
{
    if (mask & UIControlEventPrimaryActionTriggered)
        mask |= charon_primary_event(control);
    return (UIControlEvents)mask;
}

static void charon_register(UIControl *control, CharonActionEntry *entry)
{
    [control addTarget:entry->proxy action:@selector(charon_fire:) forControlEvents:charon_effective(control, entry->mask)];
}

static void charon_unregister(UIControl *control, CharonActionEntry *entry)
{
    [control removeTarget:entry->proxy action:NULL forControlEvents:UIControlEventAllEvents];
}

static void charon_sync(UIControl *control)
{
    NSMutableArray *entries = charon_entries(control, NO);
    NSSet *targets = [control allTargets];
    for (CharonActionEntry *entry in [entries copy]) {
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

static void charon_require(BOOL condition, NSString *format, ...)
{
    if (condition)
        return;
    va_list arguments;
    va_start(arguments, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [NSException raise:NSInternalInconsistencyException format:@"%@", reason];
}

@implementation UIControl (CharonActions14)

- (instancetype)initWithFrame:(CGRect)frame primaryAction:(UIAction *)primaryAction
{
    if ((self = [self initWithFrame:frame]) && primaryAction)
        [self addAction:primaryAction forControlEvents:UIControlEventPrimaryActionTriggered];
    return self;
}

- (void)addAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents
{
    charon_require(action != nil, @"Attempt to set nil action with event mask:%08lx", (unsigned long)controlEvents);
    charon_require(controlEvents != 0, @"Attempt to set action '%@' with no event mask set", action);
    charon_sync(self);
    NSMutableArray *entries = charon_entries(self, YES);
    NSUInteger mask = (NSUInteger)controlEvents;
    for (CharonActionEntry *entry in [entries copy]) {
        if ([entry->action.identifier isEqual:action.identifier]) {
            mask |= entry->mask;
            charon_unregister(self, entry);
            [entries removeObjectIdenticalTo:entry];
        }
    }
    CharonActionEntry *added = [[CharonActionEntry alloc] init];
    added->action = action;
    added->mask = mask;
    added->proxy = [[CharonControlProxy alloc] initWithControl:self action:action];
    [entries addObject:added];
    charon_register(self, added);
}

- (void)charon_removeIdentifier:(UIActionIdentifier)identifier forControlEvents:(UIControlEvents)controlEvents
{
    charon_sync(self);
    NSMutableArray *entries = charon_entries(self, NO);
    for (CharonActionEntry *entry in [entries copy]) {
        if (![entry->action.identifier isEqual:identifier])
            continue;
        charon_unregister(self, entry);
        entry->mask &= ~(NSUInteger)controlEvents;
        if (entry->mask)
            charon_register(self, entry);
        else
            [entries removeObjectIdenticalTo:entry];
    }
}

- (void)removeAction:(UIAction *)action forControlEvents:(UIControlEvents)controlEvents
{
    if (action)
        [self charon_removeIdentifier:action.identifier forControlEvents:controlEvents];
}

- (void)removeActionForIdentifier:(UIActionIdentifier)actionIdentifier forControlEvents:(UIControlEvents)controlEvents
{
    if (actionIdentifier)
        [self charon_removeIdentifier:actionIdentifier forControlEvents:controlEvents];
}

- (void)enumerateEventHandlers:(void (NS_NOESCAPE ^)(UIAction *actionHandler, id target, SEL action, UIControlEvents controlEvents, BOOL *stop))iterator
{
    charon_sync(self);
    BOOL stop = NO;
    for (id target in [self allTargets]) {
        if ([target isKindOfClass:[CharonControlProxy class]])
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
    for (CharonActionEntry *entry in [charon_entries(self, NO) copy]) {
        iterator(entry->action, nil, NULL, (UIControlEvents)entry->mask, &stop);
        if (stop)
            return;
    }
}

- (void)sendAction:(UIAction *)action
{
    [action charon_performWithSender:self];
}

@end
