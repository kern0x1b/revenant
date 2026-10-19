/* descriptors26-apple.m - APPLE'S OWN ANSWERS to the value-equality questions, in a binary of its own.
 *
 * WHY A SEPARATE BINARY. descriptors26.m carries the port's classes under other names, and asking
 * Apple's -[MTL4PipelineOptions isEqual:] in THAT binary traps: measured, a Trace/BPT trap inside
 * objc_opt_respondsToSelector at the first such call, reproducibly, with the port's classes linked and
 * not linked being the only difference. So Apple's side is asked here, where no class of the port's is
 * present at all, and descriptors26.sh compares this file's output with the port's.
 *
 * Both sides are therefore MEASURED, and neither is assumed: the script diffs two runs rather than one
 * case asking both, and the trap that forced this shape is recorded rather than avoided by asking a
 * weaker question of Apple.
 *
 * ONE LINE PER CLASS AND QUESTION, so the comparison is a diff and a reader can see what each side said:
 *   <class> fresh-equal <yes|no>     two freshly made objects of Apple's class
 *   <class> fresh-hash-same <yes|no>
 *   <class> copy-equal <yes|no>      a copy against its source
 *   <class> own-isEqual <yes|no>     whether the class carries an -isEqual: OF ITS OWN, which is what
 *                                    decides whether the port adds one: measured, the sixteen MTL4*
 *                                    classes do and the two 11.0 tile classes do not.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>

static BOOL hasOwnIsEqual(Class c)
{
    unsigned count = 0;
    Method *list = class_copyMethodList(c, &count);
    BOOL found = NO;
    for (unsigned i = 0; i < count; i++)
        if (sel_isEqual(method_getName(list[i]), @selector(isEqual:))) { found = YES; break; }
    free(list);
    return found;
}

/* $2 is NO for the one class whose declaration does not adopt NSCopying: asking it to copy RAISES an
 * NSException on Apple's side too, which is what its own method list says, so it is not asked and the
 * copy line for it is printed as "not asked" on both sides rather than answered. */
static void report(Class c, const char *name, BOOL copies)
{
    id a = [[c alloc] init];
    id b = [[c alloc] init];
    printf("%s fresh-equal %s\n", name, [a isEqual:b] ? "yes" : "no");
    printf("%s fresh-hash-same %s\n", name, [a hash] == [b hash] ? "yes" : "no");
    if (copies)
        printf("%s copy-equal %s\n", name, [[a copyWithZone:NULL] isEqual:a] ? "yes" : "no");
    else
        printf("%s copy-equal not asked\n", name);
    printf("%s own-isEqual %s\n", name, hasOwnIsEqual(c) ? "yes" : "no");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        report([MTL4PipelineOptions class], "MTL4PipelineOptions", YES);
        report([MTL4StaticLinkingDescriptor class], "MTL4StaticLinkingDescriptor", YES);
        report([MTL4PipelineStageDynamicLinkingDescriptor class], "MTL4PipelineStageDynamicLinkingDescriptor", YES);
        report([MTL4RenderPipelineDynamicLinkingDescriptor class], "MTL4RenderPipelineDynamicLinkingDescriptor", YES);
        report([MTL4RenderPipelineBinaryFunctionsDescriptor class], "MTL4RenderPipelineBinaryFunctionsDescriptor", YES);
        report([MTL4RenderPipelineColorAttachmentDescriptor class], "MTL4RenderPipelineColorAttachmentDescriptor", YES);
        report([MTL4RenderPipelineColorAttachmentDescriptorArray class], "MTL4RenderPipelineColorAttachmentDescriptorArray", YES);
        report([MTL4PipelineDescriptor class], "MTL4PipelineDescriptor", YES);
        report([MTL4RenderPipelineDescriptor class], "MTL4RenderPipelineDescriptor", YES);
        report([MTL4ComputePipelineDescriptor class], "MTL4ComputePipelineDescriptor", YES);
        report([MTL4TileRenderPipelineDescriptor class], "MTL4TileRenderPipelineDescriptor", YES);
        report([MTL4MeshRenderPipelineDescriptor class], "MTL4MeshRenderPipelineDescriptor", YES);
        report([MTL4FunctionDescriptor class], "MTL4FunctionDescriptor", YES);
        report([MTL4SpecializedFunctionDescriptor class], "MTL4SpecializedFunctionDescriptor", YES);
        report([MTL4StitchedFunctionDescriptor class], "MTL4StitchedFunctionDescriptor", YES);
        report([MTL4LibraryFunctionDescriptor class], "MTL4LibraryFunctionDescriptor", YES);
        report([MTL4RenderPassDescriptor class], "MTL4RenderPassDescriptor", YES);
        report([MTL4AccelerationStructureGeometryDescriptor class], "MTL4AccelerationStructureGeometryDescriptor", YES);
        report([MTL4AccelerationStructureTriangleGeometryDescriptor class], "MTL4AccelerationStructureTriangleGeometryDescriptor", YES);
        report([MTL4AccelerationStructureBoundingBoxGeometryDescriptor class], "MTL4AccelerationStructureBoundingBoxGeometryDescriptor", YES);
        report([MTL4AccelerationStructureCurveGeometryDescriptor class], "MTL4AccelerationStructureCurveGeometryDescriptor", YES);
        report([MTL4AccelerationStructureMotionTriangleGeometryDescriptor class], "MTL4AccelerationStructureMotionTriangleGeometryDescriptor", YES);
        report([MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor class], "MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor", YES);
        report([MTL4AccelerationStructureMotionCurveGeometryDescriptor class], "MTL4AccelerationStructureMotionCurveGeometryDescriptor", YES);
        /* AND THE THREE NAMED MEMBERS the port-side case changes one of, asked here on Apple's side so
         * the diff of the two runs covers them too. */
        {
            MTL4PipelineDescriptor *one = [[MTL4PipelineDescriptor alloc] init];
            MTL4PipelineDescriptor *two = [[MTL4PipelineDescriptor alloc] init];
            two.label = @"x";
            printf("MTL4PipelineDescriptor label-differs %s\n", [one isEqual:two] ? "no" : "yes");
            one.label = @"x";
            printf("MTL4PipelineDescriptor label-same %s\n", [one isEqual:two] ? "yes" : "no");
        }
        {
            MTL4PipelineOptions *one = [[MTL4PipelineOptions alloc] init];
            MTL4PipelineOptions *two = [[MTL4PipelineOptions alloc] init];
            two.shaderReflection = MTL4ShaderReflectionBindingInfo;
            printf("MTL4PipelineOptions reflection-differs %s\n", [one isEqual:two] ? "no" : "yes");
            two.shaderValidation = MTLShaderValidationDisabled;
            printf("MTL4PipelineOptions validation-differs %s\n", [one isEqual:two] ? "no" : "yes");
        }
        {
            MTL4RenderPipelineColorAttachmentDescriptor *one = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            MTL4RenderPipelineColorAttachmentDescriptor *two = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            two.writeMask = MTLColorWriteMaskRed;
            printf("MTL4RenderPipelineColorAttachmentDescriptor writemask-differs %s\n", [one isEqual:two] ? "no" : "yes");
        }
        {
            MTL4ComputePipelineDescriptor *one = [[MTL4ComputePipelineDescriptor alloc] init];
            MTL4ComputePipelineDescriptor *two = [[MTL4ComputePipelineDescriptor alloc] init];
            two.requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 3);
            printf("MTL4ComputePipelineDescriptor threadsize-differs %s\n", [one isEqual:two] ? "no" : "yes");
        }
        /* The tile ATTACHMENT is measured on Apple's side and NOT printed here, because the port's
         * object cannot carry it under a renamed name - the 16.4 SDK already declares that class, so the
         * rename cannot reach it. Its three answers are in facts/Metal/Descriptors26.md. */
        report([MTLTileRenderPipelineColorAttachmentDescriptorArray class], "MTLTileRenderPipelineColorAttachmentDescriptorArray", NO);
    }
    return 0;
}