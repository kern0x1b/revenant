#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
/* The HOST's inventory of one framework, by CLASS-NAME PREFIX. One probe for every framework, so a new
   one needs a spec and no new program.

   The argument is the PREFIX and not the framework name, because the two differ: the framework is
   FileProvider and its classes are NSFileProvider*. An earlier version matched on the framework name, found
   nothing, and its caller reported 10358 classes - every class on the host - and called it green. So:

     - a prefix that matches nothing exits 3, never 0;
     - the totals are printed, and the caller compares the class count with what the spec expects;
     - the framework is LINKED by the caller, or its classes are never loaded and the answer is missing
       rather than wrong, which is the same failure in the other direction.
*/
int main(int argc, char **argv){
  @autoreleasepool{
    if (argc < 2) { fprintf(stderr, "usage: inventory CLASSPREFIX [FRAMEWORKNAME]\n"); return 64; }
    const char *prefix = argv[1];
    const char *name = argc > 2 ? argv[2] : prefix;
    size_t plen = strlen(prefix);
    unsigned nc = objc_getClassList(NULL, 0);
    Class *all = (Class *)calloc(nc ? nc : 1, sizeof(Class));
    objc_getClassList(all, nc);
    unsigned classes = 0;
    for (unsigned i = 0; i < nc; i++) {
      const char *n = class_getName(all[i]);
      if (n && strncmp(n, prefix, plen) == 0) {
        unsigned m = 0; Method *ms = class_copyMethodList(all[i], &m);
        printf("class\t%s\t%u\n", n, m);
        classes++; if (ms) free(ms);
      }
    }
    free(all);
    unsigned npr = 0; Protocol *__unsafe_unretained *ps = objc_copyProtocolList(&npr);
    unsigned protocols = 0;
    for (unsigned i = 0; i < npr; i++) {
      const char *n = protocol_getName(ps[i]);
      if (n && strncmp(n, prefix, plen) == 0) {
        unsigned m = 0;
        struct objc_method_description *d = protocol_copyMethodDescriptionList(ps[i], NULL, NO, &m);
        printf("protocol\t%s\t%u\n", n, m);
        protocols++; if (d) free(d);
      }
    }
    if (ps) free(ps);
    printf("TOTALS\t%s\tclasses=%u\tprotocols=%u\n", name, classes, protocols);
    return (classes || protocols) ? 0 : 3;
  }
}
