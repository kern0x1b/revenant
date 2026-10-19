/* array.m - MTLPipelineBufferDescriptorArray and its descriptor, compared against Apple's own objects.
 *
 * The port's two classes are built beside Apple's Metal in this process with their names renamed
 * CharonHost<Name> (run.sh does the renaming). Every probe asks the same question of Apple's class and of
 * the port's, and the answers are compared. Nothing here creates a device: a descriptor and an array need
 * none (facts/Metal/DeviceOnThisMachine.md).
 *
 * Apple's array has 31 slots, and index 31 is a failed assertion that stops the process, so that boundary is
 * asked out of process: `array.m` with the argument `overflow` makes Apple's array read index 31 and nothing
 * else, and run.sh checks that the process dies. The port must raise NSRangeException there instead, which
 * this file checks in-process with a control that the exception is catchable at all.
 */
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

/* One family, asked the same way on either side. The class is looked up by name so the port's renamed
 * class and Apple's are the same code. */
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

    id nothing = nil;   // a variable, so the nullable set is asked without a literal nil the compiler refuses
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
            /* The out-of-process half: Apple's array, asked for index 31, and nothing else. The
             * process is expected to die, so the parent reads its status. */
            MTLPipelineBufferDescriptorArray *apple = [[MTLPipelineBufferDescriptorArray alloc] init];
            (void)[apple objectAtIndexedSubscript:31];
            printf("Apple's array answered index 31 and did not stop\n");
            return 0;
        }

        printf("the controls first\n");
        /* A control that the caller can catch an NSRangeException at all, so a port that raises one is
         * measured, not assumed to be unreachable. */
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
