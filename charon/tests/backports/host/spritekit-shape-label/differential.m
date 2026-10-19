#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreImage/CoreImage.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <math.h>
#include <stdio.h>

typedef id (*ObjectGetter)(id, SEL);
typedef id (*ObjectWithObject)(id, SEL, id);
typedef id (*ObjectWithPath)(id, SEL, CGPathRef);
typedef id (*ObjectWithPathCentred)(id, SEL, CGPathRef, BOOL);
typedef id (*ObjectWithRect)(id, SEL, CGRect);
typedef id (*ObjectWithSize)(id, SEL, CGSize);
typedef id (*ObjectWithRectRadius)(id, SEL, CGRect, CGFloat);
typedef id (*ObjectWithSizeRadius)(id, SEL, CGSize, CGFloat);
typedef id (*ObjectWithFloat)(id, SEL, CGFloat);
typedef id (*ObjectWithPoints)(id, SEL, CGPoint *, size_t);
typedef id (*ObjectWithString)(id, SEL, NSString *);
typedef id (*ObjectWithColorSize)(id, SEL, id, CGSize);
typedef id (*ColorMaker)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat);
typedef CGPathRef (*PathGetter)(id, SEL);
typedef CGRect (*RectGetter)(id, SEL);
typedef CGSize (*SizeGetter)(id, SEL);
typedef CGFloat (*FloatGetter)(id, SEL);
typedef NSInteger (*IntGetter)(id, SEL);
typedef BOOL (*BoolGetter)(id, SEL);
typedef void (*VoidObject)(id, SEL, id);
typedef void (*VoidPath)(id, SEL, CGPathRef);
typedef void (*VoidFloat)(id, SEL, CGFloat);
typedef void (*VoidInt)(id, SEL, NSInteger);
typedef void (*VoidBool)(id, SEL, BOOL);
typedef id (*ObjectWithData)(id, SEL, NSData *, CGSize);
typedef id (*ObjectWithRectTexture)(id, SEL, CGRect, id);

static SEL S(const char *name)
{
    return sel_registerName(name);
}

static NSString *describeColour(id colour)
{
    return colour == nil ? @"nil" : [colour description];
}

static int elements;
static int dumped;

static double clean(double value)
{
    double rounded = round(value * 1000) / 1000;
    return rounded == 0 ? 0 : rounded;
}

static void dumpElement(void *info, const CGPathElement *element)
{
    (void)info;
    int count = element->type == kCGPathElementCloseSubpath ? 0 : element->type == kCGPathElementAddCurveToPoint ? 3 : 1;
    printf("  %d type=%d", dumped++, element->type);
    for (int i = 0; i < count; i++) {
        printf(" (%.3f,%.3f)", clean(element->points[i].x), clean(element->points[i].y));
    }
    printf("\n");
}

static void splinePath(const char *label, id node)
{
    CGPathRef path = ((PathGetter)objc_msgSend)(node, S("path"));
    if (path == NULL) {
        printf("%s path nil\n", label);
        return;
    }
    CGRect box = CGPathGetBoundingBox(path);
    printf("%s bbox=(%.3f,%.3f,%.3f,%.3f)\n", label, clean(box.origin.x), clean(box.origin.y), clean(box.size.width), clean(box.size.height));
    dumped = 0;
    CGPathApply(path, NULL, dumpElement);
}

static void countElement(void *info, const CGPathElement *element)
{
    (void)info;
    (void)element;
    elements++;
}

static void shape(const char *label, id node)
{
    CGPathRef path = ((PathGetter)objc_msgSend)(node, S("path"));
    if (path == NULL) {
        printf("%s path nil\n", label);
        return;
    }
    CGRect box = CGPathGetBoundingBox(path);
    elements = 0;
    CGPathApply(path, NULL, countElement);
    printf("%s bbox=(%g,%g,%g,%g) elements=%d\n", label, box.origin.x, box.origin.y, box.size.width, box.size.height, elements);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    Class shapeClass = NSClassFromString(@"SKShapeNode");
    Class labelClass = NSClassFromString(@"SKLabelNode");
    Class cropClass = NSClassFromString(@"SKCropNode");
    Class effectClass = NSClassFromString(@"SKEffectNode");
    Class spriteClass = NSClassFromString(@"SKSpriteNode");

    CGMutablePathRef rect = CGPathCreateMutable();
    CGPathAddRect(rect, NULL, CGRectMake(0, 0, 40, 20));
    id given = ((ObjectWithPath)objc_msgSend)(shapeClass, S("shapeNodeWithPath:"), rect);
    shape("path", given);
    printf("path equal=%d\n", CGPathEqualToPath(((PathGetter)objc_msgSend)(given, S("path")), rect));
    shape("centred no", ((ObjectWithPathCentred)objc_msgSend)(shapeClass, S("shapeNodeWithPath:centered:"), rect, NO));
    shape("centred yes", ((ObjectWithPathCentred)objc_msgSend)(shapeClass, S("shapeNodeWithPath:centered:"), rect, YES));
    shape("nil path", ((ObjectWithPath)objc_msgSend)(shapeClass, S("shapeNodeWithPath:"), NULL));
    shape("rect", ((ObjectWithRect)objc_msgSend)(shapeClass, S("shapeNodeWithRect:"), CGRectMake(1, 2, 10, 6)));
    shape("rect of size", ((ObjectWithSize)objc_msgSend)(shapeClass, S("shapeNodeWithRectOfSize:"), CGSizeMake(10, 6)));
    shape("rect corner", ((ObjectWithRectRadius)objc_msgSend)(shapeClass, S("shapeNodeWithRect:cornerRadius:"), CGRectMake(1, 2, 10, 6), 2));
    shape("rect of size corner", ((ObjectWithSizeRadius)objc_msgSend)(shapeClass, S("shapeNodeWithRectOfSize:cornerRadius:"), CGSizeMake(10, 6), 2));
    shape("circle", ((ObjectWithFloat)objc_msgSend)(shapeClass, S("shapeNodeWithCircleOfRadius:"), 5));
    shape("ellipse in", ((ObjectWithRect)objc_msgSend)(shapeClass, S("shapeNodeWithEllipseInRect:"), CGRectMake(1, 1, 10, 4)));
    shape("ellipse of size", ((ObjectWithSize)objc_msgSend)(shapeClass, S("shapeNodeWithEllipseOfSize:"), CGSizeMake(10, 4)));
    CGPoint four[4] = {{0, 0}, {10, 0}, {10, 10}, {0, 10}};
    shape("points 4", ((ObjectWithPoints)objc_msgSend)(shapeClass, S("shapeNodeWithPoints:count:"), four, 4));
    shape("points 1", ((ObjectWithPoints)objc_msgSend)(shapeClass, S("shapeNodeWithPoints:count:"), four, 1));
    shape("points 0", ((ObjectWithPoints)objc_msgSend)(shapeClass, S("shapeNodeWithPoints:count:"), four, 0));
    CGPathRelease(rect);

    CGPoint square[4] = {{0, 0}, {10, 0}, {10, 10}, {0, 10}};
    CGPoint triangle[3] = {{0, 0}, {10, 0}, {10, 10}};
    CGPoint pair[2] = {{0, 0}, {10, 10}};
    CGPoint single[1] = {{3, 4}};
    CGPoint ten[10] = {{0, 0}, {2, 0}, {4, 0}, {6, 0}, {8, 0}, {10, 0}, {10, 10}, {0, 10}, {0, 5}, {5, 5}};
    SEL spline = S("shapeNodeWithSplinePoints:count:");
    splinePath("spline square", ((ObjectWithPoints)objc_msgSend)(shapeClass, spline, square, 4));
    splinePath("spline triangle", ((ObjectWithPoints)objc_msgSend)(shapeClass, spline, triangle, 3));
    splinePath("spline pair", ((ObjectWithPoints)objc_msgSend)(shapeClass, spline, pair, 2));
    splinePath("spline single", ((ObjectWithPoints)objc_msgSend)(shapeClass, spline, single, 1));
    splinePath("spline none", ((ObjectWithPoints)objc_msgSend)(shapeClass, spline, square, 0));
    splinePath("spline ten", ((ObjectWithPoints)objc_msgSend)(shapeClass, spline, ten, 10));

    id textureClass = NSClassFromString(@"SKTexture");
    unsigned char pixels[16] = {0};
    id base = ((ObjectWithData)objc_msgSend)(textureClass, S("textureWithData:size:"), [NSData dataWithBytes:pixels length:16], CGSizeMake(2, 2));
    id texture = ((ObjectWithRectTexture)objc_msgSend)(textureClass, S("textureWithRect:inTexture:"), CGRectMake(0, 0, 0.5, 0.5), base);
    printf("texture size=(%g,%g)\n", clean(((SizeGetter)objc_msgSend)(texture, S("size")).width), clean(((SizeGetter)objc_msgSend)(texture, S("size")).height));
    id textured = ((ObjectWithPath)objc_msgSend)(shapeClass, S("shapeNodeWithPath:"), NULL);
    printf("fillTexture default nil=%d strokeTexture default nil=%d\n", ((ObjectGetter)objc_msgSend)(textured, S("fillTexture")) == nil, ((ObjectGetter)objc_msgSend)(textured, S("strokeTexture")) == nil);
    ((VoidObject)objc_msgSend)(textured, S("setFillTexture:"), texture);
    printf("fillTexture same=%d strokeTexture nil=%d fillColor=%s\n", ((ObjectGetter)objc_msgSend)(textured, S("fillTexture")) == texture,
           ((ObjectGetter)objc_msgSend)(textured, S("strokeTexture")) == nil, [describeColour(((ObjectGetter)objc_msgSend)(textured, S("fillColor"))) UTF8String]);
    ((VoidObject)objc_msgSend)(textured, S("setStrokeTexture:"), texture);
    printf("strokeTexture same=%d\n", ((ObjectGetter)objc_msgSend)(textured, S("strokeTexture")) == texture);
    ((VoidObject)objc_msgSend)(textured, S("setFillTexture:"), nil);
    printf("fillTexture cleared=%d strokeTexture kept=%d\n", ((ObjectGetter)objc_msgSend)(textured, S("fillTexture")) == nil,
           ((ObjectGetter)objc_msgSend)(textured, S("strokeTexture")) == texture);

    id shape0 = ((ObjectWithPath)objc_msgSend)(shapeClass, S("shapeNodeWithPath:"), NULL);
    printf("stroke=%s\n", [describeColour(((ObjectGetter)objc_msgSend)(given, S("strokeColor"))) UTF8String]);
    printf("fill=%s\n", [describeColour(((ObjectGetter)objc_msgSend)(given, S("fillColor"))) UTF8String]);
    printf("lineWidth=%g glowWidth=%g miterLimit=%g lineCap=%ld lineJoin=%ld antialiased=%d blendMode=%ld\n",
           ((FloatGetter)objc_msgSend)(given, S("lineWidth")), ((FloatGetter)objc_msgSend)(given, S("glowWidth")),
           ((FloatGetter)objc_msgSend)(given, S("miterLimit")), (long)((IntGetter)objc_msgSend)(given, S("lineCap")),
           (long)((IntGetter)objc_msgSend)(given, S("lineJoin")), ((BoolGetter)objc_msgSend)(given, S("isAntialiased")),
           (long)((IntGetter)objc_msgSend)(given, S("blendMode")));
    ((VoidFloat)objc_msgSend)(given, S("setLineWidth:"), 3);
    ((VoidFloat)objc_msgSend)(given, S("setGlowWidth:"), 2.5);
    ((VoidBool)objc_msgSend)(given, S("setAntialiased:"), NO);
    ((VoidInt)objc_msgSend)(given, S("setLineCap:"), 1);
    ((VoidInt)objc_msgSend)(given, S("setLineJoin:"), 1);
    ((VoidFloat)objc_msgSend)(given, S("setMiterLimit:"), 7);
    ((VoidInt)objc_msgSend)(given, S("setBlendMode:"), 1);
    printf("set lineWidth=%g glowWidth=%g antialiased=%d lineCap=%ld lineJoin=%ld miterLimit=%g blendMode=%ld\n",
           ((FloatGetter)objc_msgSend)(given, S("lineWidth")), ((FloatGetter)objc_msgSend)(given, S("glowWidth")),
           ((BoolGetter)objc_msgSend)(given, S("isAntialiased")), (long)((IntGetter)objc_msgSend)(given, S("lineCap")),
           (long)((IntGetter)objc_msgSend)(given, S("lineJoin")), ((FloatGetter)objc_msgSend)(given, S("miterLimit")),
           (long)((IntGetter)objc_msgSend)(given, S("blendMode")));
    ((VoidFloat)objc_msgSend)(given, S("setLineWidth:"), -4);
    printf("negative lineWidth=%g\n", ((FloatGetter)objc_msgSend)(given, S("lineWidth")));
    ((VoidObject)objc_msgSend)(given, S("setStrokeColor:"), ((ColorMaker)objc_msgSend)(NSClassFromString(@"NSColor"), S("colorWithDeviceRed:green:blue:alpha:"), 0, 0, 1, 1));
    printf("stroke after set=%s\n", [describeColour(((ObjectGetter)objc_msgSend)(given, S("strokeColor"))) UTF8String]);
    ((VoidPath)objc_msgSend)(given, S("setPath:"), NULL);
    printf("path after nil set=%d\n", ((PathGetter)objc_msgSend)(given, S("path")) == NULL);
    printf("default path of a fresh shape nil=%d\n", ((PathGetter)objc_msgSend)(shape0, S("path")) == NULL);

    id text = ((ObjectWithString)objc_msgSend)(labelClass, S("labelNodeWithText:"), @"Hi");
    printf("label class=%s text=%s font=%s size=%g\n", [NSStringFromClass([text class]) UTF8String],
           [((ObjectGetter)objc_msgSend)(text, S("text")) UTF8String], [((ObjectGetter)objc_msgSend)(text, S("fontName")) UTF8String],
           ((FloatGetter)objc_msgSend)(text, S("fontSize")));
    printf("fontColor=%s color=%s colorBlendFactor=%g blendMode=%ld\n", [describeColour(((ObjectGetter)objc_msgSend)(text, S("fontColor"))) UTF8String],
           [describeColour(((ObjectGetter)objc_msgSend)(text, S("color"))) UTF8String], ((FloatGetter)objc_msgSend)(text, S("colorBlendFactor")),
           (long)((IntGetter)objc_msgSend)(text, S("blendMode")));
    printf("horizontal=%ld vertical=%ld lines=%ld lineBreak=%ld preferredWidth=%g\n",
           (long)((IntGetter)objc_msgSend)(text, S("horizontalAlignmentMode")), (long)((IntGetter)objc_msgSend)(text, S("verticalAlignmentMode")),
           (long)((IntGetter)objc_msgSend)(text, S("numberOfLines")), (long)((IntGetter)objc_msgSend)(text, S("lineBreakMode")),
           ((FloatGetter)objc_msgSend)(text, S("preferredMaxLayoutWidth")));
    id named = ((ObjectWithString)objc_msgSend)(labelClass, S("labelNodeWithFontNamed:"), @"Courier");
    printf("named font=%s text nil=%d\n", [((ObjectGetter)objc_msgSend)(named, S("fontName")) UTF8String], ((ObjectGetter)objc_msgSend)(named, S("text")) == nil);
    id inited = ((ObjectWithString)objc_msgSend)(((ObjectGetter)objc_msgSend)(labelClass, S("alloc")), S("initWithFontNamed:"), @"Helvetica");
    printf("inited font=%s text nil=%d\n", [((ObjectGetter)objc_msgSend)(inited, S("fontName")) UTF8String], ((ObjectGetter)objc_msgSend)(inited, S("text")) == nil);
    ((VoidObject)objc_msgSend)(text, S("setText:"), nil);
    printf("text nil after set=%d\n", ((ObjectGetter)objc_msgSend)(text, S("text")) == nil);
    ((VoidFloat)objc_msgSend)(text, S("setFontSize:"), 20);
    ((VoidObject)objc_msgSend)(text, S("setFontColor:"), ((ColorMaker)objc_msgSend)(NSClassFromString(@"NSColor"), S("colorWithDeviceRed:green:blue:alpha:"), 1, 0, 0, 1));
    ((VoidInt)objc_msgSend)(text, S("setHorizontalAlignmentMode:"), 1);
    ((VoidInt)objc_msgSend)(text, S("setVerticalAlignmentMode:"), 2);
    ((VoidInt)objc_msgSend)(text, S("setNumberOfLines:"), 3);
    ((VoidFloat)objc_msgSend)(text, S("setPreferredMaxLayoutWidth:"), 99);
    printf("set size=%g fontColor=%s horizontal=%ld vertical=%ld lines=%ld preferredWidth=%g\n",
           ((FloatGetter)objc_msgSend)(text, S("fontSize")), [describeColour(((ObjectGetter)objc_msgSend)(text, S("fontColor"))) UTF8String],
           (long)((IntGetter)objc_msgSend)(text, S("horizontalAlignmentMode")), (long)((IntGetter)objc_msgSend)(text, S("verticalAlignmentMode")),
           (long)((IntGetter)objc_msgSend)(text, S("numberOfLines")), ((FloatGetter)objc_msgSend)(text, S("preferredMaxLayoutWidth")));

    id crop = ((ObjectGetter)objc_msgSend)(cropClass, S("node"));
    printf("crop class=%s mask nil=%d\n", [NSStringFromClass([crop class]) UTF8String], ((ObjectGetter)objc_msgSend)(crop, S("maskNode")) == nil);
    id white = ((ColorMaker)objc_msgSend)(NSClassFromString(@"NSColor"), S("colorWithDeviceRed:green:blue:alpha:"), 1, 1, 1, 1);
    id mask = ((ObjectWithColorSize)objc_msgSend)(spriteClass, S("spriteNodeWithColor:size:"), white, CGSizeMake(4, 4));
    ((VoidObject)objc_msgSend)(crop, S("setMaskNode:"), mask);
    printf("mask same=%d\n", ((ObjectGetter)objc_msgSend)(crop, S("maskNode")) == mask);

    id effect = ((ObjectGetter)objc_msgSend)(effectClass, S("node"));
    printf("effect class=%s filter nil=%d center=%d enable=%d raster=%d blendMode=%ld\n", [NSStringFromClass([effect class]) UTF8String],
           ((ObjectGetter)objc_msgSend)(effect, S("filter")) == nil, ((BoolGetter)objc_msgSend)(effect, S("shouldCenterFilter")),
           ((BoolGetter)objc_msgSend)(effect, S("shouldEnableEffects")), ((BoolGetter)objc_msgSend)(effect, S("shouldRasterize")),
           (long)((IntGetter)objc_msgSend)(effect, S("blendMode")));
    ((VoidBool)objc_msgSend)(effect, S("setShouldRasterize:"), YES);
    ((VoidBool)objc_msgSend)(effect, S("setShouldEnableEffects:"), NO);
    ((VoidBool)objc_msgSend)(effect, S("setShouldCenterFilter:"), YES);
    printf("effect set: raster=%d enable=%d center=%d\n", ((BoolGetter)objc_msgSend)(effect, S("shouldRasterize")),
           ((BoolGetter)objc_msgSend)(effect, S("shouldEnableEffects")), ((BoolGetter)objc_msgSend)(effect, S("shouldCenterFilter")));
    id blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    ((VoidObject)objc_msgSend)(effect, S("setFilter:"), blur);
    printf("filter same=%d\n", ((ObjectGetter)objc_msgSend)(effect, S("filter")) == blur);
    return 0;
}
