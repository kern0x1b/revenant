#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <stdlib.h>
#include <string.h>
#import <float.h>

@interface RevenantPortARPlaneExtent : NSObject <NSSecureCoding>
@property (nonatomic, readonly) float rotationOnYAxis;
@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) float height;
- (void)setRotationOnYAxis:(float)rotationOnYAxis;
- (void)setWidth:(float)width;
- (void)setHeight:(float)height;
- (id)copyWithZone:(NSZone *)zone;
@end

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

static BOOL archive_carries(NSData *data, const char *key)
{
    return [data rangeOfData:[NSData dataWithBytes:key length:strlen(key)]
                     options:0
                       range:NSMakeRange(0, data.length)].location != NSNotFound;
}

int main(void)
{
    @autoreleasepool {
        RevenantPortARPlaneExtent *fresh = [[RevenantPortARPlaneExtent alloc] init];
        ok(fresh.rotationOnYAxis == 0.0f, @"a fresh extent's rotation is the release's zero");
        ok(fresh.width == -1.0f, @"a fresh extent's width is the release's -1");
        ok(fresh.height == -1.0f, @"a fresh extent's height is the release's -1");
        ok(![fresh isKindOfClass:[NSArray class]], @"the extent is not something else");

        ok([RevenantPortARPlaneExtent supportsSecureCoding],
           @"the extent answers YES to +supportsSecureCoding");
        ok(class_implements([RevenantPortARPlaneExtent class], @selector(supportsSecureCoding)),
           @"the class carries +supportsSecureCoding itself, as the release's one-entry class list does");

        RevenantPortARPlaneExtent *extent = [[RevenantPortARPlaneExtent alloc] init];
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
        RevenantPortARPlaneExtent *read =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[RevenantPortARPlaneExtent class]
                                              fromData:archive
                                                 error:&failure];
        ok(read != nil && failure == nil, @"the port reads its own archive back");
        ok(read.rotationOnYAxis == extent.rotationOnYAxis, @"the rotation survives the archive");
        ok(read.width == extent.width, @"the width survives the archive");
        ok(read.height == extent.height, @"the height survives the archive");

        RevenantPortARPlaneExtent *odd = [[RevenantPortARPlaneExtent alloc] init];
        [odd setRotationOnYAxis:0.1234567f];
        [odd setWidth:12345.6789f];
        [odd setHeight:-1.0e-8f];
        NSData *oddArchive = [NSKeyedArchiver archivedDataWithRootObject:odd
                                                   requiringSecureCoding:YES
                                                                   error:NULL];
        RevenantPortARPlaneExtent *oddRead =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[RevenantPortARPlaneExtent class]
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

        RevenantPortARPlaneExtent *twin = [[RevenantPortARPlaneExtent alloc] init];
        [twin setRotationOnYAxis:extent.rotationOnYAxis];
        [twin setWidth:extent.width];
        [twin setHeight:extent.height];
        ok(twin != extent && [twin isEqual:extent] && [extent isEqual:twin],
           @"two extents with the same three floats are equal, and are not the same object");

        RevenantPortARPlaneExtent *near = [[RevenantPortARPlaneExtent alloc] init];
        [near setRotationOnYAxis:extent.rotationOnYAxis + FLT_EPSILON / 2];
        [near setWidth:extent.width];
        [near setHeight:extent.height];
        ok([near isEqual:extent],
           @"a rotation below the release's tolerance still counts as equal");

        RevenantPortARPlaneExtent *far = [[RevenantPortARPlaneExtent alloc] init];
        [far setRotationOnYAxis:extent.rotationOnYAxis + 1.0f];
        [far setWidth:extent.width];
        [far setHeight:extent.height];
        ok(![far isEqual:extent], @"a rotation the release can see is not equal");

        ok(![extent isEqual:@"not an extent"], @"an extent is not equal to a string");

        RevenantPortARPlaneExtent *copy = [extent copyWithZone:NULL];
        ok(copy != extent, @"a copy is a different object");
        ok([copy isEqual:extent], @"a copy equals the original");
        ok(copy.rotationOnYAxis == extent.rotationOnYAxis && copy.width == extent.width &&
               copy.height == extent.height,
           @"a copy carries all three floats");

        printf("VERDICT %s\n", failures == 0 ? "ok" : "red");
    }
    return failures == 0 ? 0 : 1;
}
