/* The argument bindings, compared per property against a HOST MTLDevice where the host can make one.
 *
 * Metal.framework is on the host, so a host MTLDevice can be asked for a real argument encoder and
 * real bindings. Where it answers one, the port's value is compared to it PROPERTY BY PROPERTY -
 * a round trip of the port's own object against itself would prove only that the port agrees with
 * itself, which is the round trip that let three reviews through.
 *
 * Where the host CANNOT make one - the port's device has no argument buffers, so neither does the
 * host's - the case measures only what the HEADER fixes: the type, the access and the index
 * constants, which are facts read from MTLArgument.h and not chosen.
 */
#import <Foundation/Foundation.h>
#import "CharonMetal.h"

static int failures;

// Declared here rather than by including the object, which is LINKED: including it as well gave 45
// duplicate _OBJC_IVAR_ symbols at link time.
// The base FIRST, then the four that derive from it: the subclass interfaces reference the base by
// name and cannot before it is declared.
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

        // The base is a row of its own, and it is asked directly: the four subclasses all OVERRIDE
        // -type, so a break in the base's own -type reaches nothing else, and nothing else reaches it.
        // Without an instance of the base there is nothing that could catch a mutant there at all.
        CharonMetalBinding *base = (CharonMetalBinding *)
            CharonMakeBinding(CharonMetalBinding.class, @"charonBase", 2,
                              MTLArgumentAccessReadWrite, YES, NO);

        // WHAT THE HEADER FIXES, compared against a host binding of the same kind and index.
        // ONE assertion per class. A mutant that breaks only one class must be caught by that class's
        // own line and by no other, or the case cannot say WHICH row the break belongs to.
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

        // The header gives an object payload a kind of ITS OWN - MTLBindingTypeObjectPayload is 34
        // (MTLArgument.h:179 in 16.4, :76 in 26.2) - and an earlier revision of this case claimed
        // the header had no such case and that a payload rides in the buffer. That was wrong, and it
        // was wrong in the object too; both are fixed, and the mutant below is the one that keeps it
        // fixed: an object answering the buffer kind is now red.
        check(payload.type == MTLBindingTypeObjectPayload,
              @"MTLObjectPayloadBinding: its type is MTLBindingTypeObjectPayload (34)");
        check(payload.index == 6 && payload.access == MTLArgumentAccessReadOnly,
              @"MTLObjectPayloadBinding: it reads back its index and access");
        check([payload.name isEqualToString:@"charonPayload"] && payload.isUsed == YES &&
              payload.isArgument == NO,
              @"MTLObjectPayloadBinding: it reads back its name and both flags");

        // WHAT IS NOT MEASURED, said here so it is not guessed at: the memory numbers -
        // bufferAlignment, bufferDataSize, bufferDataType, bufferStructType, bufferPointerType,
        // textureType, textureDataType, isDepthTexture, arrayLength, threadgroupMemoryAlignment,
        // threadgroupMemoryDataSize, objectPayloadAlignment and objectPayloadDataSize - are NOT
        // asserted anywhere. The header declares them readonly and gives none of them a fixed
        // value, so there is no oracle to compare against, and a round trip of the port's own
        // object against itself would prove only that the port agrees with the port. They are
        // carried, not measured, and the facts file and the registry's effects say so by name.

        // PER-PROPERTY AGAINST A HOST BINDING IS NOT POSSIBLE, and the case says so instead of
        // pretending. A host MTLDevice here has no `newArgumentEncoderWithBufferIndex:` - the whole
        // family is behind an argument buffer, which is the facility the port does not have either -
        // so there is no host binding to compare a port binding to, and a comparison of the port's
        // object against ITSELF would prove only that the port agrees with the port. What the header
        // fixes is measured above: the four types, the two access values and the index, all read from
        // MTLArgument.h and none of them chosen here.
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
