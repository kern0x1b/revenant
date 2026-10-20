#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"

#import <CommonCrypto/CommonDigest.h>

NSString *RevenantCKDatabaseRoot(CKDatabase *database)
{
    CKDatabaseScope scope = database.databaseScope;
    NSString *root = (scope == CKDatabaseScopePublic) ? @"public"
                     : (scope == CKDatabaseScopeShared) ? @"shared" : @"private";
    CKContainer *container = [[RevenantCKTransport shared].containerForDatabase
                             objectForKey:database];
    return [NSString stringWithFormat:@"database/1/%@/%@/%@", container.containerIdentifier,
            [[RevenantCKTransport shared].environmentForDatabase objectForKey:database]
                ?: RevenantCKDevelopmentEnvironment, root];
}

NSString *RevenantCKZonePath(CKRecordZoneID *zoneID)
{
    if (!zoneID) {
        return @"zones";
    }
    return [NSString stringWithFormat:@"zones/%@", [zoneID.zoneName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

NSDictionary *RevenantCKRecordIDDocument(CKRecordID *recordID)
{
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"recordName"] = recordID.recordName;
    document[@"zoneID"] = RevenantCKZoneIDDocument(recordID.zoneID);
    return document;
}

NSDictionary *RevenantCKZoneIDDocument(CKRecordZoneID *zoneID)
{
    return @{@"zoneName": zoneID.zoneName, @"ownerName": zoneID.ownerName};
}

CKRecordZoneID *RevenantCKZoneIDFromDocument(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]]
        || ![json[@"zoneName"] isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *owner = json[@"ownerName"];
    return [[CKRecordZoneID alloc] initWithZoneName:json[@"zoneName"]
                                         ownerName:[owner isKindOfClass:[NSString class]] ? owner : nil];
}

CKRecordID *RevenantCKRecordIDFromDocument(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]] || ![json[@"recordName"] isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSDictionary *zone = json[@"zoneID"];
    CKRecordZoneID *zoneID = [zone isKindOfClass:[NSDictionary class]]
        ? [[CKRecordZoneID alloc] initWithZoneName:zone[@"zoneName"] ownerName:zone[@"ownerName"]]
        : [[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName ownerName:CKOwnerDefaultName];
    return [[CKRecordID alloc] initWithRecordName:json[@"recordName"] zoneID:zoneID];
}

double RevenantCKMilliseconds(NSDate *date)
{
    return date ? date.timeIntervalSince1970 * 1000.0 : 0;
}

NSString *RevenantCKMD5Hex(NSData *data)
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int index = 0; index < CC_MD5_DIGEST_LENGTH; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return hex;
}

static NSString *RevenantCKDateString(NSDate *date)
{
    static NSDateFormatter *written, *plain;
    if (!written) {
        written = [[NSDateFormatter alloc] init];
        written.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        written.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        written.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        plain = [[NSDateFormatter alloc] init];
        plain.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        plain.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        plain.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    }
    return [written stringFromDate:date];
}

static NSDate *RevenantCKDateFromString(NSString *text)
{
    static NSDateFormatter *written, *plain;
    if (!written) {
        written = [[NSDateFormatter alloc] init];
        written.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
        written.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        written.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        plain = [[NSDateFormatter alloc] init];
        plain.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        plain.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        plain.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    }
    return [written dateFromString:text] ?: [plain dateFromString:text];
}

NSDate *RevenantCKDateFromJSON(id json)
{
    if ([json isKindOfClass:[NSDate class]]) {
        return json;
    }
    if ([json isKindOfClass:[NSString class]]) {
        return RevenantCKDateFromString(json);
    }
    if ([json isKindOfClass:[NSNumber class]]) {
        return [NSDate dateWithTimeIntervalSince1970:[json doubleValue] / 1000.0];
    }
    return nil;
}

@interface RevenantCKLocatedCoordinate : CLLocation
- (instancetype)initWithLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude altitude:(CLLocationDistance)altitude;
@end

@implementation RevenantCKLocatedCoordinate
{
    CLLocationDistance _altitude;
}

- (instancetype)initWithLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude altitude:(CLLocationDistance)altitude
{
    self = [super initWithLatitude:latitude longitude:longitude];
    if (self) {
        _altitude = altitude;
    }
    return self;
}

- (CLLocationDistance)altitude
{
    return _altitude;
}

@end

static CLLocation *RevenantCKLocationFromJSON(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]] || !json[@"latitude"] || !json[@"longitude"]) {
        return nil;
    }
    CLLocationCoordinate2D coordinate = {[(NSNumber *)json[@"latitude"] doubleValue],
                                         [(NSNumber *)json[@"longitude"] doubleValue]};
    CLLocationAccuracy altitude = [json[@"altitude"] isKindOfClass:[NSNumber class]]
        ? [json[@"altitude"] doubleValue] : 0;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    if (altitude == 0) {
        return location;
    }
    return [[RevenantCKLocatedCoordinate alloc] initWithLatitude:coordinate.latitude
                                                  longitude:coordinate.longitude
                                                     altitude:altitude];
}

id RevenantCKValueFromJSON(id json, Class *kind)
{
    if (!json || json == NSNull.null) {
        return nil;
    }
    if ([json isKindOfClass:[NSString class]] || [json isKindOfClass:[NSNumber class]]) {
        if (kind) {
            *kind = [json isKindOfClass:[NSString class]] ? [NSString class] : [NSNumber class];
        }
        return json;
    }
    if ([json isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:[json count]];
        for (id item in (NSArray *)json) {
            [out addObject:RevenantCKValueFromJSON(item, NULL) ?: NSNull.null];
        }
        if (kind) {
            *kind = [NSArray class];
        }
        return out;
    }
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *object = json;
    if (object[@"latitude"] && object[@"longitude"]) {
        if (kind) {
            *kind = [CLLocation class];
        }
        return RevenantCKLocationFromJSON(object);
    }
    if (object[@"recordName"]) {
        if (kind) {
            *kind = [CKReference class];
        }
        CKRecordID *recordID = RevenantCKRecordIDFromDocument(object);
        if (!recordID) {
            return nil;
        }
        NSString *action = object[@"action"];
        return [[CKReference alloc] initWithRecordID:recordID
                                                action:[action isEqualToString:@"DELETE_SELF"] ? CKReferenceActionDeleteSelf
                                                                                              : CKReferenceActionNone];
    }
    if (object[@"fileChecksum"] || object[@"size"]) {
        if (kind) {
            *kind = [CKAsset class];
        }
        return nil;
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:object.count];
    for (id key in object) {
        id value = RevenantCKValueFromJSON(object[key], NULL);
        if (value) {
            out[key] = value;
        }
    }
    if (kind) {
        *kind = [NSDictionary class];
    }
    return out;
}

id RevenantCKValueToJSON(id value)
{
    if (!value || value == NSNull.null) {
        return NSNull.null;
    }
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return RevenantCKDateString(value);
    }
    if ([value isKindOfClass:[NSData class]]) {
        return [value base64EncodedStringWithOptions:0];
    }
    if ([value isKindOfClass:[CLLocation class]]) {
        return @{@"latitude": @([value coordinate].latitude),
                 @"longitude": @([value coordinate].longitude),
                 @"altitude": @([value altitude])};
    }
    if ([value isKindOfClass:[CKReference class]]) {
        CKReference *reference = value;
        NSMutableDictionary *document = [RevenantCKRecordIDDocument(reference.recordID) mutableCopy];
        document[@"action"] = reference.referenceAction == CKReferenceActionDeleteSelf ? @"DELETE_SELF" : @"NONE";
        return document;
    }
    if ([value isKindOfClass:[CKAsset class]]) {
        NSURL *file = [value fileURL];
        NSDictionary *attributes = file ? [[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:NULL] : nil;
        if (!file || !attributes) {
            return @{@"fileChecksum": @"", @"size": @0, @"wrappingKey": @""};
        }
        return @{@"fileChecksum": RevenantCKMD5Hex([NSData dataWithContentsOfFile:file.path]),
                 @"size": @([attributes fileSize]),
                 @"wrappingKey": @""};
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            [out addObject:RevenantCKValueToJSON(item)];
        }
        return out;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        for (id key in dictionary) {
            out[[key description]] = RevenantCKValueToJSON(dictionary[key]);
        }
        return out;
    }
    return NSNull.null;
}

NSDictionary *RevenantCKFieldsToJSON(NSDictionary *fields)
{
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:fields.count];
    for (id key in fields) {
        out[key] = RevenantCKValueToJSON(fields[key]);
    }
    return out;
}

NSDictionary *RevenantCKFieldsFromJSON(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:json.count];
    for (id key in json) {
        id value = RevenantCKValueFromJSON(json[key], NULL);
        if (value) {
            out[key] = value;
        }
    }
    return out;
}

CKRecordZone *RevenantCKZoneWithDocument(NSDictionary *document)
{
    NSDictionary *zone = [document[@"zoneID"] isKindOfClass:[NSDictionary class]] ? document[@"zoneID"] : nil;
    if (!zone || !zone[@"zoneName"]) {
        return nil;
    }
    return [[CKRecordZone alloc] initWithZoneID:[[CKRecordZoneID alloc] initWithZoneName:zone[@"zoneName"]
                                                                               ownerName:zone[@"ownerName"] ?: CKOwnerDefaultName]];
}

static NSString *RevenantCKOparatorForPredicateOperator(NSPredicateOperatorType op)
{
    switch (op) {
        case NSEqualToPredicateOperatorType: return @"equals";
        case NSNotEqualToPredicateOperatorType: return @"notEquals";
        case NSLessThanPredicateOperatorType: return @"lessThan";
        case NSLessThanOrEqualToPredicateOperatorType: return @"lessThanOrEquals";
        case NSGreaterThanPredicateOperatorType: return @"greaterThan";
        case NSGreaterThanOrEqualToPredicateOperatorType: return @"greaterThanOrEquals";
        case NSBeginsWithPredicateOperatorType: return @"beginsWith";
        case NSContainsPredicateOperatorType: return @"contains";
        case NSLikePredicateOperatorType: return @"like";
        case NSMatchesPredicateOperatorType: return @"like";
        default: return nil;
    }
}

static BOOL RevenantCKKeyChain(NSString *key, NSArray **chain)
{
    NSMutableArray *parts = [[key componentsSeparatedByString:@"."] mutableCopy];
    if (parts.count < 1 || [key hasPrefix:@"."] || [key hasSuffix:@"."]) {
        return NO;
    }
    for (NSString *part in parts) {
        if (!part.length) {
            return NO;
        }
    }
    if (chain) {
        *chain = parts;
    }
    return YES;
}

static id RevenantCKQueryValue(id value)
{
    if ([value isKindOfClass:[NSDate class]]) {
        return RevenantCKDateString(value);
    }
    if ([value isKindOfClass:[CLLocation class]]) {
        return @{@"latitude": @([value coordinate].latitude), @"longitude": @([value coordinate].longitude)};
    }
    if ([value isKindOfClass:[NSData class]]) {
        return [value base64EncodedStringWithOptions:0];
    }
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    return nil;
}

static NSDictionary *RevenantCKPredicateDocument(NSPredicate *predicate, NSError **error)
{
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *compound = (NSCompoundPredicate *)predicate;
        if (compound.compoundPredicateType != NSAndPredicateType && compound.compoundPredicateType != NSOrPredicateType) {
            if (error) {
                *error = RevenantCKError(CKErrorInvalidArguments, @"A negated predicate has no form in a CloudKit query", nil);
            }
            return nil;
        }
        NSMutableArray *subs = [NSMutableArray array];
        for (NSPredicate *sub in compound.subpredicates) {
            NSDictionary *document = RevenantCKPredicateDocument(sub, error);
            if (!document) {
                return nil;
            }
            [subs addObject:document];
        }
        return @{@"type": compound.compoundPredicateType == NSAndPredicateType ? @"and" : @"or",
                 @"subs": subs};
    }
    if (![predicate isKindOfClass:[NSComparisonPredicate class]]) {
        if (error) {
            *error = RevenantCKError(CKErrorInvalidArguments,
                                  [NSString stringWithFormat:@"A predicate of the kind %@ has no form in a CloudKit query",
                                   NSStringFromClass([predicate class])], nil);
        }
        return nil;
    }
    NSComparisonPredicate *comparison = (NSComparisonPredicate *)predicate;
    if ([comparison.rightExpression isKindOfClass:[NSPredicate class]] ||
        comparison.predicateOperatorType == NSInPredicateOperatorType ||
        comparison.predicateOperatorType == NSBetweenPredicateOperatorType) {
        if (error) {
            *error = RevenantCKError(CKErrorInvalidArguments,
                                  @"This comparison has no form in a CloudKit query", nil);
        }
        return nil;
    }
    NSString *op = RevenantCKOparatorForPredicateOperator(comparison.predicateOperatorType);
    if (!op) {
        if (error) {
            *error = RevenantCKError(CKErrorInvalidArguments,
                                  @"This comparison has no form in a CloudKit query", nil);
        }
        return nil;
    }
    id key = comparison.leftExpression;
    if ([key isKindOfClass:[NSExpression class]]) {
        NSExpression *expression = (NSExpression *)key;
        if (expression.expressionType != NSKeyPathExpressionType) {
            if (error) {
                *error = RevenantCKError(CKErrorInvalidArguments, @"Only a field has a form in a CloudKit query", nil);
            }
            return nil;
        }
        NSString *path = expression.description;
        if ([path hasPrefix:@"<"] && [path hasSuffix:@">"]) {
            path = [path substringWithRange:NSMakeRange(1, path.length - 2)];
        }
        key = path;
    }
    if (![key isKindOfClass:[NSString class]] || !RevenantCKKeyChain(key, NULL)) {
        if (error) {
            *error = RevenantCKError(CKErrorInvalidArguments, @"A CloudKit query names a field, and this names nothing", nil);
        }
        return nil;
    }
    id comparator = RevenantCKQueryValue(comparison.rightExpression);
    if (!comparator) {
        if (error) {
            *error = RevenantCKError(CKErrorInvalidArguments, @"A CloudKit query compares against a literal", nil);
        }
        return nil;
    }
    return @{@"operator": op, @"field": key, @"comparator": comparator, @"value": @1};
}

NSDictionary *RevenantCKQueryDocument(CKQuery *query, NSString *zoneID, NSArray *desiredKeys,
                                    NSUInteger resultsLimit, NSError **error)
{
    if (!query) {
        if (error) {
            *error = RevenantCKError(CKErrorInvalidArguments, @"No query", nil);
        }
        return nil;
    }
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"recordType"] = query.recordType;
    if (zoneID) {
        document[@"zoneID"] = @{@"zoneName": zoneID, @"ownerName": CKOwnerDefaultName};
    }
    NSDictionary *filter = RevenantCKPredicateDocument(query.predicate, error);
    if (!filter) {
        return nil;
    }
    document[@"filter"] = filter;
    if (desiredKeys.count) {
        document[@"desiredKeys"] = desiredKeys;
    }
    NSArray *sortDescriptors = query.sortDescriptors;
    if (sortDescriptors.count) {
        NSMutableArray *sorts = [NSMutableArray array];
        for (NSSortDescriptor *descriptor in sortDescriptors) {
            [sorts addObject:@{@"field": descriptor.key,
                               @"ascending": @((int)descriptor.ascending),
                               @"relativeLocation": RevenantCKValueToJSON([descriptor isKindOfClass:[CKLocationSortDescriptor class]]
                                                                            ? ((CKLocationSortDescriptor *)descriptor).relativeLocation : nil)}];
        }
        document[@"sort"] = sorts;
    }
    if (resultsLimit) {
        document[@"resultsLimit"] = @(resultsLimit);
    }
    return document;
}

CKQueryCursor *RevenantCKCursorFromToken(NSData *token)
{
    return token.length ? [[CKQueryCursor alloc] initWithToken:token] : nil;
}

NSData *RevenantCKTokenFromCursor(CKQueryCursor *cursor)
{
    return cursor.serverChangeToken;
}
