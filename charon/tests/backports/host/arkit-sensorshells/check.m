// check.m - the six sensor-data classes of ARKit against the host's own ARKit, on Mac Catalyst.
//
// The host's ARKit.framework (the iOSSupport copy in the macOS SDK) answers for every class named here, and
// so does the port: the port's files are compiled into this program with each class renamed to
// CharonPort<name>, so both are alive in one process and nothing is taken on trust from either side.
//
// What is compared: the superclass; the protocol ARFaceAnchor adopts; every property the port declares,
// found on the host by name and compared by type and ownership (the SDK declaration is the contract, so
// readonly is not compared: the host's runtime attribute is its implementation's); and, for
// AREnvironmentProbeAnchor, what its two extent initialisers answer - the extent, the place, the name, and a
// texture that is nil because no session renders one.
//
// What is not compared: a property the host carries and the port does not. The host's release is later than
// the band the port is built for, so it has members the port never declared; that is not a difference in
// what the port carries.
//
// What is not measured at all: a session. No session runs here, so no ARFaceAnchor, ARDepthData, ARMeshAnchor,
// ARObjectAnchor or ARDirectionalLightEstimate is ever produced by either side.

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

// The probe and the anchor read through their declared types, so each value has the type the SDK gives it.
// The receiver is the host's class or the port's; the selector decides which implementation answers.
static simd_float3 probeExtent(id probe) { return ((AREnvironmentProbeAnchor *)probe).extent; }
static simd_float4x4 anchorTransform(id anchor) { return ((ARAnchor *)anchor).transform; }
static id probeTexture(id probe) { return ((AREnvironmentProbeAnchor *)probe).environmentTexture; }
static NSString *anchorName(id anchor) { return ((ARAnchor *)anchor).name; }

// The type and ownership of a property as the runtime states them: T<type>, then copy (C) or weak (W). Retain
// (&) is left out, and so is readonly: the host states ARC strong (&) on environmentTexture and does not on geometry,
// which is also declared strong, so the flag does not say the same thing on both sides of one framework.
static NSString *typeAndOwnership(const char *attributes)
{
    NSArray *fields = [@(attributes) componentsSeparatedByString:@","];
    NSMutableString *out = [NSMutableString stringWithString:fields[0]];
    for (NSString *field in fields)
        if ([field isEqualToString:@"C"] || [field isEqualToString:@"W"])
            [out appendFormat:@",%@", field];
    return out;
}

// Every property the port declares, found on the host by name. A name the host lacks is a difference; a
// name the host has with another type or ownership is a difference. Returns the differences, or "" for none.
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

// One class: the port's (renamed) against the host's.
static void compareShape(NSString *name, NSString *superName, Protocol *protocol)
{
    Class host = NSClassFromString(name);
    Class port = NSClassFromString([@"CharonPort" stringByAppendingString:name]);
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

        // The probe's constructors: the port's and the host's answer the same extent, place, name and texture.
        simd_float4x4 place = matrix_identity_float4x4;
        place.columns[3] = (simd_float4){1.5f, -2.0f, 0.25f, 1.0f};
        simd_float3 extent = {3.0f, 2.0f, 4.0f};
        id host = [[NSClassFromString(@"AREnvironmentProbeAnchor") alloc] initWithTransform:place extent:extent];
        id port = [[NSClassFromString(@"CharonPortAREnvironmentProbeAnchor") alloc] initWithTransform:place extent:extent];
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
        id portNamed = [[NSClassFromString(@"CharonPortAREnvironmentProbeAnchor") alloc] initWithName:@"room" transform:place extent:extent];
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
