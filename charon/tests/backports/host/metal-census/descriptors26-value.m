/* descriptors26-value.m - the PORT'S answers to the value-equality questions, one line per class and
 * question, in the same shape descriptors26-apple.m prints for Apple's own objects.
 *
 * WHAT IS MEASURED HERE, and why it is a case of its own:
 *
 *   * two freshly made objects of each class are equal, their hashes agree, and a copy equals its
 *     source - measured on Apple's side too, in descriptors26-apple.m, and the two files are diffed;
 *   * changing ONE NAMED MEMBER makes them differ, on the port's side, which is what holds the
 *     implementation to its member list: a class that compared nothing would answer equal here too;
 *   * the eleven 0 tile classes carry NO -isEqual: of their own on Apple's side, measured, so the port
 *     adds none and two fresh ones are not equal - NSObject's pointer identity, which is Apple's.
 *
 * WHY A SEPARATE BINARY, and the trap that is actually worth naming: asking these questions in the big
 * case's binary printed a Trace/BPT trap inside objc_opt_respondsToSelector at the first such call. The
 * cause was in THIS file and not in the port: three of the messages were built with "%@" and a
 * `[name UTF8String]` - a C string where NSString's formatter expects an object - and the formatter
 * sends -respondsToSelector: to what it is handed. So the trap was a format string, not a difference
 * between two runtimes, and the honest fix is the format string. The two sides still have a binary each
 * because the comparison between them is a diff of two runs, which is easier to read than one case
 * asking both.
 *
 * Asking these questions in the big case's binary also traps: measured, a
 * Trace/BPT trap inside objc_opt_respondsToSelector at the first such call, reproducibly, and the
 * presence of the port's classes in the binary is the only difference that makes it. It traps here as
 * well if Apple's objects are asked in the same binary, so each side has one and the comparison between
 * them is a diff of two runs. The trap is recorded in facts/Metal/Descriptors26.md rather than avoided
 * by asking a weaker question.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

/* The port's classes, under the names the harness compiles them with. */
@interface charonHost_MTL4PipelineOptions : NSObject
@property (nonatomic) MTLShaderValidation shaderValidation;
@property (nonatomic) MTL4ShaderReflection shaderReflection;
@end
@interface charonHost_MTL4StaticLinkingDescriptor : NSObject
@property (nonatomic, copy) NSArray *functionDescriptors;
@end
@interface charonHost_MTL4PipelineStageDynamicLinkingDescriptor : NSObject
@end
@interface charonHost_MTL4RenderPipelineDynamicLinkingDescriptor : NSObject
@end
@interface charonHost_MTL4RenderPipelineBinaryFunctionsDescriptor : NSObject
@end
@interface charonHost_MTL4RenderPipelineColorAttachmentDescriptor : NSObject
@property (nonatomic) MTLColorWriteMask writeMask;
@end
@interface charonHost_MTL4RenderPipelineColorAttachmentDescriptorArray : NSObject
@end
@interface charonHost_MTL4PipelineDescriptor : NSObject
@property (nonatomic, copy) id label;
@property (nonatomic, retain) id options;
@end
@interface charonHost_MTL4RenderPipelineDescriptor : NSObject
@end
@interface charonHost_MTL4ComputePipelineDescriptor : NSObject
@property (nonatomic) MTLSize requiredThreadsPerThreadgroup;
@end
@interface charonHost_MTL4TileRenderPipelineDescriptor : NSObject
@end
@interface charonHost_MTL4MeshRenderPipelineDescriptor : NSObject
@end
@interface charonHost_MTL4FunctionDescriptor : NSObject
@end
@interface charonHost_MTL4SpecializedFunctionDescriptor : NSObject
@end
@interface charonHost_MTL4StitchedFunctionDescriptor : NSObject
@end
@interface charonHost_MTL4LibraryFunctionDescriptor : NSObject
@end
@interface charonHost_MTL4RenderPassDescriptor : NSObject <NSCopying>
@end
@interface charonHost_MTL4AccelerationStructureGeometryDescriptor : NSObject <NSCopying>
@end
@interface charonHost_MTL4AccelerationStructureTriangleGeometryDescriptor : charonHost_MTL4AccelerationStructureGeometryDescriptor
@end
@interface charonHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor : charonHost_MTL4AccelerationStructureGeometryDescriptor
@end
@interface charonHost_MTL4AccelerationStructureCurveGeometryDescriptor : charonHost_MTL4AccelerationStructureGeometryDescriptor
@end
@interface charonHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor : charonHost_MTL4AccelerationStructureGeometryDescriptor
@end
@interface charonHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor : charonHost_MTL4AccelerationStructureGeometryDescriptor
@end
@interface charonHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor : charonHost_MTL4AccelerationStructureGeometryDescriptor
@end
@interface charonHost_MTLTileRenderPipelineColorAttachmentDescriptor : NSObject <NSCopying>
@end
/* The tile ARRAY, whose three answers are the point: no -isEqual: and no -hash of its own on Apple's
 * side, measured, so two fresh ones are not equal and the port adds none. */
@interface charonHost_MTLTileRenderPipelineColorAttachmentDescriptorArray : NSObject
@end

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) printf("  ok   %s\n", [what UTF8String]);
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

static void same_value(NSString *name, id portA, id portB)
{
    BOOL freshEqual = [portA isEqual:portB];
    BOOL hashSame = [portA hash] == [portB hash];
    // -copyWithZone: AND NOT -copy: -copy is NSObject's convenience and the declaration's method is
    // NSCopying's, and asking -copy in a host binary that ALSO carries Apple's class of the same
    // members traps - measured, a Trace/BPT trap inside objc_opt_respondsToSelector. The protocol's
    // own method is the question the declaration asks anyway.
    id copied = [portA copyWithZone:NULL];
    BOOL copyEqual = [copied isEqual:portA];
    check(freshEqual, ([NSString stringWithFormat:@"%s: two fresh objects are equal", [name UTF8String]]));
    check(hashSame, ([NSString stringWithFormat:@"%s: two fresh objects hash the same", [name UTF8String]]));
    check(copyEqual, ([NSString stringWithFormat:@"%s: a copy equals its source", [name UTF8String]]));
    printf("%s fresh-equal %s\n", [name UTF8String], freshEqual ? "yes" : "no");
    printf("%s fresh-hash-same %s\n", [name UTF8String], hashSame ? "yes" : "no");
    printf("%s copy-equal %s\n", [name UTF8String], copyEqual ? "yes" : "no");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        same_value(@"MTL4PipelineOptions", (id)[[charonHost_MTL4PipelineOptions alloc] init], (id)[[charonHost_MTL4PipelineOptions alloc] init]);
        same_value(@"MTL4StaticLinkingDescriptor", (id)[[charonHost_MTL4StaticLinkingDescriptor alloc] init], (id)[[charonHost_MTL4StaticLinkingDescriptor alloc] init]);
        same_value(@"MTL4PipelineStageDynamicLinkingDescriptor", (id)[[charonHost_MTL4PipelineStageDynamicLinkingDescriptor alloc] init], (id)[[charonHost_MTL4PipelineStageDynamicLinkingDescriptor alloc] init]);
        same_value(@"MTL4RenderPipelineDynamicLinkingDescriptor", (id)[[charonHost_MTL4RenderPipelineDynamicLinkingDescriptor alloc] init], (id)[[charonHost_MTL4RenderPipelineDynamicLinkingDescriptor alloc] init]);
        same_value(@"MTL4RenderPipelineBinaryFunctionsDescriptor", (id)[[charonHost_MTL4RenderPipelineBinaryFunctionsDescriptor alloc] init], (id)[[charonHost_MTL4RenderPipelineBinaryFunctionsDescriptor alloc] init]);
        same_value(@"MTL4RenderPipelineColorAttachmentDescriptor", (id)[[charonHost_MTL4RenderPipelineColorAttachmentDescriptor alloc] init], (id)[[charonHost_MTL4RenderPipelineColorAttachmentDescriptor alloc] init]);
        same_value(@"MTL4RenderPipelineColorAttachmentDescriptorArray", (id)[[charonHost_MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init], (id)[[charonHost_MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init]);
        same_value(@"MTL4PipelineDescriptor", (id)[[charonHost_MTL4PipelineDescriptor alloc] init], (id)[[charonHost_MTL4PipelineDescriptor alloc] init]);
        same_value(@"MTL4RenderPipelineDescriptor", (id)[[charonHost_MTL4RenderPipelineDescriptor alloc] init], (id)[[charonHost_MTL4RenderPipelineDescriptor alloc] init]);
        same_value(@"MTL4ComputePipelineDescriptor", (id)[[charonHost_MTL4ComputePipelineDescriptor alloc] init], (id)[[charonHost_MTL4ComputePipelineDescriptor alloc] init]);
        same_value(@"MTL4TileRenderPipelineDescriptor", (id)[[charonHost_MTL4TileRenderPipelineDescriptor alloc] init], (id)[[charonHost_MTL4TileRenderPipelineDescriptor alloc] init]);
        same_value(@"MTL4MeshRenderPipelineDescriptor", (id)[[charonHost_MTL4MeshRenderPipelineDescriptor alloc] init], (id)[[charonHost_MTL4MeshRenderPipelineDescriptor alloc] init]);
        same_value(@"MTL4FunctionDescriptor", (id)[[charonHost_MTL4FunctionDescriptor alloc] init], (id)[[charonHost_MTL4FunctionDescriptor alloc] init]);
        same_value(@"MTL4SpecializedFunctionDescriptor", (id)[[charonHost_MTL4SpecializedFunctionDescriptor alloc] init], (id)[[charonHost_MTL4SpecializedFunctionDescriptor alloc] init]);
        same_value(@"MTL4StitchedFunctionDescriptor", (id)[[charonHost_MTL4StitchedFunctionDescriptor alloc] init], (id)[[charonHost_MTL4StitchedFunctionDescriptor alloc] init]);
        same_value(@"MTL4LibraryFunctionDescriptor", (id)[[charonHost_MTL4LibraryFunctionDescriptor alloc] init], (id)[[charonHost_MTL4LibraryFunctionDescriptor alloc] init]);
        same_value(@"MTL4RenderPassDescriptor", (id)[[charonHost_MTL4RenderPassDescriptor alloc] init], (id)[[charonHost_MTL4RenderPassDescriptor alloc] init]);
        /* ONE NAMED MEMBER PER CLASS, and the two sides of each answer are printed so a reader can see
         * what the port said and the script can hold it to the member list. */
        {
            charonHost_MTL4PipelineDescriptor *one = [[charonHost_MTL4PipelineDescriptor alloc] init];
            charonHost_MTL4PipelineDescriptor *two = [[charonHost_MTL4PipelineDescriptor alloc] init];
            check([one isEqual:two], @"two fresh MTL4PipelineDescriptors are equal");
            two.label = @"x";
            printf("MTL4PipelineDescriptor label-differs %s\n", [one isEqual:two] ? "no" : "yes");
            check(![one isEqual:two], @"a label makes them differ");
            one.label = @"x";
            printf("MTL4PipelineDescriptor label-same %s\n", [one isEqual:two] ? "yes" : "no");
            check([one isEqual:two], @"the same label makes them equal again");
        }
        {
            charonHost_MTL4RenderPipelineColorAttachmentDescriptor *one = [[charonHost_MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            charonHost_MTL4RenderPipelineColorAttachmentDescriptor *two = [[charonHost_MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            check([one isEqual:two], @"two fresh colour attachments are equal");
            two.writeMask = MTLColorWriteMaskRed;
            printf("MTL4RenderPipelineColorAttachmentDescriptor writemask-differs %s\n", [one isEqual:two] ? "no" : "yes");
            check(![one isEqual:two], @"a write mask makes them differ");
        }
        {
            charonHost_MTL4ComputePipelineDescriptor *one = [[charonHost_MTL4ComputePipelineDescriptor alloc] init];
            charonHost_MTL4ComputePipelineDescriptor *two = [[charonHost_MTL4ComputePipelineDescriptor alloc] init];
            check([one isEqual:two], @"two fresh compute descriptors are equal");
            two.requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 3);
            printf("MTL4ComputePipelineDescriptor threadsize-differs %s\n", [one isEqual:two] ? "no" : "yes");
            check(![one isEqual:two], @"a required threadgroup size whose DEPTH alone differs makes them differ");
        }
        {
            charonHost_MTL4PipelineOptions *one = [[charonHost_MTL4PipelineOptions alloc] init];
            charonHost_MTL4PipelineOptions *two = [[charonHost_MTL4PipelineOptions alloc] init];
            check([one isEqual:two], @"two fresh MTL4PipelineOptions are equal");
            two.shaderReflection = MTL4ShaderReflectionBindingInfo;
            printf("MTL4PipelineOptions reflection-differs %s\n", [one isEqual:two] ? "no" : "yes");
            check(![one isEqual:two], @"a shader reflection makes them differ");
            two.shaderValidation = MTLShaderValidationDisabled;
            printf("MTL4PipelineOptions validation-differs %s\n", [one isEqual:two] ? "no" : "yes");
        }
        {
            charonHost_MTL4StaticLinkingDescriptor *one = [[charonHost_MTL4StaticLinkingDescriptor alloc] init];
            charonHost_MTL4StaticLinkingDescriptor *two = [[charonHost_MTL4StaticLinkingDescriptor alloc] init];
            check([one isEqual:two], @"two fresh static linking descriptors are equal");
            two.functionDescriptors = @[@"a"];
            check(![one isEqual:two], @"a function list makes them differ");
        }

        same_value(@"MTL4AccelerationStructureGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureGeometryDescriptor alloc] init]);
        same_value(@"MTL4AccelerationStructureTriangleGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureTriangleGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureTriangleGeometryDescriptor alloc] init]);
        same_value(@"MTL4AccelerationStructureBoundingBoxGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor alloc] init]);
        same_value(@"MTL4AccelerationStructureCurveGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureCurveGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureCurveGeometryDescriptor alloc] init]);
        same_value(@"MTL4AccelerationStructureMotionTriangleGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor alloc] init]);
        same_value(@"MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor alloc] init]);
        same_value(@"MTL4AccelerationStructureMotionCurveGeometryDescriptor", (id)[[charonHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor alloc] init], (id)[[charonHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor alloc] init]);
        /* THE TILE COLOUR ATTACHMENT'S THREE LINES ARE NOT IN EITHER RUN, and the reason is a harness
         * limitation rather than a member: the 16.4 SDK this package compiles against already DECLARES
         * MTLTileRenderPipelineColorAttachmentDescriptor, so the rename that gives the port's classes
         * another name cannot reach a class the SDK owns and the port's object carries the array but not
         * the attachment under the renamed name. Apple's own answers for all three are measured and are in
         * facts/Metal/Descriptors26.md; the port adds no -isEqual: to that class either, so it keeps
         * NSObject's identity equality like Apple's. */
        /* THE TILE COLOUR ATTACHMENT'S THREE LINES ARE NOT IN EITHER RUN, and the reason is a harness
         * limitation rather than a member: the 16.4 SDK this package compiles against already DECLARES
         * MTLTileRenderPipelineColorAttachmentDescriptor, so the rename that gives the port's classes
         * another name cannot reach a class the SDK owns. Apple's own three answers are measured and are
         * in facts/Metal/Descriptors26.md. The tile ARRAY is here, and its three answers are the point:
         * no -isEqual: and no -hash of its own on Apple's side, measured, so two fresh ones are not equal
         * and the port adds none. */
        {
            charonHost_MTLTileRenderPipelineColorAttachmentDescriptorArray *one = [[charonHost_MTLTileRenderPipelineColorAttachmentDescriptorArray alloc] init];
            charonHost_MTLTileRenderPipelineColorAttachmentDescriptorArray *two = [[charonHost_MTLTileRenderPipelineColorAttachmentDescriptorArray alloc] init];
            printf("MTLTileRenderPipelineColorAttachmentDescriptorArray fresh-equal %s\n", [one isEqual:two] ? "yes" : "no");
            printf("MTLTileRenderPipelineColorAttachmentDescriptorArray fresh-hash-same %s\n", [one hash] == [two hash] ? "yes" : "no");
            printf("MTLTileRenderPipelineColorAttachmentDescriptorArray copy-equal not asked\n");
            check(![one isEqual:two], @"the tile array keeps NSObject's identity equality, as Apple's own does");
        }
    }
    printf("%d checks\n", checks);
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
