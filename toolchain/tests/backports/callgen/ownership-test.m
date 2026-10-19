#import <Foundation/Foundation.h>
#import <objc/runtime.h>

extern int revenant_copy_is_copy_for_testing(Class owner, const char *ivar);

@interface OwnershipProbe : NSObject
@property (nonatomic, strong) NSMutableString *retained;
@property (nonatomic, copy) NSMutableString *copied;
@property (nonatomic, assign) NSMutableString *assigned;
@end

@implementation OwnershipProbe
@end

static unsigned revenant_failures = 0;

static void revenant_check(const char *what, int got, int want)
{
    if (got != want) {
        revenant_failures++;
    }
    printf("%-10s %-28s got %d, want %d\n", got == want ? "same" : "DIFFER", what, got, want);
}

int main(void)
{
    @autoreleasepool {
        revenant_check("strong answers copy", revenant_copy_is_copy_for_testing([OwnershipProbe class], "_retained"), 0);
        revenant_check("copy answers copy", revenant_copy_is_copy_for_testing([OwnershipProbe class], "_copied"), 1);
        revenant_check("assign answers copy", revenant_copy_is_copy_for_testing([OwnershipProbe class], "_assigned"), 0);
        revenant_check("an ivar with no property", revenant_copy_is_copy_for_testing([OwnershipProbe class], "_nonesuch"), 1);

        printf("\n%s: %u expectation(s) failed\n", revenant_failures ? "FAILED" : "all met",
               revenant_failures);
        return revenant_failures ? 1 : 0;
    }
}
