#import <Foundation/Foundation.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdio.h>

typedef id (*ObjectGetter)(id, SEL);
typedef id (*ObjectWithObject)(id, SEL, id);
typedef id (*ObjectWithSize)(id, SEL, CGSize);
typedef CGSize (*SizeGetter)(id, SEL);
typedef CGPoint (*PointGetter)(id, SEL);
typedef CGRect (*RectGetter)(id, SEL);
typedef CGFloat (*FloatGetter)(id, SEL);
typedef NSInteger (*IntGetter)(id, SEL);
typedef BOOL (*BoolGetter)(id, SEL);
typedef BOOL (*BoolWithObject)(id, SEL, id);
typedef void (*VoidObject)(id, SEL, id);
typedef void (*VoidSize)(id, SEL, CGSize);
typedef void (*VoidPoint)(id, SEL, CGPoint);
typedef void (*VoidFloat)(id, SEL, CGFloat);
typedef void (*VoidBool)(id, SEL, BOOL);
typedef void (*VoidInt)(id, SEL, NSInteger);
typedef void (*VoidVoid)(id, SEL);
typedef id (*ColorMaker)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat);

static SEL S(const char *name)
{
    return sel_registerName(name);
}

static void size(const char *label, CGSize s)
{
    printf("%s=(%g,%g)\n", label, s.width, s.height);
}

static void rect(const char *label, CGRect r)
{
    printf("%s=(%g,%g,%g,%g)\n", label, r.origin.x, r.origin.y, r.size.width, r.size.height);
}

static void point(const char *label, CGPoint p)
{
    printf("%s=(%g,%g)\n", label, p.x, p.y);
}

static void loggedDidChangeSize(id self, SEL _cmd, CGSize old)
{
    (void)_cmd;
    CGSize now = ((SizeGetter)objc_msgSend)(self, S("size"));
    printf("didChangeSize old=(%g,%g) new=(%g,%g)\n", old.width, old.height, now.width, now.height);
}

static void loggedUpdate(id self, SEL _cmd, double time)
{
    (void)self;
    (void)_cmd;
    printf("update %g\n", time);
}

static id loggedObject;

static void delegateUpdate(id self, SEL _cmd, double time, id scene)
{
    (void)self;
    (void)_cmd;
    (void)scene;
    printf("delegate update %g\n", time);
}

static NSString *nameOf(id object)
{
    return object == nil ? @"nil" : [NSString stringWithFormat:@"%@", NSStringFromClass([object class])];
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    Class sceneClass = NSClassFromString(@"SKScene");
    Class nodeClass = NSClassFromString(@"SKNode");

    id scene = ((ObjectWithSize)objc_msgSend)(sceneClass, S("sceneWithSize:"), CGSizeMake(320, 480));
    printf("class=%s\n", [nameOf(scene) UTF8String]);
    size("size", ((SizeGetter)objc_msgSend)(scene, S("size")));
    printf("scaleMode=%ld\n", (long)((IntGetter)objc_msgSend)(scene, S("scaleMode")));
    point("anchorPoint", ((PointGetter)objc_msgSend)(scene, S("anchorPoint")));
    printf("backgroundColor=%s\n", [[((ObjectGetter)objc_msgSend)(scene, S("backgroundColor")) description] UTF8String]);
    printf("delegate nil=%d\n", ((ObjectGetter)objc_msgSend)(scene, S("delegate")) == nil);
    printf("scene.scene==scene %d\n", ((ObjectGetter)objc_msgSend)(scene, S("scene")) == scene);
    printf("name nil=%d children=%lu\n", ((ObjectGetter)objc_msgSend)(scene, S("name")) == nil,
           (unsigned long)[((ObjectGetter)objc_msgSend)(scene, S("children")) count]);
    rect("frame", ((RectGetter)objc_msgSend)(scene, S("frame")));
    point("position", ((PointGetter)objc_msgSend)(scene, S("position")));
    printf("userData nil=%d\n", ((ObjectGetter)objc_msgSend)(scene, S("userData")) == nil);

    id bare = ((ObjectGetter)objc_msgSend)(((ObjectGetter)objc_msgSend)(sceneClass, S("alloc")), S("init"));
    size("init size", ((SizeGetter)objc_msgSend)(bare, S("size")));
    id sized = ((ObjectWithSize)objc_msgSend)(((ObjectGetter)objc_msgSend)(sceneClass, S("alloc")), S("initWithSize:"), CGSizeMake(100, 50));
    size("initWithSize size", ((SizeGetter)objc_msgSend)(sized, S("size")));

    ((VoidPoint)objc_msgSend)(sized, S("setAnchorPoint:"), CGPointMake(0.5, 0.25));
    rect("frame with anchor (0.5,0.25)", ((RectGetter)objc_msgSend)(sized, S("frame")));
    ((VoidSize)objc_msgSend)(sized, S("setSize:"), CGSizeMake(40, 20));
    rect("frame after size (40,20)", ((RectGetter)objc_msgSend)(sized, S("frame")));
    ((VoidPoint)objc_msgSend)(sized, S("setAnchorPoint:"), CGPointMake(0, 0));
    rect("frame at anchor zero", ((RectGetter)objc_msgSend)(sized, S("frame")));

    ((VoidPoint)objc_msgSend)(scene, S("setPosition:"), CGPointMake(7, 9));
    point("position after set", ((PointGetter)objc_msgSend)(scene, S("position")));
    ((VoidFloat)objc_msgSend)(scene, S("setXScale:"), 3);
    printf("xScale after set=%g\n", ((FloatGetter)objc_msgSend)(scene, S("xScale")));
    ((VoidFloat)objc_msgSend)(scene, S("setYScale:"), 3);
    printf("yScale after set=%g\n", ((FloatGetter)objc_msgSend)(scene, S("yScale")));
    ((VoidFloat)objc_msgSend)(scene, S("setScale:"), 4);
    printf("xScale after setScale=%g yScale=%g\n", ((FloatGetter)objc_msgSend)(scene, S("xScale")),
           ((FloatGetter)objc_msgSend)(scene, S("yScale")));
    ((VoidFloat)objc_msgSend)(scene, S("setZRotation:"), 1);
    printf("zRotation after set=%g\n", ((FloatGetter)objc_msgSend)(scene, S("zRotation")));
    ((VoidFloat)objc_msgSend)(scene, S("setZPosition:"), 5);
    printf("zPosition after set=%g\n", ((FloatGetter)objc_msgSend)(scene, S("zPosition")));
    ((VoidFloat)objc_msgSend)(scene, S("setAlpha:"), 0.25);
    printf("alpha after set=%g\n", ((FloatGetter)objc_msgSend)(scene, S("alpha")));
    ((VoidBool)objc_msgSend)(scene, S("setHidden:"), YES);
    printf("hidden after set=%d\n", ((BoolGetter)objc_msgSend)(scene, S("isHidden")));
    ((VoidFloat)objc_msgSend)(scene, S("setSpeed:"), 2);
    printf("speed after set=%g\n", ((FloatGetter)objc_msgSend)(scene, S("speed")));
    printf("scale refusal done\n");

    Class logClass = objc_allocateClassPair(sceneClass, "LogScene", 0);
    class_addMethod(logClass, S("didChangeSize:"), (IMP)loggedDidChangeSize, "v@:{CGSize=dd}");
    class_addMethod(logClass, S("update:"), (IMP)loggedUpdate, "v@:d");
    objc_registerClassPair(logClass);
    id logged = ((ObjectWithSize)objc_msgSend)(logClass, S("sceneWithSize:"), CGSizeMake(10, 10));
    ((VoidSize)objc_msgSend)(logged, S("setSize:"), CGSizeMake(20, 30));
    ((VoidSize)objc_msgSend)(logged, S("setSize:"), CGSizeMake(20, 30));
    printf("same size set again\n");
    ((VoidVoid)objc_msgSend)(logged, S("didEvaluateActions"));
    printf("didEvaluateActions returned\n");
    ((VoidVoid)objc_msgSend)(logged, S("didSimulatePhysics"));
    printf("didSimulatePhysics returned\n");
    ((void (*)(id, SEL, double))objc_msgSend)(logged, S("update:"), 1.5);

    ((VoidInt)objc_msgSend)(scene, S("setScaleMode:"), 3);
    printf("scaleMode after set 3=%ld\n", (long)((IntGetter)objc_msgSend)(scene, S("scaleMode")));
    ((VoidObject)objc_msgSend)(scene, S("setBackgroundColor:"), ((ColorMaker)objc_msgSend)(NSClassFromString(@"NSColor"), S("colorWithDeviceRed:green:blue:alpha:"), 1, 0, 0, 1));
    printf("backgroundColor after set=%s\n", [[((ObjectGetter)objc_msgSend)(scene, S("backgroundColor")) description] UTF8String]);

    id plainNode = ((ObjectGetter)objc_msgSend)(nodeClass, S("node"));
    printf("plain node scene nil=%d\n", ((ObjectGetter)objc_msgSend)(plainNode, S("scene")) == nil);
    id child = ((ObjectGetter)objc_msgSend)(nodeClass, S("node"));
    id grandchild = ((ObjectGetter)objc_msgSend)(nodeClass, S("node"));
    ((VoidObject)objc_msgSend)(scene, S("addChild:"), child);
    ((VoidObject)objc_msgSend)(child, S("addChild:"), grandchild);
    printf("child scene==scene %d\n", ((ObjectGetter)objc_msgSend)(child, S("scene")) == scene);
    printf("grandchild scene==scene %d\n", ((ObjectGetter)objc_msgSend)(grandchild, S("scene")) == scene);
    ((VoidObject)objc_msgSend)(scene, S("removeChildrenInArray:"), @[child]);
    printf("removed child scene nil=%d\n", ((ObjectGetter)objc_msgSend)(child, S("scene")) == nil);

    Class delegateClass = objc_allocateClassPair([NSObject class], "LogDelegate", 0);
    class_addMethod(delegateClass, S("update:forScene:"), (IMP)delegateUpdate, "v@:d@");
    objc_registerClassPair(delegateClass);
    @autoreleasepool {
        id delegate = [[delegateClass alloc] init];
        ((VoidObject)objc_msgSend)(scene, S("setDelegate:"), delegate);
        printf("delegate set==delegate %d\n", ((ObjectGetter)objc_msgSend)(scene, S("delegate")) == delegate);
        printf("delegate responds to update:forScene: %d\n", [delegate respondsToSelector:S("update:forScene:")]);
    }
    printf("delegate released nil=%d\n", ((ObjectGetter)objc_msgSend)(scene, S("delegate")) == nil);
    printf("responds didApplyConstraints=%d didFinishUpdate=%d\n",
           [logged respondsToSelector:S("didApplyConstraints")], [logged respondsToSelector:S("didFinishUpdate")]);
    return 0;
}
