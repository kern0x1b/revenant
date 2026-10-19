#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import <objc/runtime.h>
#include <string.h>

static int failures = 0;
static int checks = 0;

static void check(BOOL ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", line.UTF8String);
    else { printf("  FAIL %s\n", line.UTF8String); failures++; }
}

static NSString *shapeOf(objc_property_t p)
{
    NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(p)];
    return [[attrs componentsSeparatedByString:@","] firstObject];
}

static NSDictionary<NSString *, NSString *> *shapesOf(Class c)
{
    unsigned n = 0;
    objc_property_t *list = class_copyPropertyList(c, &n);
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (unsigned i = 0; i < n; i++)
        out[[NSString stringWithUTF8String:property_getName(list[i])]] = shapeOf(list[i]);
    free(list);
    return out;
}

static NSString *valueDescription(id obj, NSString *key)
{
    id v = [obj valueForKey:key];
    return v == nil ? @"nil" : [v description];
}

typedef struct { const char *name; const char *properties; } Entry;

static const Entry entries[] = {
    { "ARFaceGeometry", "vertexCount vertices textureCoordinateCount textureCoordinates triangleCount triangleIndices" },
    { "ARSCNFaceGeometry", "" },
    { "ARReferenceObject", "name center extent scale resourceGroupName rawFeaturePoints" },
    { "ARMeshGeometry", "vertices normals faces classification" },
    { "ARGeometrySource", "buffer count format componentsPerVector offset stride" },
    { "ARGeometryElement", "buffer count bytesPerIndex indexCountPerPrimitive primitiveType" },
    { "ARMatteGenerator", "" },
    { "ARCollaborationData", "priority" },
    { "ARSkeleton", "definition jointCount" },
    { "ARSkeleton2D", "jointLandmarks" },
    { "ARSkeleton3D", "jointModelTransforms jointLocalTransforms" },
    { "ARBody2D", "skeleton" },
    { "ARGeoTrackingStatus", "state accuracy stateReason" },
};

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("controls\n");
        NSDictionary *camera = shapesOf(NSClassFromString(@"ARCamera"));
        NSDictionary *face = shapesOf(NSClassFromString(@"ARFaceGeometry"));
        check(camera.count > 0 && face.count > 0 && ![camera isEqualToDictionary:face],
              @"two different classes have different property shapes, so the comparison can fail");
        check(NSClassFromString(@"ZZZNoSuchNameCharonR16") == nil, @"a name no framework has is not a class");

        printf("the thirteen classes\n");
        for (size_t i = 0; i < sizeof entries / sizeof entries[0]; i++) {
            NSString *name = [NSString stringWithUTF8String:entries[i].name];
            NSMutableArray *expected = [[[NSString stringWithUTF8String:entries[i].properties]
                componentsSeparatedByString:@" "] mutableCopy];
            [expected removeObject:@""];
            Class host = NSClassFromString(name), port = NSClassFromString([@"CharonPort" stringByAppendingString:name]);
            check(host != nil, [name stringByAppendingString:@": the host has the class"]);
            check(port != nil, [name stringByAppendingString:@": the port has the class"]);
            if (!host || !port) continue;

            NSDictionary *hostShapes = shapesOf(host), *portShapes = shapesOf(port);
            for (NSString *key in expected) {
                NSString *hs = hostShapes[key], *ps = portShapes[key];
                check(ps != nil && [hs isEqualToString:ps],
                      [NSString stringWithFormat:@"%@.%@: the port declares it with the host's type %@", name, key, hs ?: @"none"]);
            }
            check([NSStringFromClass(class_getSuperclass(host)) isEqualToString:NSStringFromClass(class_getSuperclass(port))],
                  [NSString stringWithFormat:@"%@: superclass %@ on both", name, NSStringFromClass(class_getSuperclass(host))]);

            id ho = [[host alloc] init], po = [[port alloc] init];
            check(ho != nil && po != nil, [name stringByAppendingString:@": alloc and init answer an object on both"]);
            if (!ho || !po) continue;
            for (NSString *key in expected) {
                NSString *shape = hostShapes[key];
                if (shape.length < 2 || strchr("@qQBdf", [shape characterAtIndex:1]) == NULL) {
                    printf("  skip %s.%s: a %s, not read as a value\n", entries[i].name, key.UTF8String,
                           shape.length ? shape.UTF8String : "property the host lacks");
                    continue;
                }
                NSString *h = valueDescription(ho, key), *p = valueDescription(po, key);
                check([h isEqualToString:p],
                      [NSString stringWithFormat:@"%@.%@ answers %@ on the host and %@ on the port", name, key, h, p]);
            }
            if ([name isEqualToString:@"ARGeometryElement"]) {
                [ho setValue:@1 forKey:@"primitiveType"];
                [po setValue:@1 forKey:@"primitiveType"];
                NSString *h = valueDescription(ho, @"indexCountPerPrimitive"), *p = valueDescription(po, @"indexCountPerPrimitive");
                check([h isEqualToString:p] && [p isEqualToString:@"3"],
                      [NSString stringWithFormat:@"%@.indexCountPerPrimitive for a triangle answers %@ on the host and %@ on the port", name, h, p]);
            }
        }
        printf("%d checks\n", checks);
    }
    printf("%s\n", failures == 0 ? "VERDICT ok" : "VERDICT FAIL");
    return failures == 0 ? 0 : 1;
}
