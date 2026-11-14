#include "typeinfo.h"

#include <cstring>
#include <set>

namespace xlate {

namespace {

struct VtableName {
  GuestTypeInfo::Kind kind;
  const char *symbol;
};

constexpr VtableName kVtables[] = {
    {GuestTypeInfo::Class, "__ZTVN10__cxxabiv117__class_type_infoE"},
    {GuestTypeInfo::SingleInheritance, "__ZTVN10__cxxabiv120__si_class_type_infoE"},
    {GuestTypeInfo::MultipleInheritance, "__ZTVN10__cxxabiv121__vmi_class_type_infoE"},
    {GuestTypeInfo::Fundamental, "__ZTVN10__cxxabiv123__fundamental_type_infoE"},
    {GuestTypeInfo::Pointer, "__ZTVN10__cxxabiv119__pointer_type_infoE"},
    {GuestTypeInfo::PointerToMember, "__ZTVN10__cxxabiv129__pointer_to_member_type_infoE"},
    {GuestTypeInfo::Array, "__ZTVN10__cxxabiv117__array_type_infoE"},
    {GuestTypeInfo::Function, "__ZTVN10__cxxabiv120__function_type_infoE"},
    {GuestTypeInfo::Enum, "__ZTVN10__cxxabiv116__enum_type_infoE"},
};

constexpr uint64_t kVptrOffset = 16;
constexpr uint64_t kAddressMask = 0x00FFFFFFFFFFFFFFull;
constexpr unsigned kMaxBases = 4096;

const struct {
  const char *name;
  const char *symbol;
} kHostFundamentals[] = {
    {"i", "__ZTIi"}, {"j", "__ZTIj"}, {"x", "__ZTIx"}, {"y", "__ZTIy"}, {"s", "__ZTIs"}, {"t", "__ZTIt"},
    {"c", "__ZTIc"}, {"a", "__ZTIa"}, {"h", "__ZTIh"}, {"b", "__ZTIb"}, {"f", "__ZTIf"}, {"d", "__ZTId"},
    {"e", "__ZTIe"}, {"w", "__ZTIw"}, {"Di", "__ZTIDi"}, {"Ds", "__ZTIDs"},
};

bool ReadWord(const Image &image, uint64_t address, uint8_t *out, size_t size) {
  return image.ReadBytes(address, out, size);
}

bool ReadU32(const Image &image, uint64_t address, uint32_t &value) {
  uint8_t bytes[4];
  if (!ReadWord(image, address, bytes, 4)) {
    return false;
  }
  memcpy(&value, bytes, 4);
  return true;
}

bool ReadI64(const Image &image, uint64_t address, int64_t &value) {
  uint8_t bytes[8];
  if (!ReadWord(image, address, bytes, 8)) {
    return false;
  }
  memcpy(&value, bytes, 8);
  return true;
}

bool ReadCString(const Image &image, uint64_t address, std::string &text) {
  text.clear();
  for (uint8_t c = 0;; ++address) {
    if (text.size() > 4096 || !image.ReadBytes(address, &c, 1)) {
      return false;
    }
    if (!c) {
      return true;
    }
    text.push_back(static_cast<char>(c));
  }
}

bool ReadTarget(const Image &image, const GuestExports &exports, uint64_t address, TypeRef &ref) {
  uint64_t vmaddr = address - image.slide();
  if (auto bind = image.binds().find(vmaddr); bind != image.binds().end()) {
    if (auto found = exports.Find(bind->second.library, bind->second.symbol)) {
      ref.address = *found + bind->second.addend;
    } else {
      ref.symbol = bind->second.symbol;
    }
    return true;
  }
  if (auto rebase = image.rebases().find(vmaddr); rebase != image.rebases().end()) {
    ref.address = image.host(rebase->second & kAddressMask);
    return true;
  }
  return false;
}

}

const char *TypeInfoTable::VtableSymbol(GuestTypeInfo::Kind kind) {
  for (auto &entry : kVtables) {
    if (entry.kind == kind) {
      return entry.symbol;
    }
  }
  return nullptr;
}

const char *TypeInfoTable::HostFundamental(const std::string &name) {
  for (auto &entry : kHostFundamentals) {
    if (name == entry.name) {
      return entry.symbol;
    }
  }
  return nullptr;
}

const GuestTypeInfo *TypeInfoTable::Find(uint64_t address) const {
  auto found = types_.find(address);
  return found == types_.end() ? nullptr : &found->second;
}

bool TypeInfoTable::Decode(const Image &image, const GuestExports &exports, const ImageAtFunction &image_at, GuestTypeInfo::Kind kind,
                           uint64_t address, std::string &problem) {
  GuestTypeInfo info;
  info.kind = kind;
  info.address = address;
  uint64_t vmaddr = address - image.slide();
  auto name = image.rebases().find(vmaddr + 8);
  if (name == image.rebases().end()) {
    problem = "the type_info at 0x" + std::to_string(address) + " has no name pointer";
    return false;
  }
  info.name = image.host(name->second & kAddressMask);
  auto owner = image_at(info.name);
  if (!owner || !ReadCString(*owner, info.name, info.text)) {
    problem = "the type_info at 0x" + std::to_string(address) + " has an unreadable name";
    return false;
  }
  switch (kind) {
    case GuestTypeInfo::SingleInheritance:
      if (!ReadTarget(image, exports, address + 16, info.target) || !info.target.valid()) {
        problem = "the base of the type_info " + info.text + " is unreadable";
        return false;
      }
      break;
    case GuestTypeInfo::MultipleInheritance: {
      uint32_t count = 0;
      if (!ReadU32(image, address + 16, info.flags) || !ReadU32(image, address + 20, count) || count > kMaxBases) {
        problem = "the bases of the type_info " + info.text + " are unreadable";
        return false;
      }
      for (uint32_t i = 0; i < count; ++i) {
        TypeBase base;
        uint64_t entry = address + 24 + 16ull * i;
        int64_t packed = 0;
        if (!ReadTarget(image, exports, entry, base.type) || !base.type.valid() || !ReadI64(image, entry + 8, packed)) {
          problem = "a base of the type_info " + info.text + " is unreadable";
          return false;
        }
        base.flags = static_cast<uint32_t>(packed & 0xFF);
        base.offset = packed >> 8;
        info.bases.push_back(base);
      }
      break;
    }
    case GuestTypeInfo::Pointer:
    case GuestTypeInfo::PointerToMember:
      if (!ReadU32(image, address + 16, info.flags) || !ReadTarget(image, exports, address + 24, info.target) || !info.target.valid()) {
        problem = "the pointee of the type_info " + info.text + " is unreadable";
        return false;
      }
      if (kind == GuestTypeInfo::PointerToMember && (!ReadTarget(image, exports, address + 32, info.context) || !info.context.valid())) {
        problem = "the class of the type_info " + info.text + " is unreadable";
        return false;
      }
      break;
    default:
      break;
  }
  types_[address] = std::move(info);
  return true;
}

void TypeInfoTable::Scan(const std::vector<std::unique_ptr<Image>> &images, const GuestExports &exports, const ImageAtFunction &image_at,
                         std::vector<std::string> &problems) {
  std::map<uint64_t, GuestTypeInfo::Kind> pointers;
  std::map<std::string, GuestTypeInfo::Kind> symbols;
  for (auto &entry : kVtables) {
    symbols[entry.symbol] = entry.kind;
    for (auto &image : images) {
      if (auto found = image->exports().find(entry.symbol); found != image->exports().end()) {
        pointers[image->host(found->second) + kVptrOffset] = entry.kind;
      }
    }
  }
  for (auto &image : images) {
    std::vector<std::pair<uint64_t, GuestTypeInfo::Kind>> objects;
    for (auto &[vmaddr, bind] : image->binds()) {
      if (auto kind = symbols.find(bind.symbol); kind != symbols.end() && bind.addend == static_cast<int64_t>(kVptrOffset)) {
        objects.push_back({image->host(vmaddr), kind->second});
      }
    }
    for (auto &[vmaddr, target] : image->rebases()) {
      if (auto kind = pointers.find(image->host(target & kAddressMask)); kind != pointers.end()) {
        objects.push_back({image->host(vmaddr), kind->second});
      }
    }
    for (auto &[address, kind] : objects) {
      std::string problem;
      if (!Decode(*image, exports, image_at, kind, address, problem)) {
        problems.push_back(image->path() + ": " + problem);
      }
    }
  }
}

}
