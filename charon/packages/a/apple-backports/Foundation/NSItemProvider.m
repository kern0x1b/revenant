#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>

NSString *const NSItemProviderErrorDomain = @"NSItemProviderErrorDomain";
NSString *const NSItemProviderPreferredImageSizeKey = @"NSItemProviderPreferredImageSize";
NSString *const NSExtensionJavaScriptPreprocessingResultsKey = @"NSExtensionJavaScriptPreprocessingResultsKey";
NSString *const NSExtensionJavaScriptFinalizeArgumentKey = @"NSExtensionJavaScriptFinalizeArgumentKey";

typedef Boolean (*CharonConformsFunction)(CFStringRef, CFStringRef);
typedef CFStringRef (*CharonIdentifierFunction)(CFStringRef, CFStringRef, CFStringRef);

static CharonConformsFunction charon_conforms_function;
static CharonIdentifierFunction charon_identifier_function;

static void charon_load_uti(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_conforms_function = (CharonConformsFunction)dlsym(RTLD_DEFAULT, "UTTypeConformsTo");
        charon_identifier_function = (CharonIdentifierFunction)dlsym(RTLD_DEFAULT, "UTTypeCreatePreferredIdentifierForTag");
        if (!charon_conforms_function || !charon_identifier_function) {
            void *image = dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
            charon_conforms_function = (CharonConformsFunction)dlsym(image, "UTTypeConformsTo");
            charon_identifier_function = (CharonIdentifierFunction)dlsym(image, "UTTypeCreatePreferredIdentifierForTag");
        }
    });
}

static BOOL charon_conforms(NSString *type, NSString *parent)
{
    if ([type isEqualToString:parent])
        return YES;
    charon_load_uti();
    return charon_conforms_function && charon_conforms_function((__bridge CFStringRef)type, (__bridge CFStringRef)parent);
}

static NSError *charon_error(NSInteger code)
{
    return [NSError errorWithDomain:NSItemProviderErrorDomain code:code userInfo:nil];
}

static Class charon_expected_class(id block)
{
    struct CharonBlock {
        void *isa;
        int flags;
        int reserved;
        void (*invoke)(void);
        struct {
            unsigned long reserved;
            unsigned long size;
        } *descriptor;
    } *layout = (__bridge struct CharonBlock *)block;
    const int hasCopyDispose = 1 << 25, hasSignature = 1 << 30;
    if (!layout || !(layout->flags & hasSignature))
        return Nil;
    const char **signature = (const char **)((char *)layout->descriptor + sizeof(*layout->descriptor) + ((layout->flags & hasCopyDispose) ? 2 * sizeof(void *) : 0));
    const char *encoding = *signature;
    const char *argument = strstr(encoding, "@?");
    if (!argument)
        return Nil;
    argument += 2;
    while (*argument >= '0' && *argument <= '9')
        argument++;
    if (*argument != '@' || argument[1] != '"')
        return Nil;
    const char *start = argument + 2, *end = strchr(start, '"');
    if (!end)
        return Nil;
    char name[128];
    size_t length = MIN((size_t)(end - start), sizeof(name) - 1);
    memcpy(name, start, length);
    name[length] = 0;
    char *protocol = strchr(name, '<');
    if (protocol)
        *protocol = 0;
    return name[0] ? NSClassFromString(@(name)) : Nil;
}

static id charon_image(NSData *data)
{
    Class image = NSClassFromString(@"UIImage");
    return data.length && image ? ((id (*)(Class, SEL, NSData *))objc_msgSend)(image, NSSelectorFromString(@"imageWithData:"), data) : nil;
}

static id charon_coerce(id item, NSString *type, Class expected, NSInteger *code)
{
    *code = 0;
    if (!expected || [item isKindOfClass:expected])
        return item;
    BOOL fileURL = [item isKindOfClass:[NSURL class]] && [item isFileURL];
    BOOL urlType = charon_conforms(type, @"public.url");
    NSString *urlString = nil;
    if (urlType && [item isKindOfClass:[NSData class]])
        urlString = [[NSString alloc] initWithData:item encoding:NSUTF8StringEncoding];
    if ([expected isSubclassOfClass:[NSString class]]) {
        if ([item isKindOfClass:[NSURL class]] && urlType)
            return [item absoluteString];
        if (urlString)
            return urlString;
        if ([item isKindOfClass:[NSData class]] && charon_conforms(type, @"public.text")) {
            NSString *string = [[NSString alloc] initWithData:item encoding:NSUTF8StringEncoding];
            if (string)
                return string;
        }
    } else if ([expected isSubclassOfClass:[NSURL class]]) {
        NSURL *URL = urlString ? [NSURL URLWithString:urlString] : nil;
        if (URL)
            return URL;
        *code = -1100;
        return nil;
    } else if ([expected isSubclassOfClass:[NSData class]]) {
        if (fileURL) {
            NSData *data = [NSData dataWithContentsOfURL:item];
            if (data)
                return data;
        }
    } else if ([expected isSubclassOfClass:(NSClassFromString(@"UIImage") ?: [NSNull class])]) {
        NSData *data = [item isKindOfClass:[NSData class]] ? item : fileURL ? [NSData dataWithContentsOfURL:item] : nil;
        if (data) {
            id image = charon_image(data);
            if (image)
                return image;
            *code = -1100;
            return nil;
        }
    } else if ([expected isSubclassOfClass:[NSAttributedString class]]) {
        NSString *string = [item isKindOfClass:[NSString class]] ? item : nil;
        if (!string && [item isKindOfClass:[NSData class]] && charon_conforms(type, @"public.text"))
            string = [[NSString alloc] initWithData:item encoding:NSUTF8StringEncoding];
        if (string)
            return [[NSAttributedString alloc] initWithString:string];
    }
    *code = -1200;
    return nil;
}

@interface CharonRepresentation : NSObject {
@public
    NSString *_type;
    NSItemProviderLoadHandler _loader;
    NSProgress *(^_dataLoader)(void (^)(NSData *, NSError *));
    NSProgress *(^_fileLoader)(void (^)(NSURL *, BOOL, NSError *));
    NSItemProviderFileOptions _fileOptions;
    /* The visibility the caller handed the registration. The port took the argument and dropped it,
       so -itemProviderVisibilityForRepresentationWithTypeIdentifier: had nothing true to answer with. */
    NSItemProviderRepresentationVisibility _visibility;
    BOOL _itemBacked;
}
@end

@implementation CharonRepresentation
@end

@implementation NSItemProvider {
    NSMutableArray<CharonRepresentation *> *_representations;
    NSString *_suggestedName;
    NSItemProviderLoadHandler _previewImageHandler;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _representations = [NSMutableArray array];
    return self;
}

- (instancetype)initWithItem:(id<NSSecureCoding>)item typeIdentifier:(NSString *)typeIdentifier
{
    self = [self init];
    if (self) {
        if (!typeIdentifier)
            [NSException raise:NSInvalidArgumentException format:@"*** -[NSMutableOrderedSet addObject:]: object cannot be nil"];
        CharonRepresentation *representation = [self charon_representationForType:typeIdentifier];
        representation->_itemBacked = YES;
        representation->_loader = [^(NSItemProviderCompletionHandler completionHandler, Class expectedValueClass, NSDictionary *options) {
            completionHandler(item, nil);
        } copy];
    }
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)fileURL
{
    self = [self init];
    if (self && fileURL) {
        if (fileURL.isFileURL) {
            charon_load_uti();
            NSString *type = nil;
            if (charon_identifier_function && fileURL.pathExtension.length)
                type = CFBridgingRelease(charon_identifier_function(CFSTR("public.filename-extension"), (__bridge CFStringRef)fileURL.pathExtension, NULL));
            if (type) {
                CharonRepresentation *representation = [self charon_representationForType:type];
                representation->_itemBacked = YES;
                representation->_loader = [^(NSItemProviderCompletionHandler completionHandler, Class expectedValueClass, NSDictionary *options) {
                    NSData *data = [NSData dataWithContentsOfURL:fileURL];
                    completionHandler(data, nil);
                } copy];
            }
            CharonRepresentation *fileRepresentation = [self charon_representationForType:@"public.file-url"];
            fileRepresentation->_itemBacked = YES;
            fileRepresentation->_loader = [^(NSItemProviderCompletionHandler completionHandler, Class expectedValueClass, NSDictionary *options) {
                completionHandler([fileURL.absoluteString dataUsingEncoding:NSUTF8StringEncoding], nil);
            } copy];
        }
        CharonRepresentation *representation = [self charon_representationForType:@"public.url"];
        representation->_itemBacked = YES;
        representation->_loader = [^(NSItemProviderCompletionHandler completionHandler, Class expectedValueClass, NSDictionary *options) {
            completionHandler([fileURL.absoluteString dataUsingEncoding:NSUTF8StringEncoding], nil);
        } copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSItemProvider *copy = [[[self class] alloc] init];
    copy->_representations = [_representations mutableCopy];
    copy->_suggestedName = [_suggestedName copy];
    copy->_previewImageHandler = [_previewImageHandler copy];
    return copy;
}

- (CharonRepresentation *)charon_representationForType:(NSString *)type
{
    for (CharonRepresentation *representation in _representations) {
        if ([representation->_type isEqualToString:type]) {
            representation->_loader = nil;
            representation->_dataLoader = nil;
            representation->_fileLoader = nil;
            return representation;
        }
    }
    CharonRepresentation *representation = [[CharonRepresentation alloc] init];
    representation->_type = type;
    [_representations addObject:representation];
    return representation;
}

- (void)registerItemForTypeIdentifier:(NSString *)typeIdentifier loadHandler:(NSItemProviderLoadHandler)loadHandler
{
    if (!typeIdentifier)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSMutableOrderedSet addObject:]: object cannot be nil"];
    CharonRepresentation *representation = [self charon_representationForType:typeIdentifier];
    representation->_loader = loadHandler;
}

- (NSArray<NSString *> *)registeredTypeIdentifiers
{
    NSMutableArray *types = [NSMutableArray array];
    for (CharonRepresentation *representation in _representations)
        [types addObject:representation->_type];
    return types;
}

- (NSArray<NSString *> *)registeredTypeIdentifiersWithFileOptions:(NSItemProviderFileOptions)fileOptions
{
    NSMutableArray *types = [NSMutableArray array];
    for (CharonRepresentation *representation in _representations) {
        if (representation->_fileLoader ? (representation->_fileOptions & fileOptions) == fileOptions : fileOptions == 0)
            [types addObject:representation->_type];
    }
    return types;
}

- (BOOL)hasItemConformingToTypeIdentifier:(NSString *)typeIdentifier
{
    for (CharonRepresentation *representation in _representations) {
        if (charon_conforms(representation->_type, typeIdentifier))
            return YES;
    }
    return NO;
}

- (BOOL)hasRepresentationConformingToTypeIdentifier:(NSString *)typeIdentifier fileOptions:(NSItemProviderFileOptions)fileOptions
{
    for (CharonRepresentation *representation in _representations) {
        BOOL matchesOptions = representation->_fileLoader ? (representation->_fileOptions & fileOptions) == fileOptions : fileOptions == 0;
        if (matchesOptions && charon_conforms(representation->_type, typeIdentifier))
            return YES;
    }
    return NO;
}

- (CharonRepresentation *)charon_representationConformingTo:(NSString *)typeIdentifier
{
    for (CharonRepresentation *representation in _representations) {
        if (charon_conforms(representation->_type, typeIdentifier))
            return representation;
    }
    return nil;
}

- (CharonRepresentation *)charon_representationConformingTo:(NSString *)typeIdentifier preferring:(BOOL (^)(CharonRepresentation *))preferred
{
    for (CharonRepresentation *representation in _representations) {
        if (charon_conforms(representation->_type, typeIdentifier) && preferred(representation))
            return representation;
    }
    return [self charon_representationConformingTo:typeIdentifier];
}

- (void)loadItemForTypeIdentifier:(NSString *)typeIdentifier options:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)completionHandler
{
    if (!completionHandler)
        return;
    CharonRepresentation *representation = typeIdentifier ? [self charon_representationConformingTo:typeIdentifier] : nil;
    if (!representation) {
        completionHandler(nil, charon_error(-1000));
        return;
    }
    Class expected = charon_expected_class(completionHandler);
    NSItemProviderCompletionHandler reply = [completionHandler copy];
    NSString *type = representation->_type;
    void (^deliver)(id, NSError *) = ^(id item, NSError *error) {
        if (!item || error) {
            reply(nil, charon_error(-1000));
            return;
        }
        NSInteger code = 0;
        id coerced = charon_coerce(item, type, expected, &code);
        reply(coerced, coerced ? nil : charon_error(code));
    };
    if (representation->_loader) {
        NSItemProviderLoadHandler loader = representation->_loader;
        BOOL itemBacked = representation->_itemBacked;
        void (^run)(void) = ^{
            loader(^(id<NSSecureCoding> item, NSError *error) {
                deliver(item, error);
            }, expected, expected ? (options ?: @{}) : options);
        };
        dispatch_async(itemBacked || ![NSThread isMainThread] ? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) : dispatch_get_main_queue(), run);
        return;
    }
    if (representation->_dataLoader) {
        representation->_dataLoader(^(NSData *data, NSError *error) {
            deliver(data, error);
        });
        return;
    }
    if (representation->_fileLoader) {
        representation->_fileLoader(^(NSURL *URL, BOOL coordinated, NSError *error) {
            deliver(URL, error);
        });
        return;
    }
    reply(nil, charon_error(-1000));
}

- (NSItemProviderLoadHandler)previewImageHandler
{
    return _previewImageHandler;
}

- (void)setPreviewImageHandler:(NSItemProviderLoadHandler)handler
{
    _previewImageHandler = [handler copy];
}

- (void)loadPreviewImageWithOptions:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)completionHandler
{
    if (!completionHandler)
        return;
    NSItemProviderLoadHandler handler = _previewImageHandler;
    if (!handler) {
        completionHandler(nil, charon_error(-1000));
        return;
    }
    Class expected = charon_expected_class(completionHandler);
    NSItemProviderCompletionHandler reply = [completionHandler copy];
    handler(^(id<NSSecureCoding> item, NSError *error) {
        if (!item || error) {
            reply(nil, charon_error(-1000));
            return;
        }
        NSInteger code = 0;
        id coerced = charon_coerce(item, @"public.image", expected, &code);
        reply(coerced, coerced ? nil : charon_error(code));
    }, expected, options ?: @{});
}

- (NSString *)suggestedName
{
    return _suggestedName;
}

- (void)setSuggestedName:(NSString *)name
{
    _suggestedName = [name copy];
}

- (void)registerDataRepresentationForTypeIdentifier:(NSString *)typeIdentifier visibility:(NSItemProviderRepresentationVisibility)visibility loadHandler:(NSProgress *(^)(void (^)(NSData *, NSError *)))loadHandler
{
    CharonRepresentation *representation = [self charon_representationForType:typeIdentifier];
    representation->_dataLoader = loadHandler;
    representation->_visibility = visibility;
}

- (void)registerFileRepresentationForTypeIdentifier:(NSString *)typeIdentifier fileOptions:(NSItemProviderFileOptions)fileOptions visibility:(NSItemProviderRepresentationVisibility)visibility loadHandler:(NSProgress *(^)(void (^)(NSURL *, BOOL, NSError *)))loadHandler
{
    CharonRepresentation *representation = [self charon_representationForType:typeIdentifier];
    representation->_fileLoader = loadHandler;
    representation->_fileOptions = fileOptions;
    representation->_visibility = visibility;
}

- (NSProgress *)loadDataRepresentationForTypeIdentifier:(NSString *)typeIdentifier completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    CharonRepresentation *representation = [self charon_representationConformingTo:typeIdentifier preferring:^BOOL(CharonRepresentation *candidate) { return candidate->_dataLoader != nil; }];
    void (^reply)(NSData *, NSError *) = [completionHandler copy];
    if (!representation) {
        reply(nil, charon_error(-1000));
        return progress;
    }
    if (representation->_dataLoader) {
        NSProgress *inner = representation->_dataLoader(^(NSData *data, NSError *error) {
            reply(data, data ? nil : (error ?: charon_error(-1000)));
        });
        return inner ?: progress;
    }
    [self loadItemForTypeIdentifier:representation->_type options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
        reply([(id)item isKindOfClass:[NSData class]] ? (NSData *)item : nil, error ?: ([(id)item isKindOfClass:[NSData class]] ? nil : charon_error(-1200)));
    }];
    return progress;
}

- (NSProgress *)loadFileRepresentationForTypeIdentifier:(NSString *)typeIdentifier completionHandler:(void (^)(NSURL *, NSError *))completionHandler
{
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    CharonRepresentation *representation = [self charon_representationConformingTo:typeIdentifier preferring:^BOOL(CharonRepresentation *candidate) { return candidate->_fileLoader != nil; }];
    void (^reply)(NSURL *, NSError *) = [completionHandler copy];
    if (!representation) {
        reply(nil, charon_error(-1000));
        return progress;
    }
    void (^copyOut)(NSURL *) = ^(NSURL *source) {
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *target = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:source.lastPathComponent]];
        NSError *error = nil;
        if ([[NSFileManager defaultManager] copyItemAtURL:source toURL:target error:&error]) {
            reply(target, nil);
        } else {
            reply(nil, error);
        }
        [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    };
    if (representation->_fileLoader) {
        NSProgress *inner = representation->_fileLoader(^(NSURL *URL, BOOL coordinated, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (URL)
                    copyOut(URL);
                else
                    reply(nil, error ?: charon_error(-1000));
            });
        });
        return inner ?: progress;
    }
    [self loadDataRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSData *data, NSError *error) {
        if (!data) {
            reply(nil, error ?: charon_error(-1000));
            return;
        }
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *target = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"item"]];
        [data writeToURL:target atomically:NO];
        reply(target, nil);
        [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    }];
    return progress;
}

- (NSProgress *)loadInPlaceFileRepresentationForTypeIdentifier:(NSString *)typeIdentifier completionHandler:(void (^)(NSURL *, BOOL, NSError *))completionHandler
{
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    CharonRepresentation *representation = [self charon_representationConformingTo:typeIdentifier preferring:^BOOL(CharonRepresentation *candidate) { return candidate->_fileLoader != nil; }];
    void (^reply)(NSURL *, BOOL, NSError *) = [completionHandler copy];
    if (representation->_fileLoader && (representation->_fileOptions & NSItemProviderFileOptionOpenInPlace)) {
        NSProgress *inner = representation->_fileLoader(^(NSURL *URL, BOOL coordinated, NSError *error) {
            reply(URL, YES, URL ? nil : (error ?: charon_error(-1000)));
        });
        return inner ?: progress;
    }
    [self loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL *URL, NSError *error) {
        reply(URL, NO, error);
    }];
    return progress;
}

/* The six members of the two provider protocols, answered by the provider itself: this class *is* the
   port's item provider, so it can answer them rather than only read through an application's object.
   The two protocols stay `ignored` in the registry and their own effect says why - an application's
   class adopts them and -registerObject:visibility: and -loadObjectOfClass:completionHandler: read
   the four members a conforming object has to answer.

   The type identifiers are the ones this provider has registered, which is the only thing either
   member can mean of an object that carries nothing else. The visibility is the one the caller handed
   the registration, which the port used to take and drop. The class answer is All, the enumeration's
   own case for a class that registers nothing narrower. +objectWithItemProviderData:...: builds a
   provider over the data and hands out the documented failure rather than raising when the type
   identifier is empty or the data is nil. */

- (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider
{
    return [self registeredTypeIdentifiers];
}

- (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider
{
    return [self registeredTypeIdentifiers];
}

+ (NSItemProviderRepresentationVisibility)itemProviderVisibilityForRepresentationWithTypeIdentifier:(NSString *)typeIdentifier
{
    (void)typeIdentifier;
    return NSItemProviderRepresentationVisibilityAll;
}

- (NSItemProviderRepresentationVisibility)itemProviderVisibilityForRepresentationWithTypeIdentifier:(NSString *)typeIdentifier
{
    (void)typeIdentifier;
    /* The narrowest of the registered visibilities, and nothing else: the widest one was computed
       here and never read, which is a variable that lies about what the method does. */
    NSItemProviderRepresentationVisibility narrowest = NSItemProviderRepresentationVisibilityAll;
    BOOL any = NO;
    for (CharonRepresentation *representation in _representations) {
        any = YES;
        if (representation->_visibility > narrowest)
            narrowest = representation->_visibility;
    }
    /* A provider registered with mixed visibilities is only as visible as its least visible member:
       anything else would claim a representation the receiver is not allowed to see. */
    return any ? narrowest : NSItemProviderRepresentationVisibilityAll;
}

- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)typeIdentifier forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    return [self loadDataRepresentationForTypeIdentifier:typeIdentifier completionHandler:completionHandler];
}

+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier error:(NSError **)error
{
    if (!typeIdentifier.length || !data) {
        if (error)
            *error = charon_error(-1000);
        return nil;
    }
    NSItemProvider *provider = [[NSItemProvider alloc] init];
    [provider registerDataRepresentationForTypeIdentifier:typeIdentifier
                                               visibility:NSItemProviderRepresentationVisibilityAll
                                             loadHandler:^NSProgress *(void (^done)(NSData *, NSError *)) {
        done(data, nil);
        return [NSProgress progressWithTotalUnitCount:1];
    }];
    return provider;
}

- (instancetype)initWithObject:(id<NSItemProviderWriting>)object
{
    self = [self init];
    if (self)
        [self registerObject:object visibility:NSItemProviderRepresentationVisibilityAll];
    return self;
}

- (void)registerObject:(id<NSItemProviderWriting>)object visibility:(NSItemProviderRepresentationVisibility)visibility
{
    for (NSString *type in [(id)object writableTypeIdentifiersForItemProvider]) {
        [self registerDataRepresentationForTypeIdentifier:type visibility:visibility loadHandler:^NSProgress *(void (^completionHandler)(NSData *, NSError *)) {
            return [object loadDataWithTypeIdentifier:type forItemProviderCompletionHandler:completionHandler];
        }];
    }
}

- (void)registerObjectOfClass:(Class<NSItemProviderWriting>)aClass visibility:(NSItemProviderRepresentationVisibility)visibility loadHandler:(NSProgress * _Nullable (^)(void (^)(__kindof id<NSItemProviderWriting> _Nullable, NSError * _Nullable)))loadHandler
{
    for (NSString *type in [(id)aClass writableTypeIdentifiersForItemProvider]) {
        [self registerDataRepresentationForTypeIdentifier:type visibility:visibility loadHandler:^NSProgress *(void (^completionHandler)(NSData *, NSError *)) {
            return loadHandler(^(id<NSItemProviderWriting> object, NSError *error) {
                if (!object) {
                    completionHandler(nil, error ?: charon_error(-1000));
                    return;
                }
                [object loadDataWithTypeIdentifier:type forItemProviderCompletionHandler:completionHandler];
            });
        }];
    }
}

- (BOOL)canLoadObjectOfClass:(Class<NSItemProviderReading>)aClass
{
    for (NSString *type in [(id)aClass readableTypeIdentifiersForItemProvider]) {
        if ([self hasItemConformingToTypeIdentifier:type])
            return YES;
    }
    return NO;
}

- (NSProgress *)loadObjectOfClass:(Class<NSItemProviderReading>)aClass completionHandler:(void (^)(__kindof id<NSItemProviderReading> _Nullable, NSError * _Nullable))completionHandler
{
    void (^reply)(__kindof id<NSItemProviderReading>, NSError *) = [completionHandler copy];
    for (NSString *type in [(id)aClass readableTypeIdentifiersForItemProvider]) {
        if ([self hasItemConformingToTypeIdentifier:type]) {
            return [self loadDataRepresentationForTypeIdentifier:type completionHandler:^(NSData *data, NSError *error) {
                if (!data) {
                    reply(nil, error);
                    return;
                }
                NSError *readError = nil;
                id object = [aClass objectWithItemProviderData:data typeIdentifier:type error:&readError];
                reply(object, object ? nil : readError);
            }];
        }
    }
    reply(nil, charon_error(-1000));
    return [NSProgress progressWithTotalUnitCount:1];
}

@end
