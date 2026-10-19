#import <UIKit/UIKit.h>

// A suggestion listed under a search field: the text it suggests, an optional description and icon, and an object the app attaches.
// The release copies a plain suggestion string and keeps the attributed suggestion, the icon and the description as given (the
// description copied, as the string is); a plain initialiser leaves the attributed suggestion nil, and an attributed initialiser sets
// the plain suggestion to the attributed string's text. Equality compares every value the item holds, the represented object included.
//
// The class conforms to UISearchSuggestion, so the protocol is emitted by this object: a name the port answers.
@interface UISearchSuggestionItem () <UISearchSuggestion>
@end

// Two values are equal when both are nil, or when they are equal objects (a nil never equals a non-nil value).
static BOOL charon_sameValue(id first, id second)
{
    return first == second || [first isEqual:second];
}

@implementation UISearchSuggestionItem {
@private
    NSString *_localizedSuggestion;
    NSAttributedString *_localizedAttributedSuggestion;
    NSString *_localizedDescription;
    UIImage *_iconImage;
    id _representedObject;
}

+ (instancetype)suggestionWithLocalizedSuggestion:(NSString *)suggestion
{
    return [[self alloc] initWithLocalizedSuggestion:suggestion];
}

+ (instancetype)suggestionWithLocalizedSuggestion:(NSString *)suggestion descriptionString:(NSString *)description
{
    return [[self alloc] initWithLocalizedSuggestion:suggestion localizedDescription:description];
}

+ (instancetype)suggestionWithLocalizedSuggestion:(NSString *)suggestion descriptionString:(NSString *)description iconImage:(UIImage *)iconImage
{
    return [[self alloc] initWithLocalizedSuggestion:suggestion localizedDescription:description iconImage:iconImage];
}

+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion
{
    return [[self alloc] initWithLocalizedAttributedSuggestion:suggestion];
}

+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion descriptionString:(NSString *)description
{
    return [[self alloc] initWithLocalizedAttributedSuggestion:suggestion localizedDescription:description];
}

+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion descriptionString:(NSString *)description iconImage:(UIImage *)iconImage
{
    return [[self alloc] initWithLocalizedAttributedSuggestion:suggestion localizedDescription:description iconImage:iconImage];
}

- (instancetype)initWithLocalizedSuggestion:(NSString *)suggestion
{
    return [self initWithLocalizedSuggestion:suggestion localizedDescription:nil iconImage:nil];
}

- (instancetype)initWithLocalizedSuggestion:(NSString *)suggestion localizedDescription:(NSString *)description
{
    return [self initWithLocalizedSuggestion:suggestion localizedDescription:description iconImage:nil];
}

- (instancetype)initWithLocalizedSuggestion:(NSString *)suggestion localizedDescription:(NSString *)description iconImage:(UIImage *)iconImage
{
    if ((self = [super init])) {
        _localizedSuggestion = [suggestion copy];
        _localizedDescription = [description copy];
        _iconImage = iconImage;
    }
    return self;
}

- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion
{
    return [self initWithLocalizedAttributedSuggestion:suggestion localizedDescription:nil iconImage:nil];
}

- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion localizedDescription:(NSString *)description
{
    return [self initWithLocalizedAttributedSuggestion:suggestion localizedDescription:description iconImage:nil];
}

- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion localizedDescription:(NSString *)description iconImage:(UIImage *)iconImage
{
    if ((self = [super init])) {
        _localizedAttributedSuggestion = suggestion;
        _localizedSuggestion = [suggestion string];
        _localizedDescription = [description copy];
        _iconImage = iconImage;
    }
    return self;
}

- (NSString *)localizedSuggestion
{
    return _localizedSuggestion;
}

- (NSAttributedString *)localizedAttributedSuggestion
{
    return _localizedAttributedSuggestion;
}

- (NSString *)localizedDescription
{
    return _localizedDescription;
}

- (UIImage *)iconImage
{
    return _iconImage;
}

- (id)representedObject
{
    return _representedObject;
}

- (void)setRepresentedObject:(id)representedObject
{
    _representedObject = representedObject;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[UISearchSuggestionItem class]]) {
        return NO;
    }
    UISearchSuggestionItem *other = object;
    return charon_sameValue(_localizedSuggestion, other->_localizedSuggestion)
        && charon_sameValue(_localizedAttributedSuggestion, other->_localizedAttributedSuggestion)
        && charon_sameValue(_localizedDescription, other->_localizedDescription)
        && charon_sameValue(_iconImage, other->_iconImage)
        && charon_sameValue(_representedObject, other->_representedObject);
}

// The hash follows the suggestion and the description, which every equal pair shares; the rest may collide.
- (NSUInteger)hash
{
    return [_localizedSuggestion hash] * 31 + [_localizedDescription hash];
}

@end
