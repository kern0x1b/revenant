// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/jit_artifact.hpp"

#include <dynarmic/interface/A32/a32.h>
#include <dynarmic/interface/A32/config.h>

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <optional>
#include <vector>

using namespace emulator;

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "image_slab_test.cpp:%d: check failed: %s\n", line,
        expression);
}

void check_equal(std::uint64_t actual, std::uint64_t expected,
    const char* expression, int line)
{
    if (actual == expected)
        return;
    ++failures;
    std::fprintf(stderr,
        "image_slab_test.cpp:%d: %s is %llu, expected %llu\n", line,
        expression, static_cast<unsigned long long>(actual),
        static_cast<unsigned long long>(expected));
}

#define CHECK(expression) check((expression), #expression, __LINE__)
#define CHECK_EQ(actual, expected) \
    check_equal((actual), (expected), #actual, __LINE__)

constexpr std::uint32_t code_begin = 0x30000000U;
constexpr std::uint32_t code_end = 0x40000000U;
constexpr std::size_t page_bytes = 4096U;
constexpr std::uint32_t svc_opcode = 0xEF000000U;
constexpr std::uint32_t user_mode = 0x10U;
constexpr std::uint64_t ticks_per_run = 1000U;
constexpr std::size_t mebibyte = 1024U * 1024U;

using Backing = std::shared_ptr<std::vector<std::uint8_t>>;

Backing make_backing(const std::vector<std::uint8_t>& contents)
{
    return std::make_shared<std::vector<std::uint8_t>>(contents);
}

void store_program(std::vector<std::uint8_t>& page, std::uint32_t value)
{
    const std::array<std::uint32_t, 2> words {
        0xE3A00000U | (value & 0xFFU),
        svc_opcode,
    };
    std::memcpy(page.data(), words.data(), sizeof(words));
}

class Process final : public Dynarmic::A32::UserCallbacks {
public:
    explicit Process(Backing backing)
        : backing_ { std::move(backing) }
        , context_ { std::make_unique<ExecutionContext>() }
    {
        const auto callbacks_cell = context_->create_link_cell();
        context_->link(callbacks_cell, static_cast<std::uint64_t>(
            reinterpret_cast<std::uintptr_t>(this)));
        callbacks_link_ = context_->link_cell_address(callbacks_cell);
        lookup_link_ = context_->link_cell_address(
            context_->create_link_cell());
        runtime_config_link_ = context_->link_cell_address(
            context_->create_link_cell());
        build_jit();
    }

    void write_program(std::uint32_t value)
    {
        store_program(*backing_, value);
    }

    void detach()
    {
        backing_ = make_backing(*backing_);
    }

    void invalidate()
    {
        static_cast<void>(context_->request_cache_range(
            code_begin, page_bytes));
    }

    void exec()
    {
        static_cast<void>(context_->request_cache_clear());
        context_->native_code_slab()->service_pending_invalidation();
        service_machine_image_code_slab();
    }

    std::uint32_t run()
    {
        if (jit_ && jit_image_slab_ != machine_image_code_slab_for(*context_))
            jit_.reset();
        if (!jit_)
            build_jit();
        context_->native_code_slab()->service_pending_invalidation();
        service_machine_image_code_slab();
        jit_->ClearHalt();
        jit_->Regs()[0] = 0U;
        jit_->Regs()[15] = code_begin;
        jit_->SetCpsr(user_mode);
        jit_->Run();
        return jit_->Regs()[0];
    }

    bool image_slab_in_use() const
    {
        return jit_image_slab_ != nullptr;
    }

    std::uint8_t MemoryRead8(std::uint32_t vaddr) override { return load<std::uint8_t>(vaddr); }
    std::uint16_t MemoryRead16(std::uint32_t vaddr) override { return load<std::uint16_t>(vaddr); }
    std::uint32_t MemoryRead32(std::uint32_t vaddr) override { return load<std::uint32_t>(vaddr); }
    std::uint64_t MemoryRead64(std::uint32_t vaddr) override { return load<std::uint64_t>(vaddr); }
    void MemoryWrite8(std::uint32_t vaddr, std::uint8_t value) override { store(vaddr, value); }
    void MemoryWrite16(std::uint32_t vaddr, std::uint16_t value) override { store(vaddr, value); }
    void MemoryWrite32(std::uint32_t vaddr, std::uint32_t value) override { store(vaddr, value); }
    void MemoryWrite64(std::uint32_t vaddr, std::uint64_t value) override { store(vaddr, value); }

    std::uint8_t MemorySwap8(std::uint32_t vaddr, std::uint8_t value) override
    {
        const auto old = load<std::uint8_t>(vaddr);
        store(vaddr, value);
        return old;
    }

    std::uint32_t MemorySwap32(std::uint32_t vaddr, std::uint32_t value) override
    {
        const auto old = load<std::uint32_t>(vaddr);
        store(vaddr, value);
        return old;
    }

    std::optional<std::uint32_t> MemoryReadCode(std::uint32_t vaddr) override
    {
        return load<std::uint32_t>(vaddr);
    }

    void InterpreterFallback(std::uint32_t, std::size_t) override { }

    void CallSVC(std::uint32_t) override { jit_->HaltExecution(); }

    void ExceptionRaised(std::uint32_t, Dynarmic::A32::Exception) override { }

    void AddTicks(std::uint64_t) override { }

    std::uint64_t GetTicksRemaining() override { return ticks_per_run; }

private:
    void build_jit()
    {
        Dynarmic::A32::UserConfig config { this };
        config.native_code_slab = context_->native_code_slab();
        config.callbacks_link = callbacks_link_;
        config.coprocessor_user_arg_link = callbacks_link_;
        config.lookup_link = lookup_link_;
        config.runtime_config_link = runtime_config_link_;
        jit_image_slab_ = machine_image_code_slab_for(*context_);
        if (jit_image_slab_ != nullptr) {
            const auto region = machine_image_code_region();
            config.image_native_code_slab = jit_image_slab_;
            config.image_code_begin = region.begin;
            config.image_code_end = region.end;
            config.image_code_cache_size = region.cache_bytes;
        }
        jit_ = std::make_unique<Dynarmic::A32::Jit>(config);
    }

    template <typename T>
    T load(std::uint32_t vaddr) const
    {
        T value {};
        if (vaddr >= code_begin && vaddr - code_begin + sizeof(T) <= page_bytes)
            std::memcpy(&value, backing_->data() + (vaddr - code_begin), sizeof(T));
        return value;
    }

    template <typename T>
    void store(std::uint32_t vaddr, T value)
    {
        if (vaddr >= code_begin && vaddr - code_begin + sizeof(T) <= page_bytes)
            std::memcpy(backing_->data() + (vaddr - code_begin), &value, sizeof(T));
    }

    Backing backing_;
    std::unique_ptr<ExecutionContext> context_;
    std::atomic<std::uint64_t>* callbacks_link_ { };
    std::atomic<std::uint64_t>* lookup_link_ { };
    std::atomic<std::uint64_t>* runtime_config_link_ { };
    Dynarmic::A32::NativeCodeSlab* jit_image_slab_ { };
    std::unique_ptr<Dynarmic::A32::Jit> jit_;
};

}

int main()
{
    set_machine_image_code_region(ImageCodeRegion { "rootfs|iPhone4,1",
        code_begin, code_end, 8U * mebibyte });

    const auto shared = make_backing(std::vector<std::uint8_t>(page_bytes));
    store_program(*shared, 1);

    Process reader { shared };
    Process other { shared };
    CHECK_EQ(reader.run(), 1U);
    CHECK(reader.image_slab_in_use());
    CHECK(machine_image_code_slab() != nullptr);
    CHECK(machine_image_code_slab()->code_cache_used() != 0U);
    CHECK_EQ(other.run(), 1U);
    CHECK(other.image_slab_in_use());

    const auto translated_before_exec =
        machine_image_code_slab()->code_cache_used();
    reader.exec();
    CHECK_EQ(other.run(), 1U);
    CHECK_EQ(machine_image_code_slab()->code_cache_used(),
        translated_before_exec);

    reader.detach();
    reader.write_program(2);
    CHECK_EQ(other.run(), 1U);
    reader.invalidate();
    CHECK_EQ(reader.run(), 2U);
    CHECK(!reader.image_slab_in_use());
    CHECK_EQ(other.run(), 1U);
    CHECK(other.image_slab_in_use());

    other.detach();
    other.write_program(5);
    CHECK_EQ(other.run(), 1U);
    other.invalidate();
    CHECK_EQ(other.run(), 5U);
    CHECK_EQ(reader.run(), 2U);

    Process writer { shared };
    writer.detach();
    writer.write_program(7);
    writer.invalidate();
    const auto translated_before_writer =
        machine_image_code_slab()->code_cache_used();
    CHECK_EQ(writer.run(), 7U);
    CHECK(!writer.image_slab_in_use());
    CHECK_EQ(machine_image_code_slab()->code_cache_used(),
        translated_before_writer);

    Process clean { shared };
    CHECK_EQ(clean.run(), 1U);
    CHECK(clean.image_slab_in_use());

    if (failures == 0)
        std::puts("image_slab_test: ok");
    return failures == 0 ? 0 : 1;
}
