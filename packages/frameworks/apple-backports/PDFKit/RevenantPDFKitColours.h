#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

#define REVENANT_ANNOTATION_FONT_DEFAULT_NAME @"Helvetica"
#define REVENANT_ANNOTATION_FONT_DEFAULT_SIZE ((CGFloat)12)

static inline BOOL revenant_annotation_number(CGPDFArrayRef array, size_t index, double *out)
{
    CGPDFObjectRef component = NULL;
    if (!CGPDFArrayGetObject(array, index, &component) || component == NULL)
        return NO;
    switch (CGPDFObjectGetType(component)) {
    case kCGPDFObjectTypeInteger: {
        long integer = 0;
        if (!CGPDFObjectGetValue(component, kCGPDFObjectTypeInteger, &integer))
            return NO;
        *out = (double)integer;
        return YES;
    }
    case kCGPDFObjectTypeReal: {
        double real = 0;
        if (!CGPDFObjectGetValue(component, kCGPDFObjectTypeReal, &real))
            return NO;
        *out = real;
        return YES;
    }
    default:
        return NO;
    }
}

static inline CGColorRef revenant_annotation_device_colour(CGPDFArrayRef array)
{
    if (array == NULL)
        return NULL;
    size_t components = CGPDFArrayGetCount(array);
    CGColorSpaceRef space = NULL;
    if (components == 1)
        space = CGColorSpaceCreateDeviceGray();
    else if (components == 3)
        space = CGColorSpaceCreateDeviceRGB();
    else if (components == 4)
        space = CGColorSpaceCreateDeviceCMYK();
    if (space == NULL)
        return NULL;
    CGFloat values[5] = {0, 0, 0, 0, 0};
    for (size_t i = 0; i < components; i++) {
        double component = 0;
        if (!revenant_annotation_number(array, i, &component)) {
            CGColorSpaceRelease(space);
            return NULL;
        }
        values[i] = (CGFloat)component;
    }
    values[components] = 1;
    CGColorRef colour = CGColorCreate(space, values);
    CGColorSpaceRelease(space);
    return colour;
}

static inline CGColorRef revenant_annotation_named_colour(CFStringRef name, const CGFloat *components,
                                                        size_t count)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    if (space == NULL)
        return NULL;
    CGColorRef colour = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return colour;
}

static inline CGColorRef revenant_annotation_colour_for_key(CGPDFDictionaryRef annotation, const char *key,
                                                          bool appearance)
{
    if (annotation == NULL)
        return NULL;
    CGPDFArrayRef array = NULL;
    if (appearance) {
        CGPDFObjectRef mark = NULL;
        if (!CGPDFDictionaryGetObject(annotation, "MK", &mark) || mark == NULL
            || CGPDFObjectGetType(mark) != kCGPDFObjectTypeDictionary)
            return NULL;
        CGPDFDictionaryRef appearanceDictionary = NULL;
        if (!CGPDFObjectGetValue(mark, kCGPDFObjectTypeDictionary, &appearanceDictionary)
            || appearanceDictionary == NULL)
            return NULL;
        if (!CGPDFDictionaryGetArray(appearanceDictionary, key, &array) || array == NULL)
            return NULL;
    } else {
        CGPDFObjectRef found = NULL;
        if (!CGPDFDictionaryGetObject(annotation, key, &found) || found == NULL
            || CGPDFObjectGetType(found) != kCGPDFObjectTypeArray)
            return NULL;
        if (!CGPDFObjectGetValue(found, kCGPDFObjectTypeArray, &array) || array == NULL)
            return NULL;
    }
    return revenant_annotation_device_colour(array);
}

static inline CGColorRef revenant_annotation_background_colour(CGPDFDictionaryRef annotation)
{
    return revenant_annotation_colour_for_key(annotation, "BG", true);
}

static inline CGColorRef revenant_annotation_interior_colour(CGPDFDictionaryRef annotation)
{
    return revenant_annotation_colour_for_key(annotation, "IC", false);
}

static inline NSArray *revenant_annotation_da_tokens(NSString *text)
{
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *word in [text componentsSeparatedByCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (word.length == 0)
            continue;
        [tokens addObject:word];
    }
    return tokens;
}

static inline BOOL revenant_annotation_da_is_operator(NSString *token, NSString *wanted)
{
    return ![token hasPrefix:@"/"] && [token isEqualToString:wanted];
}

static inline NSString *revenant_annotation_da_text(CGPDFDictionaryRef annotation, bool *present)
{
    *present = NO;
    if (annotation == NULL)
        return nil;
    CGPDFObjectRef found = NULL;
    if (!CGPDFDictionaryGetObject(annotation, "DA", &found) || found == NULL
        || CGPDFObjectGetType(found) != kCGPDFObjectTypeString)
        return nil;
    CGPDFStringRef string = NULL;
    if (!CGPDFObjectGetValue(found, kCGPDFObjectTypeString, &string) || string == NULL)
        return nil;
    CFStringRef text = CGPDFStringCopyTextString(string);
    if (text == NULL)
        return nil;
    *present = YES;
    return (__bridge NSString *)text;
}

static inline CGColorRef revenant_annotation_font_colour(CGPDFDictionaryRef annotation)
{
    bool present = NO;
    NSString *text = revenant_annotation_da_text(annotation, &present);
    if (!present)
        return revenant_annotation_named_colour(kCGColorSpaceGenericGrayGamma2_2,
                                              (const CGFloat[]){0, 1}, 2);
    NSArray *tokens = revenant_annotation_da_tokens(text);
    for (NSUInteger i = 0; i < tokens.count; i++) {
        NSString *token = tokens[i];
        if (revenant_annotation_da_is_operator(token, @"rg") && i >= 3) {
            CGFloat values[4] = {(CGFloat)[tokens[i - 3] doubleValue],
                                 (CGFloat)[tokens[i - 2] doubleValue],
                                 (CGFloat)[tokens[i - 1] doubleValue], 1};
            return revenant_annotation_named_colour(kCGColorSpaceGenericRGB, values, 4);
        }
        if (revenant_annotation_da_is_operator(token, @"g") && i >= 1) {
            CGFloat values[2] = {(CGFloat)[tokens[i - 1] doubleValue], 1};
            return revenant_annotation_named_colour(kCGColorSpaceGenericGray, values, 2);
        }
    }
    return revenant_annotation_named_colour(kCGColorSpaceGenericGray, (const CGFloat[]){0, 1}, 2);
}

static inline CGFloat revenant_annotation_font_size(CGPDFDictionaryRef annotation)
{
    bool present = NO;
    NSString *text = revenant_annotation_da_text(annotation, &present);
    if (!present)
        return REVENANT_ANNOTATION_FONT_DEFAULT_SIZE;
    NSArray *tokens = revenant_annotation_da_tokens(text);
    for (NSUInteger i = 0; i < tokens.count; i++) {
        if (!revenant_annotation_da_is_operator(tokens[i], @"Tf") || i < 1)
            continue;
        NSString *sizeToken = tokens[i - 1];
        if ([sizeToken hasPrefix:@"/"])
            break;
        return (CGFloat)[sizeToken doubleValue];
    }
    return REVENANT_ANNOTATION_FONT_DEFAULT_SIZE;
}

static inline NSString *revenant_annotation_font_name(CGPDFDictionaryRef annotation)
{
    bool present = NO;
    NSString *text = revenant_annotation_da_text(annotation, &present);
    if (!present)
        return REVENANT_ANNOTATION_FONT_DEFAULT_NAME;
    NSArray *tokens = revenant_annotation_da_tokens(text);
    for (NSUInteger i = 0; i < tokens.count; i++) {
        if (!revenant_annotation_da_is_operator(tokens[i], @"Tf") || i < 2)
            continue;
        NSString *nameToken = tokens[i - 2];
        if (![nameToken hasPrefix:@"/"])
            break;
        NSString *name = [nameToken substringFromIndex:1];
        CGFloat size = revenant_annotation_font_size(annotation);
        if ([UIFont fontWithName:name size:size] != nil)
            return name;
        if ([name isEqualToString:@"Helv"])
            return @"Helvetica";
        if ([name isEqualToString:@"HeBo"])
            return @"Helvetica-Bold";
        if ([name isEqualToString:@"Cour"])
            return @"Courier";
        break;
    }
    return REVENANT_ANNOTATION_FONT_DEFAULT_NAME;
}
