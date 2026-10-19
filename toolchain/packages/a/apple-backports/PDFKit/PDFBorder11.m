#import "RevenantPDFKit.h"

static PDFBorderStyle revenantBorderStyleForName(const char *name)
{
    if (name == NULL)
        return kPDFBorderStyleSolid;
    if (strcmp(name, "S") == 0)
        return kPDFBorderStyleSolid;
    if (strcmp(name, "D") == 0)
        return kPDFBorderStyleDashed;
    if (strcmp(name, "B") == 0)
        return kPDFBorderStyleBeveled;
    if (strcmp(name, "I") == 0)
        return kPDFBorderStyleInset;
    if (strcmp(name, "U") == 0)
        return kPDFBorderStyleUnderline;
    return kPDFBorderStyleSolid;
}

static NSArray *revenantDefaultDashPattern(void)
{
    return [NSArray arrayWithObjects:[NSNumber numberWithDouble:3.0], [NSNumber numberWithDouble:2.0], nil];
}

@implementation PDFBorder {
    NSMutableDictionary *_values;
}

- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _values = [NSMutableDictionary dictionary];
    [_values setObject:[NSNumber numberWithInteger:kPDFBorderStyleSolid] forKey:PDFBorderKeyStyle];
    [_values setObject:[NSNumber numberWithDouble:1.0] forKey:PDFBorderKeyLineWidth];
    return self;
}

- (instancetype)initWithRevenantAnnotationDictionary:(CGPDFDictionaryRef)annotation
{
    self = [self init];
    if (self == nil)
        return nil;
    if (annotation == NULL)
        return self;
    CGPDFDictionaryRef style = NULL;
    if (CGPDFDictionaryGetDictionary(annotation, "BS", &style) && style != NULL) {
        const char *name = NULL;
        PDFBorderStyle resolved = kPDFBorderStyleSolid;
        if (CGPDFDictionaryGetName(style, "S", &name))
            resolved = revenantBorderStyleForName(name);
        [self setStyle:resolved];
        CGPDFReal width = 0;
        if (CGPDFDictionaryGetNumber(style, "W", &width))
            [self setLineWidth:(CGFloat)width];
        if (resolved == kPDFBorderStyleDashed) {
            NSMutableArray *pattern = [NSMutableArray array];
            CGPDFArrayRef array = NULL;
            if (CGPDFDictionaryGetArray(style, "D", &array) && array != NULL) {
                size_t count = CGPDFArrayGetCount(array);
                for (size_t i = 0; i < count; i++) {
                    CGPDFReal number = 0;
                    if (!CGPDFArrayGetNumber(array, i, &number))
                        continue;
                    [pattern addObject:[NSNumber numberWithDouble:(double)number]];
                }
            }
            [self setDashPattern:pattern.count ? pattern : revenantDefaultDashPattern()];
        }
        return self;
    }
    CGPDFArrayRef array = NULL;
    if (CGPDFDictionaryGetArray(annotation, "Border", &array) && array != NULL) {
        CGPDFReal width = 0;
        if (CGPDFArrayGetNumber(array, 2, &width))
            [self setLineWidth:(CGFloat)width];
    }
    return self;
}

- (PDFBorderStyle)style
{
    return (PDFBorderStyle)[[_values objectForKey:PDFBorderKeyStyle] integerValue];
}

- (void)setStyle:(PDFBorderStyle)style
{
    [_values setObject:[NSNumber numberWithInteger:(NSInteger)style] forKey:PDFBorderKeyStyle];
}

- (CGFloat)lineWidth
{
    return (CGFloat)[[_values objectForKey:PDFBorderKeyLineWidth] doubleValue];
}

- (void)setLineWidth:(CGFloat)lineWidth
{
    [_values setObject:[NSNumber numberWithDouble:(double)lineWidth] forKey:PDFBorderKeyLineWidth];
}

- (NSArray *)dashPattern
{
    return [_values objectForKey:PDFBorderKeyDashPattern];
}

- (void)setDashPattern:(NSArray *)dashPattern
{
    [_values setObject:(dashPattern ?: [NSArray array]) forKey:PDFBorderKeyDashPattern];
    [self setStyle:dashPattern.count ? kPDFBorderStyleDashed : kPDFBorderStyleSolid];
}

- (NSDictionary *)borderKeyValues
{
    return [_values copy];
}

@end
