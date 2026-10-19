#import <Foundation/Foundation.h>

/* The iCloud user defaults notifications of iOS 9.3.

   One object for this release group and no other: the file stays in a band while any of
   its keys is in range, so a second group's key would be defined in the band where the
   release itself exports it. Every value is the one a real release shipped, read out of
   its dyld shared cache; facts/Foundation/NSURLResourceKeyStrings.md carries the reading
   and the ladder. */

NSString * const NSUbiquitousUserDefaultsCompletedInitialSyncNotification = @"NSUbiquitousUserDefaultsCompletedInitialSyncNotification";
NSString * const NSUbiquitousUserDefaultsDidChangeAccountsNotification = @"NSUbiquitousUserDefaultsDidChangeAccountsNotification";
NSString * const NSUbiquitousUserDefaultsNoCloudAccountNotification = @"NSUbiquitousUserDefaultsNoCloudAccountNotification";
NSString * const NSUserDefaultsSizeLimitExceededNotification = @"com.apple.CFPreferences.byteCountLimitReached";
