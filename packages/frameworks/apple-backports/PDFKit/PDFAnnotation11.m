#import "RevenantPDFKit.h"

static const CGFloat kTextAnnotationSize = 24.0;

@interface PDFAnnotation ()
- (nullable CGPDFDictionaryRef)revenant_CGPDFAnnotation;
@end

@implementation PDFAnnotation {
    CGPDFDictionaryRef _annotation;
    __weak PDFPage *_page;
    NSString *_type;
    NSString *_contents;
    NSString *_userName;
    NSDate *_modificationDate;
    PDFBorder *_border;
    PDFAction *_action;
    PDFDestination *_destination;
    BOOL _borderSet;
}

- (instancetype)initWithRevenantDictionary:(CGPDFDictionaryRef)annotation onPage:(PDFPage *)page
{
    self = [super init];
    if (self == nil)
        return nil;
    _annotation = annotation;
    _page = page;
    return self;
}

- (CGPDFDictionaryRef)revenant_CGPDFAnnotation
{
    return _annotation;
}

@dynamic bounds;
@dynamic shouldPrint;

@synthesize type = _type;
@synthesize contents = _contents;
@synthesize userName = _userName;
@synthesize modificationDate = _modificationDate;
@synthesize page = _page;
@synthesize border = _border;
@synthesize action = _action;
@synthesize destination = _destination;

- (NSString *)type
{
    if (_type != nil)
        return _type;
    const char *name = NULL;
    if (!CGPDFDictionaryGetName(_annotation, "Subtype", &name) || name == NULL)
        return nil;
    _type = [[NSString alloc] initWithUTF8String:name];
    return _type;
}

- (CGRect)bounds
{
    if (_type == nil)
        [self type];
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, "Rect", &object) || object == NULL)
        return CGRectZero;
    if (CGPDFObjectGetType(object) != kCGPDFObjectTypeArray)
        return CGRectZero;
    CGPDFArrayRef array = NULL;
    if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array) || array == NULL)
        return CGRectZero;
    CGFloat number[4] = {0, 0, 0, 0};
    for (size_t i = 0; i < 4; i++) {
        CGPDFObjectRef element = NULL;
        if (!CGPDFArrayGetObject(array, i, &element) || element == NULL)
            return CGRectZero;
        if (CGPDFObjectGetType(element) == kCGPDFObjectTypeInteger) {
            long integer = 0;
            if (!CGPDFObjectGetValue(element, kCGPDFObjectTypeInteger, &integer))
                return CGRectZero;
            number[i] = (CGFloat)integer;
        } else if (CGPDFObjectGetValue(element, kCGPDFObjectTypeReal, &number[i]) == false) {
            return CGRectZero;
        }
    }
    CGRect rect = CGRectMake(number[0], number[1], number[2] - number[0], number[3] - number[1]);
    if ([_type isEqualToString:@"Text"])
        return CGRectMake(CGRectGetMinX(rect), CGRectGetMaxY(rect) - kTextAnnotationSize,
                         kTextAnnotationSize, kTextAnnotationSize);
    return rect;
}

- (NSString *)revenant_stringForKey:(const char *)key
{
    if (_annotation == NULL)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, key, &object) || object == NULL)
        return nil;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type != kCGPDFObjectTypeString)
        return nil;
    CGPDFStringRef string = NULL;
    if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeString, &string) || string == NULL)
        return nil;
    CFStringRef text = CGPDFStringCopyTextString(string);
    if (text == NULL)
        return nil;
    NSString *answer = (__bridge_transfer NSString *)text;
    return answer;
}

- (NSString *)contents
{
    if (_contents != nil)
        return _contents;
    _contents = [self revenant_stringForKey:"Contents"];
    return _contents;
}

- (NSString *)userName
{
    if (_userName != nil)
        return _userName;
    if (_type == nil)
        [self type];
    if ([_type isEqualToString:@"Widget"])
        return nil;
    _userName = [self revenant_stringForKey:"T"];
    return _userName;
}

- (NSDate *)modificationDate
{
    if (_modificationDate != nil)
        return _modificationDate;
    NSString *date = [self revenant_stringForKey:"M"];
    if (date.length < 16 || ![date hasPrefix:@"D:"])
        return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    _modificationDate = [formatter dateFromString:[date substringFromIndex:2]];
    return _modificationDate;
}

- (BOOL)shouldPrint
{
    if (_annotation == NULL)
        return NO;
    if (_type == nil)
        [self type];
    if ([_type isEqualToString:@"Popup"])
        return NO;
    long flags = 0;
    if (!CGPDFDictionaryGetInteger(_annotation, "F", &flags))
        return YES;
    return (flags & 4) != 0;
}

- (PDFPage *)page
{
    return _page;
}

- (void)setBorder:(PDFBorder *)border
{
    _border = border;
    _borderSet = YES;
}

- (PDFAction *)action
{
    if (_action != nil)
        return _action;
    if (_annotation == NULL)
        return nil;
    CGPDFDictionaryRef action = NULL;
    if (CGPDFDictionaryGetDictionary(_annotation, "A", &action) && action != NULL) {
        _action = [PDFAction revenant_actionWithDictionary:action inDocument:[self revenant_document]];
        return _action;
    }
    if (![self revenant_hasDestination])
        return nil;
    PDFDestination *destination = [self revenant_destinationFromDest];
    if (destination == nil)
        return nil;
    _action = [[PDFActionGoTo alloc] initWithDestination:destination];
    return _action;
}

- (PDFDestination *)revenant_destinationFromDest
{
    if (_destination != nil)
        return _destination;
    if (_annotation == NULL)
        return nil;
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, "Dest", &object) || object == NULL)
        return nil;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    if (type == kCGPDFObjectTypeArray) {
        CGPDFArrayRef array = NULL;
        if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array) || array == NULL)
            return nil;
        _destination = [[PDFDestination alloc] initWithRevenantDestinationArray:array
                                                                    inDocument:[self revenant_document]];
        return _destination;
    }
    if (type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString) {
        _destination = [[PDFDestination alloc] initWithRevenantDestinationArray:NULL
                                                                    inDocument:[self revenant_document]];
        return _destination;
    }
    return nil;
}

- (PDFDestination *)destination
{
    PDFAction *action = [self action];
    if (![action isKindOfClass:[PDFActionGoTo class]])
        return nil;
    return [(PDFActionGoTo *)action destination];
}

- (BOOL)revenant_hasDestination
{
    CGPDFObjectRef object = NULL;
    if (!CGPDFDictionaryGetObject(_annotation, "Dest", &object) || object == NULL)
        return NO;
    CGPDFObjectType type = CGPDFObjectGetType(object);
    return type == kCGPDFObjectTypeArray || type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString
           || type == kCGPDFObjectTypeDictionary;
}

- (PDFDocument *)revenant_document
{
    return [_page document];
}
- (PDFBorder *)border
{
    if (_borderSet)
        return _border;
    if (_annotation == NULL)
        return nil;
    if (_border != nil)
        return _border;
    NSString *type = [self type];
    BOOL named = NO;
    CGPDFObjectRef object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "Border", &object) && object != NULL)
        named = YES;
    object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "BS", &object) && object != NULL)
        named = YES;
    if (!named) {
        if ([type isEqualToString:@"Square"] || [type isEqualToString:@"Circle"]
            || [type isEqualToString:@"Ink"] || [type isEqualToString:@"Line"]
            || [type isEqualToString:@"FreeText"]) {
            named = YES;
        } else if ([type isEqualToString:@"Widget"]) {
            CGPDFObjectRef mark = NULL;
            if (CGPDFDictionaryGetObject(_annotation, "MK", &mark) && mark != NULL
                && CGPDFObjectGetType(mark) == kCGPDFObjectTypeDictionary) {
                CGPDFDictionaryRef appearance = NULL;
                if (CGPDFObjectGetValue(mark, kCGPDFObjectTypeDictionary, &appearance)
                    && appearance != NULL) {
                    CGPDFArrayRef colour = NULL;
                    if (CGPDFDictionaryGetArray(appearance, "BC", &colour) && colour != NULL) {
                        size_t components = CGPDFArrayGetCount(colour);
                        if (components == 0 || components == 1 || components == 3 || components == 4)
                            named = YES;
                    }
                }
            }
        }
    }
    if (!named)
        return nil;
    _border = [[PDFBorder alloc] initWithRevenantAnnotationDictionary:_annotation];
    return _border;
}

- (BOOL)hasAppearanceStream
{
    if (_annotation == NULL)
        return NO;
    CGPDFDictionaryRef appearance = NULL;
    if (!CGPDFDictionaryGetDictionary(_annotation, "AP", &appearance) || appearance == NULL)
        return NO;
    CGPDFStreamRef normal = NULL;
    return CGPDFDictionaryGetStream(appearance, "N", &normal) && normal != NULL;
}

- (BOOL)open
{
    if (_annotation == NULL)
        return NO;
    CGPDFBoolean open = NO;
    return CGPDFDictionaryGetBoolean(_annotation, "Open", &open) && open;
}

- (nullable NSURL *)URL
{
    PDFAction *action = self.action;
    if (![action isKindOfClass:[PDFActionURL class]])
        return nil;
    return ((PDFActionURL *)action).URL;
}

@end

@implementation PDFAnnotation (PDFAnnotationUtilitiesSubset)

@dynamic readOnly;
@dynamic multiline;
@dynamic isPasswordField;
@dynamic comb;
@dynamic allowsToggleToOff;
@dynamic radiosInUnison;
@dynamic listChoice;
@dynamic widgetControlType;
@dynamic activatableTextField;
@dynamic fieldName;
@dynamic buttonWidgetStateString;
@dynamic buttonWidgetState;

typedef struct { NSString *onState; } RevenantOnState;

static void revenantTakeOnState(const char *key, CGPDFObjectRef value, void *info)
{
    RevenantOnState *state = (RevenantOnState *)info;
    if (key == NULL || state == NULL || state->onState != nil)
        return;
    if (strcmp(key, "Off") == 0)
        return;
    state->onState = [[NSString alloc] initWithUTF8String:key];
}

- (NSString *)buttonWidgetStateString
{
    if (_annotation == NULL)
        return @"Yes";
    CGPDFDictionaryRef appearance = NULL;
    if (!CGPDFDictionaryGetDictionary(_annotation, "AP", &appearance) || appearance == NULL)
        return @"Yes";
    CGPDFDictionaryRef normal = NULL;
    if (!CGPDFDictionaryGetDictionary(appearance, "N", &normal) || normal == NULL)
        return @"Yes";
    RevenantOnState state = {nil};
    CGPDFDictionaryApplyFunction(normal, revenantTakeOnState, &state);
    return state.onState ?: @"Yes";
}

- (NSInteger)buttonWidgetState
{
    if (_annotation == NULL)
        return -1;
    const char *fieldType = NULL;
    if (!CGPDFDictionaryGetName(_annotation, "FT", &fieldType) || fieldType == NULL)
        return -1;
    if (strcmp(fieldType, "Btn") != 0)
        return -1;
    NSString *onState = [self buttonWidgetStateString];
    NSString *appearance = nil;
    NSString *value = nil;
    CGPDFObjectRef object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "AS", &object) && object != NULL
        && CGPDFObjectGetType(object) == kCGPDFObjectTypeName) {
        const char *name = NULL;
        if (CGPDFObjectGetValue(object, kCGPDFObjectTypeName, &name) && name != NULL)
            appearance = [[NSString alloc] initWithUTF8String:name];
    }
    object = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "V", &object) && object != NULL
        && CGPDFObjectGetType(object) == kCGPDFObjectTypeName) {
        const char *name = NULL;
        if (CGPDFObjectGetValue(object, kCGPDFObjectTypeName, &name) && name != NULL)
            value = [[NSString alloc] initWithUTF8String:name];
    }
    if (appearance != nil && [appearance isEqualToString:onState])
        return 1;
    if (value != nil && [value isEqualToString:onState])
        return 1;
    if (appearance != nil && ![appearance isEqualToString:@"Off"] && value != nil
        && ![value isEqualToString:@"Off"])
        return 1;
    return 0;
}

- (CGPDFDictionaryRef)revenant_CGPDFDictionary
{
    return _annotation;
}

- (long)revenant_flags
{
    long flags = 0;
    if (_annotation == NULL)
        return 0;
    if (!CGPDFDictionaryGetInteger(_annotation, "Ff", &flags))
        return 0;
    return flags;
}

- (BOOL)isReadOnly
{
    return ([self revenant_flags] & (1 << 0)) != 0;
}

- (BOOL)isMultiline
{
    return ([self revenant_flags] & (1 << 12)) != 0;
}

- (BOOL)isPasswordField
{
    return ([self revenant_flags] & (1 << 13)) != 0;
}

- (BOOL)hasComb
{
    return ([self revenant_flags] & (1 << 24)) != 0;
}

- (BOOL)allowsToggleToOff
{
    return ([self revenant_flags] & ((1 << 14) | (1 << 16))) == 0;
}

- (BOOL)radiosInUnison
{
    return ([self revenant_flags] & (1 << 25)) != 0;
}

- (BOOL)isListChoice
{
    return ([self revenant_flags] & (1 << 17)) == 0;
}

- (PDFWidgetControlType)widgetControlType
{
    long flags = [self revenant_flags];
    if ((flags & (1 << 15)) != 0)
        return kPDFWidgetRadioButtonControl;
    if ((flags & (1 << 16)) != 0)
        return kPDFWidgetPushButtonControl;
    return kPDFWidgetCheckBoxControl;
}

- (NSString *)fieldName
{
    if (_annotation == NULL)
        return nil;
    NSString *own = nil;
    CGPDFObjectRef title = NULL;
    if (CGPDFDictionaryGetObject(_annotation, "T", &title) && title != NULL
        && CGPDFObjectGetType(title) == kCGPDFObjectTypeString) {
        CGPDFStringRef string = NULL;
        if (CGPDFObjectGetValue(title, kCGPDFObjectTypeString, &string) && string != NULL) {
            CFStringRef text = CGPDFStringCopyTextString(string);
            if (text != NULL)
                own = (__bridge_transfer NSString *)text;
        }
    }
    NSString *inherited = nil;
    CGPDFDictionaryRef parent = NULL;
    if (CGPDFDictionaryGetDictionary(_annotation, "Parent", &parent) && parent != NULL) {
        CGPDFObjectRef parentTitle = NULL;
        if (CGPDFDictionaryGetObject(parent, "T", &parentTitle) && parentTitle != NULL
            && CGPDFObjectGetType(parentTitle) == kCGPDFObjectTypeString) {
            CGPDFStringRef string = NULL;
            if (CGPDFObjectGetValue(parentTitle, kCGPDFObjectTypeString, &string) && string != NULL) {
                CFStringRef text = CGPDFStringCopyTextString(string);
                if (text != NULL)
                    inherited = (__bridge_transfer NSString *)text;
            }
        }
    }
    if (inherited == nil)
        return own;
    if (own == nil)
        return inherited;
    return [NSString stringWithFormat:@"%@.%@", inherited, own];
}

- (BOOL)isActivatableTextField
{
    const char *fieldType = NULL;
    if (_annotation == NULL || !CGPDFDictionaryGetName(_annotation, "FT", &fieldType)
        || fieldType == NULL || strcmp(fieldType, "Tx") != 0)
        return NO;
    return ![self isReadOnly];
}

@end
