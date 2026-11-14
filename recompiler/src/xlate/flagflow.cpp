#include "flagflow.h"

#include <cstdio>

#include <stdint.h>
#include <farmdec.h>

using namespace farmdec;

namespace xlate {
namespace {

constexpr unsigned kLookahead = 64;
constexpr uint64_t kNzcvSysregs[] = {0xda10, 0x5a10};

bool IsNzcv(uint64_t sysreg) {
  for (auto value : kNzcvSysregs) {
    if (sysreg == value) {
      return true;
    }
  }
  return false;
}

bool WritesWithSuffix(Op op) {
  switch (op) {
    case A64_ADD_IMM: case A64_SUB_IMM: case A64_AND_IMM:
    case A64_ADD_SHIFTED: case A64_SUB_SHIFTED: case A64_NEG: case A64_AND_SHIFTED: case A64_BIC:
    case A64_ADD_EXT: case A64_SUB_EXT:
      return true;
    default:
      return false;
  }
}

FlagUse Classify(const Inst &inst) {
  switch (inst.op) {
    case A64_BCOND:
      return fad_get_cond(inst.flags) == COND_AL ? FlagUse::Jump : FlagUse::Reads;
    case A64_ADC: case A64_SBC: case A64_NGC:
    case A64_CCMN_REG: case A64_CCMP_REG: case A64_CCMN_IMM: case A64_CCMP_IMM:
    case A64_CSEL: case A64_CSINC: case A64_CINC: case A64_CSET: case A64_CSINV: case A64_CINV: case A64_CSETM: case A64_CSNEG: case A64_CNEG:
    case A64_FCCMP: case A64_FCCMPE: case A64_FCSEL:
    case A64_RMIF: case A64_SETF8: case A64_SETF16: case A64_CFINV: case A64_XAFlag: case A64_AXFlag:
      return FlagUse::Reads;
    case A64_MRS:
      return IsNzcv(inst.imm) ? FlagUse::Reads : FlagUse::None;
    case A64_MSR_REG:
      return IsNzcv(inst.imm) ? FlagUse::Writes : FlagUse::None;
    case A64_CMN_IMM: case A64_CMP_IMM: case A64_TST_IMM:
    case A64_CMN_SHIFTED: case A64_CMP_SHIFTED: case A64_TST_SHIFTED:
    case A64_CMN_EXT: case A64_CMP_EXT:
    case A64_FCMP_REG: case A64_FCMP_ZERO: case A64_FCMPE_REG: case A64_FCMPE_ZERO:
      return FlagUse::Writes;
    case A64_B:
      return FlagUse::Jump;
    case A64_CBZ: case A64_CBNZ: case A64_TBZ: case A64_TBNZ:
      return FlagUse::CondJump;
    case A64_BL: case A64_BLR:
      return FlagUse::Call;
    case A64_BR: case A64_RET:
      return FlagUse::Return;
    case A64_BRK: case A64_UDF: case A64_HLT:
      return FlagUse::Stop;
    default:
      return WritesWithSuffix(inst.op) && (inst.flags & SET_FLAGS) ? FlagUse::Writes : FlagUse::None;
  }
}

int64_t BranchOffset(const Inst &inst) {
  return inst.op == A64_TBZ || inst.op == A64_TBNZ ? inst.tbz.offset : inst.offset;
}

std::string Describe(const Inst &inst) {
  switch (inst.op) {
    case A64_BCOND: return "b.cond";
    case A64_ADC: case A64_SBC: case A64_NGC: return "adc/sbc";
    case A64_CCMN_REG: case A64_CCMP_REG: case A64_CCMN_IMM: case A64_CCMP_IMM: return "ccmp/ccmn";
    case A64_CSEL: return "csel";
    case A64_CSINC: case A64_CINC: case A64_CSET: return "csinc/cset";
    case A64_CSINV: case A64_CINV: case A64_CSETM: return "csinv/csetm";
    case A64_CSNEG: case A64_CNEG: return "csneg";
    case A64_FCCMP: case A64_FCCMPE: return "fccmp";
    case A64_FCSEL: return "fcsel";
    case A64_MRS: return "mrs";
    default: return "flags";
  }
}

bool Decode(uint32_t word, Inst &inst) {
  return fad_decode(&word, 1, &inst) == 1 && inst.op != A64_UNKNOWN && inst.op != A64_ERROR;
}

}

bool FlagFlow::LiveFrom(uint64_t pc, std::string &reader, bool &resolved) const {
  std::set<uint64_t> visited;
  std::vector<uint64_t> work{pc};
  resolved = true;
  while (!work.empty()) {
    uint64_t at = work.back();
    work.pop_back();
    for (;;) {
      if (!visited.insert(at).second) {
        break;
      }
      if (visited.size() > kLookahead) {
        resolved = false;
        return false;
      }
      uint32_t word;
      Inst inst;
      if (!read_(at, word) || !Decode(word, inst)) {
        break;
      }
      auto use = Classify(inst);
      if (use == FlagUse::Reads) {
        reader = Describe(inst);
        return true;
      }
      if (use == FlagUse::Writes || use == FlagUse::Call || use == FlagUse::Return || use == FlagUse::Stop) {
        break;
      }
      if (use == FlagUse::Jump) {
        at += BranchOffset(inst);
        continue;
      }
      if (use == FlagUse::CondJump) {
        work.push_back(at + BranchOffset(inst));
      }
      at += 4;
    }
  }
  return false;
}

bool FlagFlow::CanReturn(uint64_t entry) const {
  if (auto known = returns_.find(entry); known != returns_.end()) {
    return known->second;
  }
  constexpr size_t kLimit = 16384;
  std::set<uint64_t> visited;
  std::vector<uint64_t> work{entry};
  bool returns = false;
  while (!work.empty() && !returns) {
    uint64_t at = work.back();
    work.pop_back();
    for (;;) {
      if (!visited.insert(at).second) {
        break;
      }
      if (visited.size() > kLimit || (at != entry && is_start_(at))) {
        returns = visited.size() > kLimit;
        break;
      }
      uint32_t word;
      Inst inst;
      if (!read_(at, word) || !Decode(word, inst)) {
        returns = true;
        break;
      }
      auto use = Classify(inst);
      if (use == FlagUse::Return) {
        returns = true;
        break;
      }
      if (use == FlagUse::Stop) {
        break;
      }
      if (use == FlagUse::Jump) {
        uint64_t target = at + BranchOffset(inst);
        if (target != entry && is_start_(target)) {
          returns = true;
          break;
        }
        at = target;
        continue;
      }
      if (use == FlagUse::CondJump || (use == FlagUse::Reads && inst.op == A64_BCOND)) {
        work.push_back(at + BranchOffset(inst));
      }
      at += 4;
    }
  }
  returns_[entry] = returns;
  return returns;
}

void FlagFlow::ScanRange(uint64_t begin, uint64_t end, FlagFlowResult &result) const {
  for (uint64_t at = begin; at + 4 <= end; at += 4) {
    uint32_t word;
    Inst inst;
    if (!read_(at, word) || !Decode(word, inst) || (inst.op != A64_BL && inst.op != A64_BLR)) {
      continue;
    }
    std::string reader;
    bool resolved = true;
    bool live = LiveFrom(at + 4, reader, resolved);
    if (inst.op == A64_BLR) {
      ++result.indirect_calls;
      if (live) {
        result.indirect.push_back({at, reader});
      }
      continue;
    }
    ++result.direct_calls;
    uint64_t target = at + inst.offset;
    if (live && !CanReturn(target)) {
      ++result.no_return;
      live = false;
    }
    if (live) {
      result.live_after[target].push_back({at, reader});
    } else if (!resolved) {
      ++result.unresolved[target];
    }
    std::string entry_reader;
    bool entry_resolved = true;
    if (LiveFrom(target, entry_reader, entry_resolved)) {
      result.live_in[target].push_back({at, entry_reader});
    }
  }
}

}
