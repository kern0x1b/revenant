#import "RevenantPDFKit.h"

static Class revenantActionClassForName(const char *name)
{
    if (name == NULL)
        return Nil;
    if (strcmp(name, "GoTo") == 0)
        return [PDFActionGoTo class];
    if (strcmp(name, "Named") == 0)
        return [PDFActionNamed class];
    if (strcmp(name, "URI") == 0)
        return [PDFActionURL class];
    if (strcmp(name, "GoToR") == 0)
        return [PDFActionRemoteGoTo class];
    if (strcmp(name, "ResetForm") == 0)
        return [PDFActionResetForm class];
    return [PDFAction class];
}

static BOOL revenantNamedActionValue(const char *name, PDFActionNamedName *out)
{
    if (name == NULL)
        return NO;
    if (strcmp(name, "NextPage") == 0) { *out = kPDFActionNamedNextPage; return YES; }
    if (strcmp(name, "FirstPage") == 0) { *out = kPDFActionNamedFirstPage; return YES; }
    if (strcmp(name, "LastPage") == 0) { *out = kPDFActionNamedLastPage; return YES; }
    if (strcmp(name, "GoBack") == 0) { *out = kPDFActionNamedGoBack; return YES; }
    if (strcmp(name, "GoForward") == 0) { *out = kPDFActionNamedGoForward; return YES; }
    if (strcmp(name, "GoToPage") == 0) { *out = kPDFActionNamedGoToPage; return YES; }
    if (strcmp(name, "Find") == 0) { *out = kPDFActionNamedFind; return YES; }
    if (strcmp(name, "Print") == 0) { *out = kPDFActionNamedPrint; return YES; }
    return NO;
}

static const char *revenantActionName(CGPDFDictionaryRef action)
{
    const char *name = NULL;
    if (!CGPDFDictionaryGetName(action, "S", &name))
        return NULL;
    return name;
}

static NSString *revenantActionString(CGPDFDictionaryRef action, const char *key)
{
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(action, key, &object) || object == NULL)
        return nil;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type == kCGPDFObjectTypeString) {
        CGPDFStringRef string = NULL;
        if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeString, &string) || string == NULL)
            return nil;
        CFStringRef text = CGPDFStringCopyTextString(string);
        if (text == NULL)
            return nil;
        return (__bridge_transfer NSString *)text;
    }
    if (type == kCGPDFObjectTypeName) {
        const char *name = NULL;
        if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeName, &name) || name == NULL)
            return nil;
        return [[NSString alloc] initWithUTF8String:name];
    }
    return nil;
}

@implementation PDFAction {
    NSString *_type;
}

@synthesize type = _type;

- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    return self;
}

- (NSString *)type
{
    return _type;
}

- (void)revenant_setTypeName:(NSString *)name
{
    _type = [name copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFAction *copy = [[[self class] alloc] init];
    copy->_type = _type;
    return copy;
}

+ (instancetype)revenant_actionWithDictionary:(CGPDFDictionaryRef)action inDocument:(PDFDocument *)document
{
    if (action == NULL)
        return nil;
    const char *name = revenantActionName(action);
    if (name == NULL)
        return nil;
    if (strcmp(name, "Named") == 0)
        return [[PDFActionNamed alloc] initWithRevenantActionDictionary:action];
    if (strcmp(name, "Launch") == 0)
        return [[PDFActionURL alloc] initWithRevenantLaunchDictionary:action inDocument:document];
    Class chosen = revenantActionClassForName(name);
    if (chosen == [PDFActionGoTo class])
        return [[PDFActionGoTo alloc] initWithRevenantActionDictionary:action inDocument:document];
    if (chosen == [PDFActionURL class])
        return [[PDFActionURL alloc] initWithRevenantActionDictionary:action];
    if (chosen == [PDFActionRemoteGoTo class])
        return [[PDFActionRemoteGoTo alloc] initWithRevenantActionDictionary:action inDocument:document];
    if (chosen == [PDFActionResetForm class])
        return [[PDFActionResetForm alloc] initWithRevenantActionDictionary:action];
    PDFAction *plain = [[PDFAction alloc] init];
    [plain revenant_setTypeName:[NSString stringWithUTF8String:name]];
    return plain;
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFActionGoTo {

    PDFDestination *_destination;
}

@synthesize destination = _destination;

- (instancetype)initWithDestination:(PDFDestination *)destination
{
    self = [super init];
    if (self == nil)
        return nil;
    _destination = destination;
    [self revenant_setTypeName:@"GoTo"];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFActionGoTo *copy = (PDFActionGoTo *)[super copyWithZone:zone];
    copy->_destination = [_destination copy];
    return copy;
}

- (instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action inDocument:(PDFDocument *)document
{
    self = [self initWithDestination:nil];
    if (self == nil)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(action, "D", &object) || object == NULL)
        return self;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type == kCGPDFObjectTypeArray) {
        CGPDFArrayRef array = NULL;
        if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array) || array == NULL)
            return self;
        _destination = [[PDFDestination alloc] initWithRevenantDestinationArray:array
                                                                    inDocument:document];
    } else if (type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString) {
        _destination = [[PDFDestination alloc] initWithRevenantDestinationArray:NULL
                                                                    inDocument:document];
    }
    return self;
}

@end
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFActionNamed {

    PDFActionNamedName _name;
}

@synthesize name = _name;

- (instancetype)initWithName:(PDFActionNamedName)name
{
    self = [super init];
    if (self == nil)
        return nil;
    _name = name;
    [self revenant_setTypeName:@"Named"];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFActionNamed *copy = (PDFActionNamed *)[super copyWithZone:zone];
    copy->_name = _name;
    return copy;
}

- (instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action
{
    NSString *name = revenantActionString(action, "N");
    if (name == nil)
        return nil;
    PDFActionNamedName value = kPDFActionNamedNone;
    if (!revenantNamedActionValue([name UTF8String], &value))
        return nil;
    return [self initWithName:value];
}

@end
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFActionURL {

    NSURL *_url;
}

@synthesize URL = _url;

- (id)copyWithZone:(NSZone *)zone
{
    PDFActionURL *copy = (PDFActionURL *)[super copyWithZone:zone];
    copy->_url = _url;
    return copy;
}

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self == nil)
        return nil;
    _url = [url copy];
    [self revenant_setTypeName:@"URI"];
    return self;
}

- (instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action
{
    self = [self initWithURL:nil];
    if (self == nil)
        return nil;
    NSString *uri = revenantActionString(action, "URI");
    if (uri != nil)
        _url = [NSURL URLWithString:uri];
    return self;
}

- (nullable instancetype)initWithRevenantLaunchDictionary:(CGPDFDictionaryRef)action
                                             inDocument:(nullable PDFDocument *)document
{
    self = [self initWithURL:nil];
    if (self == nil)
        return nil;
    [self revenant_setTypeName:@"Launch"];
    NSString *file = revenantActionString(action, "F");
    if (file == nil) {
        CGPDFDictionaryRef spec = NULL;
        if (CGPDFDictionaryGetDictionary(action, "F", &spec) && spec != NULL)
            file = revenantActionString(spec, "F");
    }
    NSURL *documentURL = [document documentURL];
    if (file != nil && documentURL != nil) {
        NSString *directory = [[documentURL path] stringByDeletingLastPathComponent];
        _url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", directory, file]];
    }
    return self;
}

@end
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFActionRemoteGoTo {
    NSUInteger _pageIndex;
    CGPoint _point;
    NSURL *_url;
    BOOL _pointIsSet;
}

@synthesize pageIndex = _pageIndex;
@synthesize URL = _url;

- (CGPoint)point
{
    if (!_pointIsSet)
        return CGPointMake(kPDFDestinationUnspecifiedValue, kPDFDestinationUnspecifiedValue);
    return _point;
}

- (void)setPoint:(CGPoint)point
{
    _point = point;
    _pointIsSet = YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFActionRemoteGoTo *copy = (PDFActionRemoteGoTo *)[super copyWithZone:zone];
    copy->_pageIndex = _pageIndex;
    copy->_point = _point;
    copy->_pointIsSet = _pointIsSet;
    copy->_url = _url;
    return copy;
}

- (instancetype)initWithPageIndex:(NSUInteger)pageIndex atPoint:(CGPoint)point fileURL:(NSURL *)url
{
    self = [super init];
    if (self == nil)
        return nil;
    _pageIndex = pageIndex;
    _point = point;
    _pointIsSet = YES;
    _url = [url copy];
    [self revenant_setTypeName:@"GoToR"];
    return self;
}

- (instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action inDocument:(PDFDocument *)document
{
    self = [self initWithPageIndex:0
                           atPoint:CGPointMake(kPDFDestinationUnspecifiedValue,
                                               kPDFDestinationUnspecifiedValue)
                           fileURL:nil];
    if (self == nil)
        return nil;
    _pointIsSet = NO;
    NSString *file = revenantActionString(action, "F");
    NSURL *documentURL = [document documentURL];
    if (file != nil && documentURL != nil) {
        NSString *directory = [[documentURL path] stringByDeletingLastPathComponent];
        _url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", directory, file]];
    }
    return self;
}

@end
#pragma clang diagnostic pop

@implementation PDFActionResetForm {
    NSArray<NSString *> *_fields;
    BOOL _fieldsIncludedAreCleared;
}

@synthesize fields = _fields;
@synthesize fieldsIncludedAreCleared = _fieldsIncludedAreCleared;

- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _fieldsIncludedAreCleared = YES;
    [self revenant_setTypeName:@"ResetForm"];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFActionResetForm *copy = (PDFActionResetForm *)[super copyWithZone:zone];
    copy->_fields = _fields;
    copy->_fieldsIncludedAreCleared = _fieldsIncludedAreCleared;
    return copy;
}

- (instancetype)initWithRevenantActionDictionary:(CGPDFDictionaryRef)action
{
    self = [self init];
    if (self == nil)
        return nil;
    CGPDFArrayRef fields = NULL;
    if (CGPDFDictionaryGetArray(action, "Fields", &fields) && fields != NULL) {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        size_t count = CGPDFArrayGetCount(fields);
        for (size_t i = 0; i < count; i++) {
            CGPDFObjectRef element = NULL;
            if (!CGPDFArrayGetObject(fields, i, &element) || element == NULL)
                continue;
            CGPDFObjectType type = CGPDFObjectGetType(element);
            NSString *name = nil;
            if (type == kCGPDFObjectTypeString) {
                CGPDFStringRef string = NULL;
                if (CGPDFObjectGetValue(element, kCGPDFObjectTypeString, &string) && string != NULL) {
                    CFStringRef text = CGPDFStringCopyTextString(string);
                    if (text != NULL)
                        name = (__bridge_transfer NSString *)text;
                }
            } else if (type == kCGPDFObjectTypeName) {
                const char *value = NULL;
                if (CGPDFObjectGetValue(element, kCGPDFObjectTypeName, &value) && value != NULL)
                    name = [[NSString alloc] initWithUTF8String:value];
            }
            if (name != nil)
                [names addObject:name];
        }
        _fields = names;
        long flags = 0;
        if (!CGPDFDictionaryGetInteger(action, "Flags", &flags))
            flags = 0;
        _fieldsIncludedAreCleared = (flags & 1) == 0;
    } else {
        _fieldsIncludedAreCleared = NO;
    }
    return self;
}

@end
