// What the SDK this port builds with does not carry, declared from the SDK the API comes from.
//
// The goal is SDK 26.2's FileProvider. The SDK the port's headers are rendered from is 16.4, and the
// known-folders API is not in it at all:
//
//   $ grep -rn "claimKnownFolders" <16.4 SDK>/…/FileProvider.framework/Headers/*.h
//   (no output)
//
// while SDK 26.2 declares it in NSFileProviderKnownFolders.h, with
// `FILEPROVIDER_API_AVAILABILITY_DESKTOP` - which is what makes the corpus list it at 11.0 and the
// 16.4 headers silent about it. So it is declared here, in the 26.2 spelling, and the .m
// implements it. The pattern is VideoToolbox's CharonVideoToolbox.h: a header of the port's own
// that carries what that SDK does not.
//
// FACTS ONLY, from the 26.2 headers and the corpus - not Apple's implementation and not a
// behaviour: the spellings, the types, and the availability macro, copied.

#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>

/**
 The known-folder declarations below: the folder kinds, and the claim and release methods.
 FILEPROVIDER_API_AVAILABILITY_DESKTOP
 */
// The macOS SDK the host differential builds against HAS these - NSFileProviderKnownFolders.h:21
// and :46 - and the iOS 16.4 SDK the port builds with does not have the file at all. So the
// declaration is made where it is missing and skipped where the SDK already has it: a second
// @interface for a class the SDK declares is a duplicate definition, which is what the host build
// answered before this guard.
// The disconnect enums are NOT in the same situation as the known folders, and the previous text
// here said they were. Both SDKs DECLARE the method -disconnectWithReason:options:completionHandler:
// - and NEITHER declares the two types it names: the macOS SDK has neither the types nor the
// method, and the iOS 16.4 SDK has the method and neither type. The types are therefore the port's
// own, and they are unguarded because there is nothing to guard against.
#if !__has_include(<FileProvider/NSFileProviderKnownFolders.h>)

typedef NS_OPTIONS(NSUInteger, NSFileProviderKnownFolders) {
    NSFileProviderDesktop = 1 << 0,
    NSFileProviderDocuments = 1 << 1
};

/**
 The locations of the known folders an extension claims, keyed by the folders themselves.
 26.2's NSFileProviderKnownFolders.h: `NSFileProviderKnownFolderLocations`, an object the
 claimKnownFolders: and releaseKnownFolders: methods take. A dictionary of
 NSFileProviderKnownFolders to NSFileProviderKnownFolderLocation, which is why the claim is
 "claim ~/Desktop and ~/Documents together".
 */
@interface NSFileProviderKnownFolderLocation : NSObject
@end

@interface NSFileProviderKnownFolderLocations : NSObject
@end

@interface NSFileProviderManager (CharonKnownFolders)
/**
 Claim the given known folders, with a reason shown to the user.
 26.2's NSFileProviderKnownFolders.h:106-110, verbatim in its spelling and its availability.
 */
- (void)claimKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
          localizedReason:(NSString *)localizedReason
        completionHandler:(void (^)(NSError * _Nullable))completionHandler
                NS_SWIFT_NAME(claimKnownFolders(_:localizedReason:completionHandler:));
/* 26.2 gates this with FILEPROVIDER_API_AVAILABILITY_DESKTOP, which the 16.4 SDK does not
   define - naming it here would make this a bare identifier and the header would not parse. The
   corpus lists the member at 11.0; the availability is therefore recorded, not applied. */

/**
 Release the given known folders back to whoever held them.
 */
- (void)releaseKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
           localizedReason:(NSString *)localizedReason
             completionHandler:(void (^)(NSError * _Nullable))completionHandler
                     NS_SWIFT_NAME(releaseKnownFolders(_:localizedReason:completionHandler:));
/* FILEPROVIDER_API_AVAILABILITY_DESKTOP in 26.2; recorded for the reason above. */
@end


#endif

// The storage the 16.0 object answers, reached the only way a category can on this target: the class owns
// it and hands it over. A class extension may not carry ivars on armv7 - the compiler says
//     instance variables may not be placed in class extension
// - and an @implementation ivar block is private to its own file, so neither place is reachable from a
// second object. One slot on the class, a method that returns it, and the category stores through that.
//
// IT IS NOT UNDER THE __has_include GUARD ABOVE, and the reason is measured rather than stylistic.
// It sat there, and the host build answered:
//     FileProvider16.m:37:36: error: no visible @interface for 'NSFileProviderDomain' declares the
//     selector 'charon_userEnabled'
// which is tests/backports/host/inventory/run.sh FileProvider failing on this framework's own band
// object. The guard is for the KNOWN FOLDERS, which the macOS SDK declares and the 16.4 SDK does
// not; every name in this category is the port's own and NEITHER SDK declares one of them
// (`grep -rl charon_userEnabled <macOS SDK>/.../FileProvider.framework/Headers
// <16.4 SDK>/.../FileProvider.framework/Headers` answers nothing), so there is nothing here to guard
// against - the same argument the disconnect enums below make, for the same reason. A named category
// is not a second @interface for the class either: it is its own symbol, and that is what the
// 16.4 build has always compiled.
@interface NSFileProviderDomain (Charon16Storage)
- (void)charon_setUserEnabled:(BOOL)userEnabled replicated:(BOOL)replicated
                     hidden:(BOOL)hidden supportsSyncingTrash:(BOOL)supportsSyncingTrash;
- (BOOL)charon_userEnabled;
- (BOOL)charon_replicated;
- (BOOL)charon_hidden;
- (BOOL)charon_supportsSyncingTrash;
@end

/**
 The reason a domain is disconnected, and the options it is disconnected with.

 UNGUARDED, and the reason is measured: neither SDK has them. The iOS 16.4 SDK the port builds
 with declares -disconnectWithReason:options:completionHandler: in NSFileProviderManager.h and names
 two types it does not define; and the macOS SDK the host differential builds against has neither
 the types nor the method -

   $ grep -rn "NSFileProviderDisconnectReason\|disconnectWithReason" <macOS SDK>/…/FileProvider.framework/Headers
   (no output)
   $ ls <macOS SDK>/…/FileProvider.framework/Headers | grep -i disconnect
   (no header named for it)

 so there is no file to test with __has_include and nothing to guard against: both builds need
 these, and the port's own -disconnectWithReason:options:completionHandler: is the only declaration
 of it either of them has. Spelled as 26.2 spells them - the port's header carries the spellings,
 the macro and the behaviour.
 */
typedef NS_ENUM(NSInteger, NSFileProviderDisconnectReason) {
    NSFileProviderDisconnectReasonUnknown = 0,
    NSFileProviderDisconnectReasonSignedOut = 1,
    NSFileProviderDisconnectReasonQuotaExceeded = 2,
    NSFileProviderDisconnectReasonServerUnreachable = 3
};

typedef NS_OPTIONS(NSUInteger, NSFileProviderDisconnectOptions) {
    NSFileProviderDisconnectOptionNone = 0,
    NSFileProviderDisconnectOptionDropPending = 1 << 0
};
