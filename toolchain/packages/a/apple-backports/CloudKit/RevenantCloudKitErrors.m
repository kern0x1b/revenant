#import "CharonCloudKit.h"
#import "CharonCKConstants.h"

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
