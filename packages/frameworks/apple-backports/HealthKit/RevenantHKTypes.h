#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RevenantHKTypeKind) {
    RevenantHKTypeKindQuantity = 0,
    RevenantHKTypeKindCategory = 1,
    RevenantHKTypeKindCorrelation = 2,
    RevenantHKTypeKindCharacteristic = 3,
    RevenantHKTypeKindWorkout = 4,
};

typedef NS_ENUM(NSInteger, RevenantHKAggregationStyle) {
    RevenantHKAggregationCumulativeSum = 0,
    RevenantHKAggregationDiscreteArithmetic = 1,
    RevenantHKAggregationDiscreteStatistical = 2,
    RevenantHKAggregationDiscreteMostRecent = 3,
    RevenantHKAggregationDiscreteEquivalentContinuousLevel = 4,
    RevenantHKAggregationDiscreteTemporallyWeighted = 5,
};

typedef struct {
    __unsafe_unretained NSString *identifier;
    __unsafe_unretained NSString *unit;
    RevenantHKAggregationStyle aggregation;
} RevenantHKTypeEntry;

extern const RevenantHKTypeEntry *_Nullable RevenantHKQuantityTypeEntry(NSString *identifier);
extern NSUInteger RevenantHKQuantityTypeCount(void);
extern const RevenantHKTypeEntry *_Nullable RevenantHKQuantityTypeEntryAt(NSUInteger index);

extern Class _Nullable RevenantHKClassForObjectKind(NSInteger kind);

typedef Class _Nullable (^RevenantHKClassResolver)(NSString *name);
extern void RevenantHKSetClassResolver(RevenantHKClassResolver _Nullable resolver);
extern Class _Nullable RevenantHKClassForTypeKind(NSInteger kind);

extern BOOL RevenantHKHasTypeIdentifier(NSString *identifier, RevenantHKTypeKind kind);

NS_ASSUME_NONNULL_END
