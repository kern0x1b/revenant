#import "RevenantPDFKit.h"

static BOOL revenantDestinationNameIsKnown(const char *name)
{
    if (name == NULL)
        return NO;
    return strcmp(name, "XYZ") == 0 || strcmp(name, "Fit") == 0 || strcmp(name, "FitH") == 0
           || strcmp(name, "FitV") == 0 || strcmp(name, "FitB") == 0 || strcmp(name, "FitBH") == 0
           || strcmp(name, "FitBV") == 0;
}

static CGFloat revenantDestinationNumber(CGPDFArrayRef destination, size_t index)
{
    CGPDFReal number = 0;
    if (!CGPDFArrayGetNumber(destination, index, &number))
        return kPDFDestinationUnspecifiedValue;
    return (CGFloat)number;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFDestination {
    __weak PDFPage *_page;
    CGPoint _point;
    CGFloat _zoom;
}

@synthesize page = _page;
@synthesize point = _point;
@synthesize zoom = _zoom;

- (instancetype)initWithPage:(PDFPage *)page atPoint:(CGPoint)point
{
    if (page == nil)
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _page = page;
    _point = point;
    _zoom = kPDFDestinationUnspecifiedValue;
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _point = CGPointMake(kPDFDestinationUnspecifiedValue, kPDFDestinationUnspecifiedValue);
    _zoom = kPDFDestinationUnspecifiedValue;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFDestination *copy = [[[self class] alloc] init];
    copy->_page = _page;
    copy->_point = _point;
    copy->_zoom = _zoom;
    return copy;
}

- (instancetype)initWithRevenantDestinationArray:(CGPDFArrayRef)destination
                                    inDocument:(PDFDocument *)document
{
    if (destination == NULL)
        return [self init];

    const char *name = NULL;
    if (!CGPDFArrayGetName(destination, 1, &name) || !revenantDestinationNameIsKnown(name))
        return nil;
    const char *firstName = NULL;
    if (CGPDFArrayGetName(destination, 0, &firstName))
        return nil;

    self = [self init];
    if (self == nil)
        return nil;

    CGPDFDictionaryRef referenced = NULL;
    if (CGPDFArrayGetDictionary(destination, 0, &referenced) && referenced != NULL)
        _page = [self revenant_pageForDictionary:referenced inDocument:document];

    if (strcmp(name, "XYZ") != 0)
        return self;
    _point = CGPointMake(revenantDestinationNumber(destination, 2),
                         revenantDestinationNumber(destination, 3));
    CGFloat zoom = revenantDestinationNumber(destination, 4);
    _zoom = zoom != 0 ? zoom : kPDFDestinationUnspecifiedValue;
    return self;
}

- (PDFPage *)revenant_pageForDictionary:(CGPDFDictionaryRef)dictionary inDocument:(PDFDocument *)document
{
    if (document == nil)
        return nil;
    NSUInteger count = [document pageCount];
    for (NSUInteger index = 0; index < count; index++) {
        PDFPage *page = [document pageAtIndex:index];
        CGPDFPageRef cgPage = [page revenant_CGPDFPage];
        if (cgPage == NULL)
            continue;
        if (CGPDFPageGetDictionary(cgPage) == dictionary)
            return page;
    }
    return nil;
}

@end
#pragma clang diagnostic pop
