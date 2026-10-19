// What each quantity type of the SDK is counted in, and how its values are aggregated.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The kinds of type the store records, as the store's own type row records them.
typedef NS_ENUM(NSInteger, CharonHKTypeKind) {
    CharonHKTypeKindQuantity = 0,
    CharonHKTypeKindCategory = 1,
    CharonHKTypeKindCorrelation = 2,
    CharonHKTypeKindCharacteristic = 3,
    CharonHKTypeKindWorkout = 4,
};

// The aggregation styles, as the store's own type row records them. The three of
// HKQuantityAggregationStyle are the first three; the two later ones the header's own comment names
// are recorded as the style each is, and a query that asks for either is answered as the release
// answers a type whose aggregation it does not have.
typedef NS_ENUM(NSInteger, CharonHKAggregationStyle) {
    CharonHKAggregationCumulativeSum = 0,
    CharonHKAggregationDiscreteArithmetic = 1,
    CharonHKAggregationDiscreteStatistical = 2,
    CharonHKAggregationDiscreteMostRecent = 3,
    CharonHKAggregationDiscreteEquivalentContinuousLevel = 4,
    CharonHKAggregationDiscreteTemporallyWeighted = 5,
};

// One row of the table: what a quantity type identifier is counted in.
typedef struct {
    __unsafe_unretained NSString *identifier;
    __unsafe_unretained NSString *unit;
    CharonHKAggregationStyle aggregation;
} CharonHKTypeEntry;

// The row of a quantity type identifier, or NULL for an identifier the SDK header names no unit for.
extern const CharonHKTypeEntry *_Nullable CharonHKQuantityTypeEntry(NSString *identifier);
// How many rows the table has, and the row at an index of it, so that a caller can be asked about
// every identifier the SDK's own header names - the host differential is one such caller.
extern NSUInteger CharonHKQuantityTypeCount(void);
extern const CharonHKTypeEntry *_Nullable CharonHKQuantityTypeEntryAt(NSUInteger index);

// The class a row of the store holds, from the kind its row records, and the class a type
// identifier names, from the kind the store keeps for it. Both are answered by name and looked up,
// so that no file of this framework names a class of it as a symbol except the one that defines it.
extern Class _Nullable CharonHKClassForObjectKind(NSInteger kind);

// How a kind's class is found. The default is the runtime's own lookup by name, which is right in the
// library: this port defines the class under the name the table names. A host harness that links this
// library's objects next to the system's HealthKit has two classes of each name, and the harness's own
// are renamed, so it installs a resolver of its own to say where they went. Nothing here decides policy:
// the table still says which name belongs to which kind, and only the lookup of that name is replaceable.
typedef Class _Nullable (^CharonHKClassResolver)(NSString *name);
extern void CharonHKSetClassResolver(CharonHKClassResolver _Nullable resolver);
extern Class _Nullable CharonHKClassForTypeKind(NSInteger kind);

// Whether the SDK header names an identifier of this kind at all, so that the class methods of
// HKObjectType answer nil for one it does not have, as the release does.
extern BOOL CharonHKHasTypeIdentifier(NSString *identifier, CharonHKTypeKind kind);

NS_ASSUME_NONNULL_END
