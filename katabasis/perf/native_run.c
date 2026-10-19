#include <stdint.h>

uint64_t k_crc32(uint8_t *, uint64_t);
uint64_t k_sha256(uint8_t *, uint64_t);
uint64_t k_fnv64(uint8_t *, uint64_t);
uint64_t k_sort(uint8_t *, uint64_t);
uint64_t k_list(uint8_t *, uint64_t);
uint64_t k_geometry(uint8_t *, uint64_t);
uint64_t k_matrix(uint8_t *, uint64_t);
uint64_t k_text(uint8_t *, uint64_t);

uint64_t native_run(unsigned which, uint8_t *arena, uint32_t size)
{
    switch (which) {
    case 0: return k_crc32(arena, size);
    case 1: return k_sha256(arena, size);
    case 2: return k_fnv64(arena, size);
    case 3: return k_sort(arena, size);
    case 4: return k_list(arena, size);
    case 5: return k_geometry(arena, size);
    case 6: return k_matrix(arena, size);
    case 7: return k_text(arena, size);
    }
    return 0;
}
