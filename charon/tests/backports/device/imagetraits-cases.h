#import <UIKit/UIKit.h>

typedef void (^ImageTraitsRecorder)(NSString *name, NSString *value);

void imagetraits_run(UIWindow *window, ImageTraitsRecorder record);
