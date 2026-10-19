#import <Foundation/Foundation.h>

typedef void (^PersonNameRecorder)(NSString *name, NSString *value);

void personname_run(PersonNameRecorder record);
