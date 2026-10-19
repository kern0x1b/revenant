/* loaderoptions.m - the value of every MetalKit texture-loader option key, side by side: Apple's own
 * framework and the port's object.
 *
 * TWO COPIES OF EACH NAME ARE IN THIS BINARY and that is the point. The port's
 * MTKTextureLoaderOptionLoadAsArray17.m is compiled with `-DMTKTextureLoaderOptionLoadAsArray=
 * charonHost_MTKTextureLoaderOptionLoadAsArray`, so the framework keeps Apple's name and the port
 * keeps its own, and the two can be asked apart and compared. A harness that could not tell them
 * apart would be reading Apple's framework and calling it the port's answer.
 *
 * Apple's copy is reached through an asm label rather than through the identifier, because the -D
 * rewrites the identifier itself: `appleLoadAsArrayKey` is a declaration of Apple's symbol
 * `_MTKTextureLoaderOptionLoadAsArray` under another C name, and the port's is the real
 * `_charonHost_...`. dlsym was the first spelling of this and it read the ADDRESS OF THE VARIABLE as
 * an object pointer - a Bus error on the first comparison, which is why the label is here.
 *
 * NO DEVICE IS CREATED and none is needed: these are strings, and a key is compared to a key.
 */
#import <Foundation/Foundation.h>

/* Apple's own, from the framework this binary links. */
extern NSString *const MTKTextureLoaderOptionSRGB;
extern NSString *const MTKTextureLoaderOptionAllocateMipmaps;
extern NSString *const MTKTextureLoaderOptionGenerateMipmaps;
extern NSString *const MTKTextureLoaderOptionTextureUsage;
extern NSString *const MTKTextureLoaderOptionTextureCPUCacheMode;
extern NSString *const MTKTextureLoaderOptionTextureStorageMode;
extern NSString *const MTKTextureLoaderOptionCubeLayout;
extern NSString *const MTKTextureLoaderOptionOrigin;

/* Apple's MTKTextureLoaderOptionLoadAsArray, under a name the -D does not touch. */
extern NSString *const appleLoadAsArrayKey __asm__("_MTKTextureLoaderOptionLoadAsArray");

/* The port's, under the name the -D gave it. */
extern NSString *const charonHost_MTKTextureLoaderOptionLoadAsArray;

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
        /* THE CONTROL: a name neither framework has must read as no symbol, or a comparison that
         * answered "the same" for two nils would be a pass with nothing in it. */
        checks++;
        if (dlsym(RTLD_DEFAULT, "ZZZNoSuchNameCharonR16") == NULL)
            printf("  ok   the control: ZZZNoSuchNameCharonR16 is not a symbol of anything loaded\n");
        else {
            printf("  FAIL the control: ZZZNoSuchNameCharonR16 was found, so this harness's answers mean nothing\n");
            failures++;
        }

        same(charonHost_MTKTextureLoaderOptionLoadAsArray, appleLoadAsArrayKey,
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
            /* Each of these is its own name, and that is Apple's own value, measured here rather than
             * assumed: the harness prints what the framework says and fails if a key reads nil, which
             * is what a wrong spelling would look like from this side. */
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