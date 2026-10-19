#import "CharonPDFKit.h"

@implementation PDFOutline {
    CGPDFDictionaryRef _item;
    __weak PDFDocument *_document;
    __weak PDFOutline *_parent;
    NSString *_label;
    NSUInteger _index;
    NSArray *_children;
}

- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _label = @"";
    return self;
}

@synthesize document = _document;
@synthesize parent = _parent;
@synthesize label = _label;
@synthesize index = _index;

- (NSArray *)charon_children
{
    if (_children != nil)
        return _children;
    NSMutableArray *answer = [NSMutableArray array];
    if (_item != NULL) {
        CGPDFDictionaryRef child = NULL;
        if (CGPDFDictionaryGetDictionary(_item, "First", &child) && child != NULL) {
            while (child != NULL && [answer count] < 4096) {
                PDFOutline *outline = [[PDFOutline alloc] initWithCharonItem:child
                                                                  document:_document
                                                                     parent:self
                                                                      index:[answer count]];
                if (outline == nil)
                    break;
                [answer addObject:outline];
                CGPDFDictionaryRef next = NULL;
                if (!CGPDFDictionaryGetDictionary(child, "Next", &next) || next == NULL)
                    break;
                child = next;
            }
        }
    }
    _children = answer;
    return _children;
}

- (NSUInteger)numberOfChildren
{
    return [self charon_children].count;
}

- (PDFOutline *)childAtIndex:(NSUInteger)index
{
    NSArray *children = [self charon_children];
    if (index >= children.count) {
        if (children.count > 0) {
            [NSException raise:NSRangeException
                        format:@"childAtIndex: %lu out of bounds", (unsigned long)index];
            return nil;
        }
        return nil;
    }
    return children[index];
}

- (NSString *)label
{
    return _label;
}

- (BOOL)isOpen
{
    if (_item == NULL)
        return NO;
    long count = 0;
    if (CGPDFDictionaryGetInteger(_item, "Count", &count))
        return count > 0;
    CGPDFObjectRef title = NULL;
    if (CGPDFDictionaryGetObject(_item, "Title", &title) && title != NULL)
        return NO;
    return YES;
}

- (PDFDestination *)destination
{
    if (_item == NULL)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_item, "Dest", &object) || object == NULL)
        return nil;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type == kCGPDFObjectTypeArray) {
        CGPDFArrayRef array = NULL;
        if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array) || array == NULL)
            return nil;
        return [[PDFDestination alloc] initWithCharonDestinationArray:array inDocument:_document];
    }
    if (type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString)
        return [[PDFDestination alloc] initWithCharonDestinationArray:NULL inDocument:_document];
    return nil;
}

- (PDFAction *)action
{
    if (_item == NULL)
        return nil;
    CGPDFObjectRef dest = NULL;
    if (CGPDFDictionaryGetObject(_item, "Dest", &dest) && dest != NULL) {
        PDFDestination *destination = [self destination];
        if (destination == nil)
            return nil;
        return [[PDFActionGoTo alloc] initWithDestination:destination];
    }
    CGPDFDictionaryRef action = NULL;
    if (!CGPDFDictionaryGetDictionary(_item, "A", &action) || action == NULL)
        return nil;
    return [PDFAction charon_actionWithDictionary:action inDocument:_document];
}

@end

@implementation PDFOutline (CharonInternals)

- (instancetype)initWithCharonItem:(CGPDFDictionaryRef)item
                           document:(nullable PDFDocument *)document
                             parent:(nullable PDFOutline *)parent
                              index:(NSUInteger)index
{
    self = [self init];
    if (self == nil)
        return nil;
    _item = item;
    _document = document;
    _parent = parent;
    _index = index;
    _label = [self charon_title] ?: @"";
    return self;
}

- (NSString *)charon_title
{
    if (_item == NULL)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_item, "Title", &object) || object == NULL)
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

@end
