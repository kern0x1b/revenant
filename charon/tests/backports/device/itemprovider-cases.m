#import <UIKit/UIKit.h>
#import "itemprovider-cases.h"

@interface ProviderNote : NSObject <NSItemProviderWriting, NSItemProviderReading>
@property (nonatomic, copy) NSString *text;
@end

@implementation ProviderNote

+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return @[@"public.utf8-plain-text", @"com.charon.note"];
}

+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider
{
    return @[@"com.charon.note"];
}

- (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return [[self class] writableTypeIdentifiersForItemProvider];
}

- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)type forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    completionHandler([[NSString stringWithFormat:@"%@:%@", type, self.text] dataUsingEncoding:NSUTF8StringEncoding], nil);
    return nil;
}

+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)type error:(NSError **)error
{
    ProviderNote *note = [[ProviderNote alloc] init];
    note.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return note;
}

@end

static void spin(NSTimeInterval seconds)
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static NSString *describe(id object, NSError *error)
{
    if (error)
        return [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code];
    if (!object)
        return @"nil";
    if ([object isKindOfClass:[NSURL class]])
        return [NSString stringWithFormat:@"NSURL(%@)", [object isFileURL] ? @"file" : @"web"];
    if ([object isKindOfClass:[NSData class]])
        return [NSString stringWithFormat:@"NSData(%@)", [object length] > 8 && !memcmp([object bytes], "\x89PNG", 4) ? @"png" : [NSString stringWithFormat:@"%lu", (unsigned long)[object length]]];
    if ([object isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"NSString(%@)", object];
    if ([object isKindOfClass:[UIImage class]])
        return @"UIImage";
    if ([object isKindOfClass:[NSAttributedString class]])
        return [NSString stringWithFormat:@"NSAttributedString(%lu)", (unsigned long)[object length]];
    if ([object isKindOfClass:[NSNumber class]])
        return @"NSNumber";
    if ([object isKindOfClass:[NSDictionary class]])
        return @"NSDictionary";
    if ([object isKindOfClass:[NSArray class]])
        return @"NSArray";
    return NSStringFromClass([object class]);
}

#define LOAD(CLASS, NAME) { __block NSString *result = @"none"; [provider loadItemForTypeIdentifier:type options:nil completionHandler:^(CLASS *item, NSError *error) { result = describe(item, error); }]; spin(0.3); [row appendFormat:@" %@=%@", NAME, result]; }

static NSString *matrix_row(NSItemProvider *provider, NSString *type, NSString *skip, NSString *scrub)
{
    NSMutableString *row = [NSMutableString string];
    if (![skip containsString:@"S"]) LOAD(NSString, @"String")
    LOAD(NSURL, @"URL")
    if (![skip containsString:@"D"]) LOAD(NSData, @"Data")
    if (![skip containsString:@"I"]) LOAD(UIImage, @"Image")
    if (![skip containsString:@"A"]) LOAD(NSAttributedString, @"Attr")
    LOAD(NSNumber, @"Number")
    LOAD(NSDictionary, @"Dict")
    LOAD(NSArray, @"Array")
    { __block NSString *result = @"none"; [provider loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError *error) { result = describe(item, error); }]; spin(0.3); [row appendFormat:@" id=%@", result]; }
    if (!scrub)
        return row;
    NSString *scrubbed = [row stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"];
    scrubbed = [scrubbed stringByReplacingOccurrencesOfString:scrub withString:@"$"];
    return scrubbed;
}

void itemprovider_run(ItemProviderRecorder record)
{
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"provider-cases"];
    [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *text = [directory stringByAppendingPathComponent:@"provider.txt"];
    [@"hello" writeToFile:text atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    UIGraphicsBeginImageContext(CGSizeMake(4, 4));
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, 4, 4));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *png = UIImagePNGRepresentation(image);
    NSString *pngPath = [directory stringByAppendingPathComponent:@"provider.png"];
    [png writeToFile:pngPath atomically:YES];
    NSData *abc = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *root = [[NSURL fileURLWithPath:directory isDirectory:YES].absoluteString stringByReplacingOccurrencesOfString:@"file://localhost/" withString:@"file:///"];
    root = [root hasSuffix:@"/"] ? [root substringToIndex:root.length - 1] : root;
    NSArray *cases = @[
        @[@"string", @"hello", @"public.plain-text", @""],
        @[@"webURL", [NSURL URLWithString:@"https://a.b/c"], @"public.url", @"DI"],
        @[@"fileURL", [NSURL fileURLWithPath:text], @"public.file-url", @"AS"],
        @[@"fileURLAsData", [NSURL fileURLWithPath:text], @"public.data", @""],
        @[@"imageFileURL", [NSURL fileURLWithPath:pngPath], @"public.png", @""],
        @[@"data", abc, @"public.data", @""],
        @[@"textData", abc, @"public.plain-text", @""],
        @[@"pngData", png, @"public.png", @""],
        @[@"pngDataAsImage", png, @"public.image", @""],
        @[@"image", image, @"public.image", @""],
        @[@"number", @5, @"public.data", @""],
        @[@"dictionary", @{@"a": @1}, @"public.data", @""],
        @[@"array", @[@1], @"public.data", @""],
    ];
    for (NSArray *entry in cases) {
        NSString *skip = entry[3];
        if ([entry[0] isEqualToString:@"string"] || [entry[0] isEqualToString:@"webURL"])
            skip = [skip stringByAppendingString:@"A"];
        NSItemProvider *provider = [[NSItemProvider alloc] initWithItem:entry[1] typeIdentifier:entry[2]];
        record([@"matrix." stringByAppendingString:entry[0]], matrix_row(provider, entry[2], skip, nil));
    }

    NSItemProvider *string = [[NSItemProvider alloc] initWithItem:@"hello" typeIdentifier:@"public.plain-text"];
    NSMutableArray *conformances = [NSMutableArray array];
    for (NSString *type in @[@"public.plain-text", @"public.text", @"public.utf8-plain-text", @"public.image", @"public.data", @"com.bogus", @"public.content"])
        [conformances addObject:[NSString stringWithFormat:@"%@=%d", type, [string hasItemConformingToTypeIdentifier:type]]];
    record(@"types.conformance", [conformances componentsJoinedByString:@" "]);
    record(@"types.registered", [[string registeredTypeIdentifiers] componentsJoinedByString:@","]);
    record(@"types.empty", [[[[NSItemProvider alloc] init] registeredTypeIdentifiers] componentsJoinedByString:@","]);
    NSString *raised = @"none";
    @try {
        (void)[[NSItemProvider alloc] initWithItem:@"x" typeIdentifier:nil];
    } @catch (NSException *exception) {
        raised = exception.name;
    }
    record(@"types.nilType", raised);
    for (NSString *type in @[@"com.bogus", @"public.image"]) {
        __block NSString *result = @"none";
        [string loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError *error) { result = describe(item, error); }];
        spin(0.3);
        record([@"load.missing." stringByAppendingString:type], result);
    }

    for (NSNumber *withNothing in @[@NO, @YES]) {
        NSItemProvider *handler = [[NSItemProvider alloc] init];
        NSMutableArray *seen = [NSMutableArray array];
        [handler registerItemForTypeIdentifier:@"public.plain-text" loadHandler:^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) {
            [seen addObject:[NSString stringWithFormat:@"%@ %@", NSStringFromClass(expected) ?: @"nil", options.count ? @"options" : options ? @"empty" : @"none"]];
            completion(@"from handler", nil);
        }];
        NSDictionary *options = withNothing.boolValue ? nil : @{@"k": @1};
        __block NSString *result = @"none";
        [handler loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(NSString *item, NSError *error) { result = describe(item, error); }];
        spin(0.3);
        [handler loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(NSData *item, NSError *error) {}];
        [handler loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(id item, NSError *error) {}];
        spin(0.3);
        record(withNothing.boolValue ? @"handler.noOptions" : @"handler.options", [NSString stringWithFormat:@"%@ | %@", result, [seen componentsJoinedByString:@" | "]]);
    }
    for (NSString *kind in @[@"error", @"nil"]) {
        NSItemProvider *bad = [[NSItemProvider alloc] init];
        [bad registerItemForTypeIdentifier:@"public.plain-text" loadHandler:^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) {
            completion(nil, [kind isEqualToString:@"error"] ? [NSError errorWithDomain:@"mine" code:5 userInfo:nil] : nil);
        }];
        __block NSString *result = @"none";
        [bad loadItemForTypeIdentifier:@"public.plain-text" options:nil completionHandler:^(NSString *item, NSError *error) { result = describe(item, error); }];
        spin(0.3);
        record([@"handler.fails." stringByAppendingString:kind], result);
    }
    NSItemProvider *order = [[NSItemProvider alloc] init];
    for (NSString *type in @[@"public.plain-text", @"public.utf8-plain-text", @"public.plain-text"])
        [order registerItemForTypeIdentifier:type loadHandler:^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) { completion(type, nil); }];
    record(@"order.registered", [[order registeredTypeIdentifiers] componentsJoinedByString:@","]);
    __block NSString *first = @"none";
    [order loadItemForTypeIdentifier:@"public.text" options:nil completionHandler:^(NSString *item, NSError *error) { first = describe(item, error); }];
    spin(0.3);
    record(@"order.load", first);

    NSItemProvider *file = [[NSItemProvider alloc] initWithContentsOfURL:[NSURL fileURLWithPath:text]];
    record(@"file.types", [[file registeredTypeIdentifiers] componentsJoinedByString:@","]);
    record(@"file.contents", matrix_row(file, [file registeredTypeIdentifiers].firstObject, @"", root));
    NSString *urlRow = matrix_row(file, @"public.file-url", @"AD", root);
    urlRow = [[NSRegularExpression regularExpressionWithPattern:@"NSData\\([0-9]+\\)" options:0 error:NULL] stringByReplacingMatchesInString:urlRow options:0 range:NSMakeRange(0, urlRow.length) withTemplate:@"NSData(n)"];
    record(@"file.url", urlRow);
    NSItemProvider *imageFile = [[NSItemProvider alloc] initWithContentsOfURL:[NSURL fileURLWithPath:pngPath]];
    record(@"file.image.types", [[imageFile registeredTypeIdentifiers] componentsJoinedByString:@","]);
    NSItemProvider *copy = [string copy];
    record(@"copy", [NSString stringWithFormat:@"%d %@", copy != string, [[copy registeredTypeIdentifiers] componentsJoinedByString:@","]]);
    __block NSString *preview = @"none", *noPreview = @"none";
    string.previewImageHandler = ^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) { completion(image, nil); };
    [string loadPreviewImageWithOptions:nil completionHandler:^(UIImage *item, NSError *error) { preview = describe(item, error); }];
    [[[NSItemProvider alloc] init] loadPreviewImageWithOptions:nil completionHandler:^(UIImage *item, NSError *error) { noPreview = describe(item, error); }];
    spin(0.3);
    record(@"preview", [NSString stringWithFormat:@"%@ | %@", preview, noPreview]);
    record(@"constants", [NSString stringWithFormat:@"%@ %@ %@ %ld %ld %ld %ld", NSItemProviderErrorDomain, NSItemProviderPreferredImageSizeKey, NSExtensionJavaScriptPreprocessingResultsKey, (long)NSItemProviderUnknownError, (long)NSItemProviderItemUnavailableError, (long)NSItemProviderUnexpectedValueClassError, (long)NSItemProviderUnavailableCoercionError]);

    NSItemProvider *representations = [[NSItemProvider alloc] init];
    NSString *source = [directory stringByAppendingPathComponent:@"source.txt"];
    [@"source body" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [representations registerDataRepresentationForTypeIdentifier:@"public.plain-text" visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^done)(NSData *, NSError *)) {
        done([@"bytes" dataUsingEncoding:NSUTF8StringEncoding], nil);
        return nil;
    }];
    [representations registerFileRepresentationForTypeIdentifier:@"public.data" fileOptions:0 visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^done)(NSURL *, BOOL, NSError *)) {
        done([NSURL fileURLWithPath:source], NO, nil);
        return nil;
    }];
    [representations registerFileRepresentationForTypeIdentifier:@"public.png" fileOptions:NSItemProviderFileOptionOpenInPlace visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^done)(NSURL *, BOOL, NSError *)) {
        done([NSURL fileURLWithPath:source], YES, nil);
        return nil;
    }];
    record(@"representations.types", [NSString stringWithFormat:@"%@ | %@ | %@", [[representations registeredTypeIdentifiers] componentsJoinedByString:@","], [[representations registeredTypeIdentifiersWithFileOptions:0] componentsJoinedByString:@","], [[representations registeredTypeIdentifiersWithFileOptions:NSItemProviderFileOptionOpenInPlace] componentsJoinedByString:@","]]);
    record(@"representations.has", [NSString stringWithFormat:@"%d %d %d", [representations hasRepresentationConformingToTypeIdentifier:@"public.text" fileOptions:0], [representations hasRepresentationConformingToTypeIdentifier:@"public.png" fileOptions:NSItemProviderFileOptionOpenInPlace], [representations hasRepresentationConformingToTypeIdentifier:@"public.png" fileOptions:0]]);
    NSMutableArray *parts = [NSMutableArray array];
    [representations loadDataRepresentationForTypeIdentifier:@"public.plain-text" completionHandler:^(NSData *data, NSError *error) { [parts addObject:[@"data=" stringByAppendingString:describe(data, error)]]; }];
    [representations loadDataRepresentationForTypeIdentifier:@"com.bogus" completionHandler:^(NSData *data, NSError *error) { [parts addObject:[@"bogus=" stringByAppendingString:describe(data, error)]]; }];
    [representations loadFileRepresentationForTypeIdentifier:@"public.data" completionHandler:^(NSURL *URL, NSError *error) {
        [parts addObject:[NSString stringWithFormat:@"file=%@ same=%d exists=%d body=%@", URL.lastPathComponent, [URL.path isEqualToString:source], [[NSFileManager defaultManager] fileExistsAtPath:URL.path], [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:NULL]]];
    }];
    [representations loadInPlaceFileRepresentationForTypeIdentifier:@"public.png" completionHandler:^(NSURL *URL, BOOL inPlace, NSError *error) {
        [parts addObject:[NSString stringWithFormat:@"inplace=%@ %d %d", URL.lastPathComponent, inPlace, [URL.path isEqualToString:source]]];
    }];
    [representations loadInPlaceFileRepresentationForTypeIdentifier:@"public.data" completionHandler:^(NSURL *URL, BOOL inPlace, NSError *error) { [parts addObject:[NSString stringWithFormat:@"inplace2=%d", inPlace]]; }];
    spin(0.5);
    record(@"representations.load", [[parts sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@" | "]);

    ProviderNote *note = [[ProviderNote alloc] init];
    note.text = @"body";
    NSItemProvider *object = [[NSItemProvider alloc] initWithObject:note];
    record(@"object.types", [NSString stringWithFormat:@"%@ | %d %d", [[object registeredTypeIdentifiers] componentsJoinedByString:@","], [object canLoadObjectOfClass:[ProviderNote class]], [object canLoadObjectOfClass:[NSString class]]]);
    __block NSString *loaded = @"none";
    [object loadObjectOfClass:[ProviderNote class] completionHandler:^(id loadedObject, NSError *error) { loaded = loadedObject ? [loadedObject text] : describe(nil, error); }];
    spin(0.5);
    record(@"object.load", loaded);
    NSItemProvider *builtin = [[NSItemProvider alloc] initWithObject:@"héllo"];
    __block NSString *builtinLoaded = @"none";
    [builtin loadObjectOfClass:[NSString class] completionHandler:^(id loadedObject, NSError *error) { builtinLoaded = loadedObject ? loadedObject : describe(nil, error); }];
    spin(0.5);
    record(@"builtin.string", [NSString stringWithFormat:@"%@ | %d %d | %@", [[builtin registeredTypeIdentifiers] componentsJoinedByString:@","], [builtin canLoadObjectOfClass:[NSString class]], [builtin canLoadObjectOfClass:[NSURL class]], builtinLoaded]);
    NSItemProvider *builtinURL = [[NSItemProvider alloc] initWithObject:[NSURL URLWithString:@"https://a.b"]];
    __block NSString *urlLoaded = @"none";
    [builtinURL loadObjectOfClass:[NSURL class] completionHandler:^(id loadedObject, NSError *error) { urlLoaded = loadedObject ? [loadedObject absoluteString] : describe(nil, error); }];
    spin(0.5);
    record(@"builtin.url", [NSString stringWithFormat:@"%@ | %@", [[builtinURL registeredTypeIdentifiers] componentsJoinedByString:@","], urlLoaded]);

    NSExtensionItem *item = [[NSExtensionItem alloc] init];
    NSMutableArray *fields = [NSMutableArray array];
    [fields addObject:[NSString stringWithFormat:@"new=%d%d%d%d %lu", item.attributedTitle != nil, item.attributedContentText != nil, item.attachments != nil, item.userInfo != nil, (unsigned long)item.userInfo.count]];
    item.attributedTitle = [[NSAttributedString alloc] initWithString:@"title"];
    item.attributedContentText = [[NSAttributedString alloc] initWithString:@"text"];
    item.attachments = @[string];
    [fields addObject:[NSString stringWithFormat:@"set=%@ %@ %lu keys=%@", item.attributedTitle.string, item.attributedContentText.string, (unsigned long)item.attachments.count, [[item.userInfo.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]]];
    item.attachments = nil;
    item.attributedTitle = nil;
    [fields addObject:[NSString stringWithFormat:@"cleared=%d %d keys=%@", item.attributedTitle != nil, item.attachments != nil, [[item.userInfo.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]]];
    item.userInfo = @{@"k": @1};
    [fields addObject:[NSString stringWithFormat:@"replaced=%@ %d %@", item.userInfo, item.attributedContentText != nil, item.attachments]];
    NSExtensionItem *plain = [[NSExtensionItem alloc] init];
    plain.userInfo = @{@"k": @1};
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:plain];
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL];
    NSMutableArray *keys = [[plist[@"$objects"][1] allKeys] mutableCopy];
    [keys removeObject:@"$class"];
    [fields addObject:[NSString stringWithFormat:@"archive=%@", [[keys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]]];
    NSExtensionItem *back = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    [fields addObject:[NSString stringWithFormat:@"back=%@", back.userInfo]];
    item.userInfo = nil;
    [fields addObject:[NSString stringWithFormat:@"nil=%@", item.userInfo]];
    record(@"extensionItem", [fields componentsJoinedByString:@" | "]);
    record(@"extensionItem.keys", [NSString stringWithFormat:@"%@ %@ %@", NSExtensionItemAttributedTitleKey, NSExtensionItemAttributedContentTextKey, NSExtensionItemAttachmentsKey]);
}
