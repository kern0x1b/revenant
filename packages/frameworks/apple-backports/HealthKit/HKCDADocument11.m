#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"
#import "../revenant_alias.h"

@interface RevenantHKCDADocumentState : NSObject
@property (nonatomic, copy) NSData *documentData;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *patientName;
@property (nonatomic, copy, nullable) NSString *authorName;
@property (nonatomic, copy, nullable) NSString *custodianName;
@end

@implementation RevenantHKCDADocumentState

@synthesize documentData = _documentData;
@synthesize title = _title;
@synthesize patientName = _patientName;
@synthesize authorName = _authorName;
@synthesize custodianName = _custodianName;

@end

REVENANT_ALIAS(HKCDADocument)

static RevenantHKCDADocumentState *RevenantHKCDADocumentStateOf(id document)
{
    static const void *key = &key;
    RevenantHKCDADocumentState *state = objc_getAssociatedObject(document, key);
    if (!state) {
        state = [[RevenantHKCDADocumentState alloc] init];
        objc_setAssociatedObject(document, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

@implementation REVENANT_ALIAS_CLASS(HKCDADocument) (RevenantHKCDADocument11)

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)revenant_initWithDocumentData:(NSData *)documentData
                                      title:(nullable NSString *)title
                                 patientName:(nullable NSString *)patientName
                                  authorName:(nullable NSString *)authorName
                               custodianName:(nullable NSString *)custodianName
{
    REVENANT_ALIAS_CLASS(HKCDADocument) *document = [super init];
    if (document) {
        RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(document);
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
    REVENANT_ALIAS_CLASS(HKCDADocument) *document = [super init];
    if (document) {
        RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(document);
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
    RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(self);
    [coder encodeObject:state.documentData forKey:@"documentData"];
    [coder encodeObject:state.title forKey:@"title"];
    [coder encodeObject:state.patientName forKey:@"patientName"];
    [coder encodeObject:state.authorName forKey:@"authorName"];
    [coder encodeObject:state.custodianName forKey:@"custodianName"];
}

- (id)copyWithZone:(NSZone *)zone
{
    RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(self);
    return [[[self class] alloc] revenant_initWithDocumentData:state.documentData
                                               title:state.title
                                          patientName:state.patientName
                                           authorName:state.authorName
                                        custodianName:state.custodianName];
}

- (NSData *)documentData
{
    return RevenantHKCDADocumentStateOf(self).documentData;
}

- (NSString *)title
{
    return RevenantHKCDADocumentStateOf(self).title;
}

- (NSString *)patientName
{
    return RevenantHKCDADocumentStateOf(self).patientName;
}

- (NSString *)authorName
{
    return RevenantHKCDADocumentStateOf(self).authorName;
}

- (NSString *)custodianName
{
    return RevenantHKCDADocumentStateOf(self).custodianName;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKCDADocument class]])
        return NO;
    RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(self);
    RevenantHKCDADocumentState *that = RevenantHKCDADocumentStateOf(other);
    return [state.documentData isEqualToData:that.documentData]
           && (state.title == that.title || [state.title isEqualToString:that.title])
           && (state.patientName == that.patientName || [state.patientName isEqualToString:that.patientName])
           && (state.authorName == that.authorName || [state.authorName isEqualToString:that.authorName])
           && (state.custodianName == that.custodianName || [state.custodianName isEqualToString:that.custodianName]);
}

- (NSUInteger)hash
{
    RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(self);
    return state.documentData.hash ^ state.title.hash;
}

- (NSString *)description
{
    RevenantHKCDADocumentState *state = RevenantHKCDADocumentStateOf(self);
    return [NSString stringWithFormat:@"HKCDADocument[%@ %lu bytes]", state.title,
            (unsigned long)state.documentData.length];
}

@end
