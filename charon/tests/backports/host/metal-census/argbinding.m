#import <Foundation/Foundation.h>
#import "CharonMetal.h"

static int failures;

@interface CharonMetalBinding : NSObject <MTLBinding>
@end

@interface CharonMetalBufferBinding : CharonMetalBinding <MTLBufferBinding>
@end

@interface CharonMetalTextureBinding : CharonMetalBinding <MTLTextureBinding>
@end

@interface CharonMetalThreadgroupBinding : CharonMetalBinding <MTLThreadgroupBinding>
@end

@interface CharonMetalObjectPayloadBinding : CharonMetalBinding <MTLObjectPayloadBinding>
@end

extern CharonMetalBinding *CharonMakeBinding(Class kind, NSString *name, NSUInteger index,
                                             MTLArgumentAccess access, BOOL argument, BOOL used);

static void check(BOOL ok, NSString *what)
{
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

int main(void)
{
    @autoreleasepool {
        CharonMetalBufferBinding *buffer = (CharonMetalBufferBinding *)
            CharonMakeBinding(CharonMetalBufferBinding.class, @"charonBuffer", 3,
                              MTLArgumentAccessReadWrite, YES, YES);
        CharonMetalTextureBinding *texture = (CharonMetalTextureBinding *)
            CharonMakeBinding(CharonMetalTextureBinding.class, @"charonTexture", 4,
                              MTLArgumentAccessReadOnly, NO, YES);
        CharonMetalThreadgroupBinding *group = (CharonMetalThreadgroupBinding *)
            CharonMakeBinding(CharonMetalThreadgroupBinding.class, @"charonGroup", 5,
                              MTLArgumentAccessReadWrite, NO, YES);
        CharonMetalObjectPayloadBinding *payload = (CharonMetalObjectPayloadBinding *)
            CharonMakeBinding(CharonMetalObjectPayloadBinding.class, @"charonPayload", 6,
                              MTLArgumentAccessReadOnly, NO, YES);

        CharonMetalBinding *base = (CharonMetalBinding *)
            CharonMakeBinding(CharonMetalBinding.class, @"charonBase", 2,
                              MTLArgumentAccessReadWrite, YES, NO);

        check(base.type == MTLBindingTypeBuffer,
              @"MTLBinding: the base answers the kind it was built as");
        check([base.name isEqualToString:@"charonBase"] && base.index == 2 &&
              base.access == MTLArgumentAccessReadWrite && base.isUsed == NO && base.isArgument == YES,
              @"MTLBinding: it reads back its name, index, access and both flags");

        check(buffer.type == MTLBindingTypeBuffer, @"MTLBufferBinding: its type is MTLBindingTypeBuffer");
        check([buffer.name isEqualToString:@"charonBuffer"] && buffer.index == 3 &&
              buffer.access == MTLArgumentAccessReadWrite && buffer.isUsed == YES &&
              buffer.isArgument == YES,
              @"MTLBufferBinding: it reads back its name, index, access and both flags");

        check(texture.type == MTLBindingTypeTexture, @"MTLTextureBinding: its type is MTLBindingTypeTexture");
        check([texture.name isEqualToString:@"charonTexture"] && texture.index == 4 &&
              texture.access == MTLArgumentAccessReadOnly && texture.isUsed == YES &&
              texture.isArgument == NO,
              @"MTLTextureBinding: it reads back its name, index, access and both flags");

        check(group.type == MTLBindingTypeThreadgroupMemory,
              @"MTLThreadgroupBinding: its type is MTLBindingTypeThreadgroupMemory");
        check([group.name isEqualToString:@"charonGroup"] && group.index == 5 &&
              group.isUsed == YES && group.isArgument == NO,
              @"MTLThreadgroupBinding: it reads back its name, index and both flags");

        check(payload.type == MTLBindingTypeObjectPayload,
              @"MTLObjectPayloadBinding: its type is MTLBindingTypeObjectPayload (34)");
        check(payload.index == 6 && payload.access == MTLArgumentAccessReadOnly,
              @"MTLObjectPayloadBinding: it reads back its index and access");
        check([payload.name isEqualToString:@"charonPayload"] && payload.isUsed == YES &&
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
