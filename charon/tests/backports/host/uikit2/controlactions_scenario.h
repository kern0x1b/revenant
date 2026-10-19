#import "uirest.h"

@interface Target : NSObject
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation Target

- (instancetype)init
{
    if ((self = [super init]))
        self.log = [NSMutableArray array];
    return self;
}

- (void)go:(id)sender
{
    [self.log addObject:[NSString stringWithFormat:@"target go %@", NSStringFromClass([sender class])]];
}

@end

@interface Driver : NSObject
@property (nonatomic, strong) NSMutableArray *lines;
@property (nonatomic, strong) NSMutableArray *fired;
@property (nonatomic, strong) Class actionClass;
@end

@implementation Driver

- (id)action:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier
{
    __weak Driver *weak = self;
    return ((id (*)(Class, SEL, NSString *, UIImage *, NSString *, id))objc_msgSend)(self.actionClass, @selector(actionWithTitle:image:identifier:handler:), title, image, identifier, ^(id action) {
        [weak.fired addObject:[NSString stringWithFormat:@"fired %@ sender %@", title, NSStringFromClass([[action sender] class])]];
    });
}

- (void)add:(UIControl *)control action:(id)action events:(UIControlEvents)events
{
    [(UIControl *)control addAction:action forControlEvents:events];
}

- (void)remove:(UIControl *)control action:(id)action events:(UIControlEvents)events
{
    [control removeAction:action forControlEvents:events];
}

- (void)removeIdentifier:(NSString *)identifier control:(UIControl *)control events:(UIControlEvents)events
{
    [control removeActionForIdentifier:identifier forControlEvents:events];
}

- (NSArray *)handlers:(UIControl *)control
{
    NSMutableArray *rows = [NSMutableArray array];
    [control enumerateEventHandlers:^(id action, id target, SEL sel, UIControlEvents events, BOOL *stop) {
        [rows addObject:[NSString stringWithFormat:@"%@ %@ %@ 0x%lx", action ? [action title] : @"-", target ? NSStringFromClass([target class]) : @"-", sel ? NSStringFromSelector(sel) : @"-", (unsigned long)events]];
    }];
    return [rows sortedArrayUsingSelector:@selector(compare:)];
}

- (id)primary:(Class)cls frame:(CGRect)frame action:(id)action
{
    return [(UIControl *)[cls alloc] initWithFrame:frame primaryAction:action];
}

- (void)log:(NSString *)label control:(UIControl *)control events:(UIControlEvents)events
{
    [self.fired removeAllObjects];
    [control sendActionsForControlEvents:events];
    NSMutableArray *once = [NSMutableArray array];
    for (NSString *entry in self.fired) {
        if (![once containsObject:entry])
            [once addObject:entry];
    }
    [self.lines addObject:[NSString stringWithFormat:@"%@: %@", label, [once componentsJoinedByString:@" | "]]];
}

@end

static NSArray *control_scenario(Class actionClass)
{
    Driver *d = [[Driver alloc] init];
    d.lines = [NSMutableArray array];
    d.fired = [NSMutableArray array];
    d.actionClass = actionClass;
    Target *target = [[Target alloc] init];
    UIImage *image = [[UIImage alloc] init];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    id a1 = [d action:@"a1" image:nil identifier:@"id1"], a2 = [d action:@"a2" image:nil identifier:@"id2"], a1b = [d action:@"a1b" image:nil identifier:@"id1"];
    [d add:b action:a1 events:UIControlEventTouchUpInside];
    [b addTarget:target action:@selector(go:) forControlEvents:UIControlEventTouchUpInside | UIControlEventValueChanged];
    [d add:b action:a2 events:UIControlEventTouchUpInside | UIControlEventTouchDown];
    [d.lines addObject:[@"initial " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];
    [d log:@"touch up inside" control:b events:UIControlEventTouchUpInside];
    [d log:@"touch down" control:b events:UIControlEventTouchDown];
    [d add:b action:a1b events:UIControlEventTouchUpInside];
    [d.lines addObject:[@"same identifier " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];
    [d log:@"touch up inside" control:b events:UIControlEventTouchUpInside];
    [d add:b action:a2 events:UIControlEventTouchUpInside];
    [d.lines addObject:[@"same action again " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];
    [d remove:b action:a1 events:UIControlEventTouchUpInside];
    [d.lines addObject:[@"remove by equal identifier " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];
    [d removeIdentifier:@"id2" control:b events:UIControlEventTouchDown];
    [d.lines addObject:[@"remove identifier for one event " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];
    [d log:@"touch down after" control:b events:UIControlEventTouchDown];
    [d removeIdentifier:@"id2" control:b events:UIControlEventTouchUpInside];
    [d.lines addObject:[@"remove identifier " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];
    [d removeIdentifier:@"none" control:b events:UIControlEventTouchUpInside];
    [b removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [d.lines addObject:[@"after remove target " stringByAppendingString:[[d handlers:b] componentsJoinedByString:@" ; "]]];

    [d.lines addObject:ur_line(@"nil action", ur_raised(^id { [d add:b action:nil events:UIControlEventTouchUpInside]; return @"no"; }))];
    [d.lines addObject:ur_line(@"no events", ur_raised(^id { [d add:b action:a1 events:0]; return @"no"; }))];

    UIButton *primary = [d primary:[UIButton class] frame:CGRectMake(0, 0, 10, 10) action:[d action:@"P" image:image identifier:@"pid"]];
    [d.lines addObject:ur_line(@"primary button", @[[[d handlers:primary] componentsJoinedByString:@" ; "], [primary titleForState:UIControlStateNormal] ?: @"nil", ur_yes([primary imageForState:UIControlStateNormal] != nil)])];
    [d log:@"primary: touch up inside" control:primary events:UIControlEventTouchUpInside];
    [d log:@"primary: primary action triggered" control:primary events:UIControlEventPrimaryActionTriggered];
    [d log:@"primary: value changed" control:primary events:UIControlEventValueChanged];
    NSArray *classes = @[[UISwitch class], [UITextField class], [UISlider class], [UIStepper class], [UISegmentedControl class], [UIControl class]];
    NSArray *events = @[@(UIControlEventValueChanged), @(UIControlEventEditingDidEndOnExit), @(UIControlEventValueChanged), @(UIControlEventValueChanged), @(UIControlEventValueChanged), @(UIControlEventTouchUpInside)];
    for (NSUInteger index = 0; index < classes.count; index++) {
        UIControl *control = [d primary:classes[index] frame:CGRectMake(0, 0, 100, 30) action:[d action:@"Q" image:nil identifier:@"qid"]];
        [d.lines addObject:[NSString stringWithFormat:@"primary %@ handlers %@", classes[index], [[d handlers:control] componentsJoinedByString:@" ; "]]];
        UIControlEvents all[] = {UIControlEventValueChanged, UIControlEventEditingDidEndOnExit, UIControlEventTouchUpInside, UIControlEventPrimaryActionTriggered, UIControlEventTouchDown};
        for (int e = 0; e < 5; e++)
            [d log:[NSString stringWithFormat:@"primary %@ event 0x%lx", classes[index], (unsigned long)all[e]] control:control events:all[e]];
        (void)events;
    }
    UIButton *menuless = [UIButton buttonWithType:UIButtonTypeCustom];
    [d add:menuless action:a1 events:UIControlEventAllTouchEvents];
    [d.lines addObject:[@"all touch events " stringByAppendingString:[[d handlers:menuless] componentsJoinedByString:@" ; "]]];
    UIButton *weakHolder = [UIButton buttonWithType:UIButtonTypeCustom];
    [d.fired removeAllObjects];
    [weakHolder sendAction:a2];
    [d.lines addObject:[@"sendAction " stringByAppendingString:[d.fired componentsJoinedByString:@" | "]]];
    NSMutableArray *flat = [NSMutableArray array];
    for (NSString *entry in d.lines)
        [flat addObject:[entry stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return flat;
}

