#import <Intents/Intents.h>

typedef NS_ENUM(NSInteger, RevenantIntentsResolutionStatus) {
    RevenantIntentsResolutionNeedsValue = 0,
    RevenantIntentsResolutionNotRequired,
    RevenantIntentsResolutionUnsupported,
    RevenantIntentsResolutionSuccess,
    RevenantIntentsResolutionDisambiguation,
    RevenantIntentsResolutionConfirmationRequired,
};

@interface INIntentResolutionResult (RevenantIntentsResolution)

- (id)resolvedValue;

- (NSArray *)valuesToDisambiguate;

- (id)valueToConfirm;

- (RevenantIntentsResolutionStatus)resolutionStatus;

- (NSInteger)revenant_unsupportedReason;

@end

@interface INIntentResolutionResult (RevenantIntentsBuilding)

+ (instancetype)revenant_resolutionWithStatus:(RevenantIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm;

+ (instancetype)revenant_resolutionWithStatus:(RevenantIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm
                         unsupportedReason:(NSInteger)unsupportedReason;

+ (instancetype)confirmationRequiredWithItemToConfirm:(id)itemToConfirm forReason:(NSInteger)reason;

- (void)revenant_adoptResolutionOf:(id)inner;

@end
