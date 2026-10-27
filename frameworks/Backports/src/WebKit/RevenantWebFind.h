#import <UIKit/UIKit.h>

typedef NSString *(^RevenantWebEvaluator)(NSString *script);

@interface RevenantWebFindSession : UIFindSession

- (instancetype)initWithEvaluator:(RevenantWebEvaluator)evaluator;

@end
