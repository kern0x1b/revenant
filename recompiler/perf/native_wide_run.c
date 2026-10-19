#include <stdint.h>

uint64_t kw_crc32(uint8_t *, uint64_t);
uint64_t kw_sha256(uint8_t *, uint64_t);
uint64_t kw_fnv64(uint8_t *, uint64_t);
uint64_t kw_sort(uint8_t *, uint64_t);
uint64_t kw_list(uint8_t *, uint64_t);
uint64_t kw_geometry(uint8_t *, uint64_t);
uint64_t kw_matrix(uint8_t *, uint64_t);
uint64_t kw_text(uint8_t *, uint64_t);

uint64_t native_wide_run(unsigned which, uint8_t *arena, uint32_t size)
{
    switch (which) {
    case 0: return kw_crc32(arena, size);
    case 1: return kw_sha256(arena, size);
    case 2: return kw_fnv64(arena, size);
    case 3: return kw_sort(arena, size);
    case 4: return kw_list(arena, size);
    case 5: return kw_geometry(arena, size);
    case 6: return kw_matrix(arena, size);
    case 7: return kw_text(arena, size);
    }
    return 0;
}
