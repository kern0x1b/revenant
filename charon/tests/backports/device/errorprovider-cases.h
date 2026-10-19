#import <Foundation/Foundation.h>

typedef void (^ErrorProviderRecorder)(NSString *name, NSString *value);
// The registration of a provider for a domain, as one call, because the two callers cannot spell it the
// same way: the device test registers on NSError with the port's own class method, and a host differential
// registers on a class of its own with the renamed spelling prefix_selectors.py gives the port's file. The
// class errors are made with comes with it, so that the answers asked of are the answers of that class.
typedef void (^ErrorProviderSetter)(Class error_class, NSString *domain, id provider);

void errorprovider_run(Class error_class, ErrorProviderSetter set_provider, ErrorProviderRecorder record);
