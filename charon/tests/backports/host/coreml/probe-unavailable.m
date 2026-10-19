#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <objc/message.h>
#import <objc/runtime.h>

static void report_initialiser(const char *label, Class cls, SEL sel, BOOL from_class)
{
    id answer = nil;
    NSString *what;
    @try {
        if (from_class) {
            answer = ((id (*)(id, SEL))objc_msgSend)(cls, sel);
        } else {
            id allocated = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
            answer = ((id (*)(id, SEL))objc_msgSend)(allocated, sel);
        }
        what = [NSString stringWithFormat:@"answered %@", answer];
        if ([answer isKindOfClass:[MLKey class]]) {
            what = [what stringByAppendingFormat:@" (name=%@ scope=%@)", ((MLKey *)answer).name,
                                                              ((MLKey *)answer).scope];
        }
    } @catch (NSException *exception) {
        what = [NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason];
    }
    printf("  %-8s responds=%d  %s\n", label,
           (int)(from_class ? [cls respondsToSelector:sel] : [cls instancesRespondToSelector:sel]),
           [what UTF8String]);
}

int main(void)
{
    @autoreleasepool {
        const char *classes[] = {"MLKey", "MLMetricKey", "MLParameterKey", "MLTask", "MLUpdateTask",
                                 "MLUpdateContext", "MLUpdateProgressHandlers"};
        size_t count = sizeof(classes) / sizeof(classes[0]);
        size_t index;

        for (index = 0; index < count; index++) {
            NSString *name = [NSString stringWithUTF8String:classes[index]];
            Class cls = NSClassFromString(name);
            printf("%s: NSClassFromString -> %s\n", [name UTF8String], cls ? "a class" : "nil");
            if (cls == nil) {
                continue;
            }
            printf("  superclass %s\n",
                   class_getSuperclass(cls) ? class_getName(class_getSuperclass(cls)) : "(none)");
            report_initialiser("+new", cls, @selector(new), YES);
            report_initialiser("-init", cls, @selector(init), NO);
        }

        printf("MLWritable: NSProtocolFromString -> %s\n",
               NSProtocolFromString(@"MLWritable") ? "a protocol" : "nil");
        printf("MLFeatureProvider: NSProtocolFromString -> %s\n",
               NSProtocolFromString(@"MLFeatureProvider") ? "a protocol" : "nil");

        Class feature = NSClassFromString(@"MLFeatureValue");
        printf("MLFeatureValue +featureValueWithCGImage:constraint:options:error: responds=%d\n",
               (int)[feature respondsToSelector:@selector(featureValueWithCGImage:constraint:options:error:)]);
        printf("MLFeatureValue +featureValueWithImageAtURL:constraint:options:error: responds=%d\n",
               (int)[feature respondsToSelector:@selector(featureValueWithImageAtURL:constraint:options:error:)]);
        printf("MLFeatureValue +featureValueWithPixelBuffer: responds=%d\n",
               (int)[feature respondsToSelector:@selector(featureValueWithPixelBuffer:)]);
    }
    return 0;
}
