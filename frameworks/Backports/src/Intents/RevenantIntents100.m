#import <Intents/Intents.h>
#import <Intents/INIntentHandlerProviding.h>
#import <Intents/INParameter.h>
#import <EventKit/EventKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#import "RevenantCoding.h"
#import "RevenantIntentsResolution.h"
#import "RevenantIntentsStore.h"

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

- (NSData *)revenant_imageData
{
    return _data;
}

+ (instancetype)imageNamed:(NSString *)name
{
    if (!name.length) {
        return nil;
    }
    UIImage *image = [UIImage imageNamed:name];
    NSData *data = image ? UIImagePNGRepresentation(image) : nil;
    if (!data) {
        return nil;
    }
    return [self revenant_imageWithName:name data:data width:image.size.width height:image.size.height];
}

+ (instancetype)systemImageNamed:(NSString *)name
{
    if (!name.length) {
        return nil;
    }
    UIImage *image = [UIImage systemImageNamed:name];
    NSData *data = image ? UIImagePNGRepresentation(image) : nil;
    if (!data) {
        return nil;
    }
    return [self revenant_imageWithName:name data:data width:image.size.width height:image.size.height];
}

+ (instancetype)imageWithImageData:(NSData *)imageData
{
    if (!imageData) {
        return nil;
    }
    return [self revenant_imageWithName:nil data:imageData width:0 height:0];
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
    return [self revenant_imageWithName:URL.lastPathComponent data:data width:width height:height];
}

+ (instancetype)revenant_imageWithName:(NSString *)name data:(NSData *)data width:(double)width height:(double)height
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
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INImage *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
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
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INIntent *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
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
    if ((self = [self initWithVocabularyIdentifier:identifier
                                      spokenPhrase:spokenPhrase
                                 pronunciationHint:pronunciationHint]))
        _identifier = [identifier copy];
    return self;
}

- (instancetype)initWithSpokenPhrase:(NSString *)spokenPhrase
{
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
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INSpeakableString *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INExtension

@implementation INExtension

+ (NSString *)revenant_handlingProtocolNameForIntent:(INIntent *)intent
{
    NSString *name = [NSString stringWithCString:class_getName([intent class]) encoding:NSUTF8StringEncoding];
    return [name stringByAppendingString:@"Handling"];
}

- (id)handlerForIntent:(INIntent *)intent
{
    if (!intent) {
        return nil;
    }
    NSString *wanted = [[self class] revenant_handlingProtocolNameForIntent:intent];
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
    id instance = [[self class] revenant_newHandlerOfClass:candidate];
    return [instance respondsToSelector:@selector(handleIntent:)] ? instance : nil;
}

+ (id)revenant_newHandlerOfClass:(Class)candidate
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
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INPaymentMethod *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INRideCompletionStatus

typedef NS_ENUM(NSInteger, RevenantIntentsRideOutcome) {
    RevenantIntentsRideCompleted = 0,
    RevenantIntentsRideCanceled,
    RevenantIntentsRideMissedPickup,
};

@implementation INRideCompletionStatus {
    RevenantIntentsRideOutcome _outcome;
    BOOL _outstanding;
    INCurrencyAmount *_paymentAmount;
    INRideFeedbackTypeOptions _feedbackType;
    NSUserActivity *_completionUserActivity;
    NSSet *_defaultTippingOptions;
}

@synthesize completionUserActivity = _completionUserActivity;
@synthesize defaultTippingOptions = _defaultTippingOptions;

+ (instancetype)revenant_completionWithOutcome:(RevenantIntentsRideOutcome)outcome
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
    return [self revenant_completionWithOutcome:RevenantIntentsRideCompleted
                                    outstanding:NO
                                  paymentAmount:nil
                                   feedbackType:0];
}

+ (instancetype)completedWithSettledPaymentAmount:(INCurrencyAmount *)settledPaymentAmount
{
    return [self revenant_completionWithOutcome:RevenantIntentsRideCompleted
                                    outstanding:NO
                                  paymentAmount:settledPaymentAmount
                                   feedbackType:0];
}

+ (instancetype)completedWithOutstandingPaymentAmount:(INCurrencyAmount *)outstandingPaymentAmount
{
    return [self revenant_completionWithOutcome:RevenantIntentsRideCompleted
                                    outstanding:YES
                                  paymentAmount:outstandingPaymentAmount
                                   feedbackType:0];
}

+ (instancetype)completedWithOutstandingFeedbackType:(INRideFeedbackTypeOptions)feedbackType
{
    return [self revenant_completionWithOutcome:RevenantIntentsRideCompleted
                                    outstanding:YES
                                  paymentAmount:nil
                                   feedbackType:feedbackType];
}

+ (instancetype)canceledByService
{
    return [self revenant_completionWithOutcome:RevenantIntentsRideCanceled
                                    outstanding:NO
                                  paymentAmount:nil
                                   feedbackType:0];
}

+ (instancetype)canceledByUser
{
    return [self canceledByService];
}

+ (instancetype)canceledMissedPickup
{
    return [self revenant_completionWithOutcome:RevenantIntentsRideMissedPickup
                                    outstanding:NO
                                  paymentAmount:nil
                                   feedbackType:0];
}

- (BOOL)isCompleted
{
    return _outcome == RevenantIntentsRideCompleted;
}

- (BOOL)isCanceled
{
    return _outcome != RevenantIntentsRideCompleted;
}

- (BOOL)isMissedPickup
{
    return _outcome == RevenantIntentsRideMissedPickup;
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
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INRideCompletionStatus *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

@end

#pragma mark - INPreferences

@implementation INPreferences

+ (INSiriAuthorizationStatus)siriAuthorizationStatus
{
    return INSiriAuthorizationStatusRestricted;
}

+ (void)requestSiriAuthorization:(void (^)(INSiriAuthorizationStatus status))handler
{
    if (handler) {
        handler([self siriAuthorizationStatus]);
    }
}

+ (NSString *)siriLanguageCode
{
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
    revenant_intents_store_vocabulary(type, [vocabulary array]);
}

- (void)setVocabulary:(NSOrderedSet *)vocabulary ofType:(INVocabularyStringType)type
{
    NSMutableArray *phrases = [NSMutableArray arrayWithCapacity:vocabulary.count];
    for (id<INSpeakable> value in vocabulary) {
        NSString *phrase = value.spokenPhrase;
        if (phrase) {
            [phrases addObject:phrase];
        }
    }
    revenant_intents_store_vocabulary(type, phrases);
}

- (void)removeAllVocabularyStrings
{
    revenant_intents_remove_vocabulary();
}

- (NSOrderedSet *)revenant_vocabularyStringsOfType:(INVocabularyStringType)type
{
    return revenant_intents_vocabulary(type);
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
    if (!_dateInterval) {
        _dateInterval = [[NSDateInterval alloc] initWithStartDate:[NSDate date] endDate:[NSDate date]];
    }
    NSError *error = revenant_intents_store_interaction(self);
    if (completion) {
        completion(error);
    }
}

+ (void)deleteAllInteractionsWithCompletion:(void (^)(NSError *))completion
{
    if (completion) {
        completion(revenant_intents_delete_interactions(nil, nil));
    }
}

+ (void)deleteInteractionsWithIdentifiers:(NSArray *)identifiers completion:(void (^)(NSError *))completion
{
    if (completion) {
        completion(revenant_intents_delete_interactions(identifiers, nil));
    }
}

+ (void)deleteInteractionsWithGroupIdentifier:(NSString *)groupIdentifier completion:(void (^)(NSError *))completion
{
    if (completion) {
        completion(revenant_intents_delete_interactions(nil, groupIdentifier));
    }
}

- (id)parameterValueForParameter:(INParameter *)parameter
{
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

+ (NSArray *)revenant_interactions
{
    return revenant_intents_stored_interactions(nil);
}

+ (NSArray *)revenant_interactionsWithGroupIdentifier:(NSString *)groupIdentifier
{
    return revenant_intents_stored_interactions(groupIdentifier);
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
    INInteraction *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

@end

@implementation INRideDriver (RevenantDeprecatedInitialisers)

static NSString *RevenantRideDriverNameFromComponents(NSPersonNameComponents *components)
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
    NSString *name = RevenantRideDriverNameFromComponents(nameComponents) ?: (handle ?: @"");
    return [self initWithPersonHandle:personHandle nameComponents:nameComponents displayName:name image:image rating:rating phoneNumber:phoneNumber];
}

@end

static INRecurrenceFrequency RevenantRecurrenceFrequencyFromEventKit(EKRecurrenceFrequency frequency)
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

static BOOL RevenantEventKitFrequencyFromRecurrence(INRecurrenceFrequency frequency, EKRecurrenceFrequency *eventKit)
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

@implementation INDateComponentsRange (RevenantEventKit)

- (instancetype)initWithEKRecurrenceRule:(EKRecurrenceRule *)recurrenceRule
{
    INRecurrenceFrequency frequency = INRecurrenceFrequencyDaily;
    NSUInteger interval = 0;
    NSDateComponents *start = nil;
    if (recurrenceRule) {
        frequency = RevenantRecurrenceFrequencyFromEventKit(recurrenceRule.frequency);
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
    if (!self.recurrenceRule || !RevenantEventKitFrequencyFromRecurrence(self.recurrenceRule.frequency, &frequency)) {
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
    EKRecurrenceDayOfWeek *day = [EKRecurrenceDayOfWeek dayOfWeek:weekday weekNumber:ordinal];
    return [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:frequency interval:self.recurrenceRule.interval daysOfTheWeek:@[day] daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:nil end:nil];
}

@end
