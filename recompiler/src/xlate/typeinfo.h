#pragma once

#include "exports.h"
#include "macho.h"

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace xlate {

struct TypeRef {
  uint64_t address = 0;
  std::string symbol;
  bool valid() const { return address != 0 || !symbol.empty(); }
};

struct TypeBase {
  TypeRef type;
  int64_t offset = 0;
  uint32_t flags = 0;
};

struct GuestTypeInfo {
  enum Kind { Class, SingleInheritance, MultipleInheritance, Fundamental, Pointer, PointerToMember, Array, Function, Enum };
  Kind kind = Class;
  uint64_t address = 0;
  uint64_t name = 0;
  std::string text;
  uint32_t flags = 0;
  TypeRef target;
  TypeRef context;
  std::vector<TypeBase> bases;
};

using ImageAtFunction = std::function<const Image *(uint64_t)>;

class TypeInfoTable {
 public:
  void Scan(const std::vector<std::unique_ptr<Image>> &images, const GuestExports &exports, const ImageAtFunction &image_at,
            std::vector<std::string> &problems);
  const GuestTypeInfo *Find(uint64_t address) const;
  const std::map<uint64_t, GuestTypeInfo> &all() const { return types_; }
  static const char *VtableSymbol(GuestTypeInfo::Kind kind);
  static const char *HostFundamental(const std::string &name);

 private:
  bool Decode(const Image &image, const GuestExports &exports, const ImageAtFunction &image_at, GuestTypeInfo::Kind kind, uint64_t address,
              std::string &problem);

  std::map<uint64_t, GuestTypeInfo> types_;
};

}
