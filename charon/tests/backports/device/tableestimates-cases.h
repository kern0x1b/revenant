#import <UIKit/UIKit.h>

typedef void (^TableEstimatesRecorder)(NSString *name, NSString *value);

void tableestimates_run(TableEstimatesRecorder record);
