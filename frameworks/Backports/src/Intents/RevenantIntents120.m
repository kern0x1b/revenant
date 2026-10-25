#if defined(REVENANT_HOST_BUILD)
#define INObject INObjectRevenant
#define INObjectSection INObjectSectionRevenant
#define INObjectCollection INObjectCollectionRevenant
#define INObjectResolutionResult INObjectResolutionResultRevenant
#endif

#import <Intents/Intents.h>
#import <Intents/INObject.h>
#import <Intents/INObjectSection.h>
#import <Intents/INObjectCollection.h>
#import <Intents/INObjectResolutionResult.h>

#import "coding/RevenantCoding.h"
#import "RevenantIntentsResolution.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#pragma mark - INObject

@implementation INObject {
    NSString *_identifier;
    NSString *_displayString;
    NSString *_pronunciationHint;
    NSString *_subtitleString;
    INImage *_displayImage;
    NSArray *_alternativeSpeakableMatches;
}

@synthesize identifier = _identifier;
@synthesize displayString = _displayString;
@synthesize pronunciationHint = _pronunciationHint;
@synthesize subtitleString = _subtitleString;
@synthesize displayImage = _displayImage;
@synthesize alternativeSpeakableMatches = _alternativeSpeakableMatches;

- (instancetype)initWithIdentifier:(NSString *)identifier
                     displayString:(NSString *)displayString
                 pronunciationHint:(NSString *)pronunciationHint
{
    if ((self = [super init])) {
        _identifier = [identifier copy];
        _displayString = [displayString copy];
        _pronunciationHint = [pronunciationHint copy];
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                     displayString:(NSString *)displayString
{
    return [self initWithIdentifier:identifier displayString:displayString pronunciationHint:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                     displayString:(NSString *)displayString
                    subtitleString:(NSString *)subtitleString
                      displayImage:(INImage *)displayImage
{
    return [self initWithIdentifier:identifier displayString:displayString pronunciationHint:nil subtitleString:subtitleString displayImage:displayImage];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                     displayString:(NSString *)displayString
                 pronunciationHint:(NSString *)pronunciationHint
                    subtitleString:(NSString *)subtitleString
                      displayImage:(INImage *)displayImage
{
    if ((self = [self initWithIdentifier:identifier displayString:displayString pronunciationHint:pronunciationHint])) {
        _subtitleString = [subtitleString copy];
        _displayImage = displayImage;
    }
    return self;
}

- (NSString *)spokenPhrase
{
    return _displayString;
}

- (NSString *)vocabularyIdentifier
{
    return _identifier;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INObject *other = object;
    return ((_identifier == other->_identifier) || [_identifier isEqualToString:other->_identifier]) &&
        ((_displayString == other->_displayString) || [_displayString isEqualToString:other->_displayString]) &&
        ((_pronunciationHint == other->_pronunciationHint) || [_pronunciationHint isEqualToString:other->_pronunciationHint]) &&
        ((_subtitleString == other->_subtitleString) || [_subtitleString isEqualToString:other->_subtitleString]) &&
        ((_displayImage == other->_displayImage) || [_displayImage isEqual:other->_displayImage]);
}

- (NSUInteger)hash
{
    return _identifier.hash ^ (_displayString.hash << 1);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INObject *copy = [[[self class] allocWithZone:zone] initWithIdentifier:_identifier displayString:_displayString pronunciationHint:_pronunciationHint];
    copy->_subtitleString = [_subtitleString copy];
    copy->_displayImage = _displayImage;
    copy->_alternativeSpeakableMatches = [_alternativeSpeakableMatches copy];
    return copy;
}

@end

#pragma mark - INObjectSection

@implementation INObjectSection {
    NSString *_title;
    NSArray *_items;
}

@synthesize title = _title;
@synthesize items = _items;

- (instancetype)initWithTitle:(NSString *)title items:(NSArray *)items
{
    if ((self = [super init])) {
        _title = [title copy];
        _items = [items copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INObjectSection *other = object;
    return ((_title == other->_title) || [_title isEqualToString:other->_title]) && [_items isEqualToArray:other->_items];
}

- (NSUInteger)hash
{
    return _title.hash ^ _items.count;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithTitle:_title items:_items];
}

@end

#pragma mark - INObjectCollection

@implementation INObjectCollection {
    NSArray *_sections;
    BOOL _usesIndexedCollation;
}

@synthesize sections = _sections;
@synthesize usesIndexedCollation = _usesIndexedCollation;

- (instancetype)initWithSections:(NSArray *)sections
{
    if ((self = [super init])) {
        _sections = [sections copy];
    }
    return self;
}

- (instancetype)initWithItems:(NSArray *)items
{
    return [self initWithSections:@[[[INObjectSection alloc] initWithTitle:nil items:items]]];
}

- (NSArray *)allItems
{
    NSMutableArray *items = [NSMutableArray array];
    for (INObjectSection *section in _sections) {
        [items addObjectsFromArray:section.items];
    }
    return [items copy];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[self class]])
        return NO;
    INObjectCollection *other = object;
    return [_sections isEqualToArray:other->_sections] && _usesIndexedCollation == other->_usesIndexedCollation;
}

- (NSUInteger)hash
{
    return _sections.count ^ (NSUInteger)_usesIndexedCollation;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INObjectCollection *copy = [[[self class] allocWithZone:zone] initWithSections:_sections];
    copy->_usesIndexedCollation = _usesIndexedCollation;
    return copy;
}

@end

#pragma mark - INObjectResolutionResult

@implementation INObjectResolutionResult

+ (instancetype)successWithResolvedObject:(INObject *)resolvedObject
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionSuccess
                                 resolvedValue:resolvedObject
                          valuesToDisambiguate:nil
                                valueToConfirm:nil];
}

+ (instancetype)disambiguationWithObjectsToDisambiguate:(NSArray<INObject *> *)objectsToDisambiguate
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionDisambiguation
                                 resolvedValue:nil
                          valuesToDisambiguate:objectsToDisambiguate
                                valueToConfirm:nil];
}

+ (instancetype)confirmationRequiredWithObjectToConfirm:(INObject *)objectToConfirm
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                 resolvedValue:nil
                          valuesToDisambiguate:nil
                                valueToConfirm:objectToConfirm];
}

@end
