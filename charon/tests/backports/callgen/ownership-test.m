#import <Foundation/Foundation.h>
#import <objc/runtime.h>

extern int charon_copy_is_copy_for_testing(Class owner, const char *ivar);

@interface OwnershipProbe : NSObject
@property (nonatomic, strong) NSMutableString *retained;
@property (nonatomic, copy) NSMutableString *copied;
@property (nonatomic, assign) NSMutableString *assigned;
@end

@implementation OwnershipProbe
@end

static unsigned charon_failures = 0;

static void charon_check(const char *what, int got, int want)
{
    if (got != want) {
        charon_failures++;
    }
    printf("%-10s %-28s got %d, want %d\n", got == want ? "same" : "DIFFER", what, got, want);
}

int main(void)
{
    @autoreleasepool {
        charon_check("strong answers copy", charon_copy_is_copy_for_testing([OwnershipProbe class], "_retained"), 0);
        charon_check("copy answers copy", charon_copy_is_copy_for_testing([OwnershipProbe class], "_copied"), 1);
        charon_check("assign answers copy", charon_copy_is_copy_for_testing([OwnershipProbe class], "_assigned"), 0);
        charon_check("an ivar with no property", charon_copy_is_copy_for_testing([OwnershipProbe class], "_nonesuch"), 1);

        printf("\n%s: %u expectation(s) failed\n", charon_failures ? "FAILED" : "all met",
               charon_failures);
        return charon_failures ? 1 : 0;
    }
}
