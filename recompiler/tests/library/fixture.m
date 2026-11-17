#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "RCFixture.h"
#include <dispatch/dispatch.h>

static NSInteger RCFCreated;

@implementation RCFToken
- (instancetype)initWithValue:(NSInteger)value
{
    self = [super init];
    if (self)
        _value = value;
    return self;
}
@end

@implementation RCFClient {
    NSInteger _seed;
    NSInteger _counter;
}

+ (RCFClient *)clientWithSeed:(NSInteger)seed
{
    RCFClient *client = [[RCFClient alloc] init];
    client->_seed = seed;
    RCFCreated++;
    return client;
}

- (NSInteger)bump
{
    return ++_counter;
}

- (NSInteger)seed
{
    return _seed;
}

- (NSInteger)describedLength
{
    return (NSInteger)[NSString stringWithFormat:@"client-%ld-%ld", (long)_seed, (long)_counter].length;
}

- (NSObject *)hostBundle
{
    return [NSBundle mainBundle];
}

- (RCFToken *)tokenForAction:(NSInteger)action
{
    return [[RCFToken alloc] initWithValue:_seed * 1000 + action * 10 + RCFCreated];
}

- (void)executeWithAction:(NSInteger)action completion:(void (^)(RCFToken *token, NSError *error))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion([self tokenForAction:action], nil);
    });
}

- (NSUInteger)threadNumber
{
    return [[NSThread currentThread] isMainThread] ? 1 : 2;
}
@end

@implementation RCFClient (RCFExtra)
- (NSInteger)categoryValue
{
    return [self seed] + 35;
}
@end

@implementation RCFHooked
@end

static void RCFNote(NSMutableArray *lines, NSString *name, BOOL passed);

static float RCFLevel;
static double RCFRatio;

@implementation RCFFloat
+ (void)install
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = [RCFFloat class];
        class_addMethod(cls, sel_registerName("scaleFloat:by:"), imp_implementationWithBlock(^float(id self_, float value, double factor) { return (float)(value * factor); }), "f@:fd");
        class_addMethod(cls, sel_registerName("mixInt:float:double:"), imp_implementationWithBlock(^double(id self_, int a, float b, double c) { return a + b + c; }), "d@:ifd");
        class_addMethod(cls, sel_registerName("tagFloat:int:"), imp_implementationWithBlock(^int(id self_, float a, int b) { return (int)(a * 2) + b; }), "i@:fi");
        class_addMethod(cls, sel_registerName("setLevel:"), imp_implementationWithBlock(^(id self_, float value) { RCFLevel = value; }), "v@:f");
        class_addMethod(cls, sel_registerName("level"), imp_implementationWithBlock(^float(id self_) { return RCFLevel; }), "f@:");
        class_addMethod(cls, sel_registerName("setRatio:"), imp_implementationWithBlock(^(id self_, double value) { RCFRatio = value; }), "v@:d");
        class_addMethod(cls, sel_registerName("ratio"), imp_implementationWithBlock(^double(id self_) { return RCFRatio; }), "d@:");
        class_addMethod(cls, sel_registerName("sumFloats:b:c:d:"), imp_implementationWithBlock(^float(id self_, float a, float b, float c, float d) { return a + b + c + d; }), "f@:ffff");
        class_addMethod(cls, sel_registerName("sumDoubles:b:c:"), imp_implementationWithBlock(^double(id self_, double a, double b, double c) { return a + b + c; }), "d@:ddd");
        class_addMethod(cls, sel_registerName("objectAfter:float:"), imp_implementationWithBlock(^id(id self_, id object, float value) { return value > 0 ? object : nil; }), "@@:@f");
    });
}

+ (NSArray *)run
{
    NSMutableArray *lines = [NSMutableArray array];
    [self install];
    id object = [[RCFFloat alloc] init];
    SEL scale = sel_registerName("scaleFloat:by:");
    RCFNote(lines, @"float.scale", ((float (*)(id, SEL, float, double))objc_msgSend)(object, scale, 1.5f, 4.0) == 6.0f);
    RCFNote(lines, @"float.negative", ((float (*)(id, SEL, float, double))objc_msgSend)(object, scale, -2.5f, 2.0) == -5.0f);
    RCFNote(lines, @"float.mix", ((double (*)(id, SEL, int, float, double))objc_msgSend)(object, sel_registerName("mixInt:float:double:"), 3, 0.5f, 0.25) == 3.75);
    RCFNote(lines, @"float.integer.after", ((int (*)(id, SEL, float, int))objc_msgSend)(object, sel_registerName("tagFloat:int:"), 2.0f, 7) == 11);
    ((void (*)(id, SEL, float))objc_msgSend)(object, sel_registerName("setLevel:"), 0.1f);
    RCFNote(lines, @"float.property", ((float (*)(id, SEL))objc_msgSend)(object, sel_registerName("level")) == 0.1f);
    ((void (*)(id, SEL, double))objc_msgSend)(object, sel_registerName("setRatio:"), 1.0e300);
    RCFNote(lines, @"double.property", ((double (*)(id, SEL))objc_msgSend)(object, sel_registerName("ratio")) == 1.0e300);
    RCFNote(lines, @"float.four", ((float (*)(id, SEL, float, float, float, float))objc_msgSend)(object, sel_registerName("sumFloats:b:c:d:"), 1.0f, 2.0f, 4.0f, 8.0f) == 15.0f);
    RCFNote(lines, @"double.three", ((double (*)(id, SEL, double, double, double))objc_msgSend)(object, sel_registerName("sumDoubles:b:c:"), 0.5, 0.25, 0.125) == 0.875);
    RCFNote(lines, @"float.object", ((id (*)(id, SEL, id, float))objc_msgSend)(object, sel_registerName("objectAfter:float:"), object, 1.0f) == object &&
                                    ((id (*)(id, SEL, id, float))objc_msgSend)(object, sel_registerName("objectAfter:float:"), object, -1.0f) == nil);
    return lines;
}
@end

static objc_hook_getClass RCFOldHook;
static NSInteger RCFHookCalls;

static BOOL RCFClassHook(const char *name, Class *outClass)
{
    RCFHookCalls++;
    if (strcmp(name, "RCFixture.Hooked") == 0) {
        *outClass = [RCFHooked class];
        return YES;
    }
    return RCFOldHook ? RCFOldHook(name, outClass) : NO;
}

static void RCFNote(NSMutableArray *lines, NSString *name, BOOL passed)
{
    [lines addObject:[NSString stringWithFormat:@"%@ %@", passed ? @"ok" : @"FAIL", name]];
}

@implementation RCFHook
+ (NSArray *)run
{
    NSMutableArray *lines = [NSMutableArray array];
    const char *dotted = "RCFixture.Hooked";
    RCFNote(lines, @"hook.absent", objc_getClass(dotted) == Nil && objc_lookUpClass(dotted) == Nil && NSClassFromString(@"RCFixture.Hooked") == Nil);
    objc_setHook_getClass(RCFClassHook, &RCFOldHook);
    Class sink = Nil;
    RCFNote(lines, @"hook.old", RCFOldHook != NULL && !RCFOldHook(dotted, &sink) && sink == Nil);
    Class hooked = [RCFHooked class];
    RCFNote(lines, @"hook.guest", objc_getClass(dotted) == hooked && objc_lookUpClass(dotted) == hooked && NSClassFromString(@"RCFixture.Hooked") == hooked);
    NSInteger asked = RCFHookCalls;
    BOOL exact = objc_getClass("RCFClient") == [RCFClient class] && NSClassFromString(@"RCFHooked") == hooked;
    RCFNote(lines, @"hook.exact", exact && RCFHookCalls == asked);
    RCFNote(lines, @"hook.unknown", objc_getClass("RCFixture.Nothing") == Nil && NSClassFromString(@"RCFixture.Nothing") == Nil && RCFHookCalls == asked + 2);
    return lines;
}
@end
