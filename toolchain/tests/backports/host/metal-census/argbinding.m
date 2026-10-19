#import <Foundation/Foundation.h>
#import "RevenantMetal.h"

static int failures;

@interface RevenantMetalBinding : NSObject <MTLBinding>
@end

@interface RevenantMetalBufferBinding : RevenantMetalBinding <MTLBufferBinding>
@end

@interface RevenantMetalTextureBinding : RevenantMetalBinding <MTLTextureBinding>
@end

@interface RevenantMetalThreadgroupBinding : RevenantMetalBinding <MTLThreadgroupBinding>
@end

@interface RevenantMetalObjectPayloadBinding : RevenantMetalBinding <MTLObjectPayloadBinding>
@end

extern RevenantMetalBinding *RevenantMakeBinding(Class kind, NSString *name, NSUInteger index,
                                             MTLArgumentAccess access, BOOL argument, BOOL used);

static void check(BOOL ok, NSString *what)
{
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

int main(void)
{
    @autoreleasepool {
        RevenantMetalBufferBinding *buffer = (RevenantMetalBufferBinding *)
            RevenantMakeBinding(RevenantMetalBufferBinding.class, @"revenantBuffer", 3,
                              MTLArgumentAccessReadWrite, YES, YES);
        RevenantMetalTextureBinding *texture = (RevenantMetalTextureBinding *)
            RevenantMakeBinding(RevenantMetalTextureBinding.class, @"revenantTexture", 4,
                              MTLArgumentAccessReadOnly, NO, YES);
        RevenantMetalThreadgroupBinding *group = (RevenantMetalThreadgroupBinding *)
            RevenantMakeBinding(RevenantMetalThreadgroupBinding.class, @"revenantGroup", 5,
                              MTLArgumentAccessReadWrite, NO, YES);
        RevenantMetalObjectPayloadBinding *payload = (RevenantMetalObjectPayloadBinding *)
            RevenantMakeBinding(RevenantMetalObjectPayloadBinding.class, @"revenantPayload", 6,
                              MTLArgumentAccessReadOnly, NO, YES);

        RevenantMetalBinding *base = (RevenantMetalBinding *)
            RevenantMakeBinding(RevenantMetalBinding.class, @"revenantBase", 2,
                              MTLArgumentAccessReadWrite, YES, NO);

        check(base.type == MTLBindingTypeBuffer,
              @"MTLBinding: the base answers the kind it was built as");
        check([base.name isEqualToString:@"revenantBase"] && base.index == 2 &&
              base.access == MTLArgumentAccessReadWrite && base.isUsed == NO && base.isArgument == YES,
              @"MTLBinding: it reads back its name, index, access and both flags");

        check(buffer.type == MTLBindingTypeBuffer, @"MTLBufferBinding: its type is MTLBindingTypeBuffer");
        check([buffer.name isEqualToString:@"revenantBuffer"] && buffer.index == 3 &&
              buffer.access == MTLArgumentAccessReadWrite && buffer.isUsed == YES &&
              buffer.isArgument == YES,
              @"MTLBufferBinding: it reads back its name, index, access and both flags");

        check(texture.type == MTLBindingTypeTexture, @"MTLTextureBinding: its type is MTLBindingTypeTexture");
        check([texture.name isEqualToString:@"revenantTexture"] && texture.index == 4 &&
              texture.access == MTLArgumentAccessReadOnly && texture.isUsed == YES &&
              texture.isArgument == NO,
              @"MTLTextureBinding: it reads back its name, index, access and both flags");

        check(group.type == MTLBindingTypeThreadgroupMemory,
              @"MTLThreadgroupBinding: its type is MTLBindingTypeThreadgroupMemory");
        check([group.name isEqualToString:@"revenantGroup"] && group.index == 5 &&
              group.isUsed == YES && group.isArgument == NO,
              @"MTLThreadgroupBinding: it reads back its name, index and both flags");

        check(payload.type == MTLBindingTypeObjectPayload,
              @"MTLObjectPayloadBinding: its type is MTLBindingTypeObjectPayload (34)");
        check(payload.index == 6 && payload.access == MTLArgumentAccessReadOnly,
              @"MTLObjectPayloadBinding: it reads back its index and access");
        check([payload.name isEqualToString:@"revenantPayload"] && payload.isUsed == YES &&
              payload.isArgument == NO,
              @"MTLObjectPayloadBinding: it reads back its name and both flags");

        id<MTLDevice> host = MTLCreateSystemDefaultDevice();
        if (!host || ![host respondsToSelector:@selector(newArgumentEncoderWithBufferIndex:error:)]) {
            printf("  note the host makes no argument encoder, so no host binding exists to compare to;"
                   " the values above are the header's\n");
        }
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
