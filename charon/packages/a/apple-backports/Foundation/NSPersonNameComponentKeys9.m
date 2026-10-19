#import "NSPersonNameComponentKeys.h"

/* The eight names the person name formatter writes, defined here rather than beside the formatter
   for the same reason they are in an object of their own at all: a host differential links this
   object and the system's Foundation into one binary, and two definitions of the same exported
   symbol in one process is what makes the *system's* copy of a name dangle. The differential links
   only the formatter's object, so both sides read the system's names there, and the port carries
   its own in this one for the device. */

NSString * const NSPersonNameComponentKey = @"NSPersonNameComponentKey";
NSString * const NSPersonNameComponentGivenName = @"givenName";
NSString * const NSPersonNameComponentFamilyName = @"familyName";
NSString * const NSPersonNameComponentMiddleName = @"middleName";
NSString * const NSPersonNameComponentPrefix = @"namePrefix";
NSString * const NSPersonNameComponentSuffix = @"nameSuffix";
NSString * const NSPersonNameComponentNickname = @"nickname";
NSString * const NSPersonNameComponentDelimiter = @"delimiter";
