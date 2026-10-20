#import <Foundation/Foundation.h>
#import "RevenantTermOfAddress.h"
#import <objc/message.h>
#import <objc/runtime.h>

static char RevenantTermOfAddressStateKey;

@interface RevenantTermOfAddressState : NSObject
@property NSString *languageIdentifier;
@property NSArray *pronouns;
@property BOOL currentUser;
@property NSString *origin;
@end

@implementation RevenantTermOfAddressState

@synthesize languageIdentifier = _languageIdentifier;
@synthesize pronouns = _pronouns;
@synthesize currentUser = _currentUser;
@synthesize origin = _origin;

@end

static char RevenantTermOfAddressStateKey;

@implementation NSTermOfAddress

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)revenant_termWithLanguage:(NSString *)language pronouns:(NSArray *)pronouns currentUser:(BOOL)currentUser
{
    return [self revenant_termWithLanguage:language pronouns:pronouns currentUser:currentUser origin:nil];
}

+ (instancetype)revenant_termWithLanguage:(NSString *)language pronouns:(NSArray *)pronouns currentUser:(BOOL)currentUser origin:(NSString *)origin
{
    NSTermOfAddress *term = [NSTermOfAddress alloc];
    struct objc_super super = { .receiver = term, .super_class = [NSObject class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, @selector(init));
    RevenantTermOfAddressState *state = [[RevenantTermOfAddressState alloc] init];
    state.languageIdentifier = [language copy];
    state.pronouns = [pronouns copy];
    state.currentUser = currentUser;
    state.origin = origin;
    objc_setAssociatedObject(term, &RevenantTermOfAddressStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return term;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSTermOfAddress class]])
        return NO;
    RevenantTermOfAddressState *mine = objc_getAssociatedObject(self, &RevenantTermOfAddressStateKey);
    RevenantTermOfAddressState *theirs = objc_getAssociatedObject(object, &RevenantTermOfAddressStateKey);
    if (!mine || !theirs)
        return NO;
    if (mine.currentUser != theirs.currentUser)
        return NO;
    if (mine.origin != theirs.origin && ![mine.origin isEqualToString:theirs.origin])
        return NO;
    if (mine.languageIdentifier != theirs.languageIdentifier &&
        ![mine.languageIdentifier isEqualToString:theirs.languageIdentifier])
        return NO;
    return mine.pronouns == theirs.pronouns || [mine.pronouns isEqualToArray:theirs.pronouns];
}

- (NSUInteger)hash
{
    RevenantTermOfAddressState *state = objc_getAssociatedObject(self, &RevenantTermOfAddressStateKey);
    return state.languageIdentifier.hash ^ state.pronouns.count ^ (state.currentUser ? 2u : 0u) ^ state.origin.hash;
}

+ (instancetype)neutral
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self revenant_termWithLanguage:nil pronouns:nil currentUser:NO origin:@"neutral"];
    });
    return term;
}

+ (instancetype)feminine
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self revenant_termWithLanguage:nil pronouns:nil currentUser:NO origin:@"feminine"];
    });
    return term;
}

+ (instancetype)masculine
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self revenant_termWithLanguage:nil pronouns:nil currentUser:NO origin:@"masculine"];
    });
    return term;
}

+ (instancetype)currentUser
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self revenant_termWithLanguage:nil pronouns:nil currentUser:YES origin:@"currentUser"];
    });
    return term;
}

+ (instancetype)localizedForLanguageIdentifier:(NSString *)language withPronouns:(NSArray *)pronouns
{
    return [self revenant_termWithLanguage:language pronouns:pronouns currentUser:NO origin:@"localized"];
}

+ (instancetype)termWithLanguageIdentifier:(NSString *)language
{
    return [self localizedForLanguageIdentifier:language withPronouns:nil];
}

- (NSString *)languageIdentifier
{
    RevenantTermOfAddressState *state = objc_getAssociatedObject(self, &RevenantTermOfAddressStateKey);
    return state ? state.languageIdentifier : nil;
}

- (NSArray *)pronouns
{
    RevenantTermOfAddressState *state = objc_getAssociatedObject(self, &RevenantTermOfAddressStateKey);
    return state ? state.pronouns : nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSTermOfAddress cannot be encoded by non-keyed archivers"];
        return;
    }
    RevenantTermOfAddressState *state = objc_getAssociatedObject(self, &RevenantTermOfAddressStateKey);
    [coder encodeObject:state.languageIdentifier forKey:@"NS.languageIdentifier"];
    [coder encodeObject:state.pronouns forKey:@"NS.pronouns"];
    [coder encodeBool:state.currentUser forKey:@"NS.currentUser"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSTermOfAddress cannot be decoded by non-keyed archivers"];
        return nil;
    }
    self = [super init];
    if (!self)
        return nil;
    RevenantTermOfAddressState *state = [[RevenantTermOfAddressState alloc] init];
    state.languageIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.languageIdentifier"];
    state.pronouns = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                          forKey:@"NS.pronouns"];
    state.currentUser = [coder decodeBoolForKey:@"NS.currentUser"];
    objc_setAssociatedObject(self, &RevenantTermOfAddressStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

@end
