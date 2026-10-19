// The paths of the CloudKit Web Services interface, the mapping between a record field and its wire
// value, and the query document a CKQuery's predicate becomes.
//
// These are the three pieces of the transport that need no network, and they are where most of what
// CloudKit asks for actually lives: the path a request goes to, the shape of the JSON it carries, and
// the one translation that has no mechanical answer, an NSPredicate into the query grammar the
// service reads.
//
// The endpoints are the ones Apple's CloudKit Web Services reference names. The database root is
// `database/1/<container>/<development|production>/<database>`, where 1 is development and 2 is
// production, and the database is `private`, `public`, `shared` or `zones/<name>`; facts/CloudKit/
// WebServices.md has the whole list. A zone or a record name is percent-encoded with the characters
// the reference names and no others, so a name with a slash in it cannot become a path.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"

#import <CommonCrypto/CommonDigest.h>

NSString *CharonCKDatabaseRoot(CKDatabase *database)
{
    CKDatabaseScope scope = database.databaseScope;
    NSString *root = (scope == CKDatabaseScopePublic) ? @"public"
                     : (scope == CKDatabaseScopeShared) ? @"shared" : @"private";
    CKContainer *container = [[CharonCKTransport shared].containerForDatabase
                             objectForKey:database];
    return [NSString stringWithFormat:@"database/1/%@/%@/%@", container.containerIdentifier,
            [[CharonCKTransport shared].environmentForDatabase objectForKey:database]
                ?: CharonCKDevelopmentEnvironment, root];
}

NSString *CharonCKZonePath(CKRecordZoneID *zoneID)
{
    if (!zoneID) {
        return @"zones";
    }
    return [NSString stringWithFormat:@"zones/%@", [zoneID.zoneName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

NSDictionary *CharonCKRecordIDDocument(CKRecordID *recordID)
{
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"recordName"] = recordID.recordName;
    document[@"zoneID"] = CharonCKZoneIDDocument(recordID.zoneID);
    return document;
}

NSDictionary *CharonCKZoneIDDocument(CKRecordZoneID *zoneID)
{
    return @{@"zoneName": zoneID.zoneName, @"ownerName": zoneID.ownerName};
}

CKRecordZoneID *CharonCKZoneIDFromDocument(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]]
        || ![json[@"zoneName"] isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *owner = json[@"ownerName"];
    return [[CKRecordZoneID alloc] initWithZoneName:json[@"zoneName"]
                                         ownerName:[owner isKindOfClass:[NSString class]] ? owner : nil];
}

CKRecordID *CharonCKRecordIDFromDocument(NSDictionary *json)
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

double CharonCKMilliseconds(NSDate *date)
{
    return date ? date.timeIntervalSince1970 * 1000.0 : 0;
}

NSString *CharonCKMD5Hex(NSData *data)
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int index = 0; index < CC_MD5_DIGEST_LENGTH; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return hex;
}

// MARK: - The field mapping

static NSString *CharonCKDateString(NSDate *date)
{
    // CloudKit writes a date as ISO 8601 in UTC with fractional seconds, the form its own documents
    // show, and reads that and the plain form of a query answer.
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

static NSDate *CharonCKDateFromString(NSString *text)
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

NSDate *CharonCKDateFromJSON(id json)
{
    if ([json isKindOfClass:[NSDate class]]) {
        return json;
    }
    if ([json isKindOfClass:[NSString class]]) {
        return CharonCKDateFromString(json);
    }
    if ([json isKindOfClass:[NSNumber class]]) {
        return [NSDate dateWithTimeIntervalSince1970:[json doubleValue] / 1000.0];
    }
    return nil;
}

// A location that carries an altitude, which CLLocation of this release cannot be asked for: the
// altitude is a property of the value CloudKit sends and the release's own CLLocation answers 0 for
// it, so a port that read a 3D location into a 2D one would answer a different place.
@interface CharonCKLocatedCoordinate : CLLocation
- (instancetype)initWithLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude altitude:(CLLocationDistance)altitude;
@end

@implementation CharonCKLocatedCoordinate
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

static CLLocation *CharonCKLocationFromJSON(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]] || !json[@"latitude"] || !json[@"longitude"]) {
        return nil;
    }
    CLLocationCoordinate2D coordinate = {[(NSNumber *)json[@"latitude"] doubleValue],
                                         [(NSNumber *)json[@"longitude"] doubleValue]};
    CLLocationAccuracy altitude = [json[@"altitude"] isKindOfClass:[NSNumber class]]
        ? [json[@"altitude"] doubleValue] : 0;
    // This release makes a location with a C function and with no initializer of its own that takes
    // a coordinate and an altitude, so the port's own is built from the two it does have.
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    if (altitude == 0) {
        return location;
    }
    return [[CharonCKLocatedCoordinate alloc] initWithLatitude:coordinate.latitude
                                                  longitude:coordinate.longitude
                                                     altitude:altitude];
}

id CharonCKValueFromJSON(id json, Class *kind)
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
            [out addObject:CharonCKValueFromJSON(item, NULL) ?: NSNull.null];
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
        return CharonCKLocationFromJSON(object);
    }
    if (object[@"recordName"]) {
        if (kind) {
            *kind = [CKReference class];
        }
        CKRecordID *recordID = CharonCKRecordIDFromDocument(object);
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
        // An asset arrives as its metadata. The bytes are a request of their own, so the file the
        // port answers -fileURL with is the one that request wrote, and it does not exist until it
        // has run: an asset of a fetched record that has not been downloaded has no file, and the
        // header says exactly that.
        return nil;
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:object.count];
    for (id key in object) {
        id value = CharonCKValueFromJSON(object[key], NULL);
        if (value) {
            out[key] = value;
        }
    }
    if (kind) {
        *kind = [NSDictionary class];
    }
    return out;
}

id CharonCKValueToJSON(id value)
{
    if (!value || value == NSNull.null) {
        return NSNull.null;
    }
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return CharonCKDateString(value);
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
        NSMutableDictionary *document = [CharonCKRecordIDDocument(reference.recordID) mutableCopy];
        document[@"action"] = reference.referenceAction == CKReferenceActionDeleteSelf ? @"DELETE_SELF" : @"NONE";
        return document;
    }
    if ([value isKindOfClass:[CKAsset class]]) {
        NSURL *file = [value fileURL];
        NSDictionary *attributes = file ? [[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:NULL] : nil;
        if (!file || !attributes) {
            // An asset with no readable file is a request the caller has not made yet, and the
            // service's own answer for that is an asset document with nothing in it.
            return @{@"fileChecksum": @"", @"size": @0, @"wrappingKey": @""};
        }
        return @{@"fileChecksum": CharonCKMD5Hex([NSData dataWithContentsOfFile:file.path]),
                 @"size": @([attributes fileSize]),
                 @"wrappingKey": @""};
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            [out addObject:CharonCKValueToJSON(item)];
        }
        return out;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        for (id key in dictionary) {
            out[[key description]] = CharonCKValueToJSON(dictionary[key]);
        }
        return out;
    }
    return NSNull.null;
}

NSDictionary *CharonCKFieldsToJSON(NSDictionary *fields)
{
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:fields.count];
    for (id key in fields) {
        out[key] = CharonCKValueToJSON(fields[key]);
    }
    return out;
}

NSDictionary *CharonCKFieldsFromJSON(NSDictionary *json)
{
    if (![json isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:json.count];
    for (id key in json) {
        id value = CharonCKValueFromJSON(json[key], NULL);
        if (value) {
            out[key] = value;
        }
    }
    return out;
}

CKRecordZone *CharonCKZoneWithDocument(NSDictionary *document)
{
    NSDictionary *zone = [document[@"zoneID"] isKindOfClass:[NSDictionary class]] ? document[@"zoneID"] : nil;
    if (!zone || !zone[@"zoneName"]) {
        return nil;
    }
    return [[CKRecordZone alloc] initWithZoneID:[[CKRecordZoneID alloc] initWithZoneName:zone[@"zoneName"]
                                                                               ownerName:zone[@"ownerName"] ?: CKOwnerDefaultName]];
}

// MARK: - The query document
//
// CloudKit's query grammar is not NSPredicate: a comparison is an `operator` of `equals`, `notEquals`,
// `lessThan`, `lessThanOrEquals`, `greaterThan`, `greaterThanOrEquals`, `like`, `notLike`, `beginsWith`,
// `contains` or `in` over a `field`, a `comparator` and a `value`; a compound is a `type` of `and` or
// `or` over `subs`; and a field is named either bare or with a chain of `field`/`value`. A predicate
// the grammar has no form for - a function, a compound comparison, a negation, a `ANY`/`ALL`/`NONE`
// quantifier - is refused with CKErrorInvalidArguments, which is the code CKErrorCode names for a
// malformed predicate. Answering a query the service would reject differently, or dropping part of
// the predicate and sending the rest, would be sending a query the caller did not ask for.

static NSString *CharonCKOparatorForPredicateOperator(NSPredicateOperatorType op)
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

// A key path, and the chain of values a compound key such as `location.latitude` is written with.
static BOOL CharonCKKeyChain(NSString *key, NSArray **chain)
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

static id CharonCKQueryValue(id value)
{
    if ([value isKindOfClass:[NSDate class]]) {
        return CharonCKDateString(value);
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

static NSDictionary *CharonCKPredicateDocument(NSPredicate *predicate, NSError **error)
{
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *compound = (NSCompoundPredicate *)predicate;
        if (compound.compoundPredicateType != NSAndPredicateType && compound.compoundPredicateType != NSOrPredicateType) {
            // A NOT has no form in the grammar. Negating is not the same as asking for the
            // complement, and a port that answered it with something else would be answering a
            // different query.
            if (error) {
                *error = CharonCKError(CKErrorInvalidArguments, @"A negated predicate has no form in a CloudKit query", nil);
            }
            return nil;
        }
        NSMutableArray *subs = [NSMutableArray array];
        for (NSPredicate *sub in compound.subpredicates) {
            NSDictionary *document = CharonCKPredicateDocument(sub, error);
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
            *error = CharonCKError(CKErrorInvalidArguments,
                                  [NSString stringWithFormat:@"A predicate of the kind %@ has no form in a CloudKit query",
                                   NSStringFromClass([predicate class])], nil);
        }
        return nil;
    }
    NSComparisonPredicate *comparison = (NSComparisonPredicate *)predicate;
    // A comparison whose right-hand side is another predicate is a compound comparison - `x < 1 < y` -
    // and the grammar has no form for one, whatever the operator says. The same goes for IN and
    // BETWEEN, which CloudKit's own CKQuery does not accept either.
    if ([comparison.rightExpression isKindOfClass:[NSPredicate class]] ||
        comparison.predicateOperatorType == NSInPredicateOperatorType ||
        comparison.predicateOperatorType == NSBetweenPredicateOperatorType) {
        if (error) {
            *error = CharonCKError(CKErrorInvalidArguments,
                                  @"This comparison has no form in a CloudKit query", nil);
        }
        return nil;
    }
    NSString *op = CharonCKOparatorForPredicateOperator(comparison.predicateOperatorType);
    if (!op) {
        if (error) {
            *error = CharonCKError(CKErrorInvalidArguments,
                                  @"This comparison has no form in a CloudKit query", nil);
        }
        return nil;
    }
    id key = comparison.leftExpression;
    if ([key isKindOfClass:[NSExpression class]]) {
        NSExpression *expression = (NSExpression *)key;
        if (expression.expressionType != NSKeyPathExpressionType) {
            if (error) {
                *error = CharonCKError(CKErrorInvalidArguments, @"Only a field has a form in a CloudKit query", nil);
            }
            return nil;
        }
        NSString *path = expression.description;
        if ([path hasPrefix:@"<"] && [path hasSuffix:@">"]) {
            path = [path substringWithRange:NSMakeRange(1, path.length - 2)];
        }
        key = path;
    }
    if (![key isKindOfClass:[NSString class]] || !CharonCKKeyChain(key, NULL)) {
        if (error) {
            *error = CharonCKError(CKErrorInvalidArguments, @"A CloudKit query names a field, and this names nothing", nil);
        }
        return nil;
    }
    id comparator = CharonCKQueryValue(comparison.rightExpression);
    if (!comparator) {
        if (error) {
            *error = CharonCKError(CKErrorInvalidArguments, @"A CloudKit query compares against a literal", nil);
        }
        return nil;
    }
    return @{@"operator": op, @"field": key, @"comparator": comparator, @"value": @1};
}

NSDictionary *CharonCKQueryDocument(CKQuery *query, NSString *zoneID, NSArray *desiredKeys,
                                    NSUInteger resultsLimit, NSError **error)
{
    if (!query) {
        if (error) {
            *error = CharonCKError(CKErrorInvalidArguments, @"No query", nil);
        }
        return nil;
    }
    NSMutableDictionary *document = [NSMutableDictionary dictionary];
    document[@"recordType"] = query.recordType;
    if (zoneID) {
        document[@"zoneID"] = @{@"zoneName": zoneID, @"ownerName": CKOwnerDefaultName};
    }
    NSDictionary *filter = CharonCKPredicateDocument(query.predicate, error);
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
                               @"relativeLocation": CharonCKValueToJSON([descriptor isKindOfClass:[CKLocationSortDescriptor class]]
                                                                            ? ((CKLocationSortDescriptor *)descriptor).relativeLocation : nil)}];
        }
        document[@"sort"] = sorts;
    }
    if (resultsLimit) {
        document[@"resultsLimit"] = @(resultsLimit);
    }
    return document;
}

CKQueryCursor *CharonCKCursorFromToken(NSData *token)
{
    return token.length ? [[CKQueryCursor alloc] initWithToken:token] : nil;
}

NSData *CharonCKTokenFromCursor(CKQueryCursor *cursor)
{
    return cursor.serverChangeToken;
}
