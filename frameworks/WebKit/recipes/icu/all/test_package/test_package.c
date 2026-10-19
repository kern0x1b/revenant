#include <unicode/ubrk.h>
#include <unicode/unorm2.h>
#include <unicode/ustring.h>

int main(void)
{
    static const UChar family[] = { 0xD83D, 0xDC68, 0x200D, 0xD83D, 0xDC69, 0x200D, 0xD83D, 0xDC67, 0 };
    UErrorCode status = U_ZERO_ERROR;
    UBreakIterator *characters = ubrk_open(UBRK_CHARACTER, "en", family, -1, &status);
    if (U_FAILURE(status))
        return 1;
    int graphemes = 0;
    for (int32_t at = ubrk_first(characters); ubrk_next(characters) != UBRK_DONE; )
        ++graphemes;
    ubrk_close(characters);

    static const UChar decomposed[] = { 'e', 0x0301, 0 };
    UChar composed[4];
    const UNormalizer2 *nfc = unorm2_getNFCInstance(&status);
    int32_t length = U_SUCCESS(status) ? unorm2_normalize(nfc, decomposed, -1, composed, 4, &status) : 0;
    return graphemes == 1 && U_SUCCESS(status) && length == 1 && composed[0] == 0x00E9 ? 0 : 1;
}
