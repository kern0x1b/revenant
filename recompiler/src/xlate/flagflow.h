#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace xlate {

enum class FlagUse { None, Reads, Writes, Jump, CondJump, Call, Return, Stop };

struct FlagSite {
  uint64_t site = 0;
  std::string reader;
};

struct FlagFlowResult {
  std::map<uint64_t, std::vector<FlagSite>> live_after;
  std::vector<FlagSite> indirect;
  std::map<uint64_t, std::vector<FlagSite>> live_in;
  std::map<uint64_t, uint64_t> unresolved;
  uint64_t direct_calls = 0;
  uint64_t indirect_calls = 0;
  uint64_t no_return = 0;
};

class FlagFlow {
 public:
  using Reader = std::function<bool(uint64_t address, uint32_t &word)>;
  using Starts = std::function<bool(uint64_t address)>;

  FlagFlow(Reader read, Starts is_start) : read_(std::move(read)), is_start_(std::move(is_start)) {}

  bool LiveFrom(uint64_t pc, std::string &reader, bool &resolved) const;
  bool CanReturn(uint64_t entry) const;
  void ScanRange(uint64_t begin, uint64_t end, FlagFlowResult &result) const;

 private:
  Reader read_;
  Starts is_start_;
  mutable std::map<uint64_t, bool> returns_;
};

}
