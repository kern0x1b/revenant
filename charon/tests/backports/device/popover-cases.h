#import <UIKit/UIKit.h>

typedef void (^PopoverRecorder)(NSString *name, NSString *value);

void popover_defaults(UIWindow *window, PopoverRecorder record);
