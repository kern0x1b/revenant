#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>

#if !__has_include(<FileProvider/NSFileProviderKnownFolders.h>)

typedef NS_OPTIONS(NSUInteger, NSFileProviderKnownFolders) {
    NSFileProviderDesktop = 1 << 0,
    NSFileProviderDocuments = 1 << 1
};

@interface NSFileProviderKnownFolderLocation : NSObject
@end

@interface NSFileProviderKnownFolderLocations : NSObject
@end

@interface NSFileProviderManager (CharonKnownFolders)
- (void)claimKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
          localizedReason:(NSString *)localizedReason
        completionHandler:(void (^)(NSError * _Nullable))completionHandler
                NS_SWIFT_NAME(claimKnownFolders(_:localizedReason:completionHandler:));

- (void)releaseKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
           localizedReason:(NSString *)localizedReason
             completionHandler:(void (^)(NSError * _Nullable))completionHandler
                     NS_SWIFT_NAME(releaseKnownFolders(_:localizedReason:completionHandler:));
@end


#endif

@interface NSFileProviderDomain (Charon16Storage)
- (void)charon_setUserEnabled:(BOOL)userEnabled replicated:(BOOL)replicated
                     hidden:(BOOL)hidden supportsSyncingTrash:(BOOL)supportsSyncingTrash;
- (BOOL)charon_userEnabled;
- (BOOL)charon_replicated;
- (BOOL)charon_hidden;
- (BOOL)charon_supportsSyncingTrash;
@end

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
