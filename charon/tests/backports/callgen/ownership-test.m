//
//  ownership-test.m
//  The copy's ownership check, against properties declared the way the SDK's headers declare
//  them. This is the negative control the re-review asked for: `charon_intents_ivar_is_copy`
//  answered copy for everything, twice, because the guard that decides which property an ivar
//  belongs to never matched - a property's `V_` field carries the ivar name without its leading
//  underscore and `ivar_getName()` carries it with - so a broken guard has to fail a test and
//  not wait for a reader to notice.
//
//  It builds properties declared the way the SDK's headers declare the ones under test and asks
//  the package's own decision what it makes of each: a strong property is shared, a copy one is
//  not, an assign one is shared, and an ivar no property declares is copied. Those four answers
//  are the guard; the guard missed twice, and each time every object ivar was copied.
//
//  The behavioural half - copying an object and checking what the two share - is **not** here
//  yet: it does not share a copied property and then raises, and a test that aborts is not a test.
//  It is the next thing to get right, and the decision half stands on its own in the meantime.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// The package's own two functions, reached as the package's symbols.
extern int charon_copy_is_copy_for_testing(Class owner, const char *ivar);

@interface OwnershipProbe : NSObject
@property (nonatomic, strong) NSMutableString *retained;    // T@"NSMutableString",&,N,V_retained
@property (nonatomic, copy) NSMutableString *copied;       // T@"NSMutableString",C,N,V_copied
@property (nonatomic, assign) NSMutableString *assigned;   // T@"NSMutableString",N,V_assigned
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
        // The ownership the function decides, read straight out of the class's own metadata, so
        // the test is on the same attributes the runtime will show the function.
        charon_check("strong answers copy", charon_copy_is_copy_for_testing([OwnershipProbe class], "_retained"), 0);
        charon_check("copy answers copy", charon_copy_is_copy_for_testing([OwnershipProbe class], "_copied"), 1);
        charon_check("assign answers copy", charon_copy_is_copy_for_testing([OwnershipProbe class], "_assigned"), 0);
        charon_check("an ivar with no property", charon_copy_is_copy_for_testing([OwnershipProbe class], "_nonesuch"), 1);

        printf("\n%s: %u expectation(s) failed\n", charon_failures ? "FAILED" : "all met",
               charon_failures);
        return charon_failures ? 1 : 0;
    }
}
