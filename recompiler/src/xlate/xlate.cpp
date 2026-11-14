#include "exports.h"
#include "macho.h"
#include "objc.h"
#include "tsd_scan.h"
#include "unwind.h"
#include "xl_guest_image.h"

#include <llvm-c/Core.h>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/DataLayout.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Intrinsics.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/IR/Verifier.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/Format.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Analysis/LazyValueInfo.h>
#include <llvm/IR/Operator.h>
#include <llvm/IR/GetElementPtrTypeIterator.h>
#include <llvm/Transforms/InstCombine/InstCombine.h>
#include <llvm/Transforms/Scalar/GVN.h>
#include <llvm/IR/CFG.h>
#include <llvm/Transforms/Utils/BasicBlockUtils.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include <llvm/Transforms/Utils/Local.h>
#include <llvm/Transforms/Utils/ModuleUtils.h>
#include <llvm/Transforms/Utils/ValueMapper.h>
#include <rellume/rellume.h>

#include <algorithm>
#include <fstream>
#include <map>
#include <set>
#include <tuple>

using namespace llvm;

static cl::list<std::string> Inputs(cl::Positional, cl::OneOrMore, cl::desc("<main image> [guest images...]"));
static cl::list<std::string> Bridges("bridge", cl::desc("An input image whose exports stand for host library symbols"));
static cl::list<std::string> Replaces("replaces", cl::desc("LIBRARY=IMAGE: binds that name LIBRARY are answered by the input IMAGE"));
static cl::opt<std::string> ResolvedOut("resolved-out", cl::desc("With --objc-manifest: write the symbols every bind of which an input image answers"));
static cl::opt<std::string> Output("output", cl::desc("Output bitcode"));
static cl::opt<std::string> IROutput("ir", cl::desc("Optional textual IR output"));
static cl::opt<std::string> LayoutOutput("layout", cl::desc("Linker arguments placing guest segments"));
static cl::opt<bool> Library("library", cl::desc("The output is a dylib whose guest segments are one image in a section (__XGUEST,__image) that the loader maps at their addresses, "
                                                 "with a table of the slots that hold host addresses, instead of segments the linker places there"));
static cl::opt<std::string> StateHeader("state-header", cl::desc("C header with guest register offsets and guest export addresses"));
static cl::opt<std::string> PassthroughPath("passthrough", cl::desc("Host symbols guest data may bind directly"));
static cl::opt<std::string> ObjCManifest("objc-manifest", cl::desc("Write the Objective-C metadata of the guest images as JSON"));
static cl::opt<std::string> CoveragePath("coverage", cl::desc("Only lift every instruction and list unsupported ones"));
static cl::opt<std::string> HostTriple("host-triple", cl::init("armv7-apple-ios6.0.0"));
static cl::opt<std::string> HostLayout("host-datalayout", cl::init("e-m:o-p:32:32-Fi8-f64:32:64-v64:32:64-v128:32:128-a:0:32-n32-S32"));
static cl::opt<uint64_t> Base("base", cl::init(0x10000000));
static cl::opt<bool> Optimize("optimize", cl::init(true));
static cl::opt<std::string> LiftTargets("lift-targets", cl::init("entries"),
                                        cl::desc("entries: a jump table target that is not a function start becomes an entry of the function that holds the table, "
                                                 "and the code the targets share is lifted once; functions: every target is a function of its own, with its own copy "
                                                 "of the code it reaches"));
static cl::opt<bool> TailCalls("tail-calls", cl::init(true),
                               cl::desc("A branch to the start of another function, and a fall through into it, is a tail call to that function; "
                                        "false lifts the code the branch reaches into the function that branches, as it was"));
static cl::opt<bool> DevirtExits("devirt-exits", cl::init(false),
                                 cl::desc("A jump out of a function to the constant address of another function (a tail call) calls that function directly, "
                                          "with a copy of the function's exit block of its own, instead of through xl_tail and its search of the function table"));
static cl::opt<bool> ReportDuplicates("report-duplicates", cl::init(false),
                                      cl::desc("Report how many guest instructions the lift decoded in all and how many different ones: the rest is code that "
                                               "more than one lifted function carries"));
static cl::opt<bool> SwiftHostAncestors("swift-host-ancestors", cl::init(false),
                                        cl::desc("Keep the guest's class layout for Swift classes that have a host ancestor"));
static cl::opt<std::string> NamespacePrefix("namespace-prefix", cl::init(""),
                                            cl::desc("The Objective-C classes of every guest image but the first (the runtime and overlays of a library) are "
                                                     "registered under this prefix, so a host that has its own copy of them keeps its names"));

namespace {

using xlate::Image;

constexpr const char *kTrapPrefix = "_xl_trap_";

uint64_t AlignUp(uint64_t value, uint64_t alignment) {
  return (value + alignment - 1) & ~(alignment - 1);
}

std::string Hex(uint64_t value) {
  std::string text;
  raw_string_ostream os(text);
  os << format_hex_no_prefix(value, 8);
  return text;
}

std::string IRName(const std::string &symbol) {
  if (!symbol.empty() && symbol[0] == '_') {
    return symbol.substr(1);
  }
  return "\1" + symbol;
}

bool IsPersonality(const std::string &symbol) {
  return symbol == "___objc_personality_v0" || symbol == "___gxx_personality_v0" || symbol == "___gcc_personality_v0";
}

std::string HostPersonality(const std::string &guest) {
  if (guest == "___objc_personality_v0") {
    return "__objc_personality_v0";
  }
  if (guest == "___gxx_personality_v0") {
    return "__gxx_personality_sj0";
  }
  if (guest == "___gcc_personality_v0") {
    return "__gcc_personality_sj0";
  }
  return {};
}

const std::map<std::string, uint64_t> &StateOffsets() {
  static const std::map<std::string, uint64_t> offsets = {
#define RELLUME_PUBLIC_REG(name, name_cap, reg_size, offset) {#name, offset},
#include <cpustruct-aarch64.inc>
#undef RELLUME_PUBLIC_REG
  };
  return offsets;
}

struct Program {
  std::vector<std::unique_ptr<Image>> images;
  xlate::GuestExports exports;
  std::map<uint64_t, uint64_t> stub_to_guest;
  std::map<uint64_t, std::string> stub_to_host;
  std::set<std::string> passthrough;
  std::set<uint64_t> functions;
  xlate::UnwindTable unwind;

  const Image *ImageAt(uint64_t host) const {
    for (auto &image : images) {
      if (host >= image->host(image->preferred_base()) && host < image->host(image->image_end())) {
        return image.get();
      }
    }
    return nullptr;
  }
};

static std::set<uint64_t> *g_trace = nullptr;
static std::map<uint64_t, std::set<uint64_t>> g_lift_sets;
static std::map<uint64_t, int> g_lift_kind;
static int g_kind = 0;

size_t ReadCode(size_t address, uint8_t *buffer, size_t size, void *user) {
  if (g_trace) {
    g_trace->insert(address);
  }
  auto program = static_cast<Program *>(user);
  auto image = program->ImageAt(address);
  if (!image || !image->IsExecutable(address) || program->stub_to_guest.count(address) ||
      program->stub_to_host.count(address)) {
    return 0;
  }
  auto section = image->SectionAt(address);
  auto end = image->host(section->addr + section->size);
  size = std::min<size_t>(size, end - address);
  return image->ReadBytes(address, buffer, size) ? size : 0;
}

bool LoadPassthrough(Program &program) {
  if (PassthroughPath.empty()) {
    return true;
  }
  std::ifstream input(PassthroughPath);
  if (!input) {
    errs() << "xlate: cannot read " << PassthroughPath << "\n";
    return false;
  }
  std::string line;
  while (std::getline(input, line)) {
    if (!line.empty() && line[0] != '#') {
      program.passthrough.insert(line);
    }
  }
  return true;
}

bool IsBridge(const std::string &path) {
  return llvm::any_of(Bridges, [&](const std::string &bridge) {
    bool same = false;
    return !sys::fs::equivalent(bridge, path, same) && same;
  });
}

std::vector<bool> HostAncestorImages(const Program &program) {
  std::vector<bool> result;
  for (auto &image : program.images) {
    bool runtime = IsBridge(image->path()) || image->exports().count("_swift_allocObject");
    for (auto &spec : Replaces) {
      auto split = spec.find('=');
      bool same = false;
      if (split != std::string::npos && !sys::fs::equivalent(spec.substr(split + 1), image->path(), same) && same) {
        runtime = true;
      }
    }
    result.push_back(SwiftHostAncestors && !runtime);
  }
  return result;
}

bool LayoutAndResolve(Program &program, bool strict) {
  uint64_t cursor = Base;
  for (auto &image : program.images) {
    auto base = image->preferred_base();
    image->set_slide(cursor - base);
    cursor = AlignUp(image->host(image->image_end()), 0x100000);
  }
  for (auto &image : program.images) {
    std::string error;
    if (!program.exports.Add(*image, IsBridge(image->path()), error)) {
      llvm::errs() << "xlate: " << error << "\n";
      return false;
    }
    for (auto vmaddr : image->functions()) {
      program.functions.insert(image->host(vmaddr));
    }
  }
  for (auto &spec : Replaces) {
    auto split = spec.find('=');
    const Image *target = nullptr;
    for (auto &image : program.images) {
      bool same = false;
      if (split != std::string::npos && !sys::fs::equivalent(spec.substr(split + 1), image->path(), same) && same) {
        target = image.get();
      }
    }
    if (!target) {
      llvm::errs() << "xlate: --replaces " << spec << ": expected LIBRARY=IMAGE, IMAGE being one of the inputs\n";
      return false;
    }
    std::string error;
    if (!program.exports.Replace(spec.substr(0, split), *target, error)) {
      llvm::errs() << "xlate: " << error << "\n";
      return false;
    }
  }
  bool ok = true;
  for (auto &image : program.images) {
    for (auto &[vmaddr, stub] : image->stubs()) {
      auto host = image->host(vmaddr);
      if (auto target = program.exports.Find(stub.library, stub.symbol)) {
        program.stub_to_guest[host] = *target;
      } else if (stub.symbol.rfind(kTrapPrefix, 0) == 0) {
        program.stub_to_host[host] = "xl_h_" + stub.symbol.substr(strlen(kTrapPrefix));
      } else if (stub.weak) {
        if (program.exports.Find({}, stub.symbol)) {
          errs() << "xlate: " << image->path() << ": weak import " << stub.symbol << " of " << stub.library
                 << " is left unbound although a guest image defines that name; a bind takes the library it names\n";
        }
      } else if (strict) {
        errs() << "xlate: " << image->path() << ": call stub for unresolved import " << stub.symbol;
        if (program.exports.Find({}, stub.symbol)) {
          errs() << " (a guest image defines that name, but the bind names " << stub.library << ")";
        }
        errs() << "\n";
        ok = false;
      }
    }
  }
  return ok;
}

bool WriteResolved(Program &program) {
  std::set<std::string> answered, host;
  auto note = [&](const std::string &library, const std::string &symbol) {
    (program.exports.Find(library, symbol) ? answered : host).insert(symbol);
  };
  for (auto &image : program.images) {
    for (auto &[vmaddr, stub] : image->stubs()) {
      note(stub.library, stub.symbol);
    }
    for (auto &[vmaddr, bind] : image->binds()) {
      note(bind.library, bind.symbol);
    }
    for (auto &[name, target] : image->reexports()) {
      (program.exports.Find(target.library, target.symbol) ? answered : host).insert(name);
    }
  }
  std::error_code ec;
  raw_fd_ostream os(ResolvedOut, ec);
  if (ec) {
    errs() << "xlate: " << ResolvedOut << ": " << ec.message() << "\n";
    return false;
  }
  for (auto &symbol : answered) {
    if (!host.count(symbol)) {
      os << symbol << "\n";
    }
  }
  return true;
}

class Lifter {
 public:
  Lifter(Program &program, Module &module) : program_(program), module_(module), context_(module.getContext()) {
    auto type = FunctionType::get(Type::getVoidTy(context_), {PointerType::get(context_, 0)}, false);
    call_ = Function::Create(type, GlobalValue::ExternalLinkage, "xl_call", module_);
    tail_ = Function::Create(type, GlobalValue::ExternalLinkage, "xl_tail", module_);
    config_ = ll_config_new();
    ll_config_set_architecture(config_, "aarch64");
    ll_config_set_call_ret_clobber_flags(config_, true);
    ll_config_set_call_func(config_, wrap(call_));
    ll_config_set_tail_func(config_, wrap(tail_));
    if (TailCalls) {
      ll_config_set_function_start_cb(
          config_, [](uintptr_t address, void *user) { return static_cast<Program *>(user)->functions.count(address) != 0; }, &program_);
    }
  }

  ~Lifter() { ll_config_free(config_); }

  Function *Lift(uint64_t address, const std::vector<uint64_t> &entries = {}) {
    auto func = ll_func_new(wrap(&module_), config_);
    std::set<uint64_t> seen;
    g_trace = ReportDuplicates ? &seen : nullptr;
    int failed = entries.empty() ? ll_func_decode_cfg(func, address, ReadCode, &program_)
                                 : ll_func_decode_entry(func, address, ReadCode, &program_);
    for (auto entry : entries) {
      if (!failed) {
        failed = ll_func_decode_entry(func, entry, ReadCode, &program_);
      }
    }
    g_trace = nullptr;
    if (!failed && ReportDuplicates) {
      g_lift_sets[address] = std::move(seen);
      g_lift_kind[address] = g_kind;
    }
    Function *lifted = nullptr;
    if (!failed) {
      LLVMValueRef raw = ll_func_lift(func);
      lifted = raw ? unwrap<Function>(raw) : nullptr;
    }
    ll_func_dispose(func);
    if (!lifted) {
      return nullptr;
    }
    lifted->setName("sub_" + Hex(address));
    lifted->setLinkage(GlobalValue::ExternalLinkage);
    lifted->setVisibility(GlobalValue::HiddenVisibility);
    functions[address] = lifted;
    for (auto entry : entries) {
      functions[entry] = lifted;
    }
    return lifted;
  }

  void Discard(uint64_t address, const std::vector<uint64_t> &entries) {
    auto found = functions.find(address);
    if (found == functions.end()) {
      return;
    }
    auto function = found->second;
    functions.erase(found);
    for (auto entry : entries) {
      functions.erase(entry);
    }
    function->eraseFromParent();
  }

  Function *Handler(const std::string &name) {
    if (auto existing = module_.getFunction(name)) {
      return existing;
    }
    return Function::Create(call_->getFunctionType(), GlobalValue::ExternalLinkage, name, module_);
  }

  Function *Target(uint64_t pc) {
    if (auto guest = program_.stub_to_guest.find(pc); guest != program_.stub_to_guest.end()) {
      pc = guest->second;
    }
    if (auto host = program_.stub_to_host.find(pc); host != program_.stub_to_host.end()) {
      return Handler(host->second);
    }
    auto found = functions.find(pc);
    return found == functions.end() ? nullptr : found->second;
  }

  std::vector<CallInst *> Calls() {
    std::vector<CallInst *> calls;
    for (auto user : call_->users()) {
      if (auto call = dyn_cast<CallInst>(user)) {
        calls.push_back(call);
      }
    }
    return calls;
  }

  std::vector<CallInst *> CallsIn(Function &function) {
    std::vector<CallInst *> calls;
    for (auto &block : function) {
      for (auto &inst : block) {
        if (auto call = dyn_cast<CallInst>(&inst); call && call->getCalledFunction() == call_) {
          calls.push_back(call);
        }
      }
    }
    return calls;
  }

  Function *Tail() { return tail_; }

  unsigned SplitExits() {
    unsigned count = 0;
    std::set<Function *> done;
    for (auto &[address, function] : functions) {
      if (!done.insert(function).second) {
        continue;
      }
      std::vector<CallInst *> jumps;
      for (auto &block : *function) {
        for (auto &inst : block) {
          if (auto call = dyn_cast<CallInst>(&inst); call && call->getCalledFunction() == tail_) {
            jumps.push_back(call);
          }
        }
      }
      for (auto call : jumps) {
        BasicBlock *exit = call->getParent();
        StoreInst *store = nullptr;
        for (auto it = call->getReverseIterator(); it != exit->rend(); ++it) {
          if (auto candidate = dyn_cast<StoreInst>(&*it); candidate && candidate->getPointerOperand() == call->getArgOperand(0)) {
            store = candidate;
            break;
          }
        }
        auto pc = store ? dyn_cast<PHINode>(store->getValueOperand()) : nullptr;
        if (!pc || pc->getParent() != exit) {
          continue;
        }
        std::vector<BasicBlock *> sources;
        for (unsigned i = 0; i < pc->getNumIncomingValues(); ++i) {
          auto constant = dyn_cast<ConstantInt>(pc->getIncomingValue(i));
          BasicBlock *source = pc->getIncomingBlock(i);
          if (constant && Target(constant->getZExtValue()) && std::find(sources.begin(), sources.end(), source) == sources.end()) {
            sources.push_back(source);
          }
        }
        for (auto source : sources) {
          ValueToValueMapTy map;
          for (auto &phi : exit->phis()) {
            map[&phi] = phi.getIncomingValueForBlock(source);
          }
          BasicBlock *copy = BasicBlock::Create(context_, "xl.exit", function);
          for (auto &inst : *exit) {
            if (isa<PHINode>(inst)) {
              continue;
            }
            Instruction *clone = inst.clone();
            clone->setName(inst.getName());
            map[&inst] = clone;
            clone->insertInto(copy, copy->end());
            RemapInstruction(clone, map, RF_NoModuleLevelChanges | RF_IgnoreMissingLocals);
          }
          source->getTerminator()->replaceSuccessorWith(exit, copy);
          for (auto &phi : exit->phis()) {
            while (phi.getBasicBlockIndex(source) >= 0) {
              phi.removeIncomingValue(source, false);
            }
          }
          ++count;
        }
        if (!sources.empty() && pred_empty(exit)) {
          DeleteDeadBlock(exit);
        }
      }
    }
    return count;
  }

  unsigned Devirtualize() {
    unsigned count = 0;
    std::vector<CallInst *> calls;
    for (auto dispatcher : {call_, tail_}) {
      for (auto user : dispatcher->users()) {
        if (auto call = dyn_cast<CallInst>(user)) {
          calls.push_back(call);
        }
      }
    }
    for (auto call : calls) {
      auto sptr = call->getArgOperand(0);
      std::optional<uint64_t> pc;
      for (auto it = call->getReverseIterator(); it != call->getParent()->rend(); ++it) {
        auto store = dyn_cast<StoreInst>(&*it);
        if (!store || store->getPointerOperand() != sptr) {
          continue;
        }
        if (auto constant = dyn_cast<ConstantInt>(store->getValueOperand())) {
          pc = constant->getZExtValue();
        }
        break;
      }
      if (!pc) {
        continue;
      }
      auto target = Target(*pc);
      if (!target) {
        continue;
      }
      call->setCalledFunction(target);
      ++count;
    }
    return count;
  }

  std::map<uint64_t, Function *> functions;

 private:
  Program &program_;
  Module &module_;
  LLVMContext &context_;
  Function *call_;
  Function *tail_;
  LLConfig *config_;
};


class JumpTables {
 public:
  explicit JumpTables(Program &program) : program_(program), starts_(program.functions) {}

  std::set<uint64_t> Targets(Function &lifted, uint64_t start, uint64_t address = 0, const std::vector<uint64_t> *variants = nullptr) {
    std::set<uint64_t> targets;
    auto tail = lifted.getParent()->getFunction("xl_tail");
    if (!tail) {
      return targets;
    }
    bool indirect = false;
    for (auto user : tail->users()) {
      auto call = dyn_cast<CallInst>(user);
      indirect |= call && call->getFunction() == &lifted;
    }
    if (!indirect || !HasIndirectBranch(start)) {
      return targets;
    }
    if (!variants) {
      Analyze(lifted, start, std::nullopt, address, targets);
      return targets;
    }
    for (auto variant : *variants) {
      Analyze(lifted, start, variant, address, targets);
    }
    return targets;
  }

 private:
  void Analyze(Function &lifted, uint64_t start, std::optional<uint64_t> variant, uint64_t address, std::set<uint64_t> &targets) {
    Module scratch("jump-tables", lifted.getContext());
    scratch.setDataLayout(lifted.getParent()->getDataLayout());
    dl_ = &scratch.getDataLayout();
    ValueToValueMapTy map;
    auto clone = Function::Create(lifted.getFunctionType(), GlobalValue::ExternalLinkage, lifted.getName(), scratch);
    auto dest = clone->arg_begin();
    for (auto &argument : lifted.args()) {
      map[&argument] = &*dest++;
    }
    SmallVector<ReturnInst *, 4> returns;
    CloneFunctionInto(clone, &lifted, map, CloneFunctionChangeType::DifferentModule, returns);
    if (variant) {
      auto &first = clone->getEntryBlock();
      if (auto dispatch = dyn_cast<SwitchInst>(first.getTerminator())) {
        auto destination = dispatch->getDefaultDest();
        if (*variant != address) {
          auto found = dispatch->findCaseValue(ConstantInt::get(cast<IntegerType>(dispatch->getCondition()->getType()), *variant));
          if (found != dispatch->case_default()) {
            destination = found->getCaseSuccessor();
          }
        }
        dispatch->eraseFromParent();
        BranchInst::Create(destination, &first);
        removeUnreachableBlocks(*clone);
      }
    }
    PreserveCalleeSaved(*clone);
    LoopAnalysisManager lam;
    FunctionAnalysisManager fam;
    CGSCCAnalysisManager cgam;
    ModuleAnalysisManager mam;
    PassBuilder builder;
    builder.registerModuleAnalyses(mam);
    builder.registerCGSCCAnalyses(cgam);
    builder.registerFunctionAnalyses(fam);
    builder.registerLoopAnalyses(lam);
    builder.crossRegisterProxies(lam, fam, cgam, mam);
    FunctionPassManager passes;
    passes.addPass(InstCombinePass());
    passes.addPass(GVNPass());
    passes.addPass(InstCombinePass());
    passes.run(*clone, fam);
    auto &lvi = fam.getResult<LazyValueAnalysis>(*clone);
    uint64_t end = NextFunction(start);
    for (auto &block : *clone) {
      for (auto &inst : block) {
        auto call = dyn_cast<CallInst>(&inst);
        if (!call || !call->getCalledFunction() || call->getCalledFunction()->getName() != "xl_tail") {
          continue;
        }
        StoreInst *store = nullptr;
        for (auto it = call->getReverseIterator(); it != block.rend(); ++it) {
          if (auto candidate = dyn_cast<StoreInst>(&*it); candidate && candidate->getPointerOperand() == clone->getArg(0)) {
            store = candidate;
            break;
          }
        }
        if (!store) {
          continue;
        }
        std::vector<Value *> values = {store->getValueOperand()};
        if (auto phi = dyn_cast<PHINode>(values[0])) {
          values.assign(phi->incoming_values().begin(), phi->incoming_values().end());
        }
        for (auto value : values) {
          Resolve(value, lvi, start, end, targets);
        }
      }
    }
  }

  uint64_t NextFunction(uint64_t start) {
    auto next = starts_.upper_bound(start);
    return next == starts_.end() ? start + 0x100000 : *next;
  }

  bool HasIndirectBranch(uint64_t start) {
    auto image = program_.ImageAt(start);
    if (!image) {
      return true;
    }
    uint64_t end = NextFunction(start);
    for (uint64_t address = start; address + 4 <= end; address += 4) {
      uint8_t bytes[4];
      if (!image->ReadBytes(address, bytes, sizeof bytes)) {
        return true;
      }
      uint32_t word;
      memcpy(&word, bytes, sizeof word);
      if ((word & 0xFFFFFC1Fu) == 0xD61F0000u) {
        return true;
      }
    }
    return false;
  }

  static void PreserveCalleeSaved(Function &clone) {
    auto &offsets = StateOffsets();
    auto &context = clone.getContext();
    auto i8 = Type::getInt8Ty(context);
    auto i64 = Type::getInt64Ty(context);
    std::vector<uint64_t> saved;
    for (int n = 19; n <= 29; ++n) {
      saved.push_back(offsets.at("x" + std::to_string(n)));
    }
    saved.push_back(offsets.at("sp"));
    std::vector<CallInst *> calls;
    for (auto &block : clone) {
      for (auto &inst : block) {
        auto call = dyn_cast<CallInst>(&inst);
        if (call && call->getCalledFunction() && call->getCalledFunction()->getName() == "xl_call") {
          calls.push_back(call);
        }
      }
    }
    auto state = clone.getArg(0);
    for (auto call : calls) {
      IRBuilder<> before(call);
      IRBuilder<> after(call->getNextNode());
      for (auto offset : saved) {
        auto slot = before.CreateConstInBoundsGEP1_64(i8, state, offset);
        auto value = before.CreateAlignedLoad(i64, slot, Align(8));
        after.CreateAlignedStore(value, slot, Align(8));
      }
    }
  }

  static Value *Strip(Value *value) {
    if (auto expr = dyn_cast<ConstantExpr>(value); expr && expr->getOpcode() == Instruction::IntToPtr) {
      return expr->getOperand(0);
    }
    if (auto cast = dyn_cast<CastInst>(value); cast && (isa<IntToPtrInst>(cast) || isa<PtrToIntInst>(cast))) {
      return cast->getOperand(0);
    }
    return value;
  }

  static Value *StripCasts(Value *value) {
    for (;;) {
      value = Strip(value);
      if (auto cast = dyn_cast<CastInst>(value); cast && (isa<ZExtInst>(cast) || isa<SExtInst>(cast) || isa<TruncInst>(cast))) {
        value = cast->getOperand(0);
        continue;
      }
      return value;
    }
  }

  bool FindLoad(Value *value, LoadInst *&load, int depth) {
    if (depth > 12) {
      return false;
    }
    if (auto found = dyn_cast<LoadInst>(value)) {
      if (load && load != found) {
        return false;
      }
      load = found;
      return true;
    }
    if (isa<ConstantInt>(value)) {
      return true;
    }
    if (auto op = dyn_cast<BinaryOperator>(value)) {
      return FindLoad(op->getOperand(0), load, depth + 1) && FindLoad(op->getOperand(1), load, depth + 1);
    }
    if (auto cast = dyn_cast<CastInst>(value)) {
      return FindLoad(cast->getOperand(0), load, depth + 1);
    }
    return false;
  }

  bool FindIndex(Value *value, Value *&index, int depth) {
    value = Strip(value);
    if (depth > 12) {
      return false;
    }
    if (isa<ConstantInt>(value)) {
      return true;
    }
    if (auto gep = dyn_cast<GEPOperator>(value)) {
      if (!FindIndex(gep->getPointerOperand(), index, depth + 1)) {
        return false;
      }
      for (unsigned i = 1; i < gep->getNumOperands(); ++i) {
        auto operand = gep->getOperand(i);
        if (isa<ConstantInt>(operand)) {
          continue;
        }
        auto candidate = StripCasts(operand);
        if (index && index != candidate) {
          return false;
        }
        index = candidate;
      }
      return true;
    }
    if (auto op = dyn_cast<BinaryOperator>(value)) {
      return FindIndex(op->getOperand(0), index, depth + 1) && FindIndex(op->getOperand(1), index, depth + 1);
    }
    if (auto cast = dyn_cast<CastInst>(value); cast && (isa<ZExtInst>(cast) || isa<SExtInst>(cast) || isa<TruncInst>(cast))) {
      if (!isa<Instruction>(cast->getOperand(0)) || !index || index == cast->getOperand(0)) {
        if (!index && isa<Instruction>(cast->getOperand(0)) && !isa<BinaryOperator>(cast->getOperand(0)) &&
            !isa<CastInst>(cast->getOperand(0))) {
          index = cast->getOperand(0);
          return true;
        }
      }
      return FindIndex(cast->getOperand(0), index, depth + 1);
    }
    if (isa<Instruction>(value) || isa<Argument>(value)) {
      if (index && index != value) {
        return false;
      }
      index = value;
      return true;
    }
    return false;
  }

  std::optional<uint64_t> Evaluate(Value *value, Value *index, uint64_t index_value, LoadInst *load,
                                   std::optional<uint64_t> loaded, int depth) {
    value = Strip(value);
    if (depth > 16) {
      return std::nullopt;
    }
    if (value == index) {
      return index_value;
    }
    if (value == load) {
      return loaded;
    }
    if (auto constant = dyn_cast<ConstantInt>(value)) {
      return constant->getZExtValue();
    }
    if (auto gep = dyn_cast<GEPOperator>(value)) {
      auto base = Evaluate(gep->getPointerOperand(), index, index_value, load, loaded, depth + 1);
      if (!base) {
        return std::nullopt;
      }
      uint64_t address = *base;
      auto gti = gep_type_begin(gep);
      for (unsigned i = 1; i < gep->getNumOperands(); ++i, ++gti) {
        auto idx = Evaluate(gep->getOperand(i), index, index_value, load, loaded, depth + 1);
        if (!idx) {
          return std::nullopt;
        }
        if (StructType *st = gti.getStructTypeOrNull()) {
          address += dl_->getStructLayout(st)->getElementOffset(*idx);
        } else {
          int64_t signed_index = SignExtend64(*idx, gep->getOperand(i)->getType()->getIntegerBitWidth());
          address += signed_index * static_cast<int64_t>(dl_->getTypeAllocSize(gti.getIndexedType()));
        }
      }
      return address;
    }
    if (auto cast = dyn_cast<CastInst>(value)) {
      auto operand = Evaluate(cast->getOperand(0), index, index_value, load, loaded, depth + 1);
      if (!operand) {
        return std::nullopt;
      }
      unsigned from = cast->getSrcTy()->getScalarSizeInBits();
      unsigned to = cast->getDestTy()->getScalarSizeInBits();
      uint64_t mask_from = from >= 64 ? ~0ull : (1ull << from) - 1;
      uint64_t mask_to = to >= 64 ? ~0ull : (1ull << to) - 1;
      if (isa<SExtInst>(cast)) {
        return static_cast<uint64_t>(SignExtend64(*operand & mask_from, from)) & mask_to;
      }
      return *operand & mask_from & mask_to;
    }
    if (auto op = dyn_cast<BinaryOperator>(value)) {
      auto a = Evaluate(op->getOperand(0), index, index_value, load, loaded, depth + 1);
      auto b = Evaluate(op->getOperand(1), index, index_value, load, loaded, depth + 1);
      if (!a || !b) {
        return std::nullopt;
      }
      unsigned bits = op->getType()->getIntegerBitWidth();
      uint64_t mask = bits >= 64 ? ~0ull : (1ull << bits) - 1;
      switch (op->getOpcode()) {
        case Instruction::Add: return (*a + *b) & mask;
        case Instruction::Sub: return (*a - *b) & mask;
        case Instruction::Mul: return (*a * *b) & mask;
        case Instruction::Shl: return (*a << *b) & mask;
        case Instruction::LShr: return (*a >> *b) & mask;
        case Instruction::AShr: return static_cast<uint64_t>(SignExtend64(*a, bits) >> *b) & mask;
        case Instruction::And: return *a & *b;
        case Instruction::Or: return *a | *b;
        case Instruction::Xor: return *a ^ *b;
        default: return std::nullopt;
      }
    }
    if (auto cmp = dyn_cast<ICmpInst>(value)) {
      auto a = Evaluate(cmp->getOperand(0), index, index_value, load, loaded, depth + 1);
      auto b = Evaluate(cmp->getOperand(1), index, index_value, load, loaded, depth + 1);
      if (!a || !b) {
        return std::nullopt;
      }
      unsigned bits = cmp->getOperand(0)->getType()->getIntegerBitWidth();
      int64_t sa = SignExtend64(*a, bits), sb = SignExtend64(*b, bits);
      uint64_t mask = bits >= 64 ? ~0ull : (1ull << bits) - 1;
      uint64_t ua = *a & mask, ub = *b & mask;
      switch (cmp->getPredicate()) {
        case CmpInst::ICMP_EQ: return ua == ub;
        case CmpInst::ICMP_NE: return ua != ub;
        case CmpInst::ICMP_UGT: return ua > ub;
        case CmpInst::ICMP_UGE: return ua >= ub;
        case CmpInst::ICMP_ULT: return ua < ub;
        case CmpInst::ICMP_ULE: return ua <= ub;
        case CmpInst::ICMP_SGT: return sa > sb;
        case CmpInst::ICMP_SGE: return sa >= sb;
        case CmpInst::ICMP_SLT: return sa < sb;
        case CmpInst::ICMP_SLE: return sa <= sb;
        default: return std::nullopt;
      }
    }
    if (auto sel = dyn_cast<SelectInst>(value)) {
      auto cond = Evaluate(sel->getCondition(), index, index_value, load, loaded, depth + 1);
      if (!cond) {
        return std::nullopt;
      }
      return Evaluate(*cond ? sel->getTrueValue() : sel->getFalseValue(), index, index_value, load, loaded, depth + 1);
    }
    return std::nullopt;
  }

  std::vector<std::pair<Value *, bool>> Guards(BasicBlock *bb) {
    std::vector<std::pair<Value *, bool>> guards;
    for (int steps = 0; steps < 32 && bb; ++steps) {
      auto pred = bb->getSinglePredecessor();
      if (!pred) {
        break;
      }
      if (auto br = dyn_cast<BranchInst>(pred->getTerminator()); br && br->isConditional()) {
        if (br->getSuccessor(0) == bb) {
          guards.push_back({br->getCondition(), true});
        } else if (br->getSuccessor(1) == bb) {
          guards.push_back({br->getCondition(), false});
        }
      }
      bb = pred;
    }
    return guards;
  }

  void Resolve(Value *pc, LazyValueInfo &lvi, uint64_t start, uint64_t end, std::set<uint64_t> &targets) {
    if (isa<ConstantInt>(pc)) {
      return;
    }
    LoadInst *load = nullptr;
    if (!FindLoad(pc, load, 0) || !load) {
      return;
    }
    Value *index = nullptr;
    if (!FindIndex(load->getPointerOperand(), index, 0) || !index) {
      return;
    }
    uint64_t limit = 4096;
    if (index->getType()->isIntegerTy()) {
      auto range = lvi.getConstantRange(index, load, false);
      if (!range.isFullSet() && !range.getUnsignedMax().isMaxValue()) {
        limit = std::min<uint64_t>(limit, range.getUnsignedMax().getZExtValue() + 1);
      }
    }
    std::vector<std::pair<Value *, bool>> guards;
    for (auto &guard : Guards(load->getParent())) {
      if (Evaluate(guard.first, index, 0, load, 0, 0) && Evaluate(guard.first, index, 1, load, 0, 0)) {
        guards.push_back(guard);
      }
    }
    unsigned width = load->getType()->getIntegerBitWidth() / 8;
    if (!width || width > 8) {
      return;
    }
    std::vector<std::pair<uint64_t, unsigned>> entries;
    if (auto base = Evaluate(load->getPointerOperand(), index, 0, nullptr, std::nullopt, 0)) {
      entries.push_back({*base, width});
    }
    for (uint64_t i = 0; i < limit; ++i) {
      bool in_domain = true;
      for (auto &guard : guards) {
        auto value = Evaluate(guard.first, index, i, load, 0, 0);
        if (value && (*value != 0) != guard.second) {
          in_domain = false;
          break;
        }
      }
      if (!in_domain) {
        continue;
      }
      auto address = Evaluate(load->getPointerOperand(), index, i, nullptr, std::nullopt, 0);
      if (!address) {
        return;
      }
      auto image = program_.ImageAt(*address);
      uint8_t bytes[8] = {};
      if (!image || !image->ReadBytes(*address, bytes, width)) {
        return;
      }
      entries.push_back({*address, width});
      uint64_t raw = 0;
      memcpy(&raw, bytes, width);
      auto target = Evaluate(pc, index, i, load, raw, 0);
      if (!target || *target < start || *target >= end || (*target & 3)) {
        if (limit == 4096 && guards.empty()) {
          return;
        }
        continue;
      }
      targets.insert(*target);
    }
    for (auto &[address, size] : entries) {
      data_[address] = std::max<uint64_t>(data_[address], address + size);
    }
  }

  Program &program_;
  std::set<uint64_t> starts_;
  std::map<uint64_t, uint64_t> data_;
  const DataLayout *dl_ = nullptr;

 public:
  bool IsData(uint64_t address) const {
    auto it = data_.upper_bound(address);
    return it != data_.begin() && address < std::prev(it)->second;
  }

  uint64_t Owner(uint64_t address) const {
    auto it = starts_.upper_bound(address);
    return it == starts_.begin() ? address : *std::prev(it);
  }
};

struct GuestSegment {
  const Image *image;
  xlate::Segment segment;
  std::string host_name;
};

Constant *HostSymbol(Module &module, const std::string &symbol) {
  auto name = IRName(symbol);
  if (auto global = module.getNamedValue(name)) {
    return global;
  }
  return new GlobalVariable(module, Type::getInt8Ty(module.getContext()), false, GlobalValue::ExternalLinkage,
                            nullptr, name);
}

class LandingPads {
 public:
  LandingPads(Program &program, Lifter &lifter, Module &module)
      : program_(program), lifter_(lifter), module_(module), context_(module.getContext()) {
    auto &offsets = StateOffsets();
    x30_ = offsets.at("x30");
    for (int n = 19; n <= 29; ++n) {
      saved_.push_back({offsets.at("x" + std::to_string(n)), 8});
    }
    saved_.push_back({offsets.at("sp"), 8});
    for (int n = 8; n <= 15; ++n) {
      saved_.push_back({offsets.at("v" + std::to_string(n)), 16});
    }
  }

  std::set<uint64_t> Targets(Function &lifted) {
    std::set<uint64_t> targets;
    for (auto call : lifter_.CallsIn(lifted)) {
      auto site = SiteOf(call);
      auto landing = site ? program_.unwind.Find(*site) : std::nullopt;
      std::string why;
      if (landing && landing->site->pad && Describe(*landing, why)) {
        targets.insert(landing->site->pad);
        continuations_.insert(landing->site->pad);
      }
    }
    return targets;
  }

  unsigned Lower(const std::vector<CallInst *> &calls) {
    for (auto address : continuations_) {
      if (auto found = lifter_.functions.find(address); found != lifter_.functions.end() && found->second->getName() == "sub_" + Hex(address)) {
        continuation_functions_.insert(found->second);
      }
    }
    std::map<std::string, std::pair<Function *, std::vector<Site>>> by_function;
    for (auto call : calls) {
      auto address = SiteOf(call);
      auto landing = address ? program_.unwind.Find(*address) : std::nullopt;
      if (landing && landing->site->pad) {
        auto &entry = by_function[call->getFunction()->getName().str()];
        entry.first = call->getFunction();
        entry.second.push_back({call, *address, *landing});
      }
    }
    unsigned lowered = 0;
    for (auto &[name, entry] : by_function) {
      lowered += LowerFunction(*entry.first, entry.second);
    }
    EmitResume();
    for (auto &[reason, count] : unsupported_) {
      errs() << "xlate: " << count << " call site(s) with a landing pad were left as plain calls: " << reason << "\n";
    }
    return lowered;
  }

  unsigned functions() const { return functions_; }

 private:
  struct Site {
    CallInst *call;
    uint64_t address;
    xlate::Landing landing;
  };

  struct Pad {
    uint64_t address = 0;
    std::string personality;
    bool cleanup = false;
    std::vector<std::pair<Constant *, int64_t>> catches;
  };

  struct Saved {
    uint64_t offset;
    uint64_t size;
  };

  std::optional<uint64_t> SiteOf(CallInst *call) {
    auto state = call->getArgOperand(0);
    for (auto it = call->getReverseIterator(); it != call->getParent()->rend(); ++it) {
      auto store = dyn_cast<StoreInst>(&*it);
      auto gep = store ? dyn_cast<GEPOperator>(store->getPointerOperand()) : nullptr;
      if (!gep || gep->getPointerOperand() != state || gep->getNumIndices() != 1) {
        continue;
      }
      auto offset = dyn_cast<ConstantInt>(gep->getOperand(1));
      auto value = dyn_cast<ConstantInt>(store->getValueOperand());
      if (offset && value && offset->getZExtValue() == x30_) {
        return value->getZExtValue() - 4;
      }
    }
    return std::nullopt;
  }

  Constant *LocalType(const xlate::ExceptionType &type) {
    auto key = std::make_tuple(type.name, type.cls, type.cls_symbol);
    if (auto found = local_types_.find(key); found != local_types_.end()) {
      return found->second;
    }
    auto ptr = PointerType::get(context_, 0);
    auto i32 = Type::getInt32Ty(context_);
    auto layout = StructType::get(context_, {ptr, ptr, ptr});
    Constant *vtable = ConstantExpr::getPtrAdd(HostSymbol(module_, "_objc_ehtype_vtable"), ConstantInt::get(i32, 8));
    Constant *name = ConstantExpr::getIntToPtr(ConstantInt::get(i32, type.name), ptr);
    Constant *cls = type.cls_symbol.empty() ? ConstantExpr::getIntToPtr(ConstantInt::get(i32, type.cls), ptr)
                                            : HostSymbol(module_, type.cls_symbol);
    auto global = new GlobalVariable(module_, layout, false, GlobalValue::InternalLinkage,
                                     ConstantStruct::get(layout, {vtable, name, cls}), "xl_ehtype_" + Hex(type.name));
    local_types_[key] = global;
    return global;
  }

  std::optional<Pad> Describe(const xlate::Landing &landing, std::string &why) {
    Pad pad;
    pad.address = landing.site->pad;
    pad.personality = HostPersonality(landing.function->personality);
    if (pad.personality.empty()) {
      why = "its personality routine is " +
            (landing.function->personality.empty() ? std::string("not an imported symbol") : landing.function->personality);
      return std::nullopt;
    }
    for (auto filter : landing.site->filters) {
      if (filter == 0) {
        pad.cleanup = true;
        continue;
      }
      if (filter < 0) {
        why = "it has an exception specification";
        return std::nullopt;
      }
      if (static_cast<uint64_t>(filter) > landing.function->types.size()) {
        why = "its action refers to a type outside the type table";
        return std::nullopt;
      }
      auto &type = landing.function->types[filter - 1];
      Constant *clause = nullptr;
      switch (type.kind) {
        case xlate::ExceptionType::CatchAll:
          clause = ConstantPointerNull::get(PointerType::get(context_, 0));
          break;
        case xlate::ExceptionType::Import:
          clause = HostSymbol(module_, type.symbol);
          break;
        case xlate::ExceptionType::LocalObjC:
          clause = LocalType(type);
          break;
        case xlate::ExceptionType::LocalOther:
          break;
      }
      if (clause) {
        pad.catches.push_back({clause, filter});
      }
    }
    if (!pad.cleanup && pad.catches.empty()) {
      return std::nullopt;
    }
    return pad;
  }

  std::set<size_t> Written(Function &function, Value *state) {
    std::set<size_t> written;
    for (auto &block : function) {
      for (auto &inst : block) {
        auto store = dyn_cast<StoreInst>(&inst);
        auto gep = store ? dyn_cast<GEPOperator>(store->getPointerOperand()) : nullptr;
        if (!gep || gep->getPointerOperand() != state || gep->getNumIndices() != 1) {
          continue;
        }
        auto index = dyn_cast<ConstantInt>(gep->getOperand(1));
        if (!index) {
          continue;
        }
        for (size_t k = 0; k < saved_.size(); ++k) {
          if (index->getZExtValue() >= saved_[k].offset && index->getZExtValue() < saved_[k].offset + saved_[k].size) {
            written.insert(k);
          }
        }
      }
    }
    return written;
  }

  void Capture(IRBuilder<> &b, Value *state, AllocaInst *snapshot, size_t k) {
    auto i8 = Type::getInt8Ty(context_);
    auto i64 = Type::getInt64Ty(context_);
    auto value = b.CreateAlignedLoad(i64, b.CreateConstGEP1_64(i8, state, saved_[k].offset), Align(8));
    b.CreateAlignedStore(value, b.CreateConstInBoundsGEP2_64(snapshot->getAllocatedType(), snapshot, 0, k), Align(8));
  }

  BasicBlock *PadBlock(Function &function, Value *state, AllocaInst *snapshot, const Pad &pad) {
    auto target = lifter_.functions.find(pad.address);
    if (target == lifter_.functions.end()) {
      unsupported_["the landing pad was not lifted"]++;
      return nullptr;
    }
    auto i8 = Type::getInt8Ty(context_);
    auto i32 = Type::getInt32Ty(context_);
    auto i64 = Type::getInt64Ty(context_);
    auto ptr = PointerType::get(context_, 0);
    auto block = BasicBlock::Create(context_, "xl.pad", &function);
    IRBuilder<> b(block);
    auto landing = b.CreateLandingPad(StructType::get(context_, {ptr, i32}), pad.catches.size());
    landing->setCleanup(pad.cleanup);
    for (auto &[type, filter] : pad.catches) {
      landing->addClause(type);
    }
    Value *exception = b.CreateExtractValue(landing, 0);
    Value *selector = b.CreateExtractValue(landing, 1);
    Value *guest = ConstantInt::get(i32, 0);
    for (auto it = pad.catches.rbegin(); it != pad.catches.rend(); ++it) {
      Value *id = b.CreateIntrinsic(Intrinsic::eh_typeid_for, {ptr}, {it->first});
      guest = b.CreateSelect(b.CreateICmpEQ(selector, id), ConstantInt::get(i32, it->second), guest);
    }
    for (size_t k = 0; k < saved_.size(); ++k) {
      auto value = b.CreateAlignedLoad(i64, b.CreateConstInBoundsGEP2_64(snapshot->getAllocatedType(), snapshot, 0, k), Align(8));
      b.CreateAlignedStore(value, b.CreateConstGEP1_64(i8, state, saved_[k].offset), Align(8));
    }
    auto &offsets = StateOffsets();
    b.CreateAlignedStore(b.CreateZExt(b.CreatePtrToInt(exception, i32), i64), b.CreateConstGEP1_64(i8, state, offsets.at("x0")), Align(8));
    b.CreateAlignedStore(b.CreateZExt(guest, i64), b.CreateConstGEP1_64(i8, state, offsets.at("x1")), Align(8));
    resumable_.insert(pad.address);
    if (continuation_functions_.count(&function)) {
      b.CreateAlignedStore(ConstantInt::get(i64, kResumeMarker | pad.address), b.CreateConstGEP1_64(i8, state, offsets.at("pc")), Align(16));
    } else {
      b.CreateCall(Resume()->getFunctionType(), Resume(), {state, ConstantInt::get(i32, pad.address)});
    }
    b.CreateRetVoid();
    return block;
  }

  Function *Resume() {
    if (!resume_) {
      auto ptr = PointerType::get(context_, 0);
      auto type = FunctionType::get(Type::getVoidTy(context_), {ptr, Type::getInt32Ty(context_)}, false);
      resume_ = Function::Create(type, GlobalValue::InternalLinkage, "xl.resume", module_);
      resume_->addFnAttr(Attribute::NoInline);
    }
    return resume_;
  }

  void EmitResume() {
    if (!resume_) {
      return;
    }
    auto i32 = Type::getInt32Ty(context_);
    auto i64 = Type::getInt64Ty(context_);
    auto state = resume_->getArg(0);
    auto entry = BasicBlock::Create(context_, "entry", resume_);
    auto dispatch = BasicBlock::Create(context_, "dispatch", resume_);
    auto check = BasicBlock::Create(context_, "check", resume_);
    auto again = BasicBlock::Create(context_, "again", resume_);
    auto done = BasicBlock::Create(context_, "done", resume_);
    auto bad = BasicBlock::Create(context_, "bad", resume_);
    IRBuilder<> b(entry);
    b.CreateBr(dispatch);
    b.SetInsertPoint(dispatch);
    auto pad = b.CreatePHI(i32, 2);
    auto select = b.CreateSwitch(pad, bad, resumable_.size());
    for (auto address : resumable_) {
      auto target = lifter_.functions.at(address);
      auto block = BasicBlock::Create(context_, "pad." + Hex(address), resume_);
      select->addCase(ConstantInt::get(i32, address), block);
      IRBuilder<> call(block);
      call.CreateAlignedStore(ConstantInt::get(i64, address), state, Align(16));
      call.CreateCall(target->getFunctionType(), target, {state})->setIsNoInline();
      call.CreateBr(check);
    }
    b.SetInsertPoint(check);
    auto pc = b.CreateAlignedLoad(i64, state, Align(16));
    b.CreateCondBr(b.CreateICmpSLT(pc, ConstantInt::get(i64, 0)), again, done);
    b.SetInsertPoint(again);
    auto next = b.CreateTrunc(pc, i32);
    b.CreateBr(dispatch);
    pad->addIncoming(resume_->getArg(1), entry);
    pad->addIncoming(next, again);
    b.SetInsertPoint(done);
    b.CreateRetVoid();
    b.SetInsertPoint(bad);
    b.CreateUnreachable();
  }

  unsigned LowerFunction(Function &function, std::vector<Site> &sites) {
    std::sort(sites.begin(), sites.end(), [](const Site &a, const Site &b) { return a.address < b.address; });
    struct Usable {
      Site site;
      Pad pad;
    };
    std::vector<Usable> usable;
    std::string personality;
    for (auto &site : sites) {
      std::string why;
      auto pad = Describe(site.landing, why);
      if (!pad) {
        if (!why.empty()) {
          unsupported_[why]++;
        }
        continue;
      }
      if (personality.empty()) {
        personality = pad->personality;
      } else if (pad->personality != personality) {
        unsupported_["one function mixes personality routines"]++;
        continue;
      }
      usable.push_back({site, std::move(*pad)});
    }
    if (usable.empty()) {
      return 0;
    }
    Value *state = function.getArg(0);
    auto written = Written(function, state);
    IRBuilder<> entry(&*function.getEntryBlock().getFirstInsertionPt());
    auto snapshot = entry.CreateAlloca(ArrayType::get(Type::getInt64Ty(context_), saved_.size()), nullptr, "xl.snapshot");
    for (size_t k = 0; k < saved_.size(); ++k) {
      if (!written.count(k)) {
        Capture(entry, state, snapshot, k);
      }
    }
    std::map<std::pair<uint64_t, uint64_t>, BasicBlock *> blocks;
    unsigned lowered = 0;
    for (auto &item : usable) {
      auto &block = blocks[{item.pad.address, item.site.landing.site->action}];
      if (!block) {
        block = PadBlock(function, state, snapshot, item.pad);
      }
      if (!block) {
        continue;
      }
      IRBuilder<> before(item.site.call);
      for (auto k : written) {
        Capture(before, state, snapshot, k);
      }
      changeToInvokeAndSplitBasicBlock(item.site.call, block);
      ++lowered;
    }
    if (lowered) {
      auto routine = module_.getFunction(personality);
      if (!routine) {
        routine = Function::Create(FunctionType::get(Type::getInt32Ty(context_), {}, true), GlobalValue::ExternalLinkage,
                                   personality, module_);
      }
      function.setPersonalityFn(routine);
      for (auto &block : function) {
        for (auto &inst : block) {
          if (auto call = dyn_cast<CallInst>(&inst); call && call->isMustTailCall()) {
            call->setTailCallKind(CallInst::TCK_None);
          }
        }
      }
      ++functions_;
    }
    return lowered;
  }

  static constexpr uint64_t kResumeMarker = 1ull << 63;

  Program &program_;
  Lifter &lifter_;
  Module &module_;
  LLVMContext &context_;
  uint64_t x30_ = 0;
  std::vector<Saved> saved_;
  std::set<uint64_t> continuations_;
  std::set<Function *> continuation_functions_;
  std::set<uint64_t> resumable_;
  Function *resume_ = nullptr;
  std::map<std::tuple<uint64_t, uint64_t, std::string>, Constant *> local_types_;
  std::map<std::string, unsigned> unsupported_;
  unsigned functions_ = 0;
};

struct Override {
  std::vector<Constant *> fields;
  uint64_t size = 0;
  GlobalVariable *global = nullptr;
};

using Overrides = std::map<uint64_t, Override>;

Overrides ObjCOverrides(Module &module, const std::vector<xlate::ObjCImage> &objc) {
  auto &context = module.getContext();
  auto i32 = Type::getInt32Ty(context);
  auto i8 = Type::getInt8Ty(context);
  Overrides overrides;
  auto padding = [&](uint64_t size) { return ConstantAggregateZero::get(ArrayType::get(i8, size)); };
  auto symbol = [&](const std::string &name) {
    return ConstantExpr::getPtrToInt(HostSymbol(module, "_" + name), i32);
  };
  auto class_type = StructType::get(context, {i32, i32, i32, i32, i32, ArrayType::get(i8, 20)}, true);
  std::map<uint64_t, GlobalVariable *> classes;
  for (auto &image : objc) {
    for (auto &cls : image.classes) {
      for (auto address : Library ? std::vector<uint64_t>{} : std::vector<uint64_t>{cls.address, cls.metaclass}) {
        auto global = new GlobalVariable(module, class_type, false, GlobalValue::ExternalLinkage, nullptr,
                                         "xl_guest_class_" + Hex(address));
        global->setVisibility(GlobalValue::HiddenVisibility);
        classes[address] = global;
      }
    }
  }
  auto pointer = [&](const xlate::Pointer &value) -> Constant * {
    switch (value.kind) {
      case xlate::Pointer::Local:
        if (auto found = classes.find(value.host); found != classes.end()) {
          return ConstantExpr::getPtrToInt(found->second, i32);
        }
        return ConstantInt::get(i32, value.host);
      case xlate::Pointer::Raw:
        return ConstantInt::get(i32, value.host);
      case xlate::Pointer::Import:
        return ConstantExpr::getPtrToInt(HostSymbol(module, value.symbol), i32);
      case xlate::Pointer::Null:
        break;
    }
    return ConstantInt::get(i32, 0);
  };
  for (size_t image = 0; image < objc.size(); ++image) {
    for (size_t index = 0; index < objc[image].classes.size(); ++index) {
      auto &cls = objc[image].classes[index];
      auto suffix = std::to_string(image) + "_" + std::to_string(index);
      xlate::Pointer metaclass;
      metaclass.kind = xlate::Pointer::Local;
      metaclass.host = cls.metaclass;
      Override object;
      object.fields = {pointer(metaclass), pointer(cls.superclass), symbol("_objc_empty_cache"),
                       symbol("_objc_empty_vtable"), symbol("xl_objc_ro_" + suffix), padding(20)};
      object.size = 40;
      object.global = Library ? nullptr : classes[cls.address];
      overrides[cls.address] = object;
      Override meta;
      meta.fields = {pointer(cls.meta_isa), pointer(cls.meta_superclass), symbol("_objc_empty_cache"),
                     symbol("_objc_empty_vtable"), symbol("xl_objc_metaro_" + suffix), padding(20)};
      meta.size = 40;
      meta.global = Library ? nullptr : classes[cls.metaclass];
      overrides[cls.metaclass] = meta;
    }
    for (auto &protocol : objc[image].protocols) {
      auto name = [&](const char *part) { return "xl_objc_proto_" + Hex(protocol.address) + "_" + part; };
      auto list = [&](bool present, const char *part) -> Constant * {
        return present ? symbol(name(part)) : ConstantInt::get(i32, 0);
      };
      uint64_t occupied = protocol.size >= 44 ? protocol.size : 96;
      auto protocol_type = StructType::get(
          context, {i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, ArrayType::get(i8, occupied - 44)}, true);
      Override value;
      value.fields = {ConstantInt::get(i32, 0),
                      ConstantInt::get(i32, protocol.name_address),
                      list(!protocol.protocols.empty(), "protocols"),
                      list(!protocol.instance_methods.empty(), "instance"),
                      list(!protocol.class_methods.empty(), "class"),
                      list(!protocol.optional_instance_methods.empty(), "optional_instance"),
                      list(!protocol.optional_class_methods.empty(), "optional_class"),
                      list(!protocol.properties.empty(), "properties"),
                      ConstantInt::get(i32, 40),
                      ConstantInt::get(i32, protocol.flags),
                      ConstantInt::get(i32, 0),
                      padding(occupied - 44)};
      value.size = occupied;
      if (!Library) {
        value.global = new GlobalVariable(module, protocol_type, false, GlobalValue::ExternalLinkage, nullptr,
                                          "xl_guest_protocol_" + Hex(protocol.address));
        value.global->setVisibility(GlobalValue::HiddenVisibility);
      }
      overrides[protocol.address] = value;
    }
    for (auto &string : objc[image].strings) {
      Override value;
      value.fields = {symbol("__CFConstantStringClassReference"), ConstantInt::get(i32, string.flags),
                      ConstantInt::get(i32, string.string), ConstantInt::get(i32, string.length), padding(16)};
      value.size = 32;
      overrides[string.address] = value;
    }
  }
  return overrides;
}

bool SkippedSegment(const xlate::Segment &segment) {
  return segment.name == "__PAGEZERO" || segment.name == "__LINKEDIT" || !segment.vmsize;
}

Overrides SegmentPieces(Program &program, Module &module, Image &image, const xlate::Segment &segment, const Overrides &overrides, bool &ok) {
  auto &context = module.getContext();
  auto i32 = Type::getInt32Ty(context);
  auto i64 = Type::getInt64Ty(context);
  std::map<uint64_t, Constant *> slots;
  for (auto &[vmaddr, target] : image.rebases()) {
    if (vmaddr < segment.vmaddr || vmaddr >= segment.vmaddr + segment.vmsize) {
      continue;
    }
    uint64_t value = target & 0x00FFFFFFFFFFFFFFull;
    if (value < image.preferred_base() || value >= image.image_end()) {
      errs() << "xlate: " << image.path() << ": rebase at 0x" << Hex(vmaddr) << " targets 0x" << Hex(value)
             << " outside the image\n";
      ok = false;
      continue;
    }
    slots[vmaddr] = ConstantInt::get(i64, image.host(value));
  }
  for (auto &[vmaddr, bind] : image.binds()) {
    if (vmaddr < segment.vmaddr || vmaddr >= segment.vmaddr + segment.vmsize) {
      continue;
    }
    if (auto target = program.exports.Find(bind.library, bind.symbol)) {
      slots[vmaddr] = ConstantInt::get(i64, *target + bind.addend);
    } else if (program.passthrough.count(bind.symbol)) {
      auto host = HostSymbol(module, bind.symbol);
      if (bind.weak_import) {
        if (auto global = dyn_cast<GlobalVariable>(host)) {
          global->setLinkage(GlobalValue::ExternalWeakLinkage);
        }
      }
      Constant *address = ConstantExpr::getPtrToInt(host, i32);
      if (bind.addend) {
        address = ConstantExpr::getAdd(address, ConstantInt::get(i32, bind.addend));
      }
      slots[vmaddr] = ConstantStruct::getAnon(context, {address, ConstantInt::get(i32, 0)}, true);
    } else if (IsPersonality(bind.symbol)) {
      slots[vmaddr] = ConstantInt::get(i64, 0);
    } else if (bind.symbol == "dyld_stub_binder" || bind.weak_import || bind.symbol.rfind(kTrapPrefix, 0) == 0) {
      if (bind.weak_import && program.exports.Find({}, bind.symbol)) {
        errs() << "xlate: " << image.path() << ": weak import " << bind.symbol << " of " << bind.library
               << " is left unbound although a guest image defines that name; a bind takes the library it names\n";
      }
      slots[vmaddr] = ConstantInt::get(i64, 0);
    } else {
      errs() << "xlate: " << image.path() << ": data bind to unresolved symbol " << bind.symbol << "\n";
      ok = false;
    }
  }
  Overrides pieces;
  for (auto &[vmaddr, value] : slots) {
    Override piece;
    piece.fields = {value};
    piece.size = 8;
    pieces[vmaddr] = piece;
  }
  for (auto &[host, piece] : overrides) {
    uint64_t vmaddr = host - image.slide();
    if (vmaddr < segment.vmaddr || vmaddr >= segment.vmaddr + segment.vmsize) {
      continue;
    }
    pieces.erase(pieces.lower_bound(vmaddr), pieces.lower_bound(vmaddr + piece.size));
    pieces[vmaddr] = piece;
  }
  return pieces;
}

struct HostSlot {
  uint64_t address;
  Constant *value;
};

bool Flatten(const DataLayout &layout, Constant *constant, uint64_t offset, std::vector<uint8_t> &bytes, uint64_t address,
             std::vector<HostSlot> &slots) {
  uint64_t size = layout.getTypeAllocSize(constant->getType()).getFixedValue();
  if (offset + size > bytes.size()) {
    return false;
  }
  if (auto integer = dyn_cast<ConstantInt>(constant)) {
    uint64_t value = integer->getZExtValue();
    for (unsigned index = 0; index < layout.getTypeStoreSize(integer->getType()).getFixedValue(); ++index) {
      bytes[offset + index] = value >> (8 * index);
    }
    return true;
  }
  if (isa<ConstantAggregateZero>(constant)) {
    std::fill_n(bytes.begin() + offset, size, 0);
    return true;
  }
  if (auto aggregate = dyn_cast<ConstantStruct>(constant)) {
    auto &structure = *layout.getStructLayout(aggregate->getType());
    for (unsigned index = 0; index < aggregate->getNumOperands(); ++index) {
      if (!Flatten(layout, aggregate->getOperand(index), offset + structure.getElementOffset(index), bytes, address, slots)) {
        return false;
      }
    }
    return true;
  }
  if (constant->getType()->isIntegerTy(32)) {
    slots.push_back({address + offset, constant});
    return true;
  }
  return false;
}

template <typename T>
void Store(std::vector<uint8_t> &blob, size_t offset, const T &value) {
  std::memcpy(blob.data() + offset, &value, sizeof value);
}

bool EmitGuestImage(Program &program, Module &module, const Overrides &overrides) {
  auto &context = module.getContext();
  auto i32 = Type::getInt32Ty(context);
  auto &layout = module.getDataLayout();
  struct Record {
    xl_guest_segment header;
    std::vector<uint8_t> bytes;
  };
  std::vector<Record> records;
  std::vector<HostSlot> slots;
  bool ok = true;
  for (auto &image : program.images) {
    for (auto &segment : image->segments()) {
      if (SkippedSegment(segment)) {
        continue;
      }
      uint64_t address = image->host(segment.vmaddr);
      if (address % XL_GUEST_GRANULE || segment.vmsize % XL_GUEST_GRANULE || address + segment.vmsize > UINT32_MAX) {
        errs() << "xlate: " << image->path() << ": segment " << segment.name << " at 0x" << Hex(address) << " of 0x" << Hex(segment.vmsize)
               << " bytes is not a whole number of 0x" << Hex(XL_GUEST_GRANULE) << " byte granules below 4 GB\n";
        ok = false;
        continue;
      }
      std::vector<uint8_t> bytes(segment.vmsize);
      image->ReadBytes(image->host(segment.vmaddr), bytes.data(), bytes.size());
      for (auto &[vmaddr, piece] : SegmentPieces(program, module, *image, segment, overrides, ok)) {
        uint64_t offset = vmaddr - segment.vmaddr;
        for (auto field : piece.fields) {
          if (!Flatten(layout, field, offset, bytes, address, slots)) {
            errs() << "xlate: " << image->path() << ": the field at 0x" << Hex(address + offset) << " is not a number or a host address\n";
            ok = false;
            break;
          }
          offset += layout.getTypeAllocSize(field->getType()).getFixedValue();
        }
      }
      size_t length = bytes.size();
      while (length && !bytes[length - 1]) {
        --length;
      }
      length = std::min<uint64_t>(AlignUp(length, XL_GUEST_GRANULE), bytes.size());
      bytes.resize(length);
      Record record;
      record.header = {static_cast<uint32_t>(address), static_cast<uint32_t>(segment.vmsize), 0, static_cast<uint32_t>(length),
                       static_cast<uint32_t>(segment.initprot & (XL_GUEST_READ | XL_GUEST_WRITE))};
      record.bytes = std::move(bytes);
      records.push_back(std::move(record));
    }
  }
  if (records.empty()) {
    errs() << "xlate: no guest segment to put in the library\n";
    return false;
  }
  if (!ok) {
    return false;
  }
  xl_guest_header header = {XL_GUEST_MAGIC, XL_GUEST_VERSION, UINT32_MAX, 0, static_cast<uint32_t>(records.size())};
  uint64_t cursor = AlignUp(sizeof header + records.size() * sizeof(xl_guest_segment), XL_GUEST_GRANULE);
  for (auto &record : records) {
    header.low = std::min(header.low, record.header.address);
    header.high = std::max(header.high, record.header.address + record.header.size);
    if (record.header.length) {
      record.header.offset = cursor;
      cursor += record.header.length;
    }
  }
  std::vector<uint8_t> blob(cursor);
  Store(blob, 0, header);
  for (size_t index = 0; index < records.size(); ++index) {
    Store(blob, sizeof header + index * sizeof(xl_guest_segment), records[index].header);
    std::copy(records[index].bytes.begin(), records[index].bytes.end(), blob.begin() + records[index].header.offset);
  }
  auto array = ConstantDataArray::get(context, ArrayRef<uint8_t>(blob));
  auto image = new GlobalVariable(module, array->getType(), true, GlobalValue::InternalLinkage, array, "xl_guest_image");
  image->setSection(std::string(XL_GUEST_SEGMENT) + "," + XL_GUEST_SECTION);
  image->setAlignment(Align(XL_GUEST_GRANULE));
  appendToCompilerUsed(module, {image});

  std::sort(slots.begin(), slots.end(), [](const HostSlot &a, const HostSlot &b) { return a.address < b.address; });
  auto slot_type = StructType::get(context, {i32, i32});
  std::vector<Constant *> entries;
  for (auto &slot : slots) {
    entries.push_back(ConstantStruct::get(slot_type, {ConstantInt::get(i32, slot.address), slot.value}));
  }
  auto table_type = ArrayType::get(slot_type, entries.size());
  new GlobalVariable(module, table_type, true, GlobalValue::ExternalLinkage, ConstantArray::get(table_type, entries), "xl_guest_slots");
  new GlobalVariable(module, i32, true, GlobalValue::ExternalLinkage, ConstantInt::get(i32, entries.size()), "xl_guest_slot_count");
  errs() << "xlate: guest image 0x" << Hex(header.low) << "-0x" << Hex(header.high) << ", " << records.size() << " segments, " << blob.size()
         << " bytes in the library, " << entries.size() << " slots hold host addresses\n";
  return true;
}

bool MergesData(const Image &image) {
  uint64_t previous_end = 0;
  bool first = true;
  for (auto &segment : image.segments()) {
    if (segment.name == "__PAGEZERO" || segment.name == "__LINKEDIT" || !segment.vmsize || segment.name == "__TEXT") {
      continue;
    }
    if (!first && segment.vmaddr != previous_end) {
      return false;
    }
    first = false;
    previous_end = segment.vmaddr + segment.vmsize;
  }
  return true;
}

std::string HostSegmentName(unsigned image_index, bool merge_data, const xlate::Segment &segment) {
  if (merge_data && segment.name != "__TEXT") {
    return "__X" + std::to_string(image_index) + "DATA";
  }
  return "__X" + std::to_string(image_index) + segment.name.substr(2, std::min<size_t>(12, segment.name.size() - 2));
}

constexpr unsigned kExecutableSegmentsBeforeGuest = 3;
constexpr unsigned kBindSegmentIndexLimit = 16;

bool CheckExecutableSegmentLimit(const Program &program) {
  std::vector<std::string> order;
  std::map<std::string, bool> writable;
  unsigned image_index = 0;
  for (auto &image : program.images) {
    bool merge_data = MergesData(*image);
    for (auto &segment : image->segments()) {
      if (SkippedSegment(segment)) {
        continue;
      }
      auto name = HostSegmentName(image_index, merge_data, segment);
      if (!writable.count(name)) {
        order.push_back(name);
      }
      writable[name] = writable[name] || (segment.initprot & 2);
    }
    ++image_index;
  }
  for (size_t position = 0; position < order.size(); ++position) {
    unsigned index = kExecutableSegmentsBeforeGuest + static_cast<unsigned>(position);
    if (writable[order[position]] && index >= kBindSegmentIndexLimit) {
      errs() << "xlate: the executable would hold " << order.size() << " guest segments of " << program.images.size()
             << " images after __PAGEZERO, __TEXT and __DATA, and the writable segment " << order[position] << " would be segment "
             << index << ": dyld's bind and rebase opcodes name a segment with 4 bits, so a fixup in a segment past index "
             << kBindSegmentIndexLimit - 1 << " lands in another segment and the program dies before main. An executable takes at most "
             << (kBindSegmentIndexLimit - kExecutableSegmentsBeforeGuest) / 2 << " guest images; translate with --library (XL_LIBRARY=1 in translate.lua), "
             << "where the guest is one image and has no segments of its own\n";
      return false;
    }
  }
  return true;
}

bool EmitGuestData(Program &program, Module &module, std::vector<GuestSegment> &out, const Overrides &overrides) {
  auto &context = module.getContext();
  bool ok = true;
  unsigned image_index = 0;
  for (auto &image : program.images) {
    bool merge_data = MergesData(*image);
    for (auto &segment : image->segments()) {
      if (SkippedSegment(segment)) {
        continue;
      }
      std::string host_name = HostSegmentName(image_index, merge_data, segment);
      std::vector<uint8_t> bytes(segment.vmsize);
      image->ReadBytes(image->host(segment.vmaddr), bytes.data(), bytes.size());
      auto pieces = SegmentPieces(program, module, *image, segment, overrides, ok);
      std::vector<Constant *> fields;
      std::vector<Type *> types;
      uint64_t cursor = segment.vmaddr;
      uint64_t chunk_start = segment.vmaddr;
      auto place = [&](GlobalVariable *global) {
        global->removeFromParent();
        module.insertGlobalVariable(global);
        global->setSection(host_name + ",__image");
        global->setAlignment(Align(1));
        appendToCompilerUsed(module, {global});
      };
      auto close_chunk = [&]() {
        if (fields.empty()) {
          return;
        }
        auto type = StructType::get(context, types, true);
        auto global = new GlobalVariable(module, type, false, GlobalValue::InternalLinkage,
                                         ConstantStruct::get(type, fields),
                                         "guest_" + std::to_string(image_index) + "_" + Hex(chunk_start));
        place(global);
        fields.clear();
        types.clear();
      };
      auto flush = [&](uint64_t until) {
        if (until > cursor) {
          auto begin = bytes.data() + (cursor - segment.vmaddr);
          auto array = ConstantDataArray::get(context, ArrayRef<uint8_t>(begin, until - cursor));
          fields.push_back(array);
          types.push_back(array->getType());
          cursor = until;
        }
      };
      for (auto &[vmaddr, piece] : pieces) {
        flush(vmaddr);
        if (piece.global) {
          close_chunk();
          piece.global->setInitializer(ConstantStruct::get(cast<StructType>(piece.global->getValueType()), piece.fields));
          place(piece.global);
          cursor = vmaddr + piece.size;
          chunk_start = cursor;
          continue;
        }
        for (auto value : piece.fields) {
          fields.push_back(value);
          types.push_back(value->getType());
        }
        cursor = vmaddr + piece.size;
      }
      flush(segment.vmaddr + segment.vmsize);
      close_chunk();
      out.push_back({image.get(), segment, host_name});
    }
    ++image_index;
  }
  return ok;
}

void EmitTables(Program &program, Lifter &lifter, Module &module) {
  auto &context = module.getContext();
  auto i32 = Type::getInt32Ty(context);
  auto ptr = PointerType::get(context, 0);
  auto entry_type = StructType::get(context, {i32, ptr});
  std::map<uint64_t, Function *> table(lifter.functions.begin(), lifter.functions.end());
  for (auto &[stub, target] : program.stub_to_guest) {
    if (auto function = lifter.Target(stub)) {
      table[stub] = function;
    }
  }
  for (auto &[stub, name] : program.stub_to_host) {
    table[stub] = lifter.Handler(name);
  }
  std::vector<Constant *> entries;
  for (auto &[address, function] : table) {
    entries.push_back(ConstantStruct::get(entry_type, {ConstantInt::get(i32, address), function}));
  }
  auto array_type = ArrayType::get(entry_type, entries.size());
  new GlobalVariable(module, array_type, true, GlobalValue::ExternalLinkage, ConstantArray::get(array_type, entries),
                     "xl_functions");
  new GlobalVariable(module, i32, true, GlobalValue::ExternalLinkage, ConstantInt::get(i32, entries.size()),
                     "xl_function_count");
  auto &main_image = program.images.front();
  uint64_t entry = main_image->entry() ? main_image->host(*main_image->entry()) : 0;
  new GlobalVariable(module, i32, true, GlobalValue::ExternalLinkage, ConstantInt::get(i32, entry),
                     "xl_entry_address");
  std::vector<Constant *> initializers;
  for (auto it = program.images.rbegin(); it != program.images.rend(); ++it) {
    auto &image = *it;
    for (auto &section : image->sections()) {
      uint32_t section_type = section.flags & MachO::SECTION_TYPE;
      if (section_type == MachO::S_MOD_INIT_FUNC_POINTERS) {
        for (uint64_t offset = 0; offset + 8 <= section.size; offset += 8) {
          auto rebase = image->rebases().find(section.addr + offset);
          if (rebase != image->rebases().end()) {
            initializers.push_back(ConstantInt::get(i32, image->host(rebase->second & 0x00FFFFFFFFFFFFFFull)));
          }
        }
      } else if (section_type == MachO::S_INIT_FUNC_OFFSETS) {
        for (uint64_t offset = 0; offset + 4 <= section.size; offset += 4) {
          uint32_t rel = 0;
          if (!image->ReadBytes(image->host(section.addr + offset), reinterpret_cast<uint8_t *>(&rel), 4)) {
            continue;
          }
          initializers.push_back(ConstantInt::get(i32, image->host(image->preferred_base() + rel)));
        }
      }
    }
  }
  auto initializer_type = ArrayType::get(i32, initializers.size());
  new GlobalVariable(module, initializer_type, true, GlobalValue::ExternalLinkage,
                     ConstantArray::get(initializer_type, initializers), "xl_initializers");
  new GlobalVariable(module, i32, true, GlobalValue::ExternalLinkage, ConstantInt::get(i32, initializers.size()),
                     "xl_initializer_count");

  auto tlv_type = StructType::get(context, {i32, i32, i32, i32, i32});
  std::vector<Constant *> tlv_regions;
  for (auto &image : program.images) {
    const xlate::Section *vars = nullptr, *data = nullptr, *bss = nullptr;
    for (auto &section : image->sections()) {
      switch (section.flags & MachO::SECTION_TYPE) {
        case MachO::S_THREAD_LOCAL_VARIABLES: vars = &section; break;
        case MachO::S_THREAD_LOCAL_REGULAR: data = &section; break;
        case MachO::S_THREAD_LOCAL_ZEROFILL: bss = &section; break;
        default: break;
      }
    }
    if (!vars) {
      continue;
    }
    uint64_t data_size = data ? data->size : 0;
    uint64_t bss_size = bss ? bss->size : 0;
    tlv_regions.push_back(ConstantStruct::get(
        tlv_type, {ConstantInt::get(i32, image->host(vars->addr)),
                   ConstantInt::get(i32, image->host(vars->addr + vars->size)),
                   ConstantInt::get(i32, data ? image->host(data->addr) : 0),
                   ConstantInt::get(i32, data_size), ConstantInt::get(i32, data_size + bss_size)}));
  }
  auto tlv_array_type = ArrayType::get(tlv_type, tlv_regions.size());
  new GlobalVariable(module, tlv_array_type, true, GlobalValue::ExternalLinkage,
                     ConstantArray::get(tlv_array_type, tlv_regions), "xl_tlv_regions");
  new GlobalVariable(module, i32, true, GlobalValue::ExternalLinkage, ConstantInt::get(i32, tlv_regions.size()),
                     "xl_tlv_region_count");
}

bool WriteLayout(const std::vector<GuestSegment> &segments) {
  if (LayoutOutput.empty()) {
    return true;
  }
  std::error_code ec;
  raw_fd_ostream os(LayoutOutput, ec);
  if (ec) {
    errs() << "xlate: " << LayoutOutput << ": " << ec.message() << "\n";
    return false;
  }
  std::vector<std::string> order;
  std::map<std::string, uint64_t> lowest;
  std::map<std::string, bool> writable;
  for (auto &entry : segments) {
    uint64_t address = entry.image->host(entry.segment.vmaddr);
    if (!lowest.count(entry.host_name)) {
      order.push_back(entry.host_name);
      lowest[entry.host_name] = address;
    } else {
      lowest[entry.host_name] = std::min(lowest[entry.host_name], address);
    }
    writable[entry.host_name] = writable[entry.host_name] || (entry.segment.initprot & 2);
  }
  for (auto &name : order) {
    os << "-Wl,-segaddr," << name << ",0x" << Hex(lowest[name]) << "\n";
    const char *prot = writable[name] ? "rw" : "r";
    os << "-Wl,-segprot," << name << "," << prot << "," << prot << "\n";
  }
  if (Library) {
    os << "-Wl,-segprot," << XL_GUEST_SEGMENT << ",r,r\n";
  }
  return true;
}

bool WriteStateHeader(const Program &program) {
  if (StateHeader.empty()) {
    return true;
  }
  std::error_code ec;
  raw_fd_ostream os(StateHeader, ec);
  if (ec) {
    errs() << "xlate: " << StateHeader << ": " << ec.message() << "\n";
    return false;
  }
  os << "#pragma once\n";
  uint64_t size = 0;
#define RELLUME_PUBLIC_REG(name, name_cap, reg_size, offset) \
  os << "#define XL_OFFSET_" #name_cap " " << (offset) << "u\n"; \
  size = std::max<uint64_t>(size, (offset) + (reg_size));
#include <cpustruct-aarch64.inc>
#undef RELLUME_PUBLIC_REG
  os << "#define XL_STATE_SIZE " << AlignUp(size, 16) << "u\n";
  for (size_t index = 1; index < program.images.size(); ++index) {
    for (auto &[name, vmaddr] : program.images[index]->exports()) {
      std::string macro = name.substr(name[0] == '_' ? 1 : 0);
      std::replace_if(macro.begin(), macro.end(), [](char c) { return !isalnum(static_cast<unsigned char>(c)); }, '_');
      os << "#define XL_GUEST_" << macro << " 0x" << Hex(program.images[index]->host(vmaddr)) << "u\n";
    }
  }
  os << "struct xl_guest_image { const void *header; long slide; };\n";
  os << "static const struct xl_guest_image xl_guest_images[] = {\n";
  for (auto &image : program.images) {
    os << "  { (const void *)0x" << Hex(image->host(image->preferred_base())) << "u, "
       << static_cast<int64_t>(image->slide()) << "L },\n";
  }
  os << "};\n";
  os << "static const unsigned xl_guest_image_count = " << program.images.size() << "u;\n";
  return true;
}

void RunPipeline(Module &module) {
  LoopAnalysisManager lam;
  FunctionAnalysisManager fam;
  CGSCCAnalysisManager cgam;
  ModuleAnalysisManager mam;
  PassBuilder builder;
  builder.registerModuleAnalyses(mam);
  builder.registerCGSCCAnalyses(cgam);
  builder.registerFunctionAnalyses(fam);
  builder.registerLoopAnalyses(lam);
  builder.crossRegisterProxies(lam, fam, cgam, mam);
  builder.buildPerModuleDefaultPipeline(OptimizationLevel::O2).run(module, mam);
}

unsigned EnterEntries(Lifter &lifter, Module &module, const std::map<uint64_t, std::vector<uint64_t>> &merged) {
  auto tail = module.getFunction("xl_tail");
  if (!tail) {
    return 0;
  }
  auto &context = module.getContext();
  auto i64 = Type::getInt64Ty(context);
  unsigned count = 0;
  for (auto &[address, entries] : merged) {
    Function *parent = lifter.functions.at(address);
    std::vector<CallInst *> jumps;
    for (auto &block : *parent) {
      for (auto &inst : block) {
        if (auto call = dyn_cast<CallInst>(&inst); call && call->getCalledFunction() == tail) {
          jumps.push_back(call);
        }
      }
    }
    for (auto call : jumps) {
      auto state = call->getArgOperand(0);
      Value *pc = nullptr;
      for (auto it = call->getReverseIterator(); it != call->getParent()->rend(); ++it) {
        if (auto store = dyn_cast<StoreInst>(&*it); store && store->getPointerOperand() == state) {
          pc = store->getValueOperand();
          break;
        }
      }
      if (!pc || isa<ConstantInt>(pc) || pc->getType() != i64) {
        continue;
      }
      BasicBlock *block = call->getParent();
      BasicBlock *original = block->splitBasicBlock(call, "xl.jump");
      block->getTerminator()->eraseFromParent();
      BasicBlock *enter = BasicBlock::Create(context, "xl.enter", parent);
      IRBuilder<> inside(enter);
      CallInst *again = inside.CreateCall(parent->getFunctionType(), parent, {state});
      again->setCallingConv(call->getCallingConv());
      again->setTailCallKind(call->getTailCallKind());
      inside.CreateRetVoid();
      IRBuilder<> before(block);
      SwitchInst *dispatch = before.CreateSwitch(pc, original, entries.size());
      for (auto entry : entries) {
        dispatch->addCase(ConstantInt::get(i64, entry), enter);
      }
      ++count;
    }
  }
  return count;
}

int Coverage(Program &program) {
  std::error_code ec;
  raw_fd_ostream os(CoveragePath, ec);
  LLVMContext context;
  Module module("coverage", context);
  module.setDataLayout(HostLayout);
  auto config = ll_config_new();
  ll_config_set_architecture(config, "aarch64");
  uint64_t total = 0, failed = 0;
  for (auto &image : program.images) {
    for (auto &section : image->sections()) {
      if (!(section.flags & MachO::S_ATTR_PURE_INSTRUCTIONS) || section.sectname != "__text") {
        continue;
      }
      for (uint64_t offset = 0; offset + 4 <= section.size; offset += 4) {
        uint64_t address = image->host(section.addr + offset);
        uint8_t bytes[4];
        image->ReadBytes(address, bytes, 4);
        uint32_t word = bytes[0] | bytes[1] << 8 | bytes[2] << 16 | (uint32_t)bytes[3] << 24;
        auto func = ll_func_new(wrap(&module), config);
        bool decoded = ll_func_decode_instr(func, address, ReadCode, &program) == 0;
        LLVMValueRef raw = decoded ? ll_func_lift(func) : nullptr;
        Function *lifted = raw ? unwrap<Function>(raw) : nullptr;
        ll_func_dispose(func);
        ++total;
        bool unhandled = !lifted;
        if (lifted) {
          for (auto &block : *lifted) {
            for (auto &inst : block) {
              auto store = dyn_cast<StoreInst>(&inst);
              if (store && store->getPointerOperand() == lifted->getArg(0)) {
                if (auto pc = dyn_cast<ConstantInt>(store->getValueOperand()); pc && pc->getZExtValue() == address) {
                  unhandled = true;
                }
              }
            }
          }
          lifted->eraseFromParent();
        }
        if (unhandled) {
          ++failed;
          os << Hex(section.addr + offset) << " " << format_hex_no_prefix(word, 8) << "\n";
        }
      }
    }
  }
  ll_config_free(config);
  outs() << "coverage: " << failed << " of " << total << " instructions not lifted\n";
  return 0;
}

}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv, "xlate: arm64 Mach-O to armv7 LLVM bitcode");
  Program program;
  for (auto &path : Inputs) {
    std::string error;
    auto image = Image::Load(path, error);
    if (!image) {
      errs() << "xlate: " << error << "\n";
      return 1;
    }
    for (auto &warning : image->warnings()) {
      errs() << "xlate: warning: " << warning << "\n";
    }
    program.images.push_back(std::move(image));
  }
  {
    std::vector<std::string> tsd_violations;
    for (auto &image : program.images) {
      xlate::ScanTSDOffsets(*image, tsd_violations);
    }
    if (!tsd_violations.empty()) {
      errs() << "xlate: TPIDRRO_EL0 accessed at an offset the fake TSD block does not model:\n";
      for (auto &line : tsd_violations) {
        errs() << "  " << line << "\n";
      }
      errs() << "xlate: add the offset to src/xlate/tsd_scan.h's kAllowedTSDOffsets, citing the "
              << "real Darwin TSD slot it is, and back it with real content in src/runtime/runtime.c "
              << "-- or fix the guest code path if this access was not meant to happen\n";
      return 1;
    }
  }
  if (!ResolvedOut.empty() && ObjCManifest.empty()) {
    errs() << "xlate: --resolved-out is written with --objc-manifest\n";
    return 1;
  }
  if (!CoveragePath.empty()) {
    if (!LayoutAndResolve(program, false)) {
      return 1;
    }
    return Coverage(program);
  }
  std::vector<xlate::ObjCImage> objc;
  std::vector<const Image *> images;
  if (!ObjCManifest.empty()) {
    if (!LayoutAndResolve(program, false)) {
      return 1;
    }
    for (auto &image : program.images) {
      images.push_back(image.get());
      objc.push_back(xlate::AnalyzeObjC(*image));
    }
    xlate::ResolveGuestImports(objc, program.exports);
    if (std::string error; !xlate::SplitGuestLayoutClasses(objc, HostAncestorImages(program), error)) {
      errs() << "xlate: " << error << "\n";
      return 1;
    }
    if (!ResolvedOut.empty() && !WriteResolved(program)) {
      return 1;
    }
    std::error_code ec;
    raw_fd_ostream os(ObjCManifest, ec);
    if (ec) {
      errs() << "xlate: " << ObjCManifest << ": " << ec.message() << "\n";
      return 1;
    }
    for (size_t index = 1; index < objc.size() && !NamespacePrefix.empty(); ++index) {
      objc[index].namespaced = true;
    }
    xlate::WriteManifest(os, images, objc, NamespacePrefix);
    return 0;
  }
  if (Output.empty() || (!Library && !CheckExecutableSegmentLimit(program)) || !LoadPassthrough(program) || !LayoutAndResolve(program, true)) {
    return 1;
  }
  for (auto &image : program.images) {
    objc.push_back(xlate::AnalyzeObjC(*image));
    for (auto &error : objc.back().errors) {
      errs() << "xlate: " << image->path() << ": " << error << "\n";
    }
  }
  xlate::ResolveGuestImports(objc, program.exports);
  if (std::string error; !xlate::SplitGuestLayoutClasses(objc, HostAncestorImages(program), error)) {
    errs() << "xlate: " << error << "\n";
    return 1;
  }
  LLVMContext context;
  Module module("xlate", context);
  module.setTargetTriple(Triple(HostTriple));
  module.setDataLayout(HostLayout);
  for (auto &image : program.images) {
    std::vector<std::string> problems;
    program.unwind.Add(*image, problems);
    for (auto &problem : problems) {
      errs() << "xlate: warning: " << image->path() << ": " << problem << "\n";
    }
  }
  Lifter lifter(program, module);
  LandingPads pads(program, lifter, module);
  unsigned failures = 0;
  JumpTables tables(program);
  std::set<uint64_t> pending(program.functions.begin(), program.functions.end());
  unsigned table_targets = 0;
  unsigned pad_targets = 0;
  unsigned table_data = 0;
  if (LiftTargets != "entries" && LiftTargets != "functions") {
    errs() << "xlate: --lift-targets is entries or functions, not " << LiftTargets << "\n";
    return 1;
  }
  std::map<uint64_t, std::vector<uint64_t>> merged;
  std::map<uint64_t, uint64_t> claimed;
  int round = 0;
  while (!pending.empty()) {
    std::set<uint64_t> discovered;
    g_kind = round++ == 0 ? 0 : 1;
    for (auto address : pending) {
      std::vector<uint64_t> entries;
      bool merge = LiftTargets == "entries";
      Function *lifted = nullptr;
      std::set<uint64_t> analyzed;
      for (;;) {
        lifted = lifter.Lift(address, entries);
        if (!lifted && !entries.empty()) {
          for (auto entry : entries) {
            claimed.erase(entry);
            discovered.insert(entry);
          }
          entries.clear();
          analyzed.clear();
          merge = false;
          continue;
        }
        if (!lifted) {
          break;
        }
        bool grew = false;
        std::vector<uint64_t> variants;
        for (auto entry : entries) {
          if (analyzed.insert(entry).second) {
            variants.push_back(entry);
          }
        }
        analyzed.insert(address);
        auto found_targets = tables.Targets(*lifted, tables.Owner(address), address, entries.empty() ? nullptr : &variants);
        for (auto target : found_targets) {
          if (program.functions.count(target) || lifter.functions.count(target) || claimed.count(target)) {
            continue;
          }
          if (merge) {
            claimed[target] = address;
            entries.push_back(target);
            ++table_targets;
            grew = true;
          } else if (discovered.insert(target).second) {
            ++table_targets;
          }
        }
        for (auto target : pads.Targets(*lifted)) {
          if (!program.functions.count(target) && !lifter.functions.count(target) && !claimed.count(target) && discovered.insert(target).second) {
            ++pad_targets;
          }
        }
        if (!grew) {
          break;
        }
        lifter.Discard(address, entries);
      }
      if (!lifted) {
        if (tables.IsData(address)) {
          ++table_data;
          continue;
        }
        errs() << "xlate: cannot decode function at 0x" << Hex(address) << "\n";
        ++failures;
        continue;
      }
      if (!entries.empty()) {
        merged[address] = entries;
      }
    }
    for (auto target : discovered) {
      program.functions.insert(target);
    }
    pending = discovered;
  }
  if (ReportDuplicates) {
    std::map<uint64_t, unsigned> cover;
    uint64_t total = 0;
    for (auto &[a, s] : g_lift_sets) {
      total += s.size();
      for (auto i : s) {
        ++cover[i];
      }
    }
    errs() << "xlate: duplicates:" << g_lift_sets.size() << " lifts, " << total << " instructions lifted, " << cover.size() << " unique\n";
    uint64_t histogram[6] = {};
    for (auto &[i, n] : cover) {
      ++histogram[n == 1 ? 0 : n == 2 ? 1 : n <= 4 ? 2 : n <= 8 ? 3 : n <= 16 ? 4 : 5];
    }
    errs() << "xlate: duplicates:addresses covered by 1, 2, 3-4, 5-8, 9-16, 17+ functions:";
    for (auto h : histogram) {
      errs() << " " << h;
    }
    errs() << "\n";
    struct Acc {
      uint64_t functions = 0, lifted = 0, redundant = 0;
    };
    std::map<std::string, Acc> by_image;
    std::map<int, Acc> by_kind;
    std::vector<std::tuple<uint64_t, uint64_t, uint64_t, std::string>> worst;
    for (auto &[a, s] : g_lift_sets) {
      double redundant = 0;
      for (auto i : s) {
        redundant += 1.0 - 1.0 / cover[i];
      }
      std::string name = "?";
      if (auto image = program.ImageAt(a)) {
        name = image->path();
        name = name.substr(name.rfind('/') + 1);
      }
      for (auto *acc : {&by_image[name], &by_kind[g_lift_kind[a]]}) {
        ++acc->functions;
        acc->lifted += s.size();
        acc->redundant += static_cast<uint64_t>(redundant);
      }
      worst.push_back({static_cast<uint64_t>(redundant), a, s.size(), name});
    }
    for (auto &[kind, acc] : by_kind) {
      errs() << "xlate: duplicates:kind " << (kind ? "discovered" : "function start") << ": " << acc.functions << " lifts, " << acc.lifted << " instructions, " << acc.redundant << " redundant\n";
    }
    for (auto &[name, acc] : by_image) {
      errs() << "xlate: duplicates:image " << name << ": " << acc.functions << " lifts, " << acc.lifted << " instructions, " << acc.redundant << " redundant\n";
    }
    std::sort(worst.rbegin(), worst.rend());
    for (size_t i = 0; i < worst.size() && i < 15; ++i) {
      auto &[redundant, a, size, name] = worst[i];
      errs() << "xlate: duplicates:worst 0x" << Hex(a) << " " << name << " " << size << " instructions, " << redundant << " redundant\n";
    }
  }
  unsigned split = DevirtExits ? lifter.SplitExits() : 0;
  auto jumps = EnterEntries(lifter, module, merged);
  std::set<Function *> distinct;
  for (auto &[address, function] : lifter.functions) {
    distinct.insert(function);
  }
  auto calls = lifter.Calls();
  auto devirtualized = lifter.Devirtualize();
  errs() << "xlate: lifted " << distinct.size() << " functions, " << devirtualized << " direct calls, " << table_targets << " jump table targets, "
         << failures << " failures, " << table_data << " jump table data words that the linker listed as function starts\n";
  errs() << "xlate: " << claimed.size() << " jump table targets are entries of " << merged.size() << " functions, which " << jumps
         << " indirect jumps enter again\n";
  if (DevirtExits) {
    errs() << "xlate: " << split << " jumps out of functions to the address of a function got an exit block of their own\n";
  }
  auto invokes = pads.Lower(calls);
  errs() << "xlate: " << invokes << " call sites in " << pads.functions() << " functions unwind to " << pad_targets << " landing pads\n";
  std::vector<GuestSegment> segments;
  auto overrides = ObjCOverrides(module, objc);
  if (!(Library ? EmitGuestImage(program, module, overrides) : EmitGuestData(program, module, segments, overrides))) {
    return 1;
  }
  EmitTables(program, lifter, module);
  if (verifyModule(module, &errs())) {
    errs() << "xlate: invalid module before optimization\n";
    return 1;
  }
  if (Optimize) {
    RunPipeline(module);
  }
  std::error_code ec;
  raw_fd_ostream bc(Output, ec, sys::fs::OF_None);
  if (ec) {
    errs() << "xlate: " << Output << ": " << ec.message() << "\n";
    return 1;
  }
  WriteBitcodeToFile(module, bc);
  if (!IROutput.empty()) {
    raw_fd_ostream ir(IROutput, ec, sys::fs::OF_Text);
    module.print(ir, nullptr);
  }
  return WriteLayout(segments) && WriteStateHeader(program) ? 0 : 1;
}
