#import "RevenantGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCPhysicalInputProfile {
    __weak id<GCDevice> _device;
    NSDictionary<NSString *, GCControllerElement *> *_elements;
    NSSet<GCControllerElement *> *_allElements;
    NSArray<GCControllerElement *> *_ordered;
}

- (instancetype)initWithRevenantSpecs:(NSArray<NSDictionary *> *)specs
{
    self = [super init];
    if (!self)
        return nil;
    NSMutableDictionary *byAlias = [NSMutableDictionary dictionary];
    NSMutableSet *all = [NSMutableSet set];
    NSMutableArray *ranked = [NSMutableArray array];
    for (NSDictionary *spec in specs) {
        NSString *kind = spec[@"kind"];
        Class elementClass;
        if ([kind isEqual:@"dpad"])
            elementClass = [GCControllerDirectionPad class];
        else if ([kind isEqual:@"cursor"])
            elementClass = [GCDeviceCursor class];
        else if ([kind isEqual:@"axis"])
            elementClass = [GCControllerAxisInput class];
        else if ([kind isEqual:@"trigger"])
            elementClass = [GCDualSenseAdaptiveTrigger class];
        else
            elementClass = [GCControllerButtonInput class];
        GCControllerElement *element = [[elementClass alloc] initWithRevenantSpec:spec];
        [element revenant_attachToProfile:self];
        for (NSString *alias in spec[@"aliases"])
            byAlias[alias] = element;
        [all addObject:element];
        if ([spec[@"order"] integerValue] >= 0)
            [ranked addObject:@[spec[@"order"], element]];
    }
    [ranked sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
        return [a[0] compare:b[0]];
    }];
    NSMutableArray *ordered = [NSMutableArray array];
    for (NSArray *pair in ranked)
        [ordered addObject:pair[1]];
    _ordered = ordered;
    for (NSDictionary *spec in specs) {
        id collection = spec[@"collection"];
        if (collection != [NSNull null] && collection)
            [byAlias[[spec[@"aliases"] firstObject]] revenant_setCollection:byAlias[collection]];
    }
    for (GCControllerElement *element in all) {
        if (![element isKindOfClass:[GCControllerDirectionPad class]])
            continue;
        NSString *name = element.aliases.anyObject;
        GCControllerAxisInput *x = (id)byAlias[[name stringByAppendingString:@" X Axis"]];
        GCControllerAxisInput *y = (id)byAlias[[name stringByAppendingString:@" Y Axis"]];
        GCControllerButtonInput *up = (id)byAlias[[name stringByAppendingString:@" Up"]];
        GCControllerButtonInput *down = (id)byAlias[[name stringByAppendingString:@" Down"]];
        GCControllerButtonInput *left = (id)byAlias[[name stringByAppendingString:@" Left"]];
        GCControllerButtonInput *right = (id)byAlias[[name stringByAppendingString:@" Right"]];
        [(GCControllerDirectionPad *)element revenant_linkXAxis:x yAxis:y up:up down:down left:left right:right];
        [x revenant_linkPositive:right negative:left dpad:(GCControllerDirectionPad *)element];
        [y revenant_linkPositive:up negative:down dpad:(GCControllerDirectionPad *)element];
    }
    _elements = byAlias;
    _allElements = all;
    return self;
}

- (void)revenant_setDevice:(id<GCDevice>)device
{
    _device = device;
}

- (id<GCDevice>)device
{
    return _device;
}

- (GCControllerElement *)revenant_elementNamed:(NSString *)alias
{
    return _elements[alias];
}

- (NSTimeInterval)lastEventTimestamp
{
    return 0;
}

- (BOOL)hasRemappedElements
{
    return NO;
}

- (NSDictionary<NSString *, GCControllerElement *> *)revenant_elementsOfClass:(Class)elementClass
{
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    [_elements enumerateKeysAndObjectsUsingBlock:^(NSString *key, GCControllerElement *element, BOOL *stop) {
        if ([element isKindOfClass:elementClass])
            found[key] = element;
    }];
    return found;
}

- (NSSet *)revenant_allOfClass:(Class)elementClass
{
    NSMutableSet *found = [NSMutableSet set];
    for (GCControllerElement *element in _allElements) {
        if ([element isKindOfClass:elementClass])
            [found addObject:element];
    }
    return found;
}

- (NSDictionary<NSString *, GCControllerElement *> *)elements
{
    return _elements;
}

- (NSDictionary<NSString *, GCControllerButtonInput *> *)buttons
{
    return (id)[self revenant_elementsOfClass:[GCControllerButtonInput class]];
}

- (NSDictionary<NSString *, GCControllerAxisInput *> *)axes
{
    return (id)[self revenant_elementsOfClass:[GCControllerAxisInput class]];
}

- (NSDictionary<NSString *, GCControllerDirectionPad *> *)dpads
{
    return (id)[self revenant_elementsOfClass:[GCControllerDirectionPad class]];
}

- (NSDictionary *)touchpads
{
    return @{};
}

- (NSSet<GCControllerElement *> *)allElements
{
    return _allElements;
}

- (NSSet<GCControllerButtonInput *> *)allButtons
{
    return [self revenant_allOfClass:[GCControllerButtonInput class]];
}

- (NSSet<GCControllerAxisInput *> *)allAxes
{
    return [self revenant_allOfClass:[GCControllerAxisInput class]];
}

- (NSSet<GCControllerDirectionPad *> *)allDpads
{
    return [self revenant_allOfClass:[GCControllerDirectionPad class]];
}

- (NSSet *)allTouchpads
{
    return [NSSet set];
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return _elements[key];
}

- (instancetype)capture
{
    GCPhysicalInputProfile *copy = [[[self class] alloc] init];
    [copy setStateFromPhysicalInput:self];
    return copy;
}

- (void)setStateFromPhysicalInput:(GCPhysicalInputProfile *)physicalInput
{
    for (GCControllerElement *element in _ordered) {
        GCControllerElement *source = physicalInput.elements[element.aliases.anyObject];
        if ([element isKindOfClass:[GCControllerDirectionPad class]])
            [(GCControllerDirectionPad *)element setValueForXAxis:[(GCControllerDirectionPad *)source xAxis].value yAxis:[(GCControllerDirectionPad *)source yAxis].value];
        else
            [(GCControllerButtonInput *)element setValue:[(GCControllerButtonInput *)source value]];
    }
}

- (NSString *)mappedElementAliasForPhysicalInputName:(NSString *)inputName
{
    return inputName;
}

- (NSSet<NSString *> *)mappedPhysicalInputNamesForElementAlias:(NSString *)elementAlias
{
    return [NSSet setWithObject:elementAlias];
}

@end
