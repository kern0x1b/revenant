// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Serialize and validate portable Umbra IR translation artifacts.

#include "umbra_ir_artifact.hpp"

#include <algorithm>
#include <array>
#include <boost/variant/apply_visitor.hpp>
#include <limits>
#include <unordered_map>
#include <unordered_set>
#include <utility>

#include <umbra/frontend/A32/a32_location_descriptor.h>
#include <umbra/frontend/A32/a32_types.h>
#include <umbra/frontend/A64/a64_types.h>
#include <umbra/ir/acc_type.h>
#include <umbra/ir/cond.h>
#include <umbra/ir/opcodes.h>
#include <umbra/ir/terminal.h>
#include <umbra/ir/type.h>

namespace shade {
namespace {

    constexpr std::array<std::uint8_t, 8> magic { 'i', 'L', 'I', 'R', 'B', '0',
        '0', '1' };
    constexpr std::uint32_t format_version = 1U;
    constexpr std::size_t maximum_bytes = 16U * 1024U * 1024U;
    constexpr std::uint32_t maximum_instructions = 16U * 1024U;
    constexpr std::uint32_t maximum_terminal_depth = 32U;
    // Umbra's x64 allocator has 64 spill slots. Keeping the entire
    // live-value frontier within that pool guarantees that an adversarial
    // dependency graph cannot exhaust spills regardless of which host registers
    // the configuration reserves for fastmem or page-table state.
    constexpr std::size_t maximum_live_values = 64U;

    enum class ValueTag : std::uint8_t {
        Reference,
        Immediate,
    };

    class Writer {
    public:
        void byte(std::uint8_t value)
        {
            if (bytes_.size() < maximum_bytes) {
                bytes_.push_back(static_cast<std::byte>(value));
            } else {
                valid_ = false;
            }
        }

        void u16(std::uint16_t value)
        {
            byte(static_cast<std::uint8_t>(value));
            byte(static_cast<std::uint8_t>(value >> 8U));
        }

        void u32(std::uint32_t value)
        {
            for (unsigned shift = 0; shift < 32U; shift += 8U) {
                byte(static_cast<std::uint8_t>(value >> shift));
            }
        }

        void u64(std::uint64_t value)
        {
            for (unsigned shift = 0; shift < 64U; shift += 8U) {
                byte(static_cast<std::uint8_t>(value >> shift));
            }
        }

        void raw(std::span<const std::uint8_t> values)
        {
            for (const auto value : values)
                byte(value);
        }

        [[nodiscard]] bool valid() const { return valid_; }
        [[nodiscard]] std::vector<std::byte> take() &&
        {
            return std::move(bytes_);
        }

    private:
        std::vector<std::byte> bytes_;
        bool valid_ { true };
    };

    class Reader {
    public:
        explicit Reader(std::span<const std::byte> bytes)
            : bytes_ { bytes }
        {
        }

        [[nodiscard]] bool byte(std::uint8_t& value)
        {
            if (offset_ >= bytes_.size())
                return false;
            value = std::to_integer<std::uint8_t>(bytes_[offset_++]);
            return true;
        }

        [[nodiscard]] bool u16(std::uint16_t& value)
        {
            std::uint8_t low { };
            std::uint8_t high { };
            if (!byte(low) || !byte(high))
                return false;
            value = static_cast<std::uint16_t>(
                static_cast<std::uint16_t>(low) |
                static_cast<std::uint16_t>(
                    static_cast<std::uint16_t>(high) << 8U));
            return true;
        }

        [[nodiscard]] bool u32(std::uint32_t& value)
        {
            value = 0;
            for (unsigned shift = 0; shift < 32U; shift += 8U) {
                std::uint8_t current { };
                if (!byte(current))
                    return false;
                value |= static_cast<std::uint32_t>(current) << shift;
            }
            return true;
        }

        [[nodiscard]] bool u64(std::uint64_t& value)
        {
            value = 0;
            for (unsigned shift = 0; shift < 64U; shift += 8U) {
                std::uint8_t current { };
                if (!byte(current))
                    return false;
                value |= static_cast<std::uint64_t>(current) << shift;
            }
            return true;
        }

        [[nodiscard]] bool raw(std::span<std::uint8_t> values)
        {
            if (values.size() > bytes_.size() - offset_)
                return false;
            for (auto& value : values) {
                value = std::to_integer<std::uint8_t>(bytes_[offset_++]);
            }
            return true;
        }

        [[nodiscard]] bool at_end() const { return offset_ == bytes_.size(); }

    private:
        std::span<const std::byte> bytes_;
        std::size_t offset_ { };
    };

    [[nodiscard]] bool valid_condition(std::uint8_t value)
    {
        return value <= static_cast<std::uint8_t>(Umbra::IR::Cond::AL);
    }

    [[nodiscard]] bool valid_acc_type(std::uint8_t value)
    {
        return value <= static_cast<std::uint8_t>(Umbra::IR::AccType::SWAP);
    }

    [[nodiscard]] bool valid_value_type(Umbra::IR::Type type)
    {
        switch (type) {
        case Umbra::IR::Type::U1:
        case Umbra::IR::Type::U8:
        case Umbra::IR::Type::U16:
        case Umbra::IR::Type::U32:
        case Umbra::IR::Type::U64:
        case Umbra::IR::Type::A32Reg:
        case Umbra::IR::Type::A32ExtReg:
        case Umbra::IR::Type::A64Reg:
        case Umbra::IR::Type::A64Vec:
        case Umbra::IR::Type::CoprocInfo:
        case Umbra::IR::Type::NZCVFlags:
        case Umbra::IR::Type::Cond:
        case Umbra::IR::Type::AccType:
            return true;
        case Umbra::IR::Type::Void:
        case Umbra::IR::Type::Opaque:
        case Umbra::IR::Type::U128:
        case Umbra::IR::Type::Table:
            return false;
        }
        return false;
    }

    [[nodiscard]] bool canonical_a32_location(
        Umbra::IR::LocationDescriptor location)
    {
        const Umbra::A32::LocationDescriptor decoded { location };
        return static_cast<Umbra::IR::LocationDescriptor>(decoded).Value() ==
               location.Value();
    }

    [[nodiscard]] bool aligned_a32_location(
        Umbra::IR::LocationDescriptor location)
    {
        const Umbra::A32::LocationDescriptor decoded { location };
        const auto alignment = decoded.TFlag() ? 2U : 4U;
        return decoded.PC() % alignment == 0U;
    }

    [[nodiscard]] bool valid_terminal(const Umbra::IR::Terminal& terminal,
        const Umbra::A32::LocationDescriptor& initial_location,
        bool has_set_check_bit)
    {
        struct Visitor : boost::static_visitor<bool> {
            const Umbra::A32::LocationDescriptor& initial_location;
            bool has_set_check_bit;

            Visitor(const Umbra::A32::LocationDescriptor& initial,
                bool has_set_check_bit_)
                : initial_location { initial }
                , has_set_check_bit { has_set_check_bit_ }
            {
            }

            bool operator()(const Umbra::IR::Term::Invalid&) const
            {
                return false;
            }

            bool operator()(const Umbra::IR::Term::Interpret& value) const
            {
                const Umbra::A32::LocationDescriptor next { value.next };
                // Both current backends either assert these invariants or do
                // not emit Interpret terminals at all. Keep malformed portable
                // IR off Emit().
                return canonical_a32_location(value.next) &&
                       aligned_a32_location(value.next) &&
                       value.num_instructions == 1U &&
                       next.TFlag() == initial_location.TFlag() &&
                       next.EFlag() == initial_location.EFlag();
            }

            bool operator()(const Umbra::IR::Term::ReturnToDispatch&) const
            {
                return true;
            }

            bool operator()(const Umbra::IR::Term::LinkBlock& value) const
            {
                return canonical_a32_location(value.next) &&
                       aligned_a32_location(value.next);
            }

            bool operator()(
                const Umbra::IR::Term::LinkBlockFast& value) const
            {
                return canonical_a32_location(value.next) &&
                       aligned_a32_location(value.next);
            }

            bool operator()(const Umbra::IR::Term::PopRSBHint&) const
            {
                return true;
            }

            bool operator()(const Umbra::IR::Term::FastDispatchHint&) const
            {
                return true;
            }

            bool operator()(const Umbra::IR::Term::If& value) const
            {
                return value.if_ <= Umbra::IR::Cond::AL &&
                       valid_terminal(
                           value.then_, initial_location, has_set_check_bit) &&
                       valid_terminal(
                           value.else_, initial_location, has_set_check_bit);
            }

            bool operator()(const Umbra::IR::Term::CheckBit& value) const
            {
                return has_set_check_bit &&
                       valid_terminal(
                           value.then_, initial_location, has_set_check_bit) &&
                       valid_terminal(
                           value.else_, initial_location, has_set_check_bit);
            }

            bool operator()(const Umbra::IR::Term::CheckHalt& value) const
            {
                return valid_terminal(
                    value.else_, initial_location, has_set_check_bit);
            }
        } visitor { initial_location, has_set_check_bit };
        return boost::apply_visitor(visitor, terminal);
    }

    void write_location(
        Writer& writer, Umbra::IR::LocationDescriptor location)
    {
        writer.u64(location.Value());
    }

    [[nodiscard]] bool read_location(
        Reader& reader, Umbra::IR::LocationDescriptor& location)
    {
        std::uint64_t value { };
        if (!reader.u64(value))
            return false;
        location = Umbra::IR::LocationDescriptor { value };
        return true;
    }

    void write_terminal(Writer& writer, const Umbra::IR::Terminal& terminal,
        std::uint32_t depth);

    void write_terminal_location(
        Writer& writer, Umbra::IR::LocationDescriptor location)
    {
        write_location(writer, location);
    }

    void write_terminal(Writer& writer, const Umbra::IR::Terminal& terminal,
        std::uint32_t depth)
    {
        if (depth > maximum_terminal_depth) {
            writer.byte(0xffU);
            return;
        }
        struct Visitor : boost::static_visitor<void> {
            Writer& writer;
            std::uint32_t depth;

            Visitor(Writer& writer_, std::uint32_t depth_)
                : writer { writer_ }
                , depth { depth_ }
            {
            }

            void operator()(const Umbra::IR::Term::Invalid&) const
            {
                writer.byte(0U);
            }
            void operator()(const Umbra::IR::Term::Interpret& value) const
            {
                writer.byte(1U);
                write_terminal_location(writer, value.next);
                if (value.num_instructions >
                    std::numeric_limits<std::uint64_t>::max()) {
                    writer.byte(0xffU);
                } else {
                    writer.u64(
                        static_cast<std::uint64_t>(value.num_instructions));
                }
            }
            void operator()(const Umbra::IR::Term::ReturnToDispatch&) const
            {
                writer.byte(2U);
            }
            void operator()(const Umbra::IR::Term::LinkBlock& value) const
            {
                writer.byte(3U);
                write_terminal_location(writer, value.next);
            }
            void operator()(
                const Umbra::IR::Term::LinkBlockFast& value) const
            {
                writer.byte(4U);
                write_terminal_location(writer, value.next);
            }
            void operator()(const Umbra::IR::Term::PopRSBHint&) const
            {
                writer.byte(5U);
            }
            void operator()(const Umbra::IR::Term::FastDispatchHint&) const
            {
                writer.byte(6U);
            }
            void operator()(const Umbra::IR::Term::If& value) const
            {
                writer.byte(7U);
                writer.byte(static_cast<std::uint8_t>(value.if_));
                write_terminal(writer, value.then_, depth + 1U);
                write_terminal(writer, value.else_, depth + 1U);
            }
            void operator()(const Umbra::IR::Term::CheckBit& value) const
            {
                writer.byte(8U);
                write_terminal(writer, value.then_, depth + 1U);
                write_terminal(writer, value.else_, depth + 1U);
            }
            void operator()(const Umbra::IR::Term::CheckHalt& value) const
            {
                writer.byte(9U);
                write_terminal(writer, value.else_, depth + 1U);
            }
        } visitor { writer, depth };
        boost::apply_visitor(visitor, terminal);
    }

    [[nodiscard]] std::optional<Umbra::IR::Terminal> read_terminal(
        Reader& reader, std::uint32_t depth)
    {
        if (depth > maximum_terminal_depth)
            return std::nullopt;
        std::uint8_t tag { };
        if (!reader.byte(tag))
            return std::nullopt;
        switch (tag) {
        case 1: {
            Umbra::IR::LocationDescriptor next { 0 };
            std::uint64_t count { };
            if (!read_location(reader, next) || !reader.u64(count) ||
                count == 0) {
                return std::nullopt;
            }
            if (count > std::numeric_limits<std::size_t>::max()) {
                return std::nullopt;
            }
            auto terminal = Umbra::IR::Term::Interpret { next };
            terminal.num_instructions = static_cast<std::size_t>(count);
            return Umbra::IR::Terminal { terminal };
        }
        case 2:
            return Umbra::IR::Terminal {
                Umbra::IR::Term::ReturnToDispatch { }
            };
        case 3: {
            Umbra::IR::LocationDescriptor next { 0 };
            if (!read_location(reader, next))
                return std::nullopt;
            return Umbra::IR::Terminal { Umbra::IR::Term::LinkBlock {
                next } };
        }
        case 4: {
            Umbra::IR::LocationDescriptor next { 0 };
            if (!read_location(reader, next))
                return std::nullopt;
            return Umbra::IR::Terminal { Umbra::IR::Term::LinkBlockFast {
                next } };
        }
        case 5:
            return Umbra::IR::Terminal {
                Umbra::IR::Term::PopRSBHint { }
            };
        case 6:
            return Umbra::IR::Terminal {
                Umbra::IR::Term::FastDispatchHint { }
            };
        case 7: {
            std::uint8_t condition { };
            if (!reader.byte(condition) || !valid_condition(condition)) {
                return std::nullopt;
            }
            auto then_terminal = read_terminal(reader, depth + 1U);
            auto else_terminal = read_terminal(reader, depth + 1U);
            if (!then_terminal || !else_terminal)
                return std::nullopt;
            return Umbra::IR::Terminal { Umbra::IR::Term::If {
                static_cast<Umbra::IR::Cond>(condition),
                std::move(*then_terminal), std::move(*else_terminal) } };
        }
        case 8: {
            auto then_terminal = read_terminal(reader, depth + 1U);
            auto else_terminal = read_terminal(reader, depth + 1U);
            if (!then_terminal || !else_terminal)
                return std::nullopt;
            return Umbra::IR::Terminal { Umbra::IR::Term::CheckBit {
                std::move(*then_terminal), std::move(*else_terminal) } };
        }
        case 9: {
            auto else_terminal = read_terminal(reader, depth + 1U);
            if (!else_terminal)
                return std::nullopt;
            return Umbra::IR::Terminal { Umbra::IR::Term::CheckHalt {
                std::move(*else_terminal) } };
        }
        default:
            return std::nullopt;
        }
    }

    struct EncodedValue {
        ValueTag tag { };
        Umbra::IR::Type type { Umbra::IR::Type::Void };
        std::uint32_t reference { };
        std::uint64_t scalar { };
        std::array<std::uint8_t, 8> coprocessor { };
    };

    struct EncodedInstruction {
        Umbra::IR::Opcode opcode { Umbra::IR::Opcode::Void };
        std::uint32_t name { };
        std::vector<EncodedValue> arguments;
    };

    [[nodiscard]] bool emitter_safe_opcode(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::Void:
        case Opcode::Identity:
        case Opcode::Breakpoint:
        case Opcode::CallHostFunction:
        case Opcode::VectorMultiplySignedWiden8:
        case Opcode::VectorMultiplySignedWiden16:
        case Opcode::VectorMultiplySignedWiden32:
        case Opcode::VectorMultiplyUnsignedWiden8:
        case Opcode::VectorMultiplyUnsignedWiden16:
        case Opcode::VectorMultiplyUnsignedWiden32:
        case Opcode::A32CoprocInternalOperation:
        case Opcode::A32CoprocSendOneWord:
        case Opcode::A32CoprocSendTwoWords:
        case Opcode::A32CoprocGetOneWord:
        case Opcode::A32CoprocGetTwoWords:
        case Opcode::A32CoprocLoadWords:
        case Opcode::A32CoprocStoreWords:
            return false;
        default:
            break;
        }
        switch (opcode) {
#define OPCODE(name, type, ...) case Opcode::name:
#define A32OPC(name, type, ...) case Opcode::A32##name:
#define A64OPC(...)
#include <umbra/ir/opcodes.inc>
#undef OPCODE
#undef A32OPC
#undef A64OPC
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] Umbra::IR::Type encoded_value_type(
        const EncodedValue& value,
        const std::vector<EncodedInstruction>& instructions)
    {
        if (value.tag == ValueTag::Immediate)
            return value.type;
        return Umbra::IR::GetTypeOf(instructions[value.reference].opcode);
    }

    [[nodiscard]] bool encoded_is_scalar(const EncodedValue& value,
        const std::vector<EncodedInstruction>& instructions)
    {
        switch (encoded_value_type(value, instructions)) {
        case Umbra::IR::Type::U8:
        case Umbra::IR::Type::U16:
        case Umbra::IR::Type::U32:
        case Umbra::IR::Type::U64:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool carry_parent(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::MostSignificantWord:
        case Opcode::LogicalShiftLeft32:
        case Opcode::LogicalShiftRight32:
        case Opcode::ArithmeticShiftRight32:
        case Opcode::RotateRight32:
        case Opcode::RotateRightExtended:
        case Opcode::Add32:
        case Opcode::Add64:
        case Opcode::Sub32:
        case Opcode::Sub64:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool overflow_parent(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::Add32:
        case Opcode::Add64:
        case Opcode::Sub32:
        case Opcode::Sub64:
        case Opcode::SignedSaturatedAddWithFlag32:
        case Opcode::SignedSaturatedSubWithFlag32:
        case Opcode::SignedSaturation:
        case Opcode::UnsignedSaturation:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool ge_parent(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::PackedAddU8:
        case Opcode::PackedAddS8:
        case Opcode::PackedSubU8:
        case Opcode::PackedSubS8:
        case Opcode::PackedAddU16:
        case Opcode::PackedAddS16:
        case Opcode::PackedSubU16:
        case Opcode::PackedSubS16:
        case Opcode::PackedAddSubU16:
        case Opcode::PackedAddSubS16:
        case Opcode::PackedSubAddU16:
        case Opcode::PackedSubAddS16:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool nzcv_parent(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::Add32:
        case Opcode::Add64:
        case Opcode::Sub32:
        case Opcode::Sub64:
        case Opcode::And32:
        case Opcode::And64:
        case Opcode::AndNot32:
        case Opcode::AndNot64:
        case Opcode::Eor32:
        case Opcode::Eor64:
        case Opcode::Or32:
        case Opcode::Or64:
        case Opcode::Not32:
        case Opcode::Not64:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool upper_lower_parent(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::VectorSignedMultiply16:
        case Opcode::VectorSignedMultiply32:
        case Opcode::VectorUnsignedMultiply16:
        case Opcode::VectorUnsignedMultiply32:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool a32_memory_opcode(Umbra::IR::Opcode opcode)
    {
        using Opcode = Umbra::IR::Opcode;
        switch (opcode) {
        case Opcode::A32ReadMemory8:
        case Opcode::A32ReadMemory16:
        case Opcode::A32ReadMemory32:
        case Opcode::A32ReadMemory64:
        case Opcode::A32ExclusiveReadMemory8:
        case Opcode::A32ExclusiveReadMemory16:
        case Opcode::A32ExclusiveReadMemory32:
        case Opcode::A32ExclusiveReadMemory64:
        case Opcode::A32WriteMemory8:
        case Opcode::A32WriteMemory16:
        case Opcode::A32WriteMemory32:
        case Opcode::A32WriteMemory64:
        case Opcode::A32SwapMemory8:
        case Opcode::A32SwapMemory32:
        case Opcode::A32ExclusiveWriteMemory8:
        case Opcode::A32ExclusiveWriteMemory16:
        case Opcode::A32ExclusiveWriteMemory32:
        case Opcode::A32ExclusiveWriteMemory64:
            return true;
        default:
            return false;
        }
    }

    [[nodiscard]] bool immediate_value(const EncodedValue& value)
    {
        return value.tag == ValueTag::Immediate;
    }

    [[nodiscard]] bool immediate_at(
        const EncodedInstruction& instruction, std::size_t argument)
    {
        return argument < instruction.arguments.size() &&
               immediate_value(instruction.arguments[argument]);
    }

    [[nodiscard]] bool a32_execution_mode_equal(
        Umbra::IR::LocationDescriptor lhs,
        Umbra::IR::LocationDescriptor rhs)
    {
        const Umbra::A32::LocationDescriptor lhs_decoded { lhs };
        const Umbra::A32::LocationDescriptor rhs_decoded { rhs };
        return lhs_decoded.TFlag() == rhs_decoded.TFlag() &&
               lhs_decoded.EFlag() == rhs_decoded.EFlag() &&
               lhs_decoded.SingleStepping() == rhs_decoded.SingleStepping() &&
               lhs_decoded.FPSCR().Value() == rhs_decoded.FPSCR().Value();
    }

    [[nodiscard]] bool a32_location_in_block(
        Umbra::IR::LocationDescriptor candidate,
        Umbra::IR::LocationDescriptor start,
        Umbra::IR::LocationDescriptor end)
    {
        if (!canonical_a32_location(candidate) ||
            !aligned_a32_location(candidate) ||
            !a32_execution_mode_equal(candidate, start)) {
            return false;
        }
        const Umbra::A32::LocationDescriptor candidate_decoded { candidate };
        const Umbra::A32::LocationDescriptor start_decoded { start };
        const Umbra::A32::LocationDescriptor end_decoded { end };
        return candidate_decoded.PC() >= start_decoded.PC() &&
               candidate_decoded.PC() < end_decoded.PC();
    }

    [[nodiscard]] bool is_fp_opcode(Umbra::IR::Opcode opcode)
    {
        return opcode >= Umbra::IR::Opcode::FPAbs16 &&
               opcode <= Umbra::IR::Opcode::FPVectorToUnsignedFixed64;
    }

    [[nodiscard]] bool valid_fp_instruction(
        const EncodedInstruction& instruction,
        const Umbra::A32::LocationDescriptor& initial_location)
    {
        using Opcode = Umbra::IR::Opcode;
        if (!is_fp_opcode(instruction.opcode))
            return true;

        // Umbra's FP control operands are compile-time IR metadata. Several
        // x64 emitters dereference lookup tables or optional rounding encodings
        // directly, so a reference here is not merely semantically odd: it is
        // unsafe input.
        for (std::size_t argument = 0; argument < instruction.arguments.size();
            ++argument) {
            const auto expected =
                Umbra::IR::GetArgTypeOf(instruction.opcode, argument);
            if ((expected == Umbra::IR::Type::U1 ||
                    expected == Umbra::IR::Type::U8) &&
                !immediate_at(instruction, argument)) {
                return false;
            }
        }

        const auto rounding_valid = [](const EncodedValue& value) {
            return value.scalar <= 4U;
        };
        const auto fixed = [&](std::size_t bits) {
            return immediate_at(instruction, 1) &&
                   immediate_at(instruction, 2) &&
                   instruction.arguments[1].scalar <= bits &&
                   rounding_valid(instruction.arguments[2]);
        };
        const auto conversion = [&] {
            return immediate_at(instruction, 1) &&
                   instruction.arguments[1].scalar <= 3U;
        };

        switch (instruction.opcode) {
        case Opcode::FPRoundInt16:
        case Opcode::FPRoundInt32:
        case Opcode::FPRoundInt64:
        case Opcode::FPVectorRoundInt16:
        case Opcode::FPVectorRoundInt32:
        case Opcode::FPVectorRoundInt64:
            return rounding_valid(instruction.arguments[1]);

        case Opcode::FPHalfToDouble:
        case Opcode::FPHalfToSingle:
        case Opcode::FPSingleToDouble:
        case Opcode::FPDoubleToHalf:
        case Opcode::FPDoubleToSingle:
            return rounding_valid(instruction.arguments[1]);
        case Opcode::FPSingleToHalf:
            return conversion();

        case Opcode::FPDoubleToFixedS16:
        case Opcode::FPDoubleToFixedU16:
        case Opcode::FPHalfToFixedS16:
        case Opcode::FPHalfToFixedU16:
        case Opcode::FPSingleToFixedS16:
        case Opcode::FPSingleToFixedU16:
            return fixed(16U);
        case Opcode::FPDoubleToFixedS32:
        case Opcode::FPDoubleToFixedU32:
        case Opcode::FPHalfToFixedS32:
        case Opcode::FPHalfToFixedU32:
        case Opcode::FPSingleToFixedS32:
        case Opcode::FPSingleToFixedU32:
            return fixed(32U);
        case Opcode::FPDoubleToFixedS64:
        case Opcode::FPDoubleToFixedU64:
        case Opcode::FPHalfToFixedS64:
        case Opcode::FPHalfToFixedU64:
        case Opcode::FPSingleToFixedS64:
        case Opcode::FPSingleToFixedU64:
            return fixed(64U);

        case Opcode::FPFixedU16ToSingle:
        case Opcode::FPFixedS16ToSingle:
        case Opcode::FPFixedU16ToDouble:
        case Opcode::FPFixedS16ToDouble:
            return fixed(16U);
        case Opcode::FPFixedU32ToSingle:
        case Opcode::FPFixedS32ToSingle:
        case Opcode::FPFixedU32ToDouble:
        case Opcode::FPFixedS32ToDouble:
            if (!fixed(32U))
                return false;
            if (instruction.opcode == Opcode::FPFixedU32ToSingle ||
                instruction.opcode == Opcode::FPFixedS32ToSingle) {
                const auto rounding = instruction.arguments[2].scalar;
                return rounding == static_cast<std::uint8_t>(
                                       initial_location.FPSCR().RMode()) ||
                       rounding == 0U;
            }
            return true;
        case Opcode::FPFixedU64ToDouble:
        case Opcode::FPFixedU64ToSingle:
        case Opcode::FPFixedS64ToDouble:
        case Opcode::FPFixedS64ToSingle:
            return fixed(64U) && instruction.arguments[2].scalar ==
                                     static_cast<std::uint8_t>(
                                         initial_location.FPSCR().RMode());

        case Opcode::FPVectorFromSignedFixed32:
        case Opcode::FPVectorFromUnsignedFixed32:
        case Opcode::FPVectorFromSignedFixed64:
        case Opcode::FPVectorFromUnsignedFixed64: {
            const std::size_t bits =
                instruction.opcode == Opcode::FPVectorFromSignedFixed32 ||
                        instruction.opcode ==
                            Opcode::FPVectorFromUnsignedFixed32
                    ? 32U
                    : 64U;
            if (!fixed(bits) || !immediate_at(instruction, 3))
                return false;
            const auto required_rounding =
                instruction.arguments[3].scalar != 0U
                    ? static_cast<std::uint8_t>(
                          initial_location.FPSCR().RMode())
                    : 0U;
            return instruction.arguments[2].scalar == required_rounding;
        }

        case Opcode::FPVectorToSignedFixed16:
        case Opcode::FPVectorToUnsignedFixed16:
            return fixed(16U) && immediate_at(instruction, 3);
        case Opcode::FPVectorToSignedFixed32:
        case Opcode::FPVectorToUnsignedFixed32:
            return fixed(32U) && immediate_at(instruction, 3);
        case Opcode::FPVectorToSignedFixed64:
        case Opcode::FPVectorToUnsignedFixed64:
            return fixed(64U) && immediate_at(instruction, 3);

        case Opcode::FPVectorFromHalf32:
            return rounding_valid(instruction.arguments[1]);
        case Opcode::FPVectorToHalf32:
            return conversion();
        default:
            return true;
        }
    }

    [[nodiscard]] bool valid_vector_instruction(
        const EncodedInstruction& instruction)
    {
        using Opcode = Umbra::IR::Opcode;
        const auto immediate_below = [&](std::size_t argument,
                                         std::uint64_t limit) {
            return immediate_at(instruction, argument) &&
                   instruction.arguments[argument].scalar < limit;
        };

        switch (instruction.opcode) {
        case Opcode::VectorGetElement8:
        case Opcode::VectorSetElement8:
        case Opcode::VectorBroadcastElementLower8:
        case Opcode::VectorBroadcastElement8:
            return immediate_below(1, 16U);
        case Opcode::VectorGetElement16:
        case Opcode::VectorSetElement16:
        case Opcode::VectorBroadcastElementLower16:
        case Opcode::VectorBroadcastElement16:
            return immediate_below(1, 8U);
        case Opcode::VectorGetElement32:
        case Opcode::VectorSetElement32:
        case Opcode::VectorBroadcastElementLower32:
        case Opcode::VectorBroadcastElement32:
            return immediate_below(1, 4U);
        case Opcode::VectorGetElement64:
        case Opcode::VectorSetElement64:
        case Opcode::VectorBroadcastElement64:
            return immediate_below(1, 2U);

        case Opcode::VectorExtract:
            return immediate_at(instruction, 2) &&
                   instruction.arguments[2].scalar <= 128U &&
                   instruction.arguments[2].scalar % 8U == 0U;
        case Opcode::VectorExtractLower:
            return immediate_at(instruction, 2) &&
                   instruction.arguments[2].scalar <= 64U &&
                   instruction.arguments[2].scalar % 8U == 0U;

        case Opcode::VectorArithmeticShiftRight8:
        case Opcode::VectorArithmeticShiftRight16:
        case Opcode::VectorArithmeticShiftRight32:
        case Opcode::VectorArithmeticShiftRight64:
        case Opcode::VectorLogicalShiftLeft8:
        case Opcode::VectorLogicalShiftLeft16:
        case Opcode::VectorLogicalShiftLeft32:
        case Opcode::VectorLogicalShiftLeft64:
        case Opcode::VectorLogicalShiftRight8:
        case Opcode::VectorLogicalShiftRight16:
        case Opcode::VectorLogicalShiftRight32:
        case Opcode::VectorLogicalShiftRight64:
            return immediate_at(instruction, 1);

        case Opcode::VectorSignedSaturatedShiftLeftUnsigned8:
            return immediate_below(1, 8U);
        case Opcode::VectorSignedSaturatedShiftLeftUnsigned16:
            return immediate_below(1, 16U);
        case Opcode::VectorSignedSaturatedShiftLeftUnsigned32:
            return immediate_below(1, 32U);
        case Opcode::VectorSignedSaturatedShiftLeftUnsigned64:
            return immediate_below(1, 64U);

        case Opcode::VectorRotateWholeVectorRight:
            return immediate_at(instruction, 1) &&
                   instruction.arguments[1].scalar % 32U == 0U;
        case Opcode::VectorTranspose8:
        case Opcode::VectorTranspose16:
        case Opcode::VectorTranspose32:
        case Opcode::VectorTranspose64:
            return immediate_at(instruction, 2);
        case Opcode::SHA256Hash:
            return immediate_at(instruction, 3);
        default:
            return true;
        }
    }

    [[nodiscard]] std::optional<EncodedValue> encode_value(
        const Umbra::IR::Value& value,
        const std::unordered_map<const Umbra::IR::Inst*, std::uint32_t>&
            indices)
    {
        if (!value.IsImmediate() || value.IsIdentity()) {
            const auto* instruction = value.GetInst();
            const auto found = indices.find(instruction);
            if (found == indices.end())
                return std::nullopt;
            return EncodedValue { ValueTag::Reference,
                Umbra::IR::Type::Opaque, found->second, 0, { } };
        }

        const auto type = value.GetType();
        if (!valid_value_type(type))
            return std::nullopt;
        EncodedValue encoded { ValueTag::Immediate, type };
        switch (type) {
        case Umbra::IR::Type::U1:
            encoded.scalar = value.GetU1() ? 1U : 0U;
            break;
        case Umbra::IR::Type::U8:
            encoded.scalar = value.GetU8();
            break;
        case Umbra::IR::Type::U16:
            encoded.scalar = value.GetU16();
            break;
        case Umbra::IR::Type::U32:
            encoded.scalar = value.GetU32();
            break;
        case Umbra::IR::Type::U64:
            encoded.scalar = value.GetU64();
            break;
        case Umbra::IR::Type::A32Reg:
            encoded.scalar = static_cast<std::uint32_t>(value.GetA32RegRef());
            break;
        case Umbra::IR::Type::A32ExtReg:
            encoded.scalar =
                static_cast<std::uint32_t>(value.GetA32ExtRegRef());
            break;
        case Umbra::IR::Type::A64Reg:
            encoded.scalar = static_cast<std::uint32_t>(value.GetA64RegRef());
            break;
        case Umbra::IR::Type::A64Vec:
            encoded.scalar = static_cast<std::uint32_t>(value.GetA64VecRef());
            break;
        case Umbra::IR::Type::CoprocInfo: {
            const auto info = value.GetCoprocInfo();
            std::copy(info.begin(), info.end(), encoded.coprocessor.begin());
            break;
        }
        case Umbra::IR::Type::NZCVFlags:
            break;
        case Umbra::IR::Type::Cond:
            encoded.scalar = static_cast<std::uint32_t>(value.GetCond());
            break;
        case Umbra::IR::Type::AccType:
            encoded.scalar = static_cast<std::uint32_t>(value.GetAccType());
            break;
        default:
            return std::nullopt;
        }
        return encoded;
    }

    void write_encoded_value(Writer& writer, const EncodedValue& value)
    {
        writer.byte(static_cast<std::uint8_t>(value.tag));
        if (value.tag == ValueTag::Reference) {
            writer.u32(value.reference);
            return;
        }
        writer.u16(static_cast<std::uint16_t>(value.type));
        switch (value.type) {
        case Umbra::IR::Type::U1:
        case Umbra::IR::Type::U8:
            writer.byte(static_cast<std::uint8_t>(value.scalar));
            break;
        case Umbra::IR::Type::U16:
            writer.u16(static_cast<std::uint16_t>(value.scalar));
            break;
        case Umbra::IR::Type::U32:
        case Umbra::IR::Type::A32Reg:
        case Umbra::IR::Type::A32ExtReg:
        case Umbra::IR::Type::A64Reg:
        case Umbra::IR::Type::A64Vec:
            writer.u32(static_cast<std::uint32_t>(value.scalar));
            break;
        case Umbra::IR::Type::U64:
            writer.u64(value.scalar);
            break;
        case Umbra::IR::Type::CoprocInfo:
            writer.raw(value.coprocessor);
            break;
        case Umbra::IR::Type::NZCVFlags:
            break;
        case Umbra::IR::Type::Cond:
        case Umbra::IR::Type::AccType:
            writer.byte(static_cast<std::uint8_t>(value.scalar));
            break;
        default:
            writer.byte(0xffU);
            break;
        }
    }

    [[nodiscard]] std::optional<EncodedValue> read_encoded_value(
        Reader& reader, std::size_t current_index)
    {
        std::uint8_t raw_tag { };
        if (!reader.byte(raw_tag))
            return std::nullopt;
        if (raw_tag == static_cast<std::uint8_t>(ValueTag::Reference)) {
            std::uint32_t reference { };
            if (!reader.u32(reference) || reference >= current_index) {
                return std::nullopt;
            }
            return EncodedValue { ValueTag::Reference,
                Umbra::IR::Type::Opaque, reference, 0, { } };
        }
        if (raw_tag != static_cast<std::uint8_t>(ValueTag::Immediate)) {
            return std::nullopt;
        }

        std::uint16_t raw_type { };
        if (!reader.u16(raw_type))
            return std::nullopt;
        const auto type = static_cast<Umbra::IR::Type>(raw_type);
        if (!valid_value_type(type))
            return std::nullopt;
        switch (type) {
        case Umbra::IR::Type::U1:
        case Umbra::IR::Type::U8: {
            std::uint8_t value { };
            if (!reader.byte(value) ||
                (type == Umbra::IR::Type::U1 && value > 1U)) {
                return std::nullopt;
            }
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        case Umbra::IR::Type::U16: {
            std::uint16_t value { };
            if (!reader.u16(value))
                return std::nullopt;
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        case Umbra::IR::Type::U32: {
            std::uint32_t value { };
            if (!reader.u32(value))
                return std::nullopt;
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        case Umbra::IR::Type::U64: {
            std::uint64_t value { };
            if (!reader.u64(value))
                return std::nullopt;
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        case Umbra::IR::Type::A32Reg:
        case Umbra::IR::Type::A32ExtReg:
        case Umbra::IR::Type::A64Reg:
        case Umbra::IR::Type::A64Vec: {
            std::uint32_t value { };
            if (!reader.u32(value))
                return std::nullopt;
            if (type == Umbra::IR::Type::A32Reg && value > 15U) {
                return std::nullopt;
            }
            if (type == Umbra::IR::Type::A32ExtReg && value > 79U) {
                return std::nullopt;
            }
            if ((type == Umbra::IR::Type::A64Reg ||
                    type == Umbra::IR::Type::A64Vec) &&
                value > 31U) {
                return std::nullopt;
            }
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        case Umbra::IR::Type::CoprocInfo: {
            std::array<std::uint8_t, 8> value { };
            if (!reader.raw(value))
                return std::nullopt;
            return EncodedValue { ValueTag::Immediate, type, 0, 0, value };
        }
        case Umbra::IR::Type::NZCVFlags:
            return EncodedValue { ValueTag::Immediate, type };
        case Umbra::IR::Type::Cond: {
            std::uint8_t value { };
            if (!reader.byte(value) || !valid_condition(value))
                return std::nullopt;
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        case Umbra::IR::Type::AccType: {
            std::uint8_t value { };
            if (!reader.byte(value) || !valid_acc_type(value))
                return std::nullopt;
            return EncodedValue { ValueTag::Immediate, type, 0, value, { } };
        }
        default:
            return std::nullopt;
        }
    }

    [[nodiscard]] bool valid_encoded_ir(
        Umbra::IR::LocationDescriptor location,
        Umbra::IR::LocationDescriptor end_location,
        Umbra::IR::Cond condition,
        const std::optional<Umbra::IR::LocationDescriptor>& condition_failed,
        std::uint64_t condition_failed_cycles, std::uint64_t cycles,
        const std::vector<EncodedInstruction>& instructions,
        const Umbra::IR::Terminal& terminal)
    {
        using Opcode = Umbra::IR::Opcode;
        using Type = Umbra::IR::Type;

        if (!canonical_a32_location(location) ||
            !aligned_a32_location(location) ||
            !canonical_a32_location(end_location) ||
            !aligned_a32_location(end_location) ||
            !a32_execution_mode_equal(end_location, location)) {
            return false;
        }
        const Umbra::A32::LocationDescriptor initial_location { location };
        const Umbra::A32::LocationDescriptor final_location { end_location };
        const auto pc_delta = static_cast<std::uint64_t>(final_location.PC()) -
                              static_cast<std::uint64_t>(initial_location.PC());
        if (final_location.PC() <= initial_location.PC() ||
            pc_delta > static_cast<std::uint64_t>(maximum_instructions) * 4U) {
            return false;
        }

        const auto maximum_cycle_count = static_cast<std::uint64_t>(
            std::numeric_limits<std::int32_t>::max());
        if (cycles == 0U || cycles >= maximum_cycle_count ||
            condition_failed_cycles >= maximum_cycle_count) {
            return false;
        }
        if ((condition == Umbra::IR::Cond::AL) != !condition_failed) {
            return false;
        }
        if (!condition_failed) {
            if (condition_failed_cycles != 0U)
                return false;
        } else {
            if (!canonical_a32_location(*condition_failed) ||
                !aligned_a32_location(*condition_failed) ||
                !a32_execution_mode_equal(*condition_failed, location)) {
                return false;
            }
            const Umbra::A32::LocationDescriptor failed {
                *condition_failed
            };
            if (failed.PC() <= initial_location.PC() ||
                failed.PC() > final_location.PC() ||
                condition_failed_cycles == 0U ||
                condition_failed_cycles > cycles) {
                return false;
            }
        }

        std::vector<std::size_t> use_counts(instructions.size());
        std::vector<std::size_t> last_uses(instructions.size());
        for (std::size_t index = 0; index < instructions.size(); ++index) {
            for (const auto& argument : instructions[index].arguments) {
                if (argument.tag == ValueTag::Reference) {
                    if (argument.reference >= instructions.size())
                        return false;
                    ++use_counts[argument.reference];
                    last_uses[argument.reference] = index;
                }
            }
        }

        bool has_set_check_bit = false;
        std::uint32_t previous_name = 0U;
        std::unordered_set<std::uint64_t> associated_pseudo_operations;
        associated_pseudo_operations.reserve(instructions.size());
        std::vector<std::size_t> live_expirations(instructions.size() + 1U);
        std::size_t live_values = 0U;

        for (std::size_t index = 0; index < instructions.size(); ++index) {
            if (live_expirations[index] > live_values)
                return false;
            live_values -= live_expirations[index];
            const auto& instruction = instructions[index];
            if (!emitter_safe_opcode(instruction.opcode) ||
                instruction.name == 0U || instruction.name <= previous_name ||
                instruction.name > maximum_instructions ||
                instruction.arguments.size() !=
                    Umbra::IR::GetNumArgsOf(instruction.opcode) ||
                instruction.arguments.size() > Umbra::IR::max_arg_count) {
                return false;
            }
            previous_name = instruction.name;

            if (use_counts[index] != 0U) {
                const auto result_type =
                    Umbra::IR::GetTypeOf(instruction.opcode);
                const bool allocated_value =
                    result_type == Type::U1 || result_type == Type::U8 ||
                    result_type == Type::U16 || result_type == Type::U32 ||
                    result_type == Type::U64 || result_type == Type::U128 ||
                    result_type == Type::NZCVFlags;
                if (allocated_value) {
                    if (++live_values > maximum_live_values ||
                        last_uses[index] >= instructions.size()) {
                        return false;
                    }
                    ++live_expirations[last_uses[index] + 1U];
                }
            }

            for (std::size_t argument_index = 0;
                argument_index < instruction.arguments.size();
                ++argument_index) {
                const auto& argument = instruction.arguments[argument_index];
                if (argument.tag == ValueTag::Reference &&
                    argument.reference >= index) {
                    return false;
                }
                const auto actual_type =
                    encoded_value_type(argument, instructions);
                const auto expected_type = Umbra::IR::GetArgTypeOf(
                    instruction.opcode, argument_index);
                if (!Umbra::IR::AreTypesCompatible(
                        actual_type, expected_type)) {
                    return false;
                }
                if (argument.tag == ValueTag::Immediate &&
                    argument.type == Type::NZCVFlags &&
                    !(instruction.opcode == Opcode::A32SetCpsrNZC &&
                        argument_index == 0U)) {
                    return false;
                }
            }

            if (!valid_fp_instruction(instruction, initial_location) ||
                !valid_vector_instruction(instruction)) {
                return false;
            }

            const auto ext_reg_in = [&](std::uint64_t first,
                                        std::uint64_t last) {
                return immediate_at(instruction, 0) &&
                       instruction.arguments[0].scalar >= first &&
                       instruction.arguments[0].scalar <= last;
            };
            switch (instruction.opcode) {
            case Opcode::A32GetRegister:
            case Opcode::A32SetRegister:
                if (!immediate_at(instruction, 0) ||
                    instruction.arguments[0].type != Type::A32Reg ||
                    instruction.arguments[0].scalar > 15U) {
                    return false;
                }
                break;
            case Opcode::A32GetExtendedRegister32:
            case Opcode::A32SetExtendedRegister32:
                if (!ext_reg_in(0U, 31U))
                    return false;
                break;
            case Opcode::A32GetExtendedRegister64:
            case Opcode::A32SetExtendedRegister64:
                if (!ext_reg_in(32U, 63U))
                    return false;
                break;
            case Opcode::A32GetVector:
            case Opcode::A32SetVector:
                if (!ext_reg_in(32U, 79U))
                    return false;
                break;
            default:
                break;
            }

            if (a32_memory_opcode(instruction.opcode)) {
                if (!immediate_at(instruction, 0) ||
                    !a32_location_in_block(
                        Umbra::IR::LocationDescriptor {
                            instruction.arguments[0].scalar },
                        location, end_location)) {
                    return false;
                }
            }

            switch (instruction.opcode) {
            case Opcode::PushRSB: {
                if (!immediate_at(instruction, 0))
                    return false;
                const Umbra::IR::LocationDescriptor target {
                    instruction.arguments[0].scalar
                };
                if (!canonical_a32_location(target) ||
                    !aligned_a32_location(target)) {
                    return false;
                }
                break;
            }
            case Opcode::TestBit:
                if (!immediate_at(instruction, 1) ||
                    instruction.arguments[1].scalar >= 64U) {
                    return false;
                }
                break;
            case Opcode::ExtractRegister32:
                if (!immediate_at(instruction, 2) ||
                    instruction.arguments[2].scalar >= 32U) {
                    return false;
                }
                break;
            case Opcode::ExtractRegister64:
                if (!immediate_at(instruction, 2) ||
                    instruction.arguments[2].scalar >= 64U) {
                    return false;
                }
                break;
            case Opcode::ReplicateBit32:
                if (!immediate_at(instruction, 1) ||
                    instruction.arguments[1].scalar >= 32U) {
                    return false;
                }
                break;
            case Opcode::ReplicateBit64:
                if (!immediate_at(instruction, 1) ||
                    instruction.arguments[1].scalar >= 64U) {
                    return false;
                }
                break;
            case Opcode::SignedSaturation:
                if (!immediate_at(instruction, 1) ||
                    instruction.arguments[1].scalar == 0U ||
                    instruction.arguments[1].scalar > 32U) {
                    return false;
                }
                break;
            case Opcode::UnsignedSaturation:
                if (!immediate_at(instruction, 1) ||
                    instruction.arguments[1].scalar > 31U) {
                    return false;
                }
                break;
            case Opcode::A32SetGEFlags:
                if (immediate_at(instruction, 0))
                    return false;
                break;
            case Opcode::A32SetCpsrNZCV:
            case Opcode::A32SetCpsrNZ:
            case Opcode::A32SetFpscrNZCV:
                if (immediate_at(instruction, 0))
                    return false;
                break;
            case Opcode::A32ExceptionRaised:
                if (!immediate_at(instruction, 0) ||
                    !immediate_at(instruction, 1)) {
                    return false;
                }
                break;
            case Opcode::A32SetCheckBit:
                has_set_check_bit = true;
                break;
            default:
                break;
            }

            const auto validate_associated_pseudo = [&](auto parent_predicate) {
                const auto& parent = instruction.arguments[0];
                if (parent.tag != ValueTag::Reference ||
                    !parent_predicate(instructions[parent.reference].opcode)) {
                    return false;
                }
                const auto key =
                    (static_cast<std::uint64_t>(parent.reference) << 32U) |
                    static_cast<std::uint32_t>(instruction.opcode);
                return associated_pseudo_operations.insert(key).second;
            };

            switch (instruction.opcode) {
            case Opcode::GetCarryFromOp:
                if (!validate_associated_pseudo(carry_parent))
                    return false;
                break;
            case Opcode::GetOverflowFromOp:
                if (!validate_associated_pseudo(overflow_parent))
                    return false;
                break;
            case Opcode::GetGEFromOp:
                if (!validate_associated_pseudo(ge_parent))
                    return false;
                break;
            case Opcode::GetUpperFromOp:
            case Opcode::GetLowerFromOp:
                if (!validate_associated_pseudo(upper_lower_parent))
                    return false;
                break;
            case Opcode::GetNZCVFromOp: {
                const auto& value = instruction.arguments[0];
                if (value.tag == ValueTag::Reference) {
                    if (!nzcv_parent(instructions[value.reference].opcode))
                        return false;
                } else if (!encoded_is_scalar(value, instructions)) {
                    return false;
                }
                break;
            }
            case Opcode::GetNZFromOp:
                if (!encoded_is_scalar(
                        instruction.arguments[0], instructions)) {
                    return false;
                }
                break;
            case Opcode::VectorTable: {
                if (use_counts[index] != 1U)
                    return false;
                std::optional<Type> element_type;
                for (const auto& value : instruction.arguments) {
                    if (value.tag != ValueTag::Reference)
                        return false;
                    const auto type = encoded_value_type(value, instructions);
                    if (type != Type::U64 && type != Type::U128)
                        return false;
                    if (element_type && *element_type != type)
                        return false;
                    element_type = type;
                }
                break;
            }
            case Opcode::VectorTableLookup64:
            case Opcode::VectorTableLookup128: {
                const auto& table = instruction.arguments[1];
                if (table.tag != ValueTag::Reference ||
                    instructions[table.reference].opcode !=
                        Opcode::VectorTable) {
                    return false;
                }
                const auto required_type =
                    instruction.opcode == Opcode::VectorTableLookup64
                        ? Type::U64
                        : Type::U128;
                for (const auto& table_value :
                    instructions[table.reference].arguments) {
                    if (encoded_value_type(table_value, instructions) !=
                        required_type) {
                        return false;
                    }
                }
                break;
            }
            default:
                break;
            }
        }

        return valid_terminal(terminal, initial_location, has_set_check_bit);
    }

    [[nodiscard]] std::optional<Umbra::IR::Value> decode_value(
        const EncodedValue& encoded,
        const std::vector<Umbra::IR::Inst*>& instructions)
    {
        if (encoded.tag == ValueTag::Reference) {
            if (encoded.reference >= instructions.size())
                return std::nullopt;
            return Umbra::IR::Value { instructions[encoded.reference] };
        }
        switch (encoded.type) {
        case Umbra::IR::Type::U1:
            return Umbra::IR::Value { encoded.scalar != 0 };
        case Umbra::IR::Type::U8:
            return Umbra::IR::Value { static_cast<std::uint8_t>(
                encoded.scalar) };
        case Umbra::IR::Type::U16:
            return Umbra::IR::Value { static_cast<std::uint16_t>(
                encoded.scalar) };
        case Umbra::IR::Type::U32:
            return Umbra::IR::Value { static_cast<std::uint32_t>(
                encoded.scalar) };
        case Umbra::IR::Type::U64:
            return Umbra::IR::Value { encoded.scalar };
        case Umbra::IR::Type::A32Reg:
            return Umbra::IR::Value { static_cast<Umbra::A32::Reg>(
                encoded.scalar) };
        case Umbra::IR::Type::A32ExtReg:
            return Umbra::IR::Value { static_cast<Umbra::A32::ExtReg>(
                encoded.scalar) };
        case Umbra::IR::Type::A64Reg:
            return Umbra::IR::Value { static_cast<Umbra::A64::Reg>(
                encoded.scalar) };
        case Umbra::IR::Type::A64Vec:
            return Umbra::IR::Value { static_cast<Umbra::A64::Vec>(
                encoded.scalar) };
        case Umbra::IR::Type::CoprocInfo:
            return Umbra::IR::Value { Umbra::IR::Value::CoprocessorInfo {
                encoded.coprocessor } };
        case Umbra::IR::Type::NZCVFlags:
            return Umbra::IR::Value::EmptyNZCVImmediateMarker();
        case Umbra::IR::Type::Cond:
            return Umbra::IR::Value { static_cast<Umbra::IR::Cond>(
                encoded.scalar) };
        case Umbra::IR::Type::AccType:
            return Umbra::IR::Value { static_cast<Umbra::IR::AccType>(
                encoded.scalar) };
        default:
            return std::nullopt;
        }
    }

    [[nodiscard]] bool append_instruction(Umbra::IR::Block& block,
        Umbra::IR::Opcode opcode,
        const std::vector<Umbra::IR::Value>& args)
    {
        switch (args.size()) {
        case 0:
            block.AppendNewInst(opcode, { });
            return true;
        case 1:
            block.AppendNewInst(opcode, { args[0] });
            return true;
        case 2:
            block.AppendNewInst(opcode, { args[0], args[1] });
            return true;
        case 3:
            block.AppendNewInst(opcode, { args[0], args[1], args[2] });
            return true;
        case 4:
            block.AppendNewInst(opcode, { args[0], args[1], args[2], args[3] });
            return true;
        default:
            return false;
        }
    }

} // namespace

std::optional<std::vector<std::byte>> serialize_umbra_ir(
    const Umbra::IR::Block& block)
{
    Writer writer;
    writer.raw(magic);
    writer.u32(format_version);
    write_location(writer, block.Location());
    write_location(writer, block.EndLocation());
    writer.byte(static_cast<std::uint8_t>(block.GetCondition()));
    writer.byte(block.HasConditionFailedLocation() ? 1U : 0U);
    if (block.HasConditionFailedLocation()) {
        write_location(writer, block.ConditionFailedLocation());
    }
    writer.u64(static_cast<std::uint64_t>(block.ConditionFailedCycleCount()));
    writer.u64(static_cast<std::uint64_t>(block.CycleCount()));

    if (block.size() > maximum_instructions)
        return std::nullopt;
    writer.u32(static_cast<std::uint32_t>(block.size()));
    std::unordered_map<const Umbra::IR::Inst*, std::uint32_t> indices;
    indices.reserve(block.size());
    std::uint32_t index = 0;
    for (const auto& instruction : block) {
        indices.emplace(&instruction, index++);
    }
    for (const auto& instruction : block) {
        writer.u32(static_cast<std::uint32_t>(instruction.GetOpcode()));
        writer.u32(instruction.GetName());
        const auto argument_count = instruction.NumArgs();
        if (argument_count > Umbra::IR::max_arg_count)
            return std::nullopt;
        writer.byte(static_cast<std::uint8_t>(argument_count));
        for (std::size_t argument = 0; argument < argument_count; ++argument) {
            const auto encoded =
                encode_value(instruction.GetArg(argument), indices);
            if (!encoded)
                return std::nullopt;
            write_encoded_value(writer, *encoded);
        }
    }
    write_terminal(writer, block.GetTerminal(), 0);
    if (!writer.valid())
        return std::nullopt;
    return std::move(writer).take();
}

std::optional<Umbra::IR::Block> deserialize_umbra_ir(
    std::span<const std::byte> bytes)
{
    if (bytes.empty() || bytes.size() > maximum_bytes)
        return std::nullopt;
    Reader reader { bytes };
    std::array<std::uint8_t, magic.size()> actual_magic { };
    if (!reader.raw(actual_magic) || actual_magic != magic)
        return std::nullopt;
    std::uint32_t version { };
    if (!reader.u32(version) || version != format_version)
        return std::nullopt;

    Umbra::IR::LocationDescriptor location { 0 };
    Umbra::IR::LocationDescriptor end_location { 0 };
    if (!read_location(reader, location) ||
        !read_location(reader, end_location)) {
        return std::nullopt;
    }
    std::uint8_t condition { };
    std::uint8_t has_condition_failed { };
    if (!reader.byte(condition) || !valid_condition(condition) ||
        !reader.byte(has_condition_failed) || has_condition_failed > 1U) {
        return std::nullopt;
    }
    std::optional<Umbra::IR::LocationDescriptor> condition_failed;
    if (has_condition_failed != 0) {
        Umbra::IR::LocationDescriptor value { 0 };
        if (!read_location(reader, value))
            return std::nullopt;
        condition_failed = value;
    }
    std::uint64_t condition_failed_cycles { };
    std::uint64_t cycles { };
    if (!reader.u64(condition_failed_cycles) || !reader.u64(cycles) ||
        condition_failed_cycles > std::numeric_limits<std::size_t>::max() ||
        cycles > std::numeric_limits<std::size_t>::max()) {
        return std::nullopt;
    }
    std::uint32_t instruction_count { };
    if (!reader.u32(instruction_count) ||
        instruction_count > maximum_instructions) {
        return std::nullopt;
    }

    std::vector<EncodedInstruction> encoded_instructions;
    encoded_instructions.reserve(instruction_count);
    for (std::uint32_t index = 0; index < instruction_count; ++index) {
        std::uint32_t raw_opcode { };
        std::uint32_t name { };
        std::uint8_t argument_count { };
        if (!reader.u32(raw_opcode) || !reader.u32(name) ||
            !reader.byte(argument_count) ||
            raw_opcode >= Umbra::IR::OpcodeCount ||
            argument_count !=
                Umbra::IR::GetNumArgsOf(
                    static_cast<Umbra::IR::Opcode>(raw_opcode)) ||
            argument_count > Umbra::IR::max_arg_count) {
            return std::nullopt;
        }
        const auto opcode = static_cast<Umbra::IR::Opcode>(raw_opcode);
        EncodedInstruction instruction { opcode, name, { } };
        instruction.arguments.reserve(argument_count);
        for (std::uint8_t argument = 0; argument < argument_count; ++argument) {
            auto value = read_encoded_value(reader, index);
            if (!value)
                return std::nullopt;
            instruction.arguments.push_back(std::move(*value));
        }
        encoded_instructions.push_back(std::move(instruction));
    }

    auto terminal = read_terminal(reader, 0);
    if (!terminal || !reader.at_end() || terminal->which() == 0) {
        return std::nullopt;
    }
    if (!valid_encoded_ir(location, end_location,
            static_cast<Umbra::IR::Cond>(condition), condition_failed,
            condition_failed_cycles, cycles, encoded_instructions, *terminal)) {
        return std::nullopt;
    }

    // No Umbra IR object is touched until every byte and every x64 emitter
    // precondition above has been checked without assertions. The construction
    // calls below therefore only receive producer-shaped data.
    Umbra::IR::Block block { location };
    std::vector<Umbra::IR::Inst*> instructions;
    instructions.reserve(encoded_instructions.size());
    for (const auto& encoded_instruction : encoded_instructions) {
        std::vector<Umbra::IR::Value> arguments;
        arguments.reserve(encoded_instruction.arguments.size());
        for (const auto& encoded_argument : encoded_instruction.arguments) {
            auto value = decode_value(encoded_argument, instructions);
            if (!value)
                return std::nullopt;
            arguments.push_back(std::move(*value));
        }
        if (!append_instruction(block, encoded_instruction.opcode, arguments)) {
            return std::nullopt;
        }
        block.back().SetName(encoded_instruction.name);
        instructions.push_back(&block.back());
    }
    block.SetEndLocation(end_location);
    block.SetCondition(static_cast<Umbra::IR::Cond>(condition));
    if (condition_failed)
        block.SetConditionFailedLocation(*condition_failed);
    block.ConditionFailedCycleCount() =
        static_cast<std::size_t>(condition_failed_cycles);
    block.CycleCount() = static_cast<std::size_t>(cycles);
    block.SetTerminal(std::move(*terminal));
    return block;
}

bool validate_umbra_ir(std::span<const std::byte> bytes)
{
    return deserialize_umbra_ir(bytes).has_value();
}

} // namespace shade
