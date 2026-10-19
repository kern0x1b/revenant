#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void line(NSString *text) {
    printf("PROBE %s\n", [text UTF8String]);
    fflush(stdout);
}

static NSString *image_of(IMP imp) {
    Dl_info info;
    if (imp == NULL || dladdr((const void *)imp, &info) == 0 || info.dli_fname == NULL) {
        return @"(no image)";
    }
    return [NSString stringWithUTF8String:info.dli_fname];
}

static void round_trip(NSString *label, SEL getter, SEL setter) {
    Method getM = class_getInstanceMethod([NSObject class], getter);
    Method setM = class_getInstanceMethod([NSObject class], setter);
    if (getM == NULL || setM == NULL) {
        line([NSString stringWithFormat:@"%@: round trip skipped, getter=%@ setter=%@", label,
              getM != NULL ? @"yes" : @"no", setM != NULL ? @"yes" : @"no"]);
        return;
    }
    NSObject *object = [[NSObject alloc] init];
    id fresh = ((id (*)(id, SEL))objc_msgSend)(object, getter);
    line([NSString stringWithFormat:@"%@: fresh object getter=%@", label, fresh]);
    NSArray *value = @[@"probe-action"];
    ((void (*)(id, SEL, id))objc_msgSend)(object, setter, value);
    id after = ((id (*)(id, SEL))objc_msgSend)(object, getter);
    line([NSString stringWithFormat:@"%@: after set, getter=%@ same-object=%d", label, after, after == value]);
    NSObject *other = [[NSObject alloc] init];
    id elsewhere = ((id (*)(id, SEL))objc_msgSend)(other, getter);
    line([NSString stringWithFormat:@"%@: another object, getter=%@", label, elsewhere]);
    ((void (*)(id, SEL, id))objc_msgSend)(object, setter, nil);
    id cleared = ((id (*)(id, SEL))objc_msgSend)(object, getter);
    line([NSString stringWithFormat:@"%@: after set nil, getter=%@", label, cleared]);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        void *uikit = dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_NOW);
        line([NSString stringWithFormat:@"uikit dlopen=%@", uikit != NULL ? @"ok" : [NSString stringWithUTF8String:dlerror()]]);
        line([NSString stringWithFormat:@"system version=%@", [[NSProcessInfo processInfo] operatingSystemVersionString]]);
        line([NSString stringWithFormat:@"UIAccessibilityCustomAction class=%@", NSClassFromString(@"UIAccessibilityCustomAction") != nil ? @"yes" : @"no"]);

        SEL getter = NSSelectorFromString(@"accessibilityCustomActions");
        SEL setter = NSSelectorFromString(@"setAccessibilityCustomActions:");
        Method getM = class_getInstanceMethod([NSObject class], getter);
        Method setM = class_getInstanceMethod([NSObject class], setter);
        line([NSString stringWithFormat:@"getter on NSObject=%@ image=%@", getM != NULL ? @"yes" : @"no",
              getM != NULL ? image_of(method_getImplementation(getM)) : @"-"]);
        line([NSString stringWithFormat:@"setter on NSObject=%@ image=%@", setM != NULL ? @"yes" : @"no",
              setM != NULL ? image_of(method_getImplementation(setM)) : @"-"]);
        round_trip(@"before frameworks", getter, setter);

        NSObject *kept = [[NSObject alloc] init];
        NSArray *keptValue = @[@"kept-before"];
        if (getM != NULL && setM != NULL) {
            ((void (*)(id, SEL, id))objc_msgSend)(kept, setter, keptValue);
        }

        void *accessibility = dlopen("/System/Library/PrivateFrameworks/UIAccessibility.framework/UIAccessibility", RTLD_LAZY);
        getM = class_getInstanceMethod([NSObject class], getter);
        line([NSString stringWithFormat:@"UIAccessibility.framework dlopen=%@ getter=%@ image=%@",
              accessibility != NULL ? @"ok" : @"no", getM != NULL ? @"yes" : @"no",
              getM != NULL ? image_of(method_getImplementation(getM)) : @"-"]);
        if (getM != NULL) {
            id keptNow = ((id (*)(id, SEL))objc_msgSend)(kept, getter);
            line([NSString stringWithFormat:@"stored before the dlopen, read straight after it=%@ same-object=%d", keptNow, keptNow == keptValue]);
        }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
        if (getM != NULL) {
            id keptLater = ((id (*)(id, SEL))objc_msgSend)(kept, getter);
            line([NSString stringWithFormat:@"stored before the dlopen, read after the main queue turns=%@ same-object=%d", keptLater, keptLater == keptValue]);
        }
        getM = class_getInstanceMethod([NSObject class], getter);
        line([NSString stringWithFormat:@"after the main queue turns: getter image=%@",
              getM != NULL ? image_of(method_getImplementation(getM)) : @"-"]);
        round_trip(@"after UIAccessibility dlopen", getter, setter);

        NSArray *roots = @[@"/System/Library/Frameworks", @"/System/Library/PrivateFrameworks"];
        for (NSString *root in roots) {
            NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL];
            for (NSString *name in names) {
                if (![name hasSuffix:@".framework"]) continue;
                NSString *lower = [name lowercaseString];
                if ([lower rangeOfString:@"access"].location == NSNotFound && [lower rangeOfString:@"ax"].location == NSNotFound
                    && [lower rangeOfString:@"voice"].location == NSNotFound && [lower rangeOfString:@"uikit"].location == NSNotFound
                    && [lower rangeOfString:@"speech"].location == NSNotFound) continue;
                NSString *base = [name stringByDeletingPathExtension];
                NSString *path = [[root stringByAppendingPathComponent:name] stringByAppendingPathComponent:base];
                void *handle = dlopen([path UTF8String], RTLD_LAZY);
                Method found = class_getInstanceMethod([NSObject class], getter);
                line([NSString stringWithFormat:@"framework %@ loaded=%@ getter-after=%@ image=%@", name,
                      handle != NULL ? @"yes" : @"no", found != NULL ? @"yes" : @"no",
                      found != NULL ? image_of(method_getImplementation(found)) : @"-"]);
            }
        }

        getM = class_getInstanceMethod([NSObject class], getter);
        setM = class_getInstanceMethod([NSObject class], setter);
        line([NSString stringWithFormat:@"after frameworks: getter=%@ image=%@ setter=%@", getM != NULL ? @"yes" : @"no",
              getM != NULL ? image_of(method_getImplementation(getM)) : @"-", setM != NULL ? @"yes" : @"no"]);
        NSObject *object = [[NSObject alloc] init];
        line([NSString stringWithFormat:@"respondsToSelector getter=%d setter=%d",
              [object respondsToSelector:getter], [object respondsToSelector:setter]]);
        round_trip(@"after frameworks", getter, setter);
        line(@"done");
    }
    return 0;
}
