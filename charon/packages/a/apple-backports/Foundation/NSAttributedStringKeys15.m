#import <Foundation/Foundation.h>

/* The attribute names of iOS 15, with the progress file operation kind that shares the group.

   One object for this release group and no other: the file stays in a band while any of
   its keys is in range, so a second group's key would be defined in the band where the
   release itself exports it. Every value is the one a real release shipped, read out of
   its dyld shared cache; facts/Foundation/NSURLResourceKeyStrings.md carries the reading
   and the ladder.

   The four the attributed-string group added are read the same way, and the name is not
   the value: three of the four ARE their own name and the fourth is not -
   NSLanguageIdentifierAttributeName is "NSLanguage", which the system's own Foundation is
   the only place to read it from. All four measured by
   tests/backports/host/attributed15/run.sh, which reads the value out of the host's image
   with dlsym and compares it with the one here, and by
   tests/backports/host/morphology/run.sh for the inflection keys beside them. */

NSString * const NSAlternateDescriptionAttributeName = @"NSAlternateDescription";
NSString * const NSImageURLAttributeName = @"NSImageURL";
NSString * const NSInlinePresentationIntentAttributeName = @"NSInlinePresentationIntent";
NSString * const NSLanguageIdentifierAttributeName = @"NSLanguage";
NSString * const NSPresentationIntentAttributeName = @"NSPresentationIntent";
NSString * const NSProgressFileOperationKindDuplicating = @"NSProgressFileOperationKindDuplicating";
NSString * const NSReplacementIndexAttributeName = @"NSReplacementIndex";
