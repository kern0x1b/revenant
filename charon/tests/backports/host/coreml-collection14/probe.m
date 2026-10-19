/* probe.m - prints the value of the one constant of the model-collection family, MLModelCollectionDidChangeNotification.
 *
 * The host's CoreML is read through dlsym, because the SDK's stub of the framework does not export the symbol (the constant is
 * sunset there), and the framework's own image does. The port's MLModelCollection14.m is referenced directly, with no framework
 * linked. The two are the same file: HOST_DLSYM is defined for the host build only. */
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
