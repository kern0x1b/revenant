#import <UIKit/UIKit.h>

typedef void (^HomeIndicatorRecorder)(NSString *name, NSString *value);

void homeindicator_run(UIWindow *window, HomeIndicatorRecorder record);
