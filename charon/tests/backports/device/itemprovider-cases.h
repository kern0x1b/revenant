#import <Foundation/Foundation.h>

typedef void (^ItemProviderRecorder)(NSString *name, NSString *value);

void itemprovider_run(ItemProviderRecorder record);
