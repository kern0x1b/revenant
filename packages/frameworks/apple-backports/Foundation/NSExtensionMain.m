#import <Foundation/Foundation.h>

extern int NSExtensionMain(int argc, char *argv[]);

int NSExtensionMain(int argc, char *argv[])
{
    fprintf(stderr, "%s: an app extension needs a host, and this release has none\n", argc > 0 ? argv[0] : "NSExtensionMain");
    return 69;
}
