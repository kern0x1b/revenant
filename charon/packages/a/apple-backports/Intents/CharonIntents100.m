//
//  CharonIntents100.m
//  Intents
//
//  The ten Intents classes whose behaviour is more than storage, and the two stores an
//  application on this release can really keep: the interactions it donates and the vocabulary
//  it offers. Everything here is hand written; the rest of the framework's 10.0.1 classes are
//  generated into IN10_0.m from the SDK's own declarations.
//
//  What this release cannot do, and what it answers instead, is written down in
//  facts/Intents/Intents.md, which every registry entry of this framework points at. In short:
//  there is no assistant daemon here, so nothing is ever asked of the user, no interaction is
//  ever read by the system, and every one of those seams says so — by storing what the
//  application gave it in a real per-application store, or by answering with the value Apple's
//  own documentation gives a system that cannot reach the service.
//

#import <Intents/Intents.h>
#import <Intents/INIntentHandlerProviding.h>
#import <Intents/INParameter.h>
#import <EventKit/EventKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// The SDK marks each class's initialiser as the designated one, in a header this package does
// not own, so clang reads the -initWithCoder: and -copyWithZone: below as convenience
// initialisers of classes that have a designated one. The warning is about a convention and not
// about behaviour: each of them is the header's own chain.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#import "../../../c/charon-coding/files/CharonCoding.h"
#import "CharonIntentsResolution.h"
#import "CharonIntentsStore.h"

#pragma mark - INImage

@implementation INImage {
    NSString *_name;
    NSData *_data;
    double _width;
    double _height;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<INImage %@%@>", _name ?: @"", _data ? @" data" : @""];
}

// The bytes the image carries, for IntentsUI's category on INImage (INImage+IntentsUI100.m and
// INImage+IntentsUI110.m), which needs them to encode, decode and hand them back. Not an SDK name.
- (NSData *)charon_imageData
{
    return _data;
}

+ (instancetype)imageNamed:(NSString *)name
{
    if (!name.length) {
        return nil;
    }
    // The app's own asset catalogue is the release's, and an Intents image is one of the app's
    // images: it is resolved through UIKit, which is where the catalogue lives on every release
    // this port covers, and carried afterwards as the data itself so nothing holds a UIImage.
    UIImage *image = [UIImage imageNamed:name];
    NSData *data = image ? UIImagePNGRepresentation(image) : nil;
    if (!data) {
        return nil;
    }
    return [self charon_imageWithName:name data:data width:image.size.width height:image.size.height];
}

+ (instancetype)systemImageNamed:(NSString *)name
{
    // The answer is UIKit's own, the same name for name: +[UIImage systemImageNamed:] draws from the one symbol
    // table of the UIKit band (UIKit/UIImage+Symbols.m), and answers nil for every name outside it. Nothing here keeps
    // a second list, so the two cannot disagree. The image is carried as its PNG, as imageNamed: carries one.
    if (!name.length) {
        return nil;
    }
    UIImage *image = [UIImage systemImageNamed:name];
    NSData *data = image ? UIImagePNGRepresentation(image) : nil;
    if (!data) {
        return nil;
    }
    return [self charon_imageWithName:name data:data width:image.size.width height:image.size.height];
}

+ (instancetype)imageWithImageData:(NSData *)imageData
{
    if (!imageData) {
        return nil;
    }
    return [self charon_imageWithName:nil data:imageData width:0 height:0];
}

+ (instancetype)imageWithURL:(NSURL *)URL
{
    return [self imageWithURL:URL width:0 height:0];
}

+ (instancetype)imageWithURL:(NSURL *)URL width:(double)width height:(double)height
{
    NSData *data = URL ? [NSData dataWithContentsOfURL:URL] : nil;
    if (!data) {
        return nil;
    }
    return [self charon_imageWithName:URL.lastPathComponent data:data width:width height:height];
}

+ (instancetype)charon_imageWithName:(NSString *)name data:(NSData *)data width:(double)width height:(double)height
{
    INImage *image = [[self alloc] init];
    image->_name = [name copy];
    image->_data = [data copy];
    image->_width = width;
    image->_height = height;
    return image;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INImage *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INIntent

@implementation INIntent {
    NSString *_identifier;
    NSString *_intentDescription;
    NSString *_suggestedInvocationPhrase;
    INShortcutAvailabilityOptions _shortcutAvailability;
    NSMutableDictionary *_imagesByParameter;
    INIntentDonationMetadata *_donationMetadata;
}

// The phrase the system offers to speak for this intent, which the system reads and the
// application sets: kept as given, and nil until it is set, which is what the header's
// readwrite, copy, nullable says.
- (NSString *)suggestedInvocationPhrase
{
    return _suggestedInvocationPhrase;
}

- (void)setSuggestedInvocationPhrase:(NSString *)suggestedInvocationPhrase
{
    _suggestedInvocationPhrase = [suggestedInvocationPhrase copy];
}

- (INShortcutAvailabilityOptions)shortcutAvailability
{
    return _shortcutAvailability;
}

- (void)setShortcutAvailability:(INShortcutAvailabilityOptions)shortcutAvailability
{
    _shortcutAvailability = shortcutAvailability;
}

// donationMetadata is the metadata the system reads when the intent is donated. The class it names,
// INIntentDonationMetadata, arrived with iOS 15 and IS carried by this delivery - IN16_0.m defines
// it - so the property is answered here rather than left dynamic. It was @dynamic with the reason
// "a class of a later group of this same delivery", which was false: the class is in the 16.0
// group of this same delivery, and a getter that answers nil and a setter that keeps what it is
// given are what the header's own copy/nullable wording says this is.
- (INIntentDonationMetadata *)donationMetadata
{
    return _donationMetadata;
}

- (void)setDonationMetadata:(INIntentDonationMetadata *)donationMetadata
{
    _donationMetadata = [donationMetadata copy];
}

- (instancetype)init
{
    if ((self = [super init])) {
        // The system assigns an intent's identifier when the interaction carrying it is donated;
        // this release donates nothing to a system, and the interaction store below is keyed by
        // this value, so it is made where the intent is made. It is the same UUID string the
        // system would have written, and a port that reads it back sees a stable key.
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)intentDescription
{
    if (_intentDescription) {
        return _intentDescription;
    }
    // The SDK does not document how the framework derives this from the intent's class, and
    // this release has no framework to ask. The class name is the whole of what an intent
    // knows about itself, so the words of the class are the description, with the framework's
    // own IN prefix and Intent suffix off: INSendMessageIntent reads "Send message".
    NSString *name = [NSString stringWithCString:class_getName([self class]) encoding:NSUTF8StringEncoding];
    if ([name hasPrefix:@"IN"]) {
        name = [name substringFromIndex:2];
    }
    if ([name hasSuffix:@"Intent"]) {
        name = [name substringToIndex:name.length - @"Intent".length];
    }
    NSMutableString *words = [NSMutableString stringWithCapacity:name.length];
    for (NSUInteger index = 0; index < name.length; index++) {
        unichar letter = [name characterAtIndex:index];
        unichar before = index ? [name characterAtIndex:index - 1] : 0;
        // A class name is ASCII, and a capital that follows a lower-case letter starts a word.
        BOOL startsWord = index > 0 && letter >= 'A' && letter <= 'Z' &&
            before >= 'a' && before <= 'z';
        if (startsWord && words.length > 0) {
            [words appendString:@" "];
        }
        [words appendFormat:@"%C", letter];
    }
    _intentDescription = [words copy];
    return _intentDescription;
}

- (void)setImage:(INImage *)image forParameterNamed:(NSString *)parameterName
{
    if (!parameterName) {
        return;
    }
    if (!image) {
        [_imagesByParameter removeObjectForKey:parameterName];
        return;
    }
    if (!_imagesByParameter) {
        _imagesByParameter = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    _imagesByParameter[parameterName] = image;
}

- (INImage *)imageForParameterNamed:(NSString *)parameterName
{
    return parameterName ? _imagesByParameter[parameterName] : nil;
}

- (INImage *)keyImage
{
    // The image of the first parameter that has one. The parameters are read in name order so
    // the answer is the same on every call, which a dictionary's own order would not promise.
    for (NSString *name in [_imagesByParameter.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        INImage *image = _imagesByParameter[name];
        if (image) {
            return image;
        }
    }
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INIntent *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INIntentResolutionResult

@implementation INIntentResolutionResult {
    CharonIntentsResolutionStatus _status;
    id _resolvedValue;
    NSArray *_valuesToDisambiguate;
    id _valueToConfirm;
    NSInteger _unsupportedReason;
    NSInteger _confirmationReason;
}

+ (instancetype)needsValue
{
    return [self charon_resolutionWithStatus:CharonIntentsResolutionNeedsValue
                             resolvedValue:nil
                       valuesToDisambiguate:nil
                              valueToConfirm:nil];
}

+ (instancetype)notRequired
{
    return [self charon_answerWithStatus:CharonIntentsResolutionNotRequired
                           resolvedValue:nil
                    valuesToDisambiguate:nil
                          valueToConfirm:nil
                       unsupportedReason:0];
}

+ (instancetype)unsupported
{
    return [self charon_resolutionWithStatus:CharonIntentsResolutionUnsupported
                             resolvedValue:nil
                       valuesToDisambiguate:nil
                              valueToConfirm:nil];
}

// The two factories the header declares with a reason, which the host runtime answers as measured in
// facts/Intents/Intents.md: the reason is kept as given, and the item to confirm is the item given.
+ (instancetype)unsupportedWithReason:(NSInteger)reason
{
    return [self charon_resolutionWithStatus:CharonIntentsResolutionUnsupported
                             resolvedValue:nil
                       valuesToDisambiguate:nil
                              valueToConfirm:nil
                          unsupportedReason:reason];
}

+ (instancetype)confirmationRequiredWithItemToConfirm:(id)itemToConfirm forReason:(NSInteger)reason
{
    INIntentResolutionResult *result = [self charon_resolutionWithStatus:CharonIntentsResolutionConfirmationRequired
                                                           resolvedValue:nil
                                                     valuesToDisambiguate:nil
                                                            valueToConfirm:itemToConfirm];
    result->_confirmationReason = reason;
    return result;
}

+ (instancetype)charon_resolutionWithStatus:(CharonIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm
{
    return [self charon_resolutionWithStatus:status
                               resolvedValue:resolvedValue
                         valuesToDisambiguate:valuesToDisambiguate
                                valueToConfirm:valueToConfirm
                            unsupportedReason:0];
}

+ (instancetype)charon_resolutionWithStatus:(CharonIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm
                         unsupportedReason:(NSInteger)unsupportedReason
{
    // A disambiguation of nothing is no answer: the host's factories return nil for an empty array (measured by
    // tests/backports/host/resolution-factories), and every generated disambiguation factory builds through here.
    if (status == CharonIntentsResolutionDisambiguation && valuesToDisambiguate.count == 0) {
        return nil;
    }
    // A success, or a notRequired, of no object is no answer: the generated successWith...: factories of an object pass
    // a nil object with the notRequired status (or success), and the host's factories return nil for it (measured by
    // tests/backports/host/resolution-factories). The enumeration factories pass their zero as a number, not nil, so
    // they are not caught here, and +notRequired builds through charon_answerWithStatus: and is not caught either.
    if (resolvedValue == nil && (status == CharonIntentsResolutionSuccess || status == CharonIntentsResolutionNotRequired)) {
        return nil;
    }
    return [self charon_answerWithStatus:status
                           resolvedValue:resolvedValue
                    valuesToDisambiguate:valuesToDisambiguate
                          valueToConfirm:valueToConfirm
                       unsupportedReason:unsupportedReason];
}

// The answer as it is built, with no rule of the answers that are no answer above.
+ (instancetype)charon_answerWithStatus:(CharonIntentsResolutionStatus)status
                          resolvedValue:(id)resolvedValue
                   valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                         valueToConfirm:(id)valueToConfirm
                      unsupportedReason:(NSInteger)unsupportedReason
{
    INIntentResolutionResult *result = [self charon_adopted:NULL];
    result->_status = status;
    result->_resolvedValue = [resolvedValue copy];
    result->_valuesToDisambiguate = [valuesToDisambiguate copy];
    result->_valueToConfirm = [valueToConfirm copy];
    result->_unsupportedReason = unsupportedReason;
    return result;
}

// The allocation both builders above share, reached through objc_msgSendSuper for the reason the
// class's own header marks -init unavailable (see CharonCoding.h). The receiver is an instance: the
// helper's super -init answers its receiver, so passing the class would write the result's state into
// the class object itself.
+ (instancetype)charon_adopted:(INIntentResolutionResult *)inner
{
    INIntentResolutionResult *result = [self alloc];
    result = charon_intents_super_init(result, [INIntentResolutionResult class]);
    if (inner) {
        result->_status = inner->_status;
        result->_resolvedValue = [inner->_resolvedValue copy];
        result->_valuesToDisambiguate = [inner->_valuesToDisambiguate copy];
        result->_valueToConfirm = [inner->_valueToConfirm copy];
        result->_unsupportedReason = inner->_unsupportedReason;
        result->_confirmationReason = inner->_confirmationReason;
    } else {
        result->_status = CharonIntentsResolutionNeedsValue;
    }
    return result;
}

- (void)charon_adoptResolutionOf:(id)inner
{
    if (![inner isKindOfClass:[INIntentResolutionResult class]]) {
        return;
    }
    INIntentResolutionResult *wrapped = inner;
    _status = wrapped->_status;
    _resolvedValue = [wrapped->_resolvedValue copy];
    _valuesToDisambiguate = [wrapped->_valuesToDisambiguate copy];
    _valueToConfirm = [wrapped->_valueToConfirm copy];
    _unsupportedReason = wrapped->_unsupportedReason;
    _confirmationReason = wrapped->_confirmationReason;
}

- (NSInteger)charon_unsupportedReason
{
    return _unsupportedReason;
}

// The readers the host's own class answers by these names (tests/backports/host/intents-resolution-reason). The codes
// are the host's: success 0, unsupported 1, disambiguation 2, confirmation required 3, needs value 4, not required 5.
// A disambiguation of one item is answered as a confirmation of that item, and the host does the same.
- (NSInteger)resolutionResultCode
{
    switch (_status) {
        case CharonIntentsResolutionSuccess:
            return 0;
        case CharonIntentsResolutionUnsupported:
            return 1;
        case CharonIntentsResolutionDisambiguation:
            return _valuesToDisambiguate.count == 1 ? 3 : 2;
        case CharonIntentsResolutionConfirmationRequired:
            return 3;
        case CharonIntentsResolutionNeedsValue:
            return 4;
        case CharonIntentsResolutionNotRequired:
            return 5;
    }
    return 0;
}

- (id)itemToConfirm
{
    if (_status == CharonIntentsResolutionConfirmationRequired) {
        return _valueToConfirm;
    }
    if (_status == CharonIntentsResolutionDisambiguation && _valuesToDisambiguate.count == 1) {
        return _valuesToDisambiguate[0];
    }
    return nil;
}

- (NSInteger)unsupportedReason
{
    return _unsupportedReason;
}

- (NSInteger)confirmationReason
{
    return _confirmationReason;
}

- (NSArray *)disambiguationItems
{
    if (_status != CharonIntentsResolutionDisambiguation || _valuesToDisambiguate.count == 1) {
        return nil;
    }
    return _valuesToDisambiguate;
}

- (id)resolvedValue
{
    return _resolvedValue;
}

- (NSArray *)valuesToDisambiguate
{
    return _valuesToDisambiguate;
}

- (id)valueToConfirm
{
    return _valueToConfirm;
}

- (CharonIntentsResolutionStatus)resolutionStatus
{
    return _status;
}

- (NSString *)description
{
    static const char *names[] = {"needsValue", "notRequired", "unsupported", "success",
                                  "disambiguation", "confirmationRequired"};
    return [NSString stringWithFormat:@"<%@ %s%@%@>",
            [NSString stringWithCString:class_getName([self class]) encoding:NSUTF8StringEncoding],
            names[_status], _resolvedValue ? @" value" : @"",
            _valuesToDisambiguate ? @" choices" : (_valueToConfirm ? @" to confirm" : @"")];
}

@end

#pragma mark - INSpeakableString

@implementation INSpeakableString {
    NSString *_spokenPhrase;
    NSString *_pronunciationHint;
    NSString *_vocabularyIdentifier;
    NSString *_identifier;
    NSArray *_alternativeSpeakableMatches;
}

@synthesize spokenPhrase = _spokenPhrase;
@synthesize pronunciationHint = _pronunciationHint;
@synthesize vocabularyIdentifier = _vocabularyIdentifier;
@synthesize alternativeSpeakableMatches = _alternativeSpeakableMatches;

// INSpeakable's identifier is the vocabulary identifier, and the header says so in as many
// words ("Please use vocabularyIdentifier"), so the deprecated accessor answers it from the same
// value rather than keeping a second one.
- (NSString *)identifier
{
    return _vocabularyIdentifier;
}

- (instancetype)initWithVocabularyIdentifier:(NSString *)vocabularyIdentifier
                                spokenPhrase:(NSString *)spokenPhrase
                           pronunciationHint:(NSString *)pronunciationHint
{
    if ((self = [super init])) {
        _vocabularyIdentifier = [vocabularyIdentifier copy];
        _spokenPhrase = [spokenPhrase copy];
        _pronunciationHint = [pronunciationHint copy];
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                      spokenPhrase:(NSString *)spokenPhrase
                 pronunciationHint:(NSString *)pronunciationHint
{
    // Deprecated in iOS 11 in favour of the initialiser that takes a vocabulary identifier,
    // and the identifier is where the vocabulary identifier has been ever since, which is what
    // a release that answers this call at all has to do with it.
    if ((self = [self initWithVocabularyIdentifier:identifier
                                      spokenPhrase:spokenPhrase
                                 pronunciationHint:pronunciationHint]))
        _identifier = [identifier copy];
    return self;
}

- (instancetype)initWithSpokenPhrase:(NSString *)spokenPhrase
{
    // The header's own second initialiser, and the only one that gives a phrase with no
    // vocabulary: the state is the phrase alone, and no vocabulary identifier is invented for
    // it, which the designated initialiser above would have had to invent one for.
    if ((self = [super init])) {
        _spokenPhrase = [spokenPhrase copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INSpeakableString *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INExtension

// INExtension's own surface is empty: everything it is asked for comes from
// INIntentHandlerProviding, whose one requirement is the handler for an intent. The handlers an
// extension vends are the extension's own classes, so this looks them up in the loaded classes
// by the protocol each intent's handling declares, and answers nil where there is none - which is
// what a release with no assistant daemon to launch the extension has to say.

@implementation INExtension

+ (NSString *)charon_handlingProtocolNameForIntent:(INIntent *)intent
{
    // The handling protocol of an intent is named after it: INBookRestaurantReservationIntent is
    // handled by something conforming to INBookRestaurantReservationIntentHandling. The class is
    // asked for its own name rather than the string being guessed, so a class named differently
    // than its protocol is simply not found.
    NSString *name = [NSString stringWithCString:class_getName([intent class]) encoding:NSUTF8StringEncoding];
    return [name stringByAppendingString:@"Handling"];
}

- (id)handlerForIntent:(INIntent *)intent
{
    if (!intent) {
        return nil;
    }
    NSString *wanted = [[self class] charon_handlingProtocolNameForIntent:intent];
    unsigned count = objc_getClassList(NULL, 0);
    if (!count) {
        return nil;
    }
    Class *loaded = (Class *)malloc(sizeof(Class) * count);
    count = objc_getClassList(loaded, count);
    Class candidate = nil;
    for (unsigned index = 0; index < count && !candidate; index++) {
        unsigned held = 0;
        Protocol *__unsafe_unretained *list = class_copyProtocolList(loaded[index], &held);
        for (unsigned other = 0; other < held && !candidate; other++) {
            const char *name = protocol_getName((Protocol *)list[other]);
            if (name && [wanted isEqualToString:[NSString stringWithCString:name
                                                                  encoding:NSUTF8StringEncoding]]) {
                candidate = loaded[index];
            }
        }
        free((void *)list);
    }
    free(loaded);
    if (!candidate) {
        return nil;
    }
    // A handler is a new object the caller owns, and a method whose name does not begin with
    // alloc, new, copy or init has to hand it over autoreleased, which is what this returns.
    id instance = [[self class] charon_newHandlerOfClass:candidate];
    return [instance respondsToSelector:@selector(handleIntent:)] ? instance : nil;
}

+ (id)charon_newHandlerOfClass:(Class)candidate
{
    return [[candidate alloc] init];
}

@end

#pragma mark - INPaymentMethod

@implementation INPaymentMethod {
    INPaymentMethodType _type;
    NSString *_name;
    NSString *_identificationHint;
    INImage *_icon;
}

@synthesize type = _type;
@synthesize name = _name;
@synthesize identificationHint = _identificationHint;
@synthesize icon = _icon;

- (instancetype)initWithType:(INPaymentMethodType)type
                        name:(NSString *)name
          identificationHint:(NSString *)identificationHint
                        icon:(INImage *)icon
{
    if ((self = [super init])) {
        _type = type;
        _name = [name copy];
        _identificationHint = [identificationHint copy];
        _icon = [icon copy];
    }
    return self;
}

+ (instancetype)applePayPaymentMethod
{
    // The one payment method the system itself provides, so it is the same object every time:
    // the type is the one the header gives, and the name, the hint and the icon are the
    // system's own, which this release has no image of and no name for.
    static INPaymentMethod *method;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        method = [[INPaymentMethod alloc] initWithType:INPaymentMethodTypeApplePay
                                                  name:nil
                                    identificationHint:nil
                                                  icon:nil];
    });
    return method;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INPaymentMethod *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INRideCompletionStatus

typedef NS_ENUM(NSInteger, CharonIntentsRideOutcome) {
    CharonIntentsRideCompleted = 0,
    CharonIntentsRideCanceled,
    CharonIntentsRideMissedPickup,
};

@implementation INRideCompletionStatus {
    CharonIntentsRideOutcome _outcome;
    BOOL _outstanding;
    INCurrencyAmount *_paymentAmount;
    INRideFeedbackTypeOptions _feedbackType;
    NSUserActivity *_completionUserActivity;
    NSSet *_defaultTippingOptions;
}

@synthesize completionUserActivity = _completionUserActivity;
@synthesize defaultTippingOptions = _defaultTippingOptions;

+ (instancetype)charon_completionWithOutcome:(CharonIntentsRideOutcome)outcome
                                  outstanding:(BOOL)outstanding
                                paymentAmount:(INCurrencyAmount *)paymentAmount
                                 feedbackType:(INRideFeedbackTypeOptions)feedbackType
{
    INRideCompletionStatus *status = [[self alloc] init];
    status->_outcome = outcome;
    status->_outstanding = outstanding;
    status->_paymentAmount = [paymentAmount copy];
    status->_feedbackType = feedbackType;
    return status;
}

+ (instancetype)completed
{
    return [self charon_completionWithOutcome:CharonIntentsRideCompleted
                                    outstanding:NO
                                  paymentAmount:nil
                                   feedbackType:0];
}

+ (instancetype)completedWithSettledPaymentAmount:(INCurrencyAmount *)settledPaymentAmount
{
    return [self charon_completionWithOutcome:CharonIntentsRideCompleted
                                    outstanding:NO
                                  paymentAmount:settledPaymentAmount
                                   feedbackType:0];
}

+ (instancetype)completedWithOutstandingPaymentAmount:(INCurrencyAmount *)outstandingPaymentAmount
{
    return [self charon_completionWithOutcome:CharonIntentsRideCompleted
                                    outstanding:YES
                                  paymentAmount:outstandingPaymentAmount
                                   feedbackType:0];
}

+ (instancetype)completedWithOutstandingFeedbackType:(INRideFeedbackTypeOptions)feedbackType
{
    return [self charon_completionWithOutcome:CharonIntentsRideCompleted
                                    outstanding:YES
                                  paymentAmount:nil
                                   feedbackType:feedbackType];
}

+ (instancetype)canceledByService
{
    return [self charon_completionWithOutcome:CharonIntentsRideCanceled
                                    outstanding:NO
                                  paymentAmount:nil
                                   feedbackType:0];
}

+ (instancetype)canceledByUser
{
    // The header tells a canceled status apart from a service cancellation and from a missed
    // pickup, and exposes nothing else about it, so the two answers differ only in what a
    // reader of the class can already see: both are canceled, neither missed the pickup.
    return [self canceledByService];
}

+ (instancetype)canceledMissedPickup
{
    return [self charon_completionWithOutcome:CharonIntentsRideMissedPickup
                                    outstanding:NO
                                  paymentAmount:nil
                                   feedbackType:0];
}

- (BOOL)isCompleted
{
    return _outcome == CharonIntentsRideCompleted;
}

- (BOOL)isCanceled
{
    return _outcome != CharonIntentsRideCompleted;
}

- (BOOL)isMissedPickup
{
    return _outcome == CharonIntentsRideMissedPickup;
}

- (BOOL)isOutstanding
{
    return _outstanding;
}

- (INCurrencyAmount *)paymentAmount
{
    return _paymentAmount;
}

- (INRideFeedbackTypeOptions)feedbackType
{
    return _feedbackType;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INRideCompletionStatus *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INPreferences

@implementation INPreferences

+ (INSiriAuthorizationStatus)siriAuthorizationStatus
{
    // The header's own words for this value: not authorized to use Siri, and unable to change
    // that answer, because Siri services are restricted on this release. There is no assistant
    // daemon here to ask, so this is the status, and it is the last of the four that is not a
    // statement about the user.
    return INSiriAuthorizationStatusRestricted;
}

+ (void)requestSiriAuthorization:(void (^)(INSiriAuthorizationStatus status))handler
{
    // There is no authorization to ask for: the same restriction is already in force, so the
    // handler is answered with it rather than left waiting for a prompt this release cannot
    // show. A handler of nil is not called, as everywhere else in this package.
    if (handler) {
        handler([self siriAuthorizationStatus]);
    }
}

+ (NSString *)siriLanguageCode
{
    // The code Siri is configured to speak with. This release has no Siri and therefore no such
    // setting, and the language the release itself is set to is the one a voice would use, so
    // that is what it answers, read from the same list every other part of the system reads.
    return [[[NSLocale preferredLanguages] firstObject] copy];
}

@end

#pragma mark - INVocabulary

@implementation INVocabulary

+ (instancetype)sharedVocabulary
{
    static INVocabulary *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[INVocabulary alloc] init];
    });
    return shared;
}

- (void)setVocabularyStrings:(NSOrderedSet *)vocabulary ofType:(INVocabularyStringType)type
{
    charon_intents_store_vocabulary(type, [vocabulary array]);
}

- (void)setVocabulary:(NSOrderedSet *)vocabulary ofType:(INVocabularyStringType)type
{
    // The same store, read out of the speakable values it is given rather than out of plain
    // strings: what a voice says for a term is the term's spoken phrase.
    NSMutableArray *phrases = [NSMutableArray arrayWithCapacity:vocabulary.count];
    for (id<INSpeakable> value in vocabulary) {
        NSString *phrase = value.spokenPhrase;
        if (phrase) {
            [phrases addObject:phrase];
        }
    }
    charon_intents_store_vocabulary(type, phrases);
}

- (void)removeAllVocabularyStrings
{
    charon_intents_remove_vocabulary();
}

- (NSOrderedSet *)charon_vocabularyStringsOfType:(INVocabularyStringType)type
{
    return charon_intents_vocabulary(type);
}

@end

#pragma mark - INInteraction

@implementation INInteraction {
    INIntent *_intent;
    INIntentResponse *_intentResponse;
    INIntentHandlingStatus _intentHandlingStatus;
    INInteractionDirection _direction;
    NSDateInterval *_dateInterval;
    NSString *_identifier;
    NSString *_groupIdentifier;
}

// The header declares these seven, and the ivars above are where the class keeps them; the
// synthesised accessors are the ones the compiler would have made from the declarations, written
// out so that a reader of this file - and the registry this file is measured into - can see that
// each member has one. The three copy properties copy on the way in, which is what the header's
// ownership means.
@synthesize intent = _intent;
@synthesize intentResponse = _intentResponse;
@synthesize intentHandlingStatus = _intentHandlingStatus;
@synthesize direction = _direction;
@synthesize dateInterval = _dateInterval;
@synthesize identifier = _identifier;
@synthesize groupIdentifier = _groupIdentifier;

- (instancetype)initWithIntent:(INIntent *)intent response:(INIntentResponse *)response
{
    if ((self = [super init])) {
        _intent = [intent copy];
        _intentResponse = [response copy];
        _identifier = [[NSUUID UUID] UUIDString];
        _direction = INInteractionDirectionOutgoing;
    }
    return self;
}

- (void)donateInteractionWithCompletion:(void (^)(NSError *))completion
{
    // The system reads a donation and learns the interaction from it. This release runs no
    // assistant daemon, so there is nothing to hand it to, and what the application meant is
    // kept instead: the interaction is archived into this application's own store, stamped
    // with the moment it was donated, and read back through the two accessors below. The
    // donation is reported as the completion handler is given a nil error, because the store
    // took it — never a fabricated error and never silence.
    if (!_dateInterval) {
        _dateInterval = [[NSDateInterval alloc] initWithStartDate:[NSDate date] endDate:[NSDate date]];
    }
    NSError *error = charon_intents_store_interaction(self);
    if (completion) {
        completion(error);
    }
}

+ (void)deleteAllInteractionsWithCompletion:(void (^)(NSError *))completion
{
    if (completion) {
        completion(charon_intents_delete_interactions(nil, nil));
    }
}

+ (void)deleteInteractionsWithIdentifiers:(NSArray *)identifiers completion:(void (^)(NSError *))completion
{
    if (completion) {
        completion(charon_intents_delete_interactions(identifiers, nil));
    }
}

+ (void)deleteInteractionsWithGroupIdentifier:(NSString *)groupIdentifier completion:(void (^)(NSError *))completion
{
    if (completion) {
        completion(charon_intents_delete_interactions(nil, groupIdentifier));
    }
}

- (id)parameterValueForParameter:(INParameter *)parameter
{
    // The value the interaction's intent carries for that parameter: a parameter names a class and
    // a key path into it, and the value is read out of the intent by that path. It is read one
    // component at a time, each asked for by name first, because a key-value lookup of a path the
    // object has no accessor for raises, and an API must not crash its caller: a path the intent
    // does not have answers nil.
    id value = _intent;
    for (NSString *part in [parameter.parameterKeyPath componentsSeparatedByString:@"."]) {
        if (![value respondsToSelector:NSSelectorFromString(part)]) {
            return nil;
        }
        value = [value valueForKey:part];
        if (!value) {
            return nil;
        }
    }
    return value == [NSNull null] ? nil : value;
}

+ (NSArray *)charon_interactions
{
    return charon_intents_stored_interactions(nil);
}

+ (NSArray *)charon_interactionsWithGroupIdentifier:(NSString *)groupIdentifier
{
    return charon_intents_stored_interactions(groupIdentifier);
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INInteraction *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end

// INRideDriver's two deprecated initialisers. The 16.4 header no longer declares them and the runtime still carries
// both, so they are written here and not in IN10_0_1.m, which is generated from the header. Measured on the Catalyst
// host (tests/backports/host/intents-ride-driver; facts/Intents/Intents.md, "INRideDriver's deprecated initialisers"):
// the handle is kept as the value of a person handle of type Unknown, even when it is nil; a nil displayName is the
// handle, or "" when there is none; and with components the displayName is the name the components make, or the
// handle when they make none. Both chain to the designated initialiser.
@implementation INRideDriver (CharonDeprecatedInitialisers)

// The name a driver is shown by when the name is given as components: the given name and the family name, each only
// when it is not nil and not empty, joined by one space in that order. The middle name, prefix, suffix and nickname
// are not in it. Nil when neither part is there, so the caller falls back to the handle.
static NSString *CharonRideDriverNameFromComponents(NSPersonNameComponents *components)
{
    NSMutableArray *parts = [NSMutableArray array];
    if (components.givenName.length) {
        [parts addObject:components.givenName];
    }
    if (components.familyName.length) {
        [parts addObject:components.familyName];
    }
    return parts.count ? [parts componentsJoinedByString:@" "] : nil;
}

- (instancetype)initWithHandle:(NSString *)handle displayName:(NSString *)displayName image:(INImage *)image rating:(NSString *)rating phoneNumber:(NSString *)phoneNumber
{
    INPersonHandle *personHandle = [[INPersonHandle alloc] initWithValue:handle type:INPersonHandleTypeUnknown];
    NSString *name = displayName ?: (handle ?: @"");
    return [self initWithPersonHandle:personHandle nameComponents:nil displayName:name image:image rating:rating phoneNumber:phoneNumber];
}

- (instancetype)initWithHandle:(NSString *)handle nameComponents:(NSPersonNameComponents *)nameComponents image:(INImage *)image rating:(NSString *)rating phoneNumber:(NSString *)phoneNumber
{
    INPersonHandle *personHandle = [[INPersonHandle alloc] initWithValue:handle type:INPersonHandleTypeUnknown];
    NSString *name = CharonRideDriverNameFromComponents(nameComponents) ?: (handle ?: @"");
    return [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:name image:image rating:rating phoneNumber:phoneNumber];
}

@end

// The EventKit recurrence rule of a range. Measured on the Catalyst and macOS hosts (tests/backports/host/intents-ek;
// facts/Intents/Intents.md, "EventKit's recurrence rule"): the frequency is mapped and the interval kept; the first day
// of the rule's days becomes the weekday and the week number (the weekday ordinal) of the start components, for any
// frequency, and the other days and the end are not kept; a nil rule is a daily rule of interval 0. The getter builds
// the rule from the same things, and raises where the host raises: a range with no weekday asks EventKit for day 0,
// which it refuses.
static INRecurrenceFrequency CharonRecurrenceFrequencyFromEventKit(EKRecurrenceFrequency frequency)
{
    switch (frequency) {
        case EKRecurrenceFrequencyWeekly:
            return INRecurrenceFrequencyWeekly;
        case EKRecurrenceFrequencyMonthly:
            return INRecurrenceFrequencyMonthly;
        case EKRecurrenceFrequencyYearly:
            return INRecurrenceFrequencyYearly;
        case EKRecurrenceFrequencyDaily:
        default:
            return INRecurrenceFrequencyDaily;
    }
}

// The EventKit frequency of an Intents one. Minute and hourly have no EventKit rule, and the host answers nil for them
// (measured), so there is no frequency to give and the caller answers nil.
static BOOL CharonEventKitFrequencyFromRecurrence(INRecurrenceFrequency frequency, EKRecurrenceFrequency *eventKit)
{
    switch (frequency) {
        case INRecurrenceFrequencyDaily:
            *eventKit = EKRecurrenceFrequencyDaily;
            return YES;
        case INRecurrenceFrequencyWeekly:
            *eventKit = EKRecurrenceFrequencyWeekly;
            return YES;
        case INRecurrenceFrequencyMonthly:
            *eventKit = EKRecurrenceFrequencyMonthly;
            return YES;
        case INRecurrenceFrequencyYearly:
            *eventKit = EKRecurrenceFrequencyYearly;
            return YES;
        default:
            return NO;
    }
}

@implementation INDateComponentsRange (CharonEventKit)

- (instancetype)initWithEKRecurrenceRule:(EKRecurrenceRule *)recurrenceRule
{
    INRecurrenceFrequency frequency = INRecurrenceFrequencyDaily;
    NSUInteger interval = 0;
    NSDateComponents *start = nil;
    if (recurrenceRule) {
        frequency = CharonRecurrenceFrequencyFromEventKit(recurrenceRule.frequency);
        interval = recurrenceRule.interval;
        NSArray<EKRecurrenceDayOfWeek *> *days = recurrenceRule.daysOfTheWeek;
        if (days.count) {
            start = [[NSDateComponents alloc] init];
            start.weekday = days[0].dayOfTheWeek;
            start.weekdayOrdinal = days[0].weekNumber;
        }
    }
    INRecurrenceRule *rule = [[INRecurrenceRule alloc] initWithInterval:interval frequency:frequency];
    return [self initWithStartDateComponents:start endDateComponents:nil recurrenceRule:rule];
}

- (EKRecurrenceRule *)EKRecurrenceRule
{
    EKRecurrenceFrequency frequency;
    if (!self.recurrenceRule || !CharonEventKitFrequencyFromRecurrence(self.recurrenceRule.frequency, &frequency)) {
        return nil;
    }
    NSInteger weekday = [self.startDateComponents valueForComponent:NSCalendarUnitWeekday];
    if (weekday == NSDateComponentUndefined) {
        weekday = 0;
    }
    NSInteger ordinal = [self.startDateComponents valueForComponent:NSCalendarUnitWeekdayOrdinal];
    if (ordinal == NSDateComponentUndefined) {
        ordinal = 0;
    }
    // EventKit refuses day 0 with "Invalid day number", which the host's getter raises as well: that raise is kept.
    EKRecurrenceDayOfWeek *day = [EKRecurrenceDayOfWeek dayOfWeek:weekday weekNumber:ordinal];
    return [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:frequency interval:self.recurrenceRule.interval daysOfTheWeek:@[day] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil];
}

@end
