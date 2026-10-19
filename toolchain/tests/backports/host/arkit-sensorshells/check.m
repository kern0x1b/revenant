#import <ARKit/ARKit.h>
#import <objc/runtime.h>
#import <simd/simd.h>
#import <stdio.h>

static int failures = 0;

static void verdict(BOOL ok, NSString *name, NSString *detail)
{
    if (ok) {
        printf("ok %s\n", name.UTF8String);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name.UTF8String, detail.UTF8String);
    }
}

static simd_float3 probeExtent(id probe) { return ((AREnvironmentProbeAnchor *)probe).extent; }
static simd_float4x4 anchorTransform(id anchor) { return ((ARAnchor *)anchor).transform; }
static id probeTexture(id probe) { return ((AREnvironmentProbeAnchor *)probe).environmentTexture; }
static NSString *anchorName(id anchor) { return ((ARAnchor *)anchor).name; }

static NSString *typeAndOwnership(const char *attributes)
{
    NSArray *fields = [@(attributes) componentsSeparatedByString:@","];
    NSMutableString *out = [NSMutableString stringWithString:fields[0]];
    for (NSString *field in fields)
        if ([field isEqualToString:@"C"] || [field isEqualToString:@"W"])
            [out appendFormat:@",%@", field];
    return out;
}

static NSString *compareProperties(Class port, Class host)
{
    NSMutableArray *differences = [NSMutableArray array];
    unsigned count = 0;
    objc_property_t *list = class_copyPropertyList(port, &count);
    for (unsigned i = 0; i < count; i++) {
        const char *name = property_getName(list[i]);
        objc_property_t hostProperty = class_getProperty(host, name);
        if (!hostProperty) {
            [differences addObject:[NSString stringWithFormat:@"%s missing on the host", name]];
            continue;
        }
        NSString *portAttributes = typeAndOwnership(property_getAttributes(list[i]));
        NSString *hostAttributes = typeAndOwnership(property_getAttributes(hostProperty));
        if (![portAttributes isEqualToString:hostAttributes])
            [differences addObject:[NSString stringWithFormat:@"%s: port %@, host %@", name, portAttributes, hostAttributes]];
    }
    free(list);
    return [differences componentsJoinedByString:@"; "];
}

static void compareShape(NSString *name, NSString *superName, Protocol *protocol)
{
    Class host = NSClassFromString(name);
    Class port = NSClassFromString([@"RevenantPort" stringByAppendingString:name]);
    if (!host || !port) {
        verdict(NO, [name stringByAppendingString:@" resolves"], @"one side answers nil");
        return;
    }
    verdict(YES, [name stringByAppendingString:@" resolves on both sides"], @"");
    NSString *hostSuper = NSStringFromClass(class_getSuperclass(host));
    NSString *portSuper = NSStringFromClass(class_getSuperclass(port));
    verdict([hostSuper isEqualToString:superName] && [portSuper isEqualToString:superName],
            [name stringByAppendingString:@" superclass"],
            [NSString stringWithFormat:@"host %@, port %@, expected %@", hostSuper, portSuper, superName]);
    if (protocol)
        verdict(class_conformsToProtocol(port, protocol) && class_conformsToProtocol(host, protocol),
                [name stringByAppendingString:@" protocol"],
                [NSString stringWithFormat:@"host %d, port %d", class_conformsToProtocol(host, protocol),
                 class_conformsToProtocol(port, protocol)]);
    NSString *differences = compareProperties(port, host);
    verdict([differences length] == 0, [name stringByAppendingString:@" declared properties"], differences);
}

int main(void)
{
    @autoreleasepool {
        compareShape(@"ARDepthData", @"NSObject", nil);
        compareShape(@"ARFaceAnchor", @"ARAnchor", @protocol(ARTrackable));
        compareShape(@"AREnvironmentProbeAnchor", @"ARAnchor", nil);
        compareShape(@"ARMeshAnchor", @"ARAnchor", nil);
        compareShape(@"ARObjectAnchor", @"ARAnchor", nil);
        compareShape(@"ARDirectionalLightEstimate", @"ARLightEstimate", nil);

        simd_float4x4 place = matrix_identity_float4x4;
        place.columns[3] = (simd_float4){1.5f, -2.0f, 0.25f, 1.0f};
        simd_float3 extent = {3.0f, 2.0f, 4.0f};
        id host = [[NSClassFromString(@"AREnvironmentProbeAnchor") alloc] initWithTransform:place extent:extent];
        id port = [[NSClassFromString(@"RevenantPortAREnvironmentProbeAnchor") alloc] initWithTransform:place extent:extent];
        verdict(host && port, @"probe: initWithTransform:extent: builds on both sides", @"a side answers nil");
        if (host && port) {
            simd_float3 hostExtent = probeExtent(host);
            simd_float3 portExtent = probeExtent(port);
            verdict(simd_equal(hostExtent, extent) && simd_equal(portExtent, extent), @"probe: extent round trip",
                    [NSString stringWithFormat:@"host %.2f %.2f %.2f, port %.2f %.2f %.2f",
                     hostExtent.x, hostExtent.y, hostExtent.z, portExtent.x, portExtent.y, portExtent.z]);
            verdict(simd_equal(anchorTransform(host), place) && simd_equal(anchorTransform(port), place),
                    @"probe: transform round trip", @"a side moved the place");
            verdict(probeTexture(host) == nil && probeTexture(port) == nil,
                    @"probe: no texture before a session renders one", @"a texture is present");
        }

        id hostNamed = [[NSClassFromString(@"AREnvironmentProbeAnchor") alloc] initWithName:@"room" transform:place extent:extent];
        id portNamed = [[NSClassFromString(@"RevenantPortAREnvironmentProbeAnchor") alloc] initWithName:@"room" transform:place extent:extent];
        verdict(hostNamed && portNamed, @"probe: initWithName:transform:extent: builds on both sides", @"a side answers nil");
        if (hostNamed && portNamed) {
            verdict([anchorName(hostNamed) isEqualToString:@"room"] && [anchorName(portNamed) isEqualToString:@"room"],
                    @"probe: name round trip", @"a side lost the name");
            verdict(simd_equal(probeExtent(portNamed), extent), @"probe: named extent round trip", @"the port lost the extent");
        }
    }
    printf("%s\n", failures == 0 ? "VERDICT ok" : "VERDICT FAIL");
    return failures == 0 ? 0 : 1;
}
