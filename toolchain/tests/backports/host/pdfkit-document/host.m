#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#include <stdio.h>
#include <string.h>

static const char *imageOf(Class c)
{
    Dl_info info;
    return (c && dladdr((__bridge const void *)c, &info) && info.dli_fname) ? info.dli_fname : "?";
}

static const struct { CGPDFBox box; const char *name; } kinds[] = {
    { kCGPDFMediaBox, "mediaBox" }, { kCGPDFCropBox, "cropBox" },
    { kCGPDFBleedBox, "bleedBox" }, { kCGPDFTrimBox, "trimBox" }, { kCGPDFArtBox, "artBox" },
};


static const char *gCopyFactsFixture = NULL;


static void printOutlineWalk(const char *name, PDFOutline *outline, int depth)
{
    if (outline == nil) {
        printf("%s.outline=nil\n", name);
        return;
    }
    printf("%s.outline.label=%s\n", name,
           outline.label == nil ? "(nil)" : (outline.label.length == 0 ? "(empty)" : outline.label.UTF8String));
    printf("%s.outline.children=%lu\n", name, (unsigned long)outline.numberOfChildren);
    printf("%s.outline.index=%lu\n", name, (unsigned long)outline.index);
    printf("%s.outline.isOpen=%d\n", name, (int)outline.isOpen);
    printf("%s.outline.parent=%s\n", name, outline.parent ? "an-object" : "(nil)");
    printf("%s.outline.document=%s\n", name, outline.document ? "an-object" : "(nil)");
    PDFDestination *destination = outline.destination;
    if (destination == nil) {
        printf("%s.outline.dest=nil\n", name);
    } else {
        printf("%s.outline.dest.page=%s\n", name, destination.page ? "an-object" : "(nil)");
        printf("%s.outline.dest.point=%.4f,%.4f\n", name, (double)destination.point.x,
               (double)destination.point.y);
        printf("%s.outline.dest.zoom=%.4f\n", name, (double)destination.zoom);
    }
    PDFAction *action = outline.action;
    if (action == nil) {
        printf("%s.outline.action=nil\n", name);
    } else {
        printf("%s.outline.action.class=%s\n", name, class_getName([action class]));
        printf("%s.outline.action.type=%s\n", name, action.type.UTF8String ?: "(nil)");
        if ([action isKindOfClass:[PDFActionURL class]])
            printf("%s.outline.action.URL=%s\n", name,
                   [[(PDFActionURL *)action URL] absoluteString].UTF8String ?: "(nil)");
        if ([action isKindOfClass:[PDFActionGoTo class]]) {
            PDFDestination *goTo = [(PDFActionGoTo *)action destination];
            printf("%s.outline.action.dest=%s\n", name,
                   goTo ? (goTo.page ? "an-object" : "(nil)") : "(nil)");
            if (goTo) {
                printf("%s.outline.action.dest.point=%.4f,%.4f\n", name, (double)goTo.point.x,
                       (double)goTo.point.y);
                printf("%s.outline.action.dest.zoom=%.4f\n", name, (double)goTo.zoom);
            }
        }
    }
    for (NSUInteger i = 0; i < outline.numberOfChildren; i++) {
        char key[512];
        snprintf(key, sizeof(key), "%s.c%lu", name, (unsigned long)i);
        printOutlineWalk(key, [outline childAtIndex:i], depth + 1);
    }
    {
        char key[512];
        snprintf(key, sizeof(key), "%s.childPastEnd", name);
        @try {
            PDFOutline *past = [outline childAtIndex:outline.numberOfChildren];
            printf("%s=%s\n", key, past == nil ? "(nil)" : "an-object");
        } @catch (NSException *raised) {
            printf("%s=%s\n", key, [[raised name] UTF8String]);
        }
    }
    (void)depth;
}


static BOOL revenantFixtureNamesItsWidgets(const char *name)
{
    static const char *const named[] = {
        "widget-t-literal", "widget-t-empty", "widget-t-merged", "widget-t-mergedname",
    };
    for (unsigned i = 0; i < sizeof(named) / sizeof(*named); i++)
        if (strncmp(name, named[i], strlen(named[i])) == 0 &&
            name[strlen(named[i])] == '.' )
            return YES;
    return strncmp(name, "widget-t-extra-", 15) == 0;
}

static void printAnnotationFlagFacts(const char *prefix, PDFAnnotation *annotation)
{
    printf("%s.flags.readOnly=%d\n", prefix, (int)annotation.isReadOnly);
    printf("%s.flags.multiline=%d\n", prefix, (int)annotation.isMultiline);
    printf("%s.flags.isPasswordField=%d\n", prefix, (int)annotation.isPasswordField);
    printf("%s.flags.comb=%d\n", prefix, (int)annotation.hasComb);
    printf("%s.flags.allowsToggleToOff=%d\n", prefix, (int)annotation.allowsToggleToOff);
    printf("%s.flags.radiosInUnison=%d\n", prefix, (int)annotation.radiosInUnison);
    printf("%s.flags.listChoice=%d\n", prefix, (int)annotation.isListChoice);
    printf("%s.flags.widgetControlType=%ld\n", prefix, (long)annotation.widgetControlType);
    printf("%s.flags.activatableTextField=%d\n", prefix, (int)annotation.isActivatableTextField);
    if (revenantFixtureNamesItsWidgets(prefix))
        printf("%s.flags.fieldName=%s\n", prefix, annotation.fieldName.UTF8String ?: "(nil)");
    printf("%s.state.onName=%s\n", prefix, annotation.buttonWidgetStateString.UTF8String ?: "(nil)");
    printf("%s.state.on=%ld\n", prefix, (long)annotation.buttonWidgetState);
}

static void printCGFloatOrUnspecified(const char *label, CGFloat value)
{
    printf("%s=%.4f\n", label, (double)value);
}

static void printDestinationFacts(const char *prefix, PDFDestination *destination)
{
    if (destination == nil) {
        printf("%s.destination=nil\n", prefix);
        return;
    }
    printf("%s.destination=an-object\n", prefix);
    PDFPage *page = destination.page;
    printf("%s.destination.page=%s\n", prefix, page ? "an-object" : "(nil)");
    if (page != nil) {
        PDFDocument *owner = page.document;
        unsigned long index = owner ? owner.pageCount : 0;
        for (unsigned long i = 0; owner != nil && i < owner.pageCount; i++) {
            if ([owner pageAtIndex:i] == page) { index = i; break; }
        }
        printf("%s.destination.pageIndex=%lu\n", prefix, index);
    } else {
        printf("%s.destination.pageIndex=-1\n", prefix);
    }
    char key[512];
    snprintf(key, sizeof(key), "%s.destination.point.x", prefix);
    printCGFloatOrUnspecified(key, destination.point.x);
    snprintf(key, sizeof(key), "%s.destination.point.y", prefix);
    printCGFloatOrUnspecified(key, destination.point.y);
    snprintf(key, sizeof(key), "%s.destination.zoom", prefix);
    printCGFloatOrUnspecified(key, destination.zoom);
}

static void printActionFacts(const char *prefix, PDFAction *action)
{
    if (action == nil) {
        printf("%s.action=nil\n", prefix);
        return;
    }
    printf("%s.action.class=%s\n", prefix, class_getName([action class]));
    printf("%s.action.type=%s\n", prefix, action.type.UTF8String ?: "(nil)");
    if ([action isKindOfClass:[PDFActionGoTo class]]) {
        char key[512];
        snprintf(key, sizeof(key), "%s.actionGoTo", prefix);
        printDestinationFacts(key, [(PDFActionGoTo *)action destination]);
    }
    if ([action isKindOfClass:[PDFActionNamed class]])
        printf("%s.action.name=%ld\n", prefix, (long)[(PDFActionNamed *)action name]);
    if ([action isKindOfClass:[PDFActionURL class]])
        printf("%s.action.URL=%s\n", prefix,
               [[(PDFActionURL *)action URL] absoluteString].UTF8String ?: "(nil)");
    if ([action isKindOfClass:[PDFActionRemoteGoTo class]]) {
        PDFActionRemoteGoTo *remote = (PDFActionRemoteGoTo *)action;
        printf("%s.action.pageIndex=%lu\n", prefix, (unsigned long)remote.pageIndex);
        char key[512];
        snprintf(key, sizeof(key), "%s.action.point.x", prefix);
        printCGFloatOrUnspecified(key, remote.point.x);
        snprintf(key, sizeof(key), "%s.action.point.y", prefix);
        printCGFloatOrUnspecified(key, remote.point.y);
        printf("%s.action.URL=%s\n", prefix, remote.URL.absoluteString.UTF8String ?: "(nil)");
    }
    if ([action isKindOfClass:[PDFActionResetForm class]]) {
        PDFActionResetForm *reset = (PDFActionResetForm *)action;
        printf("%s.action.fields=%s\n", prefix, reset.fields ? "an-array" : "(nil)");
        NSMutableArray *parts = [NSMutableArray array];
        for (NSString *field in reset.fields)
            [parts addObject:field];
        [parts sortUsingSelector:@selector(compare:)];
        printf("%s.action.fields.values=%s\n", prefix,
               [[parts componentsJoinedByString:@","] UTF8String]);
        printf("%s.action.cleared=%d\n", prefix, (int)reset.fieldsIncludedAreCleared);
    }
}

static void printInitializerFacts(const char *fixture)
{
    gCopyFactsFixture = fixture;
    PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:@(fixture)]];
    PDFDestination *plain = [[PDFDestination alloc] init];
    printf("init.destination.page=%s\n", plain.page ? "an-object" : "(nil)");
    printCGFloatOrUnspecified("init.destination.point.x", plain.point.x);
    printCGFloatOrUnspecified("init.destination.zoom", plain.zoom);
    PDFPage *page = document != nil && document.pageCount > 0 ? [document pageAtIndex:0] : nil;
    PDFDestination *made = [[PDFDestination alloc] initWithPage:page atPoint:CGPointMake(3, 4)];
    printf("init.destination.made.page=%s\n", made.page ? "an-object" : "(nil)");
    printCGFloatOrUnspecified("init.destination.made.point.x", made.point.x);
    printCGFloatOrUnspecified("init.destination.made.point.y", made.point.y);
    printCGFloatOrUnspecified("init.destination.made.zoom", made.zoom);
    made.zoom = 2.5;
    printCGFloatOrUnspecified("init.destination.made.zoomAfterSet", made.zoom);
    PDFAction *base = [[PDFAction alloc] init];
    printf("init.action.class=%s\n", class_getName([base class]));
    printf("init.action.type=%s\n", base.type.UTF8String ?: "(nil)");
    PDFActionGoTo *goTo = [[PDFActionGoTo alloc] initWithDestination:made];
    printf("init.goto.class=%s type=%s destination=%s\n", class_getName([goTo class]),
           goTo.type.UTF8String ?: "(nil)", goTo.destination ? "an-object" : "(nil)");
    PDFActionGoTo *goToNil = [[PDFActionGoTo alloc] initWithDestination:nil];
    printf("init.gotoNil.destination=%s\n", goToNil.destination ? "an-object" : "(nil)");
    PDFActionNamed *named = [[PDFActionNamed alloc] initWithName:kPDFActionNamedLastPage];
    printf("init.named.class=%s type=%s name=%ld\n", class_getName([named class]),
           named.type.UTF8String ?: "(nil)", (long)named.name);
    PDFActionNamed *namedNone = [[PDFActionNamed alloc] initWithName:kPDFActionNamedNone];
    printf("init.namedNone.name=%ld\n", (long)namedNone.name);
    PDFActionNamed *named99 = [[PDFActionNamed alloc] initWithName:(PDFActionNamedName)99];
    printf("init.named99.name=%ld\n", (long)named99.name);
    PDFActionURL *url = [[PDFActionURL alloc] initWithURL:[NSURL URLWithString:@"https://example.com/x"]];
    printf("init.url.class=%s type=%s URL=%s\n", class_getName([url class]),
           url.type.UTF8String ?: "(nil)", url.URL.absoluteString.UTF8String ?: "(nil)");
    PDFActionRemoteGoTo *remote = [[PDFActionRemoteGoTo alloc]
        initWithPageIndex:2 atPoint:CGPointMake(5, 6) fileURL:[NSURL fileURLWithPath:@"/tmp/other.pdf"]];
    printf("init.remote.class=%s type=%s pageIndex=%lu\n", class_getName([remote class]),
           remote.type.UTF8String ?: "(nil)", (unsigned long)remote.pageIndex);
    printCGFloatOrUnspecified("init.remote.point.x", remote.point.x);
    printf("init.remote.URL=%s\n", remote.URL.absoluteString.UTF8String ?: "(nil)");
    PDFActionResetForm *reset = [[PDFActionResetForm alloc] init];
    printf("init.reset.class=%s type=%s fields=%s cleared=%d\n", class_getName([reset class]),
           reset.type.UTF8String ?: "(nil)", reset.fields ? "an-array" : "(nil)",
           (int)reset.fieldsIncludedAreCleared);
    reset.fields = @[@"a", @"b"];
    reset.fieldsIncludedAreCleared = NO;
    printf("init.reset.after.fields=%lu cleared=%d\n", (unsigned long)reset.fields.count,
           (int)reset.fieldsIncludedAreCleared);
}

static void printBorderKeys(const char *label, PDFBorder *border)
{
    NSDictionary *keys = border.borderKeyValues;
    NSMutableArray *sorted = [[keys allKeys] mutableCopy];
    [sorted sortUsingSelector:@selector(compare:)];
    printf("%s.keys=%lu\n", label, (unsigned long)sorted.count);
    for (NSString *key in sorted) {
        id value = keys[key];
        if ([value isKindOfClass:[NSArray class]]) {
            NSMutableArray *parts = [NSMutableArray array];
            for (id element in value)
                [parts addObject:[NSString stringWithFormat:@"%.4f", (double)[element doubleValue]]];
            printf("%s.key.%s=%s\n", label, [key UTF8String],
                   [[parts componentsJoinedByString:@","] UTF8String]);
        } else {
            printf("%s.key.%s=%.4f\n", label, [key UTF8String], (double)[value doubleValue]);
        }
    }
}

static void printBorderDash(const char *label, PDFBorder *border)
{
    if (border.dashPattern == nil) {
        printf("%s.dash.values=(nil)\n", label);
        return;
    }
    NSMutableArray *parts = [NSMutableArray array];
    for (id value in border.dashPattern)
        [parts addObject:[NSString stringWithFormat:@"%.4f", (double)[value doubleValue]]];
    printf("%s.dash.values=%s\n", label, [[parts componentsJoinedByString:@","] UTF8String]);
}
static void printBorderValueFacts(void)
{
    PDFBorder *fresh = [[PDFBorder alloc] init];
    printf("border.fresh.style=%ld\n", (long)fresh.style);
    printf("border.fresh.lineWidth=%.4f\n", (double)fresh.lineWidth);
    printf("border.fresh.dash=%s\n", fresh.dashPattern ? "an-array" : "(nil)");
    printBorderKeys("border.fresh", fresh);
    PDFBorder *all = [[PDFBorder alloc] init];
    all.style = kPDFBorderStyleDashed;
    all.lineWidth = 5;
    all.dashPattern = @[@7, @5];
    printf("border.all.style=%ld\n", (long)all.style);
    printf("border.all.lineWidth=%.4f\n", (double)all.lineWidth);
    printf("border.all.dash=%s\n", all.dashPattern ? "an-array" : "(nil)");
    printBorderDash("border.all", all);
    printBorderKeys("border.all", all);
    PDFBorder *pattern = [[PDFBorder alloc] init];
    pattern.dashPattern = @[@7, @5];
    printf("border.pattern.style=%ld\n", (long)pattern.style);
    printf("border.pattern.lineWidth=%.4f\n", (double)pattern.lineWidth);
    printBorderKeys("border.pattern", pattern);
    PDFBorder *empty = [[PDFBorder alloc] init];
    empty.dashPattern = @[];
    printf("border.empty.style=%ld\n", (long)empty.style);
    printf("border.empty.dash=%s\n", empty.dashPattern ? "an-array" : "(nil)");
    printBorderDash("border.empty", empty);
    printBorderKeys("border.empty", empty);
    PDFBorder *cleared = [[PDFBorder alloc] init];
    cleared.lineWidth = 5;
    cleared.style = kPDFBorderStyleDashed;
    cleared.dashPattern = @[@7, @5];
    cleared.dashPattern = nil;
    printf("border.cleared.style=%ld\n", (long)cleared.style);
    printf("border.cleared.lineWidth=%.4f\n", (double)cleared.lineWidth);
    printf("border.cleared.dash=%s\n", cleared.dashPattern ? "an-array" : "(nil)");
    printBorderDash("border.cleared", cleared);
    printBorderKeys("border.cleared", cleared);
    PDFBorder *styleOnly = [[PDFBorder alloc] init];
    styleOnly.style = kPDFBorderStyleInset;
    printf("border.styleonly.style=%ld lineWidth=%.4f dash=%s\n", (long)styleOnly.style,
           (double)styleOnly.lineWidth, styleOnly.dashPattern ? "an-array" : "(nil)");
    printBorderKeys("border.styleonly", styleOnly);
    PDFBorder *widthOnly = [[PDFBorder alloc] init];
    widthOnly.lineWidth = 0;
    printf("border.widthzero.lineWidth=%.4f style=%ld\n", (double)widthOnly.lineWidth,
           (long)widthOnly.style);
    printBorderKeys("border.widthzero", widthOnly);
}


static void printAppearanceColour(const char *label, const char *member, id colour)
{
    if (colour == nil) {
        printf("appearance.%s.%s=(nil)\n", label, member);
        return;
    }
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [(id)colour getRed:&r green:&g blue:&b alpha:&a];
    printf("appearance.%s.%s=%.6f,%.6f,%.6f,%.6f\n", label, member, (double)r, (double)g, (double)b,
           (double)a);
}

static void printAnnotationColour(const char *label, const char *member, id colour)
{
    if (colour == nil) {
        printf("%s.%s=(nil)\n", label, member);
        return;
    }
    CGColorRef cgcolour = [(NSColor *)colour CGColor];
    CGColorSpaceRef space = cgcolour != NULL ? CGColorGetColorSpace(cgcolour) : NULL;
    printf("%s.%s.space=%s\n", label, member,
           space != NULL ? [(__bridge NSString *)CGColorSpaceGetName(space) UTF8String] : "(nil)");
    size_t count = cgcolour != NULL ? CGColorGetNumberOfComponents(cgcolour) : 0;
    NSMutableArray *parts = [NSMutableArray array];
    const CGFloat *raw = cgcolour != NULL ? CGColorGetComponents(cgcolour) : NULL;
    for (size_t i = 0; i < count; i++)
        [parts addObject:[NSString stringWithFormat:@"%.6f", (double)raw[i]]];
    printf("%s.%s.components=%s\n", label, member,
           [[parts componentsJoinedByString:@","] UTF8String]);
}

static const char *revenantAnnotationName(PDFAnnotation *annotation)
{
    id name = [annotation valueForAnnotationKey:@"NM"];
    if (![name isKindOfClass:[NSString class]] || [(NSString *)name length] == 0)
        return NULL;
    return [(NSString *)name UTF8String];
}

static void printAnnotationColourFacts(const char *fixture, PDFPage *page)
{
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned a = 0; a < page.annotations.count; a++) {
        const char *name = revenantAnnotationName(page.annotations[a]);
        if (name != NULL)
            [names addObject:@(name)];
    }
    if (names.count == 0)
        return;
    printf("%s.colours.names=%s\n", fixture, [[names componentsJoinedByString:@","] UTF8String]);
    for (unsigned a = 0; a < page.annotations.count; a++) {
        PDFAnnotation *annotation = page.annotations[a];
        const char *name = revenantAnnotationName(annotation);
        if (name == NULL)
            continue;
        char label[512];
        snprintf(label, sizeof(label), "%s.colours.nm%s", fixture, name);
        printAnnotationColour(label, "backgroundColor", annotation.backgroundColor);
        printAnnotationColour(label, "interiorColor", annotation.interiorColor);
        printAnnotationColour(label, "fontColor", annotation.fontColor);
        NSFont *font = annotation.font;
        if (font == nil) {
            printf("%s.font.name=(nil)\n", label);
            printf("%s.font.size=(nil)\n", label);
        } else {
            printf("%s.font.name=%s\n", label, [font.fontName UTF8String]);
            printf("%s.font.size=%.6f\n", label, (double)font.pointSize);
        }
    }
}

static void printAppearanceCharacteristics(const char *label,
                                           PDFAppearanceCharacteristics *characteristics)
{
    printf("appearance.%s.controlType=%ld\n", label, (long)characteristics.controlType);
    printf("appearance.%s.rotation=%ld\n", label, (long)characteristics.rotation);
    printAppearanceColour(label, "backgroundColor", characteristics.backgroundColor);
    printAppearanceColour(label, "borderColor", characteristics.borderColor);
    printf("appearance.%s.caption=%s\n", label,
           characteristics.caption ? characteristics.caption.UTF8String : "(nil)");
    printf("appearance.%s.rolloverCaption=%s\n", label,
           characteristics.rolloverCaption ? characteristics.rolloverCaption.UTF8String : "(nil)");
    printf("appearance.%s.downCaption=%s\n", label,
           characteristics.downCaption ? characteristics.downCaption.UTF8String : "(nil)");
    NSDictionary *keys = characteristics.appearanceCharacteristicsKeyValues;
    NSMutableArray *sorted = [[keys allKeys] mutableCopy];
    [sorted sortUsingSelector:@selector(compare:)];
    printf("appearance.%s.keys=%lu\n", label, (unsigned long)sorted.count);
    for (NSString *key in sorted) {
        id value = keys[key];
        if ([value isKindOfClass:[NSString class]]) {
            printf("appearance.%s.key.%s=%s\n", label, [key UTF8String],
                   [(NSString *)value UTF8String]);
        } else if ([value respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
            CGFloat r = 0, g = 0, b = 0, a = 0;
            [(id)value getRed:&r green:&g blue:&b alpha:&a];
            printf("appearance.%s.key.%s=%.6f,%.6f,%.6f,%.6f\n", label, [key UTF8String], (double)r,
                   (double)g, (double)b, (double)a);
        } else {
            printf("appearance.%s.key.%s=%.6f\n", label, [key UTF8String], (double)[value doubleValue]);
        }
    }
}


static PDFPage *copyFactsPage(void)
{
    static PDFPage *page = nil;
    if (page != nil)
        return page;
    NSString *path = @(gCopyFactsFixture);
    PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
    page = document.pageCount > 0 ? [document pageAtIndex:0] : nil;
    return page;
}

static void printCopyFacts(void)
{
    PDFActionGoTo *goToInit = [[PDFActionGoTo alloc] init];
    printf("initgoto.class=%s type=%s destination=%s\n", class_getName([goToInit class]),
           goToInit.type.UTF8String ?: "(nil)",
           goToInit.destination ? "an-object" : "(nil)");
    PDFActionNamed *namedInit = [[PDFActionNamed alloc] init];
    printf("initnamed.class=%s type=%s name=%ld\n", class_getName([namedInit class]),
           namedInit.type.UTF8String ?: "(nil)", (long)namedInit.name);
    PDFActionURL *urlInit = [[PDFActionURL alloc] init];
    printf("initurl.class=%s type=%s URL=%s\n", class_getName([urlInit class]),
           urlInit.type.UTF8String ?: "(nil)",
           urlInit.URL.absoluteString.UTF8String ?: "(nil)");
    PDFActionRemoteGoTo *remoteInit = [[PDFActionRemoteGoTo alloc] init];
    printf("initremote.class=%s type=%s pageIndex=%lu URL=%s\n", class_getName([remoteInit class]),
           remoteInit.type.UTF8String ?: "(nil)", (unsigned long)remoteInit.pageIndex,
           remoteInit.URL.absoluteString.UTF8String ?: "(nil)");
    printCGFloatOrUnspecified("initremote.point.x", remoteInit.point.x);
    printCGFloatOrUnspecified("initremote.point.y", remoteInit.point.y);

    PDFDestination *noPage = [[PDFDestination alloc] initWithPage:nil atPoint:CGPointMake(3, 4)];
    printf("initdest.nilpage=%s\n", noPage ? "an-object" : "(nil)");

    PDFDestination *made = [[PDFDestination alloc] initWithPage:copyFactsPage()
                                                      atPoint:CGPointMake(3, 4)];
    made.zoom = 2.5;
    PDFDestination *madeCopy = [made copy];
    printf("copy.destination.class=%s\n", class_getName([madeCopy class]));
    printf("copy.destination.same=%d\n", (int)(madeCopy == made));
    printf("copy.destination.page.same=%d\n", (int)(madeCopy.page == made.page));
    printCGFloatOrUnspecified("copy.destination.point.x", madeCopy.point.x);
    printCGFloatOrUnspecified("copy.destination.point.y", madeCopy.point.y);
    printCGFloatOrUnspecified("copy.destination.zoom", madeCopy.zoom);
    madeCopy.zoom = 9;
    printCGFloatOrUnspecified("copy.destination.zoomAfterSet", madeCopy.zoom);
    printCGFloatOrUnspecified("copy.destination.zoomOriginal", made.zoom);

    PDFDestination *bare = [[PDFDestination alloc] init];
    PDFDestination *bareCopy = [bare copy];
    printf("copy.nopage=%s\n", bareCopy ? "an-object" : "(nil)");

    PDFAction *base = [[PDFAction alloc] init];
    PDFAction *baseCopy = [base copy];
    printf("copy.action.class=%s type=%s same=%d\n", class_getName([baseCopy class]),
           baseCopy.type.UTF8String ?: "(nil)", (int)(baseCopy == base));
    PDFActionGoTo *goTo = [[PDFActionGoTo alloc] initWithDestination:made];
    PDFActionGoTo *goToCopy = [goTo copy];
    printf("copy.goto.class=%s type=%s destination=%s\n", class_getName([goToCopy class]),
           goToCopy.type.UTF8String ?: "(nil)",
           goToCopy.destination ? "an-object" : "(nil)");
    printf("copy.goto.destination.same=%d\n", (int)(goToCopy.destination == goTo.destination));
    printf("copy.goto.destination.page.same=%d\n",
           (int)(goToCopy.destination && goToCopy.destination.page
                 && goToCopy.destination.page == goTo.destination.page));
    PDFActionNamed *named = [[PDFActionNamed alloc] initWithName:kPDFActionNamedFind];
    PDFActionNamed *namedCopy = [named copy];
    printf("copy.named.name=%ld\n", (long)namedCopy.name);
    namedCopy.name = kPDFActionNamedPrint;
    printf("copy.named.nameAfterSet=%ld original=%ld\n", (long)namedCopy.name, (long)named.name);
    PDFActionURL *url = [[PDFActionURL alloc]
        initWithURL:[NSURL URLWithString:@"https://example.com/x"]];
    PDFActionURL *urlCopy = [url copy];
    printf("copy.url.URL=%s\n", urlCopy.URL.absoluteString.UTF8String ?: "(nil)");
    PDFActionRemoteGoTo *remote = [[PDFActionRemoteGoTo alloc]
        initWithPageIndex:2 atPoint:CGPointMake(5, 6)
                  fileURL:[NSURL URLWithString:@"https://example.com/x"]];
    PDFActionRemoteGoTo *remoteCopy = [remote copy];
    printf("copy.remote.pageIndex=%lu\n", (unsigned long)remoteCopy.pageIndex);
    printCGFloatOrUnspecified("copy.remote.point.x", remoteCopy.point.x);
    printCGFloatOrUnspecified("copy.remote.point.y", remoteCopy.point.y);
    printf("copy.remote.URL=%s\n", remoteCopy.URL.absoluteString.UTF8String ?: "(nil)");
    PDFActionResetForm *reset = [[PDFActionResetForm alloc] init];
    reset.fields = @[@"a", @"b"];
    reset.fieldsIncludedAreCleared = NO;
    PDFActionResetForm *resetCopy = [reset copy];
    printf("copy.reset.fields.same=%d count=%lu cleared=%d\n",
           (int)(resetCopy.fields == reset.fields), (unsigned long)resetCopy.fields.count,
           (int)resetCopy.fieldsIncludedAreCleared);
}

static const char *const kNeedles[] = {
    "alpha", "bravo", "charlie", "zero", "one", "two", "three", "six", "shared", "third", "line",
    "page", "delta", "nothing here",
};

static NSString *visibleText(NSString *text)
{
    if (text == nil)
        return nil;
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\n') [out appendString:@"\\n"];
        else if (c == '\r') [out appendString:@"\\r"];
        else if (c == '\t') [out appendString:@"\\t"];
        else [out appendFormat:@"%C", c];
    }
    return out;
}

static void printSelection(const char *prefix, PDFSelection *selection, PDFDocument *document)
{
    if (selection == nil) {
        printf("%s=nil\n", prefix);
        return;
    }
    printf("%s.class=%s\n", prefix, class_getName([selection class]));
    printf("%s.string=%s\n", prefix, visibleText(selection.string).UTF8String ?: "(nil)");
    printf("%s.pages=%lu\n", prefix, (unsigned long)selection.pages.count);
    printf("%s.byLine=%lu\n", prefix, (unsigned long)selection.selectionsByLine.count);
    printf("%s.color=%s\n", prefix, selection.color ? "a-colour" : "(nil)");
    PDFPage *page0 = document.pageCount ? [document pageAtIndex:0] : nil;
    if (page0 != nil) {
        printf("%s.ranges=%lu\n", prefix, (unsigned long)[selection numberOfTextRangesOnPage:page0]);
        for (NSUInteger i = 0; i < [selection numberOfTextRangesOnPage:page0]; i++) {
            NSRange r = [selection rangeAtIndex:i onPage:page0];
            printf("%s.range%lu=%lu,%lu\n", prefix, (unsigned long)i, (unsigned long)r.location,
                   (unsigned long)r.length);
        }
        CGRect b = [selection boundsForPage:page0];
        printf("%s.bounds0=%.4f,%.4f,%.4f,%.4f\n", prefix, b.origin.x, b.origin.y, b.size.width,
               b.size.height);
        if (document.pageCount > 1) {
            PDFPage *last = [document pageAtIndex:document.pageCount - 1];
            CGRect o = [selection boundsForPage:last];
            printf("%s.boundsLast=%.4f,%.4f,%.4f,%.4f\n", prefix, o.origin.x, o.origin.y, o.size.width,
                   o.size.height);
        }
    }
    NSAttributedString *attributed = selection.attributedString;
    printf("%s.attributed=%s\n", prefix, attributed == nil ? "(nil)" : "an-object");
    if (attributed != nil)
        printf("%s.attributedLength=%lu\n", prefix, (unsigned long)attributed.length);
    PDFSelection *copy = [selection copy];
    printf("%s.copy=%s\n", prefix, copy == selection ? "same" : "another-object");
    printf("%s.copyString=%s\n", prefix, visibleText(copy.string).UTF8String ?: "(nil)");
}

static void printFindFacts(const char *name, PDFDocument *document)
{
    for (unsigned i = 0; i < sizeof(kNeedles) / sizeof(*kNeedles); i++) {
        NSString *needle = @(kNeedles[i]);
        NSArray<PDFSelection *> *found = [document findString:needle withOptions:0];
        printf("%s.find.%s.count=%lu\n", name, kNeedles[i], (unsigned long)found.count);
        if (found.count > 0) {
            char prefix[512];
            snprintf(prefix, sizeof(prefix), "%s.find.%s.0", name, kNeedles[i]);
            printSelection(prefix, found[0], document);
            NSArray<PDFSelection *> *backwards = [document findString:needle withOptions:NSBackwardsSearch];
            printf("%s.find.%s.backwards=%lu\n", name, kNeedles[i], (unsigned long)backwards.count);
            if (backwards.count > 0) {
                snprintf(prefix, sizeof(prefix), "%s.find.%s.backwards.0", name, kNeedles[i]);
                printSelection(prefix, backwards[0], document);
            }
            NSArray<PDFSelection *> *folded = [document findString:needle
                                                     withOptions:NSCaseInsensitiveSearch];
            printf("%s.find.%s.folded=%lu\n", name, kNeedles[i], (unsigned long)folded.count);
            if (folded.count > 0) {
                snprintf(prefix, sizeof(prefix), "%s.find.%s.folded.0", name, kNeedles[i]);
                printSelection(prefix, folded[0], document);
            }
        }
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        printf("side=host\n");
        printf("host.PDFDocument.image=%s\n", imageOf([PDFDocument class]));
        printf("host.PDFPage.image=%s\n", imageOf([PDFPage class]));
        printf("host.PDFDocument.hasInitWithURL=%d\n",
               (int)[PDFDocument instancesRespondToSelector:@selector(initWithURL:)]);

        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            const char *name = strrchr(argv[i], '/');
            name = name ? name + 1 : argv[i];
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            if (document == nil) {
                printf("%s.pageCount=nil\n", name);
                printf("%s.document=nil\n", name);
                continue;
            }
            printf("%s.document=an-object\n", name);
            printf("%s.pageCount=%lu\n", name, (unsigned long)document.pageCount);
            printf("%s.isLocked=%d\n", name, (int)document.isLocked);
            printf("%s.isEncrypted=%d\n", name, (int)document.isEncrypted);
            printf("%s.allowsCopying=%d\n", name, (int)document.allowsCopying);
            printf("%s.documentURL=%s\n", name,
                   document.documentURL ? [document.documentURL lastPathComponent].UTF8String : "(nil)");
            printf("%s.dataRepresentation.length=%lu\n", name,
                   (unsigned long)document.dataRepresentation.length);
            printf("%s.documentAttribute.supported=%d\n", name,
                   (int)[document respondsToSelector:NSSelectorFromString(@"documentAttribute:")]);
            NSDictionary *attributes = document.documentAttributes;
            NSMutableArray *keys = [[attributes allKeys] mutableCopy];
            [keys sortUsingSelector:@selector(compare:)];
            printf("%s.documentAttributes.keys=%lu\n", name, (unsigned long)keys.count);
            for (NSString *key in keys)
                printf("%s.documentAttributes.key.%s\n", name, [(NSString *)key UTF8String]);
            {
                PDFView *view = [[PDFView alloc] init];
                printf("%s.view.window.supported=%d\n", name,
                       (int)[view respondsToSelector:sel_registerName("window")]);
                printf("%s.view.document.before=%s\n", name, view.document ? "an-object" : "(nil)");
                view.document = document;
                printf("%s.view.document=%s\n", name, view.document ? "an-object" : "(nil)");
                printf("%s.view.currentPage=%s\n", name, view.currentPage ? "an-object" : "(nil)");
                printf("%s.view.scaleFactor=%.4f\n", name, view.scaleFactor);
                printf("%s.view.minScaleFactor=%.4f\n", name, view.minScaleFactor);
                printf("%s.view.maxScaleFactor=%.4f\n", name, view.maxScaleFactor);
                printf("%s.view.autoScales=%d\n", name, (int)view.autoScales);
                printf("%s.view.displayMode=%ld\n", name, (long)view.displayMode);
                printf("%s.view.displayBox=%ld\n", name, (long)view.displayBox);
                printf("%s.view.displayDirection=%ld\n", name, (long)view.displayDirection);
                printf("%s.view.pageShadowsEnabled=%d\n", name, (int)view.pageShadowsEnabled);
                view.displayBox = 0;
                printf("%s.view.displayBox.afterMedia=%ld\n", name, (long)view.displayBox);
                if (view.document.pageCount > 0)
                    [view goToPage:[view.document pageAtIndex:0]];
                printf("%s.view.goToPage.currentPage=%s\n", name,
                       view.currentPage ? "an-object" : "(nil)");
                view.document = nil;
                printf("%s.view.document.afterNil=%s\n", name, view.document ? "an-object" : "(nil)");
                printf("%s.view.currentPage.afterNil=%s\n", name,
                       view.currentPage ? "an-object" : "(nil)");
            }
            for (NSString *key in @[ @"Title", @"Author", @"Creator" ]) {
                id value = attributes[key];
                printf("%s.documentAttributes.%s=%s\n", name, [(NSString *)key UTF8String],
                       value ? [(NSString *)value UTF8String] : "(nil)");
            }
            SEL pageAt = NSSelectorFromString(@"pageAtIndex:");
            PDFPage *first = [document respondsToSelector:pageAt]
                                  ? ((id (*)(id, SEL, NSUInteger))objc_msgSend)(document, pageAt, (NSUInteger)0)
                                  : nil;
            if (first != nil) {
                printf("%s.page0.rotation=%ld\n", name, (long)first.rotation);
                printf("%s.page0.label=%s\n", name, first.label ? [first.label UTF8String] : "(nil)");
                printf("%s.page0.document=%s\n", name, first.document ? "an-object" : "(nil)");
                printf("%s.page0.pageIndex.supported=%d\n", name,
                       (int)[first respondsToSelector:NSSelectorFromString(@"pageIndex")]);
                printf("%s.page0.numberOfCharacters=%ld\n", name, (long)first.numberOfCharacters);
                printf("%s.page0.string=%s\n", name, first.string ? first.string.UTF8String : "(nil)");
                printf("%s.page0.annotations.count=%lu\n", name, (unsigned long)first.annotations.count);
                printFindFacts(name, document);
                printOutlineWalk(name, document.outlineRoot, 0);
                printAnnotationColourFacts(name, first);
                for (unsigned a = 0; a < first.annotations.count; a++) {
                    PDFAnnotation *each = first.annotations[a];
                    NSString *prefix = [NSString stringWithFormat:@"%s.page0.annotation%u", name, a];
                    printAnnotationFlagFacts([prefix UTF8String], each);
                    printActionFacts([prefix UTF8String], each.action);
                    printDestinationFacts([prefix UTF8String], each.destination);
                }
                for (unsigned a = 0; a < first.annotations.count; a++) {
                    PDFBorder *border = first.annotations[a].border;
                    if (border == nil) {
                        printf("%s.page0.annotation%u.border=nil\n", name, a);
                        continue;
                    }
                    printf("%s.page0.annotation%u.border.style=%ld\n", name, a, (long)border.style);
                    printf("%s.page0.annotation%u.border.lineWidth=%.6f\n", name, a,
                           (double)border.lineWidth);
                    printf("%s.page0.annotation%u.border.dash=%s\n", name, a,
                           border.dashPattern ? "an-array" : "(nil)");
                    if (border.dashPattern) {
                        NSMutableArray *parts = [NSMutableArray array];
                        for (id value in border.dashPattern)
                            [parts addObject:[NSString stringWithFormat:@"%.6f",
                                               (double)[value doubleValue]]];
                        printf("%s.page0.annotation%u.border.dash.values=%s\n", name, a,
                               [[parts componentsJoinedByString:@","] UTF8String]);
                    }
                    NSDictionary *keys = border.borderKeyValues;
                    NSMutableArray *sorted = [[keys allKeys] mutableCopy];
                    [sorted sortUsingSelector:@selector(compare:)];
                    printf("%s.page0.annotation%u.border.keys=%lu\n", name, a,
                           (unsigned long)sorted.count);
                    for (NSString *key in sorted) {
                        id value = keys[key];
                        if ([value isKindOfClass:[NSString class]]) {
                            printf("%s.page0.annotation%u.border.key.%s=%s\n", name, a,
                                   [key UTF8String], [(NSString *)value UTF8String]);
                        } else if ([value isKindOfClass:[NSArray class]]) {
                            NSMutableArray *parts = [NSMutableArray array];
                            for (id element in value)
                                [parts addObject:[NSString stringWithFormat:@"%.6f",
                                                   (double)[element doubleValue]]];
                            printf("%s.page0.annotation%u.border.key.%s=%s\n", name, a,
                                   [key UTF8String], [[parts componentsJoinedByString:@","] UTF8String]);
                        } else {
                            printf("%s.page0.annotation%u.border.key.%s=%.6f\n", name, a,
                                   [key UTF8String], (double)[value doubleValue]);
                        }
                    }
                }
                for (unsigned a = 0; a < first.annotations.count; a++) {
                    PDFAnnotation *an = first.annotations[a];
                    CGRect r = an.bounds;
                    printf("%s.page0.annotation%u.type=%s\n", name, a,
                           an.type ? an.type.UTF8String : "(nil)");
                    printf("%s.page0.annotation%u.bounds=%.4f,%.4f,%.4f,%.4f\n", name, a,
                           r.origin.x, r.origin.y, r.size.width, r.size.height);
                    printf("%s.page0.annotation%u.contents=%s\n", name, a,
                           an.contents ? an.contents.UTF8String : "(nil)");
                    printf("%s.page0.annotation%u.userName=%s\n", name, a,
                           an.userName ? an.userName.UTF8String : "(nil)");
                    printf("%s.page0.annotation%u.shouldPrint=%d\n", name, a, (int)an.shouldPrint);
                    printf("%s.page0.annotation%u.page=%s\n", name, a, an.page ? "an-object" : "(nil)");
                }
            } else {
                printf("%s.page0.rotation=NOT-COMPARED-no-page\n", name);
                printf("%s.page0.label=NOT-COMPARED-no-page\n", name);
                printf("%s.page0.document=NOT-COMPARED-no-page\n", name);
                printf("%s.page0.pageIndex=NOT-COMPARED-no-page\n", name);
                printf("%s.page0.numberOfCharacters=NOT-COMPARED-no-page\n", name);
                printf("%s.page0.annotations.count=NOT-COMPARED-no-page\n", name);
            }
            if (first == nil || ![first respondsToSelector:@selector(boundsForBox:)]) {
                for (unsigned k = 0; k < sizeof(kinds) / sizeof(*kinds); k++)
                    printf("%s.page0.%s=NOT-COMPARED-no-such-method\n", name, kinds[k].name);
            } else {
                if (first.annotations.count > 0) {
                    PDFAnnotation *target = first.annotations[0];
                    PDFBorder *once = target.border;
                    printf("%s.page0.border.identity.same=%d\n", name, (int)(once == target.border));
                    if (once != nil) {
                        once.lineWidth = 9;
                        printf("%s.page0.border.identity.mutated=%.4f\n", name,
                               (double)target.border.lineWidth);
                        PDFBorder *replacement = [[PDFBorder alloc] init];
                        replacement.lineWidth = 11;
                        target.border = replacement;
                        printf("%s.page0.border.set.same=%d\n", name,
                               (int)(target.border == replacement));
                        printf("%s.page0.border.set.lineWidth=%.4f\n", name,
                               (double)target.border.lineWidth);
                        replacement.lineWidth = 12;
                        printf("%s.page0.border.set.mutated=%.4f\n", name,
                               (double)target.border.lineWidth);
                        target.border = nil;
                        printf("%s.page0.border.set.nil=%d\n", name, (int)(target.border == nil));
                    }
                }
                for (unsigned k = 0; k < sizeof(kinds) / sizeof(*kinds); k++) {
                    CGRect box = ((CGRect (*)(id, SEL, CGPDFBox))objc_msgSend)(first,
                                                                            @selector(boundsForBox:),
                                                                            kinds[k].box);
                    printf("%s.page0.%s=%.4f,%.4f,%.4f,%.4f\n", name, kinds[k].name, box.origin.x,
                           box.origin.y, box.size.width, box.size.height);
                }
            }
            id past = [document respondsToSelector:pageAt]
                          ? ((id (*)(id, SEL, NSUInteger))objc_msgSend)(document, pageAt, document.pageCount)
                          : nil;
            printf("%s.pageAtIndex.one-past-the-end=%s\n", name, past ? "an-object" : "nil");
        }
        printAppearanceCharacteristics("fresh", [[PDFAppearanceCharacteristics alloc] init]);
        {
            PDFAppearanceCharacteristics *only = [[PDFAppearanceCharacteristics alloc] init];
            only.caption = @"cap";
            printAppearanceCharacteristics("captionOnly", only);
            PDFAppearanceCharacteristics *cleared = [[PDFAppearanceCharacteristics alloc] init];
            cleared.caption = @"cap";
            cleared.backgroundColor = [NSColor redColor];
            cleared.caption = nil;
            cleared.backgroundColor = nil;
            printAppearanceCharacteristics("cleared", cleared);
            PDFAppearanceCharacteristics *empty = [[PDFAppearanceCharacteristics alloc] init];
            empty.caption = @"";
            empty.downCaption = @"";
            printAppearanceCharacteristics("empty", empty);
            PDFAppearanceCharacteristics *negative = [[PDFAppearanceCharacteristics alloc] init];
            negative.rotation = -90;
            printAppearanceCharacteristics("negative", negative);
            for (long control = -1; control <= 3; control++) {
                PDFAppearanceCharacteristics *probe =
                    [[PDFAppearanceCharacteristics alloc] init];
                probe.controlType = (PDFWidgetControlType)control;
                printf("appearance.controlType%ld.read=%ld\n", control, (long)probe.controlType);
                printf("appearance.controlType%ld.keys=%lu\n", control,
                       (unsigned long)probe.appearanceCharacteristicsKeyValues.count);
            }
            PDFAppearanceCharacteristics *full = [[PDFAppearanceCharacteristics alloc] init];
            full.controlType = kPDFWidgetCheckBoxControl;
            full.backgroundColor = [NSColor redColor];
            full.borderColor = [NSColor blueColor];
            full.rotation = 90;
            full.caption = @"cap";
            full.rolloverCaption = @"roll";
            full.downCaption = @"down";
            printAppearanceCharacteristics("full", full);
        }
        printBorderValueFacts();
        printInitializerFacts(argv[1]);
        {
            PDFDocument *opened = [[PDFDocument alloc]
                initWithURL:[NSURL fileURLWithPath:@(argv[1])]];
            PDFOutline *fresh = [[PDFOutline alloc] init];
            printf("initoutline.class=%s label=%s children=%lu index=%lu isOpen=%d parent=%s "
                   "document=%s\n", class_getName([fresh class]),
                   fresh.label == nil ? "(nil)"
                                       : (fresh.label.length == 0 ? "(empty)" : fresh.label.UTF8String),
                   (unsigned long)fresh.numberOfChildren, (unsigned long)fresh.index,
                   (int)fresh.isOpen, fresh.parent ? "an-object" : "(nil)",
                   fresh.document ? "an-object" : "(nil)");
            printf("initoutline.dest=%s action=%s\n", fresh.destination ? "an-object" : "(nil)",
                   fresh.action ? "an-object" : "(nil)");
            printf("initoutline.root=%s\n", opened.outlineRoot ? "an-object" : "(nil)");
        }
        printCopyFacts();
    }
    return 0;
}
