#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <sstream>
#include <cassert>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/SourceMgr.h"

using namespace llvm;

extern "C" typedef void (*air2cpu_barrier_fn)(void *context, uint32_t tid, uint32_t threads);
#include "../../packages/frameworks/apple-backports/air2cpu-abi.h"

namespace {

struct Refusal {
    std::string name;
    std::string reason;
};

class Emitter {
public:
    Emitter(Function &kernel, std::vector<Refusal> &refusals) : kernel_(kernel), refusals_(refusals) {
        collect();
    }

    static bool vectorOf(Type *type, std::string &out, uint64_t &size, unsigned &count)
    {
        VectorType *vector = dyn_cast<VectorType>(type);
        if (!vector)
            return false;
        count = (unsigned)cast<FixedVectorType>(vector)->getNumElements();
        if (count < 2 || count > 4)
            return false;
        std::string element;
        uint64_t elementSize;
        if (!typeOf(vector->getElementType(), element, elementSize))
            return false;
        out = "revenant_v" + std::to_string(count) + "i";
        size = elementSize * count;
        return true;
    }

    static bool typeOf(Type *type, std::string &out, uint64_t &size) {
        unsigned count;
        if (vectorOf(type, out, size, count))
            return true;
        if (type->isIntegerTy(1)) { out = "int32_t"; size = 4; return true; }
        if (type->isIntegerTy(8)) { out = "uint8_t"; size = 1; return true; }
        if (type->isIntegerTy(16)) { out = "uint16_t"; size = 2; return true; }
        if (type->isIntegerTy(32)) { out = "uint32_t"; size = 4; return true; }
        if (type->isIntegerTy(64)) { out = "uint64_t"; size = 8; return true; }
        if (type->isFloatTy()) { out = "float"; size = 4; return true; }
        if (type->isHalfTy()) { out = "uint16_t"; size = 2; return true; }
        if (type->isPointerTy()) { out = "void *"; size = 8; return true; }
        return false;
    }

    bool emit(std::string &body) {
        size_t refusedBefore = refusals_.size();
        for (Value &argument : kernel_.args()) {
            if (getenv("AIR2CPU_PRINT_SLOTS") && reportedArgument_ >= 0)
                printf("air2cpu: %s: argument %d type %s left by %s\n",
                       kernel_.getName().str().c_str(), reportedArgument_, reportedType_, leftBy_);
            reportedType_ = argument.getType()->isPointerTy() ? "pointer"
                          : argument.getType()->isVectorTy() ? "vector" : "scalar";
            reportedArgument_ = ((Argument *)&argument)->getArgNo();
            leftBy_ = "the end of the loop";
            if (argument.getType()->isPointerTy()) {
                if (argument.getType()->getPointerAddressSpace() == 1) {
                    buffers_.push_back(&argument);
                    leftBy_ = "the BUFFER branch";
                    continue;
                }
                if (argument.getType()->getPointerAddressSpace() == 3) {
                    block_ = &argument;
                    leftBy_ = "the BLOCK branch";
                    continue;
                }
                return refuse("an argument in address space " + std::to_string(argument.getType()->getPointerAddressSpace()) +
                              " that is neither a buffer nor threadgroup memory");
            }
            bool oneOfThree = argument.getType()->isVectorTy() || argument.getType()->isIntegerTy(32);
            if (getenv("AIR2CPU_PRINT_SLOTS")) {
                std::string seen;
                uint64_t ignored;
                bool held = typeOf(argument.getType(), seen, ignored);
                printf("air2cpu: %s: argument %u type %s vector=%d i32=%d typeOf=%d taken=%d scalars=%lu\n",
                       kernel_.getName().str().c_str(), ((Argument *)&argument)->getArgNo(),
                       argument.getType()->isPointerTy() ? "ptr" : (argument.getType()->isVectorTy() ? "vector" : "scalar"),
                       (int)argument.getType()->isVectorTy(), (int)argument.getType()->isIntegerTy(32),
                       (int)held, (int)(oneOfThree && held), (unsigned long)scalars_.size());
            }
            leftBy_ = "the THREE branch";
            if (oneOfThree && scalars_.size() >= 3)
                return refuse("a fourth scalar where the call convention carries three: the thread "
                              "position, the threadgroup position and the group size");
            std::string type;
            uint64_t size;
            if (oneOfThree && typeOf(argument.getType(), type, size)) {
                unsigned slot = (unsigned)scalars_.size();
                scalarSlot_[&argument] = slot;
                scalars_.push_back(&argument);
                if (getenv("AIR2CPU_PRINT_SLOTS"))
                    printf("air2cpu: %s: argument %u of %u is scalar %u of the three (thread, group, size)\n",
                           kernel_.getName().str().c_str(), ((Argument *)&argument)->getArgNo(),
                           (unsigned)kernel_.arg_size(), slot);
                continue;
            }
            leftBy_ = "the OTHER branch";
            if (typeOf(argument.getType(), type, size)) {
                other_.push_back(&argument);
                continue;
            }
            leftBy_ = "the REFUSAL";
            return refuse("an argument of a type this port does not hold in a kernel");
        }
        if (getenv("AIR2CPU_PRINT_SLOTS") && reportedArgument_ >= 0)
            printf("air2cpu: %s: argument %d type %s left by %s\n",
                   kernel_.getName().str().c_str(), reportedArgument_, reportedType_, leftBy_);
        reportedArgument_ = -1;
        std::string code = dispatch();
        if (code.empty())
            return refuse("nothing of the body could be translated, which is a kernel that would compute nothing");
        if (refusals_.size() > refusedBefore) {
            refuse("part of the body could not be translated, so what was emitted would not be the kernel");
            return false;
        }
        body = header() + locals() + code + "}\n";
        return true;
    }

    std::string entryName() const { return kernel_.getName().str(); }
    uint32_t bufferCount() const { return (uint32_t)buffers_.size(); }
    uint32_t blockBytes() const { return blockBytes_; }

private:
    std::string claim(const char *prefix, unsigned number) {
        char text[32];
        snprintf(text, sizeof(text), "%s%u", prefix, number);
        std::string name = text;
        bool fresh = taken_.insert(name).second;
        if (!fresh)
            fprintf(stderr, "claim: %s handed out twice (kind %s, index %u)\n", name.c_str(), prefix, number);
        assert(fresh && "the emitter handed out a C name twice");
        (void)fresh;
        return name;
    }

    void collect() {
        for (Argument &argument : kernel_.args())
            names_["%arg:" + std::to_string(argument.getArgNo())] = "arg" + std::to_string(argument.getArgNo());
        unsigned index = 0;
        for (const NamedMDNode &table : kernel_.getParent()->named_metadata())
            for (const MDNode *entry : table.operands()) {
                if (!entry)
                    continue;
                for (unsigned operand = 0; operand + 2 < entry->getNumOperands(); operand++) {
                    const MDString *name = dyn_cast_or_null<MDString>(entry->getOperand(operand));
                    if (!name || name->getString() != "air.threadgroup")
                        continue;
                    if (const ConstantInt *size = mdconst::dyn_extract_or_null<ConstantInt>(entry->getOperand(operand + 2)))
                        blockBytes_ = (uint32_t)size->getZExtValue();
                }
            }
        for (BasicBlock &block : kernel_) for (Instruction &instruction : block) {
            if (instruction.hasName()) {
                names_[instruction.getName().str()] = claim("v", index);
            } else {
                unnamedNames_[&instruction] = claim("t", (unsigned)unnamed_.size());
                unnamed_.push_back(&instruction);
            }
            index++;
        }
    }

    std::string nameOf(Value &value) {
        if (Argument *argument = dyn_cast<Argument>(&value)) {
            unsigned index = argumentNo(argument);
            if (index < buffers_.size())
                return buffers_[index]->getName().str().empty()
                         ? "buffer" + std::to_string(index)
                         : buffers_[index]->getName().str();
            if (block_ == argument)
                return "block";
            auto found = scalarSlot_.find((Value *)argument);
            if (getenv("AIR2CPU_PRINT_SLOTS") && found == scalarSlot_.end()) {
                printf("air2cpu: %s: looking up argument %u at %p; the map holds",
                       kernel_.getName().str().c_str(), ((Argument *)argument)->getArgNo(), (void *)argument);
                if (scalarSlot_.empty())
                    printf(" NOTHING\n");
                else
                    for (const auto &entry : scalarSlot_)
                        printf(" %u->%p=%u", ((Argument *)entry.first)->getArgNo(), (void *)entry.first, entry.second);
                printf("\n");
            }
            unsigned slot = found == scalarSlot_.end() ? 0 : found->second;
            const char *vectors[] = {"thread", "group", "size"};
            return std::string(vectors[slot < 3 ? slot : 2]) + (argument->getType()->isVectorTy() ? "" : ".x");
        }
        if (Instruction *instruction = dyn_cast<Instruction>(&value)) {
            auto slot = slotsOf_.find(instruction);
            if (slot != slotsOf_.end())
                return "(&" + slot->second + ")";
            auto given = unnamedNames_.find(instruction);
            if (given != unnamedNames_.end())
                return given->second;
            if (instruction->hasName())
                return names_[instruction->getName().str()];
            return "0";
        }
        if (ConstantInt *constant = dyn_cast<ConstantInt>(&value)) {
            std::string text;
            raw_string_ostream stream(text);
            constant->getValue().print(stream, false);
            return stream.str();
        }
        if (ConstantFP *constant = dyn_cast<ConstantFP>(&value)) {
            char text[64];
            snprintf(text, sizeof(text), "%.9gf", constant->getValueAPF().convertToFloat());
            for (char *at = text; *at; at++)
                if (*at == 'f') {
                    if (at == text || at[-1] == '.')
                        memmove(at + 1, at, strlen(at) + 1), at[1] = '.';
                    *at = 0;
                    break;
                }
            return text;
        }
        if (isa<ConstantPointerNull>(&value))
            return "0";
        if (ConstantDataSequential *sequence = dyn_cast<ConstantDataSequential>(&value))
            if (sequence->isCString())
                return "\"" + sequence->getAsCString().str() + "\"";
        refuse("a value this port does not translate");
        return "";
    }

    unsigned argumentNo(Value *argument) {
        for (unsigned index = 0; index < kernel_.arg_size(); index++)
            if (kernel_.getArg(index) == argument)
                return index;
        return 0;
    }

    unsigned indexOf(Instruction *instruction) {
        for (unsigned index = 0; index < unnamed_.size(); index++)
            if (unnamed_[index] == instruction)
                return index;
        return 0;
    }

    bool refuse(const std::string &reason) {
        refusals_.push_back({kernel_.getName().str(), reason});
        return false;
    }

    std::string header() {
        std::string out;
        out += "static void air2cpu_" + kernel_.getName().str() + "(void *const *buffers, revenant_v4i thread, revenant_v4i group, revenant_v4i size, char *block, uint32_t blockBytes, air2cpu_barrier_fn barrier, void *barrierContext)\n{\n";
        out += "    (void)blockBytes;\n";
        for (size_t index = 0; index < buffers_.size(); index++) {
            std::string name = buffers_[index]->getName().str();
            if (name.empty())
                name = "buffer" + std::to_string(index);
            out += "    void *" + name + " = buffers[" + std::to_string(index) + "];\n";
        }
        for (Value *value : other_)
            out += "    " + cType(value->getType()) + " " + nameOf(*value) + ";\n";
        return out;
    }

    static const char *memoryOrderOf(bool threadgroup, unsigned code)
    {
        if (threadgroup) {
            switch (code) {
            case 1: return "memory_order_relaxed";
            case 2: return "memory_order_acquire";
            case 3: return "memory_order_release";
            case 4: return "memory_order_acq_rel";
            case 5: return "memory_order_seq_cst";
            default: return nullptr;
            }
        }
        if (code == 2)
            return "memory_order_relaxed";
        return nullptr;
    }

static std::string emit_compare_exchange(const std::string &type, const std::string &slot,
                                        const std::string &expected, const std::string &desired,
                                        const std::string &success, const std::string &failure, bool weak)
{
    std::ostringstream line;
    line << "    { " << type << " expected_ = *(" << type << " *)" << expected
         << "; bool ok_ = __atomic_compare_exchange_n((volatile " << type << " *)" << slot
         << ", &expected_, (" << type << ")" << desired << ", " << (weak ? "true" : "false")
         << ", " << success << ", " << failure << "); *(" << type << " *)" << expected
         << " = expected_; }\n";
    return line.str();
}

    bool emitAtomic(CallInst *call, const std::string &called, std::string &out)
    {
        std::vector<std::string> parts;
        size_t at = 0;
        while (at < called.size()) {
            size_t next = called.find('.', at);
            parts.push_back(called.substr(at, next == std::string::npos ? std::string::npos : next - at));
            if (next == std::string::npos) { at = called.size(); break; }
            at = next + 1;
        }
        if (parts.size() < 5)
            return refuseBool("an atomic intrinsic this port does not read: " + called);
        std::string operation = parts[3];
        bool isSigned = parts[4] == "s";
        bool threadgroup = parts[2] == "local";
        unsigned successIndex = operation == "load" ? 2 : 3;
        auto orderArgument = [&](unsigned index, const char *&text) -> bool {
            if (index >= call->arg_size())
                return false;
            ConstantInt *constant = dyn_cast<ConstantInt>(call->getArgOperand(index));
            if (!constant)
                return false;
            text = memoryOrderOf(threadgroup, (unsigned)constant->getZExtValue());
            return text != nullptr;
        };
        const char *order = nullptr;
        if (!orderArgument(successIndex, order))
            return refuseBool("the memory order of " + called + ", at argument " + std::to_string(successIndex) +
                              ", which this port has not seen emitted and will not guess");
        std::string pointer = nameOf(*call->getArgOperand(0));
        std::string type = isSigned ? "int32_t" : "uint32_t";
        std::string value = call->arg_size() > 1 ? nameOf(*call->getArgOperand(1)) : "0";
        std::string result = nameOf(*call);
        if (operation == "load") {
            out += "    " + result + " = __atomic_load_n((volatile " + type + " *)" + pointer + ", " + order + ");\n";
            return true;
        }
        if (operation == "store") {
            if (std::string(order) != "memory_order_relaxed" && std::string(order) != "memory_order_release" &&
                std::string(order) != "memory_order_seq_cst")
                return refuseBool("the memory order " + std::string(order) + " of " + called +
                                  ", which a C atomic store may not take and which this port will not map onto one");
            out += "    __atomic_store_n((volatile " + type + " *)" + pointer + ", " + value + ", " + order + ");\n";
            return true;
        }
        if (operation == "cmpxchg") {
            std::string expected = nameOf(*call->getArgOperand(1));
            std::string desired = call->arg_size() > 2 ? nameOf(*call->getArgOperand(2)) : "0";
            std::string success = order, failure = order;
            const char *mapped = nullptr;
            if (orderArgument(4, mapped))
                failure = mapped;
            bool weak = parts[4] == "weak";
            out += emit_compare_exchange(type, pointer, expected, desired, success, failure, weak);
            return true;
        }
        if (operation == "xchg") {
            out += "    " + result + " = __atomic_exchange_n((volatile " + type + " *)" + pointer + ", ("
                   + type + ")" + value + ", " + order + ");\n";
            return true;
        }
        static const char *builtins[] = {"add", "sub", "and", "or", "xor"};
        for (const char *builtin : builtins)
            if (operation == builtin) {
                out += "    " + result + " = __atomic_fetch_" + builtin + "((volatile " + type + " *)" + pointer
                       + ", (" + type + ")" + value + ", " + order + ");\n";
                return true;
            }
        if ((operation == "min" || operation == "max") && isSigned) {
            out += "    " + result + " = __atomic_fetch_" + operation + "((volatile " + type + " *)" + pointer
                   + ", (" + type + ")" + value + ", " + order + ");\n";
            return true;
        }
        if (operation == "min" || operation == "max") {
            out += "    { " + type + " old_ = __atomic_load_n((volatile " + type + " *)" + pointer + ", "
                   + order + "); for (;;) { " + type + " next_ = ("
                   + (operation == "min" ? "old_ < (" : "old_ > (") + type + ")" + value + " ? old_ : ("
                   + type + ")" + value + "); "
                   + type + " seen_ = __atomic_compare_exchange_n((volatile " + type + " *)" + pointer + ", &old_, next_, false, "
                   + order + ", " + order + "); if (seen_ || !((" + (operation == "min" ? "old_ < (" : "old_ > (") + type + ")" + value
                   + " ? old_ : (" + type + ")" + value + "))) break; } " + result + " = old_; }\n";
            return true;
        }
        return refuseBool("the atomic operation " + operation + " of " + called + ", which this port does not map");
    }

    static std::string identifier(const std::string &text) {
        std::string out = "air2cpu_";
        for (char character : text)
            out += (isalnum((unsigned char)character) || character == '_') ? character : '_';
        return out;
    }

    std::string cType(Type *type) {
        std::string type_name;
        uint64_t size;
        return typeOf(type, type_name, size) ? type_name : "uint64_t";
    }

    std::string locals() {
        std::string out;
      for (BasicBlock &block : kernel_) for (Instruction &instruction : block) {
            std::string type;
            uint64_t size;
            if (!typeOf(instruction.getType(), type, size)) {
                if (instruction.getType()->isVoidTy())
                    continue;
                refuse("a value of a type this port does not hold in a kernel");
                break;
            }
            if (isa<AllocaInst>(&instruction))
                continue;
            bool named = instruction.hasName();
            if (named)
                out += "    " + type + " " + nameOf(instruction) + ";\n";
        }
        for (Instruction *instruction : unnamed_)
            out += "    " + cType(instruction->getType()) + " " + nameOf(*instruction) + ";\n";
        return out;
    }

    std::string dispatch() {
        std::string out = "    goto air2cpu_entry;\n";
        for (BasicBlock &block : kernel_) {
            out += identifier(block.getName().str()) + ":\n";
            for (Instruction &instruction : block) {
                std::string line;
                if (!emitInstruction(instruction, line)) {
                    std::string type;
                    uint64_t size;
                    if (CallInst *call = dyn_cast<CallInst>(&instruction))
                        refuse("a call to " + (call->getCalledFunction() ? call->getCalledFunction()->getName().str() : "an indirect target"));
                    else
                        refuse(std::string(instruction.getOpcodeName()) + " on a " +
                                (typeOf(instruction.getType(), type, size) ? type : std::string("value this port does not hold")));
                    return "";
                }
                out += line;
            }
        }
        return out;
    }

    bool assignPhis(BasicBlock &from, BasicBlock &to, const std::string &indent, std::string &out) {
        out.clear();
        for (Instruction &instruction : to) {
            PHINode *phi = dyn_cast<PHINode>(&instruction);
            if (!phi)
                break;
            int index = phi->getBasicBlockIndex(&from);
            if (index < 0)
                return refuseBool("a phi that does not say what this edge brings it");
            out += indent + nameOf(*phi) + " = " + nameOf(*phi->getIncomingValue(index)) + ";\n";
        }
        return true;
    }

    bool refuseBool(const std::string &reason) {
        refusals_.push_back({kernel_.getName().str(), reason});
        return false;
    }

    bool emitInstruction(Instruction &instruction, std::string &out) {
        if (isa<PHINode>(&instruction))
            return true;
        if (auto *load = dyn_cast<LoadInst>(&instruction)) {
            out += "    " + nameOf(*load) + " = *(" + cType(load->getType()) + " *)" + nameOf(*load->getPointerOperand()) + ";\n";
            return true;
        }
        if (auto *store = dyn_cast<StoreInst>(&instruction)) {
            out += "    *(" + cType(store->getValueOperand()->getType()) + " *)" + nameOf(*store->getPointerOperand()) +
                   " = " + nameOf(*store->getValueOperand()) + ";\n";
            return true;
        }
        if (auto *gep = dyn_cast<GetElementPtrInst>(&instruction)) {
            Type *element = gep->getSourceElementType();
            bool readable = element->isSized();
            if (StructType *fields = dyn_cast<StructType>(element))
                readable = readable && !fields->isOpaque();
            uint64_t size = readable ? kernel_.getParent()->getDataLayout().getTypeAllocSize(element) : 0;
            if (!size)
                return refuse("a getelementptr over a type the module's datalayout cannot give a size "
                              "for - " + std::string(readable ? "" : "unsized, or with no field list") +
                              " - and the stride would be a guess");
            unsigned chosen = 0;
            bool found = false;
            for (unsigned at = 0; at < gep->getNumIndices(); at++) {
                Value *operand = gep->getOperand(gep->getNumIndices() - at);
                if (!isa<ConstantInt>(operand))
                    break;
                if (at + 1 < gep->getNumIndices()) {
                    chosen = gep->getNumIndices() - 2;
                    found = true;
                    break;
                }
            }
            if (!found)
                for (unsigned at = 0; at < gep->getNumIndices(); at++)
                    if (!isa<ConstantInt>(gep->getOperand(gep->getNumIndices() - 1 - at)))
                        { chosen = gep->getNumIndices() - 1 - at; found = true; break; }
            if (!found)
                return refuse("a getelementptr with no varying index, whose offset would be a constant this "
                              "port will not invent");
            std::string index = nameOf(*gep->getOperand(chosen + 1));
            out += "    " + nameOf(*gep) + " = (char *)" + nameOf(*gep->getPointerOperand()) + " + (" + index + ") * " +
                   std::to_string(size) + ";\n";
            return true;
        }
        if (auto *binary = dyn_cast<BinaryOperator>(&instruction)) {
            const char *op = nullptr;
            switch (binary->getOpcode()) {
            case Instruction::FAdd: op = "+"; break;
            case Instruction::FSub: op = "-"; break;
            case Instruction::FMul: op = "*"; break;
            case Instruction::FDiv: op = "/"; break;
            case Instruction::FRem: op = "fmod"; break;
            case Instruction::Add: op = "+"; break;
            case Instruction::Sub: op = "-"; break;
            case Instruction::Mul: op = "*"; break;
            case Instruction::UDiv: case Instruction::SDiv: op = "/"; break;
            case Instruction::URem: case Instruction::SRem: op = "%"; break;
            case Instruction::Shl: op = "<<"; break;
            case Instruction::LShr: op = ">>"; break;
            case Instruction::AShr: op = ">>"; break;
            case Instruction::And: op = "&"; break;
            case Instruction::Or: op = "|"; break;
            case Instruction::Xor: op = "^"; break;
            default: return false;
            }
            out += "    " + nameOf(*binary) + " = " + nameOf(*binary->getOperand(0)) + " " + op + " " +
                   nameOf(*binary->getOperand(1)) + ";\n";
            return true;
        }
        if (auto *compare = dyn_cast<CmpInst>(&instruction)) {
            const char *op = nullptr;
            switch (compare->getPredicate()) {
            case CmpInst::ICMP_EQ: case CmpInst::FCMP_OEQ: case CmpInst::FCMP_UEQ: op = "=="; break;
            case CmpInst::ICMP_NE: case CmpInst::FCMP_ONE: case CmpInst::FCMP_UNE: op = "!="; break;
            case CmpInst::ICMP_SLT: case CmpInst::FCMP_OLT: case CmpInst::FCMP_ULT: op = "<"; break;
            case CmpInst::ICMP_SLE: case CmpInst::FCMP_OLE: case CmpInst::FCMP_ULE: op = "<="; break;
            case CmpInst::ICMP_SGT: case CmpInst::FCMP_OGT: case CmpInst::FCMP_UGT: op = ">"; break;
            case CmpInst::ICMP_SGE: case CmpInst::FCMP_OGE: case CmpInst::FCMP_UGE: op = ">="; break;
            default: return false;
            }
            out += "    " + nameOf(*compare) + " = " + nameOf(*compare->getOperand(0)) + " " + op + " " +
                   nameOf(*compare->getOperand(1)) + ";\n";
            return true;
        }
        if (auto *cast = dyn_cast<CastInst>(&instruction)) {
            std::string op;
            switch (cast->getOpcode()) {
            case Instruction::ZExt: case Instruction::SExt: case Instruction::BitCast:
                op = "(" + cType(cast->getType()) + ")"; break;
            case Instruction::Trunc: op = "(uint32_t)"; break;
            case Instruction::PtrToInt: case Instruction::IntToPtr: op = "(uint64_t)"; break;
            case Instruction::FPExt: case Instruction::FPTrunc: op = "(float)"; break;
            default: return false;
            }
            out += "    " + nameOf(*cast) + " = " + op + nameOf(*cast->getOperand(0)) + ";\n";
            return true;
        }
        if (auto *alloca = dyn_cast<AllocaInst>(&instruction)) {
            std::string slot = claim("s", slots_++);
            slotsOf_[&instruction] = slot;
            if (instruction.hasName())
                names_[instruction.getName().str()] = slot;
            if (alloca->getAllocatedType()->isPointerTy()) {
                out += "    void *" + slot + " = 0;\n";
                return true;
            }
            uint64_t size = 0;
            std::string type;
            if (typeOf(alloca->getAllocatedType(), type, size)) {
                out += "    " + type + " " + slot + " = 0;\n";
                return true;
            }
            return refuse("a spill of a type this port does not hold");
        }
        if (isa<InsertElementInst>(&instruction))
            return refuse("a vector written whole, which this port's kernels read a component at a time");
        if (auto *extract = dyn_cast<ExtractElementInst>(&instruction)) {
            uint64_t index = 0;
            if (ConstantInt *which = dyn_cast<ConstantInt>(extract->getIndexOperand()))
                index = which->getZExtValue();
            static const char *members[] = {"x", "y", "z", "w"};
            if (index > 3)
                return refuse("a component read past the fourth of a vector, which this port does not hold");
            out += "    " + nameOf(*extract) + " = " + nameOf(*extract->getVectorOperand()) + "." + members[index] + ";\n";
            return true;
        }
        if (auto *select = dyn_cast<SelectInst>(&instruction)) {
            out += "    " + nameOf(*select) + " = " + nameOf(*select->getCondition()) + " ? " + nameOf(*select->getTrueValue()) +
                   " : " + nameOf(*select->getFalseValue()) + ";\n";
            return true;
        }
        if (auto *call = dyn_cast<CallInst>(&instruction)) {
            Function *callee = call->getCalledFunction();
            std::string called = callee ? callee->getName().str() : "";
            if (called.rfind("air.atomic.", 0) == 0) {
                std::string line;
                if (!emitAtomic(call, called, line))
                    return false;
                out += line;
                return true;
            }
            if (called.rfind("air.convert.", 0) == 0) {
                Type *result = call->getType();
                std::string type;
                uint64_t size;
                if (!typeOf(result, type, size))
                    return refuse("a conversion to a type this port does not hold");
                out += "    " + nameOf(*call) + " = (" + type + ")" + nameOf(*call->getArgOperand(0)) + ";\n";
                return true;
            }
            if (called.rfind("llvm.lifetime.start.", 0) == 0 || called.rfind("llvm.lifetime.end.", 0) == 0)
                return true;
            if (called == "air.wg.barrier") {
                out += "    if (barrier) barrier(barrierContext, (uint32_t)thread.x, (uint32_t)size.x);\n";
                return true;
            }
            return refuse("a call to " + (called.empty() ? std::string("an indirect target") : called));
        }
        if (auto *ret = dyn_cast<ReturnInst>(&instruction)) {
            out += "    return;\n";
            return true;
        }
        if (auto *branch = dyn_cast<BranchInst>(&instruction)) {
            if (branch->isConditional()) {
                BasicBlock *taken = branch->getSuccessor(0);
                BasicBlock *other = branch->getSuccessor(1);
                std::string takenPhis, otherPhis;
                if (!assignPhis(*branch->getParent(), *taken, "        ", takenPhis) ||
                    !assignPhis(*branch->getParent(), *other, "    ", otherPhis))
                    return false;
                out += "    if (" + nameOf(*branch->getCondition()) + ") {\n" + takenPhis +
                       "        goto " + identifier(taken->getName().str()) + ";\n    }\n" + otherPhis +
                       "    goto " + identifier(other->getName().str()) + ";\n";
            } else {
                BasicBlock *next = branch->getSuccessor(0);
                std::string phis;
                if (!assignPhis(*branch->getParent(), *next, "    ", phis))
                    return false;
                out += phis + "    goto " + identifier(next->getName().str()) + ";\n";
            }
            return true;
        }
        if (isa<UnreachableInst>(&instruction)) {
            out += "    return;\n";
            return true;
        }
        return false;
    }

    static bool blockHasNoPhis(BasicBlock &block) {
        for (Instruction &instruction : block)
            if (isa<PHINode>(&instruction))
                return false;
        return true;
    }

    Function &kernel_;
    std::vector<Refusal> &refusals_;
    std::map<std::string, std::string> names_;
    std::set<std::string> taken_;
    std::map<const Instruction *, std::string> slotsOf_;
    std::map<const Instruction *, std::string> unnamedNames_;
    unsigned slots_ = 0;
    std::vector<Instruction *> unnamed_;
    std::vector<Value *> buffers_;
    std::vector<Value *> scalars_;
    std::vector<Value *> other_;
    Value *block_ = nullptr;
    int reportedArgument_ = -1;
    const char *reportedType_ = "";
    const char *leftBy_ = "";
    uint32_t blockBytes_ = 0;
    std::map<Value *, unsigned> scalarSlot_;
};

std::vector<Function *> entryPoints(Module &module) {
    std::vector<Function *> found;
    if (NamedMDNode *named = module.getNamedMetadata("air.kernel")) {
        for (MDNode *entry : named->operands())
            if (Function *function = mdconst::dyn_extract<Function>(entry->getOperand(0)))
                found.push_back(function);
        if (!found.empty())
            return found;
    }
    for (Function &function : module) {
        if (function.isDeclaration() || function.getName().starts_with("air."))
            continue;
        bool samples = false;
        for (const Instruction &instruction : function.getEntryBlock())
            if (isa<CallInst>(&instruction)) {
                Function *callee = cast<CallInst>(&instruction)->getCalledFunction();
                if (callee && callee->getName().starts_with("air.sample"))
                    samples = true;
            }
        if (!samples)
            found.push_back(&function);
    }
    return found;
}


namespace plist {

static std::string escape(const std::string &text) {
    std::string out;
    for (char c : text) {
        if (c == '<' || c == '>') { out += "&lt;"; continue; }
        if (c == '&') { out += "&amp;"; continue; }
        if (c == '"') { out += "&quot;"; continue; }
        out += c;
    }
    return out;
}

static void indent(std::string &out, unsigned depth) { out.append(depth * 2, ' '); }

static void typeNode(std::string &out, Type *node, unsigned depth);

static void typeNode(std::string &out, Type *node, unsigned depth) {
    indent(out, depth);
    out += "<dict>\n";
    std::string name;
    uint64_t size = 0;
    unsigned count = 0;
    if (Emitter::vectorOf(node, name, size, count)) {
        indent(out, depth + 1); out += "<key>kind</key>\n";
        indent(out, depth + 1); out += "<string>vector</string>\n";
        indent(out, depth + 1); out += "<key>length</key>\n";
        indent(out, depth + 1); out += "<integer>" + std::to_string(count) + "</integer>\n";
        indent(out, depth + 1); out += "<key>elementType</key>\n";
        Type *element = nullptr;
        if (auto *vector = dyn_cast<VectorType>(node)) element = vector->getElementType();
        typeNode(out, element ? element : Type::getInt32Ty(node->getContext()), depth + 1);
    } else if (auto *array = dyn_cast<ArrayType>(node)) {
        indent(out, depth + 1); out += "<key>kind</key>\n";
        indent(out, depth + 1); out += "<string>array</string>\n";
        indent(out, depth + 1); out += "<key>length</key>\n";
        indent(out, depth + 1); out += "<integer>" + std::to_string(array->getNumElements()) + "</integer>\n";
        indent(out, depth + 1); out += "<key>elementType</key>\n";
        typeNode(out, array->getElementType(), depth + 1);
    } else if (node->isPointerTy()) {
        indent(out, depth + 1); out += "<key>kind</key>\n";
        indent(out, depth + 1); out += "<string>pointer</string>\n";
        indent(out, depth + 1); out += "<key>pointee</key>\n";
        indent(out, depth + 1); out += "<string></string>\n";
    } else if (auto *structure = dyn_cast<StructType>(node)) {
        indent(out, depth + 1); out += "<key>kind</key>\n";
        indent(out, depth + 1); out += "<string>struct</string>\n";
        indent(out, depth + 1); out += "<key>members</key>\n";
        indent(out, depth + 1); out += "<array>\n";
        for (unsigned i = 0; i < structure->getNumElements(); i++) {
            indent(out, depth + 2); out += "<dict>\n";
            indent(out, depth + 3); out += "<key>name</key>\n";
            indent(out, depth + 3); out += "<string></string>\n";
            indent(out, depth + 3); out += "<key>index</key>\n";
            indent(out, depth + 3); out += "<integer>" + std::to_string(i) + "</integer>\n";
            indent(out, depth + 3); out += "<key>type</key>\n";
            typeNode(out, structure->getElementType(i), depth + 3);
            indent(out, depth + 2); out += "</dict>\n";
        }
        indent(out, depth + 1); out += "</array>\n";
    } else if (Emitter::typeOf(node, name, size)) {
        indent(out, depth + 1); out += "<key>kind</key>\n";
        indent(out, depth + 1); out += "<string>scalar</string>\n";
        indent(out, depth + 1); out += "<key>scalar</key>\n";
        indent(out, depth + 1); out += "<string>" + escape(name) + "</string>\n";
    } else {
        indent(out, depth + 1); out += "<key>kind</key>\n";
        indent(out, depth + 1); out += "<string>unknown</string>\n";
    }
    indent(out, depth);
    out += "</dict>\n";
}

struct ArgumentMetadata {
    std::string access;
    std::string argName;
    std::string typeName;
    bool hasIndex = false;
    uint64_t index = 0;
    bool hasSize = false, hasAlignSize = false;
    uint64_t size = 0, alignSize = 0;
    MDNode *structTypeInfo = nullptr;
};

static ArgumentMetadata argumentMetadata(MDNode *node) {
    ArgumentMetadata metadata;
    if (!node || node->getNumOperands() < 2)
        return metadata;
    unsigned start = 1;
    if (auto *index = mdconst::dyn_extract<ConstantInt>(node->getOperand(0))) {
        metadata.index = index->getZExtValue();
        metadata.hasIndex = true;
    } else if (auto *marker = dyn_cast<MDString>(node->getOperand(0))) {
        metadata.access = marker->getString().str();
    }
    for (unsigned i = start; i < node->getNumOperands(); i++) {
        auto *key = dyn_cast<MDString>(node->getOperand(i));
        if (!key)
            continue;
        std::string name = key->getString().str();
        bool bare = i + 1 >= node->getNumOperands();
        if (!bare)
            if (auto *next = dyn_cast<MDString>(node->getOperand(i + 1)))
                bare = next->getString().starts_with("air.");
        if (name == "air.read" || name == "air.write" || name == "air.read_write" ||
            name == "air.read_only") {
            metadata.access = name;
            if (bare)
                continue;
        }
        if (bare)
            continue;
        if (name == "air.arg_name") {
            if (auto *value = dyn_cast<MDString>(node->getOperand(i + 1)))
                metadata.argName = value->getString().str();
        } else if (name == "air.arg_type_name") {
            if (auto *value = dyn_cast<MDString>(node->getOperand(i + 1)))
                metadata.typeName = value->getString().str();
        } else if (name == "air.arg_type_size") {
            if (auto *value = mdconst::dyn_extract<ConstantInt>(node->getOperand(i + 1))) {
                metadata.size = value->getZExtValue();
                metadata.hasSize = true;
            }
        } else if (name == "air.arg_type_align_size") {
            if (auto *value = mdconst::dyn_extract<ConstantInt>(node->getOperand(i + 1))) {
                metadata.alignSize = value->getZExtValue();
                metadata.hasAlignSize = true;
            }
        } else if (name == "air.struct_type_info") {
            metadata.structTypeInfo = dyn_cast_or_null<MDNode>(node->getOperand(i + 1));
        }
        i += 1;
    }
    return metadata;
}

static bool isArgumentNode(MDNode *node) {
    if (!node || node->getNumOperands() < 2)
        return false;
    if (mdconst::dyn_extract<ConstantInt>(node->getOperand(0)))
        return true;
    auto *first = dyn_cast<MDString>(node->getOperand(0));
    return first && first->getString().starts_with("air.") &&
           first->getString() != StringRef("air.threads_per_threadgroup") &&
           first->getString() != StringRef("air.threads_per_grid");
}

static std::vector<MDNode *> argumentNodes(MDNode *kernel) {
    std::vector<MDNode *> nodes;
    for (unsigned i = 1; i < kernel->getNumOperands(); i++) {
        MDNode *node = dyn_cast_or_null<MDNode>(kernel->getOperand(i));
        if (!node)
            continue;
        if (isArgumentNode(node)) {
            nodes.push_back(node);
            continue;
        }
        for (const MDOperand &nested : node->operands())
            if (MDNode *inner = dyn_cast_or_null<MDNode>(nested))
                if (isArgumentNode(inner))
                    nodes.push_back(inner);
    }
    return nodes;
}

static void structMembers(std::string &out, MDNode *info, unsigned depth) {
    indent(out, depth);
    out += "<array>\n";
    for (unsigned i = 0; i + 2 < info->getNumOperands(); i += 3) {
        auto *name = dyn_cast<MDString>(info->getOperand(i));
        auto *offset = mdconst::dyn_extract<ConstantInt>(info->getOperand(i + 1));
        auto *type = dyn_cast<MDString>(info->getOperand(i + 2));
        indent(out, depth + 1); out += "<dict>\n";
        indent(out, depth + 2); out += "<key>name</key>\n";
        indent(out, depth + 2);
        out += "<string>" + escape(name ? name->getString().str() : "") + "</string>\n";
        indent(out, depth + 2); out += "<key>offset</key>\n";
        indent(out, depth + 2);
        out += "<integer>" + std::to_string(offset ? offset->getZExtValue() : 0) + "</integer>\n";
        indent(out, depth + 2); out += "<key>type</key>\n";
        indent(out, depth + 2);
        out += "<string>" + escape(type ? type->getString().str() : "") + "</string>\n";
        indent(out, depth + 1); out += "</dict>\n";
    }
    indent(out, depth);
    out += "</array>\n";
}

static void function(std::string &out, Function *entry, MDNode *kernel, unsigned depth) {
    indent(out, depth);
    out += "<dict>\n";
    indent(out, depth + 1); out += "<key>name</key>\n";
    indent(out, depth + 1); out += "<string>" + escape(entry->getName().str()) + "</string>\n";
    indent(out, depth + 1); out += "<key>arguments</key>\n";
    indent(out, depth + 1); out += "<array>\n";
    std::vector<MDNode *> nodes = argumentNodes(kernel);
    unsigned index = 0;
    for (Argument &argument : entry->args()) {
        ArgumentMetadata metadata = index < nodes.size() ? argumentMetadata(nodes[index])
                                                        : ArgumentMetadata();
        indent(out, depth + 2); out += "<dict>\n";
        indent(out, depth + 3); out += "<key>index</key>\n";
        indent(out, depth + 3); out += "<integer>" + std::to_string(index) + "</integer>\n";
        indent(out, depth + 3); out += "<key>name</key>\n";
        indent(out, depth + 3); out += "<string>" + escape(argument.getName().str()) + "</string>\n";
        const char *access = nullptr;
        if (metadata.access == "air.read" || metadata.access == "air.read_only")
            access = "read-only";
        else if (metadata.access == "air.write")
            access = "write-only";
        else if (metadata.access == "air.read_write")
            access = "read-write";
        if (access) {
            indent(out, depth + 3); out += "<key>access</key>\n";
            indent(out, depth + 3);
            out += std::string("<string>") + access + "</string>\n";
        }
        indent(out, depth + 3); out += "<key>textureDataType</key>\n";
        indent(out, depth + 3);
        bool pointer = argument.getType()->isPointerTy();
        out += pointer ? "<string>texture</string>\n" : "<string>none</string>\n";
        indent(out, depth + 3); out += "<key>type</key>\n";
        typeNode(out, argument.getType(), depth + 3);
        if (!metadata.typeName.empty()) {
            indent(out, depth + 3); out += "<key>typeName</key>\n";
            indent(out, depth + 3);
            out += "<string>" + escape(metadata.typeName) + "</string>\n";
        }
        if (metadata.hasSize) {
            indent(out, depth + 3); out += "<key>size</key>\n";
            indent(out, depth + 3);
            out += "<integer>" + std::to_string(metadata.size) + "</integer>\n";
        }
        if (metadata.hasAlignSize) {
            indent(out, depth + 3); out += "<key>alignSize</key>\n";
            indent(out, depth + 3);
            out += "<integer>" + std::to_string(metadata.alignSize) + "</integer>\n";
        }
        if (metadata.structTypeInfo) {
            indent(out, depth + 3); out += "<key>members</key>\n";
            structMembers(out, metadata.structTypeInfo, depth + 3);
        }
        indent(out, depth + 2); out += "</dict>\n";
        index++;
    }
    indent(out, depth + 1); out += "</array>\n";
    indent(out, depth + 1); out += "<key>threadgroupSize</key>\n";
    indent(out, depth + 1); out += "<array>\n";
    for (unsigned axis = 0; axis < 3; axis++) {
        indent(out, depth + 2);
        out += "<integer>0</integer>\n";
    }
    indent(out, depth + 1); out += "</array>\n";
    indent(out, depth);
    out += "</dict>\n";
}

static std::string document(Module &module) {
    std::string out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    out += "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n";
    out += "<plist version=\"1.0\">\n<dict>\n";
    out += "  <key>version</key>\n  <integer>1</integer>\n";
    out += "  <key>functions</key>\n  <array>\n";
    NamedMDNode *named = module.getNamedMetadata("air.kernel");
    unsigned kernel = 0;
    for (Function *entry : entryPoints(module)) {
        MDNode *node = nullptr;
        if (named)
            for (MDNode *candidate : named->operands()) {
                if (candidate->getNumOperands() &&
                    mdconst::dyn_extract<Function>(candidate->getOperand(0)) == entry)
                    node = candidate;
            }
        function(out, entry, node, 2);
        kernel++;
    }
    out += "  </array>\n</dict>\n</plist>\n";
    return out;
}

}

}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: air2cpu MODULE.bc OUT.c [OUT.plist]\n");
        return 2;
    }
    LLVMContext context;
    SMDiagnostic diagnostic;
    std::unique_ptr<Module> module = parseIRFile(argv[1], diagnostic, context);
    if (!module) {
        fprintf(stderr, "%s: not readable bitcode\n", argv[1]);
        diagnostic.print(argv[0], errs());
        return 2;
    }

    std::vector<std::string> bodies;
    std::vector<std::string> table;
    std::vector<Refusal> refusals;
    unsigned translated = 0;

    for (Function *entry : entryPoints(*module)) {
        Emitter emitter(*entry, refusals);
        std::string body;
        if (!emitter.emit(body))
            continue;
        bodies.push_back(body);
        char row[256];
        snprintf(row, sizeof(row), "    { \"%s\", air2cpu_%s, %u, %u, 0 },\n", emitter.entryName().c_str(),
                 emitter.entryName().c_str(), emitter.bufferCount(), emitter.blockBytes());
        table.push_back(row);
        translated++;
        printf("%s: OK %s\n", argv[1], emitter.entryName().c_str());
    }

    if (argc > 3) {
        std::string plistPath = argv[3];
        FILE *plist = fopen(plistPath.c_str(), "wb");
        if (!plist) {
            fprintf(stderr, "air2cpu: cannot write %s\n", plistPath.c_str());
            return 2;
        }
        std::string document = plist::document(*module);
        fwrite(document.data(), 1, document.size(), plist);
        fclose(plist);
        printf("air2cpu: the type tree of %u function(s) written to %s\n", translated, plistPath.c_str());
    }

    if (bodies.empty()) {
        for (const Refusal &refusal : refusals)
            printf("%s: REFUSED %s: %s\n", argv[1], refusal.name.c_str(), refusal.reason.c_str());
        fprintf(stderr, "%s: no kernel of this library could be translated\n", argv[1]);
        return 1;
    }

    std::string source = argv[2];
#ifndef CHAIR_AIR2CPU_ABI
#error "air2cpu must be told where its call convention lives: build it with -DCHAIR_AIR2CPU_ABI=<path to air2cpu-abi.h>"
#endif
    const char *header = CHAIR_AIR2CPU_ABI;
    FILE *check = fopen(header, "rb");
    if (!check) {
        fprintf(stderr, "air2cpu: cannot read the call convention it emits kernels against, at %s; "
                        "the build must pass it in with -DCHAIR_AIR2CPU_ABI=<path>\n", header);
        return 2;
    }
    fclose(check);
    FILE *out = fopen(source.c_str(), "w");
    if (!out) {
        fprintf(stderr, "air2cpu: cannot write %s\n", source.c_str());
        return 2;
    }
    fputs("#include <stdatomic.h>\n#include <stdbool.h>\n#include <stddef.h>\n#include \"", out);
    fputs(header, out);
    fputs("\"\n", out);
    fputs("/* Generated by air2cpu from the AIR of a Metal library. Do not edit. */\n", out);
    for (const std::string &body : bodies)
        fputs(body.c_str(), out);
    fputs("const air2cpu_kernel air2cpu_kernels[] = {\n", out);
    for (const std::string &row : table)
        fputs(row.c_str(), out);
    fputs("};\nconst unsigned air2cpu_kernel_count = ", out);
    fprintf(out, "%u;\n", (unsigned)table.size());
    fclose(out);


    for (const Refusal &refusal : refusals)
        printf("%s: REFUSED %s: %s\n", argv[1], refusal.name.c_str(), refusal.reason.c_str());
    printf("%s: %u kernel(s) written to %s with %s, %u refused\n", argv[1], translated, source.c_str(),
           header, (unsigned)refusals.size());
    return 0;
}
