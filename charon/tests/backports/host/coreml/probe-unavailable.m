/* probe-unavailable.m -- what a host's own Core ML answers for the initialisers it declares
 * NS_UNAVAILABLE, and for the model-update classes of iOS 13.
 *
 * Why this exists: NS_UNAVAILABLE is a COMPILE-time annotation. A registry row that read it as a
 * run-time refusal was wrong, and this is what shows it: every one of +new and -init is answered
 * at run time, inherited from NSObject, and the answer is an object whose own accessors read nil.
 * `responds=` and the answer are both printed, so a row can say what a caller really gets.
 *
 * The send is through objc_msgSend rather than a bracketed call because the compiler refuses to
 * write one: that refusal is the annotation, and reproducing it here would make the probe unable
 * to measure what it exists to measure.
 *
 * Usage (this is the command facts/CoreML/CoreML.md cites):
 *   sdk=$(xcrun --show-sdk-path)
 *   xcrun clang -fobjc-arc -w -framework Foundation -framework CoreML \
 *       -F"$sdk/System/Library/Frameworks" probe-unavailable.m -o probe-unavailable && ./probe-unavailable
 */
#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* One initialiser, asked the two ways a caller can reach it: the class method, and the instance
 * method on a fresh allocation. `what` is what came back -- the address, or the exception, or (for
 * a key) the two accessors that answer for it, which is where the interesting part is. */
static void report_initialiser(const char *label, Class cls, SEL sel, BOOL from_class)
{
    id answer = nil;
    NSString *what;
    @try {
        /* Written out rather than folded into one expression: a conditional operator over two
         * objc_msgSend casts does not parse, and the shape here is the shape a reader checks. */
        if (from_class) {
            answer = ((id (*)(id, SEL))objc_msgSend)(cls, sel);
        } else {
            id allocated = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
            answer = ((id (*)(id, SEL))objc_msgSend)(allocated, sel);
        }
        what = [NSString stringWithFormat:@"answered %@", answer];
        if ([answer isKindOfClass:[MLKey class]]) {
            /* A key built by an initialiser has no name and no scope, and a dictionary of a model's
             * parameters is keyed by name, so this object answers no lookup. That is the whole
             * reason the header marks the initialiser unavailable, and it is invisible from the
             * annotation alone. */
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
        /* Every name the iOS 13 rows of registry/CoreML/absent_CoreML.json are about: the three key
         * classes whose initialisers are NS_UNAVAILABLE, the update-task family, and the protocol
         * whose one method writes a model specification out. */
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

        /* The protocol is reached by name and not by symbol, so a release that carries no Core ML
         * at all answers nil here -- which is what the absent row's effect says. */
        printf("MLWritable: NSProtocolFromString -> %s\n",
               NSProtocolFromString(@"MLWritable") ? "a protocol" : "nil");
        printf("MLFeatureProvider: NSProtocolFromString -> %s\n",
               NSProtocolFromString(@"MLFeatureProvider") ? "a protocol" : "nil");

        /* And the image constructors the eight rows of the same file are about, asked on the host
         * so the row can say the host answers them (which is why they are absent by the RELEASE's
         * doing and not the port's). */
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
