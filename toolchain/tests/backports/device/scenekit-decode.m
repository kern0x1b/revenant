#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import "check.h"
#include <unistd.h>

@interface StandIn : NSObject <NSCoding>
@property (nonatomic, strong) NSDictionary<NSString *, id> *keys;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *integers;
@property (nonatomic, strong) NSDictionary<NSString *, NSData *> *bytes;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *doubles;
@end

@implementation StandIn
@synthesize keys = _keys;
@synthesize integers = _integers;
@synthesize bytes = _bytes;
@synthesize doubles = _doubles;
- (instancetype)initWithCoder:(NSCoder *)coder { return [super init]; }
- (void)encodeWithCoder:(NSCoder *)coder
{
    for (NSString *key in _keys) {
        [coder encodeObject:_keys[key] forKey:key];
    }
    for (NSString *key in _integers) {
        [coder encodeInteger:_integers[key].integerValue forKey:key];
    }
    for (NSString *key in _bytes) {
        [coder encodeBytes:_bytes[key].bytes length:_bytes[key].length forKey:key];
    }
    for (NSString *key in _doubles) {
        [coder encodeDouble:_doubles[key].doubleValue forKey:key];
    }
}
@end

@interface StandInNode : StandIn
@end
@implementation StandInNode
@end

@interface StandInGeometry : StandIn
@end
@implementation StandInGeometry
@end

@interface StandInMaterialProperty : StandIn
@end
@implementation StandInMaterialProperty
@end

@interface StandInMaterial : StandIn
@end
@implementation StandInMaterial
@end

@interface StandInPhysicsWorld : StandIn
@end
@implementation StandInPhysicsWorld
@end

@interface StandInColor : StandIn
@end
@implementation StandInColor
@end

static id stand_in(Class cls, NSDictionary *keys)
{
    StandIn *object = [cls new];
    object.keys = keys;
    return object;
}

static id stand_in_with(Class cls, NSDictionary *keys, NSDictionary *integers, NSDictionary *bytes)
{
    StandIn *object = stand_in(cls, keys);
    object.integers = integers;
    object.bytes = bytes;
    return object;
}

static id decode_root_securely(StandIn *root, Class cls, BOOL secure, NSString **failure)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver setClassName:@"SCNNode" forClass:[StandInNode class]];
    [archiver setClassName:@"SCNGeometry" forClass:[StandInGeometry class]];
    [archiver setClassName:@"SCNMaterialProperty" forClass:[StandInMaterialProperty class]];
    [archiver setClassName:@"SCNMaterial" forClass:[StandInMaterial class]];
    [archiver setClassName:@"NSColor" forClass:[StandInColor class]];
    [archiver setClassName:@"SCNPhysicsWorld" forClass:[StandInPhysicsWorld class]];
    [archiver encodeObject:root forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.requiresSecureCoding = secure;
    @try {
        return [unarchiver decodeObjectOfClass:cls forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
        *failure = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
        return nil;
    }
}

static id decode_root(StandIn *root, Class cls, NSString **failure)
{
    return decode_root_securely(root, cls, YES, failure);
}

static SCNNode *decode_node(StandInNode *root, NSString **failure)
{
    return decode_root(root, [SCNNode class], failure);
}

static NSString *captured_stderr(void (^block)(void))
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"scenekit-decode-stderr.XXXXXX"];
    char *name = strdup(path.fileSystemRepresentation);
    int file = mkstemp(name);
    if (file < 0) {
        free(name);
        return nil;
    }
    fflush(stderr);
    int saved = dup(STDERR_FILENO);
    dup2(file, STDERR_FILENO);
    block();
    fflush(stderr);
    dup2(saved, STDERR_FILENO);
    close(saved);
    close(file);
    NSString *text = [NSString stringWithContentsOfFile:@(name) encoding:NSUTF8StringEncoding error:NULL];
    unlink(name);
    free(name);
    return text;
}

static NSUInteger count_lines_containing(NSString *text, NSString *needle)
{
    NSUInteger count = 0;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if ([line rangeOfString:needle].location != NSNotFound) {
            count++;
        }
    }
    return count;
}

static NSInteger list_count(id list)
{
    if (list == nil) {
        return 0;
    }
    return [list isKindOfClass:[NSArray class]] ? (NSInteger)[(NSArray *)list count] : -1;
}

static void check_single_objects(void)
{
    NSString *failure = nil;
    SCNNode *node = decode_node(stand_in([StandInNode class], @{@"particleSystem": [SCNParticleSystem particleSystem]}), &failure);
    charon_check(node != nil && list_count(node.particleSystems) == 1, "a single particle system under particleSystem is one system",
                 [NSString stringWithFormat:@"node %@, systems %ld, %@", node, (long)list_count(node.particleSystems), failure]);

    failure = nil;
    node = decode_node(stand_in([StandInNode class], @{@"particleSystems": [SCNParticleSystem particleSystem]}), &failure);
    charon_check(node != nil && list_count(node.particleSystems) == 1, "a single particle system under particleSystems is one system",
                 [NSString stringWithFormat:@"node %@, %@", node, failure]);

    failure = nil;
    node = decode_node(stand_in([StandInNode class], @{@"particleSystems": @[[SCNParticleSystem particleSystem], [SCNParticleSystem particleSystem]]}), &failure);
    charon_check(node != nil && list_count(node.particleSystems) == 2, "an array of two particle systems is two systems (control)",
                 [NSString stringWithFormat:@"node %@, %@", node, failure]);

    failure = nil;
    StandInNode *child = stand_in([StandInNode class], @{@"name": @"child"});
    node = decode_node(stand_in([StandInNode class], @{@"childNodes": child}), &failure);
    charon_check(node != nil && list_count(node.childNodes) == 1 && [[node.childNodes.firstObject name] isEqualToString:@"child"],
                 "a single child under childNodes is one child", [NSString stringWithFormat:@"node %@, %@", node, failure]);

    failure = nil;
    StandInGeometry *geometry = stand_in([StandInGeometry class], @{@"materials": [SCNMaterial material],
                                                                  @"elements": [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:(uint16_t[]){0, 1, 2} length:6]
                                                                                                             primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:1 bytesPerIndex:2]});
    node = decode_node(stand_in([StandInNode class], @{@"geometry": geometry}), &failure);
    charon_check(list_count(node.geometry.materials) == 1 && list_count(node.geometry.geometryElements) == 1,
                 "a single material and a single element are one of each", [NSString stringWithFormat:@"geometry %@, %@", node.geometry, failure]);
}

static void check_stray_objects(void)
{
    __block SCNNode *node = nil;
    __block NSString *failure = nil;
    NSString *log = captured_stderr(^{
        node = decode_root_securely(stand_in([StandInNode class], @{@"particleSystems": @"a string"}), [SCNNode class], NO, &failure);
    });
    charon_check(node != nil && list_count(node.particleSystems) == 0 && count_lines_containing(log, @"the archive's particleSystems holds a") == 1,
                 "a string under particleSystems is left out and said, and the node loads",
                 [NSString stringWithFormat:@"node %@, systems %ld, log %@, %@", node, (long)list_count(node.particleSystems), log, failure]);

    node = nil;
    failure = nil;
    log = captured_stderr(^{
        node = decode_root_securely(stand_in([StandInNode class], @{@"particleSystems": @[[SCNParticleSystem particleSystem], @"a string"]}),
                                    [SCNNode class], NO, &failure);
    });
    charon_check(node != nil && list_count(node.particleSystems) == 1 && count_lines_containing(log, @"the archive's particleSystems holds a") == 1,
                 "a string among particle systems is left out and said, and the system loads",
                 [NSString stringWithFormat:@"node %@, systems %ld, log %@, %@", node, (long)list_count(node.particleSystems), log, failure]);
}

static void check_colours(void)
{
    __block SCNMaterialProperty *property = nil;
    __block NSString *failure = nil;
    StandInColor *catalog = stand_in_with([StandInColor class], nil, @{@"NSColorSpace": @6}, nil);
    NSString *log = captured_stderr(^{
        property = decode_root(stand_in([StandInMaterialProperty class], @{@"color": catalog}), [SCNMaterialProperty class], &failure);
    });
    charon_check(property != nil && property.contents == nil, "an unreadable colour leaves the property at its default",
                 [NSString stringWithFormat:@"property %@, contents %@, %@", property, property.contents, failure]);
    charon_check(log != nil && count_lines_containing(log, @"the colour under color is not read") == 1,
                 "an unreadable colour is said once, naming its key", [NSString stringWithFormat:@"log: %@", log]);

    property = nil;
    failure = nil;
    const char *red = "1 0 0 1";
    StandInColor *device = stand_in_with([StandInColor class], nil, @{@"NSColorSpace": @2},
                                         @{@"NSRGB": [NSData dataWithBytes:red length:strlen(red) + 1]});
    log = captured_stderr(^{
        property = decode_root(stand_in([StandInMaterialProperty class], @{@"color": device}), [SCNMaterialProperty class], &failure);
    });
    CGFloat r = -1, g = -1, b = -1, a = -1;
    BOOL read = [property.contents isKindOfClass:[UIColor class]] && [(UIColor *)property.contents getRed:&r green:&g blue:&b alpha:&a];
    charon_check(read && r == 1 && g == 0 && b == 0 && a == 1, "a device RGB colour is read (control)",
                 [NSString stringWithFormat:@"contents %@, %@", property.contents, failure]);
    charon_check(log != nil && count_lines_containing(log, @"SceneKit:") == 0, "a colour that is read says nothing (control)",
                 [NSString stringWithFormat:@"log: %@", log]);
}

static BOOL colour_rgba(id contents, CGFloat rgba[4])
{
    if (![contents isKindOfClass:[UIColor class]]) {
        return NO;
    }
    UIColor *colour = contents;
    if ([colour getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]]) {
        return YES;
    }
    if ([colour getWhite:&rgba[0] alpha:&rgba[3]]) {
        rgba[1] = rgba[2] = rgba[0];
        return YES;
    }
    return NO;
}

static BOOL colour_is(id contents, CGFloat r, CGFloat g, CGFloat b, CGFloat a)
{
    CGFloat rgba[4];
    return colour_rgba(contents, rgba) && rgba[0] == r && rgba[1] == g && rgba[2] == b && rgba[3] == a;
}

static void check_material_colours(void)
{
    __block SCNMaterial *material = nil;
    __block NSString *failure = nil;
    StandInColor *catalog = stand_in_with([StandInColor class], nil, @{@"NSColorSpace": @6}, nil);
    const char *red = "1 0 0 1";
    StandInColor *device = stand_in_with([StandInColor class], nil, @{@"NSColorSpace": @2},
                                         @{@"NSRGB": [NSData dataWithBytes:red length:strlen(red) + 1]});
    StandInMaterial *archived = stand_in([StandInMaterial class], @{
        @"diffuse": stand_in([StandInMaterialProperty class], @{@"color": catalog}),
        @"specular": stand_in([StandInMaterialProperty class], @{@"color": catalog}),
        @"emission": stand_in([StandInMaterialProperty class], @{}),
        @"multiply": stand_in([StandInMaterialProperty class], @{@"color": device}),
    });
    NSString *log = captured_stderr(^{
        material = decode_root(archived, [SCNMaterial class], &failure);
    });
    charon_check(material != nil && colour_is(material.diffuse.contents, 1, 1, 1, 1),
                 "a material's unreadable diffuse colour keeps the slot's default, white",
                 [NSString stringWithFormat:@"material %@, diffuse %@, %@", material, material.diffuse.contents, failure]);
    charon_check(colour_is(material.specular.contents, 0, 0, 0, 1), "a material's unreadable specular colour keeps the slot's default, black",
                 [NSString stringWithFormat:@"specular %@", material.specular.contents]);
    charon_check(material != nil && material.emission != nil && material.emission.contents == nil,
                 "a material slot archived with no colour decodes to nil, as on macOS (control)",
                 [NSString stringWithFormat:@"emission %@, contents %@", material.emission, material.emission.contents]);
    charon_check(colour_is(material.multiply.contents, 1, 0, 0, 1), "a material slot's readable colour is read (control)",
                 [NSString stringWithFormat:@"multiply %@", material.multiply.contents]);
    charon_check(log != nil && count_lines_containing(log, @"the colour under color is not read, and the property keeps its default") == 2 &&
                 count_lines_containing(log, @"SceneKit:") == 2,
                 "each of the two unreadable colours is said once, and nothing else", [NSString stringWithFormat:@"log: %@", log]);
}

static void check_physics_world(void)
{
    __block SCNPhysicsWorld *world = nil;
    __block NSString *failure = nil;
    SCNVector3 authored = SCNVector3Make(0, 1.75, 0);
    StandInPhysicsWorld *archived = stand_in([StandInPhysicsWorld class], nil);
    archived.bytes = @{@"gravity": [NSData dataWithBytes:&authored length:sizeof authored]};
    archived.doubles = @{@"speed": @2.5, @"timeStep": @0.02};
    NSString *log = captured_stderr(^{
        world = decode_root(archived, [SCNPhysicsWorld class], &failure);
    });
    charon_check(world != nil && world.gravity.x == 0 && world.gravity.y == 1.75f && world.gravity.z == 0 && world.speed == 2.5 &&
                     world.timeStep == 0.02,
                 "an archived physics world reads its gravity, speed and time step",
                 [NSString stringWithFormat:@"world %@, gravity (%g, %g, %g), speed %g, time step %g, %@", world, world.gravity.x,
                                            world.gravity.y, world.gravity.z, (double)world.speed, world.timeStep, failure]);
    charon_check(log != nil && count_lines_containing(log, @"SCNPhysicsWorld:") == 0, "decoding a physics world says nothing",
                 [NSString stringWithFormat:@"log: %@", log]);

    SCNPhysicsWorld *fresh = [SCNScene scene].physicsWorld;
    log = captured_stderr(^{
        fresh.gravity = SCNVector3Make(0, -1, 0);
        fresh.speed = 0.5;
        fresh.timeStep = 1.0 / 30.0;
    });
    charon_check(fresh.gravity.y == -1 && fresh.speed == 0.5 && fresh.timeStep == 1.0 / 30.0, "what is set on a physics world reads back",
                 [NSString stringWithFormat:@"gravity y %g, speed %g, time step %g", fresh.gravity.y, (double)fresh.speed, fresh.timeStep]);
    charon_check(log != nil && count_lines_containing(log, @"SCNPhysicsWorld: nothing is simulated") == 1,
                 "setting a physics world says once that nothing is simulated", [NSString stringWithFormat:@"log: %@", log]);
    NSArray *hits = [fresh rayTestWithSegmentFromPoint:SCNVector3Make(0, 10, 0) toPoint:SCNVector3Make(0, -10, 0) options:nil];
    charon_check(hits != nil && hits.count == 0, "a ray through a world with no body hits nothing", [NSString stringWithFormat:@"%@", hits]);
}

static void check_flags(void)
{
    __block SCNNode *node = nil;
    __block NSString *failure = nil;
    NSString *log = captured_stderr(^{
        node = decode_node(stand_in([StandInNode class], @{@"castsShadow": @"no"}), &failure);
    });
    charon_check(node != nil && node.castsShadow, "a flag stored as a string keeps its default",
                 [NSString stringWithFormat:@"node %@, castsShadow %d, %@", node, node.castsShadow, failure]);
    charon_check(log != nil && count_lines_containing(log, @"the flag under castsShadow is neither") == 1,
                 "a flag stored as a string is said once, naming its key", [NSString stringWithFormat:@"log: %@", log]);

    node = nil;
    failure = nil;
    StandInNode *integer = stand_in_with([StandInNode class], nil, @{@"castsShadow": @0}, nil);
    log = captured_stderr(^{
        node = decode_node(integer, &failure);
    });
    charon_check(node != nil && !node.castsShadow && count_lines_containing(log, @"SceneKit:") == 0,
                 "a flag stored as the integer 0 is NO, and nothing is said (control)",
                 [NSString stringWithFormat:@"node %@, castsShadow %d, log %@, %@", node, node.castsShadow, log, failure]);
}

int main(void)
{
    @autoreleasepool {
        check_single_objects();
        check_stray_objects();
        check_colours();
        check_material_colours();
        check_physics_world();
        check_flags();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
