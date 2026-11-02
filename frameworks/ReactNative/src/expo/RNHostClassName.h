#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

#ifdef __cplusplus
extern "C" {
#endif
NSString *RNHostStringFromClass(Class aClass, const char *file, int line);
#ifdef __cplusplus
}
#endif

#define NSStringFromClass(aClass) RNHostStringFromClass((aClass), __FILE__, __LINE__)
