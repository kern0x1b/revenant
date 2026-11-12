#include "unwind.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <set>

namespace xlate {

namespace {

constexpr uint32_t kHasLsda = 0x40000000u;
constexpr uint32_t kPersonalityMask = 0x30000000u;
constexpr uint32_t kModeMask = 0x0F000000u;
constexpr uint32_t kModeDwarf = 0x03000000u;
constexpr uint32_t kDwarfOffsetMask = 0x00FFFFFFu;
constexpr uint8_t kOmit = 0xFF;
constexpr uint8_t kIndirect = 0x80;
constexpr uint8_t kPcRelative = 0x10;
constexpr uint8_t kApplicationMask = 0x70;
constexpr uint8_t kFormatMask = 0x0F;
constexpr size_t kMaxActionChain = 4096;
constexpr uint64_t kMaxTypeIndex = 1u << 16;

class Reader {
 public:
  explicit Reader(const Image &image) : image_(image) {}

  bool ok() const { return ok_; }

  uint64_t Unsigned(uint64_t address, unsigned bytes) {
    uint8_t buffer[8] = {};
    if (!image_.ReadBytes(address, buffer, bytes)) {
      ok_ = false;
      return 0;
    }
    uint64_t value = 0;
    memcpy(&value, buffer, bytes);
    return value;
  }

  uint8_t U8(uint64_t address) { return static_cast<uint8_t>(Unsigned(address, 1)); }
  uint16_t U16(uint64_t address) { return static_cast<uint16_t>(Unsigned(address, 2)); }
  uint32_t U32(uint64_t address) { return static_cast<uint32_t>(Unsigned(address, 4)); }
  uint64_t U64(uint64_t address) { return Unsigned(address, 8); }

  uint64_t Uleb(uint64_t &cursor) {
    uint64_t value = 0;
    for (unsigned shift = 0; shift < 64; shift += 7) {
      uint8_t byte = U8(cursor++);
      value |= static_cast<uint64_t>(byte & 0x7F) << shift;
      if (!(byte & 0x80)) {
        break;
      }
    }
    return value;
  }

  int64_t Sleb(uint64_t &cursor) {
    int64_t value = 0;
    unsigned shift = 0;
    uint8_t byte = 0;
    do {
      byte = U8(cursor++);
      value |= static_cast<int64_t>(byte & 0x7F) << shift;
      shift += 7;
    } while ((byte & 0x80) && shift < 64);
    if (shift < 64 && (byte & 0x40)) {
      value |= -(static_cast<int64_t>(1) << shift);
    }
    return value;
  }

  unsigned Width(uint8_t encoding) const {
    switch (encoding & kFormatMask) {
      case 0x02:
      case 0x0A:
        return 2;
      case 0x03:
      case 0x0B:
        return 4;
      default:
        return 8;
    }
  }

  uint64_t Encoded(uint8_t encoding, uint64_t &cursor) {
    uint64_t field = cursor;
    uint64_t value = 0;
    switch (encoding & kFormatMask) {
      case 0x01:
        value = Uleb(cursor);
        break;
      case 0x09:
        value = static_cast<uint64_t>(Sleb(cursor));
        break;
      case 0x00:
      case 0x04:
      case 0x0C:
        value = U64(cursor);
        cursor += 8;
        break;
      case 0x02:
        value = U16(cursor);
        cursor += 2;
        break;
      case 0x0A:
        value = static_cast<uint64_t>(static_cast<int64_t>(static_cast<int16_t>(U16(cursor))));
        cursor += 2;
        break;
      case 0x03:
        value = U32(cursor);
        cursor += 4;
        break;
      case 0x0B:
        value = static_cast<uint64_t>(static_cast<int64_t>(static_cast<int32_t>(U32(cursor))));
        cursor += 4;
        break;
      default:
        ok_ = false;
        return 0;
    }
    if ((encoding & kApplicationMask) == kPcRelative) {
      if (value) {
        value += field;
      }
    } else if (encoding & kApplicationMask) {
      ok_ = false;
    }
    return value;
  }

 private:
  const Image &image_;
  bool ok_ = true;
};

struct Slot {
  enum Kind { Null, Bind, Rebase } kind = Null;
  uint64_t target = 0;
  std::string symbol;
};

Slot ReadSlot(const Image &image, Reader &reader, uint64_t address) {
  Slot slot;
  uint64_t vmaddr = address - image.slide();
  if (auto bind = image.binds().find(vmaddr); bind != image.binds().end()) {
    slot.kind = Slot::Bind;
    slot.symbol = bind->second.symbol;
    return slot;
  }
  if (auto rebase = image.rebases().find(vmaddr); rebase != image.rebases().end()) {
    slot.kind = Slot::Rebase;
    slot.target = image.host(rebase->second & 0x00FFFFFFFFFFFFFFull);
    return slot;
  }
  if (uint64_t raw = reader.U64(address)) {
    slot.kind = Slot::Rebase;
    slot.target = raw;
  }
  return slot;
}

std::string ReadString(const Image &image, uint64_t address) {
  std::string text;
  for (uint8_t c = 0; address && image.ReadBytes(address, &c, 1) && c; ++address) {
    text.push_back(static_cast<char>(c));
  }
  return text;
}

ExceptionType DecodeType(const Image &image, Reader &reader, uint8_t encoding, uint64_t entry) {
  ExceptionType type;
  uint64_t cursor = entry;
  uint64_t value = reader.Encoded(encoding & ~kIndirect, cursor);
  if (!value) {
    return type;
  }
  Slot target;
  if (encoding & kIndirect) {
    target = ReadSlot(image, reader, value);
  } else {
    target.kind = Slot::Rebase;
    target.target = value;
  }
  if (target.kind == Slot::Null) {
    return type;
  }
  if (target.kind == Slot::Bind) {
    type.kind = ExceptionType::Import;
    type.symbol = target.symbol;
    return type;
  }
  auto vtable = ReadSlot(image, reader, target.target);
  if (vtable.kind != Slot::Bind || vtable.symbol != "_objc_ehtype_vtable") {
    type.kind = ExceptionType::LocalOther;
    return type;
  }
  type.kind = ExceptionType::LocalObjC;
  auto name = ReadSlot(image, reader, target.target + 8);
  type.name = name.kind == Slot::Rebase ? name.target : 0;
  auto cls = ReadSlot(image, reader, target.target + 16);
  if (cls.kind == Slot::Bind) {
    type.cls_symbol = cls.symbol;
  } else if (cls.kind == Slot::Rebase) {
    type.cls = cls.target;
  }
  return type;
}

bool ParseLsda(const Image &image, Reader &reader, FunctionUnwind &function, std::string &error) {
  uint64_t cursor = function.lsda;
  uint64_t pad_base = function.start;
  uint8_t pad_encoding = reader.U8(cursor++);
  if (pad_encoding != kOmit) {
    pad_base = reader.Encoded(pad_encoding, cursor);
  }
  uint8_t type_encoding = reader.U8(cursor++);
  uint64_t type_base = 0;
  if (type_encoding != kOmit) {
    uint64_t offset = reader.Uleb(cursor);
    type_base = cursor + offset;
  }
  uint8_t site_encoding = reader.U8(cursor++);
  uint64_t table_size = reader.Uleb(cursor);
  uint64_t table_end = cursor + table_size;
  uint64_t actions = table_end;
  if (!reader.ok()) {
    error = "the LSDA header is unreadable";
    return false;
  }
  unsigned type_width = reader.Width(type_encoding);
  std::map<uint64_t, ExceptionType> types;
  while (cursor < table_end) {
    CallSite site;
    site.start = pad_base + reader.Encoded(site_encoding, cursor);
    site.end = site.start + reader.Encoded(site_encoding, cursor);
    uint64_t pad = reader.Encoded(site_encoding, cursor);
    site.action = reader.Uleb(cursor);
    site.pad = pad ? pad_base + pad : 0;
    if (!reader.ok()) {
      error = "a call site record is unreadable";
      return false;
    }
    if (!site.action) {
      site.filters.push_back(0);
    } else {
      uint64_t record = actions + site.action - 1;
      std::set<uint64_t> chain;
      for (;;) {
        if (chain.size() >= kMaxActionChain || !chain.insert(record).second) {
          error = "an action chain does not end";
          return false;
        }
        uint64_t position = record;
        int64_t filter = reader.Sleb(position);
        uint64_t next_field = position;
        int64_t next = reader.Sleb(position);
        if (!reader.ok()) {
          error = "an action record is unreadable";
          return false;
        }
        site.filters.push_back(filter);
        if (filter > 0 && type_encoding != kOmit) {
          uint64_t index = static_cast<uint64_t>(filter);
          if (index > kMaxTypeIndex || index * type_width > type_base) {
            error = "an action names a type outside the type table";
            return false;
          }
          if (!types.count(index)) {
            types[index] = DecodeType(image, reader, type_encoding, type_base - index * type_width);
          }
        }
        if (!next) {
          break;
        }
        record = next_field + next;
      }
    }
    function.sites.push_back(std::move(site));
  }
  if (!reader.ok()) {
    error = "a type table entry is unreadable";
    return false;
  }
  if (!types.empty()) {
    function.types.resize(types.rbegin()->first);
    for (auto &[index, type] : types) {
      function.types[index - 1] = std::move(type);
    }
  }
  return reader.ok();
}

struct Frame {
  uint64_t start = 0;
  uint64_t personality_slot = 0;
  uint64_t lsda = 0;
};

std::map<uint64_t, Frame> ParseEhFrame(const Image &image, Reader &reader, const Section &section,
                                       std::vector<std::string> &errors) {
  std::map<uint64_t, Frame> frames;
  uint64_t begin = image.host(section.addr);
  uint64_t end = begin + section.size;
  for (uint64_t entry = begin; entry + 4 <= end;) {
    uint32_t length = reader.U32(entry);
    if (!length || length == 0xFFFFFFFFu) {
      break;
    }
    uint64_t body = entry + 4;
    uint32_t id = reader.U32(body);
    if (id) {
      uint64_t cie = body - id;
      uint64_t cursor = cie + 4 + 4;
      uint8_t version = reader.U8(cursor++);
      std::string augmentation;
      for (uint8_t c; (c = reader.U8(cursor++));) {
        augmentation.push_back(static_cast<char>(c));
      }
      reader.Uleb(cursor);
      reader.Sleb(cursor);
      if (version == 1) {
        cursor++;
      } else {
        reader.Uleb(cursor);
      }
      uint8_t pointer_encoding = 0, lsda_encoding = kOmit;
      uint64_t personality_slot = 0;
      if (augmentation.rfind("z", 0) == 0) {
        reader.Uleb(cursor);
        for (size_t i = 1; i < augmentation.size(); ++i) {
          switch (augmentation[i]) {
            case 'L':
              lsda_encoding = reader.U8(cursor++);
              break;
            case 'R':
              pointer_encoding = reader.U8(cursor++);
              break;
            case 'P': {
              uint8_t encoding = reader.U8(cursor++);
              personality_slot = reader.Encoded(encoding & ~kIndirect, cursor);
              break;
            }
            case 'S':
              break;
            default:
              errors.push_back("an eh_frame CIE carries the augmentation '" + std::string(1, augmentation[i]) + "'");
              break;
          }
        }
      }
      uint64_t fde = body + 4;
      uint64_t start = reader.Encoded(pointer_encoding, fde);
      reader.Encoded(pointer_encoding & kFormatMask, fde);
      Frame frame;
      frame.start = start;
      frame.personality_slot = personality_slot;
      if (augmentation.rfind("z", 0) == 0) {
        uint64_t size = reader.Uleb(fde);
        uint64_t data = fde;
        if (lsda_encoding != kOmit && size) {
          frame.lsda = reader.Encoded(lsda_encoding, data);
        }
      }
      frames[start] = frame;
    }
    entry += 4 + length;
  }
  return frames;
}

}

void UnwindTable::Add(const Image &image, std::vector<std::string> &errors) {
  const Section *info = nullptr, *eh_frame = nullptr;
  for (auto &section : image.sections()) {
    if (section.sectname == "__unwind_info" && section.segname == "__TEXT") {
      info = &section;
    } else if (section.sectname == "__eh_frame" && section.segname == "__TEXT") {
      eh_frame = &section;
    }
  }
  if (!info) {
    return;
  }
  Reader reader(image);
  uint64_t base = image.host(image.preferred_base());
  uint64_t table = image.host(info->addr);
  if (reader.U32(table) != 1) {
    errors.push_back("__unwind_info has an unknown version");
    return;
  }
  uint32_t common_offset = reader.U32(table + 4), common_count = reader.U32(table + 8);
  uint32_t personality_offset = reader.U32(table + 12), personality_count = reader.U32(table + 16);
  uint32_t index_offset = reader.U32(table + 20), index_count = reader.U32(table + 24);
  std::map<uint32_t, uint32_t> lsdas;
  struct Entry {
    uint32_t offset;
    uint32_t encoding;
  };
  std::vector<Entry> entries;
  if (index_offset + 12ull * index_count > info->size) {
    errors.push_back("__unwind_info has an index past the end of its section");
    return;
  }
  for (uint32_t i = 0; i + 1 < index_count; ++i) {
    uint64_t index = table + index_offset + 12ull * i;
    uint32_t first = reader.U32(index);
    uint32_t page = reader.U32(index + 4);
    uint64_t lsda_begin = reader.U32(index + 8);
    uint64_t lsda_end = reader.U32(index + 12 + 8);
    if (lsda_begin > lsda_end || lsda_end > info->size) {
      errors.push_back("__unwind_info has an LSDA index outside its section");
      return;
    }
    for (uint64_t at = lsda_begin; at + 8 <= lsda_end; at += 8) {
      lsdas[reader.U32(table + at)] = reader.U32(table + at + 4);
    }
    if (!page) {
      continue;
    }
    uint32_t kind = reader.U32(table + page);
    uint16_t entries_offset = reader.U16(table + page + 4), count = reader.U16(table + page + 6);
    if (kind == 2) {
      for (uint16_t e = 0; e < count; ++e) {
        uint64_t at = table + page + entries_offset + 8ull * e;
        entries.push_back({reader.U32(at), reader.U32(at + 4)});
      }
    } else if (kind == 3) {
      uint16_t encodings_offset = reader.U16(table + page + 8), encodings_count = reader.U16(table + page + 10);
      for (uint16_t e = 0; e < count; ++e) {
        uint32_t packed = reader.U32(table + page + entries_offset + 4ull * e);
        uint32_t encoding_index = packed >> 24;
        uint32_t encoding = encoding_index < common_count
                                ? reader.U32(table + common_offset + 4ull * encoding_index)
                                : (encoding_index - common_count < encodings_count
                                       ? reader.U32(table + page + encodings_offset + 4ull * (encoding_index - common_count))
                                       : 0);
        entries.push_back({first + (packed & 0x00FFFFFFu), encoding});
      }
    } else {
      errors.push_back("__unwind_info has a second level page of kind " + std::to_string(kind));
    }
  }
  uint32_t last = index_count ? reader.U32(table + index_offset + 12ull * (index_count - 1)) : 0;
  if (!reader.ok()) {
    errors.push_back("__unwind_info is unreadable");
    return;
  }
  std::map<uint64_t, Frame> frames;
  bool frames_read = false;
  for (size_t i = 0; i < entries.size(); ++i) {
    uint32_t encoding = entries[i].encoding;
    bool dwarf = (encoding & kModeMask) == kModeDwarf;
    if (!dwarf && !(encoding & kHasLsda)) {
      continue;
    }
    FunctionUnwind function;
    function.start = base + entries[i].offset;
    function.end = base + (i + 1 < entries.size() ? entries[i + 1].offset : last);
    uint64_t personality_slot = 0;
    if (dwarf) {
      if (!eh_frame) {
        errors.push_back("a function uses DWARF unwind information and the image has no __eh_frame");
        continue;
      }
      if (!frames_read) {
        Reader frame_reader(image);
        frames = ParseEhFrame(image, frame_reader, *eh_frame, errors);
        if (!frame_reader.ok()) {
          errors.push_back("__eh_frame is unreadable");
        }
        frames_read = true;
      }
      auto frame = frames.find(function.start);
      if (frame == frames.end() || !frame->second.lsda) {
        continue;
      }
      function.lsda = frame->second.lsda;
      personality_slot = frame->second.personality_slot;
    } else {
      auto lsda = lsdas.find(entries[i].offset);
      if (lsda == lsdas.end()) {
        errors.push_back("a function has an LSDA flag and no LSDA entry");
        continue;
      }
      function.lsda = base + lsda->second;
      uint32_t personality = (encoding & kPersonalityMask) >> 28;
      if (personality && personality <= personality_count) {
        personality_slot = base + reader.U32(table + personality_offset + 4ull * (personality - 1));
      }
    }
    if (personality_slot) {
      Slot slot = ReadSlot(image, reader, personality_slot);
      function.personality = slot.kind == Slot::Bind ? slot.symbol : std::string();
    }
    std::string error;
    Reader lsda_reader(image);
    if (!ParseLsda(image, lsda_reader, function, error)) {
      char where[32];
      snprintf(where, sizeof where, "0x%llx", static_cast<unsigned long long>(function.start));
      errors.push_back(std::string("the LSDA of the function at ") + where + ": " + error);
      continue;
    }
    functions_[function.start] = std::move(function);
  }
}

const FunctionUnwind *UnwindTable::FunctionAt(uint64_t address) const {
  auto it = functions_.upper_bound(address);
  if (it == functions_.begin()) {
    return nullptr;
  }
  --it;
  return address < it->second.end ? &it->second : nullptr;
}

std::optional<Landing> UnwindTable::Find(uint64_t call) const {
  auto function = FunctionAt(call);
  if (!function) {
    return std::nullopt;
  }
  for (auto &site : function->sites) {
    if (call >= site.start && call < site.end) {
      return Landing{function, &site};
    }
  }
  return std::nullopt;
}

}
