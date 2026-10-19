#import "keyedarchive11-cases.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface KeyedArchive11Plain : NSObject <NSCoding>
@end

@implementation KeyedArchive11Plain
- (void)encodeWithCoder:(NSCoder *)coder {}
- (instancetype)initWithCoder:(NSCoder *)coder { return [super init]; }
@end

@implementation KeyedArchive11Recorder

- (instancetype)init
{
    if ((self = [super init]))
        _records = [NSMutableDictionary dictionary];
    return self;
}

- (void)record:(NSString *)value named:(NSString *)name
{
    if (_records[name])
        [NSException raise:NSInternalInconsistencyException format:@"record %@ is recorded twice", name];
    _records[name] = value ?: @"nil";
}

@end

static NSString *keyedarchive11_prefix;

static SEL sel(SEL selector)
{
    if (!keyedarchive11_prefix.length)
        return selector;
    NSString *name = NSStringFromSelector(selector);
    NSString *family = [keyedarchive11_prefix stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];
    family = [[family substringToIndex:1].uppercaseString stringByAppendingString:[family substringFromIndex:1]];
    for (NSString *word in @[@"mutableCopy", @"copy", @"init", @"new", @"alloc"]) {
        if ([name hasPrefix:word] && (name.length == word.length || [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[name characterAtIndex:word.length]] || [name characterAtIndex:word.length] == ':'))
            return NSSelectorFromString([NSString stringWithFormat:@"%@%@%@", word, family, [name substringFromIndex:word.length]]);
    }
    return NSSelectorFromString([keyedarchive11_prefix stringByAppendingString:name]);
}

static NSString *describe(NSError *error)
{
    if (!error)
        return @"nil";
    NSString *debug = error.userInfo[NSDebugDescriptionErrorKey];
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    return [NSString stringWithFormat:@"%@ %ld%@%@", error.domain, (long)error.code,
                                      debug ? [@" " stringByAppendingString:debug] : @"",
                                      underlying ? [NSString stringWithFormat:@" <%@ %ld>", underlying.domain, (long)underlying.code] : @""];
}
static id allocate(Class cls)
{
    return ((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
}

static id archiver_requiring(BOOL secure)
{
    return ((id (*)(id, SEL, BOOL))objc_msgSend)(allocate([NSKeyedArchiver class]), sel(@selector(initRequiringSecureCoding:)), secure);
}

static NSData *encoded_data(id archiver)
{
    return ((id (*)(id, SEL))objc_msgSend)(archiver, sel(@selector(encodedData)));
}

static NSData *archived(id object, BOOL secure, NSError **error)
{
    return ((id (*)(id, SEL, id, BOOL, NSError **))objc_msgSend)([NSKeyedArchiver class],
        sel(@selector(archivedDataWithRootObject:requiringSecureCoding:error:)), object, secure, error);
}

static id unarchived(Class cls, NSData *data, NSError **error)
{
    return ((id (*)(id, SEL, Class, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class],
        sel(@selector(unarchivedObjectOfClass:fromData:error:)), cls, data, error);
}

void keyedarchive11_run(NSString *prefix, KeyedArchive11Recorder *recorder)
{
    keyedarchive11_prefix = prefix;
    {
        id archiver = archiver_requiring(NO);
        [archiver encodeObject:@"x" forKey:@"root"];
        NSData *first = encoded_data(archiver);
        NSData *second = encoded_data(archiver);
        [recorder record:[first isKindOfClass:[NSMutableData class]] ? @"mutable" : @"immutable" named:@"encodedData.mutability"];
        [recorder record:first == second ? @"same" : @"different" named:@"encodedData.identity"];
        [recorder record:[first isEqual:second] ? @"equal" : @"unequal" named:@"encodedData.equality"];
        [recorder record:first.length > 0 ? @"non-empty" : @"empty" named:@"encodedData.length"];
    }

    {
        NSMutableData *buffer = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:buffer];
        [archiver encodeObject:@"x" forKey:@"root"];
        NSString *answer = nil;
        @try {
            NSData *data = encoded_data(archiver);
            answer = [NSString stringWithFormat:@"%@ %@", data.length > 0 ? @"non-empty" : @"empty",
                                                data == buffer ? @"the buffer" : @"another object"];
        } @catch (NSException *exception) {
            answer = [NSString stringWithFormat:@"raised %@", exception.name];
        }
        [recorder record:answer named:@"encodedData.oldStyle"];
    }
    {
        id archiver = archiver_requiring(NO);
        [archiver encodeObject:@"x" forKey:@"other"];
        NSError *error = nil;
        id decoded = unarchived([NSString class], encoded_data(archiver), &error);
        [recorder record:decoded ? [decoded description] : @"nil" named:@"missingRoot.object"];
        [recorder record:describe(error) named:@"missingRoot.error"];

        id nilRoot = archiver_requiring(NO);
        [nilRoot encodeObject:nil forKey:@"root"];
        NSError *nilError = nil;
        id nilDecoded = unarchived([NSString class], encoded_data(nilRoot), &nilError);
        [recorder record:nilDecoded ? [nilDecoded description] : @"nil" named:@"nilRoot.object"];
        [recorder record:describe(nilError) named:@"nilRoot.error"];
    }
    {
        NSError *error = nil;
        NSData *data = archived(@"text", YES, &error);
        [recorder record:data.length > 0 ? @"non-empty" : @"empty" named:@"roundTrip.data"];
        [recorder record:describe(error) named:@"roundTrip.archiveError"];
        NSError *readError = nil;
        id decoded = unarchived([NSString class], data, &readError);
        [recorder record:decoded ?: @"nil" named:@"roundTrip.object"];
        [recorder record:describe(readError) named:@"roundTrip.readError"];
    }
    {
        NSError *error = nil;
        NSData *data = archived([KeyedArchive11Plain new], YES, &error);
        [recorder record:data ? @"non-nil" : @"nil" named:@"insecureRoot.data"];
        [recorder record:error ? [NSString stringWithFormat:@"%@ %ld underlying=%@", error.domain, (long)error.code,
                                                            error.userInfo[NSUnderlyingErrorKey] ? @"yes" : @"no"] : @"nil"
                   named:@"insecureRoot.error"];
    }
    {
        NSData *junk = [@"not an archive at all" dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        id decoded = unarchived([NSString class], junk, &error);
        [recorder record:decoded ? [decoded description] : @"nil" named:@"junk.object"];
        [recorder record:error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code] : @"nil" named:@"junk.error"];
        NSError *initError = nil;
        id unarchiver = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(allocate([NSKeyedUnarchiver class]),
            sel(@selector(initForReadingFromData:error:)), junk, &initError);
        [recorder record:unarchiver ? @"non-nil" : @"nil" named:@"junk.unarchiver"];
        [recorder record:initError ? [NSString stringWithFormat:@"%@ %ld", initError.domain, (long)initError.code] : @"nil" named:@"junk.initError"];
    }
    {
        NSData *data = archived(@"text", YES, NULL);
        NSError *error = nil;
        NSKeyedUnarchiver *unarchiver = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(allocate([NSKeyedUnarchiver class]),
            sel(@selector(initForReadingFromData:error:)), data, &error);
        [recorder record:unarchiver.requiresSecureCoding ? @"YES" : @"NO" named:@"afterInit.requiresSecureCoding"];
        NSDecodingFailurePolicy policy = ((NSDecodingFailurePolicy (*)(id, SEL))objc_msgSend)(unarchiver, sel(@selector(decodingFailurePolicy)));
        [recorder record:policy == NSDecodingFailurePolicySetErrorAndReturn ? @"SetErrorAndReturn" : @"RaiseException"
                   named:@"afterInit.failurePolicy"];
    }
    {
        id secure = archiver_requiring(YES);
        id insecure = archiver_requiring(NO);
        [recorder record:[secure requiresSecureCoding] ? @"YES" : @"NO" named:@"initRequiring.yes"];
        [recorder record:[insecure requiresSecureCoding] ? @"YES" : @"NO" named:@"initRequiring.no"];
        [recorder record:[NSString stringWithFormat:@"%ld", (long)[secure outputFormat]] named:@"initRequiring.outputFormat"];
    }

    keyedarchive11_prefix = nil;
}
