#import <Foundation/Foundation.h>

/* The credential storage key of iOS 7, which is the last band that has to carry it.

   One object for this release group and no other: the file stays in a band while any of
   its keys is in range, so a second group's key would be defined in the band where the
   release itself exports it. Every value is the one a real release shipped, read out of
   its dyld shared cache; facts/Foundation/NSURLResourceKeyStrings.md carries the reading
   and the ladder. */

NSString * const NSURLCredentialStorageRemoveSynchronizableCredentials = @"NSURLCredentialStorageRemoveSynchronizableCredentials";
