#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <stdio.h>
#include <string.h>

@@DECLS@@

static void *g_handle;
static int g_failures;

static void charonCompareString(NSString *name, NSString *port, NSString *const *apple,
                                const char *oracle, const char *cacheValue) {
  const char *p = port ? [port UTF8String] : NULL;
  const char *a;
  if (oracle && strcmp(oracle, "cache") == 0) {
    a = cacheValue;
    if (!a) { printf("NO-ORACLE\t%s\tnothing compared this name\n", [name UTF8String]); g_failures++; return; }
  } else {
    if (!apple) { printf("MISSING\t%s\tApple's own MediaPlayer has no such symbol\n", [name UTF8String]); g_failures++; return; }
    a = *apple ? [*apple UTF8String] : NULL;
    if (!a) { printf("NULL\t%s\tthe port defines it as NULL\n", [name UTF8String]); g_failures++; return; }
  }
  if (!p) { printf("PORT-NULL\t%s\tthe port defines it as NULL\n", [name UTF8String]); g_failures++; return; }
  if (strcmp(p, a) != 0) {
    printf("DIFFERS\t%s\tthe port has %s and Apple's has %s\n", [name UTF8String], p, a);
    g_failures++;
    return;
  }
  printf("OK\t%s\t%s\toracle=%s\t", [name UTF8String], p, oracle ? oracle : "host");
  for (const unsigned char *b = (const unsigned char *)p; *b; b++) printf("%02x", *b);
  printf("\n");
}

@@CHECKS@@

int main(void) {
  @autoreleasepool {
    g_handle = dlopen("/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer", RTLD_LAZY);
    if (!g_handle) { printf("NO-FRAMEWORK\t%s\n", dlerror()); return 2; }
@@CALLS@@
    charonCompareString(@"MPNoSuchConstantForTheControl", nil,
                         (NSString *const *)dlsym(g_handle, "MPNoSuchConstantForTheControl"), "host", NULL);
    printf("failures\t%d\n", g_failures);
  }
  return g_failures ? 1 : 0;
}
