#import <UIKit/UIKit.h>

typedef struct {
    Class dimension, size, spacing, edgeSpacing, anchor, item, group, customItem, supplementary, boundary, decoration, section, configuration, layout;
} CompositionalKit;

@interface CompositionalCase : NSObject
@property (nonatomic, strong) UICollectionViewLayout *layout;
@property (nonatomic, strong) NSArray *counts;
@property (nonatomic, strong) NSArray *kinds;
@property (nonatomic, strong) NSArray *decorations;
@property (nonatomic) CGSize size;
@property (nonatomic) CGPoint offset;
@property (nonatomic) UIEdgeInsets margins;
@end

CompositionalKit compositional_kit(NSString *prefix);
NSUInteger compositional_case_count(void);
NSString *compositional_case_name(NSUInteger index);
NSString *compositional_case_dump(CompositionalKit kit, NSUInteger index, UIWindow *window);
NSString *compositional_dump(CompositionalCase *built, UIWindow *window);
NSUInteger compositional_sized_count(void);
BOOL compositional_release_while_pending(CompositionalKit kit, UIWindow *window);
NSString *compositional_sized_name(NSUInteger index);
NSString *compositional_sized_expected(NSUInteger index, NSString *recorded, NSMutableArray *differences);
NSString *compositional_sized_dump(CompositionalKit kit, NSUInteger index, UIWindow *window);
NSArray *compositional_orthogonal_lines(CompositionalKit kit, UIWindow *window, BOOL system);
