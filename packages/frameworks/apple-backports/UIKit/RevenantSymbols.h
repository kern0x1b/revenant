#import <UIKit/UIKit.h>
#import "RevenantMenus.h"

NSString *revenant_trait_summary(UITraitCollection *traits);

@interface UIImageConfiguration (RevenantSymbols)
- (instancetype)initRevenantWithTraitCollection:(UITraitCollection *)traits;
- (BOOL)revenant_isUnspecified;
- (BOOL)revenant_hasTraitsOfConfiguration:(UIImageConfiguration *)otherConfiguration;
- (void)revenant_applyFieldsOfConfiguration:(UIImageConfiguration *)other;
- (NSMutableArray<NSString *> *)revenant_fieldDescriptions;
@end

@interface UIImageSymbolConfiguration (RevenantSymbols)
- (instancetype)initRevenantWithPointSize:(double)pointSize hasPointSize:(BOOL)hasPointSize weight:(NSInteger)weight scale:(NSInteger)scale
                               textStyle:(NSString *)textStyle traitCollection:(UITraitCollection *)traits;
- (double)revenant_symbolPointSize;
- (NSInteger)revenant_symbolWeight;
- (NSInteger)revenant_symbolScale;
@end

BOOL revenant_symbol_known(NSString *name);
BOOL revenant_symbol_metrics(NSString *name, double pointSize, NSInteger weight, NSInteger scale, CGSize *size, UIEdgeInsets *insets, CGFloat *baseline);
UIImage *revenant_symbol_bitmap(NSString *name, double pointSize, NSInteger weight, NSInteger scale, CGFloat displayScale);
