#import <UIKit/UIKit.h>

typedef void (^CoordSpaceRecorder)(NSString *name, NSString *value);

void coordspace_run(UIWindow *window, CoordSpaceRecorder record);
