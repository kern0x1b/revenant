// The two nil-safe comparisons the value classes of this family use, so that a field that was never
// set and a field that was set to nil are the same thing - which is what the host's own -isEqual: on a
// notification information answers, and what makes an archived object equal to the one it came from.
//
// Not API: nothing here is in the registry, and no release exports it.

#ifndef CHARON_CK_VALUE_H
#define CHARON_CK_VALUE_H

#import <Foundation/Foundation.h>

static inline BOOL CharonCKSameObject(id left, id right)
{
    return left == right || [left isEqual:right];
}

static inline BOOL CharonCKSameObjects(NSArray *left, NSArray *right)
{
    return left == right || [left isEqual:right];
}

// The identifier a subscription the service must be able to name is given when the caller supplies
// none. It is an inline and not a function in a file of its own so that no object of this package
// exports it: a C function in a file that also defines a class is left out of the bands whose release
// already carries the class, and the call from the other file is then undefined.
static inline NSString *CharonCKNewSubscriptionID(void)
{
    return [[NSUUID UUID] UUIDString];
}

#endif
