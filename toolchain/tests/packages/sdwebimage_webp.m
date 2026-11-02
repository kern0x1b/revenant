#import <Foundation/Foundation.h>
#import <SDWebImageWebPCoder/SDImageWebPCoder.h>

int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        SDImageWebPCoder *coder = [SDImageWebPCoder sharedCoder];
        const unsigned char riff[] = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'E', 'B', 'P'};
        NSData *data = [NSData dataWithBytes:riff length:sizeof(riff)];
        return [coder canDecodeFromData:data] && argc > 0 ? 0 : 1;
    }
}
