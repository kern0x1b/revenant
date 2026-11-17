#pragma once

#include "../../include/xl_tsd_offset.h"
#include "macho.h"

#include <cstdint>
#include <string>
#include <vector>

namespace xlate {

struct AllowedTSDOffset {
  uint64_t offset;
  const char *why;
};
inline constexpr AllowedTSDOffset kAllowedTSDOffsets[] = {
    {XL_TSD_AUDITED_OFFSET, "Swift __PTK_FRAMEWORK_SWIFT_KEY7 (slot 107 * 8), tsd_private.h"},
};

bool ScanTSDOffsets(const Image &image, std::vector<std::string> &violations);

}
