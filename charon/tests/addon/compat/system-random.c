#include <stdio.h>
#include <stdint.h>
#include <string.h>

void charon_arc4random_buf(void *, size_t);
void arc4random_buf(void *, size_t);

uint32_t arc4random(void)
{
    return 0x5c5c5c5c;
}

int main(void)
{
    unsigned char bytes[32];
    memset(bytes, 0xaa, sizeof bytes);
    charon_arc4random_buf(bytes, sizeof bytes);
    int ours = 1;
    for (size_t at = 0; at < sizeof bytes; at++) {
        if (bytes[at] != 0x5c)
            ours = 0;
    }
    if (ours) {
        printf("FAIL  arc4random_buf must use the system's where the release has it, not its own stream\n");
        return 1;
    }
    return 0;
}
