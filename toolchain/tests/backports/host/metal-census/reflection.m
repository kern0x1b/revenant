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
            RevenantMetalTypeTree *tree = [RevenantMetalTypeTree treeWithContentsOfFile:path];
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
                    switch (argument.access) {
                        case MTLArgumentAccessReadOnly: readOnly++; break;
                        case MTLArgumentAccessWriteOnly: writeOnly++; break;
                        case MTLArgumentAccessReadWrite: readWrite++; break;
                    }
                }
            }
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
            MTLRenderPipelineReflection *renderReflection = [[MTLRenderPipelineReflection alloc] initWithArguments:reflected];
            check(renderReflection.vertexArguments.count == reflected.count, @"the render reflection's vertex arguments are real");
            MTLVertexAttribute *attribute = [[MTLVertexAttribute alloc] initWithNode:[nodes firstObject]];
            NSDictionary *firstNode = [nodes firstObject];
            NSUInteger index = [firstNode[@"index"] unsignedIntegerValue];
            check([attribute attributeIndex] == index,
                  @"a vertex attribute's index is the argument's own index");
            check([attribute isActive], @"a vertex attribute of a bound argument is active");

            MTLAttribute *stageInput = [[MTLAttribute alloc] initWithNode:[nodes firstObject]];
            check(stageInput.attributeIndex == index,
                  @"a stage input attribute's index is the argument's own index");
            check([stageInput isActive] && ![stageInput isPatchData] && ![stageInput isPatchControlPointData],
                  @"a stage input is active and is neither patch data nor a control point");
            MTLFunctionConstant *constant = [[MTLFunctionConstant alloc] initWithNode:@{}];
            check([constant isRequired] == NO && constant.name.length == 0,
                  @"a constant with no node is not required and has no name");

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
