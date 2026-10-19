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
        Class port = NSClassFromString(@"RevenantHostMPSNNDefaultPadding");
        Class apple = [MPSNNDefaultPadding class];
        if (!port) {
            printf("FAIL the port's class is not in the process\n");
            return 1;
        }
        for (NSUInteger align = 0; align < 4; align++)
            for (NSUInteger remainder = 0; remainder < 4; remainder++)
                for (NSUInteger size = 0; size < 4; size++)
                    compare(align | (remainder << 2) | (size << 4), port, apple);
        compare((1UL << 15) | 0x0c, port, apple);
        compare((1UL << 15) | 0x10, port, apple);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
