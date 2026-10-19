// The CloudKit Web Services client: the errors, the credentials, the transport, the paths, the query
// document and the field mapping.
//
// The whole of CloudKit above this file is written over it. What it is:
//
//  * A request is JSON under `https://api.apple-cloudkit.com/database/1/<container>/<environment>/<db>/…`,
//    where 1 is development and 2 is production and the database is `private`, `public`, `shared` or
//    `zones/<name>`. The endpoints are the ones Apple's CloudKit Web Services reference names:
//    `records/lookup`, `records/query`, `records/modify`, `records/changes`, `zones/lookup`,
//    `zones/modify`, `zones/list`, `zones/<name>/changes`, `subscriptions/lookup`, `subscriptions/modify`,
//    `subscriptions/list`, `users/lookup`, `users/discover`, `users/discover` and the asset endpoints.
//  * A request carries `Authorization: Bearer <token>` and `Content-Type: application/json`.
//  * An error comes back as a `CKError` built from the payload's own `serverErrorCode`, `reason` or
//    `errorMessage`, and from the two codes the header names for a client that never got there.
//
// It is sent with NSURLConnection, which is the release's own and which iOS 6.1.3 carries, rather
// than with the NSURLSession of the backports: a CloudKit client that has to load
// libFoundationBackports' session stack to make one request is a client that cannot be used by a
// daemon, and this file's only job is to answer a caller.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"

// The one name this file takes from the SIGNING half, declared rather than included, for the same
// reason Security/SecKeyElliptic10.m declares its three: the transport must not reach into a header
// that only the signing half installs. The symbol comes from the archive this library already links.
extern int CharonCKSignES256(const unsigned char *privateKey, const unsigned char *message,
                           size_t messageLength, unsigned char *der, size_t derLength);

#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>

NSString *const CharonCKHost = @"https://api.apple-cloudkit.com";
NSString *const CharonCKDevelopmentEnvironment = @"development";
NSString *const CharonCKProductionEnvironment = @"production";

static NSString *const CharonCKTokenKey = @"CharonCKToken";
static NSString *const CharonCKTokenExpiryKey = @"CharonCKTokenExpiry";
static NSString *const CharonCKUserRecordIDKey = @"CharonCKUserRecordID";

// MARK: - Errors

// A service error payload names the error three ways and which one is there depends on the endpoint:
// a `serverErrorCode` of the string CloudKit uses, a `reason`, and an `errorMessage` to show a
// person. The strings the service sends map to the codes the CKErrorCode header lists; a string with
// no code of its own is reported as CKErrorInternalError with the string in the description, which is
// the code the header calls non-recoverable and the only honest one.
static CKErrorCode CharonCKCodeForServerError(NSString *server)
{
    static NSDictionary *codes;
    if (!codes) {
        codes = @{@"ACCESS_DENIED": @(CKErrorPermissionFailure),
                  @"AUTHENTICATION_REQUIRED": @(CKErrorNotAuthenticated),
                  @"BAD_REQUEST": @(CKErrorInvalidArguments),
                  @"CONFLICT": @(CKErrorServerRecordChanged),
                  @"INTERNAL_ERROR": @(CKErrorInternalError),
                  @"NOT_FOUND": @(CKErrorUnknownItem),
                  @"NOT_IMPLEMENTED": @(CKErrorInternalError),
                  @"QUOTA_EXCEEDED": @(CKErrorQuotaExceeded),
                  @"RATE_LIMIT": @(CKErrorRequestRateLimited),
                  @"SERVICE_UNAVAILABLE": @(CKErrorServiceUnavailable),
                  @"ZONE_NOT_FOUND": @(CKErrorZoneNotFound)};
    }
    NSNumber *found = codes[server.uppercaseString];
    return found ? (CKErrorCode)found.integerValue : CKErrorInternalError;
}

NSError *CharonCKError(CKErrorCode code, NSString *message, NSDictionary *extra)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (message.length) {
        info[NSLocalizedDescriptionKey] = message;
    }
    if (extra.count) {
        [info addEntriesFromDictionary:extra];
    }
    return [NSError errorWithDomain:CKErrorDomain code:code userInfo:info];
}

NSError *CharonCKErrorFromPayload(NSDictionary *payload, NSDictionary *extra)
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return CharonCKError(CKErrorInternalError, nil, extra);
    }
    NSString *server = payload[@"serverErrorCode"];
    NSString *message = [payload[@"reason"] isKindOfClass:[NSString class]] ? payload[@"reason"] : nil;
    if (!message && [payload[@"errorMessage"] isKindOfClass:[NSString class]]) {
        message = payload[@"errorMessage"];
    }
    CKErrorCode code = [server isKindOfClass:[NSString class]] ? CharonCKCodeForServerError(server)
                                                             : CKErrorInternalError;
    NSNumber *numeric = payload[@"code"];
    if ([numeric isKindOfClass:[NSNumber class]] && numeric.integerValue > 0 &&
        numeric.integerValue <= CKErrorAccountTemporarilyUnavailable) {
        code = (CKErrorCode)numeric.integerValue;
    }
    NSMutableDictionary *merged = extra ? [extra mutableCopy] : [NSMutableDictionary dictionary];
    // The retry delay the service sends is a string of seconds and the header says the key holds a
    // number, so it is read as one.
    id retry = payload[@"retryAfter"];
    if ([retry isKindOfClass:[NSString class]]) {
        merged[CKErrorRetryAfterKey] = @([(NSString *)retry doubleValue]);
    } else if ([retry isKindOfClass:[NSNumber class]]) {
        merged[CKErrorRetryAfterKey] = retry;
    }
    NSDictionary *partial = payload[@"partialErrors"];
    if ([partial isKindOfClass:[NSDictionary class]] && partial.count) {
        merged[CKPartialErrorsByItemIDKey] = partial;
        if (code == CKErrorInternalError) {
            code = CKErrorPartialFailure;
        }
    }
    // A save rejected because the record moved carries the three records the caller resolves it
    // against, under the keys the header names.
    for (NSString *key in @[@"serverRecord", @"clientRecord", @"ancestorRecord"]) {
        NSDictionary *record = payload[key];
        if ([record isKindOfClass:[NSDictionary class]]) {
            NSString *outgoing = [key isEqualToString:@"serverRecord"] ? CKRecordChangedErrorServerRecordKey
                             : [key isEqualToString:@"clientRecord"] ? CKRecordChangedErrorClientRecordKey
                             : CKRecordChangedErrorAncestorRecordKey;
            merged[outgoing] = CharonCKRecordFromResult(record, nil);
        }
    }
    NSString *reset = payload[@"userDidResetEncryptedData"];
    if ([reset isKindOfClass:[NSString class]]) {
        merged[CKErrorUserDidResetEncryptedDataKey] = @([(NSString *)reset boolValue]);
    }
    return CharonCKError(code, message, merged);
}

NSError *CharonCKNotAuthenticated(void)
{
    return CharonCKError(CKErrorNotAuthenticated, @"Not authenticated", nil);
}

NSError *CharonCKBadContainer(NSString *containerIdentifier)
{
    return CharonCKError(CKErrorBadContainer,
                         containerIdentifier.length ? @"Un-provisioned or unauthorized container" : @"No container",
                         nil);
}

NSError *CharonCKTransportError(NSError *underlying)
{
    // A request that never reached the service is a network that was not available; one the network
    // refused on the way is a network failure, which is the distinction the header draws.
    BOOL refused = [underlying.domain isEqualToString:NSURLErrorDomain] ||
                   [underlying.domain isEqualToString:NSPOSIXErrorDomain] ||
                   [underlying.domain isEqualToString:NSOSStatusErrorDomain] ||
                   [underlying.domain isEqualToString:@"kCFErrorDomainCFString"];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSUnderlyingErrorKey] = underlying;
    if (underlying.localizedDescription.length) {
        info[NSLocalizedDescriptionKey] = underlying.localizedDescription;
    }
    return [NSError errorWithDomain:CKErrorDomain
                               code:refused ? CKErrorNetworkFailure : CKErrorNetworkUnavailable
                           userInfo:info];
}

// MARK: - The credentials

@implementation CharonCKCredentials

+ (instancetype)shared
{
    static CharonCKCredentials *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSMutableDictionary *)keysForContainer:(NSString *)containerIdentifier
{
    NSMutableDictionary *keys = [[NSUserDefaults standardUserDefaults] objectForKey:CharonCKTokenKey];
    if (!keys) {
        keys = [NSMutableDictionary dictionary];
    }
    (void)containerIdentifier;
    return keys;
}

- (void)setDeveloperToken:(NSString *)token
{
    if (!token) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CharonCKTokenKey];
        return;
    }
    NSMutableDictionary *keys = [self keysForContainer:nil];
    keys[@"developer"] = [NSDictionary dictionaryWithObjectsAndKeys:token, CharonCKTokenKey,
                                                 [NSDate distantFuture], CharonCKTokenExpiryKey, nil];
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:CharonCKTokenKey];
}

- (NSString *)signingKeyForContainer:(NSString *)containerIdentifier
{
    NSString *container = [containerIdentifier hasPrefix:@"iCloud.com.apple.developer."]
        ? [containerIdentifier substringFromIndex:@"iCloud.com.apple.developer.".length] : containerIdentifier;
    return [self provisionedKeyForContainer:container];
}

- (void)setSigningKey:(NSString *)pem forContainer:(NSString *)containerIdentifier
{
    NSMutableDictionary *keys = [self keysForContainer:containerIdentifier];
    if (!pem) {
        [keys removeObjectForKey:containerIdentifier];
    } else {
        keys[containerIdentifier] = pem;
    }
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:CharonCKTokenKey];
}

// The `.p8` an application is shipped with, in its bundle or in the Info.plist key CloudKit's own
// tooling writes. A key this port has not been given is not one it will look for: a release the
// application is built for does not know where to put one, and a key under a name the application
// never chose is a key nobody provisioned.
- (NSString *)provisionedKeyForContainer:(NSString *)containerIdentifier
{
    NSMutableDictionary *keys = [self keysForContainer:containerIdentifier];
    NSString *given = keys[containerIdentifier];
    if ([given isKindOfClass:[NSString class]] && given.length) {
        return given;
    }
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *name = [bundle objectForInfoDictionaryKey:@"CKWebServicesKeyFileName"];
    if (![name isKindOfClass:[NSString class]] || !name.length) {
        name = [NSString stringWithFormat:@"%@.p8", containerIdentifier];
    }
    NSString *path = [bundle pathForResource:[name stringByDeletingPathExtension] ofType:@"p8"];
    if (!path) {
        return nil;
    }
    NSString *pem = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    keys[containerIdentifier] = pem;
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:CharonCKTokenKey];
    return pem;
}

- (NSString *)tokenForContainer:(NSString *)containerIdentifier error:(NSError **)error
{
    if (!containerIdentifier.length) {
        if (error) {
            *error = CharonCKBadContainer(nil);
        }
        return nil;
    }
    NSMutableDictionary *keys = [self keysForContainer:containerIdentifier];
    NSDictionary *developer = [keys[@"developer"] isKindOfClass:[NSDictionary class]] ? keys[@"developer"] : nil;
    if (developer) {
        NSString *token = developer[CharonCKTokenKey];
        NSDate *expiry = developer[CharonCKTokenExpiryKey];
        if ([token isKindOfClass:[NSString class]] && token.length && [expiry timeIntervalSinceNow] > 60) {
            return token;
        }
    }
    NSString *pem = [self provisionedKeyForContainer:containerIdentifier];
    if (!pem.length) {
        if (error) {
            *error = CharonCKNotAuthenticated();
        }
        return nil;
    }
    NSString *keyID = [NSString stringWithFormat:@"iCloud.com.apple.developer.%@", containerIdentifier];
    NSString *team = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CKWebServicesTeamIdentifier"] copy];
    if (![team isKindOfClass:[NSString class]] || !team.length) {
        team = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TeamIdentifier"];
    }
    if (![team isKindOfClass:[NSString class]] || !team.length) {
        if (error) {
            // The token's own claims name the team and there is nowhere else to read it from, so a
            // key with no team answers the error the header names for a key that was never
            // provisioned for this container.
            *error = CharonCKBadContainer(containerIdentifier);
        }
        return nil;
    }
    NSString *token = CharonCKWebAuthToken(keyID, team, [NSDate date]);
    if (!token) {
        if (error) {
            *error = CharonCKNotAuthenticated();
        }
        return nil;
    }
    keys[@"developer"] = [NSDictionary dictionaryWithObjectsAndKeys:token, CharonCKTokenKey,
                                                [NSDate dateWithTimeIntervalSinceNow:55 * 60], CharonCKTokenExpiryKey, nil];
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:CharonCKTokenKey];
    return token;
}

- (NSString *)userRecordIDForContainer:(NSString *)containerIdentifier
{
    NSDictionary *identities = [[NSUserDefaults standardUserDefaults] objectForKey:CharonCKUserRecordIDKey];
    NSString *found = identities[containerIdentifier];
    return [found isKindOfClass:[NSString class]] ? found : nil;
}

- (void)setUserRecordID:(NSString *)userRecordID forContainer:(NSString *)containerIdentifier
{
    NSMutableDictionary *identities = [[[NSUserDefaults standardUserDefaults]
                                       objectForKey:CharonCKUserRecordIDKey] mutableCopy];
    if (!identities) {
        identities = [NSMutableDictionary dictionary];
    }
    if (userRecordID) {
        identities[containerIdentifier] = userRecordID;
    } else {
        [identities removeObjectForKey:containerIdentifier];
    }
    [[NSUserDefaults standardUserDefaults] setObject:identities forKey:CharonCKUserRecordIDKey];
}

@end

// MARK: - The token

NSString *CharonCKBase64URL(NSData *data)
{
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    NSMutableString *text = [encoded mutableCopy];
    [text replaceOccurrencesOfString:@"+" withString:@"-" options:0 range:NSMakeRange(0, text.length)];
    [text replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, text.length)];
    [text replaceOccurrencesOfString:@"=" withString:@"" options:0 range:NSMakeRange(0, text.length)];
    return text;
}

NSData *CharonCKPEMPrivateKey(NSString *pem)
{
    if (![pem isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSRange opening = [pem rangeOfString:@"-----BEGIN"];
    if (opening.location == NSNotFound) {
        return nil;
    }
    NSRange body = NSMakeRange(NSMaxRange(opening), 0);
    NSRange closing = [pem rangeOfString:@"-----" options:NSBackwardsSearch];
    if (closing.location == NSNotFound || closing.location <= body.location) {
        return nil;
    }
    body = NSMakeRange(body.location, closing.location - body.location);
    NSString *base64 = [pem substringWithRange:body];
    NSString *stripped = [[base64 componentsSeparatedByCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    return [[NSData alloc] initWithBase64EncodedString:stripped
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

// The JWT a web services authentication key signs: the header and the payload are CloudKit's own
// format, and the signature is ES256 over their concatenation, which charon@micro-ecc makes. The key
// identifier is the container's own, the issuer and the subject are the team, and the expiry is the
// hour CloudKit's tokens are good for.
NSString *CharonCKWebAuthToken(NSString *keyID, NSString *teamID, NSDate *now)
{
    NSDictionary *header = @{@"alg": @"ES256", @"kid": keyID, @"typ": @"JWT"};
    NSDictionary *payload = @{@"iss": teamID,
                              @"iat": @((long long)now.timeIntervalSince1970),
                              @"exp": @((long long)(now.timeIntervalSince1970 + 3600)),
                              @"sub": teamID};
    NSData *headerData = [NSJSONSerialization dataWithJSONObject:header options:0 error:NULL];
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    if (!headerData || !payloadData) {
        return nil;
    }
    NSMutableData *signing = [NSMutableData dataWithData:headerData];
    [signing appendData:payloadData];
    NSData *privateKey = CharonCKPEMPrivateKey([[CharonCKCredentials shared] signingKeyForContainer:keyID]);
    if (!privateKey || privateKey.length != 32) {
        return nil;
    }
    uint8_t signature[80];
    int length = CharonCKSignES256(privateKey.bytes, signing.bytes, signing.length, signature, sizeof signature);
    if (length <= 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@.%@.%@", CharonCKBase64URL(headerData), CharonCKBase64URL(payloadData),
            CharonCKBase64URL([NSData dataWithBytes:signature length:(NSUInteger)length])];
}

