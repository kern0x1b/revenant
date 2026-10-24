#import "../app/revenant_check.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

Class revenant_stand_in_class(void);

REVENANT_CASE(alias_system_class)
{
    Class system = revenant_stand_in_class();
    NSUInteger count = revenant_registered_count("NSPersonNameComponents");
    BOOL resolved = system != Nil && [NSPersonNameComponents class] == system;
    revenant_expect_true(@"with NSPersonNameComponents present before the loader runs, [NSPersonNameComponents class] is the system's class",
                         resolved != (BOOL)negative,
                         [NSString stringWithFormat:@"stand-in %@, resolved %@", system ? @"registered" : @"missing", resolved ? @"yes" : @"no"]);
    revenant_expect_true(@"with the system's NSPersonNameComponents present, Backports registers no second class of that name",
                         (count == 1) != (BOOL)negative,
                         [NSString stringWithFormat:@"classes named NSPersonNameComponents: %lu", (unsigned long)count]);
}
