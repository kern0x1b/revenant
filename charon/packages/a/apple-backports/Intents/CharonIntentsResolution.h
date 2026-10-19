// What a resolution result holds, read back.
//
// INIntentResolutionResult's own surface in the SDK is three class methods and nothing else:
// on a release with Siri, the system is the reader of the result — it asks a handler's app for
// a value, the app answers with +successWithResolved…: or +confirmationRequired…:, and the
// system reads the value out of the result itself. This release runs no assistant daemon, so
// the app that resolves a parameter is the reader, and the four declarations below are where it
// reads what it just stored. They are named as Charon's own, in a header of this package, so
// they collide with nothing Apple has and they are absent on a release that carries
// Intents.framework itself (where the system's own result answers instead).
//
// The status is what the header's three names say: needsValue asks the user, notRequired says
// the parameter needs nothing, unsupported says the parameter cannot be resolved at all, and
// success / disambiguation / confirmationRequired are the three answers the typed factories
// build.

#import <Intents/Intents.h>

typedef NS_ENUM(NSInteger, CharonIntentsResolutionStatus) {
    CharonIntentsResolutionNeedsValue = 0,
    CharonIntentsResolutionNotRequired,
    CharonIntentsResolutionUnsupported,
    CharonIntentsResolutionSuccess,
    CharonIntentsResolutionDisambiguation,
    CharonIntentsResolutionConfirmationRequired,
};

@interface INIntentResolutionResult (CharonIntentsResolution)

// The value +successWithResolved…: stored, nil for every other answer.
- (id)resolvedValue;

// The values +disambiguationWith…ToDisambiguate: was given, nil for every other answer.
- (NSArray *)valuesToDisambiguate;

// The value +confirmationRequiredWith…ToConfirm: was given, nil for every other answer.
- (id)valueToConfirm;

// Which of the six answers this is.
- (CharonIntentsResolutionStatus)resolutionStatus;

// The reason +unsupportedForReason: was given, and 0 for a result that is not an unsupported one.
// The reason is an enumeration of the release that added the method, and the classes that take
// one expose no reader for it in their own headers - on those releases the system, which does
// not exist here, is the only one who reads it. A result that swallowed the reason would answer
// "unsupported" with no way to say why, which is a different answer from the one the method's
// name promises.
- (NSInteger)charon_unsupportedReason;

@end

// What every generated resolution result builds its answer with, and what the four accessors
// above read. The one place the state of a result is written, so a subclass of a subclass
// resolves exactly as its parent does.
@interface INIntentResolutionResult (CharonIntentsBuilding)

+ (instancetype)charon_resolutionWithStatus:(CharonIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm;

+ (instancetype)charon_resolutionWithStatus:(CharonIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm
                         unsupportedReason:(NSInteger)unsupportedReason;

// A confirmation of an item for a reason; the reason is kept, for the reader confirmationReason.
+ (instancetype)confirmationRequiredWithItemToConfirm:(id)itemToConfirm forReason:(NSInteger)reason;

// A result that answers what another result answers, for the resolution results whose designated
// initialiser takes one - INSendPaymentPayeeResolutionResult taking an
// INPersonResolutionResult, and the four others of that shape. A caller that resolves a payee
// asks this class and must get the answer the inner one gives, including its status, so the
// inner one's whole state is taken rather than re-derived.
- (void)charon_adoptResolutionOf:(id)inner;

@end
