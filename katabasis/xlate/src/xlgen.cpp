#include <clang/AST/ASTContext.h>
#include <clang/AST/Attr.h>
#include <clang/AST/Decl.h>
#include <clang/AST/DeclObjC.h>
#include <clang/AST/RecordLayout.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Frontend/ASTUnit.h>
#include <clang/Tooling/Tooling.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/Format.h>
#include <llvm/Support/JSON.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/Path.h>
#include <llvm/Support/raw_ostream.h>

#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

using namespace clang;
using namespace llvm;

static cl::opt<std::string> SdkPath("sdk", cl::Required);
static cl::opt<std::string> ResourceDir("resource-dir", cl::Required);
static cl::opt<std::string> GuestTarget("guest-target", cl::init("arm64-apple-ios12.0"));
static cl::opt<std::string> HostTarget("host-target", cl::init("armv7-apple-ios6.0"));
static cl::opt<std::string> IncludesPath("includes", cl::Required);
static cl::opt<std::string> AbiHeader("abi-header", cl::Required);
static cl::opt<std::string> SymbolsPath("symbols");
static cl::opt<std::string> GuestProvidedPath("guest-provided", cl::desc("Symbols another guest image defines"));
static cl::opt<std::string> WeakOnlyPath("weak-only", cl::desc("Imported symbols no image binds strongly"));
static cl::opt<std::string> ManifestPath("objc-manifest", cl::desc("Objective-C manifest written by xlate"));
static cl::opt<std::string> EntitlementsPath("entitlements", cl::desc("The input binary's entitlements plist, answered for getsectiondata(__TEXT,__entitlements)"));
static cl::opt<std::string> GuestOut("guest-out");
static cl::opt<std::string> HostOut("host-out");
static cl::opt<std::string> PassthroughOut("passthrough-out");
static cl::opt<std::string> ReportOut("report-out");
static cl::opt<std::string> SurveyOut("survey-out", cl::desc("Classify every C function and Objective-C method of the SDK headers"));

namespace {

std::set<std::string> ReadLines(const std::string &path) {
  std::set<std::string> lines;
  if (path.empty()) {
    return lines;
  }
  auto buffer = MemoryBuffer::getFile(path);
  if (!buffer) {
    return lines;
  }
  SmallVector<StringRef, 128> parts;
  (*buffer)->getBuffer().split(parts, '\n', -1, false);
  for (auto part : parts) {
    if (!part.trim().empty()) {
      lines.insert(part.trim().str());
    }
  }
  return lines;
}

std::unique_ptr<ASTUnit> Parse(const std::string &code, const std::string &target) {
  std::vector<std::string> args = {"-target", target, "-isysroot", SdkPath, "-resource-dir", ResourceDir,
                                   "-x", "objective-c", "-fblocks", "-w", "-D_FORTIFY_SOURCE=0"};
  // The includes header is concatenated into an in-memory TU, so a sibling `#include "..."` (e.g.
  // a shared libSystem-surface header the app's includes pulls in) has no on-disk anchor. Put its
  // directory on the quote search path so such includes resolve.
  StringRef incdir = llvm::sys::path::parent_path(IncludesPath);
  if (!incdir.empty()) {
    args.push_back("-iquote");
    args.push_back(incdir.str());
  }
  return tooling::buildASTFromCodeWithArgs(code, args, "xlgen.m", "xlgen");
}

std::string Spell(ASTContext &context, QualType type, const std::string &name = "") {
  // An ObjC pointer to a class the deployment target marks unavailable (e.g. a macOS-only
  // AuthenticationServices class reached through the framework umbrella header) cannot be named
  // in the generated code -- the compiler rejects the unavailable type. Every ObjC object is
  // bridged as an opaque handle cast through uintptr_t regardless, so spell it as plain `id`.
  if (auto objptr = type.getCanonicalType()->getAs<clang::ObjCObjectPointerType>()) {
    if (auto iface = objptr->getInterfaceDecl();
        iface && iface->getAvailability() == clang::AR_Unavailable) {
      return name.empty() ? "id" : "id " + name;
    }
  }
  std::string text;
  raw_string_ostream os(text);
  auto policy = context.getPrintingPolicy();
  policy.PrintAsCanonical = true;
  type.getCanonicalType().getUnqualifiedType().print(os, policy, name);
  size_t at = 0;
  while ((at = text.find("SEL *", at)) != std::string::npos) {
    text.replace(at, 5, "SEL ");
    at += 4;
  }
  while (!text.empty() && text.back() == ' ') {
    text.pop_back();
  }
  return text;
}

// Normalise an ObjC type encoding for cross-arch comparison against the device runtime's
// method_getTypeEncoding: strip offset digits, and replace struct/union tag NAMES with '?'
// (clang emits {CGPoint=dd} but a release framework's runtime encoding is the anonymous {?=dd}).
std::string NormalizeEncoding(const std::string &in) {
  std::string out;
  for (size_t i = 0; i < in.size();) {
    char c = in[i];
    if (isdigit(static_cast<unsigned char>(c))) {
      ++i;
      continue;
    }
    out.push_back(c);
    if (c == '{' || c == '(') {
      out.push_back('?');
      size_t j = i + 1;
      while (j < in.size() && in[j] != '=' && in[j] != '}' && in[j] != ')') {
        ++j;
      }
      i = j;
      continue;
    }
    ++i;
  }
  return out;
}

std::string Sanitize(StringRef text) {
  std::string out;
  for (char c : text) {
    out.push_back(isalnum(static_cast<unsigned char>(c)) ? c : '_');
  }
  return out;
}

enum class Kind { Void, Integer, Floating, Pointer, Protocol, Record, RecordPointer, OutSlot, Array, Block, Callback, Unsupported };

struct Value {
  Kind kind = Kind::Unsupported;
  QualType guest;
  QualType host;
  bool is_signed = false;
  unsigned guest_bits = 0;
  unsigned host_bits = 0;
  std::string note;
  std::shared_ptr<Value> pointee;
  int count_index = -1;
  bool writes_back = false;
  bool is_object = false;
};

struct Leaf {
  std::string guest_path;
  std::string host_path;
  uint64_t offset = 0;
  Value value;
};

class Generator;

struct Side {
  ASTContext &guest;
  ASTContext &host;
};

bool SameLayout(ASTContext &gc, QualType g, ASTContext &hc, QualType h, std::set<const Decl *> &seen) {
  g = g.getCanonicalType();
  h = h.getCanonicalType();
  if (g->isVoidType() || g->isFunctionType()) {
    return h->isVoidType() || h->isFunctionType();
  }
  if (g->isIncompleteType() || h->isIncompleteType()) {
    return true;
  }
  if (g->isAnyPointerType() || g->isBlockPointerType() || g->isObjCObjectPointerType()) {
    return false;
  }
  if (gc.getTypeSize(g) != hc.getTypeSize(h) || gc.getTypeAlign(g) != hc.getTypeAlign(h)) {
    return false;
  }
  if (auto ga = gc.getAsConstantArrayType(g)) {
    auto ha = hc.getAsConstantArrayType(h);
    return ha && SameLayout(gc, ga->getElementType(), hc, ha->getElementType(), seen);
  }
  if (auto gr = g->getAsRecordDecl()) {
    auto hr = h->getAsRecordDecl();
    if (!hr) {
      return false;
    }
    if (!seen.insert(gr).second) {
      return true;
    }
    auto &gl = gc.getASTRecordLayout(gr);
    auto &hl = hc.getASTRecordLayout(hr);
    auto gf = gr->field_begin();
    auto hf = hr->field_begin();
    for (; gf != gr->field_end() && hf != hr->field_end(); ++gf, ++hf) {
      if (gl.getFieldOffset(gf->getFieldIndex()) != hl.getFieldOffset(hf->getFieldIndex()) ||
          !SameLayout(gc, gf->getType(), hc, hf->getType(), seen)) {
        return false;
      }
    }
    return gf == gr->field_end() && hf == hr->field_end();
  }
  return true;
}

Value Classify(ASTContext &gc, QualType g, ASTContext &hc, QualType h, bool parameter) {
  Value value;
  value.guest = g;
  value.host = h;
  auto gcanon = g.getCanonicalType();
  auto hcanon = h.getCanonicalType();
  if (gcanon->isVoidType()) {
    value.kind = Kind::Void;
    return value;
  }
  if (gcanon->isIntegralOrEnumerationType()) {
    value.kind = Kind::Integer;
    value.is_signed = gcanon->isSignedIntegerOrEnumerationType();
    value.guest_bits = gc.getTypeSize(gcanon);
    value.host_bits = hc.getTypeSize(hcanon);
    return value;
  }
  if (gcanon->isRealFloatingType()) {
    value.kind = Kind::Floating;
    value.guest_bits = gc.getTypeSize(gcanon);
    value.host_bits = hc.getTypeSize(hcanon);
    return value;
  }
  if (auto objptr = gcanon->getAs<clang::ObjCObjectPointerType>()) {
    if (auto iface = objptr->getInterfaceDecl(); iface && iface->getName() == "Protocol") {
      value.kind = Kind::Protocol;
      return value;
    }
  }
  if (gcanon->isObjCObjectPointerType() || gcanon->isObjCSelType() || gcanon->isObjCClassType() ||
      gcanon->isObjCIdType()) {
    value.kind = Kind::Pointer;
    value.is_object = gcanon->isObjCObjectPointerType() || gcanon->isObjCIdType();
    return value;
  }
  if (gcanon->isBlockPointerType()) {
    value.kind = Kind::Block;
    return value;
  }
  if (gcanon->isFunctionPointerType()) {
    value.kind = Kind::Callback;
    return value;
  }
  if (gcanon->isPointerType()) {
    std::set<const Decl *> seen;
    auto gp = gcanon->getPointeeType();
    auto hp = hcanon->getPointeeType();
    if (SameLayout(gc, gp, hc, hp, seen)) {
      value.kind = Kind::Pointer;
      return value;
    }
    if (auto record = gp->getAsRecordDecl(); record && (record->getName() == "__sFILE" || record->getName() == "__sFILEX")) {
      value.kind = Kind::Pointer;
      value.note = "opaque stdio stream";
      return value;
    }
    // Opaque handles the guest only carries as tokens (never dereferences); their
    // internal layout differs between the two ABIs but is never read across the bridge.
    // The whole pthread family is opaque this way: pthread_t, and the sync primitives
    // (mutex/cond/rwlock/once) and their attribute objects, which the guest allocates and
    // passes only by pointer. Marshalling them by value is wrong -- a mutex has identity
    // tied to its address, and the guest's uninitialised/in-use bytes fail the narrowing
    // guard on __sig -- so pass the pointer straight through. This is sound because the
    // armv7 host object is smaller than the arm64 guest allocation (so pthread's writes fit)
    // and a static PTHREAD_*_INITIALIZER leaves the __sig magic in the low word the host reads.
    // The multibyte conversion state (mbrtowc/wcrtomb/mbsrtowcs and their _l forms) is the same: a union
    // only libc itself ever reads, 128 bytes on both ABIs, so hand the guest's buffer to the host as is.
    // DIR (opendir/closedir/telldir/seekdir/fdopendir) is a host handle the guest never dereferences.
    if (auto record = gp->getAsRecordDecl();
        record && (StringRef(record->getName()).starts_with("_opaque_pthread_") || record->getName() == "__mbstate_t" ||
                   (record->getTypedefNameForAnonDecl() &&
                    (record->getTypedefNameForAnonDecl()->getName() == "__mbstate_t" ||
                     record->getTypedefNameForAnonDecl()->getName() == "DIR")))) {
      value.kind = Kind::Pointer;
      value.is_object = false;
      value.note = "opaque pthread object";
      return value;
    }
    auto pointee = Classify(gc, gp, hc, hp, false);
    if (parameter && pointee.kind == Kind::Record) {
      value.kind = Kind::RecordPointer;
      value.pointee = std::make_shared<Value>(pointee);
      value.writes_back = !gp.isConstQualified();
      return value;
    }
    if (parameter && !gp.isConstQualified() &&
        (pointee.kind == Kind::Integer || pointee.kind == Kind::Floating || pointee.kind == Kind::Pointer)) {
      value.kind = Kind::OutSlot;
      value.pointee = std::make_shared<Value>(pointee);
      return value;
    }
    value.note = "pointer to " + gp.getAsString() + ", whose layout differs";
    return value;
  }
  if (gcanon->isRecordType()) {
    auto record = gcanon->getAsRecordDecl();
    if (record->isUnion()) {
      value.note = "union " + gcanon.getAsString();
      return value;
    }
    value.kind = Kind::Record;
    return value;
  }
  value.note = "type " + g.getAsString();
  return value;
}

bool Supported(const Value &value) {
  return value.kind != Kind::Unsupported;
}

std::string Bound(unsigned bits, bool is_signed, bool max) {
  if (is_signed) {
    return max ? "(int64_t)((1ull << " + std::to_string(bits - 1) + ") - 1)"
               : "(-(int64_t)((1ull << " + std::to_string(bits - 1) + ") - 1) - 1)";
  }
  return bits == 64 ? "UINT64_MAX" : "(uint64_t)((1ull << " + std::to_string(bits) + ") - 1)";
}

struct Parameter {
  Value value;
  std::string name;
};

struct Signature {
  std::vector<Parameter> params;
  Value result;
  bool supported = true;
  std::string note;
};

enum class CallKind { Function, Message };

struct FormatInfo {
  bool present = false;
  bool object = false;
  unsigned format_index = 0;
  std::string va_variant;
  int va_param = -1;  // >=0: the va_list is this parameter (vfprintf etc.); -1: variadic (...) via va_start
};

class Generator {
 public:
  Generator(ASTContext &gc, ASTContext &hc) : gc_(gc), hc_(hc) {}

  void Report(const std::string &line) { report_ << line << "\n"; }
  void Passthrough(const std::string &symbol) { passthrough_ << symbol << "\n"; }
  void Fault(const std::string &symbol, const std::string &reason);

  bool EmitFunction(const std::string &symbol, FunctionDecl *g, FunctionDecl *h);
  void EmitVariable(const std::string &symbol, VarDecl *g, VarDecl *h);
  void EmitTrampoline(const std::string &symbol, const std::string &trap);
  void EmitManualFunction(const std::string &symbol, unsigned arguments, const std::string &handler);
  void EmitLazyClassNamer(const std::string &symbol);
  void EmitImageNameHook(const std::string &symbol);
  void EmitExec(const std::string &symbol);
  std::set<std::string> exec_emitted_;
  std::string variant_alias_;  // full name of the symbol being resolved when it has a $VARIANT suffix
  std::set<std::string> weak_only_;  // imported by weak binds only: unsupported ones stay undefined, so a guest's weak check finds them absent
  unsigned variadic_words_ = 0;  // trailing params of the bridge being emitted that are C variadic args (see EmitBridge)
  void EmitTlvBootstrap();
  void EmitEmptyCollectionSingleton(const std::string &symbol, const std::string &host_class);
  void CollectMethods(ASTContext &context, std::map<std::string, std::vector<ObjCMethodDecl *>> &pool);
  void EmitSelectors(const std::set<std::string> &selectors, const std::set<std::string> &guest_selectors);
  void EmitClasses(const json::Object &manifest);
  bool Write();
  void Survey(raw_ostream &os);

 private:
  std::string PackField(const Value &value, bool guest);
  std::string Mirror(QualType guest, QualType host);
  bool Leaves(QualType g, QualType h, const std::string &gpath, const std::string &hpath, uint64_t base,
              std::vector<Leaf> &out);
  std::string GuestStore(const Value &value, const std::string &expr);
  std::string GuestLoad(const Value &value, const std::string &expr);
  std::string HostLoad(const Value &value, const std::string &expr, const std::string &where, std::string &prep,
                       std::string &post, unsigned index);
  std::string HostStore(const Value &value, const std::string &expr, const std::string &target);
  std::string ScalarToHost(const Value &value, const std::string &expr, const std::string &where);
  std::string ScalarToGuest(const Value &value, const std::string &expr);
  std::string BlockBridge(const Value &value);
  std::string HostBlockBridge(const Value &value);
  std::string CallbackBridge(const Value &value);
  Signature FromFunction(FunctionDecl *g, FunctionDecl *h);
  Signature FromMethod(ObjCMethodDecl *g, ObjCMethodDecl *h);
  Signature FromEncoding(const std::string &encoding, std::string &error);
  QualType EncodedType(ASTContext &context, StringRef &text, bool guest, std::string &error);
  QualType SynthesizeRecord(ASTContext &context, StringRef fields, bool guest, std::string &error);
  std::string EmitBridge(const std::string &id, const Signature &signature, CallKind kind, const std::string &guest_name,
                         const std::string &callee, const FormatInfo &format, const std::string &manual);
  std::string HostEncoding(const Signature &signature);
  std::string InvokeShim(const Signature &signature);
  std::string ImpWrapper(const Signature &signature, uint64_t imp, bool class_method);
  std::string StubImpWrapper(uint64_t imp);

  ASTContext &gc_;
  ASTContext &hc_;
  std::string guest_;
  std::string host_types_;
  std::string host_;
  std::string init_;
  std::string tables_;
  std::ostringstream report_;
  std::ostringstream passthrough_;
  std::set<std::string> mirrors_;
  std::map<std::string, std::string> invokers_;
  std::map<std::string, std::string> blocks_;
  std::map<std::string, std::string> host_blocks_;
  std::map<std::string, std::string> callbacks_;
  std::map<std::string, std::vector<ObjCMethodDecl *>> guest_pool_;
  std::map<std::string, std::vector<ObjCMethodDecl *>> host_pool_;
  std::vector<std::pair<std::string, std::string>> selector_shims_;
  std::vector<std::tuple<std::string, std::string, std::string>> selector_variants_;  // selector, encoding, macro
  std::vector<std::pair<std::string, std::string>> variadic_shims_;
  std::string layouts_;
  unsigned layout_count_ = 0;
  std::vector<std::string> layout_errors_;  // ivar offsets that cannot have been read from the image
  std::vector<std::pair<std::string, uint64_t>> imp_map_;
  unsigned counter_ = 0;
  unsigned unsupported_ = 0;
  // Anonymous structs synthesised from ObjC type encodings, cached per context and keyed by
  // the encoding so the same struct maps to one RecordDecl (and one mirror).
  std::map<std::string, QualType> guest_records_;
  std::map<std::string, QualType> host_records_;
  std::string guest_record_defs_;
  std::string host_record_defs_;
  unsigned record_counter_ = 0;
};

std::string Generator::Mirror(QualType guest, QualType host) {
  auto name = "xl_g_" + Sanitize(Spell(gc_, guest));
  if (mirrors_.count(name)) {
    return name;
  }
  mirrors_.insert(name);
  std::vector<Leaf> leaves;
  Leaves(guest, host, "", "", 0, leaves);
  std::ostringstream os;
  os << "struct __attribute__((packed)) " << name << " {";
  uint64_t cursor = 0;
  unsigned pad = 0;
  for (size_t i = 0; i < leaves.size(); ++i) {
    auto &leaf = leaves[i];
    if (leaf.offset > cursor) {
      os << " uint8_t pad" << pad++ << "[" << leaf.offset - cursor << "];";
    }
    auto bits = leaf.value.kind == Kind::Floating ? leaf.value.guest_bits
                : leaf.value.kind == Kind::Integer ? leaf.value.guest_bits
                                                   : 64;
    std::string type = leaf.value.kind == Kind::Floating ? (bits == 32 ? "float" : "double")
                       : leaf.value.kind == Kind::Integer
                           ? (leaf.value.is_signed ? "int" : "uint") + std::to_string(bits) + "_t"
                           : "uint64_t";
    os << " " << type << " f" << i << ";";
    cursor = leaf.offset + bits / 8;
  }
  uint64_t size = gc_.getTypeSize(guest) / 8;
  if (size > cursor) {
    os << " uint8_t pad" << pad++ << "[" << size - cursor << "];";
  }
  os << " };\n";
  os << "static inline " << Spell(hc_, host) << " " << name << "_to_host(const struct " << name << " *g)\n{\n    "
     << Spell(hc_, host) << " h;\n";
  for (size_t i = 0; i < leaves.size(); ++i) {
    os << "    h" << leaves[i].host_path << " = " << ScalarToHost(leaves[i].value, "g->f" + std::to_string(i), "\"" + name + "\", " + std::to_string(i)) << ";\n";
  }
  os << "    return h;\n}\n";
  os << "static inline void " << name << "_to_guest(struct " << name << " *g, const " << Spell(hc_, host) << " *h)\n{\n";
  for (size_t i = 0; i < leaves.size(); ++i) {
    os << "    g->f" << i << " = " << ScalarToGuest(leaves[i].value, "h->" + leaves[i].host_path.substr(1)) << ";\n";
  }
  os << "}\n\n";
  host_types_ += os.str();
  return name;
}

bool Generator::Leaves(QualType g, QualType h, const std::string &gpath, const std::string &hpath, uint64_t base,
                       std::vector<Leaf> &out) {
  auto gcanon = g.getCanonicalType();
  auto hcanon = h.getCanonicalType();
  if (auto gr = gcanon->getAsRecordDecl()) {
    auto hr = hcanon->getAsRecordDecl();
    if (!hr) {
      return false;
    }
    auto &layout = gc_.getASTRecordLayout(gr);
    auto gf = gr->field_begin();
    auto hf = hr->field_begin();
    // Bound BOTH iterators: the guest and host structs can have different field counts (e.g.
    // arm64 struct section_64 has reserved3 but armv7 struct section does not), and advancing
    // hf only against gr's end would dereference host fields past hr->field_end(). A field-count
    // or field-type mismatch means the layouts are not the same, so bail (treated as "differs").
    for (; gf != gr->field_end() && hf != hr->field_end(); ++gf, ++hf) {
      if (gf->isBitField()) {
        return false;
      }
      if (!Leaves(gf->getType(), hf->getType(), gpath + "." + gf->getNameAsString(), hpath + "." + hf->getNameAsString(),
                  base + layout.getFieldOffset(gf->getFieldIndex()) / 8, out)) {
        return false;
      }
    }
    return gf == gr->field_end() && hf == hr->field_end();
  }
  if (auto ga = gc_.getAsConstantArrayType(gcanon)) {
    auto ha = hc_.getAsConstantArrayType(hcanon);
    uint64_t element = gc_.getTypeSize(ga->getElementType()) / 8;
    for (uint64_t i = 0; i < ga->getZExtSize(); ++i) {
      if (!Leaves(ga->getElementType(), ha->getElementType(), gpath + "[" + std::to_string(i) + "]",
                  hpath + "[" + std::to_string(i) + "]", base + i * element, out)) {
        return false;
      }
    }
    return true;
  }
  Leaf leaf;
  leaf.value = Classify(gc_, g, hc_, h, false);
  if (leaf.value.kind == Kind::Callback || leaf.value.kind == Kind::Block ||
      (leaf.value.kind == Kind::Unsupported && g.getCanonicalType()->isPointerType())) {
    leaf.value.kind = Kind::Pointer;
  }
  if (leaf.value.kind != Kind::Integer && leaf.value.kind != Kind::Floating && leaf.value.kind != Kind::Pointer) {
    return false;
  }
  leaf.guest_path = gpath;
  leaf.host_path = hpath;
  leaf.offset = base;
  out.push_back(leaf);
  return true;
}

std::string Generator::ScalarToHost(const Value &value, const std::string &expr, const std::string &where) {
  switch (value.kind) {
    case Kind::Integer:
      if (value.host_bits < value.guest_bits) {
        if (value.is_signed) {
          return "(" + Spell(hc_, value.host) + ")xl_narrow_signed((int64_t)" + expr + ", " +
                 Bound(value.host_bits, true, false) + ", " + Bound(value.host_bits, true, true) + ", " +
                 Bound(value.guest_bits, true, false) + ", " + Bound(value.guest_bits, true, true) + ", " + where + ")";
        }
        return "(" + Spell(hc_, value.host) + ")xl_narrow_unsigned((uint64_t)" + expr + ", " +
               Bound(value.host_bits, false, true) + ", " + Bound(value.guest_bits, false, true) + ", " + where + ")";
      }
      return "(" + Spell(hc_, value.host) + ")" + expr;
    case Kind::Floating:
      return "(" + Spell(hc_, value.host) + ")" + expr;
    default:
      if (value.is_object)
        return "(" + Spell(hc_, value.host) + ")xl_object_in((uint64_t)" + expr + ", " + where + ")";
      return "(" + Spell(hc_, value.host) + ")xl_narrow_pointer((uint64_t)" + expr + ", " + where + ")";
  }
}

std::string Generator::ScalarToGuest(const Value &value, const std::string &expr) {
  switch (value.kind) {
    case Kind::Integer:
      if (value.host_bits < value.guest_bits) {
        if (value.is_signed) {
          return "(uint64_t)xl_widen_signed((int64_t)" + expr + ", " + Bound(value.host_bits, true, false) + ", " +
                 Bound(value.host_bits, true, true) + ", " + Bound(value.guest_bits, true, false) + ", " +
                 Bound(value.guest_bits, true, true) + ")";
        }
        return "xl_widen_unsigned((uint64_t)" + expr + ", " + Bound(value.host_bits, false, true) + ", " +
               Bound(value.guest_bits, false, true) + ")";
      }
      return value.is_signed ? "(uint64_t)(int64_t)" + expr : "(uint64_t)" + expr;
    case Kind::Floating:
      return "(double)" + expr;
    default:
      if (value.is_object)
        return "xl_object_out((uintptr_t)" + expr + ")";
      return "xl_widen_pointer((uintptr_t)" + expr + ")";
  }
}

std::string Generator::PackField(const Value &value, bool guest) {
  switch (value.kind) {
    case Kind::Floating:
      return "double";
    case Kind::Record:
      return guest ? Spell(gc_, value.guest) : "struct " + Mirror(value.guest, value.host);
    default:
      return "uint64_t";
  }
}

std::string Generator::GuestStore(const Value &value, const std::string &expr) {
  switch (value.kind) {
    case Kind::Integer:
      return value.is_signed ? "(uint64_t)(int64_t)" + expr : "(uint64_t)" + expr;
    case Kind::Floating:
      return "(double)" + expr;
    case Kind::Record:
      return expr;
    default:
      return "(uint64_t)(uintptr_t)" + expr;
  }
}

std::string Generator::GuestLoad(const Value &value, const std::string &expr) {
  switch (value.kind) {
    case Kind::Integer:
    case Kind::Floating:
    case Kind::Record:
      return "(" + Spell(gc_, value.guest) + ")" + expr;
    default:
      return "(" + Spell(gc_, value.guest) + ")(uintptr_t)" + expr;
  }
}

std::string Generator::BlockBridge(const Value &value) {
  auto gproto = value.guest.getCanonicalType()->getAs<BlockPointerType>()->getPointeeType()->getAs<FunctionProtoType>();
  auto hproto = value.host.getCanonicalType()->getAs<BlockPointerType>()->getPointeeType()->getAs<FunctionProtoType>();
  auto key = Spell(hc_, value.host);
  if (auto found = blocks_.find(key); found != blocks_.end()) {
    return found->second;
  }
  auto id = std::to_string(blocks_.size());
  auto name = "xl_block_" + id;
  blocks_[key] = name + "_host";
  Signature signature;
  for (unsigned i = 0; gproto && i < gproto->getNumParams(); ++i) {
    signature.params.push_back({Classify(gc_, gproto->getParamType(i), hc_, hproto->getParamType(i), true), "b" + std::to_string(i)});
  }
  signature.result = gproto ? Classify(gc_, gproto->getReturnType(), hc_, hproto->getReturnType(), false) : Value{};
  std::ostringstream gs, hs;
  std::string fields = " uint64_t block;";
  for (auto &param : signature.params) {
    fields += " " + PackField(param.value, true) + " " + param.name + ";";
  }
  std::string hfields = " uint64_t block;";
  for (auto &param : signature.params) {
    hfields += " " + PackField(param.value, false) + " " + param.name + ";";
  }
  bool has_result = signature.result.kind != Kind::Void;
  gs << "struct __attribute__((packed)) " << name << "_pack {" << fields << (has_result ? " " + PackField(signature.result, true) + " r;" : "") << " };\n";
  gs << "void " << name << "_guest(struct " << name << "_pack *p)\n{\n    ";
  std::string call = "((" + Spell(gc_, value.guest) + ")(void *)(uintptr_t)p->block)(";
  for (size_t i = 0; i < signature.params.size(); ++i) {
    call += (i ? ", " : "") + GuestLoad(signature.params[i].value, "p->" + signature.params[i].name);
  }
  call += ")";
  gs << (has_result ? "p->r = " + GuestStore(signature.result, call) : call) << ";\n}\n\n";
  hs << "struct __attribute__((packed)) " << name << "_pack {" << hfields << (has_result ? " " + PackField(signature.result, false) + " r;" : "") << " };\n";
  std::string args;
  for (size_t i = 0; i < signature.params.size(); ++i) {
    args += (i ? ", " : "") + Spell(hc_, hproto->getParamType(i), signature.params[i].name);
  }
  auto ret = hproto ? Spell(hc_, hproto->getReturnType()) : "void";
  hs << "static " << Spell(hc_, value.host, name + "_host(uint64_t guest)") << "\n{\n";
  hs << "    if (!guest)\n        return 0;\n    XLGuestBlock *holder = [XLGuestBlock holderWithGuestBlock:guest];\n";
  hs << "    return [[^" << ret << "(" << (args.empty() ? "void" : args) << ") {\n";
  hs << "        struct " << name << "_pack p;\n        p.block = holder.guestBlock;\n";
  for (auto &param : signature.params) {
    if (param.value.kind == Kind::Record) {
      hs << "        " << Mirror(param.value.guest, param.value.host) << "_to_guest(&p." << param.name << ", &" << param.name << ");\n";
    } else if (param.value.kind == Kind::Block) {
      hs << "        p." << param.name << " = " << HostBlockBridge(param.value) << "(" << param.name << ");\n";
    } else {
      hs << "        p." << param.name << " = " << ScalarToGuest(param.value, param.name) << ";\n";
    }
  }
  hs << "        xl_invoke(XL_GUEST_" << name << "_guest, (uintptr_t)&p);\n";
  for (auto &param : signature.params) {
    if (param.value.kind == Kind::Block) {
      hs << "        xl_invoke(XL_GUEST__Block_release, p." << param.name << ");\n";
    }
  }
  if (has_result) {
    if (signature.result.kind == Kind::Record) {
      hs << "        return " << Mirror(signature.result.guest, signature.result.host) << "_to_host(&p.r);\n";
    } else {
      hs << "        return " << ScalarToHost(signature.result, "p.r", "\"" + name + "\", 99") << ";\n";
    }
  }
  hs << "    } copy] autorelease];\n}\n\n";
  guest_ += gs.str();
  host_ += hs.str();
  return name + "_host";
}

std::string Generator::HostBlockBridge(const Value &value) {
  auto key = Spell(hc_, value.host);
  if (auto found = host_blocks_.find(key); found != host_blocks_.end()) {
    return found->second;
  }
  auto gproto = value.guest.getCanonicalType()->getAs<BlockPointerType>()->getPointeeType()->getAs<FunctionProtoType>();
  auto hproto = value.host.getCanonicalType()->getAs<BlockPointerType>()->getPointeeType()->getAs<FunctionProtoType>();
  auto name = "xl_hblock_" + std::to_string(host_blocks_.size());
  host_blocks_[key] = name + "_wrap";
  std::vector<Parameter> params;
  for (unsigned i = 0; gproto && i < gproto->getNumParams(); ++i) {
    params.push_back({Classify(gc_, gproto->getParamType(i), hc_, hproto->getParamType(i), true), "b" + std::to_string(i)});
  }
  Value result = gproto ? Classify(gc_, gproto->getReturnType(), hc_, hproto->getReturnType(), false) : Value{};
  if (!gproto) {
    result.kind = Kind::Void;
  }
  bool has_result = result.kind != Kind::Void;
  std::string gfields = " uint64_t host;", hfields = " uint64_t host;";
  for (auto &param : params) {
    gfields += " " + PackField(param.value, true) + " " + param.name + ";";
    hfields += " " + PackField(param.value, false) + " " + param.name + ";";
  }
  if (has_result) {
    gfields += " " + PackField(result, true) + " r;";
    hfields += " " + PackField(result, false) + " r;";
  }
  std::ostringstream gs, hs;
  gs << "struct __attribute__((packed)) " << name << "_pack {" << gfields << " };\n";
  gs << "extern void xl_trap_" << name << "(struct " << name << "_pack *);\n";
  std::string args = "struct xl_host_block *self";
  for (auto &param : params) {
    args += ", " + Spell(gc_, param.value.guest, param.name);
  }
  gs << Spell(gc_, has_result ? result.guest : gc_.VoidTy, name + "_invoke(" + args + ")") << "\n{\n    struct " << name << "_pack p;\n    p.host = self->host;\n";
  for (auto &param : params) {
    gs << "    p." << param.name << " = " << GuestStore(param.value, param.name) << ";\n";
  }
  gs << "    xl_trap_" << name << "(&p);\n";
  if (has_result) {
    gs << "    return " << GuestLoad(result, "p.r") << ";\n";
  }
  gs << "}\n\n";
  gs << "const struct xl_host_block_descriptor " << name << "_descriptor = {0, sizeof(struct xl_host_block), 0, xl_host_block_dispose};\n\n";
  hs << "struct __attribute__((packed)) " << name << "_pack {" << hfields << " };\n";
  hs << "void xl_h_" << name << "(State *state)\n{\n    struct " << name << "_pack *p = xl_argument(state);\n";
  std::string prep, post, call_args;
  for (size_t i = 0; i < params.size(); ++i) {
    call_args += (i ? ", " : "") + HostLoad(params[i].value, "p->" + params[i].name, "\"" + name + "\", " + std::to_string(i), prep, post, i);
  }
  std::string call = "((" + Spell(hc_, value.host) + ")(id)(uintptr_t)p->host)(" + call_args + ")";
  hs << prep;
  if (has_result) {
    hs << HostStore(result, call, "p->r");
  } else {
    hs << "    " << call << ";\n";
  }
  hs << post << "    xl_return(state);\n}\n\n";
  hs << "static uint64_t " << name << "_wrap(id block)\n{\n    return xl_host_block_wrap(block, XL_GUEST_" << name
     << "_invoke, XL_GUEST_" << name << "_descriptor);\n}\n\n";
  guest_ += gs.str();
  host_ += hs.str();
  return name + "_wrap";
}

std::string Generator::CallbackBridge(const Value &value) {
  auto gproto = value.guest.getCanonicalType()->getPointeeType()->getAs<FunctionProtoType>();
  auto hproto = value.host.getCanonicalType()->getPointeeType()->getAs<FunctionProtoType>();
  auto key = Spell(hc_, value.host);
  if (auto found = callbacks_.find(key); found != callbacks_.end()) {
    return found->second;
  }
  auto id = std::to_string(callbacks_.size());
  auto name = "xl_callback_" + id;
  callbacks_[key] = name + "_host";
  std::vector<Parameter> params;
  for (unsigned i = 0; i < gproto->getNumParams(); ++i) {
    params.push_back({Classify(gc_, gproto->getParamType(i), hc_, hproto->getParamType(i), true), "c" + std::to_string(i)});
  }
  auto result = Classify(gc_, gproto->getReturnType(), hc_, hproto->getReturnType(), false);
  bool has_result = result.kind != Kind::Void;
  std::string gfields = " uint64_t function;", hfields = " uint64_t function;";
  for (auto &param : params) {
    gfields += " " + PackField(param.value, true) + " " + param.name + ";";
    hfields += " " + PackField(param.value, false) + " " + param.name + ";";
  }
  std::ostringstream gs, hs;
  gs << "struct __attribute__((packed)) " << name << "_pack {" << gfields << (has_result ? " " + PackField(result, true) + " r;" : "") << " };\n";
  gs << "void " << name << "_guest(struct " << name << "_pack *p)\n{\n    ";
  std::string call = "((" + Spell(gc_, value.guest) + ")(uintptr_t)p->function)(";
  for (size_t i = 0; i < params.size(); ++i) {
    call += (i ? ", " : "") + GuestLoad(params[i].value, "p->" + params[i].name);
  }
  call += ")";
  gs << (has_result ? "p->r = " + GuestStore(result, call) : call) << ";\n}\n\n";
  hs << "struct __attribute__((packed)) " << name << "_pack {" << hfields << (has_result ? " " + PackField(result, false) + " r;" : "") << " };\n";
  std::string args, names;
  for (size_t i = 0; i < params.size(); ++i) {
    args += (i ? ", " : "") + Spell(hc_, hproto->getParamType(i), params[i].name);
    names += (i ? ", " : "") + params[i].name;
  }
  hs << "static " << Spell(hc_, hproto->getReturnType(), name + "_enter(unsigned slot" + (args.empty() ? "" : ", " + args) + ")") << "\n{\n";
  hs << "    struct " << name << "_pack p;\n    p.function = xl_callback_targets[" << id << "][slot];\n";
  for (auto &param : params) {
    hs << "    p." << param.name << " = " << ScalarToGuest(param.value, param.name) << ";\n";
  }
  hs << "    xl_invoke(XL_GUEST_" << name << "_guest, (uintptr_t)&p);\n";
  if (has_result) {
    hs << "    return " << ScalarToHost(result, "p.r", "\"" + name + "\", 99") << ";\n";
  }
  hs << "}\n\n";
  for (unsigned slot = 0; slot < 32; ++slot) {
    hs << "static " << Spell(hc_, hproto->getReturnType(), name + "_" + std::to_string(slot) + "(" + (args.empty() ? "void" : args) + ")")
       << "\n{\n    " << (has_result ? "return " : "") << name << "_enter(" << slot << (names.empty() ? "" : ", " + names) << ");\n}\n\n";
  }
  hs << "static " << Spell(hc_, value.host, name + "_host(uint64_t target)") << "\n{\n    static " << Spell(hc_, value.host, "const slots[32]") << " = {";
  for (unsigned slot = 0; slot < 32; ++slot) {
    hs << (slot ? ", " : "") << name << "_" << slot;
  }
  // A function-pointer argument can also be a sentinel rather than a function: SQLITE_TRANSIENT is
  // (destructor)-1, SIG_ERR/MAP_FAILED-style values likewise. Wrapping it in a host trampoline would change
  // the value the callee compares against (SQLite would then call the "destructor" with a bad address), so a
  // sentinel keeps its identity, sign-extended down to the host width.
  hs << "};\n    if (target >= 0xFFFFFFFFFFFFFF00ull)\n        return (" << Spell(hc_, value.host) << ")(uintptr_t)(uint32_t)target;\n"
     << "    return target ? slots[xl_callback_slot(" << id << ", target)] : 0;\n}\n\n";
  guest_ += gs.str();
  host_ += hs.str();
  return name + "_host";
}

std::string Generator::HostLoad(const Value &value, const std::string &expr, const std::string &where,
                                std::string &prep, std::string &post, unsigned index) {
  switch (value.kind) {
    case Kind::Protocol:
      return "(Protocol *)xl_protocol(" + expr + ")";
    case Kind::Record:
      return Mirror(value.guest, value.host) + "_to_host(&" + expr + ")";
    case Kind::Block:
      return BlockBridge(value) + "(" + expr + ")";
    case Kind::Callback:
      return CallbackBridge(value) + "(" + expr + ")";
    case Kind::OutSlot: {
      auto temp = "slot" + std::to_string(index);
      auto &pointee = *value.pointee;
      std::string guest_type = pointee.kind == Kind::Floating ? (pointee.guest_bits == 32 ? "float" : "double")
                               : pointee.kind == Kind::Integer
                                   ? (pointee.is_signed ? "int" : "uint") + std::to_string(pointee.guest_bits) + "_t"
                                   : "uint64_t";
      prep += "    " + Spell(hc_, pointee.host, temp) + ";\n";
      prep += "    " + guest_type + " *" + temp + "_guest = (" + guest_type + " *)(uintptr_t)" + expr + ";\n";
      prep += "    if (" + temp + "_guest)\n        " + temp + " = " + ScalarToHost(pointee, "*" + temp + "_guest", where) + ";\n";
      post += "    if (" + temp + "_guest)\n        *" + temp + "_guest = (" + guest_type + ")" + ScalarToGuest(pointee, temp) + ";\n";
      return temp + "_guest ? &" + temp + " : 0";
    }
    case Kind::RecordPointer: {
      auto temp = "record" + std::to_string(index);
      auto &pointee = *value.pointee;
      auto mirror = Mirror(pointee.guest, pointee.host);
      prep += "    " + Spell(hc_, pointee.host, temp) + ";\n";
      prep += "    struct " + mirror + " *" + temp + "_guest = (struct " + mirror + " *)(uintptr_t)" + expr + ";\n";
      if (value.writes_back) {
        // A non-const struct pointer is an out (or in/out) parameter. POSIX out-structs
        // (stat, statfs, rusage, ...) are pure-out and the guest buffer is uninitialised, so
        // converting it in would narrow garbage and abort the narrowing guard. Zero the host
        // struct and rely on the copy-back after the call to deliver the result.
        prep += "    __builtin_memset(&" + temp + ", 0, sizeof " + temp + ");\n";
        post += "    if (" + temp + "_guest)\n        " + mirror + "_to_guest(" + temp + "_guest, &" + temp + ");\n";
      } else {
        prep += "    if (" + temp + "_guest)\n        " + temp + " = " + mirror + "_to_host(" + temp + "_guest);\n";
      }
      return temp + "_guest ? &" + temp + " : 0";
    }
    case Kind::Array: {
      auto temp = "array" + std::to_string(index);
      auto &element = *value.pointee;
      std::string guest_type = element.kind == Kind::Floating ? (element.guest_bits == 32 ? "float" : "double")
                               : element.kind == Kind::Integer
                                   ? (element.is_signed ? "int" : "uint") + std::to_string(element.guest_bits) + "_t"
                                   : "uint64_t";
      auto count = "p->a" + std::to_string(value.count_index);
      prep += "    " + guest_type + " *" + temp + "_guest = (" + guest_type + " *)(uintptr_t)" + expr + ";\n";
      prep += "    " + Spell(hc_, hc_.getPointerType(element.host.getUnqualifiedType()), temp) + " = " + temp + "_guest ? malloc(sizeof(*" + temp +
              ") * ((size_t)" + count + " + 1)) : 0;\n";
      prep += "    for (uint64_t i = 0; " + temp + "_guest && i < " + count + "; i++)\n        " + temp + "[i] = " +
              ScalarToHost(element, temp + "_guest[i]", where) + ";\n";
      prep += "    if (" + temp + ")\n        " + temp + "[" + count + "] = 0;\n";
      if (value.writes_back) {
        post += "    for (uint64_t i = 0; " + temp + "_guest && i < " + count + "; i++)\n        " + temp + "_guest[i] = (" +
                guest_type + ")" + ScalarToGuest(element, temp + "[i]") + ";\n";
      }
      post += "    free(" + temp + ");\n";
      return "(void *)" + temp;
    }
    default:
      return ScalarToHost(value, expr, where);
  }
}

std::string Generator::HostStore(const Value &value, const std::string &expr, const std::string &target) {
  if (value.kind == Kind::Record) {
    return "    { " + Spell(hc_, value.host) + " result = " + expr + "; " + Mirror(value.guest, value.host) +
           "_to_guest(&" + target + ", &result); }\n";
  }
  return "    " + target + " = " + ScalarToGuest(value, expr) + ";\n";
}

template <typename Decl>
void DetectArrays(ASTContext &gc, ASTContext &hc, Decl *g, Decl *h, Signature &signature) {
  auto count_like = [](StringRef name) {
    auto lower = name.lower();
    return lower == "count" || lower == "cnt" || lower == "len" || lower == "length" || lower == "n" || lower == "argc" ||
           StringRef(lower).starts_with("num");
  };
  for (unsigned i = 0; i < signature.params.size(); ++i) {
    auto gtype = g->getParamDecl(i)->getType().getCanonicalType();
    if (!gtype->isPointerType() && !gtype->isArrayType()) {
      continue;
    }
    auto gp = gtype->isArrayType() ? gc.getAsArrayType(gtype)->getElementType() : gtype->getPointeeType();
    auto htype = h->getParamDecl(i)->getType().getCanonicalType();
    auto hp = htype->isArrayType() ? hc.getAsArrayType(htype)->getElementType() : htype->getPointeeType();
    auto element = Classify(gc, gp, hc, hp, false);
    std::set<const clang::Decl *> seen;
    if (SameLayout(gc, gp, hc, hp, seen) ||
        (element.kind != Kind::Integer && element.kind != Kind::Floating && element.kind != Kind::Pointer)) {
      continue;
    }
    std::vector<int> order;
    for (int distance = 1; distance < static_cast<int>(signature.params.size()); ++distance) {
      order.push_back(static_cast<int>(i) + distance);
      order.push_back(static_cast<int>(i) - distance);
    }
    for (int neighbour : order) {
      if (neighbour < 0 || neighbour >= static_cast<int>(signature.params.size())) {
        continue;
      }
      auto param = g->getParamDecl(neighbour);
      if (signature.params[neighbour].value.kind == Kind::Integer && count_like(param->getName())) {
        auto &value = signature.params[i].value;
        value.kind = Kind::Array;
        value.pointee = std::make_shared<Value>(element);
        value.count_index = neighbour;
        value.writes_back = !gp.isConstQualified();
        value.note.clear();
        break;
      }
    }
  }
  signature.supported = true;
  for (auto &param : signature.params) {
    if (!Supported(param.value)) {
      signature.supported = false;
      signature.note = param.name + ": " + param.value.note;
    }
  }
  if (!Supported(signature.result) || signature.result.kind == Kind::OutSlot || signature.result.kind == Kind::Array ||
      signature.result.kind == Kind::Callback) {
    signature.supported = false;
    signature.note = "result: " + (signature.result.note.empty() ? std::string("unsupported kind") : signature.result.note);
  }
}

Signature Generator::FromFunction(FunctionDecl *g, FunctionDecl *h) {
  Signature signature;
  for (unsigned i = 0; i < g->getNumParams(); ++i) {
    Parameter param{Classify(gc_, g->getParamDecl(i)->getType(), hc_, h->getParamDecl(i)->getType(), true),
                    "a" + std::to_string(i)};
    if (!Supported(param.value)) {
      signature.supported = false;
      signature.note = "parameter " + std::to_string(i) + ": " + param.value.note;
    }
    signature.params.push_back(param);
  }
  signature.result = Classify(gc_, g->getReturnType(), hc_, h->getReturnType(), false);
  if (!Supported(signature.result) || signature.result.kind == Kind::OutSlot ||
      signature.result.kind == Kind::Callback || signature.result.kind == Kind::Block) {
    signature.supported = false;
    signature.note = "result: " + (signature.result.note.empty() ? std::string("unsupported kind") : signature.result.note);
  }
  DetectArrays(gc_, hc_, g, h, signature);
  return signature;
}

Signature Generator::FromMethod(ObjCMethodDecl *g, ObjCMethodDecl *h) {
  Signature signature;
  for (unsigned i = 0; i < g->param_size(); ++i) {
    Parameter param{Classify(gc_, g->getParamDecl(i)->getType(), hc_, h->getParamDecl(i)->getType(), true),
                    "a" + std::to_string(i)};
    if (!Supported(param.value)) {
      signature.supported = false;
      signature.note = "parameter " + std::to_string(i) + ": " + param.value.note;
    }
    signature.params.push_back(param);
  }
  signature.result = Classify(gc_, g->getReturnType(), hc_, h->getReturnType(), false);
  if (!Supported(signature.result) || signature.result.kind == Kind::OutSlot ||
      signature.result.kind == Kind::Callback) {
    signature.supported = false;
    signature.note = "result: " + (signature.result.note.empty() ? std::string("unsupported kind") : signature.result.note);
  }
  DetectArrays(gc_, hc_, g, h, signature);
  if (signature.result.kind == Kind::Block) {
    signature.supported = false;
    signature.note = "block result";
  }
  return signature;
}

QualType Generator::EncodedType(ASTContext &context, StringRef &text, bool guest, std::string &error) {
  while (!text.empty() && strchr("rnNoORV", text[0])) {
    text = text.drop_front();
  }
  if (text.empty()) {
    error = "truncated encoding";
    return QualType();
  }
  char c = text[0];
  text = text.drop_front();
  switch (c) {
    case 'c': return context.SignedCharTy;
    case 'C': return context.UnsignedCharTy;
    case 's': return context.ShortTy;
    case 'S': return context.UnsignedShortTy;
    case 'i': return context.IntTy;
    case 'I': return context.UnsignedIntTy;
    case 'l': return context.IntTy;
    case 'L': return context.UnsignedIntTy;
    case 'q': return context.LongLongTy;
    case 'Q': return context.UnsignedLongLongTy;
    case 'f': return context.FloatTy;
    case 'd': return context.DoubleTy;
    case 'B': return context.BoolTy;
    case 'v': return context.VoidTy;
    case '*': return context.getPointerType(context.CharTy);
    case '#': return context.getObjCClassType();
    case ':': return context.getObjCSelType();
    case '@':
      if (text.starts_with("?")) {
        text = text.drop_front();
        error = "block parameter of a method the SDK does not declare";
        return QualType();
      }
      if (text.starts_with("\"")) {
        text = text.drop_front().drop_until([](char ch) { return ch == '"'; }).drop_front();
      }
      return context.getObjCIdType();
    case '^': {
      auto pointee = EncodedType(context, text, guest, error);
      return pointee.isNull() ? pointee : context.getPointerType(pointee);
    }
    case '{': {
      auto name = text.take_until([](char ch) { return ch == '=' || ch == '}'; });
      int depth = 1;
      size_t i = 0;
      for (; i < text.size() && depth; ++i) {
        if (text[i] == '{') {
          ++depth;
        } else if (text[i] == '}') {
          --depth;
        }
      }
      StringRef whole = text.take_front(i);
      text = text.drop_front(i);
      if (!name.empty() && name != "?") {
        for (auto decl : context.getTranslationUnitDecl()->lookup(DeclarationName(&context.Idents.get(name)))) {
          if (auto typedef_decl = dyn_cast<TypedefNameDecl>(decl)) {
            return typedef_decl->getUnderlyingType();
          }
          if (auto record = dyn_cast<RecordDecl>(decl)) {
            return context.getCanonicalTagType(record);
          }
        }
      }
      // The SDK does not name this structure (an anonymous struct, as CLLocationCoordinate2D
      // / MKCoordinateRegion encode). Synthesise a record from the encoded members so struct
      // parameters and returns can still be mirrored across the ABI instead of failing.
      auto body = whole.find('=');
      if (body == StringRef::npos) {
        error = "structure " + name.str() + " is not declared by the SDK";
        return QualType();
      }
      return SynthesizeRecord(context, whole.substr(0, whole.size() - 1).substr(body + 1), guest, error);
    }
    default:
      error = std::string("unsupported encoding character ") + c;
      return QualType();
  }
}

QualType Generator::SynthesizeRecord(ASTContext &context, StringRef fields, bool guest, std::string &error) {
  auto &cache = guest ? guest_records_ : host_records_;
  std::string key = fields.str();
  if (auto found = cache.find(key); found != cache.end()) {
    return found->second;
  }
  auto record = RecordDecl::Create(context, TagTypeKind::Struct, context.getTranslationUnitDecl(), SourceLocation(),
                                   SourceLocation(), &context.Idents.get("xl_anon_" + std::to_string(record_counter_++)));
  record->startDefinition();
  StringRef text = fields;
  unsigned index = 0;
  while (!text.empty()) {
    if (text.starts_with("\"")) {  // a named member: "name"type
      text = text.drop_front().drop_until([](char ch) { return ch == '"'; }).drop_front();
      continue;
    }
    auto field = EncodedType(context, text, guest, error);
    if (field.isNull()) {
      return QualType();
    }
    auto decl = FieldDecl::Create(context, record, SourceLocation(), SourceLocation(), &context.Idents.get("f" + std::to_string(index++)),
                                  field, nullptr, nullptr, false, ICIS_NoInit);
    decl->setAccess(AS_public);
    record->addDecl(decl);
  }
  record->completeDefinition();
  auto type = context.getCanonicalTagType(record);
  cache[key] = type;
  // Emit a C definition for the synthesised struct so the generated bridges can name it. Inner
  // members were synthesised first (during field parsing), so appending here keeps the C
  // definitions in dependency order.
  std::ostringstream def;
  def << "struct " << record->getName().str() << " {";
  unsigned field = 0;
  for (auto member : record->fields()) {
    def << " " << Spell(context, member->getType(), "f" + std::to_string(field++)) << ";";
  }
  def << " };\n";
  (guest ? guest_record_defs_ : host_record_defs_) += def.str();
  return type;
}

Signature Generator::FromEncoding(const std::string &encoding, std::string &error) {
  Signature signature;
  StringRef text(encoding);
  auto skip_offset = [&] { text = text.drop_while([](char ch) { return isdigit(static_cast<unsigned char>(ch)) || ch == '-'; }); };
  auto g = EncodedType(gc_, text, true, error);
  StringRef host_text(encoding);
  auto h = EncodedType(hc_, host_text, false, error);
  if (g.isNull() || h.isNull()) {
    signature.supported = false;
    signature.note = error;
    return signature;
  }
  signature.result = Classify(gc_, g, hc_, h, false);
  skip_offset();
  for (unsigned index = 0; !text.empty(); ++index) {
    StringRef before = text;
    auto gp = EncodedType(gc_, text, true, error);
    StringRef host_param = before;
    auto hp = EncodedType(hc_, host_param, false, error);
    skip_offset();
    if (gp.isNull() || hp.isNull()) {
      signature.supported = false;
      signature.note = error;
      return signature;
    }
    if (index < 2) {
      continue;
    }
    Parameter param{Classify(gc_, gp, hc_, hp, true), "a" + std::to_string(index - 2)};
    if (!Supported(param.value)) {
      signature.supported = false;
      signature.note = param.value.note;
    }
    signature.params.push_back(param);
  }
  return signature;
}

std::string Generator::HostEncoding(const Signature &signature) {
  std::string encoding;
  hc_.getObjCEncodingForType(signature.result.host, encoding);
  std::string params;
  uint64_t offset = 8;
  for (auto &param : signature.params) {
    std::string type;
    hc_.getObjCEncodingForType(param.value.host, type);
    params += type + std::to_string(offset);
    offset += std::max<uint64_t>(4, (hc_.getTypeSize(param.value.host) / 8 + 3) & ~3ull);
  }
  return encoding + std::to_string(offset) + "@0:4" + params;
}

std::string Generator::EmitBridge(const std::string &id, const Signature &signature, CallKind kind,
                                  const std::string &guest_name, const std::string &callee, const FormatInfo &format,
                                  const std::string &manual) {
  std::string pack = "xl_pack_" + id;
  std::string gfields, hfields;
  bool message = kind == CallKind::Message;
  if (message) {
    gfields += " uint64_t self; uint64_t sel;";
    hfields += " uint64_t self; uint64_t sel;";
  }
  for (auto &param : signature.params) {
    gfields += " " + PackField(param.value, true) + " " + param.name + ";";
    hfields += " " + PackField(param.value, false) + " " + param.name + ";";
  }
  if (format.present && format.va_param < 0) {
    gfields += " uint64_t va;";
    hfields += " uint64_t va;";
  }
  bool has_result = signature.result.kind != Kind::Void;
  if (has_result) {
    gfields += " " + PackField(signature.result, true) + " r;";
    hfields += " " + PackField(signature.result, false) + " r;";
  }
  std::ostringstream gs, hs;
  gs << "struct __attribute__((packed)) " << pack << " {" << gfields << " };\n";
  gs << "extern void xl_trap_" << id << "(struct " << pack << " *);\n";
  std::string args = message ? "id self, SEL _cmd" : "";
  // A function the guest calls as variadic (fcntl/ioctl/open/openat's trailing arg) receives those arguments on the
  // STACK under the Darwin arm64 ABI -- not in x2/x3. Declaring the wrapper with plain trailing parameters would read
  // whatever the registers happen to hold (F_GETPATH then got a garbage buffer), so the last `variadic_words_` params
  // are dropped from the wrapper's prototype, which ends in "...", and read back with va_arg.
  size_t named_params = signature.params.size() - std::min<size_t>(variadic_words_, signature.params.size());
  for (size_t i = 0; i < named_params; ++i) {
    auto &param = signature.params[i];
    args += (args.empty() ? "" : ", ") + Spell(gc_, param.value.guest, param.name);
  }
  if ((format.present && format.va_param < 0) || variadic_words_) {
    args += ", ...";
  }
  if (args.empty()) {
    args = "void";
  }
  std::string name = message ? "xl_" + id : guest_name;
  std::string definition = message ? name : "xl_fn_" + id;
  gs << (message ? "" : "")
     << Spell(gc_, has_result ? signature.result.guest : gc_.VoidTy, definition + "(" + args + ")") << "\n{\n";
  gs << "    struct " << pack << " p;\n";
  if (message) {
    gs << "    p.self = (uint64_t)(uintptr_t)self;\n    p.sel = (uint64_t)(uintptr_t)_cmd;\n";
  }
  for (size_t i = 0; i < named_params; ++i) {
    auto &param = signature.params[i];
    gs << "    p." << param.name << " = " << GuestStore(param.value, param.name) << ";\n";
  }
  if (variadic_words_) {
    gs << "    va_list vap;\n    va_start(vap, " << signature.params[named_params - 1].name << ");\n";
    for (size_t i = named_params; i < signature.params.size(); ++i)
      gs << "    p." << signature.params[i].name << " = (uint64_t)va_arg(vap, unsigned long);\n";
    gs << "    va_end(vap);\n";
  }
  if (format.present && format.va_param < 0) {
    gs << "    va_list ap;\n    va_start(ap, " << signature.params.back().name << ");\n    p.va = (uint64_t)(uintptr_t)ap;\n";
  }
  gs << "    xl_trap_" << id << "(&p);\n";
  if (format.present && format.va_param < 0) {
    gs << "    va_end(ap);\n";
  }
  if (has_result) {
    gs << "    return " << GuestLoad(signature.result, "p.r") << ";\n";
  }
  gs << "}\n";
  if (!message) {
    gs << "__asm__(\".globl _" << name << "\\n.set _" << name << ", _" << definition << "\\n\");\n";
  }
  gs << "\n";
  hs << "struct __attribute__((packed)) " << pack << " {" << hfields << " };\n";
  hs << "void xl_h_" << id << "(State *state)\n{\n    struct " << pack << " *p = xl_argument(state);\n";
  if (!manual.empty()) {
    hs << "    " << manual << "(p);\n    xl_return(state);\n}\n\n";
    guest_ += gs.str();
    host_ += hs.str();
    return name;
  }
  std::string prep, post, call_args;
  for (size_t i = 0; i < signature.params.size(); ++i) {
    auto &param = signature.params[i];
    std::string arg;
    if (format.present && i == format.format_index) {
      arg = format.object ? "(id)format.object" : "format.text";
    } else if (format.present && static_cast<int>(i) == format.va_param) {
      arg = "(va_list)format.arguments";  // the va_list parameter, marshalled below
    } else {
      arg = HostLoad(param.value, "p->" + param.name, "\"" + id + "\", " + std::to_string(i), prep, post, i);
    }
    call_args += ", " + arg;
  }
  if (format.present) {
    // Source of the guest varargs: the trailing ... captured via va_start (p->va) for a variadic
    // function, or the explicit va_list parameter for a v*printf-family function (vfprintf, ...).
    std::string va_src = format.va_param < 0 ? "p->va" : ("p->" + signature.params[format.va_param].name);
    prep += "    struct xl_format format;\n    xl_format_marshal(&format, " +
            std::string(format.object ? "0, (id)xl_narrow_pointer(p->" + signature.params[format.format_index].name + ", \"" + id + "\", 0)"
                                      : "(const char *)xl_narrow_pointer(p->" + signature.params[format.format_index].name + ", \"" + id + "\", 0), 0") +
            ", (const uint64_t *)(uintptr_t)" + va_src + ", \"" + id + "\");\n";
    if (format.va_param < 0) {
      call_args += ", (va_list)format.arguments";  // variadic: the marshalled list is the trailing arg
    }
    post += "    xl_format_release(&format);\n";
  }
  std::string call;
  if (message) {
    std::string types = Spell(hc_, has_result ? signature.result.host : hc_.VoidTy) + " (*)(";
    std::string super_types = types + "struct objc_super *, SEL";
    types += "id, SEL";
    for (auto &param : signature.params) {
      types += ", " + Spell(hc_, param.value.host);
      super_types += ", " + Spell(hc_, param.value.host);
    }
    if (format.present) {
      types += ", va_list";
      super_types += ", va_list";
    }
    types += ")";
    super_types += ")";
    bool stret = has_result && signature.result.kind == Kind::Record && hc_.getTypeSize(signature.result.host) > 32;
    // A receiver that is a class the guest laid out itself is sent to as its host shadow (runtime/swift_classes.m).
    prep += "    Class super_class = xl_take_super_class(state);\n    struct objc_super super_receiver = {(id)xl_class_in(p->self), super_class};\n";
    std::string plain = "((" + types + ")" + (stret ? "objc_msgSend_stret" : "objc_msgSend") + ")((id)xl_class_in(p->self), (SEL)(uintptr_t)p->sel" + call_args + ")";
    std::string super = "((" + super_types + ")" + (stret ? "objc_msgSendSuper2_stret" : "objc_msgSendSuper2") + ")(&super_receiver, (SEL)(uintptr_t)p->sel" + call_args + ")";
    if (format.present) {
      plain = callee + "((id)xl_class_in(p->self), (SEL)(uintptr_t)p->sel" + call_args + ")";
      super = plain;
    }
    call = "(super_class ? " + super + " : " + plain + ")";
  } else {
    call = callee + "(" + (call_args.empty() ? "" : call_args.substr(2)) + ")";
  }
  hs << prep;
  if (has_result) {
    hs << HostStore(signature.result, call, "p->r");
    // Failure trace (flag file xl-trace-errno at run time): a bridged libc call that returns -1 logs its name, errno
    // and first argument (shown as a path when it looks like one). errno is read straight after the call.
    if (!message && signature.result.kind == Kind::Integer && signature.result.is_signed && !signature.params.empty()) {
      hs << "    xl_errno_trace(\"" << id << "\", (int64_t)p->r, (uint64_t)p->" << signature.params[0].name << ", "
         << (signature.params.size() > 1 ? "(uint64_t)p->" + signature.params[1].name : std::string("0")) << ");\n";
    }
  } else {
    hs << "    " << call << ";\n";
  }
  hs << post << "    xl_return(state);\n}\n\n";
  guest_ += gs.str();
  host_ += hs.str();
  return name;
}

void Generator::Fault(const std::string &symbol, const std::string &reason) {
  bool weak = weak_only_.count(symbol);
  Report(symbol + ": UNSUPPORTED: " + reason + (weak ? " (weak import, left unbound)" : ""));
  ++unsupported_;
  if (weak) {
    return;
  }
  auto label = "xl_message_" + std::to_string(counter_++);
  std::string message = symbol.substr(1) + ": " + reason;
  guest_ += "__attribute__((used)) static const char " + label + "[] __asm(\"_" + label + "\") = \"" + message + "\";\n";
  guest_ += "__asm__(\".globl " + symbol + "\\n.p2align 2\\n" + symbol + ":\\n    adrp x0, _" + label + "@PAGE\\n    add x0, x0, _" +
            label + "@PAGEOFF\\n    b _xl_trap_xl_unsupported\\n\");\n\n";
}

void Generator::EmitEmptyCollectionSingleton(const std::string &symbol, const std::string &host_class) {
  auto name = symbol.substr(1);
  guest_ += "id xl_data_" + name + " __asm__(\"" + symbol + "\");\n\n";
  init_ += "    *(uint64_t *)(uintptr_t)XL_GUEST_" + name + " = xl_object_out((uintptr_t)[[" + host_class +
           " alloc] init]);\n";
  Report(symbol + ": guest-owned empty " + host_class + " singleton, created at startup");
}

void Generator::EmitTlvBootstrap() {
  // The guest's __thread_vars descriptors bind their thunk to __tlv_bootstrap, and a thread-local
  // access calls thunk(descriptor) with the descriptor in the first argument, expecting back the
  // variable's per-thread address. iOS 6 has no TLV runtime. Emit a bridge for it by hand: the SDK
  // does declare _tlv_bootstrap, but as `void(void)` (a placeholder), so neither a real declaration
  // nor EmitManualFunction's C definition can be used without colliding -- synthesize the true
  // one-pointer-in, one-pointer-out signature and route it to the runtime handler. The bridge's
  // .set alias defines the linker symbol __tlv_bootstrap without a colliding C name.
  Value ptr;
  ptr.kind = Kind::Pointer;
  ptr.guest = gc_.getPointerType(gc_.VoidTy);
  ptr.host = hc_.getPointerType(hc_.VoidTy);
  Signature signature;
  signature.supported = true;
  signature.params.push_back({ptr, "a0"});
  signature.result = ptr;
  EmitBridge("tlv_bootstrap", signature, CallKind::Function, "_tlv_bootstrap", "", FormatInfo{},
             "xl_manual__tlv_bootstrap");
  Report("__tlv_bootstrap: thread-local storage bootstrap -> xl_manual__tlv_bootstrap");
}

void Generator::EmitTrampoline(const std::string &symbol, const std::string &trap) {
  auto name = symbol.substr(1);
  guest_ += "extern void xl_trap_" + trap + "(void);\n__asm__(\".globl _" + name + "\\n.p2align 2\\n_" + name +
            ":\\n    b _xl_trap_" + trap + "\\n\");\n\n";
  Report(symbol + ": register-preserving trampoline to " + trap);
}

void Generator::EmitManualFunction(const std::string &symbol, unsigned arguments, const std::string &handler) {
  auto name = symbol.substr(1);
  auto functions = gc_.getTranslationUnitDecl()->lookup(DeclarationName(&gc_.Idents.get(name)));
  FunctionDecl *decl = nullptr;
  for (auto candidate : functions) {
    decl = decl ? decl : dyn_cast<FunctionDecl>(candidate);
  }
  if (!decl || decl->getNumParams() != arguments) {
    Fault(symbol, "manual bridge has no matching declaration");
    return;
  }
  std::string pack = "xl_pack_" + name;
  std::ostringstream gs, hs;
  gs << "struct __attribute__((packed)) " << pack << " {";
  for (unsigned i = 0; i < arguments; ++i) {
    gs << " uint64_t a" << i << ";";
  }
  gs << " uint64_t r; };\nextern void xl_trap_" << name << "(struct " << pack << " *);\n";
  std::string args;
  for (unsigned i = 0; i < arguments; ++i) {
    args += (i ? ", " : "") + Spell(gc_, decl->getParamDecl(i)->getType(), "a" + std::to_string(i));
  }
  gs << Spell(gc_, decl->getReturnType(), name + "(" + args + ")") << "\n{\n    struct " << pack << " p;\n";
  for (unsigned i = 0; i < arguments; ++i) {
    gs << "    p.a" << i << " = (uint64_t)(uintptr_t)a" << i << ";\n";
  }
  gs << "    xl_trap_" << name << "(&p);\n";
  if (!decl->getReturnType()->isVoidType()) {
    gs << "    return (" << Spell(gc_, decl->getReturnType()) << ")(uintptr_t)p.r;\n";
  }
  gs << "}\n\n";
  hs << "void " << handler << "(void *pack);\nvoid xl_h_" << name << "(State *state)\n{\n    " << handler
     << "(xl_argument(state));\n    xl_return(state);\n}\n\n";
  guest_ += gs.str();
  host_ += hs.str();
  Report(symbol + ": manual bridge " + handler + " (the runtime keeps the address of the guest slot)");
}

// objc_setHook_lazyClassNamer(hook, &previous): the Swift runtime names the classes it builds for itself (a generic
// class's mangled name) only when the Objective-C runtime asks, and chains every class that is not its own to the hook
// it replaced. iOS 6 has no such hook, so the runtime keeps the hook and asks it (runtime/swift_classes.m); the
// hook it replaced is a guest function that names nothing, as the real runtime's is.
void Generator::EmitLazyClassNamer(const std::string &symbol) {
  guest_ +=
      "extern void xl_trap_objc_setHook_lazyClassNamer(void *);\n"
      "static const char *xl_no_lazy_class_name(Class cls) { return 0; }\n"
      "void objc_setHook_lazyClassNamer(objc_hook_lazyClassNamer newValue, objc_hook_lazyClassNamer *oldOutValue)\n{\n"
      "    struct __attribute__((packed)) { uint64_t new_hook, old_out, none; } p;\n"
      "    p.new_hook = (uint64_t)(uintptr_t)newValue;\n"
      "    p.old_out = (uint64_t)(uintptr_t)oldOutValue;\n"
      "    p.none = (uint64_t)(uintptr_t)xl_no_lazy_class_name;\n"
      "    xl_trap_objc_setHook_lazyClassNamer(&p);\n}\n\n";
  host_ +=
      "void xl_manual_objc_setHook_lazyClassNamer(void *pack);\n"
      "void xl_h_objc_setHook_lazyClassNamer(State *state)\n{\n"
      "    xl_manual_objc_setHook_lazyClassNamer(xl_argument(state));\n    xl_return(state);\n}\n\n";
  Report(symbol + ": manual bridge xl_manual_objc_setHook_lazyClassNamer (the runtime keeps the hook and asks it)");
}

// objc_setHook_getImageName(hook, &previous): the hook answers class_getImageName for a class (BOOL hook(cls, &name): the Swift
// runtime answers for its own classes and chains the rest to the hook it replaced). Without the call it patches every loaded image's lazy pointers through a dyld add-image
// callback, which reads a 32-bit host image's header as a 64-bit one. iOS 6 libobjc has no such hook, so class_getImageName
// is a manual bridge that asks the hook first (runtime/swift_classes.m), and the hook it replaced is a guest function that
// asks the host's own class_getImageName.
void Generator::EmitImageNameHook(const std::string &symbol) {
  guest_ +=
      "extern void xl_trap_objc_setHook_getImageName(void *);\n"
      "extern void xl_trap_xl_default_class_getImageName(void *);\n"
      "static BOOL xl_default_image_name(Class cls, const char **outImageName)\n{\n"
      "    struct __attribute__((packed)) { uint64_t cls, r; } p;\n"
      "    p.cls = (uint64_t)(uintptr_t)cls;\n"
      "    xl_trap_xl_default_class_getImageName(&p);\n"
      "    *outImageName = (const char *)(uintptr_t)p.r;\n"
      "    return p.r != 0;\n}\n\n"
      "void objc_setHook_getImageName(objc_hook_getImageName newValue, objc_hook_getImageName *outOldValue)\n{\n"
      "    struct __attribute__((packed)) { uint64_t new_hook, old_out, default_hook; } p;\n"
      "    p.new_hook = (uint64_t)(uintptr_t)newValue;\n"
      "    p.old_out = (uint64_t)(uintptr_t)outOldValue;\n"
      "    p.default_hook = (uint64_t)(uintptr_t)xl_default_image_name;\n"
      "    xl_trap_objc_setHook_getImageName(&p);\n}\n\n";
  host_ +=
      "void xl_manual_objc_setHook_getImageName(void *pack);\n"
      "void xl_h_objc_setHook_getImageName(State *state)\n{\n"
      "    xl_manual_objc_setHook_getImageName(xl_argument(state));\n    xl_return(state);\n}\n\n"
      "void xl_manual_default_class_getImageName(void *pack);\n"
      "void xl_h_xl_default_class_getImageName(State *state)\n{\n"
      "    xl_manual_default_class_getImageName(xl_argument(state));\n    xl_return(state);\n}\n\n";
  Report(symbol + ": manual bridge xl_manual_objc_setHook_getImageName (class_getImageName asks the hook first)");
}

// The exec family. The vector forms take argv (and envp) as arrays of pointers, which the host reads 4 bytes wide, so
// each goes to a hand-written handler that narrows them. The list forms are variadic: the guest's arguments sit in
// guest registers and stack a host bridge cannot walk, so guest code gathers them into a vector and calls the vector
// form -- whichever of the two the guest imports, both are emitted, once.
void Generator::EmitExec(const std::string &symbol) {
  static const std::map<std::string, unsigned> vectors = {{"_execv", 2}, {"_execve", 3}, {"_execvp", 2}, {"_execvP", 3}};
  static const std::map<std::string, std::string> lists = {{"_execl", "_execv"}, {"_execle", "_execve"}, {"_execlp", "_execvp"}};
  auto list = lists.find(symbol);
  auto vector = list == lists.end() ? symbol : list->second;
  if (exec_emitted_.insert(vector).second) {
    EmitManualFunction(vector, vectors.at(vector), "xl_manual_" + vector.substr(1));
  }
  if (list == lists.end() || !exec_emitted_.insert(symbol).second) {
    return;
  }
  auto name = symbol.substr(1);
  bool environment = name == "execle";
  std::ostringstream gs;
  gs << "int " << name << "(const char *path, const char *arg0, ...)\n{\n"
     << "    __builtin_va_list ap, count;\n"
     << "    unsigned long n = 0;\n"
     << "    __builtin_va_start(ap, arg0);\n"
     << "    if (arg0) {\n"
     << "        __builtin_va_copy(count, ap);\n"
     << "        for (n = 1; __builtin_va_arg(count, const char *); n++)\n"
     << "            ;\n"
     << "        __builtin_va_end(count);\n"
     << "    }\n"
     << "    const char *argv[n + 1];\n"
     << "    argv[0] = arg0;\n"
     << "    for (unsigned long i = 1; i < n; i++)\n"
     << "        argv[i] = __builtin_va_arg(ap, const char *);\n"
     << "    argv[n] = 0;\n";
  if (environment) {
    // What follows the terminating NULL of execle's list is the environment vector.
    gs << "    if (n)\n"
       << "        (void)__builtin_va_arg(ap, const char *);\n"
       << "    char *const *envp = __builtin_va_arg(ap, char *const *);\n"
       << "    __builtin_va_end(ap);\n"
       << "    return " << vector.substr(1) << "(path, (char *const *)argv, envp);\n";
  } else {
    gs << "    __builtin_va_end(ap);\n"
       << "    return " << vector.substr(1) << "(path, (char *const *)argv);\n";
  }
  gs << "}\n\n";
  guest_ += gs.str();
  Report(symbol + ": guest-side argument collection, then " + vector);
}

bool Generator::EmitFunction(const std::string &symbol, FunctionDecl *g, FunctionDecl *h) {
  auto name = g->getNameAsString();
  static bool section_helper_emitted = false;
  auto emit_section_helper = [&]() {
    if (section_helper_emitted)
      return;
    section_helper_emitted = true;
    guest_ +=
        "static const struct section_64 *xl_find_section_64(const struct mach_header_64 *mhp, const char *segname, const char *sectname)\n"
        "{\n"
        "    const struct load_command *lc = (const struct load_command *)(mhp + 1);\n"
        "    for (uint32_t i = 0; i < mhp->ncmds; i++, lc = (const struct load_command *)((const char *)lc + lc->cmdsize)) {\n"
        "        if (lc->cmd != LC_SEGMENT_64)\n"
        "            continue;\n"
        "        const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;\n"
        "        const struct section_64 *sect = (const struct section_64 *)(seg + 1);\n"
        "        for (uint32_t j = 0; j < seg->nsects; j++, sect++)\n"
        "            if (!strncmp(sect->sectname, sectname, 16) && !strncmp(sect->segname, segname, 16))\n"
        "                return sect;\n"
        "    }\n"
        "    return 0;\n"
        "}\n\n";
  };
  if (name == "getsectbynamefromheader_64") {
    // Mach-O introspection of a GUEST image: the header the guest passes is the rehosted arm64 image's
    // own 64-bit header (the original bytes sit at the guest base), which the host's 32-bit dyld
    // cannot parse, and the struct section_64 it returns has a layout the bridge cannot convert.
    // Walk the 64-bit load commands in guest code instead and return a pointer into the header.
    emit_section_helper();
    guest_ +=
        "const struct section_64 *getsectbynamefromheader_64(const struct mach_header_64 *mhp, const char *segname, const char *sectname)\n"
        "{\n"
        "    return (mhp && mhp->magic == MH_MAGIC_64) ? xl_find_section_64(mhp, segname, sectname) : 0;\n"
        "}\n\n";
    Report(symbol + ": guest-side Mach-O section lookup (64-bit guest header)");
    return true;
  }
  FormatInfo format;
  // printf-like functions whose headers carry no format attribute: name -> (va_list variant, index of the
  // format parameter). SQLite's own printf dialect is handled in the runtime marshaller.
  static const std::map<std::string, std::pair<std::string, int>> unattributed_printf = {
      {"sqlite3_mprintf", {"sqlite3_vmprintf", 0}}, {"sqlite3_snprintf", {"sqlite3_vsnprintf", 2}}};
  if (!g->getAttr<FormatAttr>() && g->isVariadic()) {
    if (auto known = unattributed_printf.find(name); known != unattributed_printf.end()) {
      format.present = true;
      format.object = false;
      format.format_index = known->second.second;
      format.va_variant = known->second.first;
    }
  }
  if (auto attr = g->getAttr<FormatAttr>()) {
    static const std::map<std::string, std::string> variants = {
        {"printf", "vprintf"}, {"fprintf", "vfprintf"}, {"sprintf", "vsprintf"}, {"snprintf", "vsnprintf"},
        {"asprintf", "vasprintf"}, {"dprintf", "vdprintf"}, {"syslog", "vsyslog"}, {"NSLog", "NSLogv"},
        {"asl_log", "asl_vlog"}};
    // v*printf-family functions take an explicit va_list and only READ it. Bridge them by
    // marshalling the guest va_list to a host one and calling the function itself. (vscanf-family
    // WRITES through the va_list -- out-params -- and is deliberately NOT here; it needs copy-back.)
    static const std::set<std::string> valist_readers = {
        "vprintf", "vfprintf", "vsprintf", "vsnprintf", "vasprintf", "vdprintf",
        "vsyslog", "asl_vlog", "NSLogv"};
    auto variant = variants.find(name);
    if (variant != variants.end() && g->isVariadic()) {
      format.present = true;
      format.object = attr->getType()->getName() == "NSString";
      format.format_index = attr->getFormatIdx() - 1;
      format.va_variant = variant->second;
    } else if (!g->isVariadic() && valist_readers.count(name) && g->getNumParams() >= 1) {
      format.present = true;
      format.object = attr->getType()->getName() == "NSString";
      format.format_index = attr->getFormatIdx() - 1;
      format.va_variant = name;  // call the function itself with the marshalled va_list
      format.va_param = static_cast<int>(g->getNumParams()) - 1;  // the va_list is the last parameter
    } else {
      Fault(symbol, "formatted function without a known va_list variant");
      return false;
    }
  } else if (g->isVariadic() && !format.present) {
    // A handful of libc functions are declared variadic but every caller passes a fixed number of
    // trailing machine-word arguments (open's mode, fcntl/ioctl's arg). On armv7 those land in the
    // same core registers a fixed parameter would, and pointer arguments are passed through without
    // translation, so bridge them by appending that many pass-through words. A cmd that ignores its
    // trailing arg just reads an unused word, which is harmless.
    static const std::map<std::string, unsigned> fixed_variadic = {
        {"open", 1}, {"fcntl", 1}, {"ioctl", 1}, {"openat", 1}};
    // A function the target release lacks is routed to a runtime shim (same fixed-arity marshalling)
    // instead of the real symbol, so no undefined libSystem import is left at load. The *at family
    // is absent on iOS 6; xl_shim_openat emulates openat with F_GETPATH dirfd resolution + open.
    static const std::map<std::string, std::string> shim_callee = {{"openat", "xl_shim_openat"}};
    auto fv = fixed_variadic.find(name);
    if (fv == fixed_variadic.end()) {
      Fault(symbol, "variadic function without a format attribute");
      return false;
    }
    auto signature = FromFunction(g, h);
    if (!signature.supported) {
      Fault(symbol, signature.note);
      return false;
    }
    for (unsigned i = 0; i < fv->second; ++i) {
      Value raw;
      raw.kind = Kind::Pointer;
      raw.guest = gc_.getUIntPtrType();
      raw.host = hc_.getUIntPtrType();
      signature.params.push_back({raw, "v" + std::to_string(i)});
    }
    auto sc = shim_callee.find(name);
    variadic_words_ = fv->second;
    EmitBridge(name, signature, CallKind::Function, name, sc == shim_callee.end() ? name : sc->second, format, "");
    variadic_words_ = 0;
    return true;
  }
  auto signature = FromFunction(g, h);
  if (!signature.supported) {
    Fault(symbol, signature.note);
    return false;
  }
  // A non-variadic function absent on iOS 6 but bridgeable from a supplied declaration is routed
  // to a runtime shim instead of the (nonexistent) real symbol. The typed-malloc family (TMO,
  // iOS 16 / macOS 13, emitted by default with the typed operator new) is dropped to the plain
  // allocator -- the type-id hint is discarded, which is always sound.
  static const std::map<std::string, std::string> shim_callee = {
      {"malloc_type_malloc", "xl_shim_malloc_type_malloc"},
      {"malloc_type_calloc", "xl_shim_malloc_type_calloc"},
      {"malloc_type_realloc", "xl_shim_malloc_type_realloc"},
      {"malloc_type_aligned_alloc", "xl_shim_malloc_type_aligned_alloc"},
      // The *at family (iOS 8+): absent on iOS 6, emulated in the runtime (path resolved via F_GETPATH).
      {"mkdirat", "xl_shim_mkdirat"}, {"unlinkat", "xl_shim_unlinkat"}, {"fstatat", "xl_shim_fstatat"},
      {"readlinkat", "xl_shim_readlinkat"}, {"fchmodat", "xl_shim_fchmodat"}, {"fchownat", "xl_shim_fchownat"},
      {"faccessat", "xl_shim_faccessat"}, {"renameat", "xl_shim_renameat"}, {"linkat", "xl_shim_linkat"},
      {"symlinkat", "xl_shim_symlinkat"}, {"fdopendir", "xl_shim_fdopendir"},
      // SQLite 3.8.7+ 64-bit entry points, absent from iOS 6's libsqlite3.
      {"sqlite3_bind_blob64", "xl_shim_sqlite3_bind_blob64"}, {"sqlite3_bind_text64", "xl_shim_sqlite3_bind_text64"},
      {"sqlite3_malloc64", "xl_shim_sqlite3_malloc64"}, {"sqlite3_realloc64", "xl_shim_sqlite3_realloc64"},
      // CommonCrypto's random generator (iOS 8+).
      {"CCRandomGenerateBytes", "xl_shim_CCRandomGenerateBytes"},
      // POSIX clocks (iOS 10+).
      {"clock_gettime", "xl_shim_clock_gettime"}, {"clock_getres", "xl_shim_clock_getres"},
      // Newer-than-iOS-6 functions found by the device-side symbol probe (Zebra and its embedded frameworks).
      {"__exp10", "xl_shim_exp10"}, {"sqlite3_prepare_v3", "xl_shim_sqlite3_prepare_v3"},
      {"CGImageGetUTType", "xl_shim_CGImageGetUTType"},
      {"CGImageSourceRemoveCacheAtIndex", "xl_shim_CGImageSourceRemoveCacheAtIndex"}};
  auto sc = shim_callee.find(name);
  std::string callee = format.present ? format.va_variant : (sc == shim_callee.end() ? name : sc->second);
  if (name == "dlsym") {
    // compiler-rt's @available check (statically linked into every modern app) asks
    // dlsym(RTLD_DEFAULT, "_availability_version_check"). iOS 6 lacks it, and the fallback reads
    // SystemVersion.plist through CoreFoundation functions it also obtains from dlsym -- which come
    // back as armv7 HOST addresses that the arm64 guest then "calls" (a wild jump into host code).
    // So wrap dlsym in guest code and answer that one query with runtime/availability.c's function.
    // Everything else goes to the real bridged dlsym.
    EmitBridge(name, signature, CallKind::Function, "xl_unused_dlsym_alias", callee, format, "");
    guest_ +=
        "int _availability_version_check(uint32_t count, const void *versions);\n"
        "void *dlsym(void *handle, const char *symbol)\n"
        "{\n"
        "    if (symbol && !strcmp(symbol, \"_availability_version_check\"))\n"
        "        return (void *)_availability_version_check;\n"
        "    return xl_fn_dlsym(handle, symbol);\n"
        "}\n\n";
    return true;
  }
  if (name == "getsectiondata") {
    // Same reason as getsectbynamefromheader_64 above: a guest image's header is 64-bit arm64, so
    // resolve it in guest code -- section address = its vmaddr + (header address - __TEXT vmaddr), the
    // slide dyld would apply, which is constant because the rehosted segments keep their relative
    // layout. A header that is not a 64-bit one (a genuine host image) goes to the real bridge.
    // The header a host image hands over is the head of a variable-size object: the load commands follow it. The
    // bridge copies a struct a pointer names into a host record of that struct's size, so a copy of the header would
    // have stack behind it where its load commands should be. Pass the pointer itself: the host's memory is the
    // guest's, and the 32-bit header the guest forwards here is at that address.
    Value header;
    header.kind = Kind::Pointer;
    header.guest = gc_.getPointerType(gc_.VoidTy);
    header.host = hc_.getPointerType(hc_.VoidTy);
    signature.params[0].value = header;
    EmitBridge(name, signature, CallKind::Function, "xl_unused_getsectiondata_alias", callee, format, "");
    emit_section_helper();
    // Apps signed outside the App Store (AltStore/sideload builds such as iSH) embed their entitlements as
    // a __TEXT,__entitlements section and read it at run time -- e.g. to find their application-group id.
    // The translated binary is re-signed, so carry the ORIGINAL entitlements (extracted by translate.sh
    // from the input's signature) and answer that one query with them when the image has no such section.
    std::string entitlements_array = "static const unsigned char xl_entitlements[] = {0};\nstatic const unsigned long xl_entitlements_size = 0;\n";
    if (!EntitlementsPath.empty()) {
      if (auto buffer = MemoryBuffer::getFile(EntitlementsPath); buffer && !(*buffer)->getBuffer().empty()) {
        std::string bytes;
        raw_string_ostream os(bytes);
        for (unsigned char c : (*buffer)->getBuffer())
          os << (unsigned)c << ",";
        entitlements_array = "static const unsigned char xl_entitlements[] = {" + os.str() + "};\nstatic const unsigned long xl_entitlements_size = sizeof xl_entitlements;\n";
      }
    }
    guest_ += entitlements_array;
    guest_ +=
        "uint8_t *getsectiondata(const struct mach_header_64 *mhp, const char *segname, const char *sectname, unsigned long *size)\n"
        "{\n"
        "    if (!mhp || mhp->magic != MH_MAGIC_64)\n"
        "        return xl_fn_getsectiondata(mhp, segname, sectname, size);\n"
        "    const struct load_command *lc = (const struct load_command *)(mhp + 1);\n"
        "    intptr_t slide = 0;\n"
        "    for (uint32_t i = 0; i < mhp->ncmds; i++, lc = (const struct load_command *)((const char *)lc + lc->cmdsize)) {\n"
        "        if (lc->cmd == LC_SEGMENT_64 && !strcmp(((const struct segment_command_64 *)lc)->segname, \"__TEXT\")) {\n"
        "            slide = (intptr_t)mhp - (intptr_t)((const struct segment_command_64 *)lc)->vmaddr;\n"
        "            break;\n"
        "        }\n"
        "    }\n"
        "    const struct section_64 *sect = xl_find_section_64(mhp, segname, sectname);\n"
        "    if (!sect) {\n"
        "        if (xl_entitlements_size && !strcmp(segname, \"__TEXT\") && !strcmp(sectname, \"__entitlements\")) {\n"
        "            if (size)\n"
        "                *size = xl_entitlements_size;\n"
        "            return (uint8_t *)xl_entitlements;\n"
        "        }\n"
        "        return 0;\n"
        "    }\n"
        "    if (size)\n"
        "        *size = (unsigned long)sect->size;\n"
        "    return (uint8_t *)(sect->addr + slide);\n"
        "}\n\n";
    return true;
  }
  if (!variant_alias_.empty()) {
    // Same function, decorated symbol: a distinct bridge id (so a plain import of the same function does not
    // collide) exported under the decorated name; the host call is the plain function.
    std::string id = variant_alias_;
    for (char &c : id)
      if (c == '$')
        c = '_';
    EmitBridge(id, signature, CallKind::Function, variant_alias_, callee, format, "");
    return true;
  }
  EmitBridge(name, signature, CallKind::Function, name, callee, format, "");
  return true;
}

void Generator::EmitVariable(const std::string &symbol, VarDecl *g, VarDecl *h) {
  // Every startup copy below is guarded with `if (&name)`: a constant the SDK declares for a newer
  // release (UIFontTextStyleBody, UIFontWeightRegular, ... -- weak-imported, so its address is NULL
  // on an older OS) must leave the guest copy at its zero/nil default instead of dereferencing NULL,
  // which crashed the whole process in the generated init before any guest code ran.
  std::set<const Decl *> seen;
  if (SameLayout(gc_, g->getType(), hc_, h->getType(), seen)) {
    Passthrough(symbol);
    Report(symbol + ": host data with an identical layout");
    return;
  }
  auto value = Classify(gc_, g->getType(), hc_, h->getType(), false);
  if (g->getType()->isAnyPointerType() || g->getType()->isBlockPointerType()) {
    value.kind = Kind::Pointer;
  }
  auto name = g->getNameAsString();
  if (value.kind == Kind::Record) {
    std::vector<Leaf> leaves;
    if (!Leaves(g->getType(), h->getType(), "", "", 0, leaves)) {
      Report(symbol + ": UNSUPPORTED: data struct with an unconvertible field");
      ++unsupported_;
      return;
    }
    auto mirror = Mirror(g->getType(), h->getType());
    guest_ += Spell(gc_, g->getType(), "xl_data_" + name) + " __asm__(\"" + symbol + "\");\n\n";
    init_ += "    if (&" + name + ")\n        " + mirror + "_to_guest((struct " + mirror + " *)(uintptr_t)XL_GUEST_" + name + ", &" + name + ");\n";
    Report(symbol + ": guest copy of host data struct, filled at startup");
    return;
  }
  if (value.kind == Kind::Floating) {
    // Floating data (e.g. NSFoundationVersionNumber double, or UIWindowLevelNormal whose
    // CGFloat is 8 bytes on arm64 but 4 on armv7). A direct bind would either copy the
    // host bits into a wrong-width slot or read past a narrower host symbol, so define a
    // guest-side copy at the symbol (which resolves the data bind through the guest export)
    // and fill it at startup with the host value converted to the guest's float width.
    const char *ty = value.guest_bits == 32 ? "float" : "double";
    guest_ += Spell(gc_, g->getType(), "xl_data_" + name) + " __asm__(\"" + symbol + "\");\n\n";
    init_ += "    if (&" + name + ")\n        *(" + std::string(ty) + " *)(uintptr_t)XL_GUEST_" + name + " = (" + ty + ")" + name + ";\n";
    Report(symbol + ": guest copy of host floating data, filled at startup");
    return;
  }
  if (value.kind != Kind::Integer && value.kind != Kind::Pointer) {
    Report(symbol + ": UNSUPPORTED: data of a different layout");
    ++unsupported_;
    return;
  }
  guest_ += Spell(gc_, g->getType(), "xl_data_" + name) + " __asm__(\"" + symbol + "\");\n\n";
  init_ += "    if (&" + name + ")\n        *(uint64_t *)(uintptr_t)XL_GUEST_" + name + " = " + ScalarToGuest(value, name) + ";\n";
  Report(symbol + ": guest copy of host data, filled at startup");
}

class MethodCollector : public RecursiveASTVisitor<MethodCollector> {
 public:
  explicit MethodCollector(std::map<std::string, std::vector<ObjCMethodDecl *>> &pool) : pool_(pool) {}
  bool shouldVisitImplicitCode() const { return true; }
  bool VisitObjCMethodDecl(ObjCMethodDecl *method) {
    if (!method->isThisDeclarationADefinition()) {
      pool_[(method->isInstanceMethod() ? "-" : "+") + method->getSelector().getAsString()].push_back(method);
      pool_["*" + method->getSelector().getAsString()].push_back(method);
    }
    return true;
  }

 private:
  std::map<std::string, std::vector<ObjCMethodDecl *>> &pool_;
};

void Generator::CollectMethods(ASTContext &context, std::map<std::string, std::vector<ObjCMethodDecl *>> &pool) {
  MethodCollector collector(pool);
  collector.TraverseDecl(context.getTranslationUnitDecl());
}

ObjCMethodDecl *Counterpart(ObjCMethodDecl *guest, const std::vector<ObjCMethodDecl *> &host) {
  auto container = dyn_cast<NamedDecl>(guest->getDeclContext());
  for (auto candidate : host) {
    auto other = dyn_cast<NamedDecl>(candidate->getDeclContext());
    if (container && other && container->getName() == other->getName() &&
        candidate->isInstanceMethod() == guest->isInstanceMethod() && candidate->param_size() == guest->param_size()) {
      return candidate;
    }
  }
  return nullptr;
}

void Generator::EmitSelectors(const std::set<std::string> &selectors, const std::set<std::string> &guest_selectors) {
  if (guest_pool_.empty()) {
    CollectMethods(gc_, guest_pool_);
    CollectMethods(hc_, host_pool_);
  }
  static const std::map<std::string, std::string> manual = {
      {"countByEnumeratingWithState:objects:count:", "xl_manual_fast_enumeration"},
      {"initWithFormat:arguments:", "xl_manual_init_with_format_arguments"}};
  static const std::map<std::string, std::string> format_variants = {
      {"stringWithFormat:", "xl_format_string_with_format"},
      {"initWithFormat:", "xl_format_init_with_format"},
      {"appendFormat:", "xl_format_append_format"},
      {"localizedStringWithFormat:", "xl_format_string_with_format"}};
  static const std::map<std::string, std::string> variadic = {
      {"dictionaryWithObjectsAndKeys:", "xl_h_dictionaryWithObjectsAndKeys"},
      {"arrayWithObjects:", "xl_h_arrayWithObjects"},
      {"initWithObjects:", "xl_h_initWithObjects"},
      {"setWithObjects:", "xl_h_setWithObjects"}};
  for (auto &selector : selectors) {
    if (auto raw = variadic.find(selector); raw != variadic.end()) {
      variadic_shims_.push_back({selector, raw->second});
      Report("selector " + selector + ": variadic handler " + raw->second);
      continue;
    }
    auto found = guest_pool_.find("*" + selector);
    if (found == guest_pool_.end()) {
      Report("selector " + selector + ": " +
             (guest_selectors.count(selector) ? "implemented by the guest only" : "UNSUPPORTED: not declared by the SDK"));
      if (!guest_selectors.count(selector)) {
        ++unsupported_;
      }
      continue;
    }
    std::map<std::string, std::pair<ObjCMethodDecl *, ObjCMethodDecl *>> variants;
    std::map<std::string, unsigned> votes;
    for (auto guest : found->second) {
      auto host = Counterpart(guest, host_pool_["*" + selector]);
      if (!host) {
        continue;
      }
      // Key on the HOST (armv7) encoding, normalised, so it matches the device runtime's
      // method_getTypeEncoding (arm64 would give q/Q for NSInteger/NSUInteger where armv7 gives i/I).
      auto key = NormalizeEncoding(hc_.getObjCEncodingForMethodDecl(host));
      variants.emplace(key, std::make_pair(guest, host));
      ++votes[key];
    }
    if (variants.empty()) {
      Report("selector " + selector + ": UNSUPPORTED: no host declaration");
      ++unsupported_;
      continue;
    }
    std::string best;
    for (auto &[key, count] : votes) {
      if (best.empty() || count > votes[best]) {
        best = key;
      }
    }
    auto [guest, host] = variants[best];
    auto signature = FromMethod(guest, host);
    std::string manual_handler;
    if (auto m = manual.find(selector); m != manual.end()) {
      manual_handler = m->second;
      signature = Signature();
      for (unsigned i = 0; i < guest->param_size(); ++i) {
        Value raw;
        raw.kind = Kind::Pointer;
        raw.guest = gc_.getUIntPtrType();
        raw.host = hc_.getUIntPtrType();
        signature.params.push_back({raw, "a" + std::to_string(i)});
      }
      signature.result.kind = Kind::Pointer;
      signature.result.guest = gc_.getUIntPtrType();
      signature.result.host = hc_.getUIntPtrType();
    }
    FormatInfo format;
    std::string callee;
    if (guest->isVariadic()) {
      auto attr = guest->getAttr<FormatAttr>();
      auto variant = format_variants.find(selector);
      if (!attr || variant == format_variants.end()) {
        Report("selector " + selector + ": UNSUPPORTED: variadic method without a va_list bridge");
        ++unsupported_;
        continue;
      }
      format.present = true;
      format.object = true;
      format.format_index = attr->getFormatIdx() - 1;
      callee = variant->second;
    }
    if (!signature.supported && manual_handler.empty()) {
      Report("selector " + selector + ": UNSUPPORTED: " + signature.note);
      ++unsupported_;
      continue;
    }
    auto id = "selector_" + std::to_string(counter_++);
    EmitBridge(id, signature, CallKind::Message, "", callee, format, manual_handler);
    selector_shims_.push_back({selector, "XL_GUEST_xl_" + id});
    if (variants.size() > 1) {
      Report("selector " + selector + ": " + std::to_string(variants.size()) + " differing SDK declarations, bridged as " + best);
      // The chosen (voted) bridge is only right for the classes that share `best`. Emit a bridge
      // for EACH distinct signature and register them by type encoding, so xl_route dispatches on
      // the receiver's actual method signature; the voted bridge stays the default/fallback. Skip
      // this for selectors handled by a manual/format handler (their bridge is special-cased).
      if (manual_handler.empty() && !format.present) {
        selector_variants_.emplace_back(selector, best, "XL_GUEST_xl_" + id);
        for (auto &[key, pair] : variants) {
          if (key == best) {
            continue;
          }
          auto variant_signature = FromMethod(pair.first, pair.second);
          if (!variant_signature.supported) {
            Report("selector " + selector + " variant " + key + ": UNSUPPORTED: " + variant_signature.note);
            continue;
          }
          auto vid = "selector_" + std::to_string(counter_++);
          EmitBridge(vid, variant_signature, CallKind::Message, "", "", FormatInfo{}, "");
          selector_variants_.emplace_back(selector, key, "XL_GUEST_xl_" + vid);
        }
      }
    }
  }
}

std::string Generator::InvokeShim(const Signature &signature) {
  std::string key = Spell(gc_, signature.result.guest);
  for (auto &param : signature.params) {
    key += "," + Spell(gc_, param.value.guest);
  }
  if (auto found = invokers_.find(key); found != invokers_.end()) {
    return found->second;
  }
  auto name = "xl_invoke_" + std::to_string(invokers_.size());
  invokers_[key] = name;
  std::string gfields = " uint64_t imp; uint64_t self; uint64_t sel;", hfields = gfields;
  for (auto &param : signature.params) {
    gfields += " " + PackField(param.value, true) + " " + param.name + ";";
    hfields += " " + PackField(param.value, false) + " " + param.name + ";";
  }
  bool has_result = signature.result.kind != Kind::Void;
  if (has_result) {
    gfields += " " + PackField(signature.result, true) + " r;";
    hfields += " " + PackField(signature.result, false) + " r;";
  }
  std::string types = Spell(gc_, has_result ? signature.result.guest : gc_.VoidTy) + " (*)(id, SEL";
  std::string call_args;
  for (auto &param : signature.params) {
    types += ", " + Spell(gc_, param.value.guest);
    call_args += ", " + GuestLoad(param.value, "p->" + param.name);
  }
  types += ")";
  std::string call = "((" + types + ")(uintptr_t)p->imp)((id)(uintptr_t)p->self, (SEL)(uintptr_t)p->sel" + call_args + ")";
  guest_ += "struct __attribute__((packed)) " + name + "_pack {" + gfields + " };\nvoid " + name + "_guest(struct " + name +
            "_pack *p)\n{\n    " + (has_result ? "p->r = " + GuestStore(signature.result, call) : call) + ";\n}\n\n";
  host_ += "struct __attribute__((packed)) " + name + "_pack {" + hfields + " };\n";
  return name;
}

std::string Generator::ImpWrapper(const Signature &signature, uint64_t imp, bool class_method) {
  auto invoke = InvokeShim(signature);
  auto name = "xl_imp_" + std::to_string(counter_++);
  bool has_result = signature.result.kind != Kind::Void;
  std::string args = std::string(class_method ? "Class" : "id") + " self, SEL _cmd";
  for (auto &param : signature.params) {
    args += ", " + Spell(hc_, param.value.host, param.name);
  }
  std::ostringstream hs;
  hs << "static " << Spell(hc_, has_result ? signature.result.host : hc_.VoidTy, name + "(" + args + ")") << "\n{\n";
  hs << "    struct " << invoke << "_pack p;\n    p.imp = 0x" << std::hex << imp << std::dec << "ull;\n";
  hs << "    p.self = (uint64_t)(uintptr_t)self;\n    p.sel = (uint64_t)(uintptr_t)_cmd;\n";
  for (auto &param : signature.params) {
    if (param.value.kind == Kind::Record) {
      hs << "    " << Mirror(param.value.guest, param.value.host) << "_to_guest(&p." << param.name << ", &" << param.name << ");\n";
    } else if (param.value.kind == Kind::Block) {
      hs << "    p." << param.name << " = " << HostBlockBridge(param.value) << "(" << param.name << ");\n";
    } else if (param.value.kind == Kind::OutSlot) {
      // The host passes a pointer to a host-width slot (e.g. NSError **). Give the guest a
      // guest-width slot seeded from the host's value, pass its address, and copy it back after.
      auto &pointee = *param.value.pointee;
      std::string guest_type = pointee.kind == Kind::Floating ? (pointee.guest_bits == 32 ? "float" : "double")
                               : pointee.kind == Kind::Integer
                                   ? (pointee.is_signed ? "int" : "uint") + std::to_string(pointee.guest_bits) + "_t"
                                   : "uint64_t";
      hs << "    " << guest_type << " " << param.name << "_gslot = " << param.name << " ? (" << guest_type << ")"
         << ScalarToGuest(pointee, "*" + param.name) << " : 0;\n";
      hs << "    p." << param.name << " = " << param.name << " ? (uint64_t)(uintptr_t)&" << param.name << "_gslot : 0;\n";
    } else if (param.value.kind == Kind::Callback) {
      hs << "    xl_unsupported(\"" << name << ": host passes a function pointer\");\n";
    } else {
      hs << "    p." << param.name << " = " << ScalarToGuest(param.value, param.name) << ";\n";
    }
  }
  hs << "    xl_invoke(XL_GUEST_" << invoke << "_guest, (uintptr_t)&p);\n";
  for (size_t i = 0; i < signature.params.size(); ++i) {
    auto &param = signature.params[i];
    if (param.value.kind == Kind::OutSlot) {
      // Copy what the guest wrote back into the host's slot (narrowing the guest width to host).
      auto &pointee = *param.value.pointee;
      hs << "    if (" << param.name << ") *" << param.name << " = "
         << ScalarToHost(pointee, param.name + "_gslot", "\"" + name + "\", " + std::to_string(i)) << ";\n";
    }
  }
  for (auto &param : signature.params) {
    if (param.value.kind == Kind::Block) {
      hs << "    xl_invoke(XL_GUEST__Block_release, p." << param.name << ");\n";
    }
  }
  if (has_result) {
    if (signature.result.kind == Kind::Record) {
      hs << "    return " << Mirror(signature.result.guest, signature.result.host) << "_to_host(&p.r);\n";
    } else {
      hs << "    return " << ScalarToHost(signature.result, "p.r", "\"" + name + "\", 99") << ";\n";
    }
  }
  hs << "}\n\n";
  host_ += hs.str();
  imp_map_.push_back({name, imp});
  return name;
}

// A lifted guest method whose signature the host<->guest bridge cannot marshal (e.g. a block
// or function-pointer parameter/return) still needs to route for guest->guest sends, where no
// marshalling is required (the block is already a guest block). Emit a UNIQUE host imp per such
// method -- so class_getMethodImplementation returns a distinct value that xl_route maps back to
// the guest imp -- with a body that only traps if a HOST caller actually invokes it (rare).
std::string Generator::StubImpWrapper(uint64_t imp) {
  auto name = "xl_imp_" + std::to_string(counter_++);
  host_ += "static void " + name + "(id self, SEL _cmd) { (void)self; (void)_cmd; xl_unsupported(\"" +
           name + ": host call of a guest method whose signature the bridge cannot marshal\"); }\n\n";
  imp_map_.push_back({name, imp});
  return name;
}

void Generator::EmitClasses(const json::Object &manifest) {
  if (guest_pool_.empty()) {
    CollectMethods(gc_, guest_pool_);
    CollectMethods(hc_, host_pool_);
  }
  std::ostringstream meta;
  auto hex = [](int64_t value) {
    std::ostringstream os;
    os << "0x" << std::hex << value << "u";
    return os.str();
  };
  auto emit_methods = [&](const json::Array *methods, bool class_method, const std::string &symbol,
                          const std::string &superclass_hint, bool implementations = true) -> std::string {
    if (!methods || methods->empty()) {
      return "0";
    }
    std::ostringstream list;
    list << "struct { uint32_t entsize; uint32_t count; struct xl_method_t methods[" << methods->size()
         << "]; } " << symbol << " __attribute__((used, section(\"__DATA,__objc_const\"))) = {12, " << methods->size() << ", {";
    for (auto &item : *methods) {
      auto &method = *item.getAsObject();
      auto selector = method.getString("selector")->str();
      auto types = method.getString("types")->str();
      uint64_t imp = *method.getInteger("imp");
      if (!implementations) {
        std::string error;
        auto described = FromEncoding(types, error);
        list << "{(SEL)" << hex(*method.getInteger("name_address")) << ", \"" << (described.supported ? HostEncoding(described) : types)
             << "\", 0}, ";
        continue;
      }
      Signature signature;
      std::string origin;
      auto guest_types = types;
      guest_types.erase(std::remove_if(guest_types.begin(), guest_types.end(), [](char ch) { return isdigit(static_cast<unsigned char>(ch)); }), guest_types.end());
      if (auto found = guest_pool_.find(std::string(class_method ? "+" : "-") + selector); found != guest_pool_.end()) {
        for (auto guest : found->second) {
          auto key = gc_.getObjCEncodingForMethodDecl(guest);
          key.erase(std::remove_if(key.begin(), key.end(), [](char ch) { return isdigit(static_cast<unsigned char>(ch)); }), key.end());
          if (key != guest_types) {
            continue;
          }
          auto host = Counterpart(guest, host_pool_[std::string(class_method ? "+" : "-") + selector]);
          if (host) {
            signature = FromMethod(guest, host);
            origin = "SDK declaration in " + dyn_cast<NamedDecl>(guest->getDeclContext())->getNameAsString();
            break;
          }
        }
      }
      if (origin.empty()) {
        std::string error;
        signature = FromEncoding(types, error);
        origin = "guest type encoding " + types;
      }
      std::string wrapper;
      std::string host_types;
      if (!signature.supported) {
        Report(std::string(class_method ? "+[" : "-[") + superclass_hint + " " + selector + "]: UNSUPPORTED: " + signature.note);
        ++unsupported_;
        // Still give it a unique imp so guest->guest sends route to the lifted method; only a
        // host->guest call with this signature remains unsupported.
        wrapper = StubImpWrapper(imp);
        host_types = types;
      } else {
        wrapper = ImpWrapper(signature, imp, class_method);
        host_types = HostEncoding(signature);
        Report(std::string(class_method ? "+[" : "-[") + superclass_hint + " " + selector + "]: host IMP from " + origin + " as " + host_types);
      }
      list << "{(SEL)" << hex(*method.getInteger("name_address")) << ", \"" << host_types << "\", (IMP)" << wrapper << "}, ";
    }
    list << "}};\n";
    meta << list.str();
    return "&" + symbol;
  };
  auto emit_ivars = [&](const json::Array *ivars, const std::string &symbol) -> std::string {
    if (!ivars || ivars->empty()) {
      return "0";
    }
    meta << "static struct { uint32_t entsize; uint32_t count; struct xl_ivar_t ivars[" << ivars->size() << "]; } " << symbol
         << " __attribute__((used, section(\"__DATA,__objc_const\"))) = {20, " << ivars->size() << ", {";
    for (auto &item : *ivars) {
      auto &ivar = *item.getAsObject();
      meta << "{(int32_t *)" << hex(*ivar.getInteger("offset_address")) << ", (const char *)" << hex(*ivar.getInteger("name_address"))
           << ", (const char *)" << hex(*ivar.getInteger("type_address")) << ", " << *ivar.getInteger("alignment") << ", "
           << *ivar.getInteger("size") << "}, ";
    }
    meta << "}};\n";
    return "&" + symbol;
  };
  auto emit_properties = [&](const json::Array *properties, const std::string &symbol) -> std::string {
    if (!properties || properties->empty()) {
      return "0";
    }
    meta << "struct { uint32_t entsize; uint32_t count; struct xl_property_t properties[" << properties->size() << "]; } "
         << symbol << " __attribute__((used, section(\"__DATA,__objc_const\"))) = {8, " << properties->size() << ", {";
    for (auto &item : *properties) {
      auto &property = *item.getAsObject();
      meta << "{(const char *)" << hex(*property.getInteger("name_address")) << ", (const char *)"
           << hex(*property.getInteger("attributes_address")) << "}, ";
    }
    meta << "}};\n";
    return "&" + symbol;
  };
  auto protocol_symbol = [&](int64_t address) {
    std::string symbol;
    raw_string_ostream name(symbol);
    name << "xl_guest_protocol_" << format_hex_no_prefix(address, 8);
    name.flush();
    return symbol;
  };
  auto emit_protocol_list = [&](const json::Array *protocols, const std::string &symbol) -> std::string {
    if (!protocols || protocols->empty()) {
      return "0";
    }
    std::string entries;
    for (auto &entry : *protocols) {
      auto target = protocol_symbol(*entry.getAsInteger());
      meta << "extern char " << target << ";\n";
      entries += "&" + target + ", ";
    }
    meta << "struct { uintptr_t count; void *list[" << protocols->size() << "]; } " << symbol
         << " __attribute__((used, section(\"__DATA,__objc_const\"))) = {" << protocols->size() << ", {" << entries << "}};\n";
    return "(void *)&" + symbol;
  };
  std::vector<std::string> classlist, catlist, protolist;
  for (auto &image_value : *manifest.getArray("images")) {
    auto &image = *image_value.getAsObject();
    auto index = std::to_string(*image.getInteger("index"));
    for (auto &error : *image.getArray("errors")) {
      Report("objc metadata: UNSUPPORTED: " + error.getAsString()->str());
      ++unsupported_;
    }
    for (auto &protocol_value : *image.getArray("protocols")) {
      auto &protocol = *protocol_value.getAsObject();
      std::string base;
      {
        raw_string_ostream name(base);
        name << "xl_objc_proto_" << format_hex_no_prefix(*protocol.getInteger("address"), 8) << "_";
      }
      auto hint = protocol.getString("name")->str();
      emit_protocol_list(protocol.getArray("protocols"), base + "protocols");
      emit_methods(protocol.getArray("instance_methods"), false, base + "instance", hint, false);
      emit_methods(protocol.getArray("class_methods"), true, base + "class", hint, false);
      emit_methods(protocol.getArray("optional_instance_methods"), false, base + "optional_instance", hint, false);
      emit_methods(protocol.getArray("optional_class_methods"), true, base + "optional_class", hint, false);
      emit_properties(protocol.getArray("properties"), base + "properties");
      auto target = protocol_symbol(*protocol.getInteger("address"));
      meta << "extern char " << target << ";\n";
      protolist.push_back("&" + target);
    }
    auto classes = image.getArray("classes");
    for (size_t c = 0; c < classes->size(); ++c) {
      auto &cls = *(*classes)[c].getAsObject();
      auto suffix = index + "_" + std::to_string(c);
      for (bool is_meta : {false, true}) {
        auto &data = *cls.getObject(is_meta ? "meta_data" : "data");
        auto base = std::string(is_meta ? "xl_objc_meta_" : "xl_objc_") + suffix;
        auto name = data.getString("name")->str();
        auto methods = emit_methods(data.getArray("methods"), is_meta, base + "_methods", name);
        auto ivars = emit_ivars(data.getArray("ivars"), base + "_ivars");
        auto properties = emit_properties(data.getArray("properties"), base + "_properties");
        auto protocols = emit_protocol_list(data.getArray("protocols"), base + "_protocols");
        meta << "struct xl_class_ro_t " << (is_meta ? "xl_objc_metaro_" : "xl_objc_ro_") << suffix
             << " __attribute__((used, section(\"__DATA,__objc_const\"))) = {" << *data.getInteger("flags") << "u, "
             << *data.getInteger("instance_start") << "u, " << *data.getInteger("instance_size") << "u, 0, (const char *)"
             << hex(*data.getInteger("name_address")) << ", " << methods << ", " << protocols << ", " << ivars << ", 0, "
             << properties << "};\n";
      }
      {
        std::string symbol;
        raw_string_ostream name(symbol);
        name << "xl_guest_class_" << format_hex_no_prefix(*cls.getInteger("address"), 8);
        name.flush();
        meta << "extern char " << symbol << ";\n";
        classlist.push_back("&" + symbol);
      }
      {
        auto &data = *cls.getObject("data");
        auto &super = *cls.getObject("superclass");
        std::string super_host = "0", super_guest = "0";
        if (*super.getString("kind") == "import") {
          auto sym = super.getString("symbol")->str();
          auto n = sym.rfind("_OBJC_CLASS_$_");
          super_host = "\"" + (n == std::string::npos ? sym : sym.substr(n + 14)) + "\"";
        } else if (*super.getString("kind") == "local") {
          super_guest = hex(*super.getInteger("address"));
        }
        std::string offsets = "xl_ivar_fixup_" + suffix;
        auto ivars = data.getArray("ivars");
        meta << "static const struct xl_ivar_fixup " << offsets << "[] = {";
        auto instance_start = *data.getInteger("instance_start");
        for (auto &item : *ivars) {
          auto &iv = *item.getAsObject();
          auto offset = *iv.getInteger("offset_value");
          // An ivar lies at or past its class's instanceStart. Zero is only a real offset at a root
          // class's own start (Swift's root class keeps isa there); anywhere else it means the
          // offset variable was not read from the image.
          if (offset < instance_start) {
            layout_errors_.push_back("class " + data.getString("name")->str() + ": ivar offset " +
                                     std::to_string(offset) + " below instanceStart " +
                                     std::to_string(instance_start) + " (offset not read from image)");
          }
          meta << "{(int32_t *)" << hex(*iv.getInteger("offset_address")) << ", " << offset << "u}, ";
        }
        meta << "{0, 0}};\n";
        layouts_ += "    {&xl_objc_ro_" + suffix + ", " + hex(*cls.getInteger("address")) + ", " + super_host + ", " +
                    super_guest + ", " + std::to_string(*data.getInteger("instance_start")) + "u, " +
                    std::to_string(*data.getInteger("instance_size")) + "u, " + std::to_string(ivars->size()) + ", " +
                    offsets + "},\n";
        ++layout_count_;
      }
    }
    auto categories = image.getArray("categories");
    for (size_t c = 0; c < categories->size(); ++c) {
      auto &category = *(*categories)[c].getAsObject();
      auto suffix = index + "_" + std::to_string(c);
      auto &cls = *category.getObject("class");
      std::string cls_expr;
      if (*cls.getString("kind") == "import") {
        auto symbol = cls.getString("symbol")->str();
        Passthrough(symbol);
        auto ir = symbol.substr(1);
        meta << "extern struct objc_class " << Sanitize(ir) << " __asm(\"_" << ir << "\");\n";
        cls_expr = "&" + Sanitize(ir);
      } else {
        cls_expr = "(Class)" + hex(*cls.getInteger("address"));
      }
      auto hint = category.getString("name")->str();
      auto instance = emit_methods(category.getArray("instance_methods"), false, "xl_objc_category_" + suffix + "_instance", hint);
      auto klass = emit_methods(category.getArray("class_methods"), true, "xl_objc_category_" + suffix + "_class", hint);
      auto properties = emit_properties(category.getArray("properties"), "xl_objc_category_" + suffix + "_properties");
      auto protocols = emit_protocol_list(category.getArray("protocols"), "xl_objc_category_" + suffix + "_protocols");
      meta << "struct xl_category_t xl_objc_category_" << suffix << " __attribute__((used, section(\"__DATA,__objc_const\"))) = {(const char *)"
           << hex(*category.getInteger("name_address")) << ", " << cls_expr << ", " << instance << ", " << klass << ", "
           << protocols << ", " << properties << "};\n";
      catlist.push_back("&xl_objc_category_" + suffix);
    }
    for (auto &selector : *image.getArray("selectors")) {
      auto &entry = *selector.getAsObject();
      init_ += "    *(uint64_t *)(uintptr_t)" + hex(*entry.getInteger("slot")) + " = (uintptr_t)sel_registerName(\"" +
               entry.getString("selector")->str() + "\");\n";
    }
  }
  if (!classlist.empty()) {
    meta << "static Class const xl_objc_classlist[] __attribute__((used, section(\"__DATA,__xlcls,regular,no_dead_strip\"))) = {";
    for (auto &entry : classlist) {
      meta << "(Class)" << entry << ", ";
    }
    meta << "};\n";
  }
  if (!protolist.empty()) {
    meta << "static void *const xl_objc_protolist[] __attribute__((used, section(\"__DATA,__xlproto,regular,no_dead_strip\"))) = {";
    for (auto &entry : protolist) {
      meta << entry << ", ";
    }
    meta << "};\n";
  }
  if (!catlist.empty()) {
    meta << "static struct xl_category_t *const xl_objc_catlist[] __attribute__((used, section(\"__DATA,__xlcat,regular,no_dead_strip\"))) = {";
    for (auto &entry : catlist) {
      meta << entry << ", ";
    }
    meta << "};\n";
  }
  meta << "const struct xl_class_layout xl_class_layouts[] = {\n" << layouts_ << "    {0, 0, 0, 0, 0, 0}};\n";
  // The class objects Swift laid out statically and left out of __objc_classlist: the runtime gives each a host shadow
  // class the first time a message or a call reaches it (runtime/swift_classes.m).
  meta << "const uint32_t xl_swift_static_classes[] = {";
  for (auto &image : *manifest.getArray("images")) {
    for (auto &address : *image.getAsObject()->getArray("swift_static_classes")) {
      meta << hex(*address.getAsInteger()) << ", ";
    }
  }
  meta << "0};\nconst uint32_t xl_swift_listed_classes[] = {";
  for (auto &image : *manifest.getArray("images")) {
    for (auto &address : *image.getAsObject()->getArray("swift_listed_classes")) {
      meta << hex(*address.getAsInteger()) << ", ";
    }
  }
  meta << "0};\n";
  tables_ += meta.str();
}

bool Generator::Write() {
  if (!layout_errors_.empty()) {
    for (auto &e : layout_errors_) errs() << "xlgen: " << e << "\n";
    return false;
  }
  auto includes = MemoryBuffer::getFile(IncludesPath);
  auto abi = MemoryBuffer::getFile(AbiHeader);
  std::error_code ec;
  raw_fd_ostream guest(GuestOut, ec);
  if (ec) {
    errs() << "xlgen: " << GuestOut << ": " << ec.message() << "\n";
    return false;
  }
  guest << (*includes)->getBuffer() << "\n" << (*abi)->getBuffer() << "\n#include <stdarg.h>\n#include <stdint.h>\n\nextern void xl_trap_xl_unsupported(const char *);\n"
        << "extern void _Block_use_RR(void (*)(const void *), void (*)(const void *));\n"
        << "static void xl_block_retain(const void *object) { objc_retain((id)object); }\n"
        << "static void xl_block_release(const void *object) { objc_release((id)object); }\n"
        << "__attribute__((constructor)) static void xl_block_runtime(void) { _Block_use_RR(xl_block_retain, xl_block_release); }\n"
        << "struct xl_host_block { void *isa; int32_t flags; int32_t reserved; void *invoke; void *descriptor; uint64_t host; };\n"
        << "struct xl_host_block_descriptor { unsigned long reserved; unsigned long size; void (*copy)(void *, void *); void (*dispose)(void *); };\n"
        << "extern void xl_trap_xl_host_block_release(uint64_t host);\n"
        << "static void xl_host_block_dispose(void *block) { xl_trap_xl_host_block_release(((struct xl_host_block *)block)->host); }\n\n"
        << guest_record_defs_ << guest_;
  raw_fd_ostream host(HostOut, ec);
  if (ec) {
    errs() << "xlgen: " << HostOut << ": " << ec.message() << "\n";
    return false;
  }
  host << (*includes)->getBuffer() << "\n" << (*abi)->getBuffer() << "\n#include <objc/message.h>\n#include <objc/runtime.h>\n#include \"xl_bridge.h\"\n#include \"xl_host.h\"\n\n";
  host << "#define XL_CALLBACK_COUNT " << std::max<size_t>(1, callbacks_.size()) << "\n";
  host << "uint64_t xl_callback_targets[XL_CALLBACK_COUNT][32];\n\n";
  host << host_record_defs_ << host_types_ << host_ << tables_;
  host << "const struct xl_selector_shim xl_selector_shims[] = {\n";
  for (auto &[selector, macro] : selector_shims_) {
    host << "    {\"" << selector << "\", " << macro << "},\n";
  }
  host << "    {0, 0}};\n";
  host << "const struct xl_selector_variant xl_selector_variants[] = {\n";
  for (auto &[selector, encoding, macro] : selector_variants_) {
    host << "    {\"" << selector << "\", \"" << encoding << "\", " << macro << "},\n";
  }
  host << "    {0, 0, 0}};\n";
  for (auto &[selector, fn] : variadic_shims_) {
    host << "extern void " << fn << "(State *);\n";
  }
  host << "const struct xl_variadic_shim xl_variadic_shims[] = {\n";
  for (auto &[selector, fn] : variadic_shims_) {
    host << "    {\"" << selector << "\", " << fn << "},\n";
  }
  host << "    {0, 0}};\n";
  host << "const struct xl_imp_entry xl_imp_map[] = {\n";
  for (auto &[wrapper, imp] : imp_map_) {
    host << "    {(IMP)" << wrapper << ", " << format_hex(imp, 10) << "u},\n";
  }
  host << "    {0, 0}};\n";
  host << "void xl_bridge_init_generated(void)\n{\n" << init_ << "}\n";
  raw_fd_ostream passthrough(PassthroughOut, ec);
  passthrough << passthrough_.str();
  raw_fd_ostream report(ReportOut, ec);
  report << report_.str();
  errs() << "xlgen: " << unsupported_ << " unsupported items, see " << ReportOut << "\n";
  return true;
}

std::string Framework(ASTContext &context, const Decl *decl) {
  auto &sm = context.getSourceManager();
  auto file = sm.getFilename(sm.getSpellingLoc(decl->getLocation())).str();
  auto at = file.find(".framework/");
  if (at != std::string::npos) {
    auto start = file.rfind('/', at);
    return file.substr(start + 1, at - start - 1);
  }
  if (file.find("/usr/include/") != std::string::npos) {
    return "usr/include";
  }
  return "other";
}

std::string ReasonClass(const std::string &note) {
  if (note.find("union") != std::string::npos) {
    return "union by value or behind a pointer";
  }
  if (note.find("whose layout differs") != std::string::npos) {
    return "pointer to data whose layout differs (needs a per-API rule)";
  }
  if (note.find("block result") != std::string::npos) {
    return "returns a block";
  }
  if (note.find("unsupported kind") != std::string::npos) {
    return "returns an out pointer, array or callback";
  }
  return "other: " + note.substr(0, 60);
}

class LayoutLeakFinder : public RecursiveASTVisitor<LayoutLeakFinder> {
 public:
  LayoutLeakFinder(ASTContext &gc, ASTContext &hc) : gc_(gc), hc_(hc) {}
  bool VisitMemberExpr(MemberExpr *expr) {
    // getMemberDecl() can be null (e.g. an unresolved member in some SDK headers); plain
    // dyn_cast asserts on a null input, so tolerate it with dyn_cast_or_null.
    auto field = dyn_cast_or_null<FieldDecl>(expr->getMemberDecl());
    if (!field) {
      return true;
    }
    auto record = field->getParent();
    if (!record->getIdentifier()) {
      return true;
    }
    for (auto decl : hc_.getTranslationUnitDecl()->lookup(DeclarationName(&hc_.Idents.get(record->getName())))) {
      if (auto host = dyn_cast<RecordDecl>(decl)) {
        std::set<const Decl *> seen;
        if (host->getDefinition() &&
            !SameLayout(gc_, gc_.getCanonicalTagType(record), hc_, hc_.getCanonicalTagType(host), seen)) {
          leaks = true;
        }
      }
    }
    return true;
  }
  bool leaks = false;

 private:
  ASTContext &gc_;
  ASTContext &hc_;
};

void Generator::Survey(raw_ostream &os) {
  struct Tally {
    unsigned plain = 0, converted = 0, formatted = 0, variadic = 0, unsupported = 0, missing_host = 0, inline_leaks = 0,
             inline_total = 0;
    std::map<std::string, unsigned> reasons;
    std::map<std::string, unsigned> conversions;
  };
  std::map<std::string, Tally> functions, methods;
  auto record_conversions = [](Tally &tally, const Signature &signature) {
    bool converted = false;
    std::set<std::string> seen;
    auto note = [&](const Value &value) {
      const char *name = nullptr;
      switch (value.kind) {
        case Kind::Record: name = "struct by value"; break;
        case Kind::OutSlot: name = "out pointer to a scalar or object"; break;
        case Kind::RecordPointer: name = "pointer to a struct (copied in, and out unless const)"; break;
        case Kind::Array: name = "counted array of scalars or objects"; break;
        case Kind::Block: name = "block"; break;
        case Kind::Callback: name = "function pointer callback"; break;
        default: break;
      }
      if (name) {
        converted = true;
        if (seen.insert(name).second) {
          ++tally.conversions[name];
        }
      }
    };
    for (auto &param : signature.params) {
      note(param.value);
    }
    note(signature.result);
    return converted;
  };
  for (auto decl : gc_.getTranslationUnitDecl()->decls()) {
    auto function = dyn_cast<FunctionDecl>(decl);
    if (!function || function->getBuiltinID()) {
      continue;
    }
    auto framework = Framework(gc_, function);
    if (framework == "other") {
      continue;
    }
    auto &tally = functions[framework];
    if (function->hasBody()) {
      ++tally.inline_total;
      LayoutLeakFinder finder(gc_, hc_);
      finder.TraverseDecl(function);
      tally.inline_leaks += finder.leaks;
      continue;
    }
    FunctionDecl *host = nullptr;
    for (auto candidate : hc_.getTranslationUnitDecl()->lookup(DeclarationName(&hc_.Idents.get(function->getName())))) {
      host = host ? host : dyn_cast<FunctionDecl>(candidate);
    }
    if (!host || host->getNumParams() != function->getNumParams()) {
      ++tally.missing_host;
      continue;
    }
    if (function->isVariadic()) {
      (function->hasAttr<FormatAttr>() ? tally.formatted : tally.variadic)++;
      continue;
    }
    auto signature = FromFunction(function, host);
    if (!signature.supported) {
      ++tally.unsupported;
      ++tally.reasons[ReasonClass(signature.note)];
    } else if (record_conversions(tally, signature)) {
      ++tally.converted;
    } else {
      ++tally.plain;
    }
  }
  CollectMethods(gc_, guest_pool_);
  CollectMethods(hc_, host_pool_);
  std::set<ObjCMethodDecl *> visited;
  for (auto &[key, list] : guest_pool_) {
    if (key[0] != '*') {
      continue;
    }
    for (auto method : list) {
      if (!visited.insert(method).second) {
        continue;
      }
      auto framework = Framework(gc_, method);
      auto &tally = methods[framework];
      auto host = Counterpart(method, host_pool_[key]);
      if (!host) {
        ++tally.missing_host;
        continue;
      }
      if (method->isVariadic()) {
        (method->hasAttr<FormatAttr>() ? tally.formatted : tally.variadic)++;
        continue;
      }
      auto signature = FromMethod(method, host);
      if (!signature.supported) {
        ++tally.unsupported;
        ++tally.reasons[ReasonClass(signature.note)];
      } else if (record_conversions(tally, signature)) {
        ++tally.converted;
      } else {
        ++tally.plain;
      }
    }
  }
  auto dump = [&](const char *title, std::map<std::string, Tally> &tallies) {
    Tally total;
    os << "== " << title << "\n";
    os << format("%-24s %7s %9s %9s %8s %11s %12s %8s %8s\n", "framework", "plain", "converted", "formatted", "variadic",
                 "unsupported", "no-host-decl", "inline", "leaking");
    for (auto &[framework, tally] : tallies) {
      os << format("%-24s %7u %9u %9u %8u %11u %12u %8u %8u\n", framework.c_str(), tally.plain, tally.converted,
                   tally.formatted, tally.variadic, tally.unsupported, tally.missing_host, tally.inline_total,
                   tally.inline_leaks);
      total.plain += tally.plain;
      total.converted += tally.converted;
      total.formatted += tally.formatted;
      total.variadic += tally.variadic;
      total.unsupported += tally.unsupported;
      total.missing_host += tally.missing_host;
      total.inline_total += tally.inline_total;
      total.inline_leaks += tally.inline_leaks;
      for (auto &[reason, count] : tally.reasons) {
        total.reasons[reason] += count;
      }
      for (auto &[kind, count] : tally.conversions) {
        total.conversions[kind] += count;
      }
    }
    os << format("%-24s %7u %9u %9u %8u %11u %12u %8u %8u\n", "TOTAL", total.plain, total.converted, total.formatted,
                 total.variadic, total.unsupported, total.missing_host, total.inline_total, total.inline_leaks);
    os << "conversions needed (declarations using each):\n";
    for (auto &[kind, count] : total.conversions) {
      os << "  " << count << "  " << kind << "\n";
    }
    os << "unsupported by reason:\n";
    std::vector<std::pair<unsigned, std::string>> sorted;
    for (auto &[reason, count] : total.reasons) {
      sorted.push_back({count, reason});
    }
    std::sort(sorted.rbegin(), sorted.rend());
    for (auto &[count, reason] : sorted) {
      os << "  " << count << "  " << reason << "\n";
    }
  };
  dump("C functions", functions);
  dump("Objective-C methods (declarations, properties included)", methods);
}

}  // namespace

int main(int argc, const char **argv) {
  cl::ParseCommandLineOptions(argc, argv, "xlgen");
  auto includes = MemoryBuffer::getFile(IncludesPath);
  auto abi = MemoryBuffer::getFile(AbiHeader);
  if (!includes || !abi) {
    errs() << "xlgen: cannot read inputs\n";
    return 1;
  }
  std::string code = (*includes)->getBuffer().str() + "\n" + (*abi)->getBuffer().str();
  auto guest_ast = Parse(code, GuestTarget);
  auto host_ast = Parse(code, HostTarget);
  if (!guest_ast || !host_ast) {
    errs() << "xlgen: parsing failed\n";
    return 1;
  }
  auto &gc = guest_ast->getASTContext();
  auto &hc = host_ast->getASTContext();
  Generator generator(gc, hc);
  if (!SurveyOut.empty()) {
    std::error_code ec;
    raw_fd_ostream os(SurveyOut, ec);
    generator.Survey(os);
    return 0;
  }
  auto provided = ReadLines(GuestProvidedPath);
  for (auto &symbol : ReadLines(WeakOnlyPath)) {
    generator.weak_only_.insert(symbol);
  }
  static const std::map<std::string, std::string> trampolines = {
      {"_objc_msgSend", "objc_msgSend"}, {"_objc_msgSendSuper2", "objc_msgSendSuper2"}};
  static const std::map<std::string, unsigned> weak_functions = {
      {"_objc_initWeak", 2}, {"_objc_storeWeak", 2}, {"_objc_destroyWeak", 1}, {"_objc_loadWeakRetained", 1},
      {"_objc_loadWeak", 1}, {"_objc_copyWeak", 2}, {"_objc_moveWeak", 2},
      {"_objc_autoreleaseReturnValue", 1}, {"_objc_retainAutoreleasedReturnValue", 1},
      {"_objc_retainAutoreleaseReturnValue", 1}, {"_objc_unsafeClaimAutoreleasedReturnValue", 1},
      {"_objc_claimAutoreleasedReturnValue", 1}, {"_objc_retainBlock", 1},
      {"_objc_retain", 1}, {"_objc_release", 1}, {"_objc_autorelease", 1},
      // C++ ABI destructor registration: the guest destructor is guest code, so it goes
      // through a manual bridge that hands the runtime the guest slot to invoke, rather
      // than letting the host C++ runtime call a guest address at exit.
      {"___cxa_atexit", 3},
      // C++ ABI operator new / new[] / delete / delete[] -> host allocator.
      {"__Znwm", 1}, {"__Znam", 1}, {"__ZdlPv", 1}, {"__ZdaPv", 1},
      // Returns a function pointer (unbridgeable result kind). A fresh process has no prior
      // handler installed by the guest, so return NULL; the runtime's own uncaught handler
      // still fires. (Interim; a faithful set/get pair would store and return the guest slot.)
      {"_NSGetUncaughtExceptionHandler", 0},
      // changelist/eventlist are arrays of struct kevent sized by nchanges/nevents; the auto
      // bridge marshals only the first element, so a multi-change call (Realm registers two read
      // filters at once) passes garbage for the rest and the registration fails. Marshal every
      // element by hand using the count arguments.
      {"_kevent", 6},
      // zlib: the guest z_stream layout differs from the host's, and zlib's internal back-pointer to the
      // stream forbids marshalling it by copy -- each guest stream gets one persistent host mirror (see
      // bridge.m). Arity = the declared parameter count.
      {"_inflateInit_", 3}, {"_inflateInit2_", 4}, {"_deflateInit_", 4}, {"_deflateInit2_", 8},
      {"_inflate", 2}, {"_deflate", 2}, {"_inflateEnd", 1}, {"_deflateEnd", 1},
      {"_inflateReset", 1}, {"_deflateReset", 1},
      // utimensat takes an ARRAY of two timespecs; readdir returns a struct dirent whose layout differs
      // (32-bit inode on iOS 6); signal returns a function pointer. Hand-written in bridge.m.
      {"_utimensat", 4}, {"_readdir", 1}, {"_signal", 2},
      // Failed assert(): log the assertion text to the crash log (stderr is unreachable under SpringBoard).
      {"___assert_rtn", 4},
      // exit/_exit: log the guest call chain first (a silent voluntary exit is undiagnosable otherwise).
      {"_exit", 1}, {"__exit", 1},
      // objc runtime "copy" calls returning a malloc'd array of pointers (widened to the guest's 64-bit slots).
      {"_objc_copyImageNames", 1}, {"_objc_copyClassNamesForImage", 2}, {"_objc_copyClassList", 1},
      // The registration calls the Swift runtime makes for its classes, which iOS 6 libobjc does not have: the runtime
      // builds a host shadow class from the guest class (runtime/swift_classes.m).
      {"_objc_readClassPair", 2}, {"__objc_realizeClassFromSwift", 2}, {"_class_getImageName", 1}};
  static const std::set<std::string> faults = {"__Unwind_Resume", "___objc_personality_v0", "___gxx_personality_v0",
                                               "___cxa_throw", "_objc_exception_throw"};
  for (auto &symbol : ReadLines(SymbolsPath)) {
    if (provided.count(symbol) || symbol == "dyld_stub_binder") {
      continue;
    }
    if (StringRef(symbol).starts_with("_OBJC_CLASS_$_") || StringRef(symbol).starts_with("_OBJC_METACLASS_$_") ||
        symbol == "__objc_empty_cache" || symbol == "___CFConstantStringClassReference") {
      generator.Passthrough(symbol);
      continue;
    }
    if (static const std::set<std::string> exec_family = {"_execl", "_execle", "_execlp", "_execv", "_execve", "_execvp", "_execvP"};
        exec_family.count(symbol)) {
      generator.EmitExec(symbol);
      continue;
    }
    if (auto trampoline = trampolines.find(symbol); trampoline != trampolines.end()) {
      generator.EmitTrampoline(symbol, trampoline->second);
      continue;
    }
    if (symbol == "__tlv_bootstrap") {
      generator.EmitTlvBootstrap();
      continue;
    }
    if (symbol == "_objc_setHook_lazyClassNamer") {
      generator.EmitLazyClassNamer(symbol);
      continue;
    }
    if (symbol == "_objc_setHook_getImageName") {
      generator.EmitImageNameHook(symbol);
      continue;
    }
    if (auto weak = weak_functions.find(symbol); weak != weak_functions.end()) {
      generator.EmitManualFunction(symbol, weak->second, "xl_manual_" + symbol.substr(1));
      continue;
    }
    if (faults.count(symbol)) {
      generator.Fault(symbol, "exception unwinding across translated code is not implemented");
      continue;
    }
    // Empty collection literals: since clang 12 `@[]` / `@{}` compile to a load of the extern
    // singletons ___NSArray0__ / ___NSDictionary0__ (exported by newer CoreFoundation, absent from iOS 6
    // and from the SDK headers). Left unresolved the guest reads garbage and passes it as "the empty
    // dictionary" (iSH: createDirectoryAtURL:...attributes:@{} aborted the narrowing guard). Own them
    // guest-side: a guest variable at the symbol, filled at startup with a real empty immutable
    // collection, which is exactly what those singletons are.
    static const std::map<std::string, std::string> empty_singletons = {
        {"___NSArray0__", "NSArray"}, {"___NSDictionary0__", "NSDictionary"}};
    if (auto singleton = empty_singletons.find(symbol); singleton != empty_singletons.end()) {
      generator.EmitEmptyCollectionSingleton(symbol, singleton->second);
      continue;
    }
    if (symbol[0] != '_') {
      generator.Report(symbol + ": UNSUPPORTED: symbol without a C name");
      continue;
    }
    auto name = symbol.substr(1);
    // A libSystem symbol can carry a $VARIANT suffix (realpath$DARWIN_EXTSN, ...) that only selects an
    // ABI flavour of the same C function; the SDK declares the plain name. Resolve the declaration by the
    // base name, but keep the full symbol as the guest export so the app's import still binds to it.
    generator.variant_alias_.clear();
    if (auto dollar = name.find('$'); dollar != std::string::npos && dollar > 0) {
      generator.variant_alias_ = name;
      name = name.substr(0, dollar);
    }
    FunctionDecl *gf = nullptr, *hf = nullptr;
    VarDecl *gv = nullptr, *hv = nullptr;
    for (auto decl : gc.getTranslationUnitDecl()->lookup(DeclarationName(&gc.Idents.get(name)))) {
      gf = gf ? gf : dyn_cast<FunctionDecl>(decl);
      gv = gv ? gv : dyn_cast<VarDecl>(decl);
    }
    for (auto decl : hc.getTranslationUnitDecl()->lookup(DeclarationName(&hc.Idents.get(name)))) {
      hf = hf ? hf : dyn_cast<FunctionDecl>(decl);
      hv = hv ? hv : dyn_cast<VarDecl>(decl);
    }
    if (gf && hf) {
      generator.EmitFunction(symbol, gf->getMostRecentDecl(), hf->getMostRecentDecl());
    } else if (gv && hv) {
      generator.EmitVariable(symbol, gv->getMostRecentDecl(), hv->getMostRecentDecl());
    } else {
      generator.Fault(symbol, "no declaration in the SDK headers");
    }
  }
  if (!ManifestPath.empty()) {
    auto buffer = MemoryBuffer::getFile(ManifestPath);
    auto parsed = buffer ? json::parse((*buffer)->getBuffer()) : Expected<json::Value>(createStringError("unreadable"));
    if (!parsed) {
      errs() << "xlgen: " << ManifestPath << ": " << toString(parsed.takeError()) << "\n";
      return 1;
    }
    auto &manifest = *parsed->getAsObject();
    std::set<std::string> selectors, guest_selectors;
    for (auto &image : *manifest.getArray("images")) {
      for (auto &selref : *image.getAsObject()->getArray("selectors")) {
        selectors.insert(selref.getAsObject()->getString("selector")->str());
      }
      for (auto &cls : *image.getAsObject()->getArray("classes")) {
        for (auto *key : {"data", "meta_data"}) {
          for (auto &method : *cls.getAsObject()->getObject(key)->getArray("methods")) {
            guest_selectors.insert(method.getAsObject()->getString("selector")->str());
          }
        }
      }
    }
    generator.EmitSelectors(selectors, guest_selectors);
    generator.EmitClasses(manifest);
  }
  return generator.Write() ? 0 : 1;
}
