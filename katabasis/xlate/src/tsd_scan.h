#pragma once

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
    {0x358, "Swift __PTK_FRAMEWORK_SWIFT_KEY7 (slot 107 * 8), tsd_private.h"},
};

bool ScanTSDOffsets(const Image &image, std::vector<std::string> &violations);

}
