/* What the port answers when a caller asks for the argument ENCODER by name.
 *
 * This is a SEPARATE case, and separate on purpose. The binding case links Apple's Metal and asks a
 * host device for a real encoder; the answer there is about the HOST, and it says nothing about what
 * a caller of the PORT sees. A caller of the port asks the runtime for a name and gets an object or
 * nil back, and what matters is which.
 *
 * WHAT WAS MEASURED, and it is not what the case wanted to hear:
 *   NSProtocolFromString(@"MTLArgumentEncoder") returns a protocol on this host even in a binary
 *   that links no Metal at all - Foundation plus the ObjC runtime already have Apple's Metal
 *   protocol names and Apple's classes conforming to them registered (measured: MTLArgumentEncoder
 *   FOUND with 2 conforming classes, MTLBinding FOUND with 6, and the process registers 1277
 *   protocols, with Foundation as the only dylib linked). So the PROTOCOL query measures the host,
 *   not the port, and a non-nil answer there says nothing about what the port vends.
 *   NSClassFromString(@"MTLArgumentEncoder") returns nil, here and on a device with no such class,
 *   because the name is a PROTOCOL in Apple's header and never a class.
 *
 * So the port's own answer is measured from the port's own registration: this binary links the
 * binding object and nothing else from Metal, and the set of port classes the runtime then holds is
 * exactly the five bindings - no encoder class among them, and so no object and no members to call.
 * The control is what makes that a measurement: the same query finds all five, so a nil for the
 * encoder is the port not vending it, not a runtime that cannot be asked.
 */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static int failures;

static void check(BOOL ok, NSString *what)
{
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

int main(void)
{
    @autoreleasepool {
        NSArray *vended = @[ @"CharonMetalBinding", @"CharonMetalBufferBinding",
                              @"CharonMetalTextureBinding", @"CharonMetalThreadgroupBinding",
                              @"CharonMetalObjectPayloadBinding" ];
        for (NSString *name in vended) {
            check(NSClassFromString(name) != nil,
                  ([NSString stringWithFormat:@"the port vends %@, and the runtime finds it", name]));
        }

        // The class query: nil. There is no object, so there is nothing to send a member to.
        check(NSClassFromString(@"MTLArgumentEncoder") == nil,
              @"the port vends no MTLArgumentEncoder class, so a caller has no members to call");

        // The port's whole contribution to the runtime, counted rather than asserted by hand: this
        // binary links the binding object alone, so every port class the runtime holds came from it.
        NSMutableArray *portClasses = [NSMutableArray array];
        int total = objc_getClassList(NULL, 0);
        Class *all = (Class *)malloc(sizeof(Class) * total);
        total = objc_getClassList(all, total);
        for (int i = 0; i < total; i++) {
            NSString *name = NSStringFromClass(all[i]);
            if ([name hasPrefix:@"CharonMetal"]) { [portClasses addObject:name]; }
        }
        free(all);
        NSArray *sorted = [portClasses sortedArrayUsingSelector:@selector(compare:)];
        NSArray *want = [vended sortedArrayUsingSelector:@selector(compare:)];
        check(sorted.count == 5 && [sorted isEqualToArray:want],
              ([NSString stringWithFormat:@"the port's whole class set here is its 5 bindings, and holds"
                                           @" no encoder: %@", [sorted componentsJoinedByString:@", "]]));

        // The FACTORY is not measured here, and this says why rather than implying it was: the two
        // `-newArgumentEncoderWithBufferIndex:` methods live on CharonMetalFunction, which is
        // implemented in the same object as the library, which references CharonMetalDevice - and
        // that object needs EAGL context headers this host case does not carry. What the source
        // says is recorded in the facts file with its line, and it is a source fact, not a
        // measurement: both methods return nil, so a call RETURNS nil instead of raising.
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
