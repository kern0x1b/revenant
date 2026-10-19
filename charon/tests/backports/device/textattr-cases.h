#import <UIKit/UIKit.h>

typedef void (^TextAttrRecorder)(NSString *name, NSString *value);

void textattr_run(TextAttrRecorder record);
