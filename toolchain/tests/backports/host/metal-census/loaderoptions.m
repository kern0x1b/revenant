#import <Foundation/Foundation.h>

extern NSString *const MTKTextureLoaderOptionSRGB;
extern NSString *const MTKTextureLoaderOptionAllocateMipmaps;
extern NSString *const MTKTextureLoaderOptionGenerateMipmaps;
extern NSString *const MTKTextureLoaderOptionTextureUsage;
extern NSString *const MTKTextureLoaderOptionTextureCPUCacheMode;
extern NSString *const MTKTextureLoaderOptionTextureStorageMode;
extern NSString *const MTKTextureLoaderOptionCubeLayout;
extern NSString *const MTKTextureLoaderOptionOrigin;

extern NSString *const appleLoadAsArrayKey __asm__("_MTKTextureLoaderOptionLoadAsArray");

extern NSString *const revenantHost_MTKTextureLoaderOptionLoadAsArray;

#include <dlfcn.h>

static int failures;
static int checks;

static void same(NSString *port, NSString *host, NSString *name)
{
    checks++;
    NSString *left = port ?: @"(nil)", *right = host ?: @"(nil)";
    if ([left isEqualToString:right])
        printf("  ok   %s: the port and Apple's own framework both say %s\n",
               [name UTF8String], [left UTF8String]);
    else {
        printf("  FAIL %s: the port says %s and Apple's own framework says %s\n",
               [name UTF8String], [left UTF8String], [right UTF8String]);
        failures++;
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("MTKTextureLoaderOptionLoadAsArray, the port's object against Apple's framework\n");
        checks++;
        if (dlsym(RTLD_DEFAULT, "ZZZNoSuchNameRevenantR16") == NULL)
            printf("  ok   the control: ZZZNoSuchNameRevenantR16 is not a symbol of anything loaded\n");
        else {
            printf("  FAIL the control: ZZZNoSuchNameRevenantR16 was found, so this harness's answers mean nothing\n");
            failures++;
        }

        same(revenantHost_MTKTextureLoaderOptionLoadAsArray, appleLoadAsArrayKey,
             @"MTKTextureLoaderOptionLoadAsArray");

        printf("the sibling keys, read out of Apple's own framework, so the port's spelling has an oracle\n");
        struct { const char *name; NSString *value; } rows[] = {
            { "MTKTextureLoaderOptionSRGB",                MTKTextureLoaderOptionSRGB },
            { "MTKTextureLoaderOptionAllocateMipmaps",     MTKTextureLoaderOptionAllocateMipmaps },
            { "MTKTextureLoaderOptionGenerateMipmaps",     MTKTextureLoaderOptionGenerateMipmaps },
            { "MTKTextureLoaderOptionTextureUsage",        MTKTextureLoaderOptionTextureUsage },
            { "MTKTextureLoaderOptionTextureCPUCacheMode", MTKTextureLoaderOptionTextureCPUCacheMode },
            { "MTKTextureLoaderOptionTextureStorageMode",  MTKTextureLoaderOptionTextureStorageMode },
            { "MTKTextureLoaderOptionCubeLayout",          MTKTextureLoaderOptionCubeLayout },
            { "MTKTextureLoaderOptionOrigin",              MTKTextureLoaderOptionOrigin },
        };
        for (unsigned i = 0; i < sizeof(rows)/sizeof(*rows); i++) {
            checks++;
            if (rows[i].value && [rows[i].value isEqualToString:@(rows[i].name)])
                printf("  ok   %s -> %s\n", rows[i].name, [rows[i].value UTF8String]);
            else {
                printf("  FAIL %s -> %s\n", rows[i].name,
                       rows[i].value ? [rows[i].value UTF8String] : "(nil)");
                failures++;
            }
        }
    }
    printf("loaderoptions: %d check(s), %d failure(s)\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
