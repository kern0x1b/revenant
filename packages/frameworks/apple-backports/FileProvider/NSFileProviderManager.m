#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>
#import "RevenantFileProvider.h"

NSString *const NSFileProviderErrorDomain = @"NSFileProviderErrorDomain";

static NSInteger const RevenantFileProviderUnavailable = -2001;

@interface NSFileProviderManager (RevenantUnavailable)
- (instancetype)initRevenant;
+ (NSError *)revenant_unavailable;
@end

@implementation NSFileProviderManager {
    NSFileProviderDomain *_domain;
}

+ (NSFileProviderManager *)defaultManager
{
    return [[NSFileProviderManager alloc] initRevenant];
}

- (instancetype)initRevenant
{
    self = [super init];
    if (self) {
        _domain = nil;
    }
    return self;
}

- (instancetype)init
{
    return nil;
}

+ (NSFileProviderManager *)managerForDomain:(NSFileProviderDomain *)domain
{
    NSFileProviderManager *manager = [[NSFileProviderManager alloc] initRevenant];
    manager->_domain = domain;
    return manager;
}

+ (void)getDomainsWithCompletionHandler:(void (^)(NSArray<NSFileProviderDomain *> *domains, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(@[], [NSError errorWithDomain:NSFileProviderErrorDomain
                                                    code:RevenantFileProviderUnavailable
                                                userInfo:@{NSLocalizedDescriptionKey: @"The application cannot be used right now."}]);
    }
}

- (NSString *)providerIdentifier
{
    return @"";
}

- (NSURL *)documentStorageURL
{
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                  inDomains:NSUserDomainMask];
    return urls.firstObject ?: [NSURL fileURLWithPath:@"/tmp"];
}

#pragma mark - The placeholder, and the state directory

+ (NSURL *)placeholderURLForURL:(NSURL *)url
{
    return url;
}

- (void)stateDirectoryURLWithError:(void (^)(NSURL *_Nullable directoryURL, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        NSURL *support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                               inDomains:NSUserDomainMask].firstObject;
        NSURL *directory = [support URLByAppendingPathComponent:@"FileProvider" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:directory
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL];
        completionHandler(directory, nil);
    }
}

+ (BOOL)writePlaceholderAtURL:(NSURL *)placeholderURL
                 withMetadata:(NSFileProviderItem)metadata
                        error:(NSError **)error
{
    if (error) {
        *error = [NSFileProviderManager revenant_unavailable];
    }
    return NO;
}

#pragma mark - Adding, removing

+ (void)addDomain:(NSFileProviderDomain *)domain completionHandler:(void(^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([self revenant_unavailable]);
    }
}

+ (void)removeDomain:(NSFileProviderDomain *)domain completionHandler:(void(^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

+ (void)removeAllDomainsWithCompletionHandler:(void(^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([self revenant_unavailable]);
    }
}

+ (NSError *)revenant_unavailable
{
    return [NSError errorWithDomain:NSFileProviderErrorDomain
                               code:RevenantFileProviderUnavailable
                           userInfo:@{NSLocalizedDescriptionKey: @"The application cannot be used right now."}];
}

#pragma mark - The requests a domain makes, none of which a release with no host can serve

- (void)reconnectWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

- (void)disconnectWithReason:(NSFileProviderDisconnectReason)reason
                     options:(NSFileProviderDisconnectOptions)options
            completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

- (void)claimKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
          localizedReason:(NSString *)localizedReason
        completionHandler:(void (^)(NSError *_Nullable))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

- (void)releaseKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
           localizedReason:(NSString *)localizedReason
             completionHandler:(void (^)(NSError *_Nullable))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

- (void)registerURLSessionTask:(NSURLSessionTask *)task
         forItemWithIdentifier:(NSFileProviderItemIdentifier)identifier
             completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)containerItemIdentifier
                                completionHandler:(void (^)(NSError *_Nullable error))completion
{
    if (completion) {
        completion([NSFileProviderManager revenant_unavailable]);
    }
}

- (void)requestDownloadForItemWithIdentifier:(NSFileProviderItemIdentifier)identifier
                               requestedRange:(NSRange)requestedRange
                             completionHandler:(void (^)(NSURL *_Nullable locationURL, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager revenant_unavailable]);
    }
}

- (void)requestDiagnosticCollectionForItemWithIdentifier:(NSFileProviderItemIdentifier)identifier
                                             errorReason:(void (^)(NSError *_Nullable))errorReason
                                       completionHandler:(void (^)(NSURL *_Nullable diagnosticReportURL, NSError *_Nullable error))completionHandler
{
    if (errorReason) {
        errorReason(nil);
    }
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager revenant_unavailable]);
    }
}

#pragma mark - The 16.0 members, and what the 6.1.3 cache says about them

- (void)getUserVisibleURLForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
                         completionHandler:(void (^)(NSURL *_Nullable url, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager revenant_unavailable]);
    }
}

+ (void)getIdentifierForUserVisibleFileAtURL:(NSURL *)url
                           completionHandler:(void (^)(NSFileProviderItemIdentifier _Nullable itemIdentifier, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager revenant_unavailable]);
    }
}

- (NSURL *)temporaryDirectoryURLWithError:(NSError **)error
{
    if (error) {
        *error = [NSFileProviderManager revenant_unavailable];
    }
    return nil;
}

- (NSProgress *)globalProgressForKind:(NSProgressFileOperationKind)kind
{
    return nil;
}

- (void)signalErrorResolved:(NSError *)error
           completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager revenant_unavailable]);
    }
}

+ (void)removeDomain:(NSFileProviderDomain *)domain
                mode:(NSFileProviderDomainRemovalMode)mode
  completionHandler:(void (^)(NSURL *_Nullable preservedLocation, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager revenant_unavailable]);
    }
}

@end
