#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CharonHKTypeKind) {
    CharonHKTypeKindQuantity = 0,
    CharonHKTypeKindCategory = 1,
    CharonHKTypeKindCorrelation = 2,
    CharonHKTypeKindCharacteristic = 3,
    CharonHKTypeKindWorkout = 4,
};

typedef NS_ENUM(NSInteger, CharonHKAggregationStyle) {
    CharonHKAggregationCumulativeSum = 0,
    CharonHKAggregationDiscreteArithmetic = 1,
    CharonHKAggregationDiscreteStatistical = 2,
    CharonHKAggregationDiscreteMostRecent = 3,
    CharonHKAggregationDiscreteEquivalentContinuousLevel = 4,
    CharonHKAggregationDiscreteTemporallyWeighted = 5,
};

typedef struct {
    __unsafe_unretained NSString *identifier;
    __unsafe_unretained NSString *unit;
    CharonHKAggregationStyle aggregation;
} CharonHKTypeEntry;

extern const CharonHKTypeEntry *_Nullable CharonHKQuantityTypeEntry(NSString *identifier);
extern NSUInteger CharonHKQuantityTypeCount(void);
extern const CharonHKTypeEntry *_Nullable CharonHKQuantityTypeEntryAt(NSUInteger index);

extern Class _Nullable CharonHKClassForObjectKind(NSInteger kind);

typedef Class _Nullable (^CharonHKClassResolver)(NSString *name);
extern void CharonHKSetClassResolver(CharonHKClassResolver _Nullable resolver);
extern Class _Nullable CharonHKClassForTypeKind(NSInteger kind);

extern BOOL CharonHKHasTypeIdentifier(NSString *identifier, CharonHKTypeKind kind);

NS_ASSUME_NONNULL_END
