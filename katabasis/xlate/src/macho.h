#pragma once

#include <llvm/Object/MachO.h>

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <vector>

namespace xlate {

struct Segment {
  std::string name;
  uint64_t vmaddr = 0;
  uint64_t vmsize = 0;
  uint64_t fileoff = 0;
  uint64_t filesize = 0;
  uint32_t initprot = 0;
};

struct Section {
  std::string segname;
  std::string sectname;
  uint64_t addr = 0;
  uint64_t size = 0;
  uint32_t offset = 0;
  uint32_t flags = 0;
  uint32_t reserved1 = 0;
  uint32_t reserved2 = 0;
};

struct Bind {
  std::string symbol;
  int64_t addend = 0;
  bool weak_import = false;
  std::string library;  // install name of the dylib the bind names; empty for a flat-namespace or unknown one
};

// A call stub, with what the image's own symbol table says of the symbol it is bound to: the library by ordinal,
// and whether this image imports it weakly. Two images can differ on both for one name.
struct Stub {
  std::string symbol;
  std::string library;  // empty for a flat-namespace one
  bool weak = false;
};

// The export trie sends a name to another library's, which is how libc++ hands out libc++abi's operators.
struct Reexport {
  std::string library;
  std::string symbol;
};

// A byte range LC_DATA_IN_CODE marks as not-instructions inside an executable section (almost
// always a compiler jump table): a scanner that decodes raw bytes as arm64 instructions outside
// the lifter's own control-flow-aware decode (e.g. tsd_scan.cpp) must skip these or risk
// misdecoding table data as code.
struct DataInCodeRange {
  uint64_t vmaddr = 0;
  uint64_t length = 0;
};

class Image {
 public:
  static std::unique_ptr<Image> Load(const std::string &path, std::string &error);

  const std::string &path() const { return path_; }
  const std::string &install_name() const { return install_name_; }
  const std::vector<Segment> &segments() const { return segments_; }
  const std::vector<Section> &sections() const { return sections_; }

  uint64_t preferred_base() const;
  uint64_t image_end() const;
  void set_slide(uint64_t slide) { slide_ = slide; }
  uint64_t slide() const { return slide_; }
  uint64_t host(uint64_t vmaddr) const { return vmaddr + slide_; }

  bool ReadBytes(uint64_t host_addr, uint8_t *out, size_t size) const;
  bool IsExecutable(uint64_t host_addr) const;
  const Section *SectionAt(uint64_t host_addr) const;

  const std::set<uint64_t> &functions() const { return functions_; }
  std::optional<uint64_t> entry() const { return entry_; }
  const std::map<uint64_t, Stub> &stubs() const { return stubs_; }
  const std::map<uint64_t, Bind> &binds() const { return binds_; }
  const std::map<uint64_t, uint64_t> &rebases() const { return rebases_; }
  const std::map<std::string, uint64_t> &exports() const { return exports_; }
  const std::map<std::string, Reexport> &reexports() const { return reexports_; }
  // The libraries this one re-exports whole (LC_REEXPORT_DYLIB): what they export, a bind that names this one gets.
  const std::vector<std::string> &reexported_libraries() const { return reexported_libraries_; }
  const std::vector<std::string> &warnings() const { return warnings_; }
  const std::vector<DataInCodeRange> &data_in_code() const { return data_in_code_; }

 private:
  bool Parse(std::string &error);
  bool ParseFunctionStarts(const llvm::object::MachOObjectFile::LoadCommandInfo &lc);
  bool ParseDataInCode(const llvm::object::MachOObjectFile::LoadCommandInfo &lc);
  bool ParseStubs(std::string &error);
  bool ParseFixups(std::string &error);
  bool ParseExports(std::string &error);
  const Segment *SegmentForVM(uint64_t vmaddr) const;

  std::string path_;
  std::string install_name_;
  std::vector<std::string> reexported_libraries_;
  std::vector<std::string> dylibs_;  // install names, by load-command order: a bind ordinal N is dylibs_[N - 1]
  std::string LibraryOf(int ordinal) const;
  llvm::object::OwningBinary<llvm::object::Binary> owning_;
  llvm::object::MachOObjectFile *object_ = nullptr;
  std::vector<Segment> segments_;
  std::vector<Section> sections_;
  uint64_t slide_ = 0;
  std::set<uint64_t> functions_;
  std::optional<uint64_t> entry_;
  std::map<uint64_t, Stub> stubs_;
  std::map<uint64_t, Bind> binds_;
  std::map<uint64_t, uint64_t> rebases_;
  std::map<std::string, uint64_t> exports_;
  std::map<std::string, Reexport> reexports_;
  std::vector<std::string> warnings_;
  std::vector<uint64_t> raw_function_starts_;
  std::vector<DataInCodeRange> data_in_code_;
};

}  // namespace xlate
