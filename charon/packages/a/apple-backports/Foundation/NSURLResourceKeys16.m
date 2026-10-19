#import <Foundation/Foundation.h>

/* The six keys no release below 18.0 exports: the file protection kind of 10.0, the three volume kinds and the two counts.

   One object for this release group and no other: the file stays in a band while any of
   its keys is in range, so a second group's key would be defined in the band where the
   release itself exports it. Every value is the one a real release shipped, read out of
   its dyld shared cache; facts/Foundation/NSURLResourceKeyStrings.md carries the reading
   and the ladder. */

NSString * const NSURLDirectoryEntryCountKey = @"NSURLDirectoryEntryCountKey";
NSString * const NSURLFileIdentifierKey = @"NSURLFileIdentifierKey";
NSString * const NSURLFileProtectionCompleteWhenUserInactive = @"NSURLFileProtectionCompleteWhenUserInactive";
NSString * const NSURLVolumeMountFromLocationKey = @"NSURLVolumeMountFromLocationKey";
NSString * const NSURLVolumeSubtypeKey = @"NSURLVolumeSubtypeKey";
NSString * const NSURLVolumeTypeNameKey = @"NSURLVolumeTypeNameKey";
