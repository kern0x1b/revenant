#import <Foundation/Foundation.h>

typedef void (^CoreMLRecorder)(NSString *name, NSString *value);

void coreml_run(NSString *models, CoreMLRecorder record);

void coreml_device_cases(CoreMLRecorder record);
