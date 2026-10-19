#import <Foundation/Foundation.h>

typedef void (^ErrorProviderRecorder)(NSString *name, NSString *value);
typedef void (^ErrorProviderSetter)(Class error_class, NSString *domain, id provider);

void errorprovider_run(Class error_class, ErrorProviderSetter set_provider, ErrorProviderRecorder record);
