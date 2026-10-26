#import <UIKit/UIKit.h>
#include <stdio.h>

extern CGImageRef UIGetScreenImage(void);

int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "usage: revenant-shot PATH\n");
        return 2;
    }
    @autoreleasepool {
        CGImageRef image = UIGetScreenImage();
        if (!image) {
            fprintf(stderr, "revenant-shot: UIGetScreenImage returned no image\n");
            return 1;
        }
        UIImage *picture = [UIImage imageWithCGImage:image];
        CGImageRelease(image);
        NSData *png = UIImagePNGRepresentation(picture);
        if (!png) {
            fprintf(stderr, "revenant-shot: the screen did not encode as PNG\n");
            return 1;
        }
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        if (![png writeToFile:path atomically:YES]) {
            fprintf(stderr, "revenant-shot: cannot write %s\n", argv[1]);
            return 1;
        }
        printf("revenant-shot: wrote %s (%lu bytes)\n", argv[1], (unsigned long)[png length]);
    }
    return 0;
}
