#import <Foundation/Foundation.h>

/* The volume and shared-item keys of iOS 10, the canonical path key and the one stream service type.

   One object for this release group and no other: the file stays in a band while any of
   its keys is in range, so a second group's key would be defined in the band where the
   release itself exports it. Every value is the one a real release shipped, read out of
   its dyld shared cache; facts/Foundation/NSURLResourceKeyStrings.md carries the reading
   and the ladder. */

NSString * const NSStreamNetworkServiceTypeCallSignaling = @"kCFStreamNetworkServiceTypeCallSignaling";
NSString * const NSURLCanonicalPathKey = @"NSURLCanonicalPathKey";
NSString * const NSURLUbiquitousSharedItemCurrentUserPermissionsKey = @"NSURLUbiquitousSharedItemCurrentUserPermissionsKey";
NSString * const NSURLUbiquitousSharedItemCurrentUserRoleKey = @"NSURLUbiquitousSharedItemCurrentUserRoleKey";
NSString * const NSURLUbiquitousSharedItemMostRecentEditorNameComponentsKey = @"NSURLUbiquitousSharedItemMostRecentEditorNameComponentsKey";
NSString * const NSURLUbiquitousSharedItemPermissionsReadOnly = @"NSURLUbiquitousSharedItemPermissionsReadOnly";
NSString * const NSURLUbiquitousSharedItemPermissionsReadWrite = @"NSURLUbiquitousSharedItemPermissionsReadWrite";
NSString * const NSURLVolumeIsEncryptedKey = @"NSURLVolumeIsEncryptedKey";
NSString * const NSURLVolumeIsRootFileSystemKey = @"NSURLVolumeIsRootFileSystemKey";
NSString * const NSURLVolumeSupportsCompressionKey = @"NSURLVolumeSupportsCompressionKey";
NSString * const NSURLVolumeSupportsExclusiveRenamingKey = @"NSURLVolumeSupportsExclusiveRenamingKey";
NSString * const NSURLVolumeSupportsFileCloningKey = @"NSURLVolumeSupportsFileCloningKey";
NSString * const NSURLVolumeSupportsSwapRenamingKey = @"NSURLVolumeSupportsSwapRenamingKey";
