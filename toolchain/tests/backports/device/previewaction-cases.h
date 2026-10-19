#import <Foundation/Foundation.h>

typedef void (^PreviewActionRecorder)(NSString *name, NSString *value);

void previewaction_run(PreviewActionRecorder record);
