#import <UIKit/UIKit.h>

typedef void (^TouchTypesRecorder)(NSString *name, NSString *value);

void touchtypes_run(UIWindow *window, TouchTypesRecorder record);
