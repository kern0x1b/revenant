#import <UIKit/UIKit.h>
#import "check.h"

@interface Note : NSObject <NSItemProviderWriting, NSItemProviderReading>
@property (nonatomic, copy) NSString *text;
@end

@implementation Note

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
    Note *note = [[Note alloc] init];
    note.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return note;
}

@end

@interface CharonHostNSItemProvider : NSObject <NSCopying>
- (void)registerDataRepresentationForTypeIdentifier:(NSString *)type visibility:(NSItemProviderRepresentationVisibility)visibility loadHandler:(NSProgress *(^)(void (^)(NSData *, NSError *)))handler;
- (void)registerFileRepresentationForTypeIdentifier:(NSString *)type fileOptions:(NSItemProviderFileOptions)options visibility:(NSItemProviderRepresentationVisibility)visibility loadHandler:(NSProgress *(^)(void (^)(NSURL *, BOOL, NSError *)))handler;
- (NSProgress *)loadDataRepresentationForTypeIdentifier:(NSString *)type completionHandler:(void (^)(NSData *, NSError *))handler;
- (NSProgress *)loadFileRepresentationForTypeIdentifier:(NSString *)type completionHandler:(void (^)(NSURL *, NSError *))handler;
- (NSProgress *)loadInPlaceFileRepresentationForTypeIdentifier:(NSString *)type completionHandler:(void (^)(NSURL *, BOOL, NSError *))handler;
- (instancetype)initWithObject:(id<NSItemProviderWriting>)object;
- (BOOL)canLoadObjectOfClass:(Class)aClass;
- (NSProgress *)loadObjectOfClass:(Class)aClass completionHandler:(void (^)(id, NSError *))handler;
- (BOOL)hasRepresentationConformingToTypeIdentifier:(NSString *)type fileOptions:(NSItemProviderFileOptions)options;
- (NSArray *)registeredTypeIdentifiersWithFileOptions:(NSItemProviderFileOptions)options;
@property (nonatomic, copy) NSString *suggestedName;
- (instancetype)initWithItem:(id)item typeIdentifier:(NSString *)type;
- (instancetype)initWithContentsOfURL:(NSURL *)URL;
- (void)registerItemForTypeIdentifier:(NSString *)type loadHandler:(NSItemProviderLoadHandler)handler;
- (void)loadItemForTypeIdentifier:(NSString *)type options:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)handler;
- (BOOL)hasItemConformingToTypeIdentifier:(NSString *)type;
@property (nonatomic, readonly) NSArray *registeredTypeIdentifiers;
@property (nonatomic, copy) NSItemProviderLoadHandler previewImageHandler;
- (void)loadPreviewImageWithOptions:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)handler;
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
        return [NSString stringWithFormat:@"NSData(%lu)", (unsigned long)[object length]];
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

#define LOAD(PROVIDER, CLASS, TYPE, NAME) { __block NSString *result = @"none"; [PROVIDER loadItemForTypeIdentifier:TYPE options:nil completionHandler:^(CLASS *item, NSError *error) { result = describe(item, error); }]; spin(0.3); [row appendFormat:@" %@=%@", NAME, result]; }

static NSString *matrix_row(id provider, NSString *type, NSString *skip)
{
    NSMutableString *row = [NSMutableString string];
    if (![skip containsString:@"S"]) LOAD(provider, NSString, type, @"String")
    LOAD(provider, NSURL, type, @"URL")
    if (![skip containsString:@"D"]) LOAD(provider, NSData, type, @"Data")
    if (![skip containsString:@"I"]) LOAD(provider, UIImage, type, @"Image")
    if (![skip containsString:@"A"]) LOAD(provider, NSAttributedString, type, @"Attr")
    LOAD(provider, NSNumber, type, @"Number")
    LOAD(provider, NSDictionary, type, @"Dict")
    LOAD(provider, NSArray, type, @"Array")
    { __block NSString *result = @"none"; [provider loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError *error) { result = describe(item, error); }]; spin(0.3); [row appendFormat:@" id=%@", result]; }
    return row;
}

int main(void)
{
    @autoreleasepool {
        NSString *directory = NSTemporaryDirectory();
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
        NSArray *cases = @[
            @[@"a string", @"hello", @"public.plain-text", @""],
            @[@"a web URL", [NSURL URLWithString:@"https://a.b/c"], @"public.url", @"DI"],
            @[@"a file URL", [NSURL fileURLWithPath:text], @"public.file-url", @""],
            @[@"a file URL as data", [NSURL fileURLWithPath:text], @"public.data", @""],
            @[@"an image file URL", [NSURL fileURLWithPath:pngPath], @"public.png", @""],
            @[@"data", abc, @"public.data", @""],
            @[@"text data", abc, @"public.plain-text", @""],
            @[@"image data as png", png, @"public.png", @""],
            @[@"image data as image", png, @"public.image", @""],
            @[@"an image", image, @"public.image", @""],
            @[@"a number", @5, @"public.data", @""],
            @[@"a dictionary", @{@"a": @1}, @"public.data", @""],
            @[@"an array", @[@1], @"public.data", @""],
        ];
        for (NSArray *entry in cases) {
            NSString *skip = entry[3];
            if ([entry[0] isEqualToString:@"a string"] || [entry[0] isEqualToString:@"a web URL"] || [entry[0] isEqualToString:@"a file URL"])
                skip = [skip stringByAppendingString:@"A"];
            if ([entry[0] isEqualToString:@"a file URL"])
                skip = [skip stringByAppendingString:@"S"];
            CharonHostNSItemProvider *ours = [[CharonHostNSItemProvider alloc] initWithItem:entry[1] typeIdentifier:entry[2]];
            NSItemProvider *system = [[NSItemProvider alloc] initWithItem:entry[1] typeIdentifier:entry[2]];
            NSString *one = matrix_row(ours, entry[2], skip), *two = matrix_row(system, entry[2], skip);
            charon_check([one isEqualToString:two], [[@"loading " stringByAppendingString:entry[0]] UTF8String], ([NSString stringWithFormat:@"\n  port %@\n  system %@", one, two]));
        }

        CharonHostNSItemProvider *ours = [[CharonHostNSItemProvider alloc] initWithItem:@"hello" typeIdentifier:@"public.plain-text"];
        NSItemProvider *system = [[NSItemProvider alloc] initWithItem:@"hello" typeIdentifier:@"public.plain-text"];
        NSMutableArray *conformances = [NSMutableArray array];
        for (NSString *type in @[@"public.plain-text", @"public.text", @"public.utf8-plain-text", @"public.image", @"public.data", @"com.bogus", @"public.content"])
            [conformances addObject:[NSString stringWithFormat:@"%@:%d:%d", type, [ours hasItemConformingToTypeIdentifier:type], [system hasItemConformingToTypeIdentifier:type]]];
        BOOL same = YES;
        for (NSString *entry in conformances) {
            NSArray *parts = [entry componentsSeparatedByString:@":"];
            same = same && [parts[1] isEqual:parts[2]];
        }
        charon_check(same && [ours.registeredTypeIdentifiers isEqual:system.registeredTypeIdentifiers], "the types a provider has and conforms to", [conformances componentsJoinedByString:@" "]);
        charon_check([[[CharonHostNSItemProvider alloc] init].registeredTypeIdentifiers isEqual:[[NSItemProvider alloc] init].registeredTypeIdentifiers], "an empty provider has no types", @"it has");
        NSString *raisedOne = @"none", *raisedTwo = @"none";
        @try { (void)[[CharonHostNSItemProvider alloc] initWithItem:@"x" typeIdentifier:nil]; } @catch (NSException *exception) { raisedOne = exception.name; }
        @try { (void)[[NSItemProvider alloc] initWithItem:@"x" typeIdentifier:nil]; } @catch (NSException *exception) { raisedTwo = exception.name; }
        charon_check([raisedOne isEqualToString:raisedTwo] && ![raisedOne isEqualToString:@"none"], "an item with no type is refused", raisedOne);

        for (NSString *type in @[@"com.bogus", @"public.image"]) {
            __block NSString *one = @"none", *two = @"none";
            [ours loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError *error) { one = describe(item, error); }];
            [system loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError *error) { two = describe(item, error); }];
            spin(0.3);
            charon_check([one isEqualToString:two], [[@"a type the provider does not have: " stringByAppendingString:type] UTF8String], ([NSString stringWithFormat:@"%@ != %@", one, two]));
        }

        for (NSNumber *withNothing in @[@NO, @YES]) {
            CharonHostNSItemProvider *handlerOurs = [[CharonHostNSItemProvider alloc] init];
            NSItemProvider *handlerSystem = [[NSItemProvider alloc] init];
            NSMutableArray *seen = [NSMutableArray array];
            NSItemProviderLoadHandler make = ^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) {
                [seen addObject:[NSString stringWithFormat:@"%@ %@", NSStringFromClass(expected) ?: @"nil", options]];
                completion(@"from handler", nil);
            };
            [handlerOurs registerItemForTypeIdentifier:@"public.plain-text" loadHandler:make];
            [handlerSystem registerItemForTypeIdentifier:@"public.plain-text" loadHandler:make];
            NSDictionary *options = withNothing.boolValue ? nil : @{@"k": @1};
            __block NSString *one = @"none", *two = @"none";
            [handlerOurs loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(NSString *item, NSError *error) { one = describe(item, error); }];
            [handlerSystem loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(NSString *item, NSError *error) { two = describe(item, error); }];
            spin(0.3);
            [handlerOurs loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(NSData *item, NSError *error) {}];
            [handlerSystem loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(NSData *item, NSError *error) {}];
            [handlerOurs loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(id item, NSError *error) {}];
            [handlerSystem loadItemForTypeIdentifier:@"public.plain-text" options:options completionHandler:^(id item, NSError *error) {}];
            spin(0.3);
            BOOL equalPairs = seen.count == 6;
            for (NSUInteger index = 0; equalPairs && index < 3; index++)
                equalPairs = [seen[index * 2] isEqualToString:seen[index * 2 + 1]];
            charon_check([one isEqualToString:two] && equalPairs, withNothing.boolValue ? "a load handler is told the class asked for and empty options" : "a load handler is told the class asked for and the options", ([NSString stringWithFormat:@"%@ / %@ / %@", one, two, seen]));
        }

        for (NSString *kind in @[@"error", @"nil"]) {
            CharonHostNSItemProvider *badOurs = [[CharonHostNSItemProvider alloc] init];
            NSItemProvider *badSystem = [[NSItemProvider alloc] init];
            NSItemProviderLoadHandler fail = ^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) {
                completion(nil, [kind isEqualToString:@"error"] ? [NSError errorWithDomain:@"mine" code:5 userInfo:nil] : nil);
            };
            [badOurs registerItemForTypeIdentifier:@"public.plain-text" loadHandler:fail];
            [badSystem registerItemForTypeIdentifier:@"public.plain-text" loadHandler:fail];
            __block NSString *one = @"none", *two = @"none";
            [badOurs loadItemForTypeIdentifier:@"public.plain-text" options:nil completionHandler:^(NSString *item, NSError *error) { one = describe(item, error); }];
            [badSystem loadItemForTypeIdentifier:@"public.plain-text" options:nil completionHandler:^(NSString *item, NSError *error) { two = describe(item, error); }];
            spin(0.3);
            charon_check([one isEqualToString:two], [[@"a handler that answers " stringByAppendingString:kind] UTF8String], ([NSString stringWithFormat:@"%@ != %@", one, two]));
        }

        CharonHostNSItemProvider *orderOurs = [[CharonHostNSItemProvider alloc] init];
        NSItemProvider *orderSystem = [[NSItemProvider alloc] init];
        for (NSString *type in @[@"public.plain-text", @"public.utf8-plain-text", @"public.plain-text"]) {
            NSItemProviderLoadHandler handler = ^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) { completion(type, nil); };
            [orderOurs registerItemForTypeIdentifier:type loadHandler:handler];
            [orderSystem registerItemForTypeIdentifier:type loadHandler:handler];
        }
        charon_check([orderOurs.registeredTypeIdentifiers isEqual:orderSystem.registeredTypeIdentifiers], "registering a type again keeps its place", ([NSString stringWithFormat:@"%@ != %@", orderOurs.registeredTypeIdentifiers, orderSystem.registeredTypeIdentifiers]));
        __block NSString *first = @"none", *second = @"none";
        [orderOurs loadItemForTypeIdentifier:@"public.text" options:nil completionHandler:^(NSString *item, NSError *error) { first = describe(item, error); }];
        [orderSystem loadItemForTypeIdentifier:@"public.text" options:nil completionHandler:^(NSString *item, NSError *error) { second = describe(item, error); }];
        spin(0.3);
        charon_check([first isEqualToString:second], "the first type that conforms answers", ([NSString stringWithFormat:@"%@ != %@", first, second]));

        CharonHostNSItemProvider *fileOurs = [[CharonHostNSItemProvider alloc] initWithContentsOfURL:[NSURL fileURLWithPath:text]];
        NSItemProvider *fileSystem = [[NSItemProvider alloc] initWithContentsOfURL:[NSURL fileURLWithPath:text]];
        charon_check([fileOurs.registeredTypeIdentifiers isEqual:fileSystem.registeredTypeIdentifiers], "a provider of a file has the type of the file, the file URL and the URL", ([NSString stringWithFormat:@"%@ != %@", fileOurs.registeredTypeIdentifiers, fileSystem.registeredTypeIdentifiers]));
        NSString *one = matrix_row(fileOurs, [fileOurs.registeredTypeIdentifiers firstObject], @"");
        NSString *two = matrix_row(fileSystem, [fileSystem.registeredTypeIdentifiers firstObject], @"");
        charon_check([one isEqualToString:two], "the contents of a file as each class", ([NSString stringWithFormat:@"\n  port %@\n  system %@", one, two]));
        one = matrix_row(fileOurs, @"public.file-url", @"A");
        two = matrix_row(fileSystem, @"public.file-url", @"A");
        charon_check([one isEqualToString:two], "the URL of a file as each class", ([NSString stringWithFormat:@"\n  port %@\n  system %@", one, two]));

        CharonHostNSItemProvider *copyOurs = [ours copy];
        NSItemProvider *copySystem = [system copy];
        charon_check(copyOurs != ours && copySystem != system && [copyOurs.registeredTypeIdentifiers isEqual:copySystem.registeredTypeIdentifiers], "a copy is another provider with the same types", @"it is not");

        NSItemProviderLoadHandler preview = ^(NSItemProviderCompletionHandler completion, Class expected, NSDictionary *options) { completion(image, nil); };
        ours.previewImageHandler = preview;
        system.previewImageHandler = preview;
        __block NSString *previewOne = @"none", *previewTwo = @"none", *noneOne = @"none", *noneTwo = @"none";
        [ours loadPreviewImageWithOptions:nil completionHandler:^(UIImage *item, NSError *error) { previewOne = describe(item, error); }];
        [system loadPreviewImageWithOptions:nil completionHandler:^(UIImage *item, NSError *error) { previewTwo = describe(item, error); }];
        [[[CharonHostNSItemProvider alloc] init] loadPreviewImageWithOptions:nil completionHandler:^(UIImage *item, NSError *error) { noneOne = describe(item, error); }];
        [[[NSItemProvider alloc] init] loadPreviewImageWithOptions:nil completionHandler:^(UIImage *item, NSError *error) { noneTwo = describe(item, error); }];
        spin(0.3);
        charon_check([previewOne isEqualToString:previewTwo] && [noneOne isEqualToString:noneTwo], "the preview image", ([NSString stringWithFormat:@"%@ %@ / %@ %@", previewOne, previewTwo, noneOne, noneTwo]));
        {
            CharonHostNSItemProvider *o = [[CharonHostNSItemProvider alloc] init];
            NSItemProvider *sy = [[NSItemProvider alloc] init];
            NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"provider-files"];
            [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
            NSString *source = [folder stringByAppendingPathComponent:@"source.txt"];
            [@"source body" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            for (id p in @[o, sy]) {
                [p registerDataRepresentationForTypeIdentifier:@"public.plain-text" visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^done)(NSData *, NSError *)) {
                    done([@"bytes" dataUsingEncoding:NSUTF8StringEncoding], nil);
                    return nil;
                }];
                [p registerFileRepresentationForTypeIdentifier:@"public.data" fileOptions:0 visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^done)(NSURL *, BOOL, NSError *)) {
                    done([NSURL fileURLWithPath:source], NO, nil);
                    return nil;
                }];
                [p registerFileRepresentationForTypeIdentifier:@"public.png" fileOptions:NSItemProviderFileOptionOpenInPlace visibility:NSItemProviderRepresentationVisibilityAll loadHandler:^NSProgress *(void (^done)(NSURL *, BOOL, NSError *)) {
                    done([NSURL fileURLWithPath:source], YES, nil);
                    return nil;
                }];
            }
            charon_check([o.registeredTypeIdentifiers isEqual:sy.registeredTypeIdentifiers] && [[o registeredTypeIdentifiersWithFileOptions:0] isEqual:[sy registeredTypeIdentifiersWithFileOptions:0]] && [[o registeredTypeIdentifiersWithFileOptions:NSItemProviderFileOptionOpenInPlace] isEqual:[sy registeredTypeIdentifiersWithFileOptions:NSItemProviderFileOptionOpenInPlace]], "the types of data and file representations, with and without opening in place", ([NSString stringWithFormat:@"%@ %@ / %@ %@", [o registeredTypeIdentifiersWithFileOptions:0], [o registeredTypeIdentifiersWithFileOptions:1], [sy registeredTypeIdentifiersWithFileOptions:0], [sy registeredTypeIdentifiersWithFileOptions:1]]));
            charon_check([o hasRepresentationConformingToTypeIdentifier:@"public.text" fileOptions:0] == [sy hasRepresentationConformingToTypeIdentifier:@"public.text" fileOptions:0] && [o hasRepresentationConformingToTypeIdentifier:@"public.png" fileOptions:NSItemProviderFileOptionOpenInPlace] == [sy hasRepresentationConformingToTypeIdentifier:@"public.png" fileOptions:NSItemProviderFileOptionOpenInPlace] && [o hasRepresentationConformingToTypeIdentifier:@"public.png" fileOptions:0] == [sy hasRepresentationConformingToTypeIdentifier:@"public.png" fileOptions:0], "a representation conforming to a type, with the file options", @"they differ");
            NSMutableArray *records = [NSMutableArray array];
            for (id p in @[o, sy]) {
                NSMutableString *record = [NSMutableString string];
                [p loadDataRepresentationForTypeIdentifier:@"public.plain-text" completionHandler:^(NSData *data, NSError *error) { [record appendFormat:@"data=%@ ", describe(data, error)]; }];
                [p loadDataRepresentationForTypeIdentifier:@"com.bogus" completionHandler:^(NSData *data, NSError *error) { [record appendFormat:@"bogus=%@ ", describe(data, error)]; }];
                [p loadFileRepresentationForTypeIdentifier:@"public.data" completionHandler:^(NSURL *URL, NSError *error) {
                    [record appendFormat:@"file=%@ same=%d exists=%d body=%@ ", URL ? URL.lastPathComponent : describe(nil, error), [URL.path isEqualToString:source], URL ? [[NSFileManager defaultManager] fileExistsAtPath:URL.path] : 0, URL ? [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:NULL] : @"nil"];
                }];
                [p loadInPlaceFileRepresentationForTypeIdentifier:@"public.png" completionHandler:^(NSURL *URL, BOOL inPlace, NSError *error) {
                    [record appendFormat:@"inplace=%@ %d %d ", URL ? URL.lastPathComponent : describe(nil, error), inPlace, [URL.path isEqualToString:source]];
                }];
                [p loadInPlaceFileRepresentationForTypeIdentifier:@"public.data" completionHandler:^(NSURL *URL, BOOL inPlace, NSError *error) {
                    [record appendFormat:@"inplace2=%d ", inPlace];
                }];
                spin(0.5);
                NSArray *parts = [[record componentsSeparatedByString:@" "] sortedArrayUsingSelector:@selector(compare:)];
                [records addObject:[parts componentsJoinedByString:@" "]];
            }
            charon_check([records[0] isEqualToString:records[1]], "loading data and files from representations", ([NSString stringWithFormat:@"\n  port %@\n  system %@", records[0], records[1]]));

            Note *note = [[Note alloc] init];
            note.text = @"body";
            CharonHostNSItemProvider *objectOurs = [[CharonHostNSItemProvider alloc] initWithObject:note];
            NSItemProvider *objectSystem = [[NSItemProvider alloc] initWithObject:note];
            charon_check([objectOurs.registeredTypeIdentifiers isEqual:objectSystem.registeredTypeIdentifiers] && [objectOurs canLoadObjectOfClass:[Note class]] == [objectSystem canLoadObjectOfClass:[Note class]] && [objectOurs canLoadObjectOfClass:[NSString class]] == [objectSystem canLoadObjectOfClass:[NSString class]], "a provider of an object has its types and can load its class", ([NSString stringWithFormat:@"%@ / %@", objectOurs.registeredTypeIdentifiers, objectSystem.registeredTypeIdentifiers]));
            __block NSString *loadedOurs = @"none", *loadedSystem = @"none";
            [objectOurs loadObjectOfClass:[Note class] completionHandler:^(id object, NSError *error) { loadedOurs = object ? [object text] : describe(nil, error); }];
            [objectSystem loadObjectOfClass:[Note class] completionHandler:^(id object, NSError *error) { loadedSystem = object ? [object text] : describe(nil, error); }];
            spin(0.5);
            charon_check([loadedOurs isEqualToString:loadedSystem], "loading an object back", ([NSString stringWithFormat:@"%@ != %@", loadedOurs, loadedSystem]));
            o.suggestedName = @"name";
            sy.suggestedName = @"name";
            charon_check([o.suggestedName isEqual:sy.suggestedName], "the suggested name is kept", @"it is not");
        }
        charon_check([NSItemProviderErrorDomain isEqualToString:@"NSItemProviderErrorDomain"] && NSItemProviderUnknownError == -1 && NSItemProviderItemUnavailableError == -1000 && NSItemProviderUnexpectedValueClassError == -1100 && NSItemProviderUnavailableCoercionError == -1200, "the error domain and the codes", @"they differ");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
