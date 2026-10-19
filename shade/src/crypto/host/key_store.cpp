// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Persist virtual-device class keys and wrap or unwrap guest key
// material.

#include "crypto/key_store.hpp"

#include <algorithm>
#include <cerrno>
#include <fcntl.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

namespace shade {
namespace {

    struct Secret {
        std::array<std::byte, 32> bytes { };
        ~Secret() { OPENSSL_cleanse(bytes.data(), bytes.size()); }
    };

    struct Descriptor {
        int value;
        ~Descriptor() { if (value >= 0) ::close(value); }
    };

} // namespace

KeyStore::KeyStore(std::span<const std::byte, 32> secret)
{
    std::copy(secret.begin(), secret.end(), secret_.begin());
}

KeyStore::~KeyStore()
{
    OPENSSL_cleanse(secret_.data(), secret_.size());
}

std::shared_ptr<KeyStore> KeyStore::open(
    const std::filesystem::path& state_file)
{
    std::error_code error;
    std::filesystem::create_directories(state_file.parent_path(), error);
    if (error)
        return { };
    auto fd = ::open(state_file.c_str(),
        O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    const auto created = fd >= 0;
    if (!created && errno == EEXIST)
        fd = ::open(state_file.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    Descriptor file { fd };
    if (fd < 0 || ::flock(fd, LOCK_EX) != 0)
        return { };
    Secret secret;
    struct stat status { };
    if (::fstat(fd, &status) != 0 || !S_ISREG(status.st_mode))
        return { };
    if (created) {
        if (RAND_priv_bytes(reinterpret_cast<unsigned char*>(
                                secret.bytes.data()),
                static_cast<int>(secret.bytes.size())) != 1 ||
            ::write(fd, secret.bytes.data(), secret.bytes.size()) !=
                static_cast<ssize_t>(secret.bytes.size()) ||
            ::fsync(fd) != 0) {
            // Never replace existing device material when loading fails.
            ::unlink(state_file.c_str());
            return { };
        }
        Descriptor directory { ::open(state_file.parent_path().c_str(),
            O_RDONLY | O_DIRECTORY | O_CLOEXEC) };
        if (directory.value < 0 || ::fsync(directory.value) != 0)
            return { };
    } else if (status.st_size != static_cast<off_t>(secret.bytes.size()) ||
               ::read(fd, secret.bytes.data(), secret.bytes.size()) !=
                   static_cast<ssize_t>(secret.bytes.size())) {
        return { };
    }
    return std::shared_ptr<KeyStore> { new KeyStore { secret.bytes } };
}

std::optional<std::vector<std::byte>> KeyStore::wrap(
    std::uint32_t key_class, std::span<const std::byte> key) const
{
    if (key.size() < 16U || key.size() > 32U || key.size() % 8U != 0U)
        return std::nullopt;
    return transform(key_class, key, true);
}

std::optional<std::vector<std::byte>> KeyStore::unwrap(
    std::uint32_t key_class, std::span<const std::byte> wrapped) const
{
    if (wrapped.size() < 24U || wrapped.size() > 40U ||
        wrapped.size() % 8U != 0U)
        return std::nullopt;
    return transform(key_class, wrapped, false);
}

std::optional<std::vector<std::byte>> KeyStore::transform(
    std::uint32_t key_class, std::span<const std::byte> input,
    bool wrapping) const
{
    if (key_class < 1U || key_class > 11U)
        return std::nullopt;
    // Domain-separated class keys keep protection classes independent while
    // retaining one durable device secret. No guest process shares scratch.
    std::array<unsigned char, 22> label {
        'S', 'h', 'a', 'd', 'e', ' ', 'c', 'l', 'a', 's', 's', ' ',
        'k', 'e', 'y', ' ', 'v', '1', 0, 0, 0, 0
    };
    for (unsigned byte = 0; byte < 4U; ++byte)
        label[18U + byte] = static_cast<unsigned char>(key_class >> (8U * byte));
    Secret class_key;
    unsigned key_size = 0;
    if (!HMAC(EVP_sha256(), secret_.data(), static_cast<int>(secret_.size()),
            label.data(), label.size(),
            reinterpret_cast<unsigned char*>(class_key.bytes.data()),
            &key_size) || key_size != class_key.bytes.size())
        return std::nullopt;
    std::unique_ptr<EVP_CIPHER_CTX, decltype(&EVP_CIPHER_CTX_free)> context {
        EVP_CIPHER_CTX_new(), EVP_CIPHER_CTX_free
    };
    if (!context)
        return std::nullopt;
    EVP_CIPHER_CTX_set_flags(context.get(), EVP_CIPHER_CTX_FLAG_WRAP_ALLOW);
    if (EVP_CipherInit_ex(context.get(), EVP_aes_256_wrap(), nullptr,
            reinterpret_cast<const unsigned char*>(class_key.bytes.data()),
            nullptr, wrapping ? 1 : 0) != 1)
        return std::nullopt;
    std::vector<std::byte> result(input.size() + EVP_MAX_BLOCK_LENGTH);
    int size = 0;
    int tail = 0;
    if (EVP_CipherUpdate(context.get(),
            reinterpret_cast<unsigned char*>(result.data()), &size,
            reinterpret_cast<const unsigned char*>(input.data()),
            static_cast<int>(input.size())) != 1 ||
        EVP_CipherFinal_ex(context.get(),
            reinterpret_cast<unsigned char*>(result.data()) + size, &tail) != 1) {
        OPENSSL_cleanse(result.data(), result.size());
        return std::nullopt;
    }
    result.resize(static_cast<std::size_t>(size + tail));
    return result;
}

} // namespace shade
