#import <Foundation/Foundation.h>
#import "RevenantCKWebAuth.h"

static NSData *HexData(NSString *hex, NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger index = 0; index < length; index++) {
        const char *at = [hex UTF8String] + index * 2;
        unsigned value = 0;
        for (int digit = 0; digit < 2; digit++) {
            char c = at[digit];
            value = value * 16 + (unsigned)(c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10);
        }
        bytes[index] = (uint8_t)value;
    }
    return data;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 4) {
            fprintf(stderr, "usage: tool <sign|verify|low-s> <scalar-hex> <public-hex> <file> [count]\n");
            return 2;
        }
        NSString *mode = @(argv[1]);
        NSData *scalar = HexData(@(argv[2]), 32);
        NSData *publicKey = HexData(@(argv[3]), 65);
        NSData *message = [NSData dataWithContentsOfFile:@(argv[4])] ?: [NSData data];

        if ([mode isEqualToString:@"sign"]) {
            uint8_t der[80];
            int length = RevenantCKSignES256(scalar.bytes, message.bytes, message.length, der, sizeof der);
            if (length <= 0) { fprintf(stderr, "FAIL: no signature\n"); return 1; }
            [[NSData dataWithBytes:der length:(NSUInteger)length] writeToFile:@(argv[5]) atomically:YES];
            printf("signed %d bytes of a message of %lu\n", length, (unsigned long)message.length);
            return 0;
        }
        if ([mode isEqualToString:@"verify"]) {
            NSData *der = [NSData dataWithContentsOfFile:@(argv[5])];
            int ok = RevenantCKVerifyES256(publicKey.bytes, publicKey.length, message.bytes, message.length,
                                         der.bytes, der.length);
            printf("verify %d\n", ok);
            return ok ? 0 : 1;
        }
        if ([mode isEqualToString:@"low-s"]) {
            NSUInteger count = argc > 5 ? (NSUInteger)atoi(argv[5]) : 5000;
            const uint8_t *order = RevenantCKGroupOrder();
            const uint8_t *half = RevenantCKGroupOrderHalf();
            NSUInteger low = 0, high = 0, selfVerifyFailed = 0;
            for (NSUInteger index = 0; index < count; index++) {
                NSMutableData *body = [NSMutableData dataWithLength:index % 900 + 1];
                uint8_t *bytes = body.mutableBytes;
                for (NSUInteger at = 0; at < body.length; at++) {
                    bytes[at] = (uint8_t)((index * 7 + at * 31) & 0xff);
                }
                uint8_t der[80];
                int length = RevenantCKSignES256(scalar.bytes, body.bytes, body.length, der, sizeof der);
                if (length <= 0) { selfVerifyFailed++; continue; }
                const uint8_t *s = RevenantCKDERSignatureS(der, (size_t)length);
                if (!s) { selfVerifyFailed++; continue; }
                if (memcmp(s, half, 32) <= 0) { low++; } else { high++; }
                if (!RevenantCKVerifyES256(publicKey.bytes, publicKey.length, body.bytes, body.length,
                                         der, (size_t)length)) {
                    selfVerifyFailed++;
                }
            }
            printf("low-s: low=%lu high=%lu self-verify failures=%lu of %lu\n",
                   (unsigned long)low, (unsigned long)high, (unsigned long)selfVerifyFailed, (unsigned long)count);
            return (high == 0 && selfVerifyFailed == 0) ? 0 : 1;
        }
        fprintf(stderr, "unknown mode %s\n", mode.UTF8String);
        return 2;
    }
}
