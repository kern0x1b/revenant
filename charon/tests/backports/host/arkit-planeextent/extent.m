// extent.m - the port's ARPlaneExtent, its archive, and the keys that archive carries.
//
// There is no host oracle for this class: this Mac's ARKit.framework has no ARPlaneExtent, no
// ARWorldTrackingConfiguration and no ARReferenceObject (dlopen of the framework by path answers a
// handle and NSClassFromString answers nil for all three), so nothing here is compared with a host
// answer. What is checked instead is that the port's class does what the release's own code does,
// with the release named as the source of every number and every string in
// facts/ARKit/PlaneExtent.md:
//
//   1. a fresh extent reads the release's -init defaults: rotation 0, width -1, height -1;
//   2. +supportsSecureCoding answers YES, and a class that does not declare NSSecureCoding answers
//      NO on the same runtime, which is what makes the YES mean something;
//   3. an archive written by the port carries the three literal keys the release's -encodeWithCoder:
//      uses -- origin, width, height -- read out of the archive's own bytes;
//   4. an archive round-trips: the three floats that went in are the three that come out;
//   5. a float that is not representable as a round trip of its own bits still round-trips exactly,
//      so the check above is not passing because the values are small integers in disguise.
//
// The port's class is renamed into CharonPortARPlaneExtent when this file is compiled, so nothing
// here can reach a host ARPlaneExtent by accident even if a future macOS has one.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <stdlib.h>
#include <string.h>
#import <float.h>

@interface CharonPortARPlaneExtent : NSObject <NSSecureCoding>
@property (nonatomic, readonly) float rotationOnYAxis;
@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) float height;
// The release's own method list carries these three (0x1af14f4d4, 0x1af14f4e4, 0x1af14f4f4) and its
// public header does not declare them, so they are declared here for the harness and claimed nowhere.
- (void)setRotationOnYAxis:(float)rotationOnYAxis;
- (void)setWidth:(float)width;
- (void)setHeight:(float)height;
// Reachable from the SDK's own NSObject declaration, so the port's answer to it is a caller's answer.
- (id)copyWithZone:(NSZone *)zone;
@end

// The release's class method list has exactly one entry and it is +supportsSecureCoding (read with
// tools/corpus/skeleton-table.lua), so the answer is the class's own and not an inherited one. This
// checks the same thing on the port's side: that the class itself carries the selector.
static BOOL class_implements(Class cls, SEL selector)
{
    unsigned count = 0;
    Method *found = class_copyMethodList(object_getClass(cls), &count);
    BOOL present = NO;
    for (unsigned index = 0; index < count; index++) {
        if (method_getName(found[index]) == selector)
            present = YES;
    }
    free(found);
    return present;
}

static int failures = 0;

static void ok(BOOL condition, NSString *what)
{
    if (condition) {
        printf("ok %s\n", what.UTF8String);
    } else {
        printf("FAIL %s\n", what.UTF8String);
        failures++;
    }
}

/// The bytes of an archive carry the key strings verbatim: a keyed archive is a binary property list
/// whose dictionaries are keyed by the very strings passed to -encode...forKey:. So the presence of a
/// string in the bytes is the check that the port wrote that key, and its absence is a check that it
/// did not.
static BOOL archive_carries(NSData *data, const char *key)
{
    return [data rangeOfData:[NSData dataWithBytes:key length:strlen(key)]
                     options:0
                       range:NSMakeRange(0, data.length)].location != NSNotFound;
}

int main(void)
{
    @autoreleasepool {
        CharonPortARPlaneExtent *fresh = [[CharonPortARPlaneExtent alloc] init];
        ok(fresh.rotationOnYAxis == 0.0f, @"a fresh extent's rotation is the release's zero");
        ok(fresh.width == -1.0f, @"a fresh extent's width is the release's -1");
        ok(fresh.height == -1.0f, @"a fresh extent's height is the release's -1");
        ok(![fresh isKindOfClass:[NSArray class]], @"the extent is not something else");

        ok([CharonPortARPlaneExtent supportsSecureCoding],
           @"the extent answers YES to +supportsSecureCoding");
        ok(class_implements([CharonPortARPlaneExtent class], @selector(supportsSecureCoding)),
           @"the class carries +supportsSecureCoding itself, as the release's one-entry class list does");

        CharonPortARPlaneExtent *extent = [[CharonPortARPlaneExtent alloc] init];
        [extent setRotationOnYAxis:0.7853981633974483f];
        [extent setWidth:2.5f];
        [extent setHeight:-0.25f];

        NSError *error = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:extent
                                                requiringSecureCoding:YES
                                                                error:&error];
        ok(archive != nil && error == nil, @"the port writes an archive of its own extent");
        ok(archive_carries(archive, "origin"), @"the archive carries the key origin");
        ok(archive_carries(archive, "width"), @"the archive carries the key width");
        ok(archive_carries(archive, "height"), @"the archive carries the key height");
        ok(!archive_carries(archive, "rotationOnYAxis"),
           @"the archive does not carry the property name as a key, which is what the release writes");

        NSError *failure = nil;
        CharonPortARPlaneExtent *read =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[CharonPortARPlaneExtent class]
                                              fromData:archive
                                                 error:&failure];
        ok(read != nil && failure == nil, @"the port reads its own archive back");
        ok(read.rotationOnYAxis == extent.rotationOnYAxis, @"the rotation survives the archive");
        ok(read.width == extent.width, @"the width survives the archive");
        ok(read.height == extent.height, @"the height survives the archive");

        // Values whose bits are not a short decimal, so a check that passed because both sides read
        // zero, or because a float comparison was widened, would go red here.
        CharonPortARPlaneExtent *odd = [[CharonPortARPlaneExtent alloc] init];
        [odd setRotationOnYAxis:0.1234567f];
        [odd setWidth:12345.6789f];
        [odd setHeight:-1.0e-8f];
        NSData *oddArchive = [NSKeyedArchiver archivedDataWithRootObject:odd
                                                   requiringSecureCoding:YES
                                                                   error:NULL];
        CharonPortARPlaneExtent *oddRead =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[CharonPortARPlaneExtent class]
                                              fromData:oddArchive
                                                 error:NULL];
        ok(oddRead != NULL, @"the second archive reads back");
        float gotRotation = oddRead.rotationOnYAxis, wantRotation = odd.rotationOnYAxis;
        float gotWidth = oddRead.width, wantWidth = odd.width;
        float gotHeight = oddRead.height, wantHeight = odd.height;
        ok(memcmp(&gotRotation, &wantRotation, sizeof(float)) == 0,
           @"the odd rotation survives bit for bit");
        ok(memcmp(&gotWidth, &wantWidth, sizeof(float)) == 0,
           @"the odd width survives bit for bit");
        ok(memcmp(&gotHeight, &wantHeight, sizeof(float)) == 0,
           @"the odd height survives bit for bit");

        // -isEqual: and -copyWithZone: are in the release's own method list (0x1af14f3bc and
        // 0x1af14f470) and both are reachable from the SDK's NSObject declarations, so a port that
        // did not carry them would answer identity where the release answers by value.
        CharonPortARPlaneExtent *twin = [[CharonPortARPlaneExtent alloc] init];
        [twin setRotationOnYAxis:extent.rotationOnYAxis];
        [twin setWidth:extent.width];
        [twin setHeight:extent.height];
        ok(twin != extent && [twin isEqual:extent] && [extent isEqual:twin],
           @"two extents with the same three floats are equal, and are not the same object");

        CharonPortARPlaneExtent *near = [[CharonPortARPlaneExtent alloc] init];
        [near setRotationOnYAxis:extent.rotationOnYAxis + FLT_EPSILON / 2];
        [near setWidth:extent.width];
        [near setHeight:extent.height];
        ok([near isEqual:extent],
           @"a rotation below the release's tolerance still counts as equal");

        CharonPortARPlaneExtent *far = [[CharonPortARPlaneExtent alloc] init];
        [far setRotationOnYAxis:extent.rotationOnYAxis + 1.0f];
        [far setWidth:extent.width];
        [far setHeight:extent.height];
        ok(![far isEqual:extent], @"a rotation the release can see is not equal");

        ok(![extent isEqual:@"not an extent"], @"an extent is not equal to a string");

        CharonPortARPlaneExtent *copy = [extent copyWithZone:NULL];
        ok(copy != extent, @"a copy is a different object");
        ok([copy isEqual:extent], @"a copy equals the original");
        ok(copy.rotationOnYAxis == extent.rotationOnYAxis && copy.width == extent.width &&
               copy.height == extent.height,
           @"a copy carries all three floats");

        printf("VERDICT %s\n", failures == 0 ? "ok" : "red");
    }
    return failures == 0 ? 0 : 1;
}