#import <Foundation/Foundation.h>
#ifdef HOST_DLSYM
#import <dlfcn.h>
#endif

#ifndef HOST_DLSYM
extern NSString *const MLModelCollectionDidChangeNotification;
#endif

int main(void)
{
    NSString *value = nil;
#ifdef HOST_DLSYM
    void *handle = dlopen("/System/Library/Frameworks/CoreML.framework/CoreML", RTLD_NOW);
    NSString * __unsafe_unretained const *symbol = (NSString * __unsafe_unretained const *)dlsym(handle, "MLModelCollectionDidChangeNotification");
    if (symbol == NULL) {
        printf("MLModelCollectionDidChangeNotification absent\n");
        return 1;
    }
    value = *symbol;
#else
    value = MLModelCollectionDidChangeNotification;
#endif
    printf("MLModelCollectionDidChangeNotification %s\n", [value UTF8String]);
    return 0;
}
