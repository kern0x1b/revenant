// HKCDADocument, the document a CDA document sample holds: the data, the title and the three names of
// the people it is about.
//
// The class is of iOS 11.0, not of 10.0: the corpus dates HKCDADocumentSample and its members to 10.0 by
// the version of the class they sit in, and the class itself arrived a release later. So the document
// is a file of its own, of 11.0, and the 10.0 group that the corpus dated its five members to does not
// carry them. That is the release check the gate runs, finding HKDocument10.m holding two releases.
//
// AND THE NAME IS AN ALIAS, because the release carries this class from 10.0.1 and exports it only from
// 11.0. Measured with apple.objc.inventory and apple.dyld over the caches this package is built for:
// 10.0.1, 10.1, 10.2 and 10.3.4 (armv7s) all carry HKCDADocument in HealthKit's __objc_classlist -
// superclass NSObject, fifteen own methods of its own, adopting no protocol - and no image of any of
// them exports _OBJC_CLASS_$_HKCDADocument or its metaclass, while 11.0 (arm64) exports both from
// HealthKit. So a band of 10.0.1 to 10.3.4 that linked the class implementation this file used to hold
// would have two classes of one name in every process, and the runtime keeps the one it registered
// first, which is the release's. The name therefore goes through charon_alias.h, which is what
// modules/apple/backports.lua's own check asks for when it reads this reading ("the release carries
// HKCDADocument in HealthKit without exporting it: alias it through charon_alias.h") and what
// MDLMeshBufferZoneDefault, NSTextList and NSTextTab already are for the same one.
//
// The members are a CATEGORY on Charon's own name, which ld64 merges into the proxy: a class
// implementation here would be that second class on every band from 10.0.1 on. A category cannot add an
// instance variable and neither can the class behind an alias (attach.c lays the proxy out from the
// release's class and takes that write back when the two instance sizes differ), so the document's own
// five values are an associated object - the shape CarPlay's CPListItem row and ModelIO's mesh buffer
// zone already use.
//
// What each band answers, all three measured above:
//   * From 11.0 the release exports the name, the band reexports the symbol and links neither the
//     category's object nor the proxy, and HealthKit's own class answers.
//   * On 10.0.1 to 10.3.4 the release's class answers -documentData, -title, -patientName, -authorName
//     and -custodianName, and this category is attached only where the class does not answer the
//     selector: the five-argument -charon_initWithDocumentData: and this file's -initWithCoder: and
//     -encodeWithCoder: are the port's own there (HealthKit's are the -omittedContentFlags: spellings),
//     while -copyWithZone:, -isEqual:, -hash and -description are NSObject's or the release's and this
//     category's copies of them are not attached. Nothing in such a band makes a document of ours:
//     HKDocument10.o is reexported there, measured with band() at 10.0.1 and 10.3.4, so the sample's own
//     -document is Apple's there and Apple's allocator of documents is Apple's.
//   * Below 10.0.1 the release has no HealthKit class of this name at all, the proxy IS the class, and
//     every method below answers with the state beside it.
//
// What is not measured: nothing here was run on a device, and a document Apple's own sample hands out
// on 10.x and a document of ours below 10.0.1 are different objects by construction.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "../charon_alias.h"

// The document's own five values, made when the document is first asked for, which is what a document
// made by NSObject's -init on a release that has no class of this name reads: no data, no names.
@interface CharonHKCDADocumentState : NSObject
@property (nonatomic, copy) NSData *documentData;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *patientName;
@property (nonatomic, copy, nullable) NSString *authorName;
@property (nonatomic, copy, nullable) NSString *custodianName;
@end

@implementation CharonHKCDADocumentState

@synthesize documentData = _documentData;
@synthesize title = _title;
@synthesize patientName = _patientName;
@synthesize authorName = _authorName;
@synthesize custodianName = _custodianName;

@end

// The class the release's name stands for, and nothing else: its superclass is the release's own
// (NSObject, measured at every release that carries the class) and it adopts no protocol, which is
// what CHARON_ALIAS declares it with. The release's name is exported to it.
CHARON_ALIAS(HKCDADocument)

// The state of a document, made when it is first asked for. It is a C function and not a method so that
// no selector of Charon's own lands on the release's class on a band where the release has one: this
// file's members are the release's own API or the seams CharonHKStore.h declares, and nothing else.
static CharonHKCDADocumentState *CharonHKCDADocumentStateOf(id document)
{
    static const void *key = &key;
    CharonHKCDADocumentState *state = objc_getAssociatedObject(document, key);
    if (!state) {
        state = [[CharonHKCDADocumentState alloc] init];
        objc_setAssociatedObject(document, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@implementation CHARON_ALIAS_CLASS(HKCDADocument) (CharonHKCDADocument11)

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The seam HKDocument10.m builds a document with. It is not in the init family by name, so `self` is
// not assignable in it and the object is made the way the file it replaces made it: through [super init]
// and then filled in.
- (instancetype)charon_initWithDocumentData:(NSData *)documentData
                                      title:(nullable NSString *)title
                                 patientName:(nullable NSString *)patientName
                                  authorName:(nullable NSString *)authorName
                               custodianName:(nullable NSString *)custodianName
{
    CHARON_ALIAS_CLASS(HKCDADocument) *document = [super init];
    if (document) {
        CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(document);
        state.documentData = documentData;
        state.title = title;
        state.patientName = patientName;
        state.authorName = authorName;
        state.custodianName = custodianName;
    }
    return document;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    CHARON_ALIAS_CLASS(HKCDADocument) *document = [super init];
    if (document) {
        CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(document);
        state.documentData = [[coder decodeObjectOfClass:[NSData class] forKey:@"documentData"] copy];
        state.title = [[coder decodeObjectOfClass:[NSString class] forKey:@"title"] copy];
        state.patientName = [[coder decodeObjectOfClass:[NSString class] forKey:@"patientName"] copy];
        state.authorName = [[coder decodeObjectOfClass:[NSString class] forKey:@"authorName"] copy];
        state.custodianName = [[coder decodeObjectOfClass:[NSString class] forKey:@"custodianName"] copy];
    }
    return document;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(self);
    [coder encodeObject:state.documentData forKey:@"documentData"];
    [coder encodeObject:state.title forKey:@"title"];
    [coder encodeObject:state.patientName forKey:@"patientName"];
    [coder encodeObject:state.authorName forKey:@"authorName"];
    [coder encodeObject:state.custodianName forKey:@"custodianName"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(self);
    // [self class] is the proxy's own +class, which answers the proxy where the release has no class of
    // this name (the band where this body runs at all), and its +alloc then makes one.
    return [[[self class] alloc] charon_initWithDocumentData:state.documentData
                                               title:state.title
                                          patientName:state.patientName
                                           authorName:state.authorName
                                        custodianName:state.custodianName];
}

- (NSData *)documentData
{
    return CharonHKCDADocumentStateOf(self).documentData;
}

- (NSString *)title
{
    return CharonHKCDADocumentStateOf(self).title;
}

- (NSString *)patientName
{
    return CharonHKCDADocumentStateOf(self).patientName;
}

- (NSString *)authorName
{
    return CharonHKCDADocumentStateOf(self).authorName;
}

- (NSString *)custodianName
{
    return CharonHKCDADocumentStateOf(self).custodianName;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKCDADocument class]])
        return NO;
    CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(self);
    CharonHKCDADocumentState *that = CharonHKCDADocumentStateOf(other);
    return [state.documentData isEqualToData:that.documentData]
           && (state.title == that.title || [state.title isEqualToString:that.title])
           && (state.patientName == that.patientName || [state.patientName isEqualToString:that.patientName])
           && (state.authorName == that.authorName || [state.authorName isEqualToString:that.authorName])
           && (state.custodianName == that.custodianName || [state.custodianName isEqualToString:that.custodianName]);
}

- (NSUInteger)hash
{
    CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(self);
    return state.documentData.hash ^ state.title.hash;
}

- (NSString *)description
{
    CharonHKCDADocumentState *state = CharonHKCDADocumentStateOf(self);
    return [NSString stringWithFormat:@"HKCDADocument[%@ %lu bytes]", state.title,
            (unsigned long)state.documentData.length];
}

@end