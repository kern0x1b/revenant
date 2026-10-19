#import <UIKit/UIKit.h>
#import "CharonMenus.h"

NSString *charon_trait_summary(UITraitCollection *traits);

@interface UIImageConfiguration (CharonSymbols)
- (instancetype)initCharonWithTraitCollection:(UITraitCollection *)traits;
- (BOOL)charon_isUnspecified;
- (BOOL)charon_hasTraitsOfConfiguration:(UIImageConfiguration *)otherConfiguration;
- (void)charon_applyFieldsOfConfiguration:(UIImageConfiguration *)other;
- (NSMutableArray<NSString *> *)charon_fieldDescriptions;
@end

@interface UIImageSymbolConfiguration (CharonSymbols)
- (instancetype)initCharonWithPointSize:(double)pointSize hasPointSize:(BOOL)hasPointSize weight:(NSInteger)weight scale:(NSInteger)scale
                               textStyle:(NSString *)textStyle traitCollection:(UITraitCollection *)traits;
- (double)charon_symbolPointSize;
- (NSInteger)charon_symbolWeight;
- (NSInteger)charon_symbolScale;
@end

BOOL charon_symbol_known(NSString *name);
BOOL charon_symbol_metrics(NSString *name, double pointSize, NSInteger weight, NSInteger scale, CGSize *size, UIEdgeInsets *insets, CGFloat *baseline);
UIImage *charon_symbol_bitmap(NSString *name, double pointSize, NSInteger weight, NSInteger scale, CGFloat displayScale);
