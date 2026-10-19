#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "../charon_alias.h"

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

CHARON_ALIAS(HKCDADocument)

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
