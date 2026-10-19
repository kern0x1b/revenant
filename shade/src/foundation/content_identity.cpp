// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Calculate and represent content hashes used to identify executable
// generations.

#include "foundation/content_identity.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <fstream>
#include <limits>

#if defined(__x86_64__) || defined(__i386__)
#include <immintrin.h>
#endif

#include <unistd.h>

namespace shade {
namespace {

    constexpr std::array<std::uint32_t, 64> round_constants {
        0x428a2f98U,
        0x71374491U,
        0xb5c0fbcfU,
        0xe9b5dba5U,
        0x3956c25bU,
        0x59f111f1U,
        0x923f82a4U,
        0xab1c5ed5U,
        0xd807aa98U,
        0x12835b01U,
        0x243185beU,
        0x550c7dc3U,
        0x72be5d74U,
        0x80deb1feU,
        0x9bdc06a7U,
        0xc19bf174U,
        0xe49b69c1U,
        0xefbe4786U,
        0x0fc19dc6U,
        0x240ca1ccU,
        0x2de92c6fU,
        0x4a7484aaU,
        0x5cb0a9dcU,
        0x76f988daU,
        0x983e5152U,
        0xa831c66dU,
        0xb00327c8U,
        0xbf597fc7U,
        0xc6e00bf3U,
        0xd5a79147U,
        0x06ca6351U,
        0x14292967U,
        0x27b70a85U,
        0x2e1b2138U,
        0x4d2c6dfcU,
        0x53380d13U,
        0x650a7354U,
        0x766a0abbU,
        0x81c2c92eU,
        0x92722c85U,
        0xa2bfe8a1U,
        0xa81a664bU,
        0xc24b8b70U,
        0xc76c51a3U,
        0xd192e819U,
        0xd6990624U,
        0xf40e3585U,
        0x106aa070U,
        0x19a4c116U,
        0x1e376c08U,
        0x2748774cU,
        0x34b0bcb5U,
        0x391c0cb3U,
        0x4ed8aa4aU,
        0x5b9cca4fU,
        0x682e6ff3U,
        0x748f82eeU,
        0x78a5636fU,
        0x84c87814U,
        0x8cc70208U,
        0x90befffaU,
        0xa4506cebU,
        0xbef9a3f7U,
        0xc67178f2U,
    };

    constexpr std::uint32_t rotate_right(
        std::uint32_t value, std::uint32_t amount) noexcept
    {
        return (value >> amount) | (value << (32U - amount));
    }

    constexpr std::uint32_t big_endian_word(const std::byte* bytes) noexcept
    {
        return (std::to_integer<std::uint32_t>(bytes[0]) << 24U) |
               (std::to_integer<std::uint32_t>(bytes[1]) << 16U) |
               (std::to_integer<std::uint32_t>(bytes[2]) << 8U) |
               std::to_integer<std::uint32_t>(bytes[3]);
    }

    void sha256_transform_scalar(
        std::uint32_t state[8], const std::byte input[64])
    {
        std::array<std::uint32_t, 64> schedule { };
        for (std::size_t index = 0; index < 16U; ++index) {
            schedule[index] = big_endian_word(
                input + static_cast<std::ptrdiff_t>(index * 4U));
        }
        for (std::size_t index = 16U; index < schedule.size(); ++index) {
            const auto first = schedule[index - 15U];
            const auto second = schedule[index - 2U];
            const auto sigma0 = rotate_right(first, 7U) ^
                                rotate_right(first, 18U) ^ (first >> 3U);
            const auto sigma1 = rotate_right(second, 17U) ^
                                rotate_right(second, 19U) ^ (second >> 10U);
            schedule[index] =
                schedule[index - 16U] + sigma0 + schedule[index - 7U] + sigma1;
        }

        std::array<std::uint32_t, 8> working { };
        std::copy_n(state, working.size(), working.begin());
        for (std::size_t index = 0; index < schedule.size(); ++index) {
            const auto& a = working[0];
            const auto& b = working[1];
            const auto& c = working[2];
            const auto& d = working[3];
            const auto& e = working[4];
            const auto& f = working[5];
            const auto& g = working[6];
            const auto& h = working[7];
            const auto sigma1 = rotate_right(e, 6U) ^ rotate_right(e, 11U) ^
                                rotate_right(e, 25U);
            const auto choose = (e & f) ^ ((~e) & g);
            const auto temporary1 =
                h + sigma1 + choose + round_constants[index] + schedule[index];
            const auto sigma0 = rotate_right(a, 2U) ^ rotate_right(a, 13U) ^
                                rotate_right(a, 22U);
            const auto majority = (a & b) ^ (a & c) ^ (b & c);
            const auto temporary2 = sigma0 + majority;
            working[7] = g;
            working[6] = f;
            working[5] = e;
            working[4] = d + temporary1;
            working[3] = c;
            working[2] = b;
            working[1] = a;
            working[0] = temporary1 + temporary2;
        }
        for (std::size_t index = 0; index < 8U; ++index) {
            state[index] += working[index];
        }
    }

#if (defined(__x86_64__) || defined(__i386__)) &&                              \
    (defined(__GNUC__) || defined(__clang__))

    __attribute__((target("sha,ssse3,sse4.1"))) void sha256_transform_sha_ni(
        std::uint32_t state[8], const std::byte input[64])
    {
        __m128i state0, state1;
        __m128i msg, tmp;
        __m128i msg0, msg1, msg2, msg3;
        __m128i abef_save, cdgh_save;
        const __m128i mask =
            _mm_set_epi64x(0x0c0d0e0f08090a0bULL, 0x0405060700010203ULL);
        const auto* bytes = reinterpret_cast<const std::uint8_t*>(input);

        tmp = _mm_loadu_si128(reinterpret_cast<const __m128i*>(state));
        state1 = _mm_loadu_si128(reinterpret_cast<const __m128i*>(state + 4));
        tmp = _mm_shuffle_epi32(tmp, 0xb1);
        state1 = _mm_shuffle_epi32(state1, 0x1b);
        state0 = _mm_alignr_epi8(tmp, state1, 8);
        state1 = _mm_blend_epi16(state1, tmp, 0xf0);

        abef_save = state0;
        cdgh_save = state1;

        msg = _mm_loadu_si128(reinterpret_cast<const __m128i*>(bytes + 0));
        msg0 = _mm_shuffle_epi8(msg, mask);
        msg = _mm_add_epi32(
            msg0, _mm_set_epi64x(0xe9b5dba5b5c0fbcFULL, 0x71374491428a2f98ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);

        msg1 = _mm_loadu_si128(reinterpret_cast<const __m128i*>(bytes + 16));
        msg1 = _mm_shuffle_epi8(msg1, mask);
        msg = _mm_add_epi32(
            msg1, _mm_set_epi64x(0xab1c5ed5923f82a4ULL, 0x59f111f13956c25bULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg0 = _mm_sha256msg1_epu32(msg0, msg1);

        msg2 = _mm_loadu_si128(reinterpret_cast<const __m128i*>(bytes + 32));
        msg2 = _mm_shuffle_epi8(msg2, mask);
        msg = _mm_add_epi32(
            msg2, _mm_set_epi64x(0x550c7dc3243185beULL, 0x12835b01d807aa98ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg1 = _mm_sha256msg1_epu32(msg1, msg2);

        msg3 = _mm_loadu_si128(reinterpret_cast<const __m128i*>(bytes + 48));
        msg3 = _mm_shuffle_epi8(msg3, mask);
        msg = _mm_add_epi32(
            msg3, _mm_set_epi64x(0xc19bf1749bdc06a7ULL, 0x80deb1fe72be5d74ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg3, msg2, 4);
        msg0 = _mm_add_epi32(msg0, tmp);
        msg0 = _mm_sha256msg2_epu32(msg0, msg3);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg2 = _mm_sha256msg1_epu32(msg2, msg3);

        msg = _mm_add_epi32(
            msg0, _mm_set_epi64x(0x240ca1cc0fc19dc6ULL, 0xefbe4786e49b69c1ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg0, msg3, 4);
        msg1 = _mm_add_epi32(msg1, tmp);
        msg1 = _mm_sha256msg2_epu32(msg1, msg0);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg3 = _mm_sha256msg1_epu32(msg3, msg0);

        msg = _mm_add_epi32(
            msg1, _mm_set_epi64x(0x76f988da5cb0a9dcULL, 0x4a7484aa2de92c6fULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg1, msg0, 4);
        msg2 = _mm_add_epi32(msg2, tmp);
        msg2 = _mm_sha256msg2_epu32(msg2, msg1);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg0 = _mm_sha256msg1_epu32(msg0, msg1);

        msg = _mm_add_epi32(
            msg2, _mm_set_epi64x(0xbf597fc7b00327c8ULL, 0xa831c66d983e5152ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg2, msg1, 4);
        msg3 = _mm_add_epi32(msg3, tmp);
        msg3 = _mm_sha256msg2_epu32(msg3, msg2);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg1 = _mm_sha256msg1_epu32(msg1, msg2);

        msg = _mm_add_epi32(
            msg3, _mm_set_epi64x(0x1429296706ca6351ULL, 0xd5a79147c6e00bf3ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg3, msg2, 4);
        msg0 = _mm_add_epi32(msg0, tmp);
        msg0 = _mm_sha256msg2_epu32(msg0, msg3);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg2 = _mm_sha256msg1_epu32(msg2, msg3);

        msg = _mm_add_epi32(
            msg0, _mm_set_epi64x(0x53380d134d2c6dfcULL, 0x2e1b213827b70a85ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg0, msg3, 4);
        msg1 = _mm_add_epi32(msg1, tmp);
        msg1 = _mm_sha256msg2_epu32(msg1, msg0);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg3 = _mm_sha256msg1_epu32(msg3, msg0);

        msg = _mm_add_epi32(
            msg1, _mm_set_epi64x(0x92722c8581c2c92eULL, 0x766a0abb650a7354ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg1, msg0, 4);
        msg2 = _mm_add_epi32(msg2, tmp);
        msg2 = _mm_sha256msg2_epu32(msg2, msg1);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg0 = _mm_sha256msg1_epu32(msg0, msg1);

        msg = _mm_add_epi32(
            msg2, _mm_set_epi64x(0xc76c51a3c24b8b70ULL, 0xa81a664ba2bfe8a1ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg2, msg1, 4);
        msg3 = _mm_add_epi32(msg3, tmp);
        msg3 = _mm_sha256msg2_epu32(msg3, msg2);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg1 = _mm_sha256msg1_epu32(msg1, msg2);

        msg = _mm_add_epi32(
            msg3, _mm_set_epi64x(0x106aa070f40e3585ULL, 0xd6990624d192e819ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg3, msg2, 4);
        msg0 = _mm_add_epi32(msg0, tmp);
        msg0 = _mm_sha256msg2_epu32(msg0, msg3);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg2 = _mm_sha256msg1_epu32(msg2, msg3);

        msg = _mm_add_epi32(
            msg0, _mm_set_epi64x(0x34b0bcb52748774cULL, 0x1e376c0819a4c116ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg0, msg3, 4);
        msg1 = _mm_add_epi32(msg1, tmp);
        msg1 = _mm_sha256msg2_epu32(msg1, msg0);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
        msg3 = _mm_sha256msg1_epu32(msg3, msg0);

        msg = _mm_add_epi32(
            msg1, _mm_set_epi64x(0x682e6ff35b9cca4fULL, 0x4ed8aa4a391c0cb3ULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg1, msg0, 4);
        msg2 = _mm_add_epi32(msg2, tmp);
        msg2 = _mm_sha256msg2_epu32(msg2, msg1);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);

        msg = _mm_add_epi32(
            msg2, _mm_set_epi64x(0x8cc7020884c87814ULL, 0x78a5636f748f82eeULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        tmp = _mm_alignr_epi8(msg2, msg1, 4);
        msg3 = _mm_add_epi32(msg3, tmp);
        msg3 = _mm_sha256msg2_epu32(msg3, msg2);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);

        msg = _mm_add_epi32(
            msg3, _mm_set_epi64x(0xc67178f2bef9a3f7ULL, 0xa4506ceb90befffaULL));
        state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
        msg = _mm_shuffle_epi32(msg, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, msg);

        state0 = _mm_add_epi32(state0, abef_save);
        state1 = _mm_add_epi32(state1, cdgh_save);
        tmp = _mm_shuffle_epi32(state0, 0x1b);
        state1 = _mm_shuffle_epi32(state1, 0xb1);
        state0 = _mm_blend_epi16(tmp, state1, 0xf0);
        state1 = _mm_alignr_epi8(state1, tmp, 8);
        _mm_storeu_si128(reinterpret_cast<__m128i*>(state), state0);
        _mm_storeu_si128(reinterpret_cast<__m128i*>(state + 4), state1);
    }

#endif

    class Sha256State {
    public:
        Sha256State()
            : state_ { 0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU,
                0x510e527fU, 0x9b05688cU, 0x1f83d9abU, 0x5be0cd19U }
        {
        }

        void update(std::span<const std::byte> bytes)
        {
            bit_count_ += static_cast<std::uint64_t>(bytes.size()) * 8U;
            while (!bytes.empty()) {
                const auto copied =
                    std::min(bytes.size(), block_.size() - used_);
                std::copy_n(bytes.begin(), copied,
                    block_.begin() + static_cast<std::ptrdiff_t>(used_));
                used_ += copied;
                bytes = bytes.subspan(copied);
                if (used_ == block_.size()) {
                    transform(block_);
                    used_ = 0;
                }
            }
        }

        [[nodiscard]] ContentIdentity finish()
        {
            const auto original_bit_count = bit_count_;
            block_[used_++] = std::byte { 0x80 };
            if (used_ > 56U) {
                std::fill(block_.begin() + static_cast<std::ptrdiff_t>(used_),
                    block_.end(), std::byte { 0 });
                transform(block_);
                used_ = 0;
            }
            std::fill(block_.begin() + static_cast<std::ptrdiff_t>(used_),
                block_.begin() + 56, std::byte { 0 });
            for (std::size_t index = 0; index < sizeof(original_bit_count);
                ++index) {
                block_[63U - index] = static_cast<std::byte>(
                    original_bit_count >> static_cast<unsigned>(index * 8U));
            }
            transform(block_);

            ContentIdentity identity;
            for (std::size_t word = 0; word < state_.size(); ++word) {
                for (std::size_t byte = 0; byte < sizeof(std::uint32_t);
                    ++byte) {
                    identity.digest[word * sizeof(std::uint32_t) + byte] =
                        static_cast<std::byte>(
                            state_[word] >>
                            static_cast<unsigned>(24U - byte * 8U));
                }
            }
            return identity;
        }

    private:
        void transform(const std::array<std::byte, 64>& input_block)
        {
            using TransformFunction =
                void (*)(std::uint32_t*, const std::byte*);
            static const TransformFunction transform_function = [] {
#if (defined(__x86_64__) || defined(__i386__)) &&                              \
    (defined(__GNUC__) || defined(__clang__))
                if (__builtin_cpu_supports("sha") &&
                    __builtin_cpu_supports("ssse3") &&
                    __builtin_cpu_supports("sse4.1")) {
                    return static_cast<TransformFunction>(
                        &sha256_transform_sha_ni);
                }
#endif
                return static_cast<TransformFunction>(&sha256_transform_scalar);
            }();
            transform_function(state_.data(), input_block.data());
        }

        std::array<std::uint32_t, 8> state_ { };
        std::array<std::byte, 64> block_ { };
        std::size_t used_ { };
        std::uint64_t bit_count_ { };
    };

} // namespace

bool ContentIdentity::empty() const noexcept
{
    return std::all_of(digest.begin(), digest.end(),
        [](std::byte byte) { return byte == std::byte { 0 }; });
}

std::string ContentIdentity::hex() const
{
    constexpr std::array<char, 16> digits { '0', '1', '2', '3', '4', '5', '6',
        '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
    std::string result;
    result.reserve(digest.size() * 2U);
    for (const auto byte : digest) {
        const auto value = std::to_integer<std::uint8_t>(byte);
        result.push_back(digits[value >> 4U]);
        result.push_back(digits[value & 0x0fU]);
    }
    return result;
}

std::size_t ContentIdentityHash::operator()(
    const ContentIdentity& identity) const noexcept
{
    std::uint64_t value = 0;
    for (std::size_t index = 0; index < sizeof(value); ++index) {
        value |= static_cast<std::uint64_t>(
                     std::to_integer<std::uint8_t>(identity.digest[index]))
                 << static_cast<unsigned>(index * 8U);
    }
    return std::hash<std::uint64_t> { }(value);
}

ContentIdentity sha256(std::span<const std::byte> bytes)
{
    Sha256State state;
    state.update(bytes);
    return state.finish();
}

std::optional<ContentIdentity> sha256_file(int descriptor,
    std::uint64_t file_offset, std::optional<std::uint64_t> byte_count,
    const std::function<bool()>& cancellation_check)
{
    if (descriptor < 0 ||
        file_offset >
            static_cast<std::uint64_t>(std::numeric_limits<off_t>::max())) {
        return std::nullopt;
    }

    Sha256State state;
    std::array<std::byte, 64U * 1024U> buffer { };
    std::uint64_t current_offset = file_offset;
    auto remaining = byte_count;
    while (!remaining || *remaining != 0U) {
        if (cancellation_check && cancellation_check())
            return std::nullopt;
        const auto requested =
            remaining ? std::min<std::uint64_t>(*remaining, buffer.size())
                      : buffer.size();
        ssize_t count = -1;
        do {
            count = ::pread(descriptor, buffer.data(), requested,
                static_cast<off_t>(current_offset));
        } while (count < 0 && errno == EINTR);
        if (count < 0)
            return std::nullopt;
        if (count == 0) {
            if (remaining && *remaining != 0U)
                return std::nullopt;
            break;
        }

        state.update(std::span<const std::byte> {
            buffer.data(), static_cast<std::size_t>(count) });
        const auto received = static_cast<std::uint64_t>(count);
        if (current_offset >
            std::numeric_limits<std::uint64_t>::max() - received) {
            return std::nullopt;
        }
        current_offset += received;
        if (remaining)
            *remaining -= received;
    }
    return state.finish();
}

std::optional<ContentIdentity> sha256_file(const std::filesystem::path& path,
    std::uint64_t file_offset, std::optional<std::uint64_t> byte_count,
    const std::function<bool()>& cancellation_check)
{
    std::ifstream input { path, std::ios::binary };
    if (!input)
        return std::nullopt;
    if (file_offset > static_cast<std::uint64_t>(
                          std::numeric_limits<std::streamoff>::max())) {
        return std::nullopt;
    }
    input.seekg(static_cast<std::streamoff>(file_offset));
    if (!input)
        return std::nullopt;

    Sha256State state;
    std::array<char, 64U * 1024U> buffer { };
    auto remaining = byte_count;
    while (!remaining || *remaining != 0U) {
        if (cancellation_check && cancellation_check())
            return std::nullopt;
        const auto requested =
            remaining ? std::min<std::uint64_t>(*remaining, buffer.size())
                      : buffer.size();
        input.read(buffer.data(), static_cast<std::streamsize>(requested));
        const auto count = input.gcount();
        if (count <= 0) {
            if (input.eof() && (!remaining || *remaining == 0U))
                break;
            return std::nullopt;
        }
        const auto bytes = std::span<const std::byte> {
            reinterpret_cast<const std::byte*>(buffer.data()),
            static_cast<std::size_t>(count)
        };
        state.update(bytes);
        if (remaining) {
            *remaining -= static_cast<std::uint64_t>(count);
        }
        if (input.bad())
            return std::nullopt;
        if (input.eof()) {
            if (remaining && *remaining != 0U)
                return std::nullopt;
            break;
        }
        if (!input)
            return std::nullopt;
    }
    return state.finish();
}

} // namespace shade
