#import <UIKit/UIKit.h>

typedef void (^CustomPresentationRecorder)(NSString *name, NSString *value);

void custompresentation_run(UIWindow *window, CustomPresentationRecorder record, void (^done)(void));
