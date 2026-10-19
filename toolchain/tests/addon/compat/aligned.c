
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void *revenant_aligned_alloc(size_t alignment, size_t size);

static int fails;

static void expect(int holds, const char *what)
{
    if (!holds) {
        printf("FAIL  %s\n", what);
        fails++;
    }
}

int main(void)
{
    for (size_t alignment = 1; alignment <= 4096; alignment <<= 1) {
        void *memory = revenant_aligned_alloc(alignment, alignment * 3);
        expect(memory != NULL, "a power-of-two alignment with a multiple size is allocated");
        expect(((uintptr_t)memory % alignment) == 0, "the memory is aligned as asked");
        free(memory);
    }
    errno = 0;
    expect(revenant_aligned_alloc(24, 48) == NULL && errno == EINVAL, "an alignment that is not a power of two is refused");
    errno = 0;
    expect(revenant_aligned_alloc(16, 17) == NULL && errno == EINVAL, "a size that is not a multiple is refused");
    errno = 0;
    expect(revenant_aligned_alloc(0, 16) == NULL && errno == EINVAL, "a zero alignment is refused");
    size_t rounded = (1 + 128 - 1) & ~(size_t)(128 - 1);
    void *memory = revenant_aligned_alloc(128, rounded);
    expect(memory != NULL && ((uintptr_t)memory % 128) == 0, "operator new(1, align_val_t(128)) as libc++ rounds it");
    free(memory);
    return fails != 0;
}
