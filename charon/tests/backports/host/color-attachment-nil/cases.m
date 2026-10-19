// cases.m - the colour attachment array's nil store and its index check, Apple's MTLRenderPipelineDescriptor beside the
// port's (renamed CharonHostMTLRenderPipelineDescriptor by run.sh), in one process. Measured on the macOS host: a nil
// store resets the slot IN PLACE to the init defaults (the object stays), a stored attachment is a copy, and an index
// of 8 or more asserts on both the store and the read (a child process, status 134).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

@protocol CharonSlots
- (void)setObject:(id)attachment atIndexedSubscript:(NSUInteger)index;
- (id)objectAtIndexedSubscript:(NSUInteger)index;
@end

@protocol CharonDesc
- (id)colorAttachments;
@end

@protocol CharonLinked
- (id)vertexLinkedFunctions;
- (void)setVertexLinkedFunctions:(id)functions;
- (id)fragmentLinkedFunctions;
- (void)setFragmentLinkedFunctions:(id)functions;
@end

static int checks;
static int failures;

static void fail(NSString *text)
{
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static NSArray *Fields(void)
{
    return @[ @"pixelFormat", @"blendingEnabled", @"writeMask", @"sourceRGBBlendFactor", @"destinationRGBBlendFactor",
              @"rgbBlendOperation", @"sourceAlphaBlendFactor", @"destinationAlphaBlendFactor", @"alphaBlendOperation" ];
}

// The fields of one attachment, as KVC reads them, so that the two classes are compared by value.
static NSString *Snapshot(id attachment)
{
    NSMutableString *text = [NSMutableString string];
    for (NSString *key in Fields())
        [text appendFormat:@"%@=%@ ", key, [attachment valueForKey:key]];
    return text;
}

static id NewDescriptor(Class cls)
{
    return [[cls alloc] init];
}

// The ordinary sequence, once for a class: set a slot, nil it, and compare the object, the defaults and the copy.
static void nilSequence(Class cls, Class attachmentClass, NSString *name, NSString *defaults, NSString **outSnapshot)
{
    checks++;
    id desc = NewDescriptor(cls);
    id<CharonSlots> slots = (id<CharonSlots>)[(id<CharonDesc>)desc colorAttachments];
    id custom = [[attachmentClass alloc] init];
    [custom setValue:@(MTLPixelFormatBGRA8Unorm) forKey:@"pixelFormat"];
    [custom setValue:@YES forKey:@"blendingEnabled"];
    [custom setValue:@(MTLColorWriteMaskRed) forKey:@"writeMask"];
    [slots setObject:custom atIndexedSubscript:2];
    id before = [slots objectAtIndexedSubscript:2];
    if ([Snapshot(before) isEqualToString:Snapshot(custom)] == NO)
        fail([NSString stringWithFormat:@"%@: a stored attachment does not read back its fields", name]);
    if (before == custom)
        fail([NSString stringWithFormat:@"%@: a stored attachment is the object that was set, not a copy", name]);

    [slots setObject:nil atIndexedSubscript:2];
    id after = [slots objectAtIndexedSubscript:2];
    checks++;
    if (after != before)
        fail([NSString stringWithFormat:@"%@: a nil store changed the slot's object", name]);
    checks++;
    if (![Snapshot(after) isEqualToString:defaults])
        fail([NSString stringWithFormat:@"%@: after nil the slot reads [%@] and the defaults are [%@]", name,
              Snapshot(after), defaults]);
    checks++;
    if (![Snapshot([slots objectAtIndexedSubscript:0]) isEqualToString:defaults])
        fail([NSString stringWithFormat:@"%@: slot 0, never touched, does not hold the defaults", name]);
    id copy = [(id<NSCopying>)desc copyWithZone:nil];
    checks++;
    if (![Snapshot([(id<CharonSlots>)[(id<CharonDesc>)copy colorAttachments] objectAtIndexedSubscript:2]) isEqualToString:defaults])
        fail([NSString stringWithFormat:@"%@: the copy of a descriptor with a reset slot differs", name]);
    *outSnapshot = Snapshot(after);
}

// The linked-function properties: a fresh descriptor answers one stable empty object per stage; a store keeps a copy; a nil
// store gives a new empty object, neither the one before nor the one that was set (measured on the host).
static void linkedSequence(Class cls, Class linkedClass, NSString *name)
{
    checks++;
    id<CharonLinked> desc = (id<CharonLinked>)NewDescriptor(cls);
    id fresh = [desc vertexLinkedFunctions];
    checks++;
    if (!fresh || [desc vertexLinkedFunctions] != fresh)
        fail([NSString stringWithFormat:@"% a fresh vertex linked-functions object is nil or not stable", name]);
    checks++;
    if (![desc fragmentLinkedFunctions])
        fail([NSString stringWithFormat:@"% a fresh fragment linked-functions object is nil", name]);
    id set = [[linkedClass alloc] init];
    [desc setVertexLinkedFunctions:set];
    id stored = [desc vertexLinkedFunctions];
    checks++;
    if (stored == set || !stored)
        fail([NSString stringWithFormat:@"% a stored linked-functions object is the object set, not a copy", name]);
    [desc setVertexLinkedFunctions:nil];
    id reset = [desc vertexLinkedFunctions];
    checks++;
    if (!reset || reset == stored || reset == fresh)
        fail([NSString stringWithFormat:@"% a nil store did not give a new empty object", name]);
    checks++;
    if ([[(NSObject *)reset valueForKey:@"functions"] count] != 0)
        fail([NSString stringWithFormat:@"% the object after a nil store is not empty", name]);
    id copy = [(id<NSCopying>)desc copyWithZone:nil];
    checks++;
    if (![(id<CharonLinked>)copy vertexLinkedFunctions] || [(id<CharonLinked>)copy vertexLinkedFunctions] == reset)
        fail([NSString stringWithFormat:@"% the copy's linked-functions object is nil or the same object", name]);
}

// An index of 8 asserts: forked before any Metal object is made, with the store in the child.
static int childStatus(Class cls, BOOL store)
{
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        id desc = NewDescriptor(cls);
        id<CharonSlots> slots = (id<CharonSlots>)[(id<CharonDesc>)desc colorAttachments];
        if (store)
            [slots setObject:nil atIndexedSubscript:8];
        else
            (void)[slots objectAtIndexedSubscript:8];
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) ? 128 + WTERMSIG(status) : WEXITSTATUS(status);
}

int main(void)
{
    @autoreleasepool {
        Class apple = [MTLRenderPipelineDescriptor class];
        Class port = NSClassFromString(@"CharonHostMTLRenderPipelineDescriptor");
        Class apple_attachment = [MTLRenderPipelineColorAttachmentDescriptor class];
        Class port_attachment = NSClassFromString(@"CharonHostMTLRenderPipelineColorAttachmentDescriptor");
        Class apple_linked = [MTLLinkedFunctions class];
        Class port_linked = [MTLLinkedFunctions class];
        if (!port) {
            printf("FAIL the port's class is not in the process\n");
            return 1;
        }
        // The index checks run first, in children: the store, then the read, for Apple and the port.
        for (int store = 0; store <= 1; store++) {
            checks++;
            int a = childStatus(apple, store);
            int p = childStatus(port, store);
            if (a != 134)
                fail([NSString stringWithFormat:@"Apple's %s at index 8 returned %d and should abort (134)",
                      store ? "store" : "read", a]);
            if (p != 134)
                fail([NSString stringWithFormat:@"the port's %s at index 8 returned %d and should abort (134)",
                      store ? "store" : "read", p]);
        }
        // The defaults a fresh attachment has, read from Apple's own object, are what a reset must give.
        NSString *defaults = nil;
        id fresh = [[MTLRenderPipelineColorAttachmentDescriptor alloc] init];
        defaults = Snapshot(fresh);
        NSString *appleAfter = nil, *portAfter = nil;
        nilSequence(apple, apple_attachment, @"Apple", defaults, &appleAfter);
        nilSequence(port, port_attachment, @"the port", defaults, &portAfter);
        checks++;
        if (![appleAfter isEqualToString:portAfter])
            fail([NSString stringWithFormat:@"after nil Apple reads [%@] and the port [%@]", appleAfter, portAfter]);
        linkedSequence(apple, apple_linked, @"Apple");
        linkedSequence(port, port_linked, @"the port");
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
