#import <UIKit/UIKit.h>

typedef void (^Tail3Recorder)(NSString *name, NSString *value);

void tail3_run(Tail3Recorder record);
