// differential.m - SKTexture and SKSpriteNode of iOS 7, run against the host's own SpriteKit and against the port's
// objects, with one source. It is runtime only: no SpriteKit header, typed objc_msgSend casts, and NSClassFromString for
// the classes, so the same program links either side. Each line is printed to stdout and compared line by line.
//
// The crash cases (a nil texture, a negative size) are in crash.m, one process per case, and are not run here.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdio.h>

typedef id (*ObjectGetter)(id, SEL);
typedef id (*ObjectWithObject)(id, SEL, id);
typedef id (*ObjectWithObjectSize)(id, SEL, id, CGSize);
typedef id (*ObjectWithSize)(id, SEL, CGSize);
typedef id (*ObjectWithRectObject)(id, SEL, CGRect, id);
typedef id (*ObjectWithObjectObjectSize)(id, SEL, id, id, CGSize);
typedef id (*ObjectWithColorSize)(id, SEL, id, CGSize);
typedef CGSize (*SizeGetter)(id, SEL);
typedef CGPoint (*PointGetter)(id, SEL);
typedef CGRect (*RectGetter)(id, SEL);
typedef CGFloat (*FloatGetter)(id, SEL);
typedef NSInteger (*IntGetter)(id, SEL);
typedef BOOL (*BoolGetter)(id, SEL);
typedef void (*VoidObject)(id, SEL, id);
typedef void (*VoidSize)(id, SEL, CGSize);
typedef void (*VoidPoint)(id, SEL, CGPoint);
typedef void (*VoidRect)(id, SEL, CGRect);
typedef void (*VoidFloat)(id, SEL, CGFloat);
typedef void (*VoidInt)(id, SEL, NSInteger);
typedef void (*VoidBool)(id, SEL, BOOL);
typedef id (*ColorMaker)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat);

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

static NSString *describeColor(id colour)
{
    return colour == nil ? @"nil" : [colour description];
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    Class textureClass = NSClassFromString(@"SKTexture");
    Class spriteClass = NSClassFromString(@"SKSpriteNode");
    SEL dataSel = sel_registerName("textureWithData:size:");
    SEL rectSel = sel_registerName("textureWithRect:inTexture:");

    // Textures: the whole of an image from pixels, the rectangles cut from it, and their copies.
    NSMutableData *pixels = [NSMutableData dataWithLength:4 * 4 * 4];
    id base = ((ObjectWithObjectSize)objc_msgSend)(textureClass, dataSel, pixels, CGSizeMake(4, 4));
    size("base size", ((SizeGetter)objc_msgSend)(base, sel_registerName("size")));
    rect("base rect", ((RectGetter)objc_msgSend)(base, sel_registerName("textureRect")));
    printf("base filter=%ld mipmaps=%d\n", (long)((IntGetter)objc_msgSend)(base, sel_registerName("filteringMode")),
           ((BoolGetter)objc_msgSend)(base, sel_registerName("usesMipmaps")));
    printf("base pixels nil=%d\n", ((ObjectWithObjectSize)objc_msgSend)(textureClass, dataSel, nil, CGSizeMake(4, 4)) == nil);

    id sub = ((ObjectWithRectObject)objc_msgSend)(textureClass, rectSel, CGRectMake(0.25, 0.5, 0.5, 0.25), base);
    rect("sub rect", ((RectGetter)objc_msgSend)(sub, sel_registerName("textureRect")));
    size("sub size", ((SizeGetter)objc_msgSend)(sub, sel_registerName("size")));

    id subsub = ((ObjectWithRectObject)objc_msgSend)(textureClass, rectSel, CGRectMake(0.5, 0.5, 0.5, 0.5), sub);
    rect("subsub rect", ((RectGetter)objc_msgSend)(subsub, sel_registerName("textureRect")));
    size("subsub size", ((SizeGetter)objc_msgSend)(subsub, sel_registerName("size")));

    ((VoidInt)objc_msgSend)(sub, sel_registerName("setFilteringMode:"), 0);
    printf("sub filter after set=%ld\n", (long)((IntGetter)objc_msgSend)(sub, sel_registerName("filteringMode")));
    ((VoidBool)objc_msgSend)(sub, sel_registerName("setUsesMipmaps:"), YES);
    printf("sub mipmaps after set=%d\n", ((BoolGetter)objc_msgSend)(sub, sel_registerName("usesMipmaps")));

    id copy = [sub copy];
    printf("copy distinct=%d class=%s\n", copy != sub, [NSStringFromClass([copy class]) UTF8String]);
    size("copy size", ((SizeGetter)objc_msgSend)(copy, sel_registerName("size")));
    rect("copy rect", ((RectGetter)objc_msgSend)(copy, sel_registerName("textureRect")));
    printf("copy filter=%ld mipmaps=%d\n", (long)((IntGetter)objc_msgSend)(copy, sel_registerName("filteringMode")),
           ((BoolGetter)objc_msgSend)(copy, sel_registerName("usesMipmaps")));

    // Sprites made from a colour: the colour, the size, and the defaults of the anchor, the centre rectangle and the
    // blending.
    id red = ((ColorMaker)objc_msgSend)(NSClassFromString(@"NSColor"), sel_registerName("colorWithDeviceRed:green:blue:alpha:"), 1, 0, 0, 1);
    id colour = ((ObjectWithColorSize)objc_msgSend)(spriteClass, sel_registerName("spriteNodeWithColor:size:"), red, CGSizeMake(40, 20));
    printf("colour class=%s\n", [NSStringFromClass([colour class]) UTF8String]);
    size("colour size", ((SizeGetter)objc_msgSend)(colour, sel_registerName("size")));
    point("colour anchor", ((PointGetter)objc_msgSend)(colour, sel_registerName("anchorPoint")));
    rect("colour centerRect", ((RectGetter)objc_msgSend)(colour, sel_registerName("centerRect")));
    printf("colour blendFactor=%g blendMode=%ld texture nil=%d\n", ((FloatGetter)objc_msgSend)(colour, sel_registerName("colorBlendFactor")),
           (long)((IntGetter)objc_msgSend)(colour, sel_registerName("blendMode")), ((ObjectGetter)objc_msgSend)(colour, sel_registerName("texture")) == nil);
    printf("colour=%s\n", [describeColor(((ObjectGetter)objc_msgSend)(colour, sel_registerName("color"))) UTF8String]);

    ((VoidFloat)objc_msgSend)(colour, sel_registerName("setColorBlendFactor:"), 0.5);
    printf("blendFactor after set=%g\n", ((FloatGetter)objc_msgSend)(colour, sel_registerName("colorBlendFactor")));
    ((VoidInt)objc_msgSend)(colour, sel_registerName("setBlendMode:"), 1);
    printf("blendMode after set=%ld\n", (long)((IntGetter)objc_msgSend)(colour, sel_registerName("blendMode")));
    ((VoidPoint)objc_msgSend)(colour, sel_registerName("setAnchorPoint:"), CGPointMake(0, 1));
    point("anchor after set", ((PointGetter)objc_msgSend)(colour, sel_registerName("anchorPoint")));
    ((VoidRect)objc_msgSend)(colour, sel_registerName("setCenterRect:"), CGRectMake(0.25, 0.25, 0.5, 0.5));
    rect("centerRect after set", ((RectGetter)objc_msgSend)(colour, sel_registerName("centerRect")));
    ((VoidObject)objc_msgSend)(colour, sel_registerName("setColor:"), ((ColorMaker)objc_msgSend)(NSClassFromString(@"NSColor"), sel_registerName("colorWithDeviceRed:green:blue:alpha:"), 0, 0, 1, 1));
    printf("colour after set=%s\n", [describeColor(((ObjectGetter)objc_msgSend)(colour, sel_registerName("color"))) UTF8String]);

    // A texture set on a colour sprite leaves its size and colour alone; clearing it leaves them too (measured).
    ((VoidSize)objc_msgSend)(colour, sel_registerName("setSize:"), CGSizeMake(5, 5));
    ((VoidObject)objc_msgSend)(colour, sel_registerName("setTexture:"), base);
    size("size with texture set", ((SizeGetter)objc_msgSend)(colour, sel_registerName("size")));
    printf("texture is base=%d\n", ((ObjectGetter)objc_msgSend)(colour, sel_registerName("texture")) == base);
    ((VoidObject)objc_msgSend)(colour, sel_registerName("setTexture:"), nil);
    size("size with texture cleared", ((SizeGetter)objc_msgSend)(colour, sel_registerName("size")));
    printf("texture nil after clear=%d\n", ((ObjectGetter)objc_msgSend)(colour, sel_registerName("texture")) == nil);

    // A negative size is stored by the setter: the setter does not check it (measured).
    ((VoidSize)objc_msgSend)(colour, sel_registerName("setSize:"), CGSizeMake(-5, 2));
    size("negative size after set", ((SizeGetter)objc_msgSend)(colour, sel_registerName("size")));

    // Sprites made from a texture: the texture's size, the white clear colour, and the given size.
    id textured = ((ObjectWithObject)objc_msgSend)(spriteClass, sel_registerName("spriteNodeWithTexture:"), sub);
    size("textured size", ((SizeGetter)objc_msgSend)(textured, sel_registerName("size")));
    printf("textured colour=%s blendFactor=%g\n", [describeColor(((ObjectGetter)objc_msgSend)(textured, sel_registerName("color"))) UTF8String],
           ((FloatGetter)objc_msgSend)(textured, sel_registerName("colorBlendFactor")));
    printf("textured is sub=%d\n", ((ObjectGetter)objc_msgSend)(textured, sel_registerName("texture")) == sub);
    id sized = ((ObjectWithObjectSize)objc_msgSend)(spriteClass, sel_registerName("spriteNodeWithTexture:size:"), sub, CGSizeMake(7, 8));
    size("textured sized", ((SizeGetter)objc_msgSend)(sized, sel_registerName("size")));
    printf("sized colour=%s\n", [describeColor(((ObjectGetter)objc_msgSend)(sized, sel_registerName("color"))) UTF8String]);
    id empty = ((ObjectWithObject)objc_msgSend)(spriteClass, sel_registerName("spriteNodeWithTexture:"), nil);
    size("nil texture size", ((SizeGetter)objc_msgSend)(empty, sel_registerName("size")));
    printf("nil texture texture nil=%d\n", ((ObjectGetter)objc_msgSend)(empty, sel_registerName("texture")) == nil);
    id emptySized = ((ObjectWithObjectSize)objc_msgSend)(spriteClass, sel_registerName("spriteNodeWithTexture:size:"), nil, CGSizeMake(3, 3));
    size("nil texture sized", ((SizeGetter)objc_msgSend)(emptySized, sel_registerName("size")));

    // The initialisers: a colour sprite and a texture sprite from alloc and init.
    id plain = ((ObjectWithColorSize)objc_msgSend)(((ObjectGetter)objc_msgSend)(spriteClass, sel_registerName("alloc")),
                                                   sel_registerName("initWithColor:size:"), red, CGSizeMake(3, 4));
    size("initWithColor size", ((SizeGetter)objc_msgSend)(plain, sel_registerName("size")));
    id full = ((ObjectWithObjectObjectSize)objc_msgSend)(((ObjectGetter)objc_msgSend)(spriteClass, sel_registerName("alloc")),
                                                         sel_registerName("initWithTexture:color:size:"), sub, red, CGSizeMake(9, 1));
    size("initWithTexture:color:size: size", ((SizeGetter)objc_msgSend)(full, sel_registerName("size")));
    printf("initWithTexture:color:size: colour=%s\n", [describeColor(((ObjectGetter)objc_msgSend)(full, sel_registerName("color"))) UTF8String]);
    id fromTexture = ((ObjectWithObject)objc_msgSend)(((ObjectGetter)objc_msgSend)(spriteClass, sel_registerName("alloc")), sel_registerName("initWithTexture:"), sub);
    size("initWithTexture: size", ((SizeGetter)objc_msgSend)(fromTexture, sel_registerName("size")));
    return 0;
}
