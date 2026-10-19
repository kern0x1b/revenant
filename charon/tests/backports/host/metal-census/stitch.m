/* A round trip through the stitching objects, against the header's own property names.
 *
 * Compiled in ONE clang line together with the port's source, the way
 * tests/backports/host/security/run-cases.sh does it: a test and the port sources it exercises are
 * built together, so there is no second object whose architecture has to match. An earlier version
 * compiled the port's source for the DEVICE and linked that object into a HOST test, and ld ignored it
 * - "building for macOS but attempting to link with file built for iOS" - which surfaced as an
 * undefined _main and looked like a missing test rather than a mismatched object.
 *
 * Every name here is the header's: MTLFunctionStitching.h:50 argumentIndex, :60-62
 * name/arguments/controlDependencies, :75-78 functionName/nodes/outputNode/attributes, :91-92
 * functionGraphs/functions. An earlier version of the OBJECT called the descriptor's property
 * functionsFromGraphs, which the header does not declare, and a test written against the header could
 * not see it - which is how that defect was found.
 *
 * No device: every one of these is a data container that asks nothing of the hardware, which is the
 * property that makes them carried in the first place.
 */
#import <Foundation/Foundation.h>
#import "CharonMetal.h"

static int failures;

static void check(BOOL ok, NSString *what)
{
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

int main(void)
{
    @autoreleasepool {
        MTLFunctionStitchingInputNode *a0 = [[MTLFunctionStitchingInputNode alloc] initWithArgumentIndex:0];
        MTLFunctionStitchingInputNode *a1 = [[MTLFunctionStitchingInputNode alloc] initWithArgumentIndex:1];
        check(a0.argumentIndex == 0 && a1.argumentIndex == 1, @"two input nodes carry their own index");
        a0.argumentIndex = 7;
        check(a0.argumentIndex == 7, @"argumentIndex is readwrite");

        MTLFunctionStitchingFunctionNode *fn = [[MTLFunctionStitchingFunctionNode alloc]
            initWithName:@"charonBlend" arguments:@[a0, a1] controlDependencies:@[]];
        check([fn.name isEqualToString:@"charonBlend"], @"a function node reads its name back");
        check(fn.arguments.count == 2 && fn.arguments[0] == a0 && fn.arguments[1] == a1,
              @"a function node reads both argument nodes back, in order");
        check(fn.controlDependencies.count == 0, @"an empty control-dependency list reads back empty");

        MTLFunctionStitchingAttributeAlwaysInline *attr =
            [[MTLFunctionStitchingAttributeAlwaysInline alloc] init];
        MTLFunctionStitchingGraph *graph = [[MTLFunctionStitchingGraph alloc]
            initWithFunctionName:@"charonStitched" nodes:@[fn] outputNode:fn attributes:@[attr]];
        check([graph.functionName isEqualToString:@"charonStitched"], @"a graph reads its functionName");
        check(graph.nodes.count == 1 && graph.nodes[0] == fn, @"a graph reads its node list back");
        check(graph.outputNode == fn, @"the output node that was SET is that node");
        check(graph.attributes.count == 1 && graph.attributes[0] == attr,
              @"a graph reads its attribute list back");

        // the header's outputNode is NULLABLE, so a graph built without one must keep nil
        MTLFunctionStitchingGraph *noOutput = [[MTLFunctionStitchingGraph alloc]
            initWithFunctionName:@"charonNoOutput" nodes:@[] outputNode:nil attributes:@[]];
        check(noOutput.outputNode == nil, @"an outputNode that was not set stays nil");

        // a copy is a NEW object with equal values - NSCopying, which every one of these declares
        MTLFunctionStitchingGraph *gcopy = [graph copyWithZone:nil];
        check(gcopy != graph && [gcopy.functionName isEqualToString:graph.functionName] &&
              gcopy.nodes.count == graph.nodes.count && gcopy.outputNode == graph.outputNode &&
              gcopy.attributes.count == graph.attributes.count,
              @"a graph's copy is a different object with the same values");
        MTLFunctionStitchingInputNode *ncopy = [a0 copyWithZone:nil];
        check(ncopy != a0 && ncopy.argumentIndex == a0.argumentIndex,
              @"an input node's copy is a different object with the same index");
        MTLFunctionStitchingFunctionNode *fcopy = [fn copyWithZone:nil];
        check(fcopy != fn && [fcopy.name isEqualToString:fn.name] &&
              fcopy.arguments.count == fn.arguments.count,
              @"a function node's copy is a different object with the same values");

        MTLStitchedLibraryDescriptor *descriptor = [[MTLStitchedLibraryDescriptor alloc] init];
        descriptor.functionGraphs = @[graph];
        descriptor.functions = @[];
        check(descriptor.functionGraphs.count == 1 &&
              [(descriptor.functionGraphs[0]).functionName isEqualToString:@"charonStitched"],
              @"a descriptor holds a graph under the header's functionGraphs and reads it back");
        check(descriptor.functions.count == 0, @"the header's functions list reads back empty");
        MTLStitchedLibraryDescriptor *dcopy = [descriptor copyWithZone:nil];
        check(dcopy != descriptor && dcopy.functionGraphs.count == descriptor.functionGraphs.count,
              @"a descriptor's copy is a different object with the same graphs");

        // MTLRenderPipelineFunctionsDescriptor: three nullable lists, carried on every device, and
        // empty is the header's own nullable answer - the port makes no binary functions.
        MTLRenderPipelineFunctionsDescriptor *binaries = [[MTLRenderPipelineFunctionsDescriptor alloc] init];
        check(binaries.vertexAdditionalBinaryFunctions == nil &&
              binaries.fragmentAdditionalBinaryFunctions == nil &&
              binaries.tileAdditionalBinaryFunctions == nil,
              @"a fresh binary-functions descriptor has all three lists nil, as the header's nullable says");
        binaries.vertexAdditionalBinaryFunctions = @[fn];
        binaries.tileAdditionalBinaryFunctions = @[fn];
        check(binaries.vertexAdditionalBinaryFunctions.count == 1 &&
              binaries.fragmentAdditionalBinaryFunctions == nil &&
              binaries.tileAdditionalBinaryFunctions.count == 1,
              @"two of the three lists round-trip and the one left unset stays nil");
        MTLRenderPipelineFunctionsDescriptor *bcopy = [binaries copyWithZone:nil];
        check(bcopy != binaries &&
              bcopy.vertexAdditionalBinaryFunctions.count == 1 &&
              bcopy.fragmentAdditionalBinaryFunctions == nil &&
              bcopy.tileAdditionalBinaryFunctions.count == 1,
              @"its copy is a different object carrying the same three lists");
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
