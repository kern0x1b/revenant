#import <Foundation/Foundation.h>
#import <ZXingObjC/ZXingObjC.h>

int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        ZXMultiFormatReader *reader = [ZXMultiFormatReader reader];
        return reader != nil && argc > 0 ? 0 : 1;
    }
}
