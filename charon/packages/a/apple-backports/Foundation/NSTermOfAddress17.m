#import <Foundation/Foundation.h>
#import "CharonTermOfAddress.h"
#import <objc/message.h>
#import <objc/runtime.h>

/* A term of address: the word an application uses to address the person it is speaking to, and the
   pronouns that go with it. The localized words themselves come out of the inflection machinery,
   which is NSMorphology's business; what is here is the term, its language and its pronouns.

   Measured on the host, and the port does the same: the three gendered terms are three distinct
   singletons with no language and no pronouns, each equal only to itself and hashing alike each time
   it is asked; +currentUser is a singleton too and equal only to itself; a localized term is equal to
   another with the same language and the same pronouns, different when the language differs, and
   different again when the pronouns are an empty array rather than nil (measured:
   localizedForLanguageIdentifier:@"de" withPronouns:@[] is not equal to the same call with nil).

   The state is one object kept beside the instance, for the reason every such object in this
   package is: the SDK's declaration carries no ivar block and the armv7 ABI has nowhere to add one.
   The class is declared in CharonTermOfAddress.h, without an availability mark, because the SDK this
   package is built against does not declare the class at all; see that header for the gate's words
   on the matter. */

static char CharonTermOfAddressStateKey;

@interface CharonTermOfAddressState : NSObject
@property NSString *languageIdentifier;
@property NSArray *pronouns;
@property BOOL currentUser;
/* Which factory built it, so that two terms from different factories are never equal even when
   their state is the same -- the three gendered terms all carry no language and no pronouns. */
@property NSString *origin;
@end

@implementation CharonTermOfAddressState

/* Two terms are equal when the same factory made them and their state is equal, so +neutral,
   +feminine, +masculine and +currentUser stay four singletons that are equal only to themselves --
   which is what the header promises for +currentUser, and what the host answers for all four
   (measured: the three gendered terms are mutually unequal with distinct hashes, 3, 1 and 2). */

@synthesize languageIdentifier = _languageIdentifier;
@synthesize pronouns = _pronouns;
@synthesize currentUser = _currentUser;
@synthesize origin = _origin;

@end

static char CharonTermOfAddressStateKey;

@implementation NSTermOfAddress

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_termWithLanguage:(NSString *)language pronouns:(NSArray *)pronouns currentUser:(BOOL)currentUser
{
    return [self charon_termWithLanguage:language pronouns:pronouns currentUser:currentUser origin:nil];
}

+ (instancetype)charon_termWithLanguage:(NSString *)language pronouns:(NSArray *)pronouns currentUser:(BOOL)currentUser origin:(NSString *)origin
{
    NSTermOfAddress *term = [NSTermOfAddress alloc];
    /* -init and +new are NS_UNAVAILABLE in the SDK's own header, and the compiler refuses them here
       as it refuses them there, so the superclass's -init is run the way a factory's would. */
    struct objc_super super = { .receiver = term, .super_class = [NSObject class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, @selector(init));
    CharonTermOfAddressState *state = [[CharonTermOfAddressState alloc] init];
    state.languageIdentifier = [language copy];
    state.pronouns = [pronouns copy];
    state.currentUser = currentUser;
    state.origin = origin;
    objc_setAssociatedObject(term, &CharonTermOfAddressStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return term;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSTermOfAddress class]])
        return NO;
    CharonTermOfAddressState *mine = objc_getAssociatedObject(self, &CharonTermOfAddressStateKey);
    CharonTermOfAddressState *theirs = objc_getAssociatedObject(object, &CharonTermOfAddressStateKey);
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
    CharonTermOfAddressState *state = objc_getAssociatedObject(self, &CharonTermOfAddressStateKey);
    return state.languageIdentifier.hash ^ state.pronouns.count ^ (state.currentUser ? 2u : 0u) ^ state.origin.hash;
}

+ (instancetype)neutral
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self charon_termWithLanguage:nil pronouns:nil currentUser:NO origin:@"neutral"];
    });
    return term;
}

+ (instancetype)feminine
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self charon_termWithLanguage:nil pronouns:nil currentUser:NO origin:@"feminine"];
    });
    return term;
}

+ (instancetype)masculine
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self charon_termWithLanguage:nil pronouns:nil currentUser:NO origin:@"masculine"];
    });
    return term;
}

+ (instancetype)currentUser
{
    static NSTermOfAddress *term;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        term = [self charon_termWithLanguage:nil pronouns:nil currentUser:YES origin:@"currentUser"];
    });
    return term;
}

+ (instancetype)localizedForLanguageIdentifier:(NSString *)language withPronouns:(NSArray *)pronouns
{
    /* The origin is the *factory*, not what it was asked for: if the language went into it, every
       pair of localized terms would differ by origin and the language comparison below would never
       be the thing that answered -- which is exactly what the differential's fixture found when the
       origin read "localized en" and "localized de". */
    return [self charon_termWithLanguage:language pronouns:pronouns currentUser:NO origin:@"localized"];
}

/* The fixture the differential builds its language comparisons with: a term for a language and no
   pronouns. It is the same shape as +localizedForLanguageIdentifier:withPronouns: with a nil list,
   under the name the host's own Swift interface gives it, so a test can name one argument. */
+ (instancetype)termWithLanguageIdentifier:(NSString *)language
{
    return [self localizedForLanguageIdentifier:language withPronouns:nil];
}

- (NSString *)languageIdentifier
{
    CharonTermOfAddressState *state = objc_getAssociatedObject(self, &CharonTermOfAddressStateKey);
    return state ? state.languageIdentifier : nil;
}

- (NSArray *)pronouns
{
    CharonTermOfAddressState *state = objc_getAssociatedObject(self, &CharonTermOfAddressStateKey);
    return state ? state.pronouns : nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self; /* immutable once the factory has built it */
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSTermOfAddress cannot be encoded by non-keyed archivers"];
        return;
    }
    CharonTermOfAddressState *state = objc_getAssociatedObject(self, &CharonTermOfAddressStateKey);
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
    CharonTermOfAddressState *state = [[CharonTermOfAddressState alloc] init];
    state.languageIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.languageIdentifier"];
    state.pronouns = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                          forKey:@"NS.pronouns"];
    state.currentUser = [coder decodeBoolForKey:@"NS.currentUser"];
    objc_setAssociatedObject(self, &CharonTermOfAddressStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

@end
