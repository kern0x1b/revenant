#import <UIKit/UIKit.h>
#import "../RevenantSayOnce.h"

typedef NS_ENUM(NSInteger, RevenantGroupDirection) {
    RevenantGroupDirectionHorizontal,
    RevenantGroupDirectionVertical,
    RevenantGroupDirectionCustom
};

typedef NS_ENUM(NSInteger, RevenantDimensionKind) {
    RevenantDimensionKindFractionalWidth,
    RevenantDimensionKindFractionalHeight,
    RevenantDimensionKindAbsolute,
    RevenantDimensionKindEstimated
};

static inline void revenant_layout_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
}

@interface NSCollectionLayoutItem (RevenantLayout)
- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size supplementaryItems:(NSArray *)supplementaryItems;
- (NSString *)revenant_bodyDescription;
- (NSString *)revenant_kindName;
@end

@interface NSCollectionLayoutSupplementaryItem (RevenantLayout)
- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)elementKind containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
                        itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor;
@end

@interface NSCollectionLayoutBoundarySupplementaryItem (RevenantLayout)
- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)elementKind alignment:(NSRectAlignment)alignment offset:(CGPoint)offset;
@end

@interface NSCollectionLayoutDecorationItem (RevenantLayout)
- (instancetype)initRevenantWithElementKind:(NSString *)elementKind;
@end

@interface NSCollectionLayoutGroup (RevenantLayout)
- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size direction:(RevenantGroupDirection)direction subitems:(NSArray *)subitems
                             count:(NSInteger)count provider:(NSCollectionLayoutGroupCustomItemProvider)provider;
- (RevenantGroupDirection)revenant_direction;
- (NSInteger)revenant_repeatCount;
- (NSCollectionLayoutGroupCustomItemProvider)revenant_itemProvider;
@end

@interface NSCollectionLayoutSection (RevenantLayout)
- (NSCollectionLayoutGroup *)revenant_group;
- (NSInteger)revenant_contentInsetsReference;
- (void)revenant_setContentInsetsReference:(NSInteger)reference;
- (NSInteger)revenant_supplementaryContentInsetsReference;
@end

@interface UICollectionViewCompositionalLayoutConfiguration (RevenantLayout)
- (NSInteger)revenant_contentInsetsReference;
- (void)revenant_setContentInsetsReference:(NSInteger)reference;
@end

@interface NSCollectionLayoutAnchor (RevenantLayout)
- (CGPoint)revenant_anchorPoint;
@end

@interface NSCollectionLayoutSize (RevenantLayout)
- (instancetype)initRevenantWithWidth:(NSCollectionLayoutDimension *)width height:(NSCollectionLayoutDimension *)height;
@end

@interface NSCollectionLayoutSpacing (RevenantLayout)
- (instancetype)initRevenantWithSpacing:(CGFloat)spacing flexible:(BOOL)flexible;
@end

@interface NSCollectionLayoutDimension (RevenantLayout)
- (instancetype)initRevenantWithKind:(RevenantDimensionKind)kind value:(CGFloat)value;
@end

@interface RevenantSolvedElement : NSObject {
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

@interface RevenantSolvedSection : NSObject {
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


@interface UICollectionViewLayout (RevenantOrthogonal)
- (void)revenant_offsetsDidChange;
@end

@interface RevenantOrthogonalController : NSObject <UIGestureRecognizerDelegate>
- (instancetype)initWithLayout:(UICollectionViewLayout *)layout;
- (void)updateSections:(NSArray *)sections view:(UICollectionView *)view environment:(id<NSCollectionLayoutEnvironment>)environment;
- (CGFloat)offsetOfSection:(NSInteger)section;
- (void)scrollSection:(NSInteger)section toOffset:(CGFloat)offset settle:(BOOL)settle;
- (CGRect)shiftedFrame:(CGRect)frame section:(NSInteger)section;
- (BOOL)viewportShows:(CGRect)shifted section:(NSInteger)section;
- (void)applyToAttributes:(UICollectionViewLayoutAttributes *)attributes element:(RevenantSolvedElement *)element;
- (void)detach;
@end

@interface UICollectionViewLayout (RevenantSelfSizing)
- (BOOL)revenant_settleMeasurements;
- (NSUInteger)revenant_estimatedAxesForAttributes:(UICollectionViewLayoutAttributes *)attributes;
@end

UICollectionViewLayoutAttributes *revenant_default_preferred(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight);
UICollectionViewLayoutAttributes *revenant_preferred_attributes(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight, CGFloat scale);
void revenant_layout_perform(UICollectionViewLayout *layout, void (^work)(UICollectionViewLayout *layout));
