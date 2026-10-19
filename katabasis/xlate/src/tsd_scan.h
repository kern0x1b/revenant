#pragma once

#include "macho.h"

#include <cstdint>
#include <string>
#include <vector>

namespace xlate {

// Every byte offset off TPIDRRO_EL0 (Darwin's per-thread direct-TSD base pointer, see
// runtime/runtime.c and coordination/crutches.md "TPIDRRO_EL0 backed by a mostly-zero block")
// this band has actually measured a guest image reading, with where that offset comes from.
// ScanTSDOffsets fails any access at an offset not listed here: growing this list is the ONLY
// sanctioned way to make a new offset pass, and doing so means citing a real Darwin TSD slot
// (apple-oss-distributions/libpthread's private/pthread/tsd_private.h), not just "the demo needs
// it" -- the same bar the 0x358 entry was held to (slot 107, __PTK_FRAMEWORK_SWIFT_KEY7).
struct AllowedTSDOffset {
  uint64_t offset;
  const char *why;
};
inline constexpr AllowedTSDOffset kAllowedTSDOffsets[] = {
    {0x358, "Swift __PTK_FRAMEWORK_SWIFT_KEY7 (slot 107 * 8), tsd_private.h"},
};

// Scans every executable section of `image` for `mrs Xt, TPIDRRO_EL0` (system register encoding
// 0xde83, farmdec's A64_MRS with a64.imm == 0xde83 -- see deps/patches/rellume-tpidrro-el0.patch)
// and every subsequent load or store this scanner can prove reads or writes through the register
// it lands in, at a fixed immediate offset. Appends one human-readable line per problem to
// `violations`: an access at an offset outside kAllowedTSDOffsets, or a use of a
// TPIDRRO_EL0-derived register in a shape this scanner does not itself model (so it cannot
// certify the offset touched, if any) -- register-indexed addressing, a spill to another
// register or to memory, arithmetic, and so on. Each line names the image, the enclosing
// function (by its exported symbol if one covers the address, else "sub_<hex address>", matching
// how xlate itself names lifted functions with no export), the instruction's address, and either
// the offending offset or the reason this scanner gave up. Returns true iff `violations` stayed
// empty; a caller (xlate's main()) is expected to treat a false return as a build failure.
bool ScanTSDOffsets(const Image &image, std::vector<std::string> &violations);

}  // namespace xlate
