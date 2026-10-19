// NSFileProviderManager: the manager a file-provider extension and the system talk through.
//
// The framework arrived in iOS 11.0 and the release this backport is for has none of it: no
// FileProvider, and no extension host that would load one. So every member here answers as the
// host's own FileProvider answers on a machine with no domains, and the answers are MEASURED
// where the host could be measured and DOCUMENTED where it could not - the table in
// facts/FileProvider/Manager.md says which is which for each member, and this file does not claim
// more than that table gives.
//
// The three numbers that come from the host, and that the differential compares:
//   getDomainsWithCompletionHandler: -> an empty list AND an error, NSFileProviderErrorDomain -2001
//   managerForDomain:                -> a manager
//   the error codes                   -> the header's own, -1005 NoSuchItem and -1004
//                                        ServerUnreachable, in the domain NSFileProviderErrorDomain
//
// The members that would change the state of a machine - addDomain:, removeDomain:,
// removeAllDomains…, the known-folder claim, the URL-session task registration, the enumerator
// signalling - are FORBIDDEN on the host, so their answers come from the header and are the
// documented "there is no extension to do this" error.

#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>
#import "CharonFileProvider.h"

NSString *const NSFileProviderErrorDomain = @"NSFileProviderErrorDomain";

// The error the port answers with where the host answered -2001, "the application cannot be used
// right now": on a release with no extension host, every domain call is a request to a host that
// is not running. The code is Apple's, from the host's own answer, not a number invented here.
static NSInteger const CharonFileProviderUnavailable = -2001;

/// -init is NS_UNAVAILABLE in the header, so the port's is too: a manager is reached through
/// +defaultManager or +managerForDomain:, and there is no way to make one any other way.
@interface NSFileProviderManager (CharonUnavailable)
- (instancetype)initCharon;
/// The one error every member here answers with, on a release with no extension host. Apple's
/// code, from the host's own answer (-2001, "The application cannot be used right now"), not a
/// number invented here.
+ (NSError *)charon_unavailable;
@end

@implementation NSFileProviderManager {
    NSFileProviderDomain *_domain;
}

/// A manager with no domains, which is what the port's `defaultManager` is: there is no extension
/// host to ask, and a manager that exists and holds nothing is what a system with no extensions
/// has. Documented, not measured: `defaultManager` is `API_UNAVAILABLE(macos)`.
+ (NSFileProviderManager *)defaultManager
{
    return [[NSFileProviderManager alloc] initCharon];
}

- (instancetype)initCharon
{
    self = [super init];
    if (self) {
        _domain = nil;
    }
    return self;
}

- (instancetype)init
{
    // Unavailable in the header, and unavailable here: returning nil is what NS_UNAVAILABLE means
    // at run time, and it is what stops a caller from making a second manager for a release whose
    // manager is a singleton per domain.
    return nil;
}

+ (NSFileProviderManager *)managerForDomain:(NSFileProviderDomain *)domain
{
    // MEASURED on the host: managerForDomain: on a domain that is not registered answers A
    // MANAGER, not nil. So this returns one, and it is the domain's own.
    NSFileProviderManager *manager = [[NSFileProviderManager alloc] initCharon];
    manager->_domain = domain;
    return manager;
}

/// MEASURED on the host: an EMPTY LIST and an ERROR, `NSFileProviderErrorDomain` code -2001,
/// "The application cannot be used right now". The list is empty because there are no domains and
/// the error is there because nothing could have answered for them: the extension host is not
/// running on a release that has no FileProvider, and that is what the host's own -2001 says.
+ (void)getDomainsWithCompletionHandler:(void (^)(NSArray<NSFileProviderDomain *> *domains, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(@[], [NSError errorWithDomain:NSFileProviderErrorDomain
                                                    code:CharonFileProviderUnavailable
                                                userInfo:@{NSLocalizedDescriptionKey: @"The application cannot be used right now."}]);
    }
}

/// The identifier of the extension this manager belongs to. Documented: `FILEPROVIDER_API_V2` and
/// the macOS importer refuses it, and on a release with no extension there is no provider to
/// name. Empty is the documented answer for a manager that has no extension.
- (NSString *)providerIdentifier
{
    return @"";
}

/// The container's own storage, which a manager with no domains still has. Documented: the value
/// is a property of the app, not of a domain, and there is no domain to point into.
- (NSURL *)documentStorageURL
{
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                  inDomains:NSUserDomainMask];
    return urls.firstObject ?: [NSURL fileURLWithPath:@"/tmp"];
}

#pragma mark - The placeholder, and the state directory

/// A file with no domain is where it is. Documented: a placeholder is a mapping a DOMAIN owns, and
/// there is no domain, so the file is not mapped and answers as itself.
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

/// A placeholder for a file that a domain owns. With no domain there is nothing to map, so this
/// refuses and says so in the out-parameter: the header's own contract is that a false return
/// carries the error, and the caller reads it there.
+ (BOOL)writePlaceholderAtURL:(NSURL *)placeholderURL
                 withMetadata:(NSFileProviderItem)metadata
                        error:(NSError **)error
{
    if (error) {
        *error = [NSFileProviderManager charon_unavailable];
    }
    return NO;
}

#pragma mark - Adding, removing

+ (void)addDomain:(NSFileProviderDomain *)domain completionHandler:(void(^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([self charon_unavailable]);
    }
}

+ (void)removeDomain:(NSFileProviderDomain *)domain completionHandler:(void(^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

+ (void)removeAllDomainsWithCompletionHandler:(void(^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([self charon_unavailable]);
    }
}

+ (NSError *)charon_unavailable
{
    return [NSError errorWithDomain:NSFileProviderErrorDomain
                               code:CharonFileProviderUnavailable
                           userInfo:@{NSLocalizedDescriptionKey: @"The application cannot be used right now."}];
}

#pragma mark - The requests a domain makes, none of which a release with no host can serve

- (void)reconnectWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

- (void)disconnectWithReason:(NSFileProviderDisconnectReason)reason
                     options:(NSFileProviderDisconnectOptions)options
            completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

- (void)claimKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
          localizedReason:(NSString *)localizedReason
        completionHandler:(void (^)(NSError *_Nullable))completionHandler
{
    // The known-folders API is not in the SDK this port builds against, so the header is the port's own
    // (CharonFileProvider.h, from 26.2's NSFileProviderKnownFolders.h) and this is the
    // implementation of what that header declares. Documented: there is no extension host to claim
    // a folder for, and the call is the documented "cannot be used right now".
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

- (void)releaseKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders
           localizedReason:(NSString *)localizedReason
             completionHandler:(void (^)(NSError *_Nullable))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

- (void)registerURLSessionTask:(NSURLSessionTask *)task
         forItemWithIdentifier:(NSFileProviderItemIdentifier)identifier
             completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)containerItemIdentifier
                                completionHandler:(void (^)(NSError *_Nullable error))completion
{
    if (completion) {
        completion([NSFileProviderManager charon_unavailable]);
    }
}

- (void)requestDownloadForItemWithIdentifier:(NSFileProviderItemIdentifier)identifier
                               requestedRange:(NSRange)requestedRange
                             completionHandler:(void (^)(NSURL *_Nullable locationURL, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager charon_unavailable]);
    }
}

- (void)requestDiagnosticCollectionForItemWithIdentifier:(NSFileProviderItemIdentifier)identifier
                                             errorReason:(void (^)(NSError *_Nullable))errorReason
                                       completionHandler:(void (^)(NSURL *_Nullable diagnosticReportURL, NSError *_Nullable error))completionHandler
{
    // nil IS the answer for errorReason: a nil reason is what "no reason, the request was refused
    // for the unavailable error" means, and the failure itself arrives in the completion below.
    if (errorReason) {
        errorReason(nil);
    }
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager charon_unavailable]);
    }
}

#pragma mark - The 16.0 members, and what the 6.1.3 cache says about them

// Every selector in this section was searched for in the release's own cache, beside a control
// that is known to be there:
//
//   $ LC_ALL=C grep -c -a -F -- 'setNaturalLanguageQuery:' $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7
//   2
//   getUserVisibleURLForItemIdentifier:                       0
//   temporaryDirectoryURLWithError:                           0
//   signalErrorResolved:                                      0
//   globalProgressForKind:                                    0
//   getIdentifierForUserVisibleFileAtURL:                     0
//   removeDomain:mode:completionHandler:                      0
//   getDomainsWithCompletionHandler:   0   (the 11.0 members above, for the same answer)
//   managerForDomain:                  0
//
// The control proves the search reaches the strings, so a zero is an absence and not a miss. And
// the two members already implemented answer zero too: THE WHOLE FRAMEWORK IS ABSENT AT 6.1.3,
// which is what the facts file says and what these answers rest on. There is no release-side
// behaviour to reproduce, so each of the six answers as the host answers the same question on a
// machine with no domains, and two of them - the two the macOS header gates to iOS - have no host
// to be measured on and answer as the header documents.

// The URL a user sees for an item. Read-only, and the macOS header declares it with no
// availability gate, so the differential has a line for it: an item in no domain has no
// user-visible URL, and the answer is nil with the unavailable error.
- (void)getUserVisibleURLForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
                         completionHandler:(void (^)(NSURL *_Nullable url, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager charon_unavailable]);
    }
}

// The identifier for a file a user sees, which is the same question the other way. Declared with
// no gate on macOS, so it has a differential line too.
+ (void)getIdentifierForUserVisibleFileAtURL:(NSURL *)url
                           completionHandler:(void (^)(NSFileProviderItemIdentifier _Nullable itemIdentifier, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager charon_unavailable]);
    }
}

// The manager's temporary directory. `FILEPROVIDER_API_AVAILABILITY_V3_IOS` on the macOS header:
// iOS-only, so there is no host to measure it on and the answer is documented - a manager with no
// domain has no temporary directory to hand out, and the header's own contract is the error in
// the out-parameter.
- (NSURL *)temporaryDirectoryURLWithError:(NSError **)error
{
    if (error) {
        *error = [NSFileProviderManager charon_unavailable];
    }
    return nil;
}

// The progress of a kind of file operation. `FILEPROVIDER_API_AVAILABILITY_V3_1_IOS`: iOS-only, no
// host line, and there are no operations to be in progress for. nil, as a manager with no domains
// has none of the progress the type reports.
- (NSProgress *)globalProgressForKind:(NSProgressFileOperationKind)kind
{
    return nil;
}

// Tell the system an error was resolved. Declared on the macOS header with no gate, but it is NOT
// CALLED on the host: it tells the system something changed, which is the same rule as
// addDomain: and removeDomain:. The answer is documented - nothing is listening, so resolving an
// error has no observer - and there is no differential line, and the probe does not call it.
- (void)signalErrorResolved:(NSError *)error
           completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler([NSFileProviderManager charon_unavailable]);
    }
}

// Remove a domain, with the mode saying how. NOT IN THE MACOS HEADER AT ALL - grep over the
// macOS SDK's FileProvider headers finds no 'removeDomain:mode:' - so there is no host build of
// it at all, and it is not called on the host in any case. Its differential is taken from a COPY
// of this file, the way the mutant is, and the answer is the documented one: nothing is listening,
// and the 16.0 mode has nothing to choose between.
+ (void)removeDomain:(NSFileProviderDomain *)domain
                mode:(NSFileProviderDomainRemovalMode)mode
  completionHandler:(void (^)(NSURL *_Nullable preservedLocation, NSError *_Nullable error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [NSFileProviderManager charon_unavailable]);
    }
}

@end
