#import <UIKit/UIKit.h>

typedef void (^FittingRecorder)(NSString *name, NSString *value);

void fitting_run(UIWindow *window, FittingRecorder record);
