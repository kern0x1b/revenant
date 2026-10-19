#import "scenekit-defaults-cases.h"
#import <SceneKit/SceneKit.h>
#import <QuartzCore/QuartzCore.h>
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

static NSString *number(double value)
{
    // Six significant digits: a CGFloat is a float on armv7 and a double on the host.
    NSString *text = [NSString stringWithFormat:@"%.6g", value];
    return [text isEqualToString:@"-0"] ? @"0" : text;
}

static NSString *floats(const double *values, NSUInteger count)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        [parts addObject:number(values[i])];
    }
    return [parts componentsJoinedByString:@" "];
}

static NSString *colour(id value)
{
#if TARGET_OS_OSX
    NSColor *colour = nil;
    if ([value isKindOfClass:[NSColor class]]) {
        colour = [value colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    } else if (value && CFGetTypeID((__bridge CFTypeRef)value) == CGColorGetTypeID()) {
        colour = [[NSColor colorWithCGColor:(__bridge CGColorRef)value] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    } else {
        return nil;
    }
    if (colour == nil) {
        return @"colour unconvertible";
    }
    double components[4] = {colour.redComponent, colour.greenComponent, colour.blueComponent, colour.alphaComponent};
#else
    UIColor *colour = nil;
    if ([value isKindOfClass:[UIColor class]]) {
        colour = value;
    } else if (value && CFGetTypeID((__bridge CFTypeRef)value) == CGColorGetTypeID()) {
        colour = [UIColor colorWithCGColor:(__bridge CGColorRef)value];
    } else {
        return nil;
    }
    // iOS 6 answers getRed: only for an RGB colour; a white one answers getWhite:.
    CGFloat red, green, blue, alpha;
    if (![colour getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (![colour getWhite:&red alpha:&alpha]) {
            return @"colour unconvertible";
        }
        green = blue = red;
    }
    double components[4] = {red, green, blue, alpha};
#endif
    return [@"colour " stringByAppendingString:floats(components, 4)];
}

static NSString *text(id value)
{
    if (value == nil) {
        return @"nil";
    }
    NSString *asColour = colour(value);
    if (asColour) {
        return asColour;
    }
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        // A mask of every bit is NSUIntegerMax, whose width is the platform's; it is said, not printed. armv7 boxes
        // it as a signed 64-bit number, so it is told by its value, not its type.
        if ([value doubleValue] > 0 && [value unsignedLongLongValue] == (unsigned long long)NSUIntegerMax) {
            return @"all bits";
        }
        return number([value doubleValue]);
    }
    if ([value isKindOfClass:[NSValue class]]) {
        const char *type = [value objCType];
        if (strncmp(type, "{SCNVector3", 11) == 0) {
            SCNVector3 v;
            [value getValue:&v];
            double values[3] = {v.x, v.y, v.z};
            return floats(values, 3);
        }
        if (strncmp(type, "{SCNVector4", 11) == 0) {
            SCNVector4 v;
            [value getValue:&v];
            double values[4] = {v.x, v.y, v.z, v.w};
            return floats(values, 4);
        }
        if (strncmp(type, "{CATransform3D", 14) == 0 || strncmp(type, "{SCNMatrix4", 11) == 0) {
            SCNMatrix4 m;
            [value getValue:&m];
            double values[16] = {m.m11, m.m12, m.m13, m.m14, m.m21, m.m22, m.m23, m.m24,
                                 m.m31, m.m32, m.m33, m.m34, m.m41, m.m42, m.m43, m.m44};
            return floats(values, 16);
        }
        return [NSString stringWithFormat:@"value %s", type];
    }
    if ([value isKindOfClass:[NSArray class]]) {
        return [NSString stringWithFormat:@"array of %lu", (unsigned long)[value count]];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        return [NSString stringWithFormat:@"dictionary of %lu", (unsigned long)[value count]];
    }
    return @"another object";
}

static void read_keys(NSString *name, id object, NSArray<NSString *> *keys, void (^report)(NSString *, NSString *))
{
    for (NSString *key in keys) {
        id value = nil;
        @try {
            value = [object valueForKeyPath:key];
            report([NSString stringWithFormat:@"%@.%@", name, key], text(value));
        } @catch (NSException *exception) {
            report([NSString stringWithFormat:@"%@.%@", name, key], [@"raises " stringByAppendingString:exception.name]);
        }
    }
}

void charon_scenekit_default_cases(void (^report)(NSString *name, NSString *value))
{
    NSArray *slots = @[@"diffuse", @"ambient", @"specular", @"normal", @"reflective", @"emission", @"transparent", @"multiply",
                       @"displacement", @"ambientOcclusion", @"selfIllumination", @"metalness", @"roughness", @"clearCoat",
                       @"clearCoatRoughness", @"clearCoatNormal"];
    NSMutableArray *slotKeys = [NSMutableArray array];
    for (NSString *slot in slots) {
        [slotKeys addObject:[slot stringByAppendingString:@".contents"]];
        [slotKeys addObject:[slot stringByAppendingString:@".intensity"]];
        // a material's own properties sample differently from a property made alone (mipFilter)
        for (NSString *key in @[@"minificationFilter", @"magnificationFilter", @"mipFilter", @"wrapS", @"wrapT", @"mappingChannel",
                                @"contentsTransform"]) {
            [slotKeys addObject:[NSString stringWithFormat:@"%@.%@", slot, key]];
        }
    }

    read_keys(@"SCNLight", [SCNLight light], @[@"type", @"color", @"temperature", @"intensity", @"name", @"castsShadow", @"shadowColor",
                                              @"shadowRadius", @"zNear", @"zFar", @"attenuationStartDistance", @"attenuationEndDistance",
                                              @"attenuationFalloffExponent", @"spotInnerAngle", @"spotOuterAngle", @"categoryBitMask"], report);
    read_keys(@"SCNCamera", [SCNCamera camera], @[@"name", @"fieldOfView", @"zNear", @"zFar", @"usesOrthographicProjection",
                                                  @"orthographicScale", @"automaticallyAdjustsZRange"], report);
    read_keys(@"SCNParticleSystem", [SCNParticleSystem particleSystem],
              @[@"emissionDuration", @"loops", @"birthRate", @"warmupDuration", @"spreadingAngle", @"emittingDirection", @"acceleration",
                @"particleAngleVariation", @"particleVelocity", @"particleVelocityVariation", @"particleAngularVelocity", @"particleLifeSpan",
                @"particleLifeSpanVariation", @"particleImage", @"particleColor", @"particleColorVariation", @"particleSize",
                @"particleSizeVariation", @"blendMode", @"orientationMode", @"sortingMode", @"lightingEnabled", @"affectedByGravity",
                @"affectedByPhysicsFields", @"speedFactor", @"stretchFactor", @"propertyControllers", @"emitterShape"], report);
    read_keys(@"SCNMaterial", [SCNMaterial material],
              [@[@"name", @"lightingModelName", @"doubleSided", @"transparency", @"shininess", @"blendMode", @"locksAmbientWithDiffuse",
                @"cullMode", @"writesToDepthBuffer", @"readsFromDepthBuffer"] arrayByAddingObjectsFromArray:slotKeys],
              report);
    read_keys(@"SCNMaterialProperty", [SCNMaterialProperty materialPropertyWithContents:@"contents"],
              @[@"intensity", @"minificationFilter", @"magnificationFilter", @"mipFilter", @"contentsTransform", @"wrapS", @"wrapT",
                @"mappingChannel"], report);
    read_keys(@"SCNNode", [SCNNode node], @[@"name", @"position", @"rotation", @"orientation", @"scale", @"hidden", @"opacity",
                                            @"renderingOrder", @"castsShadow", @"categoryBitMask", @"movabilityHint"], report);
    read_keys(@"SCNPlane", [SCNPlane planeWithWidth:1 height:1], @[@"widthSegmentCount", @"heightSegmentCount", @"cornerRadius",
                                                                  @"cornerSegmentCount"], report);
    // the scene's own background and lighting environment are properties made with their scene, as a material's slots are
    NSMutableArray *sceneKeys = [NSMutableArray array];
    for (NSString *slot in @[@"background", @"lightingEnvironment"]) {
        for (NSString *key in @[@"contents", @"intensity", @"minificationFilter", @"magnificationFilter", @"mipFilter", @"wrapS", @"wrapT",
                                @"mappingChannel", @"contentsTransform"]) {
            [sceneKeys addObject:[NSString stringWithFormat:@"%@.%@", slot, key]];
        }
    }
    read_keys(@"SCNScene", [SCNScene scene], sceneKeys, report);
    read_keys(@"SCNPhysicsWorld", [SCNScene scene].physicsWorld, @[@"gravity", @"speed", @"timeStep"], report);
    read_keys(@"SCNPhysicsField", [SCNPhysicsField radialGravityField],
              @[@"strength", @"falloffExponent", @"minimumDistance", @"active", @"exclusive", @"halfExtent", @"usesEllipsoidalExtent",
                @"scope", @"offset", @"direction", @"categoryBitMask"], report);
    read_keys(@"SCNParticlePropertyController", [SCNParticlePropertyController controllerWithAnimation:[CAKeyframeAnimation animation]],
              @[@"inputMode", @"inputScale", @"inputBias", @"inputProperty"], report);
}
