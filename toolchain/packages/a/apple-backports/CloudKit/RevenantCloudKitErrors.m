#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"

extern int RevenantCKSignES256(const unsigned char *privateKey, const unsigned char *message,
                           size_t messageLength, unsigned char *der, size_t derLength);

#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>

NSString *const RevenantCKHost = @"https://api.apple-cloudkit.com";
NSString *const RevenantCKDevelopmentEnvironment = @"development";
NSString *const RevenantCKProductionEnvironment = @"production";

static NSString *const RevenantCKTokenKey = @"RevenantCKToken";
static NSString *const RevenantCKTokenExpiryKey = @"RevenantCKTokenExpiry";
static NSString *const RevenantCKUserRecordIDKey = @"RevenantCKUserRecordID";

static CKErrorCode RevenantCKCodeForServerError(NSString *server)
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

NSError *RevenantCKError(CKErrorCode code, NSString *message, NSDictionary *extra)
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

NSError *RevenantCKErrorFromPayload(NSDictionary *payload, NSDictionary *extra)
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return RevenantCKError(CKErrorInternalError, nil, extra);
    }
    NSString *server = payload[@"serverErrorCode"];
    NSString *message = [payload[@"reason"] isKindOfClass:[NSString class]] ? payload[@"reason"] : nil;
    if (!message && [payload[@"errorMessage"] isKindOfClass:[NSString class]]) {
        message = payload[@"errorMessage"];
    }
    CKErrorCode code = [server isKindOfClass:[NSString class]] ? RevenantCKCodeForServerError(server)
                                                             : CKErrorInternalError;
    NSNumber *numeric = payload[@"code"];
    if ([numeric isKindOfClass:[NSNumber class]] && numeric.integerValue > 0 &&
        numeric.integerValue <= CKErrorAccountTemporarilyUnavailable) {
        code = (CKErrorCode)numeric.integerValue;
    }
    NSMutableDictionary *merged = extra ? [extra mutableCopy] : [NSMutableDictionary dictionary];
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
    for (NSString *key in @[@"serverRecord", @"clientRecord", @"ancestorRecord"]) {
        NSDictionary *record = payload[key];
        if ([record isKindOfClass:[NSDictionary class]]) {
            NSString *outgoing = [key isEqualToString:@"serverRecord"] ? CKRecordChangedErrorServerRecordKey
                             : [key isEqualToString:@"clientRecord"] ? CKRecordChangedErrorClientRecordKey
                             : CKRecordChangedErrorAncestorRecordKey;
            merged[outgoing] = RevenantCKRecordFromResult(record, nil);
        }
    }
    NSString *reset = payload[@"userDidResetEncryptedData"];
    if ([reset isKindOfClass:[NSString class]]) {
        merged[CKErrorUserDidResetEncryptedDataKey] = @([(NSString *)reset boolValue]);
    }
    return RevenantCKError(code, message, merged);
}

NSError *RevenantCKNotAuthenticated(void)
{
    return RevenantCKError(CKErrorNotAuthenticated, @"Not authenticated", nil);
}

NSError *RevenantCKBadContainer(NSString *containerIdentifier)
{
    return RevenantCKError(CKErrorBadContainer,
                         containerIdentifier.length ? @"Un-provisioned or unauthorized container" : @"No container",
                         nil);
}

NSError *RevenantCKTransportError(NSError *underlying)
{
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

@implementation RevenantCKCredentials

+ (instancetype)shared
{
    static RevenantCKCredentials *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSMutableDictionary *)keysForContainer:(NSString *)containerIdentifier
{
    NSMutableDictionary *keys = [[NSUserDefaults standardUserDefaults] objectForKey:RevenantCKTokenKey];
    if (!keys) {
        keys = [NSMutableDictionary dictionary];
    }
    (void)containerIdentifier;
    return keys;
}

- (void)setDeveloperToken:(NSString *)token
{
    if (!token) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:RevenantCKTokenKey];
        return;
    }
    NSMutableDictionary *keys = [self keysForContainer:nil];
    keys[@"developer"] = [NSDictionary dictionaryWithObjectsAndKeys:token, RevenantCKTokenKey,
                                                 [NSDate distantFuture], RevenantCKTokenExpiryKey, nil];
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:RevenantCKTokenKey];
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
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:RevenantCKTokenKey];
}

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
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:RevenantCKTokenKey];
    return pem;
}

- (NSString *)tokenForContainer:(NSString *)containerIdentifier error:(NSError **)error
{
    if (!containerIdentifier.length) {
        if (error) {
            *error = RevenantCKBadContainer(nil);
        }
        return nil;
    }
    NSMutableDictionary *keys = [self keysForContainer:containerIdentifier];
    NSDictionary *developer = [keys[@"developer"] isKindOfClass:[NSDictionary class]] ? keys[@"developer"] : nil;
    if (developer) {
        NSString *token = developer[RevenantCKTokenKey];
        NSDate *expiry = developer[RevenantCKTokenExpiryKey];
        if ([token isKindOfClass:[NSString class]] && token.length && [expiry timeIntervalSinceNow] > 60) {
            return token;
        }
    }
    NSString *pem = [self provisionedKeyForContainer:containerIdentifier];
    if (!pem.length) {
        if (error) {
            *error = RevenantCKNotAuthenticated();
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
            *error = RevenantCKBadContainer(containerIdentifier);
        }
        return nil;
    }
    NSString *token = RevenantCKWebAuthToken(keyID, team, [NSDate date]);
    if (!token) {
        if (error) {
            *error = RevenantCKNotAuthenticated();
        }
        return nil;
    }
    keys[@"developer"] = [NSDictionary dictionaryWithObjectsAndKeys:token, RevenantCKTokenKey,
                                                [NSDate dateWithTimeIntervalSinceNow:55 * 60], RevenantCKTokenExpiryKey, nil];
    [[NSUserDefaults standardUserDefaults] setObject:keys forKey:RevenantCKTokenKey];
    return token;
}

- (NSString *)userRecordIDForContainer:(NSString *)containerIdentifier
{
    NSDictionary *identities = [[NSUserDefaults standardUserDefaults] objectForKey:RevenantCKUserRecordIDKey];
    NSString *found = identities[containerIdentifier];
    return [found isKindOfClass:[NSString class]] ? found : nil;
}

- (void)setUserRecordID:(NSString *)userRecordID forContainer:(NSString *)containerIdentifier
{
    NSMutableDictionary *identities = [[[NSUserDefaults standardUserDefaults]
                                       objectForKey:RevenantCKUserRecordIDKey] mutableCopy];
    if (!identities) {
        identities = [NSMutableDictionary dictionary];
    }
    if (userRecordID) {
        identities[containerIdentifier] = userRecordID;
    } else {
        [identities removeObjectForKey:containerIdentifier];
    }
    [[NSUserDefaults standardUserDefaults] setObject:identities forKey:RevenantCKUserRecordIDKey];
}

@end

NSString *RevenantCKBase64URL(NSData *data)
{
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    NSMutableString *text = [encoded mutableCopy];
    [text replaceOccurrencesOfString:@"+" withString:@"-" options:0 range:NSMakeRange(0, text.length)];
    [text replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, text.length)];
    [text replaceOccurrencesOfString:@"=" withString:@"" options:0 range:NSMakeRange(0, text.length)];
    return text;
}

NSData *RevenantCKPEMPrivateKey(NSString *pem)
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

NSString *RevenantCKWebAuthToken(NSString *keyID, NSString *teamID, NSDate *now)
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
    NSData *privateKey = RevenantCKPEMPrivateKey([[RevenantCKCredentials shared] signingKeyForContainer:keyID]);
    if (!privateKey || privateKey.length != 32) {
        return nil;
    }
    uint8_t signature[80];
    int length = RevenantCKSignES256(privateKey.bytes, signing.bytes, signing.length, signature, sizeof signature);
    if (length <= 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@.%@.%@", RevenantCKBase64URL(headerData), RevenantCKBase64URL(payloadData),
            RevenantCKBase64URL([NSData dataWithBytes:signature length:(NSUInteger)length])];
}
