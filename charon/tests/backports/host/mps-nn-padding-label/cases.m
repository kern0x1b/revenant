// cases.m - the label and the nil answer of +[MPSNNDefaultPadding paddingWithMethod:], the port's beside Apple's, in
// one process. Every combination of the align, remainder and size fields is asked of both, plus the custom bit.
// The port's class is CharonHostMPSNNDefaultPadding (run.sh renames it). Apple's answers are the reference: the
// label string, whether the object is nil, and the method read back.
#import <Foundation/Foundation.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static int checks;
static int failures;

static void fail(NSString *text)
{
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static void compare(NSUInteger method, Class port, Class apple)
{
    checks++;
    id a = [apple paddingWithMethod:(MPSNNPaddingMethod)method];
    id p = [port paddingWithMethod:(MPSNNPaddingMethod)method];
    if ((a == nil) != (p == nil)) {
        fail([NSString stringWithFormat:@"method 0x%lx: Apple's object is %@ and the port's is %@",
              (unsigned long)method, a ? @"present" : @"nil", p ? @"present" : @"nil"]);
        return;
    }
    if (!a)
        return;
    NSString *al = [a label], *pl = [p label];
    if (![al isEqualToString:pl])
        fail([NSString stringWithFormat:@"method 0x%lx: Apple's label [%@] and the port's [%@]",
              (unsigned long)method, al, pl]);
    if ([a paddingMethod] != [p paddingMethod])
        fail([NSString stringWithFormat:@"method 0x%lx: Apple reads back 0x%lx and the port 0x%lx",
              (unsigned long)method, (unsigned long)[a paddingMethod], (unsigned long)[p paddingMethod]]);
}

int main(void)
{
    @autoreleasepool {
        Class port = NSClassFromString(@"CharonHostMPSNNDefaultPadding");
        Class apple = [MPSNNDefaultPadding class];
        if (!port) {
            printf("FAIL the port's class is not in the process\n");
            return 1;
        }
        // The 64 combinations of the three fields: align 0..3, remainder 0..3, size 0..3.
        for (NSUInteger align = 0; align < 4; align++)
            for (NSUInteger remainder = 0; remainder < 4; remainder++)
                for (NSUInteger size = 0; size < 4; size++)
                    compare(align | (remainder << 2) | (size << 4), port, apple);
        // The custom bit with the fields that the factories use.
        compare((1UL << 15) | 0x0c, port, apple);
        compare((1UL << 15) | 0x10, port, apple);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
