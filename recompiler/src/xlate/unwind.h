#pragma once

#include "macho.h"

#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace xlate {

struct ExceptionType {
  enum Kind { CatchAll, Import, LocalObjC, LocalOther } kind = CatchAll;
  std::string symbol;
  uint64_t name = 0;
  uint64_t cls = 0;
  std::string cls_symbol;
};

struct CallSite {
  uint64_t start = 0;
  uint64_t end = 0;
  uint64_t pad = 0;
  uint64_t action = 0;
  std::vector<int64_t> filters;
};

struct FunctionUnwind {
  uint64_t start = 0;
  uint64_t end = 0;
  std::string personality;
  uint64_t lsda = 0;
  std::vector<CallSite> sites;
  std::vector<ExceptionType> types;
};

struct Landing {
  const FunctionUnwind *function = nullptr;
  const CallSite *site = nullptr;
};

class UnwindTable {
 public:
  void Add(const Image &image, std::vector<std::string> &errors);
  std::optional<Landing> Find(uint64_t call) const;
  const FunctionUnwind *FunctionAt(uint64_t address) const;
  size_t size() const { return functions_.size(); }

 private:
  std::map<uint64_t, FunctionUnwind> functions_;
};

}
