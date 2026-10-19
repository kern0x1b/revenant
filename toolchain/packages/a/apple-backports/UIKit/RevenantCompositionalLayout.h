#import <UIKit/UIKit.h>
#import "../CharonSayOnce.h"

typedef NS_ENUM(NSInteger, CharonGroupDirection) {
    CharonGroupDirectionHorizontal,
    CharonGroupDirectionVertical,
    CharonGroupDirectionCustom
};

typedef NS_ENUM(NSInteger, CharonDimensionKind) {
    CharonDimensionKindFractionalWidth,
    CharonDimensionKindFractionalHeight,
    CharonDimensionKindAbsolute,
    CharonDimensionKindEstimated
};

static inline void charon_layout_say_once(NSString *key, NSString *text)
{
    charon_say_once_for(key, text);
}

@interface NSCollectionLayoutItem (CharonLayout)
- (instancetype)initCharonWithSize:(NSCollectionLayoutSize *)size supplementaryItems:(NSArray *)supplementaryItems;
- (NSString *)charon_bodyDescription;
- (NSString *)charon_kindName;
@end

@interface NSCollectionLayoutSupplementaryItem (CharonLayout)
- (instancetype)initCharonWithSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)elementKind containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
                        itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor;
@end

@interface NSCollectionLayoutBoundarySupplementaryItem (CharonLayout)
- (instancetype)initCharonWithSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)elementKind alignment:(NSRectAlignment)alignment offset:(CGPoint)offset;
@end

@interface NSCollectionLayoutDecorationItem (CharonLayout)
- (instancetype)initCharonWithElementKind:(NSString *)elementKind;
@end

@interface NSCollectionLayoutGroup (CharonLayout)
- (instancetype)initCharonWithSize:(NSCollectionLayoutSize *)size direction:(CharonGroupDirection)direction subitems:(NSArray *)subitems
                             count:(NSInteger)count provider:(NSCollectionLayoutGroupCustomItemProvider)provider;
- (CharonGroupDirection)charon_direction;
- (NSInteger)charon_repeatCount;
- (NSCollectionLayoutGroupCustomItemProvider)charon_itemProvider;
@end

@interface NSCollectionLayoutSection (CharonLayout)
- (NSCollectionLayoutGroup *)charon_group;
- (NSInteger)charon_contentInsetsReference;
- (void)charon_setContentInsetsReference:(NSInteger)reference;
- (NSInteger)charon_supplementaryContentInsetsReference;
@end

@interface UICollectionViewCompositionalLayoutConfiguration (CharonLayout)
- (NSInteger)charon_contentInsetsReference;
- (void)charon_setContentInsetsReference:(NSInteger)reference;
@end

@interface NSCollectionLayoutAnchor (CharonLayout)
- (CGPoint)charon_anchorPoint;
@end

@interface NSCollectionLayoutSize (CharonLayout)
- (instancetype)initCharonWithWidth:(NSCollectionLayoutDimension *)width height:(NSCollectionLayoutDimension *)height;
@end

@interface NSCollectionLayoutSpacing (CharonLayout)
- (instancetype)initCharonWithSpacing:(CGFloat)spacing flexible:(BOOL)flexible;
@end

@interface NSCollectionLayoutDimension (CharonLayout)
- (instancetype)initCharonWithKind:(CharonDimensionKind)kind value:(CGFloat)value;
@end

@interface CharonSolvedElement : NSObject {
@public
    NSInteger category;
    NSString *kind;
    NSIndexPath *indexPath;
    CGRect frame;
    NSInteger zIndex;
    BOOL pinned;
    NSRectAlignment alignment;
    CGFloat pinLow;
    CGFloat pinHigh;
    BOOL hasOwner;
    CGRect owner;
    BOOL scrolls;
    BOOL estimatedWidth;
    BOOL estimatedHeight;
}
@end

@interface CharonSolvedSection : NSObject {
@public
    NSInteger section;
    CGRect extent;
    NSMutableArray *elements;
    CGFloat crossSize;
    BOOL orthogonal;
    CGRect viewport;
    CGFloat contentWidth;
    NSArray *groupLeads;
    NSArray *groupWidths;
    NSInteger behavior;
    id handler;
}
@end


@interface UICollectionViewLayout (CharonOrthogonal)
- (void)charon_offsetsDidChange;
@end

@interface CharonOrthogonalController : NSObject <UIGestureRecognizerDelegate>
- (instancetype)initWithLayout:(UICollectionViewLayout *)layout;
- (void)updateSections:(NSArray *)sections view:(UICollectionView *)view environment:(id<NSCollectionLayoutEnvironment>)environment;
- (CGFloat)offsetOfSection:(NSInteger)section;
- (void)scrollSection:(NSInteger)section toOffset:(CGFloat)offset settle:(BOOL)settle;
- (CGRect)shiftedFrame:(CGRect)frame section:(NSInteger)section;
- (BOOL)viewportShows:(CGRect)shifted section:(NSInteger)section;
- (void)applyToAttributes:(UICollectionViewLayoutAttributes *)attributes element:(CharonSolvedElement *)element;
- (void)detach;
@end

@interface UICollectionViewLayout (CharonSelfSizing)
- (BOOL)charon_settleMeasurements;
- (NSUInteger)charon_estimatedAxesForAttributes:(UICollectionViewLayoutAttributes *)attributes;
@end

UICollectionViewLayoutAttributes *charon_default_preferred(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight);
UICollectionViewLayoutAttributes *charon_preferred_attributes(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight, CGFloat scale);
void charon_layout_perform(UICollectionViewLayout *layout, void (^work)(UICollectionViewLayout *layout));
