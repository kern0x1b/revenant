// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Persist virtual-device class keys and wrap or unwrap guest key
// material.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <memory>
#include <optional>
#include <span>
#include <vector>

namespace shade {

// Symmetric class keys for the virtual device's no-passcode system bag.
// The persistent secret belongs to device state, outside the guest filesystem
// and disposable translation caches. Wrapped keys remain firmware-owned data.
class KeyStore {
public:
    [[nodiscard]] static std::shared_ptr<KeyStore> open(
        const std::filesystem::path& state_file);
    ~KeyStore();
    KeyStore(const KeyStore&) = delete;
    KeyStore& operator=(const KeyStore&) = delete;

    [[nodiscard]] std::optional<std::vector<std::byte>> wrap(
        std::uint32_t key_class, std::span<const std::byte> key) const;
    [[nodiscard]] std::optional<std::vector<std::byte>> unwrap(
        std::uint32_t key_class, std::span<const std::byte> wrapped) const;

private:
    explicit KeyStore(std::span<const std::byte, 32> secret);
    [[nodiscard]] std::optional<std::vector<std::byte>> transform(
        std::uint32_t key_class, std::span<const std::byte> input,
        bool wrapping) const;
    std::array<std::byte, 32> secret_;
};

} // namespace shade
