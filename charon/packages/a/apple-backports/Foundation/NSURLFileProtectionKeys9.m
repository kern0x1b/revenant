#import <Foundation/Foundation.h>

/* The file protection group of iOS 9, with the two keys iOS 9 added beside it.

   One object for this release group and no other: the file stays in a band while any of
   its keys is in range, so a second group's key would be defined in the band where the
   release itself exports it. Every value is the one a real release shipped, read out of
   its dyld shared cache; facts/Foundation/NSURLResourceKeyStrings.md carries the reading
   and the ladder. */

NSString * const NSURLFileProtectionComplete = @"NSURLFileProtectionComplete";
NSString * const NSURLFileProtectionCompleteUnlessOpen = @"NSURLFileProtectionCompleteUnlessOpen";
NSString * const NSURLFileProtectionCompleteUntilFirstUserAuthentication = @"NSURLFileProtectionCompleteUntilFirstUserAuthentication";
NSString * const NSURLFileProtectionKey = @"NSURLFileProtectionKey";
NSString * const NSURLFileProtectionNone = @"NSURLFileProtectionNone";
NSString * const NSURLIsApplicationKey = @"_NSURLIsApplicationKey";
NSString * const NSURLUbiquitousSharedItemOwnerNameComponentsKey = @"NSURLUbiquitousSharedItemOwnerNameComponentsKey";
