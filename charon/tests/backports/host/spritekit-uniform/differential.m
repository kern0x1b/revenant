// The SKUniform of iOS 8, the port against the host's own SpriteKit, over the same scenarios. The program reaches the
// class only through the Objective-C runtime (NSClassFromString and objc_msgSend), so the same source builds against
// the host's SpriteKit framework (the oracle) and against the port's SpriteKit8.o with no SpriteKit framework linked.
// Nothing here writes an expected value: each scenario prints what the class answers, and run.sh compares the two runs.
//
// A texture is not used as a payload here: the host's SKTexture is its own class and the port has none, so the
// texture scenarios pass nil, and the texture round trip measured against a real SKTexture is in facts/SpriteKit/SKUniform.md.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef id (*NameFactory)(id, SEL, NSString *);
typedef id (*NameTextureFactory)(id, SEL, NSString *, id);
typedef id (*NameFloatFactory)(id, SEL, NSString *, float);
typedef NSInteger (*Getter)(id, SEL);
typedef float (*FloatGetter)(id, SEL);
typedef void (*FloatSetter)(id, SEL, float);
typedef void (*ObjectSetter)(id, SEL, id);
typedef id (*ObjectGetter)(id, SEL);
typedef BOOL (*BoolGetter)(id, SEL);
typedef id (*Initializer)(id, SEL, NSString *);

static Class uniformClass;

static void show(const char *label, id uniform)
{
    if (uniform == nil) {
        printf("%s: nil\n", label);
        return;
    }
    NSString *name = ((ObjectGetter)objc_msgSend)(uniform, NSSelectorFromString(@"name"));
    NSInteger type = ((Getter)objc_msgSend)(uniform, NSSelectorFromString(@"uniformType"));
    float value = ((FloatGetter)objc_msgSend)(uniform, NSSelectorFromString(@"floatValue"));
    id texture = ((ObjectGetter)objc_msgSend)(uniform, NSSelectorFromString(@"textureValue"));
    printf("%s: class=%s name=%s type=%ld float=%.9g texture=%s\n", label, class_getName([uniform class]),
           name ? [name UTF8String] : "(nil)", (long)type, value, texture ? "set" : "nil");
}

static id make(NSString *name)
{
    return ((NameFactory)objc_msgSend)(uniformClass, NSSelectorFromString(@"uniformWithName:"), name);
}

static id makeTexture(NSString *name)
{
    return ((NameTextureFactory)objc_msgSend)(uniformClass, NSSelectorFromString(@"uniformWithName:texture:"), name, nil);
}

static id makeFloat(NSString *name, float value)
{
    return ((NameFloatFactory)objc_msgSend)(uniformClass, NSSelectorFromString(@"uniformWithName:float:"), name, value);
}

static void setFloat(id uniform, float value)
{
    ((FloatSetter)objc_msgSend)(uniform, NSSelectorFromString(@"setFloatValue:"), value);
}

static void setTexture(id uniform, id texture)
{
    ((ObjectSetter)objc_msgSend)(uniform, NSSelectorFromString(@"setTextureValue:"), texture);
}

int main(void)
{
    @autoreleasepool {
        uniformClass = NSClassFromString(@"SKUniform");
        if (uniformClass == Nil) {
            printf("SKUniform: absent\n");
            return 1;
        }
        printf("supportsSecureCoding=%d\n", ((BoolGetter)objc_msgSend)(uniformClass, NSSelectorFromString(@"supportsSecureCoding")));

        show("uniformWithName:", make(@"a"));
        show("uniformWithName:nil", make(nil));
        show("uniformWithName:empty", make(@""));
        show("uniformWithName:texture:nil", makeTexture(@"t"));
        show("uniformWithName:float:2.5", makeFloat(@"f", 2.5f));
        show("uniformWithName:float:-0.0", makeFloat(@"z", -0.0f));
        show("uniformWithName:float:1e30", makeFloat(@"big", 1e30f));

        id none = make(@"none");
        setFloat(none, 3.5f);
        show("None then floatValue=3.5", none);

        id floatUniform = makeFloat(@"fu", 1.0f);
        setFloat(floatUniform, 7.25f);
        show("Float then floatValue=7.25", floatUniform);
        setTexture(floatUniform, nil);
        show("Float then textureValue=nil", floatUniform);

        id textureUniform = makeTexture(@"tu");
        setFloat(textureUniform, 2.0f);
        show("Texture then floatValue=2", textureUniform);

        id noneTexture = make(@"nt");
        setTexture(noneTexture, nil);
        show("None then textureValue=nil", noneTexture);

        id copied = [makeFloat(@"cp", 4.25f) copy];
        show("copy of Float 4.25", copied);
        printf("copy distinct=%d isEqual=%d\n", copied != makeFloat(@"x", 0) && copied != nil,
               [copied isEqual:makeFloat(@"cp", 4.25f)]);
        id copiedTexture = [makeTexture(@"ct") copy];
        show("copy of Texture(nil)", copiedTexture);

        id initNone = [[uniformClass alloc] init];
        show("alloc init", initNone);
        id initName = ((Initializer)objc_msgSend)([uniformClass alloc], NSSelectorFromString(@"initWithName:"), @"in");
        show("initWithName:", initName);
        id initFloat = ((NameFloatFactory)objc_msgSend)([uniformClass alloc], NSSelectorFromString(@"initWithName:float:"), @"if", -1.0f);
        show("initWithName:float:-1", initFloat);
        id initTexture = ((NameTextureFactory)objc_msgSend)([uniformClass alloc], NSSelectorFromString(@"initWithName:texture:"), @"it", nil);
        show("initWithName:texture:nil", initTexture);

        NSError *error = nil;
        id archived = makeFloat(@"arch", 9.5f);
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:archived requiringSecureCoding:YES error:&error];
        printf("archive float ok=%d error=%d\n", data != nil, error != nil);
        if (data != nil) {
            show("unarchived Float", [NSKeyedUnarchiver unarchivedObjectOfClass:uniformClass fromData:data error:&error]);
        }
        data = [NSKeyedArchiver archivedDataWithRootObject:make(@"plain") requiringSecureCoding:YES error:&error];
        printf("archive None ok=%d\n", data != nil);
        if (data != nil) {
            show("unarchived None", [NSKeyedUnarchiver unarchivedObjectOfClass:uniformClass fromData:data error:&error]);
        }
    }
    return 0;
}
