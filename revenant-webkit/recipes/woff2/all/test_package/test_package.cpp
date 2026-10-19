#include <woff2/decode.h>

#include <cstdint>

int main()
{
    static const uint8_t notAFont[] = { 'w', 'O', 'F', '2', 0, 1, 0, 0 };
    return woff2::ComputeWOFF2FinalSize(notAFont, sizeof(notAFont)) == 0 ? 0 : 1;
}
