#import "../app/revenant_check.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>

typedef Class (*revenant_stand_in_function)(void);

REVENANT_CASE(alias_system_class)
{
    revenant_stand_in_function stand_in = (revenant_stand_in_function)dlsym(RTLD_DEFAULT, "revenant_stand_in_class");
    Class system = stand_in ? stand_in() : Nil;
    NSUInteger count = revenant_registered_count("NSPersonNameComponents");
    BOOL resolved = system != Nil && [NSPersonNameComponents class] == system;
    revenant_expect_true(@"with NSPersonNameComponents present before the loader runs, [NSPersonNameComponents class] is the system's class",
                         resolved != (BOOL)negative,
                         [NSString stringWithFormat:@"stand-in %@, resolved %@", system ? @"registered" : @"missing", resolved ? @"yes" : @"no"]);
    revenant_expect_true(@"with the system's NSPersonNameComponents present, Backports registers no second class of that name",
                         (count == 1) != (BOOL)negative,
                         [NSString stringWithFormat:@"classes named NSPersonNameComponents: %lu", (unsigned long)count]);
}
