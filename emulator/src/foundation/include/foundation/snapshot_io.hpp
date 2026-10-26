// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <span>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

namespace emulator::snapshot {

class RefusedError : public std::runtime_error {
public:
    explicit RefusedError(std::string member)
        : std::runtime_error("snapshot refused: " + member +
                             " holds state the snapshot does not cover"),
          member_(std::move(member))
    {
    }

    [[nodiscard]] const std::string& member() const noexcept
    {
        return member_;
    }

private:
    std::string member_;
};

class FormatError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class Writer {
public:
    void u8(std::uint8_t value)
    {
        bytes_.push_back(static_cast<std::byte>(value));
    }

    template <std::unsigned_integral T> void unsigned_value(T value)
    {
        for (std::size_t shift = 0; shift < sizeof(T) * 8U; shift += 8U)
            u8(static_cast<std::uint8_t>(value >> shift));
    }

    void raw(std::span<const std::byte> data)
    {
        bytes_.insert(bytes_.end(), data.begin(), data.end());
    }

    [[nodiscard]] std::vector<std::byte>& bytes() noexcept { return bytes_; }

private:
    std::vector<std::byte> bytes_;
};

class Reader {
public:
    explicit Reader(std::span<const std::byte> data) : data_(data) { }

    [[nodiscard]] std::uint8_t u8()
    {
        require(1);
        return static_cast<std::uint8_t>(data_[offset_++]);
    }

    template <std::unsigned_integral T> [[nodiscard]] T unsigned_value()
    {
        T value { };
        for (std::size_t shift = 0; shift < sizeof(T) * 8U; shift += 8U)
            value |= static_cast<T>(static_cast<T>(u8()) << shift);
        return value;
    }

    [[nodiscard]] std::span<const std::byte> raw(std::size_t size)
    {
        require(size);
        const auto result = data_.subspan(offset_, size);
        offset_ += size;
        return result;
    }

    [[nodiscard]] bool at_end() const noexcept
    {
        return offset_ == data_.size();
    }

private:
    void require(std::size_t size) const
    {
        if (size > data_.size() - offset_)
            throw FormatError { "snapshot ends early" };
    }

    std::span<const std::byte> data_;
    std::size_t offset_ { };
};

inline void save(Writer& out, bool value)
{
    out.u8(value ? 1U : 0U);
}

inline void load(Reader& in, bool& value)
{
    const auto byte = in.u8();
    if (byte > 1U)
        throw FormatError { "snapshot holds a bad boolean" };
    value = byte == 1U;
}

template <typename T>
    requires(std::is_integral_v<T> && !std::is_same_v<T, bool>)
void save(Writer& out, T value)
{
    out.unsigned_value(static_cast<std::make_unsigned_t<T>>(value));
}

template <typename T>
    requires(std::is_integral_v<T> && !std::is_same_v<T, bool>)
void load(Reader& in, T& value)
{
    value = static_cast<T>(in.unsigned_value<std::make_unsigned_t<T>>());
}

template <typename T>
    requires std::is_enum_v<T>
void save(Writer& out, T value)
{
    save(out, static_cast<std::underlying_type_t<T>>(value));
}

template <typename T>
    requires std::is_enum_v<T>
void load(Reader& in, T& value)
{
    std::underlying_type_t<T> raw_value { };
    load(in, raw_value);
    value = static_cast<T>(raw_value);
}

inline void save(Writer& out, const std::string& value)
{
    save(out, static_cast<std::uint64_t>(value.size()));
    out.raw(std::as_bytes(std::span { value }));
}

inline void load(Reader& in, std::string& value)
{
    std::uint64_t size { };
    load(in, size);
    const auto data = in.raw(static_cast<std::size_t>(size));
    value.assign(reinterpret_cast<const char*>(data.data()), data.size());
}

template <typename T>
void save(Writer& out, const std::optional<T>& value);
template <typename T> void load(Reader& in, std::optional<T>& value);
template <typename A, typename B>
void save(Writer& out, const std::pair<A, B>& value);
template <typename A, typename B>
void load(Reader& in, std::pair<A, B>& value);
template <typename T, std::size_t N>
void save(Writer& out, const std::array<T, N>& value);
template <typename T, std::size_t N>
void load(Reader& in, std::array<T, N>& value);
template <typename T> void save(Writer& out, const std::vector<T>& value);
template <typename T> void load(Reader& in, std::vector<T>& value);
template <typename T> void save(Writer& out, const std::deque<T>& value);
template <typename T> void load(Reader& in, std::deque<T>& value);
template <typename T, typename C>
void save(Writer& out, const std::set<T, C>& value);
template <typename T, typename C> void load(Reader& in, std::set<T, C>& value);
template <typename K, typename V, typename C>
void save(Writer& out, const std::map<K, V, C>& value);
template <typename K, typename V, typename C>
void load(Reader& in, std::map<K, V, C>& value);

template <typename T>
void save(Writer& out, const std::optional<T>& value)
{
    save(out, value.has_value());
    if (value)
        save(out, *value);
}

template <typename T> void load(Reader& in, std::optional<T>& value)
{
    bool present { };
    load(in, present);
    if (!present) {
        value.reset();
        return;
    }
    T item { };
    load(in, item);
    value = std::move(item);
}

template <typename A, typename B>
void save(Writer& out, const std::pair<A, B>& value)
{
    save(out, value.first);
    save(out, value.second);
}

template <typename A, typename B>
void load(Reader& in, std::pair<A, B>& value)
{
    load(in, value.first);
    load(in, value.second);
}

template <typename T, std::size_t N>
void save(Writer& out, const std::array<T, N>& value)
{
    for (const auto& item : value)
        save(out, item);
}

template <typename T, std::size_t N>
void load(Reader& in, std::array<T, N>& value)
{
    for (auto& item : value)
        load(in, item);
}

template <typename T> void save(Writer& out, const std::vector<T>& value)
{
    save(out, static_cast<std::uint64_t>(value.size()));
    for (const auto& item : value)
        save(out, item);
}

template <typename T> void load(Reader& in, std::vector<T>& value)
{
    std::uint64_t count { };
    load(in, count);
    value.clear();
    for (std::uint64_t index = 0; index < count; ++index) {
        T item { };
        load(in, item);
        value.push_back(std::move(item));
    }
}

template <typename T> void save(Writer& out, const std::deque<T>& value)
{
    save(out, static_cast<std::uint64_t>(value.size()));
    for (const auto& item : value)
        save(out, item);
}

template <typename T> void load(Reader& in, std::deque<T>& value)
{
    std::uint64_t count { };
    load(in, count);
    value.clear();
    for (std::uint64_t index = 0; index < count; ++index) {
        T item { };
        load(in, item);
        value.push_back(std::move(item));
    }
}

template <typename T, typename C>
void save(Writer& out, const std::set<T, C>& value)
{
    save(out, static_cast<std::uint64_t>(value.size()));
    for (const auto& item : value)
        save(out, item);
}

template <typename T, typename C>
void load(Reader& in, std::set<T, C>& value)
{
    std::uint64_t count { };
    load(in, count);
    value.clear();
    for (std::uint64_t index = 0; index < count; ++index) {
        T item { };
        load(in, item);
        value.insert(std::move(item));
    }
}

template <typename K, typename V, typename C>
void save(Writer& out, const std::map<K, V, C>& value)
{
    save(out, static_cast<std::uint64_t>(value.size()));
    for (const auto& [key, item] : value) {
        save(out, key);
        save(out, item);
    }
}

template <typename K, typename V, typename C>
void load(Reader& in, std::map<K, V, C>& value)
{
    std::uint64_t count { };
    load(in, count);
    value.clear();
    for (std::uint64_t index = 0; index < count; ++index) {
        K key { };
        V item { };
        load(in, key);
        load(in, item);
        value.emplace(std::move(key), std::move(item));
    }
}

template <typename T>
    requires(std::is_arithmetic_v<T> || std::is_enum_v<T>)
bool is_default(const T& value)
{
    return value == T { };
}

template <typename T> bool is_default(const std::optional<T>& value)
{
    return !value.has_value();
}

template <typename T> bool is_default(const std::atomic<T>& value)
{
    return value.load() == T { };
}

template <typename T> bool is_default(const std::shared_ptr<T>& value)
{
    return value == nullptr;
}

template <typename T> bool is_default(const std::unique_ptr<T>& value)
{
    return value == nullptr;
}

template <typename T> bool is_default(const std::weak_ptr<T>& value)
{
    return value.expired();
}

inline bool is_default(const std::mutex&)
{
    return true;
}

inline bool is_default(const std::string& value)
{
    return value.empty();
}

inline bool is_default(const std::filesystem::path& value)
{
    return value.empty();
}

template <typename T> bool is_default(const std::vector<T>& value)
{
    return value.empty();
}

template <typename T> bool is_default(const std::deque<T>& value)
{
    return value.empty();
}

template <typename T, typename C>
bool is_default(const std::set<T, C>& value)
{
    return value.empty();
}

template <typename K, typename V, typename C>
bool is_default(const std::map<K, V, C>& value)
{
    return value.empty();
}

template <typename K, typename V>
bool is_default(const std::multimap<K, V>& value)
{
    return value.empty();
}

template <typename K, typename V>
bool is_default(const std::unordered_map<K, V>& value)
{
    return value.empty();
}

template <typename T, std::size_t N>
bool is_default(const std::array<T, N>& value)
{
    for (const auto& item : value)
        if (!is_default(item))
            return false;
    return true;
}

}
