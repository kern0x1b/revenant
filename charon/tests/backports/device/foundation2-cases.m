#import "foundation2-cases.h"
#import <objc/message.h>
#import <objc/runtime.h>

@implementation Foundation2Recorder

- (instancetype)init
{
    if ((self = [super init])) {
        _records = [NSMutableDictionary dictionary];
        _tolerated = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)record:(id)value named:(NSString *)name
{
    [self record:value named:name tolerating:nil];
}

- (void)record:(id)value named:(NSString *)name tolerating:(NSString *)divergence
{
    if (_records[name])
        [NSException raise:NSInternalInconsistencyException format:@"record %@ is recorded twice", name];
    _records[name] = foundation2_portable(value);
    if (divergence)
        _tolerated[name] = divergence;
}

@end

static void progress(NSString *stage)
{
    printf("stage %s\n", stage.UTF8String);
    fflush(stdout);
}

static NSString *foundation2_prefix;
static Foundation2Implementation foundation2_implementation;

static SEL sel(SEL selector)
{
    if (!foundation2_prefix.length)
        return selector;
    NSString *name = NSStringFromSelector(selector);
    NSString *family = [foundation2_prefix stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];
    family = [[family substringToIndex:1].uppercaseString stringByAppendingString:[family substringFromIndex:1]];
    for (NSString *word in @[@"mutableCopy", @"copy", @"init", @"new", @"alloc"]) {
        if ([name hasPrefix:word] && (name.length == word.length || [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[name characterAtIndex:word.length]] || [name characterAtIndex:word.length] == ':'))
            return NSSelectorFromString([NSString stringWithFormat:@"%@%@%@", word, family, [name substringFromIndex:word.length]]);
    }
    return NSSelectorFromString([foundation2_prefix stringByAppendingString:name]);
}

id foundation2_portable(id value)
{
    if (!value)
        return @"<nil>";
    if ([value isKindOfClass:[NSNumber class]] && strcmp([value objCType], @encode(double)) != 0 && strcmp([value objCType], @encode(float)) != 0) {
        long long number = [value longLongValue];
        if (number == (long long)NSNotFound || number == (long long)NSIntegerMax)
            return @"NSNotFound";
        return @(number);
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in value)
            [items addObject:foundation2_portable(item)];
        return items;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *items = [NSMutableDictionary dictionary];
        for (id key in value)
            items[key] = foundation2_portable(value[key]);
        return items;
    }
    return value;
}

NSString *foundation2_digest(NSData *data)
{
    uint64_t hash = 0xcbf29ce484222325ULL;
    const uint8_t *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++) {
        hash ^= bytes[index];
        hash *= 0x100000001b3ULL;
    }
    return [NSString stringWithFormat:@"%lu:%016llx", (unsigned long)data.length, (unsigned long long)hash];
}

static NSString *hex(NSData *data)
{
    if (!data)
        return @"<nil>";
    if (data.length > 48)
        return foundation2_digest(data);
    NSMutableString *text = [NSMutableString stringWithString:@"0x"];
    const uint8_t *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++)
        [text appendFormat:@"%02x", bytes[index]];
    return text;
}

static NSString *visible(NSString *string)
{
    if (!string)
        return @"<nil>";
    if (string.length > 160)
        return foundation2_digest([string dataUsingEncoding:NSUTF8StringEncoding]);
    return [[string stringByReplacingOccurrencesOfString:@"\r" withString:@"<CR>"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<LF>"];
}

static uint32_t random_state;

static uint32_t next_random(void)
{
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return random_state;
}

static NSData *random_bytes(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger index = 0; index < length; index++)
        bytes[index] = (uint8_t)next_random();
    return data;
}

static NSString *exception_name(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return exception.name;
    }
    return @"none";
}

typedef id (*F2InitObjectOptions)(__attribute__((ns_consumed)) id, SEL, id, NSUInteger) __attribute__((ns_returns_retained));
typedef id (*F2InitBytesDeallocator)(__attribute__((ns_consumed)) id, SEL, void *, NSUInteger, id) __attribute__((ns_returns_retained));
typedef id (*F2InitFileSystem)(__attribute__((ns_consumed)) id, SEL, const char *, BOOL, id) __attribute__((ns_returns_retained));
typedef id (*F2InitDataError)(__attribute__((ns_consumed)) id, SEL, id, NSError **) __attribute__((ns_returns_retained));
typedef id (*F2InitFlag)(__attribute__((ns_consumed)) id, SEL, BOOL) __attribute__((ns_returns_retained));
typedef id (*F2InitObjectObject)(__attribute__((ns_consumed)) id, SEL, id, id) __attribute__((ns_returns_retained));

static NSData *decode_string(Class class, NSString *string, NSUInteger options)
{
    return ((F2InitObjectOptions)objc_msgSend)([class alloc], sel(@selector(initWithBase64EncodedString:options:)), string, options);
}

static NSData *decode_data(Class class, NSData *data, NSUInteger options)
{
    return ((F2InitObjectOptions)objc_msgSend)([class alloc], sel(@selector(initWithBase64EncodedData:options:)), data, options);
}

static NSString *encode_string(NSData *data, NSUInteger options)
{
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(data, sel(@selector(base64EncodedStringWithOptions:)), options);
}

static NSData *encode_data(NSData *data, NSUInteger options)
{
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(data, sel(@selector(base64EncodedDataWithOptions:)), options);
}

static const NSUInteger encoding_options[] = {0, 1, 2, 3, 4, 8, 16, 32, 48, 64, 1 | 16, 1 | 32, 1 | 48, 2 | 16, 2 | 32, 2 | 48, 3 | 48, 0xFFFFFFFFu};

static void run_base64(Foundation2Recorder *recorder)
{
    size_t optionCount = sizeof encoding_options / sizeof *encoding_options;
    NSMutableData *pattern = [NSMutableData data];
    for (NSUInteger length = 0; length <= 80; length++) {
        for (size_t option = 0; option < optionCount; option++) {
            NSUInteger options = encoding_options[option];
            NSString *name = [NSString stringWithFormat:@"base64.encode.pattern.%lu.%lx", (unsigned long)length, (unsigned long)options];
            [recorder record:visible(encode_string(pattern, options)) named:[name stringByAppendingString:@".string"]];
            [recorder record:hex(encode_data(pattern, options)) named:[name stringByAppendingString:@".data"]];
        }
        uint8_t byte = (uint8_t)(length * 7 + 3);
        [pattern appendBytes:&byte length:1];
    }
    [recorder record:NSStringFromClass([encode_string([NSData data], 0) class]).length ? @"string" : @"?" named:@"base64.encode.empty.kind"];
    random_state = 0x9E3779B9u;
    for (int round = 0; round < 300; round++) {
        if (round % 25 == 0)
            progress([NSString stringWithFormat:@"base64.random.%d", round]);
        NSUInteger length = next_random() % (round < 250 ? 700 : 20000);
        NSUInteger options = encoding_options[next_random() % optionCount];
        NSData *data = random_bytes(length);
        NSString *name = [NSString stringWithFormat:@"base64.random.%d", round];
        NSString *string = encode_string(data, options);
        NSData *encoded = encode_data(data, options);
        [recorder record:@[@(length), @(options), foundation2_digest([string dataUsingEncoding:NSUTF8StringEncoding]), foundation2_digest(encoded)] named:[name stringByAppendingString:@".encode"]];
        NSUInteger decodeOptions = next_random() % 2;
        [recorder record:@[hex(decode_string([NSData class], string, decodeOptions)), hex(decode_data([NSMutableData class], encoded, decodeOptions)), @([decode_string([NSData class], string, 1) isEqual:data])] named:[name stringByAppendingString:@".decode"]];
        NSMutableString *corrupt = [string mutableCopy];
        NSUInteger edits = 1 + next_random() % 3;
        static NSString *const noise[] = {@"=", @"=", @"==", @"\r\n", @" ", @"\t", @"*", @"é", @"-", @"_", @"A", @"\0", @" ", @"/"};
        for (NSUInteger edit = 0; edit < edits; edit++) {
            NSUInteger at = corrupt.length ? next_random() % (corrupt.length + 1) : 0;
            switch (next_random() % 3) {
            case 0:
                [corrupt insertString:noise[next_random() % (sizeof noise / sizeof *noise)] atIndex:at];
                break;
            case 1:
                if (at < corrupt.length)
                    [corrupt deleteCharactersInRange:NSMakeRange(at, 1)];
                break;
            default:
                if (at < corrupt.length)
                    [corrupt replaceCharactersInRange:NSMakeRange(at, 1) withString:noise[next_random() % (sizeof noise / sizeof *noise)]];
                break;
            }
        }
        for (NSUInteger ignore = 0; ignore < 2; ignore++) {
            [recorder record:@[hex(decode_string([NSData class], corrupt, ignore)), hex(decode_data([NSData class], [corrupt dataUsingEncoding:NSUTF8StringEncoding], ignore))]
                       named:[NSString stringWithFormat:@"%@.corrupt.%lu", name, (unsigned long)ignore]];
        }
    }
    NSArray *inputs = @[@"", @"YQ==", @"YQ", @"YQ=", @"YWI=", @"YWI", @"YWJj", @"Y", @"YQ==YQ==", @"YQ==\n", @"Y Q = =", @"YR==", @"YWJ=", @"YQ===", @"=", @"==", @"===", @"====",
                        @"YQ=\n=", @"YW\r\nJj", @"YW*Jj", @"YWJj====", @"YQ=a", @"é", @"YWJjZA", @"YWJjZA=", @"YWJjZA==", @"-_-_", @"+/+/", @"YQ= =", @"YWJjZA==YWJj",
                        @"YWJjZ", @"YWJjZ===", @"=YQ==", @" YWJj ", @"YWéJj", @"YWJj\0", @"////", @"AAAA", @"QUJD\r\nREVG", @"QUJDREVG\r\n", @"\r\nQUJDREVG"];
    for (NSUInteger index = 0; index < inputs.count; index++) {
        for (NSUInteger options = 0; options < 3; options++) {
            NSString *input = inputs[index];
            NSUInteger ignore = options & 1;
            [recorder record:@[hex(decode_string([NSData class], input, options)), hex(decode_data([NSData class], [input dataUsingEncoding:NSUTF8StringEncoding], options)), hex(decode_string([NSMutableData class], input, options))]
                       named:[NSString stringWithFormat:@"base64.decode.fixed.%lu.%lu", (unsigned long)index, (unsigned long)options]];
        }
    }
    NSMutableData *mutable = (NSMutableData *)decode_string([NSMutableData class], @"YWJj", 0);
    [recorder record:@[@([mutable isKindOfClass:[NSMutableData class]]), hex(mutable)] named:@"base64.decode.mutable"];
    [mutable appendBytes:"d" length:1];
    [recorder record:hex(mutable) named:@"base64.decode.mutable.append"];
    [recorder record:exception_name(^{ decode_string([NSData class], nil, 0); }) named:@"base64.decode.nilString"];
    [recorder record:exception_name(^{ decode_data([NSData class], nil, 0); }) named:@"base64.decode.nilData"];
    [recorder record:exception_name(^{ decode_string([NSData class], nil, 1); }) named:@"base64.decode.nilStringIgnoring"];
}

static void run_byte_ranges(Foundation2Recorder *recorder)
{
    NSMutableArray *datas = [NSMutableArray arrayWithObjects:[NSData data], [@"hello" dataUsingEncoding:NSUTF8StringEncoding], [NSMutableData dataWithLength:3], nil];
    [datas addObject:[NSData dataWithBytesNoCopy:(void *)"static" length:6 freeWhenDone:NO]];
    [datas addObject:random_bytes(100000)];
    for (NSUInteger index = 0; index < datas.count; index++) {
        NSData *data = datas[index];
        NSMutableArray *calls = [NSMutableArray array];
        void (^block)(const void *, NSRange, BOOL *) = ^(const void *bytes, NSRange range, BOOL *stop) {
            [calls addObject:@[@(range.location), @(range.length), @(bytes == data.bytes), @(*stop)]];
        };
        ((void (*)(id, SEL, id))objc_msgSend)(data, sel(@selector(enumerateByteRangesUsingBlock:)), block);
        [recorder record:calls named:[NSString stringWithFormat:@"byteRanges.%lu", (unsigned long)index]];
    }
    __block NSUInteger stopped = 0;
    void (^stopping)(const void *, NSRange, BOOL *) = ^(const void *bytes, NSRange range, BOOL *stop) {
        stopped++;
        *stop = YES;
    };
    ((void (*)(id, SEL, id))objc_msgSend)([@"abc" dataUsingEncoding:NSUTF8StringEncoding], sel(@selector(enumerateByteRangesUsingBlock:)), stopping);
    [recorder record:@(stopped) named:@"byteRanges.stop"];
}

static NSMutableArray *deallocation_events;

static id deallocating(Class class, void *bytes, NSUInteger length, NSString *tag)
{
    void (^deallocator)(void *, NSUInteger) = ^(void *freed, NSUInteger freedLength) {
        [deallocation_events addObject:[NSString stringWithFormat:@"%@ deallocator same=%d length=%lu", tag, freed == bytes, (unsigned long)freedLength]];
    };
    return ((F2InitBytesDeallocator)objc_msgSend)([class alloc], sel(@selector(initWithBytesNoCopy:length:deallocator:)), bytes, length, deallocator);
}

static void run_deallocator(Foundation2Recorder *recorder)
{
    deallocation_events = [NSMutableArray array];
    char *buffer = malloc(16);
    memcpy(buffer, "0123456789abcdef", 16);
    @autoreleasepool {
        NSData *data = deallocating([NSData class], buffer, 16, @"immutable");
        [deallocation_events addObject:[NSString stringWithFormat:@"immutable created same=%d length=%lu mutable=%d", data.bytes == buffer, (unsigned long)data.length, [data isKindOfClass:[NSMutableData class]]]];
        NSData *copy = [data copy];
        NSData *mutableCopy = [data mutableCopy];
        data = nil;
        [deallocation_events addObject:[NSString stringWithFormat:@"immutable released copy=%@ mutableCopy=%@", hex(copy), hex(mutableCopy)]];
        copy = nil;
        [deallocation_events addObject:@"immutable copy released"];
    }
    [deallocation_events addObject:@"immutable pool drained"];
    @autoreleasepool {
        NSData *data = deallocating([NSData class], buffer, 0, @"empty");
        [deallocation_events addObject:[NSString stringWithFormat:@"empty created length=%lu", (unsigned long)data.length]];
        data = nil;
    }
    [deallocation_events addObject:@"empty pool drained"];
    @autoreleasepool {
        NSMutableData *data = deallocating([NSMutableData class], buffer, 16, @"mutable");
        [deallocation_events addObject:[NSString stringWithFormat:@"mutable created same=%d length=%lu mutable=%d", data.bytes == buffer, (unsigned long)data.length, [data isKindOfClass:[NSMutableData class]]]];
        [data appendBytes:"!" length:1];
        [deallocation_events addObject:[NSString stringWithFormat:@"mutable appended %@", hex(data)]];
        data = nil;
    }
    [deallocation_events addObject:@"mutable pool drained"];
    @autoreleasepool {
        NSData *data = ((F2InitBytesDeallocator)objc_msgSend)([NSData alloc],sel(@selector(initWithBytesNoCopy:length:deallocator:)), buffer, 16, nil);
        [deallocation_events addObject:[NSString stringWithFormat:@"nil deallocator same=%d %@", data.bytes == buffer, hex(data)]];
    }
    [deallocation_events addObject:@"nil pool drained"];
    [recorder record:deallocation_events named:@"deallocator.events"];
    free(buffer);
}

static void run_index_path(Foundation2Recorder *recorder)
{
    NSUInteger indexes[] = {5, 0, 7, 12, 3};
    NSIndexPath *path = [NSIndexPath indexPathWithIndexes:indexes length:5];
    NSIndexPath *empty = [[NSIndexPath alloc] init];
    NSArray *ranges = @[[NSValue valueWithRange:NSMakeRange(0, 5)], [NSValue valueWithRange:NSMakeRange(1, 3)], [NSValue valueWithRange:NSMakeRange(5, 0)], [NSValue valueWithRange:NSMakeRange(4, 1)],
                        [NSValue valueWithRange:NSMakeRange(4, 2)], [NSValue valueWithRange:NSMakeRange(6, 0)], [NSValue valueWithRange:NSMakeRange(NSNotFound, 0)], [NSValue valueWithRange:NSMakeRange(2, NSUIntegerMax)],
                        [NSValue valueWithRange:NSMakeRange(NSUIntegerMax, 2)]];
    NSArray *subjects = @[path, empty, [NSIndexPath indexPathWithIndex:9]];
    for (NSUInteger subjectIndex = 0; subjectIndex < subjects.count; subjectIndex++) {
        NSIndexPath *subject = subjects[subjectIndex];
        for (NSUInteger rangeIndex = 0; rangeIndex < ranges.count; rangeIndex++) {
            NSValue *value = ranges[rangeIndex];
            NSRange range = value.rangeValue;
            NSMutableData *storage = [NSMutableData dataWithLength:8 * sizeof(NSUInteger)];
            NSUInteger *output = storage.mutableBytes;
            for (int index = 0; index < 8; index++)
                output[index] = 99;
            NSString *exception = exception_name(^{
                ((void (*)(id, SEL, NSUInteger *, NSRange))objc_msgSend)(subject, sel(@selector(getIndexes:range:)), output, range);
            });
            NSMutableArray *written = [NSMutableArray array];
            for (int index = 0; index < 8; index++)
                [written addObject:@(output[index])];
            [recorder record:@[exception, written] named:[NSString stringWithFormat:@"indexPath.%lu.%lu", (unsigned long)subjectIndex, (unsigned long)rangeIndex]];
        }
    }
}

static NSString *url_text(NSURL *url, NSString *directory)
{
    if (!url)
        return @"<nil>";
    NSString *(^plain)(NSString *) = ^(NSString *string) {
        return [string stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"];
    };
    NSString *base = url.baseURL ? plain(url.baseURL.absoluteString) : @"-";
    NSString *absolute = plain(url.absoluteString);
    if (directory.length && [base isEqualToString:directory]) {
        BOOL upwards = [url.relativeString rangeOfString:@".."].location != NSNotFound;
        absolute = !upwards && [absolute hasPrefix:directory] ? [@"$CWD" stringByAppendingString:[absolute substringFromIndex:directory.length]] : @"$CWD-relative";
        base = @"$CWD";
    }
    return [NSString stringWithFormat:@"%@ | %@ | %@", plain(url.relativeString), base, absolute];
}

static void run_url(Foundation2Recorder *recorder)
{
    progress(@"url.fileSystem");
    NSString *directory = [[[NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES] absoluteString] stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"];
    NSArray *paths = @[@"a/b", @"/abs/x", @"", @"rel dir/ä%20#?;", @"../up", @"a//b/", @"~/x", @"/", @".", @"./x/", @"/trailing/", @"//double", @"a/./b/../c", @"näive", @"sp ace", @"%41"];
    NSArray *bases = @[[NSNull null], [NSURL URLWithString:@"file:///tmp/base/"], [NSURL URLWithString:@"file:///tmp/base"], [NSURL URLWithString:@"http://host/dir/"], [NSURL URLWithString:@"sub/" relativeToURL:[NSURL URLWithString:@"file:///root/"]]];
    for (NSUInteger pathIndex = 0; pathIndex < paths.count; pathIndex++) {
        progress([NSString stringWithFormat:@"url.fileSystem.%lu", (unsigned long)pathIndex]);
        for (NSUInteger baseIndex = 0; baseIndex < bases.count; baseIndex++) {
            for (int isDirectory = 0; isDirectory < 2; isDirectory++) {
                NSURL *base = bases[baseIndex] == [NSNull null] ? nil : bases[baseIndex];
                const char *path = [paths[pathIndex] UTF8String];
                NSURL *made = ((F2InitFileSystem)objc_msgSend)([NSURL alloc], sel(@selector(initFileURLWithFileSystemRepresentation:isDirectory:relativeToURL:)), path, isDirectory, base);
                NSURL *convenience = ((id (*)(id, SEL, const char *, BOOL, id))objc_msgSend)([NSURL class], sel(@selector(fileURLWithFileSystemRepresentation:isDirectory:relativeToURL:)), path, isDirectory, base);
                [recorder record:@[url_text(made, directory), url_text(convenience, directory), @([made isEqual:convenience] || made == convenience), @([made isKindOfClass:[NSURL class]] || !made)]
                           named:[NSString stringWithFormat:@"url.fileSystem.%lu.%lu.%d", (unsigned long)pathIndex, (unsigned long)baseIndex, isDirectory]];
            }
        }
    }
    progress(@"url.representation");
    NSArray *urls = @[[NSURL fileURLWithPath:@"/tmp/a b/ä"], [NSURL URLWithString:@"http://h/p%20q/r?x#y"], [NSURL URLWithString:@"x/y" relativeToURL:[NSURL URLWithString:@"file:///a/b/"]],
                      [NSURL URLWithString:@"file:"], [NSURL URLWithString:@"mailto:x@y"], [NSURL URLWithString:@"file:///a/%00b"], [NSURL URLWithString:@"file:///dir/"], [NSURL URLWithString:@"file://host/x"],
                      [NSURL URLWithString:@"file:///%C3%A4%2F"], [NSURL URLWithString:@"data:,hello"], [NSURL URLWithString:@"file:///a/b/../c/./d"], [NSURL URLWithString:@"file:///na%CC%88ive"]];
    for (NSUInteger index = 0; index < urls.count; index++) {
        progress([NSString stringWithFormat:@"url.representation.%lu", (unsigned long)index]);
        NSURL *url = urls[index];
        const char *representation = ((const char *(*)(id, SEL))objc_msgSend)(url, sel(@selector(fileSystemRepresentation)));
        NSMutableArray *fits = [NSMutableArray array];
        for (NSUInteger capacity = 0; capacity < 24; capacity += 3) {
            char buffer[32];
            memset(buffer, '#', sizeof buffer);
            BOOL fitted = ((BOOL (*)(id, SEL, char *, NSUInteger))objc_msgSend)(url, sel(@selector(getFileSystemRepresentation:maxLength:)), buffer, capacity);
            [fits addObject:fitted ? [NSString stringWithFormat:@"%lu:%s", (unsigned long)capacity, buffer] : [NSString stringWithFormat:@"%lu:NO", (unsigned long)capacity]];
        }
        [recorder record:@[representation ? hex([NSData dataWithBytes:representation length:strlen(representation)]) : @"<NULL>", fits] named:[NSString stringWithFormat:@"url.representation.%lu", (unsigned long)index]];
    }
    progress(@"url.resourceCache");
    NSURL *folder = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSMutableArray *events = [NSMutableArray array];
    id value = nil;
    NSError *error = nil;
    void (^read)(NSURL *, NSString *) = ^(NSURL *url, NSString *key) {
        id found = @"<untouched>";
        NSError *failure = nil;
        BOOL success = [url getResourceValue:&found forKey:key error:&failure];
        [events addObject:[NSString stringWithFormat:@"%@=%d:%@:%@", key, success, found ?: @"<nil>", failure ? @(failure.code) : @"-"]];
    };
    ((void (*)(id, SEL, id, id))objc_msgSend)(folder, sel(@selector(setTemporaryResourceValue:forKey:)), @"one", @"org.charon.first");
    ((void (*)(id, SEL, id, id))objc_msgSend)(folder, sel(@selector(setTemporaryResourceValue:forKey:)), @2, @"org.charon.second");
    read(folder, @"org.charon.first");
    read(folder, @"org.charon.second");
    read(folder, @"org.charon.unset");
    [events addObject:[NSString stringWithFormat:@"values %@", [[folder resourceValuesForKeys:@[@"org.charon.first", @"org.charon.second"] error:&error] description]]];
    ((void (*)(id, SEL, id))objc_msgSend)(folder, sel(@selector(removeCachedResourceValueForKey:)), @"org.charon.first");
    read(folder, @"org.charon.first");
    read(folder, @"org.charon.second");
    ((void (*)(id, SEL, id, id))objc_msgSend)(folder, sel(@selector(setTemporaryResourceValue:forKey:)), nil, @"org.charon.second");
    read(folder, @"org.charon.second");
    ((void (*)(id, SEL, id, id))objc_msgSend)(folder, sel(@selector(setTemporaryResourceValue:forKey:)), @"three", @"org.charon.third");
    ((void (*)(id, SEL))objc_msgSend)(folder, sel(@selector(removeAllCachedResourceValues)));
    read(folder, @"org.charon.third");
    read(folder, NSURLIsDirectoryKey);
    NSURL *copy = [folder copy];
    ((void (*)(id, SEL, id, id))objc_msgSend)(folder, sel(@selector(setTemporaryResourceValue:forKey:)), @"four", @"org.charon.fourth");
    read(copy, @"org.charon.fourth");
    read([NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES], @"org.charon.fourth");
    [recorder record:events named:@"url.resourceCache"];
    value = nil;
    NSMutableArray *keys = [NSMutableArray array];
    for (NSString *key in foundation2_implementation.ubiquityKeys)
        [keys addObject:key];
    [recorder record:keys named:@"url.ubiquityKeys"];

    progress(@"url.relativeDirectory");
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-url-relative"];
    [manager removeItemAtPath:root error:NULL];
    [manager createDirectoryAtPath:[root stringByAppendingPathComponent:@"folder"] withIntermediateDirectories:YES attributes:nil error:NULL];
    [manager createDirectoryAtPath:[root stringByAppendingPathComponent:@"folder/inner"] withIntermediateDirectories:YES attributes:nil error:NULL];
    [manager createDirectoryAtPath:[root stringByAppendingPathComponent:@"~/inner"] withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"x" writeToFile:[root stringByAppendingPathComponent:@"file.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [manager createSymbolicLinkAtPath:[root stringByAppendingPathComponent:@"link"] withDestinationPath:@"folder" error:NULL];
    [manager createSymbolicLinkAtPath:[root stringByAppendingPathComponent:@"broken"] withDestinationPath:@"nowhere" error:NULL];
    NSURL *anchor = [NSURL fileURLWithPath:root isDirectory:YES];
    NSMutableArray *relatives = [NSMutableArray array];
    for (NSString *name in @[@"folder", @"file.txt", @"missing", @"folder/", @"link", @"link/inner", @"broken", @"~/inner", @"folder/../folder"]) {
        progress([@"url.relativeDirectory." stringByAppendingString:name]);
        NSURL *made = ((F2InitObjectObject)objc_msgSend)([NSURL alloc], sel(@selector(initFileURLWithPath:relativeToURL:)), name, anchor);
        [relatives addObject:[NSString stringWithFormat:@"%@|%@", made.relativeString ?: @"<nil>", made.hasDirectoryPath ? @"directory" : @"file"]];
    }
    [recorder record:relatives named:@"url.relativeDirectory"];
    [manager removeItemAtPath:root error:NULL];
}

static NSOperatingSystemVersion system_version(void)
{
    if (!foundation2_prefix.length)
        return [NSProcessInfo processInfo].operatingSystemVersion;
    return ((NSOperatingSystemVersion (*)(id, SEL))objc_msgSend)([NSProcessInfo processInfo], sel(@selector(operatingSystemVersion)));
}

static void run_process_info(Foundation2Recorder *recorder)
{
    NSProcessInfo *info = [NSProcessInfo processInfo];
    NSOperatingSystemVersion current = system_version();
    NSMutableArray *answers = [NSMutableArray array];
    NSInteger deltas[] = {-1, 0, 1};
    for (int major = 0; major < 3; major++) {
        for (int minor = 0; minor < 3; minor++) {
            for (int patch = 0; patch < 3; patch++) {
                NSOperatingSystemVersion asked = {current.majorVersion + deltas[major], current.minorVersion + deltas[minor], current.patchVersion + deltas[patch]};
                [answers addObject:@(((BOOL (*)(id, SEL, NSOperatingSystemVersion))objc_msgSend)(info, sel(@selector(isOperatingSystemAtLeastVersion:)), asked))];
            }
        }
    }
    NSOperatingSystemVersion zero = {0, 0, 0}, huge = {NSIntegerMax, 0, 0}, negative = {current.majorVersion, -5, 99};
    [answers addObject:@(((BOOL (*)(id, SEL, NSOperatingSystemVersion))objc_msgSend)(info, sel(@selector(isOperatingSystemAtLeastVersion:)), zero))];
    [answers addObject:@(((BOOL (*)(id, SEL, NSOperatingSystemVersion))objc_msgSend)(info, sel(@selector(isOperatingSystemAtLeastVersion:)), huge))];
    [answers addObject:@(((BOOL (*)(id, SEL, NSOperatingSystemVersion))objc_msgSend)(info, sel(@selector(isOperatingSystemAtLeastVersion:)), negative))];
    [recorder record:answers named:@"processInfo.atLeast"];
    NSMutableArray *events = [NSMutableArray array];
    SEL begin = sel(@selector(beginActivityWithOptions:reason:)), end = sel(@selector(endActivity:)), perform = sel(@selector(performActivityWithOptions:reason:usingBlock:));
    static const uint64_t options[] = {0, NSActivityBackground, NSActivityUserInitiated, NSActivityUserInitiatedAllowingIdleSystemSleep, NSActivityLatencyCritical, NSActivityIdleDisplaySleepDisabled, 1ULL << 60};
    for (size_t index = 0; index < sizeof options / sizeof *options; index++) {
        uint64_t option = options[index];
        [events addObject:exception_name(^{
            id token = ((id (*)(id, SEL, uint64_t, id))objc_msgSend)(info, begin, option, @"backport test");
            [events addObject:[NSString stringWithFormat:@"token %d conforms=%d", token != nil, [token conformsToProtocol:@protocol(NSObject)]]];
            ((void (*)(id, SEL, id))objc_msgSend)(info, end, token);
        })];
    }
    [events addObject:exception_name(^{
        id token = ((id (*)(id, SEL, uint64_t, id))objc_msgSend)(info, begin, NSActivityBackground, nil);
        [events addObject:[NSString stringWithFormat:@"nil reason token %d", token != nil]];
    })];
    [events addObject:exception_name(^{
        id token = ((id (*)(id, SEL, uint64_t, id))objc_msgSend)(info, begin, NSActivityBackground, @"");
        [events addObject:[NSString stringWithFormat:@"empty reason token %d", token != nil]];
    })];
    [events addObject:exception_name(^{ ((void (*)(id, SEL, id))objc_msgSend)(info, end, nil); })];
    [events addObject:exception_name(^{ ((void (*)(id, SEL, id))objc_msgSend)(info, end, @"not an activity"); })];
    __block int ran = 0;
    void (^body)(void) = ^{
        ran++;
    };
    [events addObject:exception_name(^{ ((void (*)(id, SEL, uint64_t, id, id))objc_msgSend)(info, perform, NSActivityUserInitiated, @"perform", body); })];
    [events addObject:[NSString stringWithFormat:@"ran %d", ran]];
    [events addObject:exception_name(^{ ((void (*)(id, SEL, uint64_t, id, id))objc_msgSend)(info, perform, NSActivityUserInitiated, nil, body); })];
    [events addObject:exception_name(^{ ((void (*)(id, SEL, uint64_t, id, id))objc_msgSend)(info, perform, NSActivityUserInitiated, @"", body); })];
    [events addObject:[NSString stringWithFormat:@"ran %d", ran]];
    [recorder record:events named:@"processInfo.activity"];
}

static NSRange standard_range(NSString *string, NSString *search)
{
    if (!foundation2_prefix.length)
        return [string localizedStandardRangeOfString:search];
    return ((NSRange (*)(id, SEL, id))objc_msgSend)(string, sel(@selector(localizedStandardRangeOfString:)), search);
}

static void run_strings(Foundation2Recorder *recorder)
{
    NSArray *subjects = @[@"", @"hello world", @"Straße ÉCOLE ﬁ ǅ ıi Ⅻ ＡＢＣ", @"crème brûlée", @"Σίσυφος ΟΔΟΣ",
                          @"İstanbul ijssel", @"mcdonald's o'neil", @"123abc 4th", @"\U0001F600 emoji ß"];
    for (NSUInteger index = 0; index < subjects.count; index++) {
        NSString *subject = subjects[index];
        [recorder record:@[((id (*)(id, SEL))objc_msgSend)(subject, sel(@selector(localizedUppercaseString))), ((id (*)(id, SEL))objc_msgSend)(subject, sel(@selector(localizedLowercaseString))),
                           ((id (*)(id, SEL))objc_msgSend)(subject, sel(@selector(localizedCapitalizedString)))]
                   named:[NSString stringWithFormat:@"string.case.%lu", (unsigned long)index]];
    }
    NSArray *searches = @[@[@"Crème Brûlée", @"BRULEE"], @[@"Crème Brûlée", @"cafe"], @[@"Crème Brûlée ＣＡＦＥ", @"cafe"], @[@"abc", @""], @[@"", @""],
                          @[@"Straße", @"STRASSE"], @[@"näive", @"naïve"], @[@"Ångström", @"angstrom"], @[@"xİy", @"i"], @[@"あア", @"ア"], @[@"ABC", @"abcd"], @[@"a-b", @"a‐b"]];
    for (NSUInteger index = 0; index < searches.count; index++) {
        NSString *subject = searches[index][0], *search = searches[index][1];
        NSRange range = standard_range(subject, search);
        BOOL contains = ((BOOL (*)(id, SEL, id))objc_msgSend)(subject, sel(@selector(localizedStandardContainsString:)), search);
        BOOL plain = ((BOOL (*)(id, SEL, id))objc_msgSend)(subject, sel(@selector(containsString:)), search);
        BOOL insensitive = ((BOOL (*)(id, SEL, id))objc_msgSend)(subject, sel(@selector(localizedCaseInsensitiveContainsString:)), search);
        [recorder record:@[@(range.location), @(range.length), @(contains), @(plain), @(insensitive)] named:[NSString stringWithFormat:@"string.search.%lu", (unsigned long)index]];
    }
    [recorder record:foundation2_implementation.transformNames named:@"string.transform.names"];
    NSArray *texts = @[@"hello", @"héllo wörld", @"ひらがな", @"中文", @"ＡＢＣ", @"&#x68;ello", @"\\N{LATIN SMALL LETTER A}", @"Привет", @""];
    NSMutableArray *transforms = [foundation2_implementation.transformNames mutableCopy];
    [transforms addObject:@"Any-Latin; Latin-ASCII"];
    [transforms addObject:@"Bogus-Transform"];
    [transforms addObject:@"Hex-Any"];
    for (NSUInteger text = 0; text < texts.count; text++) {
        for (NSUInteger transform = 0; transform < transforms.count; transform++) {
            NSMutableArray *results = [NSMutableArray array];
            for (int reverse = 0; reverse < 2; reverse++)
                [results addObject:((id (*)(id, SEL, id, BOOL))objc_msgSend)(texts[text], sel(@selector(stringByApplyingTransform:reverse:)), transforms[transform], reverse) ?: @"<nil>"];
            NSMutableString *mutable = [NSMutableString stringWithFormat:@"<<%@>>", texts[text]];
            NSRange updated = NSMakeRange(99, 99);
            BOOL applied = ((BOOL (*)(id, SEL, id, BOOL, NSRange, NSRangePointer))objc_msgSend)(mutable, sel(@selector(applyTransform:reverse:range:updatedRange:)), transforms[transform], NO, NSMakeRange(2, [texts[text] length]), &updated);
            [results addObject:[NSString stringWithFormat:@"%d %@ %lu %lu", applied, mutable, (unsigned long)updated.location, (unsigned long)updated.length]];
            [recorder record:results named:[NSString stringWithFormat:@"string.transform.%lu.%lu", (unsigned long)text, (unsigned long)transform]];
        }
    }
}

static void run_expression(Foundation2Recorder *recorder)
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"value > 10"];
    NSExpression *expression = ((id (*)(id, SEL, id, id, id))objc_msgSend)([NSExpression class], sel(@selector(expressionForConditional:trueExpression:falseExpression:)), predicate,
                                                                          [NSExpression expressionForConstantValue:@"big"], [NSExpression expressionForKeyPath:@"name"]);
    NSMutableArray *facts = [NSMutableArray array];
    [facts addObject:@(expression.expressionType)];
    [facts addObject:expression.description];
    [facts addObject:[expression predicate].predicateFormat ?: @"<nil>"];
    [facts addObject:[expression trueExpression].description ?: @"<nil>"];
    [facts addObject:[expression falseExpression].description ?: @"<nil>"];
    [facts addObject:[expression expressionValueWithObject:@{@"value": @20, @"name": @"n1"} context:nil] ?: @"<nil>"];
    [facts addObject:[expression expressionValueWithObject:@{@"value": @5, @"name": @"n2"} context:nil] ?: @"<nil>"];
    NSExpression *parsed = [NSExpression expressionWithFormat:@"TERNARY(value > 10, 'big', name)"];
    [facts addObject:@([parsed isEqual:expression])];
    [facts addObject:@([[expression copy] isEqual:expression])];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:expression];
    NSExpression *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    [facts addObject:unarchived.description ?: @"<nil>"];
    [facts addObject:@([unarchived isEqual:expression])];
    NSPredicate *uses = [NSPredicate predicateWithFormat:@"%@ == 'big'", expression];
    [facts addObject:uses.predicateFormat];
    [facts addObject:@([uses evaluateWithObject:@{@"value": @11}])];
    [facts addObject:@([uses evaluateWithObject:@{@"value": @1, @"name": @"small"}])];
    NSPredicate *substituted = [[NSPredicate predicateWithFormat:@"TERNARY($limit < value, 'x', 'y') == 'x'"] predicateWithSubstitutionVariables:@{@"limit": @3}];
    [facts addObject:substituted.predicateFormat];
    [facts addObject:@([substituted evaluateWithObject:@{@"value": @4}])];
    [recorder record:facts named:@"expression.conditional"];
}

static void run_autorelease(Foundation2Recorder *recorder)
{
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    NSMutableArray *counts = [NSMutableArray array];
    CFRetain(array);
    [counts addObject:@(CFGetRetainCount(array))];
    @autoreleasepool {
        CFTypeRef returned = foundation2_implementation.autorelease(array);
        [counts addObject:@(returned == array)];
        [counts addObject:@(CFGetRetainCount(array))];
    }
    [counts addObject:@(CFGetRetainCount(array))];
    CFRelease(array);
    [recorder record:counts named:@"autorelease.counts"];
    [recorder record:foundation2_implementation.rootObjectKey named:@"archiver.rootObjectKey"];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:[NSMutableData data]];
    [archiver encodeObject:@"payload" forKey:foundation2_implementation.rootObjectKey];
    [archiver finishEncoding];
}


static NSString *date_text(NSDate *date)
{
    if (!date)
        return @"<nil>";
    return [NSString stringWithFormat:@"%.6f", date.timeIntervalSinceReferenceDate];
}

static NSString *components_text(NSDateComponents *components)
{
    if (!components)
        return @"<nil>";
    NSMutableArray *fields = [NSMutableArray array];
    NSInteger values[] = {components.era, components.year, components.month, components.day, components.hour, components.minute, components.second, components.nanosecond,
                          components.weekday, components.weekdayOrdinal, components.weekOfMonth, components.weekOfYear, components.yearForWeekOfYear};
    static const char *names[] = {"era", "year", "month", "day", "hour", "minute", "second", "nanosecond", "weekday", "weekdayOrdinal", "weekOfMonth", "weekOfYear", "yearForWeekOfYear"};
    for (size_t index = 0; index < sizeof values / sizeof *values; index++) {
        if (values[index] != NSDateComponentUndefined)
            [fields addObject:[NSString stringWithFormat:@"%s=%ld", names[index], (long)values[index]]];
    }
    if (components.timeZone)
        [fields addObject:[@"timeZone=" stringByAppendingString:components.timeZone.name]];
    if (components.calendar)
        [fields addObject:[@"calendar=" stringByAppendingString:components.calendar.calendarIdentifier]];
    [fields addObject:[NSString stringWithFormat:@"leapMonth=%d", components.isLeapMonth]];
    return [fields componentsJoinedByString:@" "];
}

static NSArray *calendar_setups(void)
{
    NSArray *identifiers = @[NSCalendarIdentifierGregorian, NSCalendarIdentifierBuddhist];
    NSArray *zones = @[@"UTC", @"America/New_York", @"Europe/Berlin", @"Asia/Tokyo", @"Asia/Kolkata", @"Australia/Sydney"];
    NSArray *locales = @[@"en_US", @"de_DE", @"he_IL", @"en_GB"];
    NSMutableArray *setups = [NSMutableArray array];
    for (NSUInteger index = 0; index < 14; index++) {
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:identifiers[index % identifiers.count]];
        calendar.timeZone = [NSTimeZone timeZoneWithName:zones[index % zones.count]];
        calendar.locale = [NSLocale localeWithLocaleIdentifier:locales[index % locales.count]];
        if (calendar)
            [setups addObject:calendar];
    }
    return setups;
}

static NSArray *calendar_dates(void)
{
    NSMutableArray *dates = [NSMutableArray array];
    double fixed[] = {0.0, 1.5, -1.5, 100000000.25, 384593400.0, 315532800.123456789, -978307200.0, 68169600.0, 341884800.0, 342000000.75, 351993600.0, 63072000.0};
    for (size_t index = 0; index < sizeof fixed / sizeof *fixed; index++)
        [dates addObject:[NSDate dateWithTimeIntervalSinceReferenceDate:fixed[index]]];
    random_state = 0x1234567u;
    for (int round = 0; round < 40; round++) {
        double seconds = (double)(next_random() % 1100000000) - 780000000.0;
        [dates addObject:[NSDate dateWithTimeIntervalSinceReferenceDate:seconds]];
    }
    return dates;
}

static const NSCalendarUnit calendar_units[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
                                                NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitQuarter, NSCalendarUnitWeekOfMonth, NSCalendarUnitWeekOfYear,
                                                NSCalendarUnitYearForWeekOfYear, NSCalendarUnitNanosecond, NSCalendarUnitCalendar, NSCalendarUnitTimeZone,
                                                NSCalendarUnitYear | NSCalendarUnitMonth, 0};

/*
 * -nextDateAfterDate:'s backwardMatch, on a day search whose day already ties the date's own, in
 * New York or Sydney, for exactly these (setup, date) pairs: the host's own answer, not the
 * backport's, is a fixed unrelated date (probed directly against the system class - see
 * facts/Foundation/NSCalendar.md, "Setting a unit, and searching for one"). Named exactly, not by
 * a year boundary, so a host that starts answering these correctly turns into a plain pass, and a
 * host that answers a *different* wrong value here still shows up as newly tolerated instead of
 * silently matching.
 */
static BOOL calendar_known_host_nextmatch_quirk(NSUInteger setupIndex, NSUInteger dateIndex)
{
    static const NSUInteger pairs[][2] = {{1, 18}, {1, 22}, {1, 27}, {1, 32}, {1, 51}, {5, 7}, {7, 18}, {7, 22}, {7, 27}, {7, 32}, {7, 51}, {11, 7}, {13, 18}, {13, 22}, {13, 27}, {13, 32}, {13, 51}};
    for (size_t index = 0; index < sizeof pairs / sizeof *pairs; index++) {
        if (pairs[index][0] == setupIndex && pairs[index][1] == dateIndex)
            return YES;
    }
    return NO;
}

static void run_calendar(Foundation2Recorder *recorder)
{
    NSArray *setups = calendar_setups();
    NSArray *dates = calendar_dates();
    for (NSUInteger setupIndex = 0; setupIndex < setups.count; setupIndex++) {
        NSCalendar *calendar = setups[setupIndex];
        NSString *prefix = [NSString stringWithFormat:@"calendar.%lu", (unsigned long)setupIndex];
        progress(prefix);
        [recorder record:[NSString stringWithFormat:@"%@ %@ %@", calendar.calendarIdentifier, calendar.timeZone.name, calendar.locale.localeIdentifier] named:[prefix stringByAppendingString:@".setup"]];
        for (NSUInteger dateIndex = 0; dateIndex < dates.count; dateIndex++) {
            NSDate *date = dates[dateIndex];
            NSMutableArray *values = [NSMutableArray array];
            for (size_t unit = 0; unit < sizeof calendar_units / sizeof *calendar_units; unit++) {
                NSInteger value = ((NSInteger (*)(id, SEL, NSCalendarUnit, id))objc_msgSend)(calendar, sel(@selector(component:fromDate:)), calendar_units[unit], date);
                if (calendar_units[unit] == NSCalendarUnitQuarter)
                    [recorder record:@(value) named:[NSString stringWithFormat:@"%@.quarter.%lu", prefix, (unsigned long)dateIndex]
                          tolerating:@"macOS 27 reports the quarter of the following day on the last day of a quarter"];
                else
                    [values addObject:@(value)];
            }
            [recorder record:values named:[NSString stringWithFormat:@"%@.component.%lu", prefix, (unsigned long)dateIndex]];
            NSInteger era = -1, year = -1, month = -1, day = -1;
            ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(calendar, sel(@selector(getEra:year:month:day:fromDate:)), &era, &year, &month, &day, date);
            NSInteger weekEra = -1, weekYear = -1, week = -1, weekday = -1;
            ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(calendar, sel(@selector(getEra:yearForWeekOfYear:weekOfYear:weekday:fromDate:)), &weekEra, &weekYear, &week, &weekday, date);
            NSInteger hour = -1, minute = -1, second = -1, nanosecond = -1;
            ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(calendar, sel(@selector(getHour:minute:second:nanosecond:fromDate:)), &hour, &minute, &second, &nanosecond, date);
            [recorder record:@[@(era), @(year), @(month), @(day), @(weekEra), @(weekYear), @(week), @(weekday), @(hour), @(minute), @(second), @(nanosecond)]
                       named:[NSString stringWithFormat:@"%@.get.%lu", prefix, (unsigned long)dateIndex]];
            NSDate *start = ((id (*)(id, SEL, id))objc_msgSend)(calendar, sel(@selector(startOfDayForDate:)), date);
            NSDateComponents *inZone = ((id (*)(id, SEL, id, id))objc_msgSend)(calendar, sel(@selector(componentsInTimeZone:fromDate:)), [NSTimeZone timeZoneWithName:@"Asia/Kolkata"], date);
            [recorder record:@(inZone.quarter) named:[NSString stringWithFormat:@"%@.zoneQuarter.%lu", prefix, (unsigned long)dateIndex]
                  tolerating:@"macOS 27 reports the quarter of the following day on the last day of a quarter"];
            NSDate *made = ((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger))objc_msgSend)(calendar, sel(@selector(dateWithEra:year:month:day:hour:minute:second:nanosecond:)), era, year, month, day, hour, minute, second, 250000000);
            NSDate *madeWeek = ((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger))objc_msgSend)(calendar, sel(@selector(dateWithEra:yearForWeekOfYear:weekOfYear:weekday:hour:minute:second:nanosecond:)), weekEra, weekYear, week, weekday, hour, minute, second, 0);
            NSDate *setHour = ((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), 3, 45, 15, date, 0);
            [recorder record:@[date_text(start), components_text(inZone), date_text(made), date_text(madeWeek), date_text(setHour)] named:[NSString stringWithFormat:@"%@.derived.%lu", prefix, (unsigned long)dateIndex]];
            NSMutableArray *added = [NSMutableArray array];
            NSInteger amounts[] = {1, -1, 45, -20};
            for (size_t unit = 0; unit < sizeof calendar_units / sizeof *calendar_units; unit++) {
                NSInteger amount = amounts[(dateIndex + unit) % 4];
                NSDate *result = ((id (*)(id, SEL, NSCalendarUnit, NSInteger, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(dateByAddingUnit:value:toDate:options:)), calendar_units[unit], amount, date, unit % 3 == 0 ? NSCalendarWrapComponents : 0);
                [added addObject:date_text(result)];
            }
            [recorder record:added named:[NSString stringWithFormat:@"%@.added.%lu", prefix, (unsigned long)dateIndex]];
            NSDate *other = dates[(dateIndex + 5) % dates.count];
            NSMutableArray *compared = [NSMutableArray array];
            for (size_t unit = 0; unit < sizeof calendar_units / sizeof *calendar_units; unit++) {
                NSComparisonResult order = ((NSComparisonResult (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(calendar, sel(@selector(compareDate:toDate:toUnitGranularity:)), date, other, calendar_units[unit]);
                BOOL equal = ((BOOL (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(calendar, sel(@selector(isDate:equalToDate:toUnitGranularity:)), date, other, calendar_units[unit]);
                [compared addObject:[NSString stringWithFormat:@"%ld%d", (long)order, equal]];
            }
            [compared addObject:@(((BOOL (*)(id, SEL, id, id))objc_msgSend)(calendar, sel(@selector(isDate:inSameDayAsDate:)), date, other))];
            [compared addObject:@(((BOOL (*)(id, SEL, id, id))objc_msgSend)(calendar, sel(@selector(isDate:inSameDayAsDate:)), date, [date dateByAddingTimeInterval:3600]))];
            [recorder record:compared named:[NSString stringWithFormat:@"%@.compared.%lu", prefix, (unsigned long)dateIndex]];
            NSDate *weekendStart = nil;
            NSTimeInterval weekendInterval = 0;
            BOOL inWeekend = ((BOOL (*)(id, SEL, id))objc_msgSend)(calendar, sel(@selector(isDateInWeekend:)), date);
            BOOL ranged = ((BOOL (*)(id, SEL, NSDate **, NSTimeInterval *, id))objc_msgSend)(calendar, sel(@selector(rangeOfWeekendStartDate:interval:containingDate:)), &weekendStart, &weekendInterval, date);
            NSDate *nextStart = nil, *previousStart = nil;
            NSTimeInterval nextInterval = 0, previousInterval = 0;
            BOOL nextFound = ((BOOL (*)(id, SEL, NSDate **, NSTimeInterval *, NSCalendarOptions, id))objc_msgSend)(calendar, sel(@selector(nextWeekendStartDate:interval:options:afterDate:)), &nextStart, &nextInterval, 0, date);
            BOOL previousFound = ((BOOL (*)(id, SEL, NSDate **, NSTimeInterval *, NSCalendarOptions, id))objc_msgSend)(calendar, sel(@selector(nextWeekendStartDate:interval:options:afterDate:)), &previousStart, &previousInterval, NSCalendarSearchBackwards, date);
            [recorder record:@[@(inWeekend), @(ranged), date_text(weekendStart), @(weekendInterval), @(nextFound), date_text(nextStart), @(nextInterval), @(previousFound), date_text(previousStart), @(previousInterval)]
                       named:[NSString stringWithFormat:@"%@.weekend.%lu", prefix, (unsigned long)dateIndex]];
            NSDateComponents *matching = [[NSDateComponents alloc] init];
            matching.day = day;
            matching.hour = hour;
            NSDateComponents *mismatching = [[NSDateComponents alloc] init];
            mismatching.month = month;
            mismatching.minute = (minute + 1) % 60;
            [recorder record:@[@(((BOOL (*)(id, SEL, id, id))objc_msgSend)(calendar, sel(@selector(date:matchesComponents:)), date, matching)),
                               @(((BOOL (*)(id, SEL, id, id))objc_msgSend)(calendar, sel(@selector(date:matchesComponents:)), date, mismatching))]
                       named:[NSString stringWithFormat:@"%@.matches.%lu", prefix, (unsigned long)dateIndex]];
            NSMutableArray *setUnit = [NSMutableArray array];
            NSCalendarUnit settingUnits[] = {NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitWeekday};
            NSInteger settingValues[] = {year + 1, ((month + 3) % 12) + 1, ((day + 10) % 25) + 1, (hour + 5) % 24, (minute + 15) % 60, ((weekday + 2) % 7) + 1};
            for (size_t index = 0; index < sizeof settingUnits / sizeof *settingUnits; index++) {
                for (int strict = 0; strict < 2; strict++) {
                    NSDate *result = ((id (*)(id, SEL, NSCalendarUnit, NSInteger, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(dateBySettingUnit:value:ofDate:options:)),
                                                                                                                       settingUnits[index], settingValues[index], date, strict ? NSCalendarMatchStrictly : 0);
                    [setUnit addObject:date_text(result)];
                }
            }
            [recorder record:setUnit named:[NSString stringWithFormat:@"%@.settingUnit.%lu", prefix, (unsigned long)dateIndex]];
            NSDate *forwardMatch = ((id (*)(id, SEL, id, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(nextDateAfterDate:matchingComponents:options:)), date, matching, 0);
            NSDate *backwardMatch = ((id (*)(id, SEL, id, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(nextDateAfterDate:matchingComponents:options:)), date, matching, NSCalendarSearchBackwards);
            NSDate *strictMatch = ((id (*)(id, SEL, id, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(nextDateAfterDate:matchingComponents:options:)), date, matching, NSCalendarMatchStrictly);
            NSDate *noMatch = ((id (*)(id, SEL, id, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(nextDateAfterDate:matchingComponents:options:)), date, mismatching, 0);
            [recorder record:@[date_text(forwardMatch), date_text(backwardMatch), date_text(strictMatch), date_text(noMatch)]
                       named:[NSString stringWithFormat:@"%@.nextMatch.%lu", prefix, (unsigned long)dateIndex]
                  tolerating:calendar_known_host_nextmatch_quirk(setupIndex, dateIndex) ? @"a backward day-tie search in New York or Sydney before a year the host does not name answers a fixed, unrelated date on the host itself, independent of the backport" : nil];
            NSMutableArray *enumerated = [NSMutableArray array];
            ((void (*)(id, SEL, id, id, NSCalendarOptions, void (^)(NSDate *, BOOL, BOOL *)))objc_msgSend)(calendar, sel(@selector(enumerateDatesStartingAfterDate:matchingComponents:options:usingBlock:)),
                                                                                                            date, matching, 0, ^(NSDate *found, BOOL exact, BOOL *stop) {
                [enumerated addObject:[NSString stringWithFormat:@"%@|%d", date_text(found), exact]];
                if (enumerated.count >= 3)
                    *stop = YES;
            });
            [recorder record:enumerated named:[NSString stringWithFormat:@"%@.enumerate.%lu", prefix, (unsigned long)dateIndex]];
            NSDateComponents *whole = [[NSDateComponents alloc] init];
            whole.year = year;
            whole.month = month;
            whole.day = day;
            whole.calendar = calendar;
            NSDateComponents *broken = [[NSDateComponents alloc] init];
            broken.year = year;
            broken.month = 2;
            broken.day = 31;
            broken.calendar = calendar;
            [recorder record:@[@(((BOOL (*)(id, SEL))objc_msgSend)(whole, sel(@selector(isValidDate)))), @(((BOOL (*)(id, SEL))objc_msgSend)(broken, sel(@selector(isValidDate)))),
                               @(((BOOL (*)(id, SEL, id))objc_msgSend)(whole, sel(@selector(isValidDateInCalendar:)), calendar))]
                       named:[NSString stringWithFormat:@"%@.valid.%lu", prefix, (unsigned long)dateIndex]];
            NSDateComponents *from = [[NSDateComponents alloc] init];
            from.year = year;
            from.month = month;
            NSDateComponents *to = [[NSDateComponents alloc] init];
            to.year = year + 1;
            to.month = month;
            to.day = 5;
            NSDateComponents *difference = ((id (*)(id, SEL, NSCalendarUnit, id, id, NSCalendarOptions))objc_msgSend)(calendar, sel(@selector(components:fromDateComponents:toDateComponents:options:)),
                                                                                                                      NSCalendarUnitMonth | NSCalendarUnitDay, from, to, 0);
            [recorder record:components_text(difference) named:[NSString stringWithFormat:@"%@.difference.%lu", prefix, (unsigned long)dateIndex]];
        }
    }
    NSCalendar *identified = ((id (*)(id, SEL, id))objc_msgSend)([NSCalendar class], sel(@selector(calendarWithIdentifier:)), NSCalendarIdentifierIslamicCivil);
    NSCalendar *unknown = ((id (*)(id, SEL, id))objc_msgSend)([NSCalendar class], sel(@selector(calendarWithIdentifier:)), @"org.charon.unknown");
    [recorder record:@[identified.calendarIdentifier ?: @"<nil>", unknown ? @"unexpected" : @"<nil>"] named:@"calendar.identifier"];
    NSCalendar *shifting = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    shifting.timeZone = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
    shifting.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    NSDateComponents *forward = [[NSDateComponents alloc] init];
    forward.year = 2026;
    forward.month = 3;
    forward.day = 29;
    forward.hour = 12;
    NSDate *jumpDay = [shifting dateFromComponents:forward];
    NSDate *(*setting)(id, SEL, NSInteger, NSInteger, NSInteger, id, NSCalendarOptions) = (NSDate *(*)(id, SEL, NSInteger, NSInteger, NSInteger, id, NSCalendarOptions))objc_msgSend;
    [recorder record:@[date_text(((id (*)(id, SEL, id))objc_msgSend)(shifting, sel(@selector(startOfDayForDate:)), jumpDay)),
                       date_text(setting(shifting, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), 2, 30, 0, jumpDay, 0)),
                       date_text(setting(shifting, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), 2, 30, 0, jumpDay, NSCalendarMatchStrictly)),
                       date_text(setting(shifting, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), 2, 30, 0, jumpDay, NSCalendarMatchNextTime))]
               named:@"calendar.clockJump"];
    NSDate *noon = setting(shifting, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), 12, 0, 0, jumpDay, 0);
    NSDate *evening = setting(shifting, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), 20, 0, 0, jumpDay, 0);
    NSCalendarUnit granularities[] = {NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitDay | NSCalendarUnitHour, NSCalendarUnitCalendar, NSCalendarUnitTimeZone};
    NSMutableArray *granular = [NSMutableArray array];
    for (size_t index = 0; index < sizeof granularities / sizeof *granularities; index++) {
        [granular addObject:@(((BOOL (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(shifting, sel(@selector(isDate:equalToDate:toUnitGranularity:)), noon, evening, granularities[index]))];
        [granular addObject:@(((NSComparisonResult (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(shifting, sel(@selector(compareDate:toDate:toUnitGranularity:)), noon, evening, granularities[index]))];
    }
    [recorder record:granular named:@"calendar.granularity"];
    for (NSString *identifier in @[@"en_US_POSIX", @"he_IL"]) {
        NSCalendar *weekly = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        weekly.timeZone = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        weekly.locale = [NSLocale localeWithLocaleIdentifier:identifier];
        NSDate *start = nil;
        NSTimeInterval interval = 0;
        BOOL found = ((BOOL (*)(id, SEL, NSDate **, NSTimeInterval *, NSCalendarOptions, id))objc_msgSend)(weekly, sel(@selector(nextWeekendStartDate:interval:options:afterDate:)), &start, &interval, 0, jumpDay);
        [recorder record:@[@(found), date_text(start), @(interval)] named:[@"calendar.weekend." stringByAppendingString:identifier]];
    }
    NSCalendar *today = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *now = [NSDate date];
    [recorder record:@[@(((BOOL (*)(id, SEL, id))objc_msgSend)(today, sel(@selector(isDateInToday:)), now)),
                       @(((BOOL (*)(id, SEL, id))objc_msgSend)(today, sel(@selector(isDateInYesterday:)), [now dateByAddingTimeInterval:-86400])),
                       @(((BOOL (*)(id, SEL, id))objc_msgSend)(today, sel(@selector(isDateInTomorrow:)), [now dateByAddingTimeInterval:86400])),
                       @(((BOOL (*)(id, SEL, id))objc_msgSend)(today, sel(@selector(isDateInToday:)), [now dateByAddingTimeInterval:-86400 * 3])),
                       @(((BOOL (*)(id, SEL, id))objc_msgSend)(today, sel(@selector(isDateInYesterday:)), now)),
                       @(((BOOL (*)(id, SEL, id))objc_msgSend)(today, sel(@selector(isDateInTomorrow:)), now))]
               named:@"calendar.relativeDays"];
}


static NSString *error_text(NSError *error)
{
    if (!error)
        return @"<nil>";
    return [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code];
}

static NSDateComponents *validity_components(NSInteger year, NSInteger month, NSInteger day, NSCalendar *calendar)
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    if (year != NSDateComponentUndefined)
        components.year = year;
    if (month != NSDateComponentUndefined)
        components.month = month;
    if (day != NSDateComponentUndefined)
        components.day = day;
    components.calendar = calendar;
    return components;
}

static void run_validity(Foundation2Recorder *recorder)
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorian.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSInteger u = NSDateComponentUndefined;
    NSInteger cases[][3] = {{2024, 2, 29}, {2023, 2, 29}, {2026, 2, 31}, {2026, 13, 1}, {2026, 0, 1}, {2026, 4, 31}, {2026, 12, 31}, {u, 2, 30}, {2026, u, u}, {u, u, u}, {2026, 5, u}, {1582, 10, 10}, {2026, -1, 5}, {2026, 1, 0}};
    NSMutableArray *rows = [NSMutableArray array];
    for (size_t index = 0; index < sizeof cases / sizeof *cases; index++) {
        NSDateComponents *with = validity_components(cases[index][0], cases[index][1], cases[index][2], gregorian);
        NSDateComponents *without = validity_components(cases[index][0], cases[index][1], cases[index][2], nil);
        [rows addObject:[NSString stringWithFormat:@"%d%d%d%d", ((BOOL (*)(id, SEL))objc_msgSend)(with, sel(@selector(isValidDate))), ((BOOL (*)(id, SEL, id))objc_msgSend)(with, sel(@selector(isValidDateInCalendar:)), gregorian),
                         ((BOOL (*)(id, SEL))objc_msgSend)(without, sel(@selector(isValidDate))), ((BOOL (*)(id, SEL, id))objc_msgSend)(without, sel(@selector(isValidDateInCalendar:)), gregorian)]];
    }
    NSDateComponents *time = [[NSDateComponents alloc] init];
    time.hour = 25;
    time.calendar = gregorian;
    BOOL hour = ((BOOL (*)(id, SEL))objc_msgSend)(time, sel(@selector(isValidDate)));
    time.hour = 23;
    time.minute = 61;
    BOOL minute = ((BOOL (*)(id, SEL))objc_msgSend)(time, sel(@selector(isValidDate)));
    NSDateComponents *week = [[NSDateComponents alloc] init];
    week.year = 2026;
    week.weekOfYear = 53;
    week.calendar = gregorian;
    NSDateComponents *zoned = validity_components(2026, 1, 1, gregorian);
    zoned.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Tokyo"];
    NSCalendar *japanese = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierJapanese];
    NSDateComponents *era = validity_components(5, 1, 1, gregorian);
    era.era = 0;
    [recorder record:@[rows, @(hour), @(minute), @(((BOOL (*)(id, SEL))objc_msgSend)(week, sel(@selector(isValidDate)))), @(((BOOL (*)(id, SEL))objc_msgSend)(zoned, sel(@selector(isValidDate)))),
                       @(((BOOL (*)(id, SEL, id))objc_msgSend)(validity_components(2026, 2, 30, gregorian), sel(@selector(isValidDateInCalendar:)), japanese)), @(((BOOL (*)(id, SEL))objc_msgSend)(era, sel(@selector(isValidDate))))]
               named:@"calendar.edges.validity"];
}

static void run_calendar_edges(Foundation2Recorder *recorder)
{
    NSCalendar *chinese = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierChinese];
    chinese.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDate *notLeap = [NSDate dateWithTimeIntervalSinceReferenceDate:609417600], *leap = [NSDate dateWithTimeIntervalSinceReferenceDate:611923200];
    NSCalendarUnit leapGranularities[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitQuarter, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitWeekOfMonth};
    NSMutableArray *leapCompared = [NSMutableArray array];
    for (size_t index = 0; index < sizeof leapGranularities / sizeof *leapGranularities; index++)
        [leapCompared addObject:@(((NSComparisonResult (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(chinese, sel(@selector(compareDate:toDate:toUnitGranularity:)), notLeap, leap, leapGranularities[index]))];
    [recorder record:leapCompared named:@"calendar.edges.leapMonthCompare"];
    NSCalendar *newYork = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    newYork.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    NSDate *beforeTransition = [NSDate dateWithTimeIntervalSinceReferenceDate:700254000];
    NSMutableArray *dstSet = [NSMutableArray array];
    for (NSInteger hour = 0; hour < 5; hour++)
        [dstSet addObject:date_text(((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, id, NSCalendarOptions))objc_msgSend)(newYork, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), hour, 30, 0, beforeTransition, 0))];
    [recorder record:dstSet named:@"calendar.edges.dstSetting"];

    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorian.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    gregorian.locale = [NSLocale localeWithLocaleIdentifier:@"fa_IR"];
    NSMutableArray *nanoseconds = [NSMutableArray array];
    double instants[] = {0.086, -0.25, -0.086, 710258281.086, 710258281.802, -0.0000000001, 0.9999999999};
    for (size_t index = 0; index < sizeof instants / sizeof *instants; index++) {
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:instants[index]];
        NSInteger hour = -1, minute = -1, second = -1, nanosecond = -1;
        ((void (*)(id, SEL, NSInteger *, NSInteger *, NSInteger *, NSInteger *, id))objc_msgSend)(gregorian, sel(@selector(getHour:minute:second:nanosecond:fromDate:)), &hour, &minute, &second, &nanosecond, date);
        [nanoseconds addObject:@[@(((NSInteger (*)(id, SEL, NSCalendarUnit, id))objc_msgSend)(gregorian, sel(@selector(component:fromDate:)), NSCalendarUnitNanosecond, date)), @(second), @(nanosecond)]];
    }
    [recorder record:nanoseconds named:@"calendar.edges.nanosecond"];
    NSDate *day = [NSDate dateWithTimeIntervalSinceReferenceDate:710258281.086];
    NSInteger times[][3] = {{40, 0, 0}, {2155, 0, 0}, {10, -954, 0}, {10, 0, -860}, {24, 0, 0}, {23, 59, 59}, {-1, 0, 0}, {0, 60, 0}, {0, 0, 60}, {14, 16, 53}, {0, 0, 0}, {3, 1, NSDateComponentUndefined}, {NSDateComponentUndefined, 35, 21}, {2, NSDateComponentUndefined, 30}, {NSDateComponentUndefined, NSDateComponentUndefined, NSDateComponentUndefined}};
    NSMutableArray *settings = [NSMutableArray array];
    for (size_t index = 0; index < sizeof times / sizeof *times; index++) {
        for (int strict = 0; strict < 2; strict++) {
            NSDate *set = ((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, id, NSCalendarOptions))objc_msgSend)(gregorian, sel(@selector(dateBySettingHour:minute:second:ofDate:options:)), times[index][0], times[index][1], times[index][2], day,
                                                                                                         strict ? NSCalendarMatchStrictly : 0);
            [settings addObject:date_text(set)];
        }
    }
    [recorder record:settings named:@"calendar.edges.settingHour"];
    NSDate *first = [NSDate dateWithTimeIntervalSinceReferenceDate:-349434443], *second = [NSDate dateWithTimeIntervalSinceReferenceDate:-349272243];
    NSCalendarUnit granularities[] = {NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitQuarter, NSCalendarUnitMonth, NSCalendarUnitWeekOfYear, NSCalendarUnitWeekOfMonth, NSCalendarUnitYearForWeekOfYear,
                                      NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond, NSCalendarUnitNanosecond};
    NSArray *others = @[second, [first dateByAddingTimeInterval:2 * 86400], [first dateByAddingTimeInterval:40 * 86400], [first dateByAddingTimeInterval:61], [first dateByAddingTimeInterval:0.5]];
    NSMutableArray *comparisons = [NSMutableArray array];
    for (NSDate *other in others) {
        NSMutableString *row = [NSMutableString string];
        for (size_t index = 0; index < sizeof granularities / sizeof *granularities; index++)
            [row appendFormat:@"%ld", (long)((NSComparisonResult (*)(id, SEL, id, id, NSCalendarUnit))objc_msgSend)(gregorian, sel(@selector(compareDate:toDate:toUnitGranularity:)), first, other, granularities[index]) + 1];
        [comparisons addObject:row];
    }
    [recorder record:comparisons named:@"calendar.edges.compare"];
    NSMutableArray *validity = [NSMutableArray array];
    for (NSString *identifier in @[NSCalendarIdentifierGregorian, NSCalendarIdentifierChinese, NSCalendarIdentifierHebrew]) {
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:identifier];
        calendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        NSDateComponents *components = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:day];
        for (int leap = 0; leap < 2; leap++) {
            components.leapMonth = leap;
            [validity addObject:@(((BOOL (*)(id, SEL, id))objc_msgSend)(components, sel(@selector(isValidDateInCalendar:)), calendar))];
        }
    }
    [recorder record:validity named:@"calendar.edges.leapMonthValid" tolerating:@"whether a leap month flag names a real month is the release's ICU, which iOS 6 ignores and macOS 27 checks per calendar"];
    NSCalendarUnit addable[] = {NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitSecond, NSCalendarUnitNanosecond, NSCalendarUnitWeekOfYear};
    NSMutableArray *undefined = [NSMutableArray array];
    for (size_t index = 0; index < sizeof addable / sizeof *addable; index++)
        [undefined addObject:date_text(((id (*)(id, SEL, NSCalendarUnit, NSInteger, id, NSCalendarOptions))objc_msgSend)(gregorian, sel(@selector(dateByAddingUnit:value:toDate:options:)), addable[index], NSDateComponentUndefined, day, 0))];
    [recorder record:undefined named:@"calendar.edges.addUndefined"];
}

static void run_archiving(Foundation2Recorder *recorder)
{
    NSArray *root = @[@"a", @2, [NSDate dateWithTimeIntervalSinceReferenceDate:1000]];
    NSMutableData *written = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:written];
    [archiver encodeObject:root forKey:foundation2_implementation.rootObjectKey];
    [archiver finishEncoding];
    NSError *error = nil;
    NSData *secure = ((id (*)(id, SEL, id, BOOL, NSError **))objc_msgSend)([NSKeyedArchiver class], sel(@selector(archivedDataWithRootObject:requiringSecureCoding:error:)), root, YES, &error);
    [recorder record:@[@(secure != nil), error_text(error)] named:@"archiving.secure"];
    NSError *plainError = nil;
    NSData *plain = ((id (*)(id, SEL, id, BOOL, NSError **))objc_msgSend)([NSKeyedArchiver class], sel(@selector(archivedDataWithRootObject:requiringSecureCoding:error:)), root, NO, &plainError);
    [recorder record:@[@([plain isEqual:written]), error_text(plainError)] named:@"archiving.plain"];
    NSError *badError = nil;
    id opaque = [[NSObject alloc] init];
    NSData *bad = ((id (*)(id, SEL, id, BOOL, NSError **))objc_msgSend)([NSKeyedArchiver class], sel(@selector(archivedDataWithRootObject:requiringSecureCoding:error:)), opaque, YES, &badError);
    [recorder record:@[@(bad != nil), error_text(badError), error_text(badError.userInfo[NSUnderlyingErrorKey])] named:@"archiving.rejected"];
    NSError *readError = nil;
    NSKeyedUnarchiver *reader = ((F2InitDataError)objc_msgSend)([NSKeyedUnarchiver alloc], sel(@selector(initForReadingFromData:error:)), written, &readError);
    [recorder record:@[@(reader != nil), error_text(readError), @(reader.requiresSecureCoding)] named:@"archiving.reader"];
    NSError *junkError = nil;
    NSKeyedUnarchiver *junk = ((F2InitDataError)objc_msgSend)([NSKeyedUnarchiver alloc], sel(@selector(initForReadingFromData:error:)), [@"junk" dataUsingEncoding:NSUTF8StringEncoding], &junkError);
    [recorder record:@[@(junk != nil), error_text(junkError)] named:@"archiving.junkReader"];
    NSError *ofClassError = nil;
    id decoded = ((id (*)(id, SEL, Class, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], sel(@selector(unarchivedObjectOfClass:fromData:error:)), [NSArray class], written, &ofClassError);
    [recorder record:@[decoded ? [decoded description] : @"<nil>", error_text(ofClassError)] named:@"archiving.ofClass"];
    NSError *wrongError = nil;
    id wrong = ((id (*)(id, SEL, Class, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], sel(@selector(unarchivedObjectOfClass:fromData:error:)), [NSString class], written, &wrongError);
    [recorder record:@[@(wrong != nil), error_text(wrongError)] named:@"archiving.wrongClass" tolerating:@"macOS 27 and iOS 6 word the failure of a secure decode differently"];
    NSError *classesError = nil;
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSString class], [NSNumber class], [NSDate class], nil];
    id several = ((id (*)(id, SEL, id, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], sel(@selector(unarchivedObjectOfClasses:fromData:error:)), classes, written, &classesError);
    [recorder record:@[several ? [several description] : @"<nil>", error_text(classesError)] named:@"archiving.ofClasses"];
    NSError *topError = nil;
    id top = ((id (*)(id, SEL, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], sel(@selector(unarchiveTopLevelObjectWithData:error:)), written, &topError);
    [recorder record:@[top ? [top description] : @"<nil>", error_text(topError)] named:@"archiving.topLevel"];
    NSError *topJunkError = nil;
    id topJunk = ((id (*)(id, SEL, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], sel(@selector(unarchiveTopLevelObjectWithData:error:)), [@"junk" dataUsingEncoding:NSUTF8StringEncoding], &topJunkError);
    [recorder record:@[@(topJunk != nil), error_text(topJunkError)] named:@"archiving.topLevelJunk"];
    NSKeyedUnarchiver *legacy = [[NSKeyedUnarchiver alloc] initForReadingWithData:written];
    NSError *keyedError = nil;
    id keyed = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(legacy, sel(@selector(decodeTopLevelObjectForKey:error:)), foundation2_implementation.rootObjectKey, &keyedError);
    [recorder record:@[keyed ? [keyed description] : @"<nil>", error_text(keyedError)] named:@"archiving.decodeTopLevel"];
    NSError *missingError = nil;
    id missing = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(legacy, sel(@selector(decodeTopLevelObjectForKey:error:)), @"org.charon.missing", &missingError);
    [recorder record:@[@(missing != nil), error_text(missingError)] named:@"archiving.decodeMissing"];
    NSError *ofClassKeyError = nil;
    id ofClassKey = ((id (*)(id, SEL, Class, id, NSError **))objc_msgSend)(legacy, sel(@selector(decodeTopLevelObjectOfClass:forKey:error:)), [NSArray class], foundation2_implementation.rootObjectKey, &ofClassKeyError);
    [recorder record:@[ofClassKey ? [ofClassKey description] : @"<nil>", error_text(ofClassKeyError)] named:@"archiving.decodeTopLevelOfClass"];
    NSKeyedUnarchiver *legacyPlain = [[NSKeyedUnarchiver alloc] initForReadingWithData:written];
    NSError *legacyPlainError = nil;
    id legacyPlainDecoded = ((id (*)(id, SEL, NSError **))objc_msgSend)(legacyPlain, sel(@selector(decodeTopLevelObjectAndReturnError:)), &legacyPlainError);
    [recorder record:@[legacyPlainDecoded ? [legacyPlainDecoded description] : @"<nil>", error_text(legacyPlainError)] named:@"archiving.decodeTopLevelPlain"];
    NSKeyedUnarchiver *classesRight = [[NSKeyedUnarchiver alloc] initForReadingWithData:written];
    NSError *classesRightError = nil;
    NSSet *rightClasses = [NSSet setWithObjects:[NSString class], [NSArray class], nil];
    id classesRightDecoded = ((id (*)(id, SEL, id, id, NSError **))objc_msgSend)(classesRight, sel(@selector(decodeTopLevelObjectOfClasses:forKey:error:)), rightClasses, foundation2_implementation.rootObjectKey, &classesRightError);
    [recorder record:@[classesRightDecoded ? [classesRightDecoded description] : @"<nil>", error_text(classesRightError)] named:@"archiving.decodeTopLevelOfClasses"];
    NSKeyedUnarchiver *classesWrong = [[NSKeyedUnarchiver alloc] initForReadingWithData:written];
    NSError *classesWrongError = nil;
    NSSet *wrongClasses = [NSSet setWithObjects:[NSNumber class], [NSDate class], nil];
    id classesWrongDecoded = ((id (*)(id, SEL, id, id, NSError **))objc_msgSend)(classesWrong, sel(@selector(decodeTopLevelObjectOfClasses:forKey:error:)), wrongClasses, foundation2_implementation.rootObjectKey, &classesWrongError);
    [recorder record:@[classesWrongDecoded ? [classesWrongDecoded description] : @"<nil>", error_text(classesWrongError)] named:@"archiving.decodeTopLevelOfClassesWrong"];
    NSKeyedArchiver *requiring = ((F2InitFlag)objc_msgSend)([NSKeyedArchiver alloc], sel(@selector(initRequiringSecureCoding:)), YES);
    [requiring encodeObject:@"payload" forKey:@"key"];
    NSData *produced = ((id (*)(id, SEL))objc_msgSend)(requiring, sel(@selector(encodedData)));
    NSKeyedUnarchiver *back = [[NSKeyedUnarchiver alloc] initForReadingWithData:produced];
    [recorder record:@[@(requiring.requiresSecureCoding), @(produced.length > 0), [back decodeObjectForKey:@"key"] ?: @"<nil>"] named:@"archiving.requiring"];
    NSKeyedUnarchiver *coder = [[NSKeyedUnarchiver alloc] initForReadingWithData:written];
    NSError *failure = [NSError errorWithDomain:@"org.charon" code:7 userInfo:nil];
    NSString *raised = exception_name(^{
        ((void (*)(id, SEL, id))objc_msgSend)(coder, sel(@selector(failWithError:)), failure);
    });
    NSInteger policy = ((NSInteger (*)(id, SEL))objc_msgSend)(coder, sel(@selector(decodingFailurePolicy)));
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(coder, sel(@selector(setDecodingFailurePolicy:)), NSDecodingFailurePolicySetErrorAndReturn);
    NSString *quiet = exception_name(^{
        ((void (*)(id, SEL, id))objc_msgSend)(coder, sel(@selector(failWithError:)), failure);
    });
    [recorder record:@[raised, @(policy), quiet, error_text(((id (*)(id, SEL))objc_msgSend)(coder, sel(@selector(error)))),
                       @(((NSInteger (*)(id, SEL))objc_msgSend)(coder, sel(@selector(decodingFailurePolicy))))]
               named:@"archiving.failure"];
}

static void run_scanner(Foundation2Recorder *recorder)
{
    NSArray *inputs = @[@"18446744073709551615", @"0", @"  42  7", @"-5", @"99999999999999999999999", @"12abc", @"abc", @"", @"0012", @"+7", @"9223372036854775808"];
    for (NSUInteger index = 0; index < inputs.count; index++) {
        NSScanner *scanner = [NSScanner scannerWithString:inputs[index]];
        NSMutableArray *results = [NSMutableArray array];
        for (int attempt = 0; attempt < 2; attempt++) {
            unsigned long long value = 12345;
            BOOL scanned = ((BOOL (*)(id, SEL, unsigned long long *))objc_msgSend)(scanner, sel(@selector(scanUnsignedLongLong:)), &value);
            [results addObject:[NSString stringWithFormat:@"%d %llu %lu", scanned, value, (unsigned long)scanner.scanLocation]];
        }
        [recorder record:results named:[NSString stringWithFormat:@"scanner.%lu", (unsigned long)index]];
    }
}

static void run_value(Foundation2Recorder *recorder)
{
    NSValue *number = [NSValue valueWithBytes:"abcdefgh" objCType:@encode(double)];
    double copied = 0;
    ((void (*)(id, SEL, void *, NSUInteger))objc_msgSend)(number, sel(@selector(getValue:size:)), &copied, sizeof copied);
    [recorder record:@[[NSString stringWithFormat:@"%.17g", copied],
                       exception_name(^{
                           char small[4];
                           ((void (*)(id, SEL, void *, NSUInteger))objc_msgSend)(number, sel(@selector(getValue:size:)), small, sizeof small);
                       })]
               named:@"value.getValue"];
    NSRange range = NSMakeRange(3, 4);
    NSValue *wrapped = [NSValue valueWithRange:range];
    NSRange read = NSMakeRange(0, 0);
    ((void (*)(id, SEL, void *, NSUInteger))objc_msgSend)(wrapped, sel(@selector(getValue:size:)), &read, sizeof read);
    [recorder record:@[@(read.location), @(read.length)] named:@"value.range"];
}

static void run_locale(Foundation2Recorder *recorder)
{
    for (NSString *identifier in @[@"en_US", @"de_DE", @"zh_Hant_TW", @"en_GB"]) {
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
        NSMutableArray *values = [NSMutableArray array];
        SEL getters[] = {@selector(languageCode), @selector(countryCode), @selector(scriptCode), @selector(variantCode), @selector(calendarIdentifier), @selector(collationIdentifier),
                         @selector(decimalSeparator), @selector(groupingSeparator), @selector(currencySymbol), @selector(currencyCode), @selector(collatorIdentifier),
                         @selector(quotationBeginDelimiter), @selector(quotationEndDelimiter), @selector(alternateQuotationBeginDelimiter), @selector(alternateQuotationEndDelimiter)};
        for (size_t index = 0; index < sizeof getters / sizeof *getters; index++)
            [values addObject:((id (*)(id, SEL))objc_msgSend)(locale, sel(getters[index])) ?: @"<nil>"];
        [values addObject:@(((BOOL (*)(id, SEL))objc_msgSend)(locale, sel(@selector(usesMetricSystem))))];
        SEL localized[] = {@selector(localizedStringForLocaleIdentifier:), @selector(localizedStringForLanguageCode:), @selector(localizedStringForCountryCode:), @selector(localizedStringForScriptCode:),
                           @selector(localizedStringForCalendarIdentifier:), @selector(localizedStringForCurrencyCode:)};
        NSArray *arguments = @[@"fr_CA", @"de", @"DE", @"Hant", NSCalendarIdentifierJapanese, @"EUR"];
        for (size_t index = 0; index < sizeof localized / sizeof *localized; index++)
            [values addObject:((id (*)(id, SEL, id))objc_msgSend)(locale, sel(localized[index]), arguments[index]) ?: @"<nil>"];
        [recorder record:values named:[NSString stringWithFormat:@"locale.%@", identifier]];
    }
}

static NSProgress *fresh_progress(int64_t total, int64_t completed)
{
    NSProgress *progress = ((id (*)(id, SEL, int64_t))objc_msgSend)([NSProgress class], sel(@selector(discreteProgressWithTotalUnitCount:)), total);
    progress.completedUnitCount = completed;
    return progress;
}

static void run_progress(Foundation2Recorder *recorder)
{
    NSMutableArray *finished = [NSMutableArray array];
    int64_t totals[] = {0, 0, -1, -1, 5, 5, 5, 1, 10, 10};
    int64_t completeds[] = {0, 3, 0, -1, 5, 5, 4, 1, 10, 0};
    BOOL cancels[] = {NO, NO, NO, NO, NO, YES, YES, NO, NO, NO};
    for (size_t index = 0; index < sizeof totals / sizeof *totals; index++) {
        NSProgress *progress = fresh_progress(totals[index], completeds[index]);
        if (cancels[index])
            [progress cancel];
        [finished addObject:@(((BOOL (*)(id, SEL))objc_msgSend)(progress, sel(@selector(isFinished))))];
    }
    [recorder record:finished named:@"progress.finished"];

    NSProgress *discrete = fresh_progress(7, 2);
    [recorder record:@[@(discrete.totalUnitCount), @(discrete.completedUnitCount), @([NSProgress currentProgress] == nil)] named:@"progress.discrete"];
    NSProgress *outer = [NSProgress progressWithTotalUnitCount:10];
    [outer becomeCurrentWithPendingUnitCount:6];
    NSProgress *detached = fresh_progress(4, 4);
    (void)detached;
    double whileCurrent = outer.fractionCompleted;
    [outer resignCurrent];
    [recorder record:@(whileCurrent) named:@"progress.discreteIsNotAttached"];
    [recorder record:@(outer.fractionCompleted) named:@"progress.resignCreditsPendingUnits"];

    NSProgress *parent = [NSProgress progressWithTotalUnitCount:10];
    NSProgress *child = ((id (*)(id, SEL, int64_t, id, int64_t))objc_msgSend)([NSProgress class], sel(@selector(progressWithTotalUnitCount:parent:pendingUnitCount:)), 4, parent, 6);
    NSMutableArray *fractions = [NSMutableArray arrayWithObject:@(parent.fractionCompleted)];
    child.completedUnitCount = 2;
    [fractions addObject:@(parent.fractionCompleted)];
    child.completedUnitCount = 4;
    [fractions addObject:@(parent.fractionCompleted)];
    [recorder record:@[fractions, @(child.totalUnitCount), @([NSProgress currentProgress] == nil)] named:@"progress.parentAndPending"];
    NSProgress *orphan = ((id (*)(id, SEL, int64_t, id, int64_t))objc_msgSend)([NSProgress class], sel(@selector(progressWithTotalUnitCount:parent:pendingUnitCount:)), 3, nil, 1);
    [recorder record:@[@(orphan.totalUnitCount), @([NSProgress currentProgress] == nil)] named:@"progress.noParent"];

    NSProgress *host = [NSProgress progressWithTotalUnitCount:10];
    __block BOOL insideIsHost = NO;
    ((void (*)(id, SEL, int64_t, void (^)(void)))objc_msgSend)(host, sel(@selector(performAsCurrentWithPendingUnitCount:usingBlock:)), 5, ^{
        insideIsHost = [NSProgress currentProgress] == host;
        NSProgress *inner = [NSProgress progressWithTotalUnitCount:2];
        inner.completedUnitCount = 2;
    });
    [recorder record:@[@(insideIsHost), @([NSProgress currentProgress] == nil), @(host.fractionCompleted)] named:@"progress.performAsCurrent"];

    NSProgress *info = [NSProgress progressWithTotalUnitCount:10];
    NSArray *keys = @[NSProgressThroughputKey, NSProgressFileOperationKindKey, NSProgressFileURLKey, NSProgressFileTotalCountKey, NSProgressFileCompletedCountKey];
    NSArray *properties = @[@"estimatedTimeRemaining", @"throughput", @"fileOperationKind", @"fileURL", @"fileTotalCount", @"fileCompletedCount"];
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/progress-file"];
    NSArray *values = @[@12.5, @100, NSProgressFileOperationKindCopying, url, @5, @2];
    NSMutableArray *before = [NSMutableArray array];
    for (NSString *property in properties)
        [before addObject:((id (*)(id, SEL))objc_msgSend)(info, sel(NSSelectorFromString(property))) ?: @"<nil>"];
    for (NSUInteger index = 0; index < properties.count; index++) {
        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [[properties[index] substringToIndex:1] uppercaseString], [properties[index] substringFromIndex:1]]);
        ((void (*)(id, SEL, id))objc_msgSend)(info, sel(setter), values[index]);
    }
    NSMutableArray *after = [NSMutableArray array];
    for (NSString *property in properties) {
        id value = ((id (*)(id, SEL))objc_msgSend)(info, sel(NSSelectorFromString(property))) ?: @"<nil>";
        [after addObject:[value isKindOfClass:[NSURL class]] ? [value path] : value];
    }
    NSMutableArray *inInfo = [NSMutableArray array];
    for (NSString *key in keys)
        [inInfo addObject:info.userInfo[key] ? @YES : @NO];
    [inInfo addObject:info.userInfo[foundation2_implementation.progressConstants[0]] ? @YES : @NO];
    for (NSUInteger index = 0; index < properties.count; index++) {
        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [[properties[index] substringToIndex:1] uppercaseString], [properties[index] substringFromIndex:1]]);
        ((void (*)(id, SEL, id))objc_msgSend)(info, sel(setter), nil);
    }
    NSMutableArray *cleared = [NSMutableArray array];
    for (NSString *property in properties)
        [cleared addObject:((id (*)(id, SEL))objc_msgSend)(info, sel(NSSelectorFromString(property))) ?: @"<nil>"];
    [recorder record:@[before, after, inInfo, cleared] named:@"progress.userInfoProperties"];

    NSMutableArray *constants = [NSMutableArray array];
    for (NSString *constant in foundation2_implementation.progressConstants)
        [constants addObject:constant];
    [recorder record:constants named:@"progress.constants"];

    NSProgress *handled = [NSProgress progressWithTotalUnitCount:1];
    __block int cancelled = 0, paused = 0;
    NSArray *unset = @[@([handled respondsToSelector:sel(@selector(cancellationHandler))] && ((id (*)(id, SEL))objc_msgSend)(handled, sel(@selector(cancellationHandler))) != nil),
                       @([handled respondsToSelector:sel(@selector(pausingHandler))] && ((id (*)(id, SEL))objc_msgSend)(handled, sel(@selector(pausingHandler))) != nil)];
    handled.cancellationHandler = ^{ cancelled++; };
    handled.pausingHandler = ^{ paused++; };
    void (^cancelHandler)(void) = ((id (*)(id, SEL))objc_msgSend)(handled, sel(@selector(cancellationHandler)));
    void (^pauseHandler)(void) = ((id (*)(id, SEL))objc_msgSend)(handled, sel(@selector(pausingHandler)));
    cancelHandler();
    pauseHandler();
    pauseHandler();
    [recorder record:@[unset, @(cancelHandler != nil), @(pauseHandler != nil), @(cancelled), @(paused)] named:@"progress.handlerGetters"];
    handled.cancellationHandler = nil;
    handled.pausingHandler = nil;
    [recorder record:@[@(((id (*)(id, SEL))objc_msgSend)(handled, sel(@selector(cancellationHandler))) == nil), @(((id (*)(id, SEL))objc_msgSend)(handled, sel(@selector(pausingHandler))) == nil)] named:@"progress.handlerCleared"];
}

static void run_array(Foundation2Recorder *recorder)
{
    NSMutableArray *mutable = [NSMutableArray arrayWithObjects:@"a", [NSNull null], @3, nil];
    NSArray *arrays[] = {@[], @[@"only"], @[[NSNull null], @"x"], mutable, [NSArray arrayWithObject:@[]], [@[@1, @2, @3] subarrayWithRange:NSMakeRange(1, 2)], [@[] arrayByAddingObject:@9], [[NSOrderedSet orderedSetWithObjects:@"p", @"q", nil] array]};
    NSMutableArray *found = [NSMutableArray array];
    for (size_t index = 0; index < sizeof arrays / sizeof *arrays; index++) {
        id first = ((id (*)(id, SEL))objc_msgSend)(arrays[index], sel(@selector(firstObject)));
        [found addObject:first ? [first description] : @"<nil>"];
    }
    [mutable removeObjectAtIndex:0];
    id afterRemoval = ((id (*)(id, SEL))objc_msgSend)(mutable, sel(@selector(firstObject)));
    [mutable removeAllObjects];
    id afterEmptied = ((id (*)(id, SEL))objc_msgSend)(mutable, sel(@selector(firstObject)));
    [recorder record:@[found, afterRemoval ? [afterRemoval description] : @"<nil>", afterEmptied ? [afterEmptied description] : @"<nil>"] named:@"array.firstObject"];
}

static NSString *item_text(id item)
{
    NSString *description = [item description];
    NSRange close = [description rangeOfString:@">"];
    return [NSString stringWithFormat:@"%@|%@|%@", [item name], [item value] ?: @"<nil>", close.location == NSNotFound ? description : [description substringFromIndex:close.location + 1]];
}

static void run_query_item(Foundation2Recorder *recorder)
{
    Class class = foundation2_implementation.queryItemClass;
    id (^make)(NSString *, NSString *) = ^(NSString *name, NSString *value) {
        return ((id (*)(id, SEL, id, id))objc_msgSend)(class, @selector(queryItemWithName:value:), name, value);
    };
    id empty = [[class alloc] init];
    id nilName = ((id (*)(id, SEL, id, id))objc_msgSend)([class alloc], @selector(initWithName:value:), nil, @"v");
    id a = make(@"k", @"v"), b = make(@"k", @"v"), c = make(@"k", nil), d = make(@"k", @""), other = make(@"k2", @"v");
    [recorder record:@[item_text(empty), item_text(nilName), item_text(a), item_text(c), item_text(d), item_text(make(@"a b&c", @"ü=é"))] named:@"queryItem.description"];
    NSArray *items = @[a, b, c, d, other, empty, nilName];
    NSMutableArray *matrix = [NSMutableArray array];
    for (id left in items) {
        NSMutableString *row = [NSMutableString string];
        for (id right in items)
            [row appendString:[left isEqual:right] ? ([left hash] == [right hash] ? @"E" : @"e") : @"."];
        [matrix addObject:row];
    }
    [recorder record:@[matrix, @([a isEqual:nil]), @([a isEqual:@"k"]), @([[a copy] isEqual:a]), @([[c copy] isEqual:c]), @([class supportsSecureCoding])] named:@"queryItem.equality"];
    NSMutableString *changing = [NSMutableString stringWithString:@"mutable"];
    id copied = make(changing, changing);
    [changing appendString:@"X"];
    [recorder record:@[[copied name], [copied value]] named:@"queryItem.copiesItsStrings"];
    NSMutableArray *archived = [NSMutableArray array];
    for (id item in @[a, c, d, make(@"ü", @"é&=")]) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:item];
        NSError *error = nil;
        id back = ((id (*)(id, SEL, Class, id, NSError **))objc_msgSend)([NSKeyedUnarchiver class], @selector(unarchivedObjectOfClass:fromData:error:), class, data, &error);
        [archived addObject:@[back ? item_text(back) : @"<nil>", error_text(error), @([back isEqual:item])]];
    }
    [recorder record:archived named:@"queryItem.archive"];
}

static void run_relative_urls(Foundation2Recorder *recorder)
{
    NSString *directory = [[[NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES] absoluteString] stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"];
    NSArray *bases = @[[NSNull null], [NSURL URLWithString:@"file:///tmp/base/"], [NSURL URLWithString:@"http://host/dir/"]];
    NSArray *paths = @[@"sub/file", @"/absolute/file", @"dir/", @"", @"~/tilde"];
    for (NSUInteger baseIndex = 0; baseIndex < bases.count; baseIndex++) {
        for (NSUInteger pathIndex = 0; pathIndex < paths.count; pathIndex++) {
            NSURL *base = bases[baseIndex] == [NSNull null] ? nil : bases[baseIndex];
            NSString *path = paths[pathIndex];
            NSURL *asDirectory = ((id (*)(id, SEL, id, BOOL, id))objc_msgSend)([NSURL class], sel(@selector(fileURLWithPath:isDirectory:relativeToURL:)), path, YES, base);
            NSURL *file = ((id (*)(id, SEL, id, id))objc_msgSend)([NSURL class], sel(@selector(fileURLWithPath:relativeToURL:)), path, base);
            [recorder record:@[url_text(asDirectory, directory), url_text(file, directory), @(((BOOL (*)(id, SEL))objc_msgSend)(asDirectory, sel(@selector(hasDirectoryPath))))]
                       named:[NSString stringWithFormat:@"url.relativePath.%lu.%lu", (unsigned long)baseIndex, (unsigned long)pathIndex]];
        }
    }
    NSArray *representations = @[@"http://host/p%20q?x#y", @"relative/path", @"mailto:a@b", @"file:///tmp/x", @"", @"http://host/ä"];
    for (NSUInteger index = 0; index < representations.count; index++) {
        NSData *data = [representations[index] dataUsingEncoding:NSUTF8StringEncoding];
        NSURL *relative = ((id (*)(id, SEL, id, id))objc_msgSend)([NSURL class], sel(@selector(URLWithDataRepresentation:relativeToURL:)), data, [NSURL URLWithString:@"http://base/dir/"]);
        NSURL *absolute = ((id (*)(id, SEL, id, id))objc_msgSend)([NSURL class], sel(@selector(absoluteURLWithDataRepresentation:relativeToURL:)), data, [NSURL URLWithString:@"http://base/dir/"]);
        NSData *back = ((id (*)(id, SEL))objc_msgSend)(relative, sel(@selector(dataRepresentation)));
        [recorder record:@[url_text(relative, nil), url_text(absolute, nil), back ? [[NSString alloc] initWithData:back encoding:NSUTF8StringEncoding] : @"<nil>",
                           @(((BOOL (*)(id, SEL))objc_msgSend)(relative, sel(@selector(hasDirectoryPath))))]
                   named:[NSString stringWithFormat:@"url.dataRepresentation.%lu", (unsigned long)index]];
    }
    NSArray *latins = @[[NSData dataWithBytes:"http://h/\xE4\xFF" length:11], [NSData dataWithBytes:"http://h/\x80\x9F" length:11],
                        [NSData dataWithBytes:"http://h/\xC3\xA4\xFF" length:12], [NSData dataWithBytes:"http://h/a\xE4?q=\xFF#\xE4" length:17]];
    NSMutableArray *latinResults = [NSMutableArray array];
    NSMutableArray *latinStrings = [NSMutableArray array];
    for (NSData *raw in latins) {
        NSURL *fromRaw = ((id (*)(id, SEL, id, id))objc_msgSend)([NSURL class], sel(@selector(URLWithDataRepresentation:relativeToURL:)), raw, nil);
        NSURL *absolute = ((id (*)(id, SEL, id, id))objc_msgSend)([NSURL class], sel(@selector(absoluteURLWithDataRepresentation:relativeToURL:)), raw, [NSURL URLWithString:@"http://b/"]);
        NSData *rawBack = ((id (*)(id, SEL))objc_msgSend)(fromRaw, sel(@selector(dataRepresentation)));
        NSData *absoluteBack = ((id (*)(id, SEL))objc_msgSend)(absolute.absoluteURL, sel(@selector(dataRepresentation)));
        NSURL *appended = [fromRaw URLByAppendingPathComponent:@"x"];
        [latinResults addObject:@[fromRaw.path ?: @"<nil>", fromRaw.query ?: @"<nil>", fromRaw.fragment ?: @"<nil>", rawBack ? hex(rawBack) : @"<nil>",
                                  absoluteBack ? hex(absoluteBack) : @"<nil>", appended.absoluteString ?: @"<nil>"]];
        [latinStrings addObject:@[url_text(fromRaw, nil), url_text(absolute, nil)]];
    }
    [recorder record:latinResults named:@"url.dataRepresentation.latin1"];
    [recorder record:latinStrings named:@"url.dataRepresentation.latin1.string"];
}


static void run_scheduling(Foundation2Recorder *recorder)
{
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
    }];
    NSMutableArray *values = [NSMutableArray array];
    [values addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(operation, sel(@selector(qualityOfService))))];
    NSInteger qualities[] = {NSQualityOfServiceUserInteractive, NSQualityOfServiceUserInitiated, NSQualityOfServiceUtility, NSQualityOfServiceBackground, NSQualityOfServiceDefault};
    for (size_t index = 0; index < sizeof qualities / sizeof *qualities; index++) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(operation, sel(@selector(setQualityOfService:)), qualities[index]);
        [values addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(operation, sel(@selector(qualityOfService))))];
    }
    [recorder record:values named:@"scheduling.operation"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    NSMutableArray *queueValues = [NSMutableArray array];
    [queueValues addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(queue, sel(@selector(qualityOfService))))];
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(queue, sel(@selector(setQualityOfService:)), NSQualityOfServiceUtility);
    [queueValues addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(queue, sel(@selector(qualityOfService))))];
    [queueValues addObject:@(((id (*)(id, SEL))objc_msgSend)(queue, sel(@selector(underlyingQueue))) != nil)];
    dispatch_queue_t target = dispatch_queue_create("org.charon.backports.test", NULL);
    ((void (*)(id, SEL, dispatch_queue_t))objc_msgSend)(queue, sel(@selector(setUnderlyingQueue:)), target);
    [queueValues addObject:@(((id (*)(id, SEL))objc_msgSend)(queue, sel(@selector(underlyingQueue))) == target)];
    [queueValues addObject:exception_name(^{
        ((void (*)(id, SEL, dispatch_queue_t))objc_msgSend)([NSOperationQueue mainQueue], sel(@selector(setUnderlyingQueue:)), target);
    })];
    [queueValues addObject:exception_name(^{
        ((void (*)(id, SEL, dispatch_queue_t))objc_msgSend)(queue, sel(@selector(setUnderlyingQueue:)), dispatch_get_main_queue());
    })];
    [recorder record:queueValues named:@"scheduling.queue"];
    NSThread *thread = [[NSThread alloc] init];
    NSMutableArray *threadValues = [NSMutableArray array];
    [threadValues addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(thread, sel(@selector(qualityOfService))))];
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(thread, sel(@selector(setQualityOfService:)), NSQualityOfServiceBackground);
    [threadValues addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(thread, sel(@selector(qualityOfService))))];
    [threadValues addObject:@(thread.threadPriority)];
    [recorder record:threadValues named:@"scheduling.thread"];
    NSMutableArray *coerced = [NSMutableArray array];
    NSInteger asked[] = {12345, 0, 1, 0x21, 0x19, 0x11, 0x09, -1, -2, 0x15};
    for (size_t index = 0; index < sizeof asked / sizeof *asked; index++) {
        NSThread *unstarted = [[NSThread alloc] init];
        NSOperationQueue *fresh = [[NSOperationQueue alloc] init];
        NSOperation *pending = [NSBlockOperation blockOperationWithBlock:^{
        }];
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(unstarted, sel(@selector(setQualityOfService:)), asked[index]);
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(fresh, sel(@selector(setQualityOfService:)), asked[index]);
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(pending, sel(@selector(setQualityOfService:)), asked[index]);
        [coerced addObject:@[@(((NSInteger (*)(id, SEL))objc_msgSend)(unstarted, sel(@selector(qualityOfService)))), @(((NSInteger (*)(id, SEL))objc_msgSend)(fresh, sel(@selector(qualityOfService)))),
                             @(((NSInteger (*)(id, SEL))objc_msgSend)(pending, sel(@selector(qualityOfService))))]];
    }
    [recorder record:coerced named:@"scheduling.coerced"];
    NSMutableArray *apart = [NSMutableArray array];
    [apart addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)([NSThread mainThread], sel(@selector(qualityOfService))))];
    [apart addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)([NSOperationQueue mainQueue], sel(@selector(qualityOfService))))];
    NSOperation *weighed = [NSBlockOperation blockOperationWithBlock:^{
    }];
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(weighed, sel(@selector(setQualityOfService:)), NSQualityOfServiceBackground);
    [apart addObject:@(weighed.threadPriority)];
    weighed.threadPriority = 0.9;
    [apart addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(weighed, sel(@selector(qualityOfService))))];
    NSThread *prioritized = [[NSThread alloc] init];
    prioritized.threadPriority = 0.1;
    [apart addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(prioritized, sel(@selector(qualityOfService))))];
    NSCondition *started = [[NSCondition alloc] init];
    __block BOOL running = NO, leave = NO;
    NSThread *runner = [[NSThread alloc] initWithTarget:[NSBlockOperation blockOperationWithBlock:^{
        [started lock];
        running = YES;
        [started broadcast];
        while (!leave)
            [started wait];
        [started unlock];
    }] selector:@selector(start) object:nil];
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(runner, sel(@selector(setQualityOfService:)), NSQualityOfServiceUtility);
    [runner start];
    [started lock];
    while (!running)
        [started wait];
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(runner, sel(@selector(setQualityOfService:)), NSQualityOfServiceBackground);
    [apart addObject:@(((NSInteger (*)(id, SEL))objc_msgSend)(runner, sel(@selector(qualityOfService))))];
    leave = YES;
    [started broadcast];
    [started unlock];
    [recorder record:apart named:@"scheduling.apart"];
}

void foundation2_run(Foundation2Implementation implementation, Foundation2Recorder *recorder)
{
    foundation2_prefix = implementation.prefix;
    foundation2_implementation = implementation;
    @autoreleasepool {
        progress(@"base64");
        run_base64(recorder);
    }
    @autoreleasepool {
        progress(@"byteRanges");
        run_byte_ranges(recorder);
    }
    progress(@"deallocator");
    run_deallocator(recorder);
    @autoreleasepool {
        progress(@"indexPath");
        run_index_path(recorder);
        progress(@"url");
        run_url(recorder);
        progress(@"processInfo");
        run_process_info(recorder);
        progress(@"strings");
        run_strings(recorder);
        progress(@"expression");
        run_expression(recorder);
        progress(@"autorelease");
        run_autorelease(recorder);
    }
    @autoreleasepool {
        progress(@"archiving");
        run_archiving(recorder);
        progress(@"scanner");
        run_scanner(recorder);
        progress(@"value");
        run_value(recorder);
        progress(@"locale");
        run_locale(recorder);
        progress(@"queryItem");
        run_query_item(recorder);
        progress(@"array");
        run_array(recorder);
        progress(@"progress");
        run_progress(recorder);
        progress(@"relativeUrls");
        run_relative_urls(recorder);
        progress(@"scheduling");
        run_scheduling(recorder);
    }
    @autoreleasepool {
        progress(@"calendar");
        run_calendar(recorder);
        progress(@"calendarEdges");
        run_calendar_edges(recorder);
        run_validity(recorder);
        progress(@"done");
    }
}
