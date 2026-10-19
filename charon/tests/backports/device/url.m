#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"
#import "url_expectations.h"

@interface ClientComponents : NSURLComponents
@end

@implementation ClientComponents
- (NSString *)percentEncodedHost
{
    return @"client";
}
@end

static BOOL same(id first, id second)
{
    return first == second || [first isEqual:second];
}

static int mismatches;
static int systemURLDifferences;

static BOOL sameURL(NSString *input, id expectedString, id expectedURL, id actualURL)
{
    if (same(expectedURL, actualURL))
        return YES;
    NSString *system = [NSURL URLWithString:expectedString].absoluteString;
    if ([expectedString isKindOfClass:[NSString class]] && same(actualURL, system)) {
        if (++systemURLDifferences <= 5)
            printf("iOS 6 NSURL turns %s into %s (macOS 27: %s)\n", [expectedString UTF8String], system.UTF8String, [[expectedURL description] UTF8String]);
        return YES;
    }
    return NO;
}

static void mismatch(const char *section, NSString *detail)
{
    if (++mismatches <= 100)
        charon_check(NO, section, detail);
}

static id value(id object)
{
    return object ? object : [NSNull null];
}

static NSString *text(id object)
{
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSArray *units = object[@"u16"];
        unichar *characters = malloc((units.count ? units.count : 1) * sizeof(unichar));
        for (NSUInteger index = 0; index < units.count; index++)
            characters[index] = (unichar)[units[index] unsignedIntValue];
        NSString *string = [NSString stringWithCharacters:characters length:units.count];
        free(characters);
        return string;
    }
    return [object isKindOfClass:[NSNull class]] ? nil : object;
}

static NSString *image_of(IMP implementation)
{
    Dl_info info;
    return dladdr((void *)implementation, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static id rangesOf(NSURLComponents *components)
{
    NSRange ranges[] = {components.rangeOfScheme, components.rangeOfUser, components.rangeOfPassword, components.rangeOfHost,
                        components.rangeOfPort, components.rangeOfPath, components.rangeOfQuery, components.rangeOfFragment};
    NSMutableArray *list = [NSMutableArray array];
    for (int index = 0; index < 8; index++)
        [list addObject:@[@(ranges[index].location == NSNotFound ? -1 : (long long)ranges[index].location), @(ranges[index].length)]];
    return list;
}

static id itemsOf(NSArray *items)
{
    if (!items)
        return [NSNull null];
    NSMutableArray *list = [NSMutableArray array];
    for (NSURLQueryItem *item in items)
        [list addObject:@[value(item.name), value(item.value)]];
    return list;
}

static NSArray *dumpNames(void)
{
    return @[@"scheme", @"percentEncodedUser", @"percentEncodedPassword", @"percentEncodedHost", @"port", @"percentEncodedPath", @"percentEncodedQuery",
             @"percentEncodedFragment", @"user", @"password", @"host", @"path", @"query", @"fragment", @"string", @"URL", @"ranges", @"queryItems"];
}

static id dump(NSURLComponents *components)
{
    if (!components)
        return [NSNull null];
    return @[value(components.scheme), value(components.percentEncodedUser), value(components.percentEncodedPassword), value(components.percentEncodedHost),
             value(components.port), value(components.percentEncodedPath), value(components.percentEncodedQuery), value(components.percentEncodedFragment),
             value(components.user), value(components.password), value(components.host), value(components.path), value(components.query), value(components.fragment),
             value(components.string), value(components.URL.absoluteString), rangesOf(components), itemsOf(components.queryItems)];
}

static BOOL compareDumps(const char *section, NSString *input, id expected, id actual)
{
    if ([expected isKindOfClass:[NSNull class]] || [actual isKindOfClass:[NSNull class]]) {
        if (same(expected, actual))
            return YES;
        mismatch(section, [NSString stringWithFormat:@"%@ -> %@, expected %@", input, actual, expected]);
        return NO;
    }
    BOOL equal = YES;
    for (NSUInteger index = 0; index < [expected count]; index++) {
        if (index == 15 && sameURL(input, expected[14], expected[15], actual[15]))
            continue;
        if (!same(expected[index], actual[index])) {
            mismatch(section, [NSString stringWithFormat:@"%@ %@ -> %@, expected %@", input, dumpNames()[index], actual[index], expected[index]]);
            equal = NO;
        }
    }
    return equal;
}

static void summary(const char *section, NSUInteger records, int before)
{
    charon_check(mismatches == before && records > 0, section, [NSString stringWithFormat:@"%d of %lu records differ", mismatches - before, (unsigned long)records]);
    printf("%s: %lu records\n", section, (unsigned long)records);
}

static NSCharacterSet *setNamed(NSString *name)
{
    if ([name isEqualToString:@"empty"])
        return [NSCharacterSet characterSetWithCharactersInString:@""];
    if ([name isEqualToString:@"alphanumeric"])
        return [NSCharacterSet alphanumericCharacterSet];
    if ([name isEqualToString:@"mixed"])
        return [NSCharacterSet characterSetWithCharactersInString:@"%é /中"];
    return [NSCharacterSet performSelector:NSSelectorFromString([NSString stringWithFormat:@"URL%@AllowedCharacterSet", name])];
}

static void testProvenance(void)
{
    CHECK([NSURLComponents class] != Nil, "NSURLComponents is bound");
    CHECK_EQUAL(@(class_getImageName([NSURLComponents class])).lastPathComponent, @"libFoundationBackports.dylib", "NSURLComponents comes from the backports library");
    CHECK(NSClassFromString(@"NSURLComponents") == [NSURLComponents class], "runtime lookup finds the same class");
    for (NSString *name in @[@"User", @"Password", @"Host", @"Path", @"Query", @"Fragment"]) {
        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"URL%@AllowedCharacterSet", name]);
        CHECK_EQUAL(image_of(class_getMethodImplementation(object_getClass([NSCharacterSet class]), selector)), @"libFoundationBackports.dylib", sel_getName(selector));
    }
    for (NSString *name in @[@"stringByAddingPercentEncodingWithAllowedCharacters:", @"stringByRemovingPercentEncoding"])
        CHECK_EQUAL(image_of(class_getMethodImplementation([NSString class], NSSelectorFromString(name))), @"libFoundationBackports.dylib", name.UTF8String);
    for (NSString *name in @[@"queryItems", @"setQueryItems:", @"string", @"rangeOfScheme", @"rangeOfUser", @"rangeOfPassword", @"rangeOfHost", @"rangeOfPort",
                             @"rangeOfPath", @"rangeOfQuery", @"rangeOfFragment", @"initWithString:", @"URL"])
        CHECK_EQUAL(image_of(class_getMethodImplementation([NSURLComponents class], NSSelectorFromString(name))), @"libFoundationBackports.dylib", name.UTF8String);
    CHECK([@"é" respondsToSelector:@selector(stringByRemovingPercentEncoding)], "a concrete string answers the added method");
}

static void testSets(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSCharacterSet *set = setNamed(record[0]);
        BOOL *members = calloc(0x10000, sizeof(BOOL));
        for (NSNumber *member in record[1])
            members[member.unsignedIntValue & 0xFFFF] = YES;
        for (UTF32Char character = 0; character < 0x10000; character++) {
            if ([set longCharacterIsMember:character] != members[character])
                mismatch("sets", [NSString stringWithFormat:@"URL%@AllowedCharacterSet U+%04X expected %d", record[0], (unsigned)character, members[character]]);
        }
        for (uint8_t plane = 1; plane <= 16; plane++) {
            if ([set hasMemberInPlane:plane])
                mismatch("sets", [NSString stringWithFormat:@"URL%@AllowedCharacterSet has members in plane %u", record[0], plane]);
        }
        free(members);
    }
    summary("sets (every BMP character, planes 1-16)", records.count, before);
}

static void testEncoding(NSArray *records)
{
    int before = mismatches;
    NSMutableDictionary *sets = [NSMutableDictionary dictionary];
    for (NSArray *record in records) {
        NSCharacterSet *set = sets[record[0]];
        if (!set)
            sets[record[0]] = set = setNamed(record[0]);
        NSString *input = text(record[1]);
        NSString *actual = [input stringByAddingPercentEncodingWithAllowedCharacters:set];
        if (!same(actual, text(record[2])))
            mismatch("encode", [NSString stringWithFormat:@"%@ %@ -> %@, expected %@", record[0], record[1], actual, record[2]]);
    }
    summary("stringByAddingPercentEncodingWithAllowedCharacters:", records.count, before);
}

static void testDecoding(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSString *actual = [text(record[0]) stringByRemovingPercentEncoding];
        if (!same(actual, text(record[1])))
            mismatch("decode", [NSString stringWithFormat:@"%@ -> %@, expected %@", record[0], actual, record[1]]);
    }
    summary("stringByRemovingPercentEncoding", records.count, before);
}

static void testParsing(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records)
        compareDumps("parse", record[0], record[1], dump([NSURLComponents componentsWithString:record[0]]));
    summary("componentsWithString: (all getters, string, URL, ranges, queryItems)", records.count, before);
}

static void testSetters(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSString *property = record[0];
        NSString *capitalized = [[[property substringToIndex:1] uppercaseString] stringByAppendingString:[property substringFromIndex:1]];
        NSURLComponents *components = [NSURLComponents new];
        [components performSelector:NSSelectorFromString([NSString stringWithFormat:@"set%@:", capitalized]) withObject:text(record[1])];
        id actual = [components performSelector:NSSelectorFromString([@"percentEncoded" stringByAppendingString:capitalized])];
        if (!same(actual, text(record[2])))
            mismatch("setters", [NSString stringWithFormat:@"set%@:%@ -> %@, expected %@", capitalized, record[1], actual, record[2]]);
    }
    summary("user/password/host/path/query/fragment setters", records.count, before);
}

static void testEncodedSetters(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSURLComponents *components = [NSURLComponents new];
        NSString *input = text(record[1]);
        BOOL accepted = YES;
        @try {
            [components performSelector:NSSelectorFromString([NSString stringWithFormat:@"setPercentEncoded%@:", record[0]]) withObject:input];
        } @catch (NSException *exception) {
            accepted = ![exception.name isEqualToString:NSInvalidArgumentException];
        }
        id stored = [components performSelector:NSSelectorFromString([@"percentEncoded" stringByAppendingString:record[0]])];
        if (accepted != [record[2] boolValue] || (accepted && !same(stored, input)))
            mismatch("percentEncoded setters", [NSString stringWithFormat:@"setPercentEncoded%@:%@ accepted %d, expected %@", record[0], record[1], accepted, record[2]]);
    }
    summary("percentEncoded setters (NSInvalidArgumentException)", records.count, before);
}

static void testSchemes(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSURLComponents *components = [NSURLComponents new];
        BOOL accepted = YES;
        @try {
            components.scheme = record[0];
        } @catch (NSException *exception) {
            accepted = ![exception.name isEqualToString:NSInvalidArgumentException];
        }
        if (accepted != [record[1] boolValue])
            mismatch("schemes", [NSString stringWithFormat:@"setScheme:%@ accepted %d", record[0], accepted]);
    }
    summary("setScheme:", records.count, before);
}

static void testPorts(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://h/p"];
        BOOL accepted = YES;
        @try {
            NSString *text = record[0];
            BOOL integral = [text rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"-0123456789"] invertedSet]].location == NSNotFound;
            components.port = integral ? [NSNumber numberWithLongLong:text.longLongValue] : [NSDecimalNumber decimalNumberWithString:text];
        } @catch (NSException *exception) {
            accepted = ![exception.name isEqualToString:NSInvalidArgumentException];
        }
        if (accepted != [record[1] boolValue] || !same(components.string, text(record[2])))
            mismatch("ports", [NSString stringWithFormat:@"setPort:%@ accepted %d string %@, expected %@", record[0], accepted, components.string, record[2]]);
    }
    summary("setPort:", records.count, before);
}

static void testComposition(NSArray *records)
{
    int before = mismatches;
    for (NSArray *record in records) {
        NSURLComponents *components = [NSURLComponents new];
        for (NSString *key in record[0])
            [components setValue:text(record[0][key]) forKey:key];
        if (!same(components.string, text(record[1])) || !same(rangesOf(components), record[2]) || !sameURL(nil, record[1], record[1], value(components.URL.absoluteString)))
            mismatch("compose", [NSString stringWithFormat:@"%@ -> %@ %@ URL %@, expected %@ %@", record[0], components.string, rangesOf(components), components.URL, record[1], record[2]]);
    }
    summary("string/URL/ranges from components", records.count, before);
}

static void testResolution(NSArray *records)
{
    int before = mismatches;
    int systemDifferences = 0;
    for (NSArray *record in records) {
        NSURL *base = [NSURL URLWithString:record[0]];
        NSURL *url = [NSURL URLWithString:record[1] relativeToURL:base];
        compareDumps("resolve NO", record[1], record[4], dump([NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO]));
        if ([url.absoluteString isEqualToString:record[2]]) {
            compareDumps("resolve YES", record[1], record[3], dump([NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES]));
            NSURL *relative = [[NSURLComponents componentsWithString:record[1]] URLRelativeToURL:base];
            if (!same(value(relative.absoluteString), record[5]))
                mismatch("URLRelativeToURL", [NSString stringWithFormat:@"%@ against %@ -> %@, expected %@", record[1], record[0], relative.absoluteString, record[5]]);
        } else {
            systemDifferences++;
            printf("iOS 6 NSURL resolves %s against %s to %s (macOS 27: %s)\n", [record[1] UTF8String], [record[0] UTF8String], url.absoluteString.UTF8String, [record[2] UTF8String]);
            compareDumps("resolve YES", record[1], dump([NSURLComponents componentsWithString:url.absoluteString]), dump([NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES]));
        }
    }
    summary("componentsWithURL:resolvingAgainstBaseURL: and URLRelativeToURL:", records.count, before);
    printf("resolution: %d references resolve differently in iOS 6 NSURL itself\n", systemDifferences);
    printf("URL: %d strings that iOS 6 NSURL itself rewrites (it percent-encodes '#' in URLs without '//')\n", systemURLDifferences);
}

static void testQueryItems(NSArray *getters, NSArray *setters)
{
    int before = mismatches;
    for (NSArray *record in getters) {
        NSURLComponents *components = [NSURLComponents new];
        components.percentEncodedQuery = record[0];
        if (!same(itemsOf(components.queryItems), record[1]))
            mismatch("queryItems", [NSString stringWithFormat:@"%@ -> %@, expected %@", record[0], itemsOf(components.queryItems), record[1]]);
    }
    for (NSArray *record in setters) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSArray *pair in record[0])
            [items addObject:[NSURLQueryItem queryItemWithName:pair[0] value:text(pair[1])]];
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://h/"];
        components.queryItems = items;
        if (!same(components.percentEncodedQuery, text(record[1])) || !same(itemsOf(components.queryItems), record[2]))
            mismatch("setQueryItems", [NSString stringWithFormat:@"%@ -> %@, expected %@", record[0], components.percentEncodedQuery, record[1]]);
    }
    summary("queryItems / setQueryItems:", getters.count + setters.count, before);
    NSURLComponents *components = [NSURLComponents componentsWithString:@"http://h/?a"];
    CHECK([NSURLComponents new].queryItems == nil, "no query gives nil queryItems");
    components.queryItems = nil;
    CHECK_EQUAL(components.string, @"http://h/", "setQueryItems:nil removes the query");
}

static void testObject(void)
{
    NSURLComponents *first = [NSURLComponents componentsWithString:@"http://u:p@h:8/p?q#f"];
    NSURLComponents *copy = [first copy];
    CHECK(copy != first && [copy isEqual:first] && copy.hash == first.hash, "copy is an equal, separate object");
    copy.host = @"other";
    CHECK([first.host isEqualToString:@"h"] && ![copy isEqual:first], "changing the copy leaves the original");
    CHECK(![[NSURLComponents componentsWithString:@"http://h/%41"] isEqual:[NSURLComponents componentsWithString:@"http://h/A"]], "equality compares percent-encoded components");
    CHECK([[NSURLComponents new] isEqual:[NSURLComponents new]], "empty components are equal");
    NSString *description = first.description;
    printf("description: %s\n", description.UTF8String);
    CHECK([description hasPrefix:@"<NSURLComponents 0x"] && [description hasSuffix:@"> {scheme = http, user = u, password = p, host = h, port = 8, path = /p, query = q, fragment = f}"], "description lists the components");
    CHECK([NSURLComponents new].path == nil, "init leaves the path undefined");
    CHECK([NSURLComponents componentsWithString:@"http://h/p q"] == nil, "invalid characters give nil");
    CHECK([NSURLComponents componentsWithString:@"http://xn--9ca.com/"].host.length == 11, "IDNA host is returned as written");
    NSURLComponents *host = [NSURLComponents new];
    host.host = @"é.com";
    CHECK_EQUAL(host.string, @"//%C3%A9.com", "non-ASCII host stays percent-encoded");
    NSString *reason = nil;
    @try {
        [NSURLComponents new].percentEncodedPath = @"a b";
    } @catch (NSException *exception) {
        reason = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    printf("exception: %s\n", reason.UTF8String);
    CHECK([reason hasPrefix:NSInvalidArgumentException], "percent-encoded setter raises NSInvalidArgumentException");
    @try {
        [NSURLComponents new].port = @(-1);
        reason = nil;
    } @catch (NSException *exception) {
        reason = exception.name;
    }
    CHECK_EQUAL(reason, NSInvalidArgumentException, "negative port raises");
    ClientComponents *client = [ClientComponents componentsWithString:@"http://h/p"];
    CHECK([client isKindOfClass:[NSURLComponents class]], "client subclass is a kind of the class");
    CHECK_EQUAL(client.string, @"http://client/p", "string uses the subclass's getters");
    CHECK_EQUAL(client.URL.host, @"client", "URL uses the subclass's getters");
    CHECK_EQUAL(NSStringFromRange(client.rangeOfHost), NSStringFromRange(NSMakeRange(7, 6)), "ranges follow the subclass's string");
    unichar lone = 0xD800;
    CHECK([[NSString stringWithCharacters:&lone length:1] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] == nil, "lone surrogate cannot be encoded");
    CHECK([[@"%F0%9F%98%80" stringByRemovingPercentEncoding] isEqualToString:@"\U0001F600"], "four-byte UTF-8 decodes to a surrogate pair");
}

int main(void)
{
    @autoreleasepool {
        testProvenance();
        NSData *data = [NSData dataWithBytesNoCopy:(void *)url_expectations length:strlen(url_expectations) freeWhenDone:NO];
        NSError *error = nil;
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        CHECK(expected != nil, "expectations generated on the host parse");
        if (!expected)
            printf("json error: %s\n", error.description.UTF8String);
        testSets(expected[@"sets"]);
        testEncoding(expected[@"encode"]);
        testDecoding(expected[@"decode"]);
        testParsing(expected[@"parse"]);
        testSetters(expected[@"setters"]);
        testEncodedSetters(expected[@"encodedSetters"]);
        testSchemes(expected[@"schemes"]);
        testPorts(expected[@"ports"]);
        testComposition(expected[@"compose"]);
        testResolution(expected[@"resolve"]);
        testQueryItems(expected[@"queryGet"], expected[@"querySet"]);
        testObject();
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
