#import "CharonPDFKit.h"

// PDFOutline over the /Outlines tree of PDF 1.7 Table 8.2.  An outline is a LINKED structure rather than
// a tree of nested dictionaries: the catalog's /Outlines names the root dictionary, every item names its
// /Parent, its /Prev and its /Next, and an item's children are its /First .. /Last chain.  So the whole
// of this class is walking those links with the release's own dictionary and array readers.
//
// Every rule below is measured on the host over the fixtures in tools/make-object-fixtures.py, and each
// names the fixture that fixes it.  Two of them are not what the format says, and both are called out at
// the member they belong to: -isOpen reads the SIGN of /Count the other way round from Table 8.2, and
// an item with no /Count and no /Title is OPEN.

@implementation PDFOutline {
    // The item dictionary, or the catalog's /Outlines ROOT dictionary for the root outline - the root is
    // a dictionary of the same shape and holds the /First of the top-level chain.
    CGPDFDictionaryRef _item;
    // Weak, as PDFOutline.h:21 declares it: an outline does not keep its document alive.
    __weak PDFDocument *_document;
    // Weak, as PDFOutline.h:33 declares it: a parent does not keep its children alive.
    __weak PDFOutline *_parent;
    NSString *_label;
    // Where this item sits in its parent's chain, zero-based - measured, and the root's own answer is 0.
    NSUInteger _index;
    // The children, built once, because -childAtIndex: and -numberOfChildren both walk the chain and an
    // outline is a fixed structure once the document is open.
    NSArray *_children;
}

// -init is the header's own designated initializer (PDFOutline.h:20) and is implemented because a class a
// program cannot construct answers a crash where the host answers an object - measured, and the harness's
// own init-outline.* keys compare it.  A fresh one answers an EMPTY label, no children, index 0, closed,
// no parent, no document, no destination and no action.
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

// The CHILDREN, built from the item's /First .. /Next chain, and memoised.  The chain is walked with the
// release's own reader and each element must resolve to a dictionary; an element that does not ends the
// chain, because there is nothing further to follow.
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

// -numberOfChildren is the length of that chain, and 0 for an item with no /First - measured on every
// fixture, where the untitled and titled leaves both answer 0.
- (NSUInteger)numberOfChildren
{
    return [self charon_children].count;
}

// -childAtIndex: answers the item at that position, and there are TWO out-of-range answers on the host,
// not one.  Both are measured on outline-collapsed.pdf's whole tree, every node asked at every index from
// 0 to its own child count:
//
//   a node WITH children raises past the end: "childAtIndex: 2 out of bounds" on the root, which has two,
//   and "childAtIndex: 1 out of bounds" on "Two One"'s parent, which has one.
//
//   a node with NO children answers NIL, even at index 0 - "One One One" and "One Two" and "Two One" all
//   answer nil and none of them raises.  So the rule is not "past the end raises": it is that a node with
//   a /First chain raises when the index runs off it, and a node with no chain at all has nothing to walk
//   and answers nil.
//
// The earlier version of this answered nil everywhere.  The coordinator's correction is right that a
// counted sequence raises out of range, and this is the whole of what it takes: raise only where the
// chain exists, and answer nil where it does not.  The harness compares both answers through @try, so a
// side that raises where the host answers nil - or the reverse - names itself.
- (PDFOutline *)childAtIndex:(NSUInteger)index
{
    NSArray *children = [self charon_children];
    if (index >= children.count) {
        if (children.count > 0) {
            [NSException raise:NSRangeException
                        format:@"childAtIndex: %lu out of bounds", (unsigned long)index];
            return nil;                 // unreachable: raise does not return
        }
        return nil;                     // no /First chain to walk, and the host answers nil
    }
    return children[index];
}

// -label is the /Title, and a MISSING /Title answers an EMPTY STRING and not nil - measured: the root of
// every fixture carries no /Title and answers "", and so does a fresh -init and every untitled item.
- (NSString *)label
{
    return _label;
}

// -isOpen is the one member whose rule is not the format's.
//
// Table 8.2 says a POSITIVE /Count means the item is CLOSED.  The host reads it the OTHER way round:
// outline-signs.pdf has two items of the same shape - two children each - one with /Count +4 and one
// with /Count -4, and the positive one answers isOpen YES and the negative one NO.  So:
//
//   an item WITH a /Count answers YES when the count is positive and NO when it is negative.
//
// And an item with NO /Count answers YES only when it has no /Title either.  That is measured on five
// fixtures and it is a rule about two keys, not one:
//
//   outline-titlekey.pdf's five leaves differ only in their /Title: one with no /Title answers YES,
//   one with an EMPTY /Title () answers NO, and one with a real /Title answers NO.
//
//   outline-nocount.pdf's four titled items with no /Count all answer NO, three runs each.
//
//   outline-untitled.pdf's chain of four UNTITLED items answers NO, NO, NO and YES - the three with
//   children have a negative /Count and the leaf has none - while outline-titled.pdf's chain of four
//   TITLED items with the same shape answers NO four times.  The two fixtures differ only in the /Title.
//
//   and the item's /F and /Dest make no difference: outline-titlekey carries a leaf with no /F and one
//   with a /Dest, and both answer YES.
//
// So: YES when the /Count is positive, and YES when there is no /Count AND no /Title.  Whether that is
// what the host means to do or a side effect of how it stores the flag is not written down anywhere in
// the SDK; this is what it answers, and each clause above is the fixture that fixes it.
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

// -destination is the item's /Dest, and Table 8.2 spells that as an ARRAY or a NAME - not as a
// dictionary, so this is the same three cases PDFAnnotation11.m reads and for the same measured reasons:
//
//   an ARRAY is the destination itself and is handed to PDFDestination's reader;
//   a NAME or a string builds a destination with nothing in it, whose page is nil - measured, and
//     outline-shapes.pdf's "Named" item, whose /Dest is (chapter1), is that case;
//   anything else, including the dictionary spelling, answers nil.
//
// An item that names no /Dest at all answers nil - measured on every fixture.
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

// -action is the item's /A read through PDFAction's factory, and the ORDER IS THE OPPOSITE of an
// annotation's: here the /Dest wins.  Measured on outline-shapes.pdf's "Child", which carries both a
// /Dest of [3 0 R /XYZ 1 2 3] and an /A of /GoTo [3 0 R /Fit] - the host answers the /DEST's 1,2,3 for
// both -destination and -action, where an annotation carrying the same pair answers the /A's, which is
// what ann-dest-and-a shows and what PDFAnnotation11.m implements.
//
// So: a /Dest gives a GoTo synthesised over it (PDF 1.7 Table 8.2: an item's /Dest is the destination of
// a go-to action), and only an item with no /Dest has its /A read.  An item with neither answers nil for
// both - measured on every fixture.
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
    // The dictionary belongs to the CGPDFDocument, which the PDFDocument holds above us, so the borrowed
    // pointer is safe for as long as this object lives.
    _item = item;
    _document = document;
    _parent = parent;
    _index = index;
    // A /Title of any kind - including an empty one - answers the empty string, and so does its absence,
    // so the label is read once here rather than asked of the dictionary on every call.
    _label = [self charon_title] ?: @"";
    return self;
}

// The item's /Title, as the format's string or name, or nil when it names none.
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