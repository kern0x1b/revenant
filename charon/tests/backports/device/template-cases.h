#import <UIKit/UIKit.h>

typedef void (^TemplateRecorder)(NSString *name, NSString *value);

void template_run(UIWindow *window, TemplateRecorder record);
