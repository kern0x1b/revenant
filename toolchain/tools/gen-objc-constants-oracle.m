#import <Foundation/Foundation.h>
#include <dlfcn.h>

static NSString *escaped(NSString *s) {
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '\\') [out appendString:@"\\\\"];
        else if (c == '"') [out appendString:@"\\\""];
        else if (c == '\t') [out appendString:@"\\t"];
        else if (c == '\n') [out appendString:@"\\n"];
        else if (c >= 0x20 && c < 0x7f) [out appendFormat:@"%C", c];
        else [out appendFormat:@"\\u%04X", c];
    }
    return out;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { fprintf(stderr, "usage: oracle <framework binary> <name>...\n"); return 2; }
        void *handle = dlopen(argv[1], RTLD_LAZY);
        if (!handle) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
        for (int i = 2; i < argc; i++) {
            NSString *name = [NSString stringWithUTF8String:argv[i]];
            if (name.length == 0) continue;
            void *sym = dlsym(handle, name.UTF8String);
            if (!sym) { printf("%s\tmissing\t-\t-\n", name.UTF8String); continue; }
            id value = *(__unsafe_unretained id *)sym;
            if (![value isKindOfClass:[NSString class]]) {
                printf("%s\tnot-object\t%s\t-\n", name.UTF8String, value ? object_getClassName(value) : "nil");
                continue;
            }
            printf("%s\tfound\t%s\t%s\n", name.UTF8String, object_getClassName(value), escaped(value).UTF8String);
        }
        dlclose(handle);
    }
    return 0;
}
