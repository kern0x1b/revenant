// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Format disk-hit artifact fingerprints for JIT diagnostics.

#include "foundation/jit_artifact.hpp"
#include <sstream>

namespace shade {

[[nodiscard]] std::string disk_hit_fingerprint_text(
    const JitArtifactStoreStats& stats)
{
    std::ostringstream text;
    text << std::hex;
    for (std::size_t index = 0; index < stats.disk_hit_key_fingerprint_count &&
                                index < stats.disk_hit_key_fingerprints.size();
        ++index) {
        if (index != 0U)
            text << ',';
        text << stats.disk_hit_key_fingerprints[index];
    }
    return text.str();
}
} // namespace shade
