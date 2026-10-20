#include "tsd_scan.h"

#include <farmdec.h>

#include <llvm/BinaryFormat/MachO.h>

#include <algorithm>
#include <array>
#include <cstring>
#include <map>
#include <sstream>
#include <unordered_map>
#include <unordered_set>

namespace xlate {

namespace {

std::string Hex(uint64_t value) {
  std::ostringstream os;
  os << "0x" << std::hex << value;
  return os.str();
}

bool IsAllowedOffset(uint64_t offset) {
  return std::any_of(std::begin(kAllowedTSDOffsets), std::end(kAllowedTSDOffsets),
                      [&](auto &entry) { return entry.offset == offset; });
}

const char *WhyAllowed(uint64_t offset) {
  for (auto &entry : kAllowedTSDOffsets) {
    if (entry.offset == offset) return entry.why;
  }
  return "";
}

bool IsVectorDestOp(farmdec::Op op) {
  switch (op) {
    case farmdec::A64_LD1_MULT: case farmdec::A64_ST1_MULT:
    case farmdec::A64_LD2_MULT: case farmdec::A64_ST2_MULT:
    case farmdec::A64_LD3_MULT: case farmdec::A64_ST3_MULT:
    case farmdec::A64_LD4_MULT: case farmdec::A64_ST4_MULT:
    case farmdec::A64_LD1_SINGLE: case farmdec::A64_ST1_SINGLE:
    case farmdec::A64_LD2_SINGLE: case farmdec::A64_ST2_SINGLE:
    case farmdec::A64_LD3_SINGLE: case farmdec::A64_ST3_SINGLE:
    case farmdec::A64_LD4_SINGLE: case farmdec::A64_ST4_SINGLE:
    case farmdec::A64_LD1R: case farmdec::A64_LD2R:
    case farmdec::A64_LD3R: case farmdec::A64_LD4R:
    case farmdec::A64_LDNP_FP: case farmdec::A64_STNP_FP:
    case farmdec::A64_LDP_FP: case farmdec::A64_STP_FP:
    case farmdec::A64_LDR_FP: case farmdec::A64_STR_FP:
      return true;
    default:
      return false;
  }
}

bool IsStoreLikeOp(farmdec::Op op) {
  switch (op) {
    case farmdec::A64_ST1_MULT: case farmdec::A64_ST2_MULT:
    case farmdec::A64_ST3_MULT: case farmdec::A64_ST4_MULT:
    case farmdec::A64_ST1_SINGLE: case farmdec::A64_ST2_SINGLE:
    case farmdec::A64_ST3_SINGLE: case farmdec::A64_ST4_SINGLE:
    case farmdec::A64_STNP: case farmdec::A64_STP:
    case farmdec::A64_STR: case farmdec::A64_STXR: case farmdec::A64_STXP:
      return true;
    default:
      return false;
  }
}

bool IsTestBranchOp(farmdec::Op op) {
  switch (op) {
    case farmdec::A64_CBZ: case farmdec::A64_CBNZ:
    case farmdec::A64_TBZ: case farmdec::A64_TBNZ:
      return true;
    default:
      return false;
  }
}

bool ClobbersGPR(const farmdec::Inst &inst, farmdec::Reg r) {
  if (IsVectorDestOp(inst.op) || IsStoreLikeOp(inst.op) || IsTestBranchOp(inst.op)) {
    return false;
  }
  switch (inst.op) {
    case farmdec::A64_LDP: case farmdec::A64_LDNP: case farmdec::A64_LDXP:
      return inst.rt == r || inst.rt2 == r;
    default:
      return inst.rd == r;
  }
}

bool UsesReg(const farmdec::Inst &inst, farmdec::Reg r) {
  return inst.rn == r || inst.rm == r;
}

bool IsBranchOp(farmdec::Op op) {
  return op == farmdec::A64_BCOND || op == farmdec::A64_B || op == farmdec::A64_BL ||
         op == farmdec::A64_BR || op == farmdec::A64_BLR || IsTestBranchOp(op);
}

bool IsIndirectBranchOp(farmdec::Op op) { return op == farmdec::A64_BR || op == farmdec::A64_BLR; }

bool IsCallOp(farmdec::Op op) { return op == farmdec::A64_BL || op == farmdec::A64_BLR; }

bool IsUnconditionalOp(const farmdec::Inst &inst) {
  switch (inst.op) {
    case farmdec::A64_B: case farmdec::A64_BR: case farmdec::A64_BLR:
      return true;
    case farmdec::A64_BCOND:
      return fad_get_cond(inst.flags) == farmdec::COND_AL;
    default:
      return false;
  }
}

bool IsNoReturnOp(farmdec::Op op) {
  switch (op) {
    case farmdec::A64_RET: case farmdec::A64_SVC: case farmdec::A64_BRK:
    case farmdec::A64_HVC: case farmdec::A64_SMC:
    case farmdec::A64_DCPS1: case farmdec::A64_DCPS2: case farmdec::A64_DCPS3:
      return true;
    default:
      return false;
  }
}

bool BranchTarget(const farmdec::Inst &inst, uint64_t addr, uint64_t *target) {
  if (IsIndirectBranchOp(inst.op)) return false;
  if (inst.op != farmdec::A64_B && inst.op != farmdec::A64_BL && inst.op != farmdec::A64_BCOND &&
      !IsTestBranchOp(inst.op)) {
    return false;
  }
  *target = addr + static_cast<uint64_t>(inst.offset);
  return true;
}

struct FunctionRange {
  uint64_t start = 0;
  uint64_t end = 0;
};

std::string FunctionName(const Image &image, uint64_t vmaddr) {
  for (auto &[name, addr] : image.exports()) {
    if (addr == vmaddr) {
      return name;
    }
  }
  return "sub_" + Hex(vmaddr).substr(2);
}

bool InDataInCode(const std::vector<DataInCodeRange> &ranges, uint64_t vmaddr) {
  return std::any_of(ranges.begin(), ranges.end(), [&](auto &range) {
    return vmaddr >= range.vmaddr && vmaddr < range.vmaddr + range.length;
  });
}

struct Code {
  std::vector<uint64_t> section_addrs;
  std::vector<uint64_t> section_sizes;
  std::vector<std::vector<farmdec::Inst>> insts;

  const farmdec::Inst *At(uint64_t addr) const {
    for (size_t i = 0; i < section_addrs.size(); i++) {
      if (addr >= section_addrs[i] && addr + 4 <= section_addrs[i] + section_sizes[i]) {
        return &insts[i][(addr - section_addrs[i]) / 4];
      }
    }
    return nullptr;
  }
};

using Tracked = std::array<bool, 32>;
using MrsAt = std::array<uint64_t, 32>;

struct State {
  Tracked tracked{};
  MrsAt mrs_at{};
};

void MergeInto(State &into, const State &from, bool may) {
  for (size_t r = 0; r < into.tracked.size(); r++) {
    into.tracked[r] = may ? (into.tracked[r] || from.tracked[r])
                          : (into.tracked[r] && from.tracked[r]);
    if (!may || into.mrs_at[r] == 0) into.mrs_at[r] = from.mrs_at[r];
  }
}

bool Differs(const State &a, const State &b) {
  for (size_t r = 0; r < a.tracked.size(); r++) {
    if (a.tracked[r] != b.tracked[r]) return true;
  }
  return false;
}

constexpr farmdec::Reg kFirstCalleeSaved = 19;
constexpr farmdec::Reg kLastCalleeSaved = 28;

struct CallSite {
  uint64_t addr = 0;
  uint64_t target = 0;
  bool resolvable = false;
  Tracked tracked{};
  MrsAt mrs_at{};
};

struct Block {
  uint64_t start = 0;
  uint64_t end = 0;
  std::vector<size_t> succs;
  std::vector<size_t> preds;
};

struct FunctionResult {
  std::vector<Block> blocks;
  std::vector<CallSite> calls;
  std::vector<std::string> violations;
};

class FunctionAnalysis {
 public:
  FunctionAnalysis(const Image &image, const Code &code, const FunctionRange &range,
                   const std::unordered_set<uint64_t> &function_starts)
      : image_(image), code_(code), range_(range), function_starts_(function_starts) {}

  FunctionResult Run(const State &seed) {
    result_.blocks = BuildBlocks();
    if (result_.blocks.empty()) return result_;
    std::vector<State> may_in = Solve(seed, true);
    std::vector<State> must_in = Solve(seed, false);
    for (size_t b = 0; b < result_.blocks.size(); b++) Report(b, may_in[b], must_in[b]);
    std::sort(result_.violations.begin(), result_.violations.end());
    result_.violations.erase(std::unique(result_.violations.begin(), result_.violations.end()),
                             result_.violations.end());
    return result_;
  }

  const std::vector<Block> &blocks() const { return result_.blocks; }

 private:
  std::vector<State> Solve(const State &seed, bool may) {
    std::vector<State> in(result_.blocks.size());
    std::vector<State> out(result_.blocks.size());
    in[0] = seed;
    std::vector<size_t> work(result_.blocks.size());
    for (size_t i = 0; i < work.size(); i++) work[i] = i;
    while (!work.empty()) {
      size_t b = work.back();
      work.pop_back();
      out[b] = Transfer(b, in[b], may);
      for (size_t s : result_.blocks[b].succs) {
        State merged = in[s];
        MergeInto(merged, out[b], may);
        if (Differs(in[s], merged)) {
          in[s] = merged;
          work.push_back(s);
        }
      }
    }
    return in;
  }

  const farmdec::Inst *At(uint64_t addr) const {
    if (addr < range_.start || addr + 4 > range_.end) return nullptr;
    if (InDataInCode(image_.data_in_code(), addr)) return nullptr;
    return code_.At(addr);
  }

  std::vector<Block> BuildBlocks() const {
    std::unordered_set<uint64_t> leaders{range_.start};
    for (uint64_t addr = range_.start; addr < range_.end; addr += 4) {
      auto inst = At(addr);
      if (!inst) continue;
      if (inst->op == farmdec::A64_ERROR || inst->op == farmdec::A64_UNKNOWN) continue;
      if (!IsBranchOp(inst->op) && !IsNoReturnOp(inst->op)) continue;
      uint64_t target = 0;
      if (BranchTarget(*inst, addr, &target) && target >= range_.start && target + 4 <= range_.end &&
          target % 4 == 0) {
        leaders.insert(target);
      }
      if (addr + 4 < range_.end) leaders.insert(addr + 4);
    }
    std::vector<uint64_t> sorted(leaders.begin(), leaders.end());
    std::sort(sorted.begin(), sorted.end());
    std::vector<Block> blocks;
    for (size_t i = 0; i < sorted.size(); i++) {
      uint64_t end = (i + 1 < sorted.size()) ? sorted[i + 1] : range_.end;
      blocks.push_back({sorted[i], end, {}, {}});
    }
    std::unordered_map<uint64_t, size_t> index_of;
    for (size_t i = 0; i < blocks.size(); i++) index_of[blocks[i].start] = i;
    for (size_t i = 0; i < blocks.size(); i++) {
      auto &block = blocks[i];
      if (block.end <= block.start) continue;
      auto last_addr = block.end - 4;
      auto last = At(last_addr);
      auto add = [&](uint64_t target) {
        auto found = index_of.find(target);
        if (found != index_of.end()) {
          block.succs.push_back(found->second);
          blocks[found->second].preds.push_back(i);
        }
      };
      if (!last || last->op == farmdec::A64_ERROR || last->op == farmdec::A64_UNKNOWN) {
        add(block.end);
        continue;
      }
      uint64_t target = 0;
      bool has_target = BranchTarget(*last, last_addr, &target);
      if (IsNoReturnOp(last->op)) continue;
      if (has_target && IsUnconditionalOp(*last)) {
        add(target);
      } else if (has_target) {
        add(target);
        add(block.end);
      } else if (IsBranchOp(last->op)) {
        continue;
      } else {
        add(block.end);
      }
    }
    return blocks;
  }

  State Transfer(size_t b, State state, bool may) {
    for (uint64_t addr = result_.blocks[b].start; addr < result_.blocks[b].end; addr += 4) {
      auto inst = At(addr);
      if (!inst) continue;
      if (inst->op == farmdec::A64_ERROR || inst->op == farmdec::A64_UNKNOWN) continue;
      if (inst->op == farmdec::A64_MRS) {
        bool is_tpidrro = (inst->imm == 0xde83);
        if (inst->rt != farmdec::ZERO_REG) {
          state.tracked[inst->rt] = is_tpidrro;
          if (is_tpidrro) state.mrs_at[inst->rt] = addr;
        }
        continue;
      }
      if (IsCallOp(inst->op)) {
        CallSite site;
        site.addr = addr;
        uint64_t target = 0;
        if (BranchTarget(*inst, addr, &target) && function_starts_.count(target)) {
          site.target = target;
          site.resolvable = true;
        }
        if (!may) {
          for (farmdec::Reg r = kFirstCalleeSaved; r <= kLastCalleeSaved; r++) {
            site.tracked[r] = state.tracked[r];
            site.mrs_at[r] = state.mrs_at[r];
          }
          result_.calls.push_back(site);
        }
        for (farmdec::Reg r = 0; r <= 17; r++) state.tracked[r] = false;
        state.tracked[30] = false;
      }
      for (farmdec::Reg r = 0; r < 31; r++) {
        if (state.tracked[r] && ClobbersGPR(*inst, r)) state.tracked[r] = false;
      }
    }
    return state;
  }

  void Report(size_t b, const State &may_in, const State &must_in) {
    State state = may_in;
    State certain = must_in;
    for (uint64_t addr = result_.blocks[b].start; addr < result_.blocks[b].end; addr += 4) {
      auto inst = At(addr);
      if (!inst) continue;
      if (inst->op == farmdec::A64_ERROR || inst->op == farmdec::A64_UNKNOWN) continue;
      if (inst->op == farmdec::A64_MRS) {
        bool is_tpidrro = (inst->imm == 0xde83);
        if (inst->rt != farmdec::ZERO_REG) {
          state.tracked[inst->rt] = is_tpidrro;
          certain.tracked[inst->rt] = is_tpidrro;
          if (is_tpidrro) {
            state.mrs_at[inst->rt] = addr;
            certain.mrs_at[inst->rt] = addr;
          }
        }
        continue;
      }
      for (farmdec::Reg r = 0; r < 31; r++) {
        if (!state.tracked[r]) continue;
        bool fixed_offset_access =
            (inst->op == farmdec::A64_LDR || inst->op == farmdec::A64_STR) && inst->rn == r &&
            fad_get_addrmode(inst->flags) == farmdec::AM_OFF_IMM;
        if (fixed_offset_access) {
          auto offset = static_cast<uint64_t>(inst->offset);
          if (!IsAllowedOffset(offset)) {
            std::ostringstream line;
            line << image_.path() << ": " << FunctionName(image_, range_.start) << ": " << Hex(addr)
                 << ": load/store off TPIDRRO_EL0 (from mrs at " << Hex(state.mrs_at[r])
                 << ") at offset " << Hex(offset) << ", not on the audited allow-list";
            result_.violations.push_back(line.str());
          }
        } else if (certain.tracked[r] && UsesReg(*inst, r)) {
          std::ostringstream line;
          line << image_.path() << ": " << FunctionName(image_, range_.start) << ": " << Hex(addr)
               << ": register holding TPIDRRO_EL0 (from mrs at " << Hex(state.mrs_at[r])
               << ") used in a form this scanner does not model (opcode "
               << static_cast<int>(inst->op)
               << "); extend src/xlate/tsd_scan.cpp to classify it, or confirm this is not a TSD "
                  "access";
          result_.violations.push_back(line.str());
        }
      }
      if (IsCallOp(inst->op)) {
        for (farmdec::Reg r = 0; r <= 17; r++) {
          state.tracked[r] = false;
          certain.tracked[r] = false;
        }
        state.tracked[30] = false;
        certain.tracked[30] = false;
      }
      for (farmdec::Reg r = 0; r < 31; r++) {
        if (state.tracked[r] && ClobbersGPR(*inst, r)) state.tracked[r] = false;
        if (certain.tracked[r] && ClobbersGPR(*inst, r)) certain.tracked[r] = false;
      }
    }
  }

  const Image &image_;
  const Code &code_;
  FunctionRange range_;
  const std::unordered_set<uint64_t> &function_starts_;
  FunctionResult result_;
};

bool HasMRS(const FunctionRange &range, const Code &code, const Image &image) {
  for (uint64_t addr = range.start; addr + 4 <= range.end; addr += 4) {
    if (InDataInCode(image.data_in_code(), addr)) continue;
    auto inst = code.At(addr);
    if (!inst || inst->op != farmdec::A64_MRS) continue;
    if (inst->imm == 0xde83 && inst->rt != farmdec::ZERO_REG) return true;
  }
  return false;
}

}

bool ScanTSDOffsets(const Image &image, std::vector<std::string> &violations) {
  Code code;
  for (auto &section : image.sections()) {
    if (!(section.flags &
          (llvm::MachO::S_ATTR_PURE_INSTRUCTIONS | llvm::MachO::S_ATTR_SOME_INSTRUCTIONS))) {
      continue;
    }
    if (section.size < 4) continue;
    std::vector<uint8_t> bytes(section.size);
    if (!image.ReadBytes(image.host(section.addr), bytes.data(), bytes.size())) {
      continue;
    }
    uint32_t words = section.size / 4;
    std::vector<uint32_t> raw(words);
    memcpy(raw.data(), bytes.data(), words * 4);
    code.section_addrs.push_back(section.addr);
    code.section_sizes.push_back(section.size);
    code.insts.emplace_back(words);
    fad_decode(raw.data(), words, code.insts.back().data());
  }

  std::vector<uint64_t> starts;
  for (auto addr : image.functions()) {
    starts.push_back(addr);
  }
  std::sort(starts.begin(), starts.end());
  starts.erase(std::unique(starts.begin(), starts.end()), starts.end());
  std::unordered_set<uint64_t> function_starts(starts.begin(), starts.end());

  std::vector<FunctionRange> ranges;
  for (size_t i = 0; i < starts.size(); i++) {
    uint64_t end = (i + 1 < starts.size()) ? starts[i + 1] : 0;
    if (end == 0) continue;
    if (code.At(starts[i]) == nullptr) continue;
    ranges.push_back({starts[i], end});
  }
  for (size_t s = 0; s < code.section_addrs.size(); s++) {
    uint64_t section_end = code.section_addrs[s] + code.section_sizes[s];
    uint64_t last_start = 0;
    for (auto &range : ranges) {
      if (range.start >= code.section_addrs[s] && range.start < section_end) last_start = range.start;
    }
    if (last_start && last_start < section_end) ranges.push_back({last_start, section_end});
  }
  std::sort(ranges.begin(), ranges.end(),
            [](const FunctionRange &a, const FunctionRange &b) { return a.start < b.start; });

  std::unordered_map<uint64_t, Tracked> seeds;
  std::unordered_map<uint64_t, MrsAt> seed_mrs;
  std::unordered_set<uint64_t> pending;
  for (auto &range : ranges) {
    if (HasMRS(range, code, image)) pending.insert(range.start);
  }
  constexpr int kMaxRounds = 4096;
  int rounds = 0;
  while (!pending.empty()) {
    if (++rounds > kMaxRounds) {
      violations.push_back(image.path() +
                           ": the TSD scan's interprocedural seed propagation did not settle in " +
                           std::to_string(kMaxRounds) + " rounds; fix src/xlate/tsd_scan.cpp");
      return false;
    }
    std::unordered_set<uint64_t> next;
    for (uint64_t start : pending) {
      auto found = std::find_if(ranges.begin(), ranges.end(),
                                [&](const FunctionRange &r) { return r.start == start; });
      if (found == ranges.end()) continue;
      State seed;
      auto seeded = seeds.find(start);
      if (seeded != seeds.end()) seed.tracked = seeded->second;
      auto seeded_mrs = seed_mrs.find(start);
      if (seeded_mrs != seed_mrs.end()) seed.mrs_at = seeded_mrs->second;
      FunctionAnalysis analysis(image, code, *found, function_starts);
      auto result = analysis.Run(seed);
      violations.insert(violations.end(), result.violations.begin(), result.violations.end());
      for (auto &call : result.calls) {
        if (!call.resolvable) continue;
        auto &callee_seed = seeds[call.target];
        auto &callee_mrs = seed_mrs[call.target];
        bool grew = false;
        for (farmdec::Reg r = kFirstCalleeSaved; r <= kLastCalleeSaved; r++) {
          if (!call.tracked[r]) continue;
          if (!callee_seed[r]) {
            callee_seed[r] = true;
            grew = true;
          }
          if (callee_mrs[r] == 0) callee_mrs[r] = call.mrs_at[r];
        }
        if (grew) next.insert(call.target);
      }
    }
    pending = std::move(next);
  }

  std::sort(violations.begin(), violations.end());
  violations.erase(std::unique(violations.begin(), violations.end()), violations.end());
  return violations.empty();
}

}
