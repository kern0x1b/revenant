#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static void probe(NSString *side, Class arrayClass, Class bufferClass)
{
    printf("%s\n", [side UTF8String]);
    id array = [[arrayClass alloc] init];
    id slot0 = [array objectAtIndexedSubscript:0];
    check(slot0 != nil && [slot0 isKindOfClass:bufferClass],
          ([NSString stringWithFormat:@"%@: every slot answers a buffer descriptor, slot 0 included", side]));
    check([array objectAtIndexedSubscript:0] == [array objectAtIndexedSubscript:0],
          ([NSString stringWithFormat:@"%@: an unset slot answers the same object on every read", side]));
    check([slot0 mutability] == MTLMutabilityDefault,
          ([NSString stringWithFormat:@"%@: a fresh slot is MTLMutabilityDefault", side]));
    check([array objectAtIndexedSubscript:30] != nil,
          ([NSString stringWithFormat:@"%@: slot 30, the last of the 31, answers a descriptor", side]));

    id mine = [[bufferClass alloc] init];
    [mine setMutability:MTLMutabilityMutable];
    [array setObject:mine atIndexedSubscript:3];
    id back = [array objectAtIndexedSubscript:3];
    check(back != nil && back != mine,
          ([NSString stringWithFormat:@"%@: a set stores a copy, so the read back is not the caller's object", side]));
    check([back mutability] == MTLMutabilityMutable,
          ([NSString stringWithFormat:@"%@: the copy keeps the mutability it was set with", side]));

    id nothing = nil;
    [array setObject:nothing atIndexedSubscript:3];
    id reset = [array objectAtIndexedSubscript:3];
    check(reset != nil && [reset mutability] == MTLMutabilityDefault,
          ([NSString stringWithFormat:@"%@: a nil set resets the slot to a fresh default", side]));
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "overflow") == 0) {
            MTLPipelineBufferDescriptorArray *apple = [[MTLPipelineBufferDescriptorArray alloc] init];
            (void)[apple objectAtIndexedSubscript:31];
            printf("Apple's array answered index 31 and did not stop\n");
            return 0;
        }

        printf("the controls first\n");
        @try {
            [NSException raise:NSRangeException format:@"control"];
            check(0, @"control: an NSRangeException is catchable in this process");
        } @catch (NSException *e) {
            check([e.name isEqualToString:NSRangeException], @"control: an NSRangeException is catchable in this process");
        }

        probe(@"apple", [MTLPipelineBufferDescriptorArray class], [MTLPipelineBufferDescriptor class]);
        probe(@"port", NSClassFromString(@"CharonHostMTLPipelineBufferDescriptorArray"),
              NSClassFromString(@"CharonHostMTLPipelineBufferDescriptor"));

        printf("the port's index 31, which Apple's array aborts on\n");
        Class portArray = NSClassFromString(@"CharonHostMTLPipelineBufferDescriptorArray");
        id port = [[portArray alloc] init];
        BOOL raised = NO;
        @try {
            (void)[port objectAtIndexedSubscript:31];
        } @catch (NSException *e) {
            raised = [e.name isEqualToString:NSRangeException];
        }
        check(raised, @"port: index 31 raises NSRangeException, where Apple's array stops the process");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}
