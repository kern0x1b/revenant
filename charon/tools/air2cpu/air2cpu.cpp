// air2cpu — a Metal compute kernel in AIR, turned into C the port can run on the CPU.
//
// A sibling of tools/air2es, and the same shape in every way that matters: it reads the AIR bitcode of a
// Metal library with LLVM, finds the functions that are kernel entry points, and writes something the
// port's runtime can execute. Where air2es writes a GLSL shader for an ES 1.00 compiler, air2cpu writes C
// for the application's own compiler, because the drivers of iOS 6 are OpenGL ES 2.0 and there is
// nowhere to dispatch a kernel into (facts/OpenGLES/ES3Functions.md, measured on an iPhone 4S).
//
//     air2cpu MODULE.bc OUT.c
//
// OUT.c is one translation unit holding every kernel it could translate and a table of them. A kernel it
// cannot translate is **refused by name**, on stdout, with the reason and the function: a kernel that
// answers the port's documented error is not a wrong answer, and a kernel that is translated wrongly is.
// The refusals are listed at the end of this file's own README section below.
//
// What a kernel looks like, read out of the AIR Apple's own compiler produced (and not from the header):
//
//   * buffers are `ptr addrspace(1)` carrying "air-buffer-no-alias";
//   * the thread identifiers are plain `i32` parameters — tid, gid, tg — because the compiler has
//     already lowered Metal's thread-position builtins into them;
//   * threadgroup memory is `ptr addrspace(3)`, a block the caller owns and hands in;
//   * a barrier is `air.wg.barrier(mem_flags, barrier_id, ...)`.
//
// Two spellings of "this is an entry point", because there are two: a library Apple's `metal` tool built
// marks its kernels in the named metadata `air.kernel`, and a library Metal's *runtime* compiled from
// source — the one tests/backports/host/air2cpu/oracle.m writes, by -[MTLDynamicLibrary
// serializeToURL:error:] — marks them with nothing at all, so they are the top-level functions that
// carry no stage marker. Both are recognised, and a library with neither is refused as a whole.

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

// The signature the port's runtime calls every kernel through, whatever the kernel's own parameters are:
// the buffers it was given, the three thread numbers, and the threadgroup block. A kernel without a block
// takes a null one.
// A kernel's barrier is a rendezvous of the threads of its workgroup, and the dispatch is what knows
// how its threads meet, so the barrier is a function the dispatch hands in. A group run on one thread
// has nothing to order and passes a null one; a group run across threads passes a rendezvous that
// waits. Neither is a stand-in: the ordering the kernel asks for is the ordering it gets.
extern "C" typedef void (*air2cpu_barrier_fn)(void *context, uint32_t tid, uint32_t threads);
// The thread position, the threadgroup position and the group size are always four components wide, so
// a kernel of one dimension and a kernel of three call the same way and the dispatch has room for the
// dimensions a grid has.
#include "../../packages/a/apple-backports/air2cpu-abi.h"

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

    // A vector of at most four elements is a struct with named members, which is the shape a C
    // lowering of a vector has always taken and the one that makes extractelement a member read.
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
        out = "charon_v" + std::to_string(count) + "i";
        size = elementSize * count;
        return true;
    }

    // The C type an IR value of this type is held in, and the width of one element of it.
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
        return false;   // a vector, an array, a struct: refused by the caller
    }

    bool emit(std::string &body) {
        // A refusal recorded while the body is being built means the kernel was NOT translated, even
        // if every instruction walked: a value the emitter could not name became an empty string in
        // the C, and the tool said OK. So the count of refusals before and after is the check.
        size_t refusedBefore = refusals_.size();
        for (Value &argument : kernel_.args()) {
            // ONE print, at the top of the loop, and the branch each argument left by travels with the
            // loop: a print inside a branch can be missed by a branch nobody thought to put one in,
            // which is exactly what happened - orderKernel2's arguments all left early and nothing said
            // so. Here the previous argument's index, type and fate are reported before the current one
            // is looked at, so every argument of every kernel is accounted for.
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
            // An i32 argument is one of the three and must fall THROUGH to the population below. It used
            // to be pushed here and continue, so every scalar in every kernel whose positions are scalars
            // left the loop before the map was filled - the map was only ever populated for a kernel
            // whose positions are VECTORS, and every i32 fell back to slot 0. That is the whole of a
            // four-turn hunt: one branch, above the code it shadowed, `continue`ing into nothing.
            // The three a kernel is given about where it is - its thread in the grid, its threadgroup
            // in the grid, and the size of the group - get their slot HERE, in the one pass that walks
            // the arguments, keyed by the ARGUMENT'S OWN INDEX. They were being numbered by that index
            // less the number of buffers, which is wrong for a kernel that also takes a threadgroup
            // block: that argument sits in the middle of the list, so counting arguments bound every
            // scalar one position late - thread<-gid, group<-tg, size<-tid - and `gid * tg + tid`
            // came out as `size.x * size.x + group.x`.
            //
            // A fourth scalar would bind to a name that is not declared, which is a C file that does
            // not compile, so it is refused here by name.
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
    // The length the kernel declares for its threadgroup block, or zero when it declares none: read out
    // of the kernel's own declaration rather than assumed, so the pipeline's default is the kernel's
    // and not a number from a fixture.
    uint32_t blockBytes() const { return blockBytes_; }

private:
    // Every value in the kernel gets one C variable, and a phi is assigned on the edge into its block
    // rather than at the top of the block, which is what makes a loop's phi a plain assignment.
    // Every name the emitter writes comes from this one table, and a name is handed out ONCE.
    // The prefixes are per kind - s<> a spill slot, v<> a named value, t<> an unnamed one - and
    // the assert is here, where the invariant is, rather than in the C compiler that only
    // discovers it afterwards.
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
        // The threadgroup block's length, where the AIR carries it. A kernel takes the block as a
        // parameter in address space 3, and a library Apple's runtime compiled from source carries no
        // argument table to name the length - so this stays zero, which the port reads as "nobody has
        // said", and refuses a dispatch that needs a block whose length is unknown. That is better
        // than a number from a fixture, which a kernel declaring more would write past.
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
            // The three a kernel is given about where it is: its thread in the grid, its threadgroup in
            // the grid, and the size of the group. A kernel of one dimension takes them as scalars and
            // a kernel of two or three takes them as vectors, so a scalar is a component of the same
            // three values and one call convention serves both.
            // LOOKED UP by the argument, not counted here: counting in this function counts per USE.
            auto found = scalarSlot_.find((Value *)argument);
            if (getenv("AIR2CPU_PRINT_SLOTS") && found == scalarSlot_.end()) {
                // The lookup key beside the map's keys, both sides, once: this is the whole of what is
                // wrong with the mapping, and a run that prints it settles whether the key is the wrong
                // pointer or the map being read is not the one being written.
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
            // A fourth scalar is refused above, so this cannot fall off the end; the bound is
            // defensive and named rather than an "extra0" that nothing declares.
            return std::string(vectors[slot < 3 ? slot : 2]) + (argument->getType()->isVectorTy() ? "" : ".x");
        }
        if (Instruction *instruction = dyn_cast<Instruction>(&value)) {
            // A SPILL SLOT first: its name was claimed when the slot was declared, and an unnamed
            // alloca has no name of its own to be looked up by, so without this it fell through to the
            // t<> counter and two of them wanted t3.
            // An alloca's VALUE is a T*: the address of the storage that holds a T, and the storage is
            // the C variable the slot declared. So the value is the ADDRESS of the slot, and every use
            // falls out of that one rule: a load is *p, a store is *p = v, a compare-exchange on p is
            // __atomic_compare_exchange_n(p, ...), and for a slot p is (&s<n>). Emitting the slot's
            // name here instead made the value the storage rather than its address, which is what the
            // trap was.
            auto slot = slotsOf_.find(instruction);
            if (slot != slotsOf_.end())
                return "(&" + slot->second + ")";
            // The name an instruction was GIVEN, never one claimed here: nameOf is called once per USE
            // of a value, so claiming here meant a second use of the same value asked for a second
            // name - which is the third time a name has been derived per use rather than per thing, and
            // the same shape as the scalar map that had to be keyed on the argument.
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
                    // printf's suffix is not a C literal's: a whole number needs a dot of its own
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
        out += "static void air2cpu_" + kernel_.getName().str() + "(void *const *buffers, charon_v4i thread, charon_v4i group, charon_v4i size, char *block, uint32_t blockBytes, air2cpu_barrier_fn barrier, void *barrierContext)\n{\n";
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

    // The memory order AIR names, as the C11 order it means. Only the codes Metal's own compiler emits
    // are in the table: a code this port has not seen is REFUSED, because guessing an order is a
    // kernel that is stronger or weaker than the one the application compiled, which is the one thing
    // an atomic must never be.
    // The order Metal's own compiler emits, read out of the AIR of the fixture's kernels.
    //
    // MEASURED, and the measurement is smaller than it looked. Metal's own diagnostics say, for every
    // atomic overload that takes no mem_flags argument: "candidate disabled: 'order' argument must be
    // 'metal::memory_order_relaxed' if no 'mem_flags' argument is provided". A DEVICE atomic can
    // therefore only be written relaxed, and relaxed is the only code a device atomic can carry. The
    // code the compiler emits for it is 1, and the two atomic kernels in the differential - sixteen
    // threads each racing to add one to a device counter - agree with Apple's own Metal on all 64
    // values, which is the proof that 1 is relaxed and not an assumption.
    //
    // The THREADGROUP family is the one that takes a mem_flags argument, and it is the one that can
    // carry the other orders; those codes are NOT MEASURED yet and are not in this table. A code this
    // port has not seen is refused, because an atomic answered with the wrong ordering is a kernel
    // stronger or weaker than the one the application compiled, which is the one thing an atomic must
    // never be.
    //
    // What is NOT the order, so the next reader does not spend the afternoon on it: the argument this
    // table used to read is not the order at all. A relaxed THREADGROUP load and a relaxed DEVICE
    // store differ in it - 1 and 2 - while both are relaxed, so the field is something else (a scope),
    // and the order is a different argument that is 0 in both. Reading the whole argument list of one
    // of each side by side, and of a threadgroup atomic written with an explicit mem_flags (the one
    // form that accepts all four orders), is what identifies it.
    //
    // The table is fitted to what the differential has PROVED, and nothing beyond it: a relaxed
    // fetch-add of a device counter is code 1 and nothing else is mapped, because the two atomic
    // kernels in the differential - sixteen threads each racing to add one - agree with Apple's own
    // Metal on all 64 values with it and did not with any other code tried.
    // The ORDER and the SCOPE, both settled by measurement rather than by inference.
    //
    // The settling measurement, in orders/settle.metal: the SAME atomic written twice with everything
    // held fixed but the mem_flags argument - a threadgroup atomic with mem_threadgroup and with
    // mem_device, and a device atomic with mem_device and with mem_none. In all four pairs ONLY THE
    // LAST FIELD before the i1 flag moves:
    //
    //   local.add.u.i32  (ptr, value, 0, 1, 2, i1)   mem_threadgroup
    //   local.add.u.i32  (ptr, value, 0, 1, 1, i1)   mem_device
    //   global.add.u.i32 (ptr, value, 0, 2, 1, i1)   mem_device
    //   global.add.u.i32 (ptr, value, 0, 2, 0, i1)   mem_none
    //
    // So the LAST field is the scope - 2 threadgroup, 1 device, 0 none - and the field before it is
    // the order, which is the field that varies with the order: measured on five threadgroup
    // fetch_adds whose only difference is the order, 1 relaxed, 2 acquire, 3 release, 4 acq_rel,
    // 5 seq_cst, cross-checked on an or, a max, an xchg, a load and a store.
    //
    // AND THE TWO FAMILIES NUMBER THE ORDER DIFFERENTLY: a relaxed threadgroup operation carries 1
    // and a relaxed DEVICE operation carries 2. One table over both numbers is what had the tool
    // reading a device operation's relaxed as an acquire - which a C atomic store may not take, so
    // an ordinary device store came out refused. The tables are per family, and the family is the
    // scope the compiler put in the intrinsic's own name.
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
        // A device atomic carries relaxed or nothing: deviceOrders writes the same fetch_add in all
        // five of the language's orders and four do not compile, with the compiler's own diagnostic
        // saying why. So the one code that can appear is the one that is relaxed.
        if (code == 2)
            return "memory_order_relaxed";
        return nullptr;
    }

// One compare-exchange, as one string, built with an ostringstream. It was an expression spread over
// four source lines, and three attempts at changing it severed it in three different ways; a function
// that assembles the whole line cannot be edited in pieces at all. The semantics are LLVM's own:
// __atomic_compare_exchange_n writes the SLOT's current value into *expected on a FAILURE, so the old
// value is expected_ after the call either way, and a success wants the value that was stored, which
// is the instruction's own operand. The old spelling named `desired_`, a variable it never declared,
// and the generated C did not compile.
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

    // One atomic intrinsic, as a C11 __atomic call.
    //
    // The shape is SwiftShader's, read out of it: Reactor.cpp:2621 gives one thin function per
    // operation over a pointer, a value and a std::memory_order, and SpirvShader.cpp:2629 dispatches
    // the opcodes onto them. What is underneath there is __sync/_Atomic; here it is the C11 __atomic
    // builtins, which is the same family and needs no library on armv7.
    //
    // The one place the obvious emission is WRONG: __atomic_fetch_min and __atomic_fetch_max compare
    // SIGNED even when the type is unsigned, which clang documents and which would make a kernel's
    // min over unsigned counters compute a signed minimum. The unsigned min and max are therefore a
    // compare-exchange loop, which is what the operation actually is.
    bool emitAtomic(CallInst *call, const std::string &called, std::string &out)
    {
        // air.atomic.<scope>.<op>[.<s|u>].<width> - the scope is global or local, the operation one of
        // add sub min max and or xor xchg cmpxchg load store.
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
        // parts[2] is the scope the compiler put in the NAME - global or local - and it is what
        // selects the order table: the two families number the order differently, and one table over
        // both numbers is what read a device operation's relaxed as an acquire.
        bool threadgroup = parts[2] == "local";
        // The memory order sits at a position that depends on the operation, and the position is
        // measured from the compiler's own declarations: a fetch-op is (ptr, value, ?, order, ?, i1),
        // a load or store is (ptr, order, ?, i1), and a compare-exchange carries a success order and
        // a failure order. Taking "the last constant above one" instead picks the wrong one of them.
        // Measured from the compiler's own declarations: a fetch-op and a store are
        // (ptr, value, ?, order, ?, i1), a load is (ptr, ?, order, ?, i1) - one argument fewer, because a
        // load has no value - and a compare-exchange carries a success order and a failure order.
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
            // A store may only be relaxed, release or seq_cst, and the order Metal emits here is not
            // one of those. Mapping it onto release would be a guess about what ordering the kernel
            // asked for, so it is refused: a kernel the tool will not answer for is the documented
            // error, and a kernel answered with the wrong order is not.
            if (std::string(order) != "memory_order_relaxed" && std::string(order) != "memory_order_release" &&
                std::string(order) != "memory_order_seq_cst")
                return refuseBool("the memory order " + std::string(order) + " of " + called +
                                  ", which a C atomic store may not take and which this port will not map onto one");
            out += "    __atomic_store_n((volatile " + type + " *)" + pointer + ", " + value + ", " + order + ");\n";
            return true;
        }
        if (operation == "cmpxchg") {
            // air.atomic.<scope>.cmpxchg.weak|strong.i32(ptr, ptr expected, i32 desired, i32 success,
            // i32 failure, i32 ?, i1) - the expected value is a POINTER, as it is in AIR and in
            // __atomic_compare_exchange_n, and the two orders are the success and the failure ones.
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
            // A signed comparison on an unsigned value, which __atomic_fetch_min and
            // __atomic_fetch_max would both perform, and which is not what the kernel asked for.
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

    // A C label may not hold a dot and AIR block names are full of them - for.body, for.cond.cleanup -
    // so every name that becomes an identifier is flattened here, once, and used everywhere.
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
            // A SLOT is storage, not a value, and dispatch() owns its declaration: it carries the
            // slot's own type - a void * for an address, the value's own type for a whole value - and
            // its own s<> name. Declaring it here as well wrote the same name twice with two types,
            // which is what "redefinition of 's0' with a different type" was.
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

    // The edge assignments a phi's incoming values stand for: right before the branch into the block.
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
            return true;   // assigned on the edge that brings it
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
            // The stride of an array is the ALLOCATED size of its element, and the module carries the
            // answer: the struct body is in the type table, and the DataLayout that came with the
            // bitcode knows the ABI's alignment and padding. That is where the size of an array of
            // atomics comes from - `struct.metal::_atomic`'s own fields, laid out by the module's
            // datalayout - and not from a default that would be right for a uint and wrong for
            // anything else. An OPAQUE type has no body to read and is the only refusal here.
            Type *element = gep->getSourceElementType();
            bool readable = element->isSized();
            if (StructType *fields = dyn_cast<StructType>(element))
                readable = readable && !fields->isOpaque();
            uint64_t size = readable ? kernel_.getParent()->getDataLayout().getTypeAllocSize(element) : 0;
            if (!size)
                return refuse("a getelementptr over a type the module's datalayout cannot give a size "
                              "for - " + std::string(readable ? "" : "unsized, or with no field list") +
                              " - and the stride would be a guess");
            // With opaque pointers the base operand is not one of the indices, so they start one
            // later - and a GEP may carry a trailing constant zero after a varying index, which is
            // what AIR's does. Taking the LAST index therefore picked the trailing zero and emitted
            // `(char *)out + 0 * 4` for every store: a wrong address, silently, and the one this
            // differential caught. So the index used is the LAST NON-CONSTANT one, and a GEP whose
            // every index is a constant is refused rather than turned into an offset of zero.
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
            // GEP index i is operand i + 1: the base sits at operand 0 with an opaque pointer.
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
            // A compare-exchange's expected value is spilled to a slot the compiler gives it; in C the
            // expected value is a variable the call takes by address, so the slot is declared and the
            // call writes through it. Anything else is a spill this port does not model, and is refused.
            // A SLOT, and not a value: a compare-exchange's expected value is a slot the call
            // writes through, and naming it by the value scheme is how a slot and a value came to
            // want one name and the generated C to refuse to compile.
            std::string slot = claim("s", slots_++);
            slotsOf_[&instruction] = slot;
            if (instruction.hasName())
                names_[instruction.getName().str()] = slot;
            if (alloca->getAllocatedType()->isPointerTy()) {
                // A slot holding an ADDRESS. A compare-exchange takes its expected value by address,
                // so this is the one construct in Metal that guarantees one, and the loads and stores
                // that go through the slot assign it - which is what the compiler's own C means. The
                // type is written plainly rather than through typeOf, because the allocated type of such
                // a slot is a POINTER and that is all the C needs to say.
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
                // air.convert.f.f32.u.i32 and its siblings are a conversion between two scalar types,
                // which in C is a cast; the name says both, so the cast is taken from the type the
                // call itself returns rather than from a table of the names.
                Type *result = call->getType();
                std::string type;
                uint64_t size;
                if (!typeOf(result, type, size))
                    return refuse("a conversion to a type this port does not hold");
                out += "    " + nameOf(*call) + " = (" + type + ")" + nameOf(*call->getArgOperand(0)) + ";\n";
                return true;
            }
            // llvm.lifetime.start / .end mark the EXTENT of a stack object for the optimiser, and they
            // accompany every alloca. A C declaration already has that extent, so in C there is nothing
            // to emit and nothing to compute - matched on the NAME PREFIX and not on the .p0 suffix,
            // because the suffix is the address space of the slot and there is more than one of them.
            if (called.rfind("llvm.lifetime.start.", 0) == 0 || called.rfind("llvm.lifetime.end.", 0) == 0)
                return true;
            if (called == "air.wg.barrier") {
                // The flags say which memory the barrier orders; the runtime's rendezvous orders the
                // whole group, which is at least as much as the kernel asked for and never less.
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

    // Whether a block has any phi, so an empty assignment string means failure and not "nothing to do".
    static bool blockHasNoPhis(BasicBlock &block) {
        for (Instruction &instruction : block)
            if (isa<PHINode>(&instruction))
                return false;
        return true;
    }

    Function &kernel_;
    std::vector<Refusal> &refusals_;
    std::map<std::string, std::string> names_;
    std::set<std::string> taken_;   // every C name handed out, once
    std::map<const Instruction *, std::string> slotsOf_; // each spill slot's name, by the instruction that owns it
    std::map<const Instruction *, std::string> unnamedNames_; // each unnamed value's name, given once
    unsigned slots_ = 0;             // the spill slots so far, for the s<> prefix
    std::vector<Instruction *> unnamed_;
    std::vector<Value *> buffers_;
    std::vector<Value *> scalars_;
    std::vector<Value *> other_;
    Value *block_ = nullptr;
    int reportedArgument_ = -1;   // the argument the one print is carrying
    const char *reportedType_ = "";
    const char *leftBy_ = "";
    uint32_t blockBytes_ = 0;   // the length the kernel declares for its threadgroup block
    std::map<Value *, unsigned> scalarSlot_; // each scalar argument's slot, fixed in the pass that walks them
};

// The entry points of a module, in the two spellings there are.
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
        // A render function samples, and only a render function does; a kernel takes a barrier and a
        // vertex texture fetch through a kernel argument, so the test is for air.sample and nothing
        // else. Marking a kernel a stage function for calling air.wg.barrier is what hid scanKernel
        // from its own tool, and the differential is what said so.
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


// The type tree, written as a property list beside the translated source.
//
// Why a file and not a re-parse: the device never sees AIR. This tool runs at build time on the host
// and only what it writes ships, so a reflection object on the device has nothing to re-read but this
// file. The format is a property list because NSPropertyListSerialization has read one since iOS 2,
// so the 6.0 port reads it with no parser of its own.
//
// The walk is the SAME one the C emitter uses - vectorOf() and typeOf() - so the tree written and the
// C emitted cannot disagree about what a type is: one function, one answer, two outputs.
namespace plist {

static std::string escape(const std::string &text) {
    std::string out;
    for (char c : text) {
        if (c == '<' || c == '>') { out += "&lt;"; continue; }   // XML, and these are the two
        if (c == '&') { out += "&amp;"; continue; }              // characters a Metal type spells
        if (c == '"') { out += "&quot;"; continue; }
        out += c;
    }
    return out;
}

static void indent(std::string &out, unsigned depth) { out.append(depth * 2, ' '); }

// A type as a dictionary, in the words MTLType.h uses: a kind, and for a vector the length, and for a
// struct the members, and for a pointer what it points at. A type this walk cannot name is written
// with kind "unknown" and its own name, which is what a caller sees as MTLUnknown - better than a
// missing entry, and it says so.
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
        // A pointer, and the AIR says nothing about what it points at. LLVM has used opaque pointers
        // since 15: PointerType carries no pointee type to ask for, which is why there is no accessor
        // to call here. So the entry is written as a pointer with no pointee, and the reader answers
        // MTLUnknown for it - the absence is in the data, not in the reader.
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
            // A struct in the AIR has element TYPES but, in LLVM 23, no per-element NAME to read:
            // StructType::getName() is the struct's own name and that is all it carries. So the member
            // is named for its position, which is what a reader can honestly report, and the reader
            // answers MTLUnknown for the name rather than inventing one.
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

// The AIR's own node for one argument: a flat list of alternating strings, as sum.ll spells it -
// !{!"air.read_write", !"air.arg_type_name", !"device float *"}. The first key is the access, and the
// rest are the type's own keys. A value that is not a string (a nested struct member list) is
// handled where it is read and nowhere else.
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
    // A REAL argument node begins with an i32 index and then key/value pairs; the older sum.ll
    // shape begins with a string key. Both are read, because both are in this repository's own
    // fixtures, and the index is taken from the node when it is there rather than from the position.
    // Both shapes put something BEFORE the key/value pairs: a real node puts an i32 index there and
    // the older one puts a bare access marker with no value of its own. So the pairs start at 1 in
    // both, and operand 0 is the index or the marker - never a key.
    // Both shapes put something before the key/value pairs: a real node an i32 index, the older one
    // a bare access marker. So the pairs start at operand 1 either way, and operand 0 is never a key.
    unsigned start = 1;
    if (auto *index = mdconst::dyn_extract<ConstantInt>(node->getOperand(0))) {
        metadata.index = index->getZExtValue();
        metadata.hasIndex = true;
    } else if (auto *marker = dyn_cast<MDString>(node->getOperand(0))) {
        metadata.access = marker->getString().str();
    }
    // A key may be BARE: a real node opens with its type class - !"air.buffer" - and the access is
    // bare too - !"air.read" with no value after it. A bare key is told from a paired one by what
    // follows: another "air." string means this key stands alone, and consuming that string as its
    // value would swallow the next key. So a bare key advances by one and a paired one by two.
    for (unsigned i = start; i < node->getNumOperands(); i++) {
        auto *key = dyn_cast<MDString>(node->getOperand(i));
        if (!key)
            continue;
        std::string name = key->getString().str();
        bool bare = i + 1 >= node->getNumOperands();
        if (!bare)
            if (auto *next = dyn_cast<MDString>(node->getOperand(i + 1)))
                bare = next->getString().starts_with("air.");
        // The access is a BARE key wherever it appears in the stream, so it is read the same way as
        // every other key here and not from one operand in particular. A node carries at most one.
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
            // The members of a struct an argument points at: a nested node, not a string, so it is
            // the one key whose value is walked rather than copied.
            metadata.structTypeInfo = dyn_cast_or_null<MDNode>(node->getOperand(i + 1));
        }
        i += 1;   // the value this key's value is
    }
    return metadata;
}

// Is this node an argument node? A REAL one begins with an i32 index - !{i32 0, !"air.buffer", ...}
// - and the older sum.ll one begins with an "air." key that is not a threadgroup size.
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

// air.kernel's argument nodes, by the REAL shape first: a function, then an empty node, then ONE
// node that NESTS them all. The older shape - the size nodes and the argument nodes as siblings of
// the function - is read too, because two of this repository's own fixtures are in it and air2cpu's
// entryPoints() is what decides the entry points for both.
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

// The members of a struct an argument points at, as the metadata spells them: a flat list of
// alternating name, offset, type, in that order, repeated per member.
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

// One function: its name, and each argument with its index, its name, its access, its type and -
// for a buffer the port binds by reference - whether the AIR says the pointer is read-only.
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
        // The AIR's own words for the access - air.read_write or air.read_only - which is what the
        // header calls MTLArgumentAccessReadWrite and MTLArgumentAccessReadOnly. When the metadata
        // node is absent there is nothing to read, and the argument is written without an access
        // rather than with one guessed from whether the type is a pointer.
        // The access spellings, mapped to the header's OWN enumerators rather than to a pair of
        // words. MTLArgument.h:214 declares MTLArgumentAccess as ReadOnly = 0, ReadWrite = 1 and
        // WriteOnly = 2, and :296 documents all three: "read, write, read-write". So air.write is
        // WRITE-ONLY and not read-write: a texture declared access::write is neither, and calling
        // it read-write would be a real argument described wrongly, which is what a guess always is.
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
        // The type's OWN keys, which is where the element type of a buffer lives: LLVM's opaque
        // pointers carry no pointee, and "device float *" is a string in this metadata. Absent keys
        // are not written at all, so the reader answers MTLUnknown for what the AIR does not say.
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
        out += "<integer>0</integer>\n";   // the AIR carries no threadgroup size; the header calls it a hint
    }
    indent(out, depth + 1); out += "</array>\n";
    indent(out, depth);
    out += "</dict>\n";
}

// The whole file: a version this tool owns, and the functions in the order the module has them.
static std::string document(Module &module) {
    std::string out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    out += "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n";
    out += "<plist version=\"1.0\">\n<dict>\n";
    out += "  <key>version</key>\n  <integer>1</integer>\n";
    out += "  <key>functions</key>\n  <array>\n";
    NamedMDNode *named = module.getNamedMetadata("air.kernel");
    unsigned kernel = 0;
    for (Function *entry : entryPoints(module)) {
        // the entry's own air.kernel operand, so the argument nodes are the ones that belong to THIS
        // function and not the first function's
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

}  // namespace plist

}  // namespace

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

    // The type tree, beside the source. Optional on the command line, and refused rather than
    // skipped when it was asked for and cannot be written: a reflection object that finds no file
    // answers nothing, and a tool that says nothing about that is not honest.
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
        // The refusals are printed FIRST: the port answers an application that asks for a kernel the
        // tool could not translate by saying the log of the build that ran it says which, and a log
        // with no name in it is not that.
        for (const Refusal &refusal : refusals)
            printf("%s: REFUSED %s: %s\n", argv[1], refusal.name.c_str(), refusal.reason.c_str());
        fprintf(stderr, "%s: no kernel of this library could be translated\n", argv[1]);
        return 1;
    }

    std::string source = argv[2];
    // The generated source includes the SAME header the port's encoder includes, so the call
    // convention has one spelling and a mismatch is a compile error on one side or the other.
    // The generated source includes the SAME header the port's encoder includes, so the convention
    // has one spelling. The path is the one the build passed in; the generated file lives beside the
    // source that is written, and the include is a relative one, so a caller that copies the pair
    // elsewhere gets a build error rather than a second spelling.
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
