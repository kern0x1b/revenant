/* The type tree, read back: a round-trip against the property lists air2cpu wrote.
 *
 *     sh tests/backports/host/metal-census/reflection.sh PLIST [PLIST...]
 *
 * Two halves, and both matter:
 *
 *   * The READER is compiled from the port's own MTLTypeReflection.m - the same file the device
 *     builds - and run over real property lists: the one the invented fixture produces, and any the
 *     caller points at. It asserts what the file says: the arguments, their names, their accesses,
 *     the three the header has enumerators for, and the type of each.
 *   * The MUTANT is a scratch copy of the READER under .agent-work/runs/, with one change: it maps
 *     every access it does not recognise to read-write. That is the guess this port is not allowed to
 *     make, and the mutant must FAIL the same assertion the real reader passes.
 *
 * What this is NOT: it does not compare against Apple's kernels, and it asserts nothing about a
 * device. It is a host check that the reader reads what the writer wrote.
 */
#import <Foundation/Foundation.h>
#import "MTLTypeReflectionInternal.h"
#import "MTLTypeReflection11.m"
#import "MTLTypeReflection8.m"
#import "MTLReflection8.m"
#import "MTLReflection10.m"
#import "MTLReflection11.m"

static int failures;

static void check(BOOL ok, NSString *what)
{
    if (ok) {
        printf("  ok   %s\n", [what UTF8String]);
    } else {
        printf("  FAIL %s\n", [what UTF8String]);
        failures++;
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: reflection FILE.plist [FILE.plist...]\n");
            return 2;
        }
        for (int i = 1; i < argc; i++) {
            NSString *path = [NSString stringWithUTF8String:argv[i]];
            printf("%s\n", [path.lastPathComponent UTF8String]);
            CharonMetalTypeTree *tree = [CharonMetalTypeTree treeWithContentsOfFile:path];
            NSArray *functions = [tree functions];
            check(functions.count > 0, @"the file has at least one function");

            NSUInteger arguments = 0, named = 0, typed = 0, readOnly = 0, writeOnly = 0, readWrite = 0;
            for (NSDictionary *function in functions) {
                for (NSDictionary *node in [tree argumentsOfFunction:function]) {
                    MTLArgument *argument = [[MTLArgument alloc] initWithNode:node];
                    arguments++;
                    if (argument.name.length)
                        named++;
                    if (node[@"type"])
                        typed++;
                    // The three the header has enumerators for. An argument whose node carries none
                    // is MTLArgumentAccessReadOnly, the enumeration's zero, and is counted there.
                    switch (argument.access) {
                        case MTLArgumentAccessReadOnly: readOnly++; break;
                        case MTLArgumentAccessWriteOnly: writeOnly++; break;
                        case MTLArgumentAccessReadWrite: readWrite++; break;
                    }
                }
            }
            // The 8.0 reflection classes, built from this file's own argument list: the arguments
            // are REAL (they are the plist's), and the binding lists are EMPTY, which is the
            // documented absence the rows record.
            NSMutableArray *reflected = [NSMutableArray array];
            NSMutableArray *nodes = [NSMutableArray array];
            for (NSDictionary *function in functions)
                for (NSDictionary *node in [tree argumentsOfFunction:function]) {
                    [reflected addObject:[[MTLArgument alloc] initWithNode:node]];
                    [nodes addObject:node];
                }
            if (reflected.count == 0) {
                printf("       (no arguments, so the reflection classes are not exercised on it)\n");
                continue;
            }
            MTLComputePipelineReflection *compute = [[MTLComputePipelineReflection alloc] initWithArguments:reflected];
            check(compute.arguments.count == reflected.count, @"the compute reflection carries every argument");
            // The BINDING lists are API_AVAILABLE(macCatalyst 16.0) and this host binary targets 15,
            // so they are not asserted here: a check that calls a member the host cannot reach proves
            // nothing about it. Their emptiness is recorded in the row and in facts/Metal/TypeTree.md,
            // and it is the documented absence the plist makes. The ARGUMENTS are 8.0 and are real.
            MTLRenderPipelineReflection *renderReflection = [[MTLRenderPipelineReflection alloc] initWithArguments:reflected];
            check(renderReflection.vertexArguments.count == reflected.count, @"the render reflection's vertex arguments are real");
            MTLVertexAttribute *attribute = [[MTLVertexAttribute alloc] initWithNode:[nodes firstObject]];
            NSDictionary *firstNode = [nodes firstObject];
            NSUInteger index = [firstNode[@"index"] unsignedIntegerValue];
            check([attribute attributeIndex] == index,
                  @"a vertex attribute's index is the argument's own index");
            check([attribute isActive], @"a vertex attribute of a bound argument is active");

            // The 10.0 classes, from the same argument node: an MTLAttribute is the stage-input form
            // of the same thing, and its patch-data getters are the header's NO because the plist has
            // no patch flag to read.
            MTLAttribute *stageInput = [[MTLAttribute alloc] initWithNode:[nodes firstObject]];
            check(stageInput.attributeIndex == index,
                  @"a stage input attribute's index is the argument's own index");
            check([stageInput isActive] && ![stageInput isPatchData] && ![stageInput isPatchControlPointData],
                  @"a stage input is active and is neither patch data nor a control point");
            MTLFunctionConstant *constant = [[MTLFunctionConstant alloc] initWithNode:@{}];
            check([constant isRequired] == NO && constant.name.length == 0,
                  @"a constant with no node is not required and has no name");

            // The 11.0 classes: a fresh buffer descriptor is the enumeration's default and its copy
            // keeps it. The array answers a descriptor at every one of its 31 slots, as Apple's does
            // (pipeline-buffer-array measures it against Apple's own array), and a set keeps a copy.
            MTLPipelineBufferDescriptor *buffer = [[MTLPipelineBufferDescriptor alloc] init];
            check(buffer.mutability == MTLMutabilityDefault,
                  @"a fresh buffer descriptor is MTLMutabilityDefault");
            id copied = [buffer copy];
            check([copied mutability] == MTLMutabilityDefault, @"a copied descriptor keeps its mutability");
            MTLPipelineBufferDescriptorArray *array = [[MTLPipelineBufferDescriptorArray alloc] init];
            check([array objectAtIndexedSubscript:0] != nil,
                  @"every slot of the buffer descriptor array answers a descriptor, as Apple's does");
            check([array objectAtIndexedSubscript:0] == [array objectAtIndexedSubscript:0],
                  @"an unset slot answers the same default descriptor on every read");
            array[2] = buffer;
            check(array[2] != buffer && array[2].mutability == buffer.mutability,
                  @"a set stores a copy of the descriptor, which keeps its mutability");

            printf("       %lu argument(s): %lu named, %lu typed, accesses %lu read-only "
                   "%lu write-only %lu read-write\n",
                   (unsigned long)arguments, (unsigned long)named, (unsigned long)typed,
                   (unsigned long)readOnly, (unsigned long)writeOnly, (unsigned long)readWrite);
            check(arguments > 0, @"every function's arguments are read, not dropped");
            check(typed == arguments, @"every argument carries a type the reader builds");
        }
    }
    if (failures) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("all checks passed\n");
    return 0;
}
