#import "CharonPDFKit.h"

// The action family over an annotation's /A dictionary - the action dictionary of PDF 1.7 Table 8.44 -
// and over the /Dest that stands in for one.  Seven classes, one factory, and every rule measured: see
// the tables on each implementation below and facts/PDFKit/Action11.md.

// The /S name to the class the host builds, and the two names it builds NOTHING for.  Measured one
// fixture per case:
//
//   /GoTo      PDFActionGoTo       act-goto-xyz, and act-goto-no-d - a /GoTo with no /D is still an
//                                  object, with a nil destination
//   /Named     PDFActionNamed      act-named-all, one fixture per name the enum declares
//   /URI       PDFActionURL        act-uri, and act-uri's second annotation - a /URI with no /URI is
//                                  still an object, with a nil URL
//   /Launch    PDFActionURL, typed  annot-launch, annot-launch-spec, annot-launch-win: the host's own class,
//              Launch               and its URL is the /F resolved against the document, not a /URI
//   /GoToR     PDFActionRemoteGoTo act-gotor, including the one with no /F
//   /ResetForm PDFActionResetForm  act-reset
//   /Bogus     PDFAction, the BASE  act-unknown-s: an /S the format does not list answers the base
//                                  class, not nil and not a subclass
//   no /S      NOTHING              act-no-s: an action dictionary with no /S answers nil, which is why
//                                  nil is a measured absence here and not an empty object
static Class charonActionClassForName(const char *name)
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

// The eight /N names the host builds a PDFActionNamed for, out of the twelve the enum declares.
// act-named-all.pdf carries all twelve plus one it does not list, one annotation each, and the host
// answers an object for exactly these eight: NextPage (1), FirstPage (3), LastPage (4), GoBack (5),
// GoForward (6), GoToPage (7), Find (8) and Print (9).  None, PreviousPage, ZoomIn, ZoomOut and
// NotAName all answer NO ACTION AT ALL.
//
// That is the host's table and not the enum's, and it is the whole reason this is a table: reading the
// name as its enum value would answer an object for all twelve, and four of the twelve would then be
// objects the host never builds.
static BOOL charonNamedActionValue(const char *name, PDFActionNamedName *out)
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

// The action's /S name, or NULL.  The name object carries no leading slash in the C string, which is
// where -type's "Text"-style spelling comes from.
static const char *charonActionName(CGPDFDictionaryRef action)
{
    const char *name = NULL;
    if (!CGPDFDictionaryGetName(action, "S", &name))
        return NULL;
    return name;
}

// A PDF STRING out of a dictionary, as an NSString.  Used for /N, /URI and /F, which the format spells as
// names or strings and which the host answers as objects either way.
static NSString *charonActionString(CGPDFDictionaryRef action, const char *key)
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

// -type is the /S NAME, and it is nil on a freshly allocated action - measured - and the name on one
// read out of a dictionary, including a name the format does not list ("Bogus" on act-unknown-s).  So
// the property is the dictionary's name and not a fixed string per class: the port's own -type for a
// PDFActionGoTo is "GoTo" because that is what its /S said, not because of the class.
//
// A freshly allocated one answers nil, so -type's answer here is nil and NOT a class's name: the base
// action's -init deliberately sets nothing, and each subclass's own initializer sets the name its /S
// would have carried.  That is what makes the measured nil on [[PDFAction alloc] init] true here.
- (NSString *)type
{
    return _type;
}

// The one place a type name is written, for the subclasses and the factory.  A method and not
// -[NSObject setValue:forKey:]: a readonly property's storage is not a setter, and reaching it through
// KVC would be a private route to an ivar for the sake of a shorter line.
- (void)charon_setTypeName:(NSString *)name
{
    _type = [name copy];
}

// -copyWithZone: is the NSCopying conformance CharonPDFKit.h declares, and it is implemented because a
// caller reaches it: [action copy] answers on the host and raises on a port that declares the protocol
// and does not implement it.  Measured: the copy is a NEW object of the SAME class carrying every member,
// and it is INDEPENDENT - a destination's zoom set on the copy leaves the original alone.  The type name
// is the base's own member and each subclass adds its own below, so -[super copyWithZone:] is what
// allocates an object of self's class with the type already copied.
- (id)copyWithZone:(NSZone *)zone
{
    PDFAction *copy = [[[self class] alloc] init];
    copy->_type = _type;
    return copy;
}

// The factory.  It reads /S once, refuses an action with no /S, and then hands the dictionary to the
// class the name picks - so the /N table, the /D reader and the /Flags rule all live in the class that
// owns them rather than in one switch here.
+ (instancetype)charon_actionWithDictionary:(CGPDFDictionaryRef)action inDocument:(PDFDocument *)document
{
    if (action == NULL)
        return nil;
    const char *name = charonActionName(action);
    if (name == NULL)
        return nil;
    if (strcmp(name, "Named") == 0)
        return [[PDFActionNamed alloc] initWithCharonActionDictionary:action];
    // /Launch is a PDFActionURL on the host, typed Launch, and its URL is read from /F, not /URI
    if (strcmp(name, "Launch") == 0)
        return [[PDFActionURL alloc] initWithCharonLaunchDictionary:action inDocument:document];
    Class chosen = charonActionClassForName(name);
    if (chosen == [PDFActionGoTo class])
        return [[PDFActionGoTo alloc] initWithCharonActionDictionary:action inDocument:document];
    if (chosen == [PDFActionURL class])
        return [[PDFActionURL alloc] initWithCharonActionDictionary:action];
    if (chosen == [PDFActionRemoteGoTo class])
        return [[PDFActionRemoteGoTo alloc] initWithCharonActionDictionary:action inDocument:document];
    if (chosen == [PDFActionResetForm class])
        return [[PDFActionResetForm alloc] initWithCharonActionDictionary:action];
    PDFAction *plain = [[PDFAction alloc] init];
    [plain charon_setTypeName:[NSString stringWithUTF8String:name]];
    return plain;
}

@end

// One -Wobjc-designated-initializers, and it is Apple's own shape rather than something left
// undone.  The iOS 16.0 arm64e cache gives PDFActionGoTo no -init of its own (own -init: 0),
// read with the tree's own census in modules/apple/objc.lua over that cache - the script is
// .agent-work/v-pdfkit/own-inits.lua and it runs through coordination/heavy.sh - while PDFAction
// has one (own -init: 1), PDFActionResetForm has one (own -init: 1), PDFDestination has one
// (own -init: 1) and PDFBorder has one (own -init: 1).  So [[X alloc] init] reaches PDFAction's,
// which is why a fresh action's -type is NIL - measured - and why this class needs no -init of
// its own to set its defaults.
//
// clang asks for the override anyway, because the header marks this class's own initializer a
// DESIGNATED one - PDFActionGoTo.h:25, PDFActionNamed.h:45, PDFActionURL.h:22 and
// PDFActionRemoteGoTo.h:27 each do exactly that - and that makes the inherited -init a
// convenience initializer.  PKPaymentRequestStatus11.m, MTLRasterizationRate13.m and
// PHObject8.m silence the same diagnostic for the same reason, and this is the same arrangement.
// Scoped to this @implementation with its push and pop, and no wider.
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
    [self charon_setTypeName:@"GoTo"];
    return self;
}

// A copy's destination is a NEW object - measured, the copy's destination is not the original's - so the
// destination itself is copied and not just pointed at.
- (id)copyWithZone:(NSZone *)zone
{
    PDFActionGoTo *copy = (PDFActionGoTo *)[super copyWithZone:zone];
    copy->_destination = [_destination copy];
    return copy;
}

// The /D, through PDFDestination's own reader.  PDF 1.7 Table 8.44 spells this action's /D as "an
// array or name" and not as a dictionary, so the value is read as whatever object it is:
//
//   an ARRAY is the destination itself - [page /XYZ left top zoom] - and is handed straight to the
//     reader.  Every /GoTo fixture in act-goto-* is this shape.
//
//   a NAME is the format's other spelling, and the host answers a destination whose PAGE is nil for it
//     (act-goto-named, whose /Dests is a name tree, and act-goto-named-dict, whose is a plain
//     dictionary).  So the object is built with nothing in it, which is that answer.
//
//   a /GoTo with NO /D at all is still an object with a nil destination - measured, act-goto-no-d.
- (instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action inDocument:(PDFDocument *)document
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
        _destination = [[PDFDestination alloc] initWithCharonDestinationArray:array
                                                                    inDocument:document];
    } else if (type == kCGPDFObjectTypeName || type == kCGPDFObjectTypeString) {
        _destination = [[PDFDestination alloc] initWithCharonDestinationArray:NULL
                                                                    inDocument:document];
    }
    return self;
}

@end
#pragma clang diagnostic pop

// One -Wobjc-designated-initializers, and it is Apple's own shape rather than something left
// undone.  The iOS 16.0 arm64e cache gives PDFActionNamed no -init of its own (own -init: 0),
// read with the tree's own census in modules/apple/objc.lua over that cache - the script is
// .agent-work/v-pdfkit/own-inits.lua and it runs through coordination/heavy.sh - while PDFAction
// has one (own -init: 1), PDFActionResetForm has one (own -init: 1), PDFDestination has one
// (own -init: 1) and PDFBorder has one (own -init: 1).  So [[X alloc] init] reaches PDFAction's,
// which is why a fresh action's -type is NIL - measured - and why this class needs no -init of
// its own to set its defaults.
//
// clang asks for the override anyway, because the header marks this class's own initializer a
// DESIGNATED one - PDFActionGoTo.h:25, PDFActionNamed.h:45, PDFActionURL.h:22 and
// PDFActionRemoteGoTo.h:27 each do exactly that - and that makes the inherited -init a
// convenience initializer.  PKPaymentRequestStatus11.m, MTLRasterizationRate13.m and
// PHObject8.m silence the same diagnostic for the same reason, and this is the same arrangement.
// Scoped to this @implementation with its push and pop, and no wider.
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
    [self charon_setTypeName:@"Named"];
    return self;
}

// The /N name, through the eight-name table above - and an /N outside it answers NIL rather than an
// object, which is what makes this initializer able to return nil and what the factory relies on.
//
// The table maps a name to the ENUM VALUE it answers, and not to a position: the enum's order and the
// host's eight are both measured, and the answer for each is its own value - /NextPage answers 1,
// /FirstPage 3, /LastPage 4, /GoBack 5, /GoForward 6, /GoToPage 7, /Find 8 and /Print 9.
// The name is a value, so a copy carries it and changing the copy's name leaves the original alone -
// measured.
- (id)copyWithZone:(NSZone *)zone
{
    PDFActionNamed *copy = (PDFActionNamed *)[super copyWithZone:zone];
    copy->_name = _name;
    return copy;
}

- (instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action
{
    NSString *name = charonActionString(action, "N");
    if (name == nil)
        return nil;
    PDFActionNamedName value = kPDFActionNamedNone;
    if (!charonNamedActionValue([name UTF8String], &value))
        return nil;
    return [self initWithName:value];
}

@end
#pragma clang diagnostic pop

// One -Wobjc-designated-initializers, and it is Apple's own shape rather than something left
// undone.  The iOS 16.0 arm64e cache gives PDFActionURL no -init of its own (own -init: 0),
// read with the tree's own census in modules/apple/objc.lua over that cache - the script is
// .agent-work/v-pdfkit/own-inits.lua and it runs through coordination/heavy.sh - while PDFAction
// has one (own -init: 1), PDFActionResetForm has one (own -init: 1), PDFDestination has one
// (own -init: 1) and PDFBorder has one (own -init: 1).  So [[X alloc] init] reaches PDFAction's,
// which is why a fresh action's -type is NIL - measured - and why this class needs no -init of
// its own to set its defaults.
//
// clang asks for the override anyway, because the header marks this class's own initializer a
// DESIGNATED one - PDFActionGoTo.h:25, PDFActionNamed.h:45, PDFActionURL.h:22 and
// PDFActionRemoteGoTo.h:27 each do exactly that - and that makes the inherited -init a
// convenience initializer.  PKPaymentRequestStatus11.m, MTLRasterizationRate13.m and
// PHObject8.m silence the same diagnostic for the same reason, and this is the same arrangement.
// Scoped to this @implementation with its push and pop, and no wider.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFActionURL {

    NSURL *_url;
}

@synthesize URL = _url;

// NSURL is immutable, so the copy shares it - which is what -[url copy] on the host answers and what
// assigning the property already does.
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
    [self charon_setTypeName:@"URI"];
    return self;
}

// The /URI, read as the format's string and handed to NSURL.  The host answers "https://example.com/a b"
// as "https://example.com/a%20b" and a RELATIVE /URI as itself - measured on act-uri and
// act-uri-shapes - and that percent-encoding is NSURL's own, which both sides share; what the port
// contributes is the string it read out of the dictionary, and the differential compares the two URLs
// as the host prints them.
- (instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action
{
    self = [self initWithURL:nil];
    if (self == nil)
        return nil;
    NSString *uri = charonActionString(action, "URI");
    if (uri != nil)
        _url = [NSURL URLWithString:uri];
    return self;
}

// A /Launch, measured on the host (annot-launch, annot-launch-spec, annot-launch-win): the action is a
// PDFActionURL whose type is Launch, and its URL is the TOP-LEVEL /F resolved against the document's directory
// the way -[PDFActionRemoteGoTo URL] resolves its own /F. The /F is a string, or a file specification whose /F
// is one - both give the same file URL. A /Launch with no top-level /F (annot-launch-win carries /Win) answers
// nil. Where the document has no URL to resolve against, the URL is nil, the same rule the /GoToR path keeps.
- (nullable instancetype)initWithCharonLaunchDictionary:(CGPDFDictionaryRef)action
                                             inDocument:(nullable PDFDocument *)document
{
    self = [self initWithURL:nil];
    if (self == nil)
        return nil;
    [self charon_setTypeName:@"Launch"];
    NSString *file = charonActionString(action, "F");
    if (file == nil) {
        CGPDFDictionaryRef spec = NULL;
        if (CGPDFDictionaryGetDictionary(action, "F", &spec) && spec != NULL)
            file = charonActionString(spec, "F");
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

// One -Wobjc-designated-initializers, and it is Apple's own shape rather than something left
// undone.  The iOS 16.0 arm64e cache gives PDFActionRemoteGoTo no -init of its own (own -init: 0),
// read with the tree's own census in modules/apple/objc.lua over that cache - the script is
// .agent-work/v-pdfkit/own-inits.lua and it runs through coordination/heavy.sh - while PDFAction
// has one (own -init: 1), PDFActionResetForm has one (own -init: 1), PDFDestination has one
// (own -init: 1) and PDFBorder has one (own -init: 1).  So [[X alloc] init] reaches PDFAction's,
// which is why a fresh action's -type is NIL - measured - and why this class needs no -init of
// its own to set its defaults.
//
// clang asks for the override anyway, because the header marks this class's own initializer a
// DESIGNATED one - PDFActionGoTo.h:25, PDFActionNamed.h:45, PDFActionURL.h:22 and
// PDFActionRemoteGoTo.h:27 each do exactly that - and that makes the inherited -init a
// convenience initializer.  PKPaymentRequestStatus11.m, MTLRasterizationRate13.m and
// PHObject8.m silence the same diagnostic for the same reason, and this is the same arrangement.
// Scoped to this @implementation with its push and pop, and no wider.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
@implementation PDFActionRemoteGoTo {
    NSUInteger _pageIndex;
    CGPoint _point;
    NSURL *_url;
    // Whether a point was ever SET, and it is what makes a FRESH object answer the unspecified sentinel
    // with no -init of its own: alloc zeroes the ivars, and zeroing gives the origin rather than the
    // sentinel.  Measured on [[PDFActionRemoteGoTo alloc] init], which answers index 0, an unspecified
    // point and a nil URL, and on every /GoToR fixture, which answers the same point.
    BOOL _pointIsSet;
}

@synthesize pageIndex = _pageIndex;
@synthesize URL = _url;

// -point, with the unset case the flag carries.  A point that WAS set is answered as it was set,
// including the origin: -initWithPageIndex:atPoint:fileURL: sets the flag whatever point it is given,
// and the dictionary reader below clears it again because a remote action's /D is not read for one.
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

// All three members are values, so a copy carries them.
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
    [self charon_setTypeName:@"GoToR"];
    return self;
}

// The three members, each measured:
//
//   -URL is the /F resolved AGAINST THE DOCUMENT'S OWN DIRECTORY.  act-gotor writes /F (other.pdf) beside
//     a document in /tmp/fc and the host answers file:///tmp/fc/other.pdf; and act-gotor-http writes an
//     /F that already looks absolute - https://example.com/other.pdf - and the host answers
//     file:///tmp/fc/https://example.com/other.pdf, so the /F is resolved as a RELATIVE name whatever it
//     looks like.  An action with no /F answers nil (act-gotor's second annotation).
//
//   -pageIndex is 0 on every /GoToR fixture measured, and NOT because it is a constant: the port's own
//     -initWithPageIndex:atPoint:fileURL: keeps the index it is given, and the host's does too -
//     initWithPageIndex:2 answers 2.  The 0s are a reading result: act-goto-page2's /D names object 4,
//     which IS the second page of that document, and the host still answers 0.  So the /D's page is not
//     resolved into this member - it belongs to the OTHER file, which is the point of a remote action -
//     and the member answers 0.  A /D that is a page index rather than a page reference
//     (act-gotor-index's /D 1) also answers 0.
//
//   -point is UNSPECIFIED on every /GoToR fixture, including the two whose /D is /XYZ - act-gotor's
//     [3 0 R /XYZ 5 6 2] and act-gotor-index's [3 0 R /XYZ 5 6 2].  So the remote action's position is
//     not read either, which is why the initializer's point stays the unspecified sentinel.
- (instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action inDocument:(PDFDocument *)document
{
    self = [self initWithPageIndex:0
                           atPoint:CGPointMake(kPDFDestinationUnspecifiedValue,
                                               kPDFDestinationUnspecifiedValue)
                           fileURL:nil];
    if (self == nil)
        return nil;
    // the flag back off: a remote action read out of a dictionary answers the same unspecified point a
    // fresh one does, which is measured on every /GoToR fixture
    _pointIsSet = NO;
    NSString *file = charonActionString(action, "F");
    NSURL *documentURL = [document documentURL];
    if (file != nil && documentURL != nil) {
        // resolved as a relative name against the document's own directory, by string: NSURL's
        // -URLByAppendingPathComponent: would percent-encode the slashes in an /F that looks absolute,
        // and the host does not - measured on act-gotor-http.
        // The directory is taken as a PATH and the result built with +fileURLWithPath:, because
        // concatenating the URL's absoluteString gives "file:/tmp/..." where the host answers
        // "file:///tmp/..." - measured on act-goto-page2, which was the fixture that showed it.
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

// -init is the header's own designated initializer (PDFActionResetForm.h:22) and a fresh one answers NO
// fields and -fieldsIncludedAreCleared YES - measured - which is the header's default and NOT what a
// dictionary carrying neither /Fields nor /Flags reads as (act-reset's second annotation answers NO).
- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _fieldsIncludedAreCleared = YES;
    [self charon_setTypeName:@"ResetForm"];
    return self;
}

// A copy's -fields is the SAME ARRAY the original holds - measured, resetCopy.fields == reset.fields -
// and not a copy of it.  So this member is shared rather than duplicated, which is also what the host
// answers, and it is the one member in this family whose copy is shallow.
- (id)copyWithZone:(NSZone *)zone
{
    PDFActionResetForm *copy = (PDFActionResetForm *)[super copyWithZone:zone];
    copy->_fields = _fields;
    copy->_fieldsIncludedAreCleared = _fieldsIncludedAreCleared;
    return copy;
}

// The /Fields array of names or strings, and the one rule behind -fieldsIncludedAreCleared.
//
// act-reset-flags.pdf carries SEVEN combinations of PDF 1.7 Table 8.44's /Flags and /Fields, and the
// host answers YES exactly when /FIELDS is present AND the /Flags bit of value 1 is clear:
//
//   /Fields present, no /Flags    YES        /Flags 0, /Fields    YES
//   /Flags 1, /Fields             NO         /Flags 2, /Fields    YES
//   /Flags 3, /Fields             NO         /Flags 1, no /Fields NO
//                                     /Flags 2, no /Fields NO
//
// The two rows with no /Fields are the ones that make it a rule about BOTH keys rather than about the
// bit: /Flags 2 alone would answer YES if only the bit mattered, and it answers NO.
- (instancetype)initWithCharonActionDictionary:(CGPDFDictionaryRef)action
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