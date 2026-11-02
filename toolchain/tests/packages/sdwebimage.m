#import <Foundation/Foundation.h>
#import <SDWebImage/SDWebImage.h>

int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        const unsigned char png[] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
        NSData *data = [NSData dataWithBytes:png length:sizeof(png)];
        return [NSData sd_imageFormatForImageData:data] == SDImageFormatPNG && argc > 0 ? 0 : 1;
    }
}
