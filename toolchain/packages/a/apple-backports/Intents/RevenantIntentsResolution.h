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

- (id)resolvedValue;

- (NSArray *)valuesToDisambiguate;

- (id)valueToConfirm;

- (CharonIntentsResolutionStatus)resolutionStatus;

- (NSInteger)charon_unsupportedReason;

@end

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

+ (instancetype)confirmationRequiredWithItemToConfirm:(id)itemToConfirm forReason:(NSInteger)reason;

- (void)charon_adoptResolutionOf:(id)inner;

@end
