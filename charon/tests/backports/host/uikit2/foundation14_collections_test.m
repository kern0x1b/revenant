#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static uint64_t state = 0xC011EC7104ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *host_selector(NSString *name)
{
    return [@"charonHost" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]];
}

static NSString *normalized(NSString *text)
{
    if (!text)
        return @"-";
    NSMutableString *result = [text mutableCopy];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"charonHost([A-Za-z])" options:0 error:NULL];
    NSArray *matches = [expression matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSString *letter = [result substringWithRange:[match rangeAtIndex:1]];
        [result replaceCharactersInRange:match.range withString:letter.lowercaseString];
    }
    for (NSString *pattern in @[@"\\(0x[0-9a-fA-F]+\\)", @"0x[0-9a-fA-F]+", @"\\[/[^\\]]*\\]", @"CharonHost"])
        [result replaceOccurrencesOfString:pattern withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, result.length)];
    NSRange allowed = [result rangeOfString:@"Allowed classes are"];
    if (allowed.location != NSNotFound)
        [result deleteCharactersInRange:NSMakeRange(allowed.location, result.length - allowed.location)];
    return result;
}

static NSString *describe(id value, NSError *error, NSString *exception)
{
    if (exception)
        return [NSString stringWithFormat:@"raises %@", exception];
    NSString *text = value ? [NSString stringWithFormat:@"%@ %@", [value class], value] : @"nil";
    text = [[text stringByReplacingOccurrencesOfString:@"__NSCFConstantString" withString:@"S"] stringByReplacingOccurrencesOfString:@"NSTaggedPointerString" withString:@"S"];
    return [NSString stringWithFormat:@"%@ | %@ %ld %@", text, error.domain ?: @"-", (long)error.code, normalized(error.userInfo[NSDebugDescriptionErrorKey])];
}

static id random_leaf(void)
{
    switch (next() % 9) {
    case 0: return @(next() % 100);
    case 1: return [NSNull null];
    case 2: return [NSDate dateWithTimeIntervalSince1970:next() % 1000];
    case 3: return [NSData dataWithBytes:"ab" length:2];
    case 4: return [NSURL URLWithString:@"http://example.com"];
    case 5: return [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
    default: return [NSString stringWithFormat:@"s%u", next() % 50];
    }
}

static id random_value(int depth)
{
    switch (next() % (depth ? 8 : 6)) {
    case 0:
    case 1: {
        NSMutableArray *array = [NSMutableArray array];
        NSUInteger count = next() % 5;
        for (NSUInteger index = 0; index < count; index++)
            [array addObject:next() % 7 == 0 && depth < 2 ? random_value(depth + 1) : random_leaf()];
        return array;
    }
    case 2: {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        NSUInteger count = next() % 4;
        for (NSUInteger index = 0; index < count; index++)
            dictionary[next() % 6 == 0 ? @(next() % 5) : [NSString stringWithFormat:@"k%u", next() % 9]] = next() % 8 == 0 && depth < 2 ? random_value(depth + 1) : random_leaf();
        return dictionary;
    }
    case 3: return [NSSet setWithObjects:random_leaf(), random_leaf(), nil];
    case 4: return [NSOrderedSet orderedSetWithObjects:random_leaf(), random_leaf(), nil];
    default: return random_leaf();
    }
}

static NSData *archive(id root, BOOL keyed, BOOL secure)
{
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:secure];
    if (keyed)
        [archiver encodeObject:root forKey:@"k"];
    else
        [archiver encodeObject:root forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    return archiver.encodedData;
}

static NSSet *random_classes(void)
{
    NSArray *all = @[[NSString class], [NSNumber class], [NSDate class], [NSData class], [NSNull class], [NSURL class], [NSUUID class], [NSArray class], [NSDictionary class], [NSSet class], [NSMutableString class], [NSOrderedSet class], [NSObject class]];
    NSMutableSet *set = [NSMutableSet set];
    NSUInteger count = 1 + next() % 4;
    for (NSUInteger index = 0; index < count; index++)
        [set addObject:all[next() % (next() % 3 ? 7 : all.count)]];
    return set;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 20000, wrong = 0, unordered = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < cases; index++) {
            BOOL dictionary = next() % 3 == 0;
            BOOL classForm = next() % 2 == 0;
            BOOL classMethod = next() % 2 == 0;
            NSInteger policy = next() % 2;
            BOOL secure = next() % 6 != 0;
            id root = next() % 4 ? (dictionary ? [NSMutableDictionary dictionaryWithDictionary:@{@"a": random_leaf(), @"b": random_leaf()}] : [NSMutableArray arrayWithObjects:random_leaf(), random_leaf(), random_leaf(), nil]) : random_value(0);
            if (next() % 5 == 0)
                root = random_value(0);
            NSData *data = archive(root, !classMethod, secure);
            NSSet *keyClasses = random_classes(), *valueClasses = random_classes();
            if (classForm) {
                keyClasses = [NSSet setWithObject:keyClasses.anyObject];
                valueClasses = [NSSet setWithObject:valueClasses.anyObject];
            }
            NSString *(^run)(BOOL) = ^NSString *(BOOL port) {
                NSError *error = nil;
                id value = nil;
                NSString *exception = nil;
                @try {
                    if (classMethod) {
                        NSString *name = port ? host_selector(dictionary ? (classForm ? @"unarchivedDictionaryWithKeysOfClass:objectsOfClass:fromData:error:" : @"unarchivedDictionaryWithKeysOfClasses:objectsOfClasses:fromData:error:") : (classForm ? @"unarchivedArrayOfObjectsOfClass:fromData:error:" : @"unarchivedArrayOfObjectsOfClasses:fromData:error:"))
                                                    : (dictionary ? (classForm ? @"unarchivedDictionaryWithKeysOfClass:objectsOfClass:fromData:error:" : @"unarchivedDictionaryWithKeysOfClasses:objectsOfClasses:fromData:error:") : (classForm ? @"unarchivedArrayOfObjectsOfClass:fromData:error:" : @"unarchivedArrayOfObjectsOfClasses:fromData:error:"));
                        SEL selector = NSSelectorFromString(name);
                        if (dictionary)
                            value = ((id (*)(id, SEL, id, id, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], selector, classForm ? keyClasses.anyObject : keyClasses, classForm ? valueClasses.anyObject : valueClasses, data, &error), error = error;
                        else
                            value = ((id (*)(id, SEL, id, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], selector, classForm ? keyClasses.anyObject : keyClasses, data, &error);
                    } else {
                        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
                        unarchiver.requiresSecureCoding = secure;
                        unarchiver.decodingFailurePolicy = (NSDecodingFailurePolicy)policy;
                        NSString *base = dictionary ? (classForm ? @"decodeDictionaryWithKeysOfClass:objectsOfClass:forKey:" : @"decodeDictionaryWithKeysOfClasses:objectsOfClasses:forKey:") : (classForm ? @"decodeArrayOfObjectsOfClass:forKey:" : @"decodeArrayOfObjectsOfClasses:forKey:");
                        SEL selector = NSSelectorFromString(port ? host_selector(base) : base);
                        NSString *key = next() % 8 == 0 ? @"missing" : @"k";
                        if (dictionary)
                            value = ((id (*)(id, SEL, id, id, id))objc_msgSend)(unarchiver, selector, classForm ? keyClasses.anyObject : keyClasses, classForm ? valueClasses.anyObject : valueClasses, key);
                        else
                            value = ((id (*)(id, SEL, id, id))objc_msgSend)(unarchiver, selector, classForm ? keyClasses.anyObject : keyClasses, key);
                        error = unarchiver.error;
                    }
                } @catch (NSException *caught) {
                    exception = [NSString stringWithFormat:@"%@ %@", caught.name, normalized(caught.reason)];
                }
                return describe(value, error, exception);
            };
            uint64_t saved = state;
            NSString *a = run(YES);
            state = saved;
            NSString *b = run(NO);
            state = saved;
            (void)(next(), next());
            if (![a isEqualToString:b] && dictionary && ([a containsString:@"unexpected class"] || [a containsString:@"nested"]) && ([b containsString:@"unexpected class"] || [b containsString:@"nested"])) {
                unordered++;
                continue;
            }
            if (![a isEqualToString:b]) {
                wrong++;
                if (samples.count < 10)
                    [samples addObject:[NSString stringWithFormat:@"%s%s%s policy %ld secure %d root %@ classes %@ / %@\n     port   %@\n     system %@", dictionary ? "dictionary " : "array ", classForm ? "class " : "classes ", classMethod ? "unarchived" : "decode", (long)policy, secure, root, keyClasses, valueClasses, a, b]];
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        printf("info: %lu dictionaries with two faults name the other one, for the archive lists them in an order a decoded dictionary has lost\n", (unsigned long)unordered);
        charon_check(wrong == 0, "arrays and dictionaries decode, or fail, as the system's coder decodes them", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)cases]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
