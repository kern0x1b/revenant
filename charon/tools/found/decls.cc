// The declarations of one framework, from clang's own AST through libclang: the source of the spec's Objective-C and C facts.
//
// usage: decls --version | --target | --digest TEXT | --list
//        decls [--doc] [--timeout SECONDS] <framework>
// The SDK is IR_SDK. <framework> is a name --list prints: a framework of System/Library/Frameworks or System/Library/SubFrameworks (a nested
// one is Outer/Inner), or a usr/include module the module maps declare (the sweep covers every one), a Swift module of usr/lib/swift that
// names no framework (no C header: its rows are an unparsed reason), or a framework of Developer/Library/Frameworks. decls resolves the
// framework's headers itself, from its module map, by the rule of ir.lua's sweep (module_headers below): the sweep and the doc mode share
// that one code path. A framework's headers become one
// unsaved buffer of #import lines; a usr/include module is imported as the module its own map declares (-fmodule-map-file, -fmodules,
// @import), so the module build compiles its headers as the SDK does. Nothing is written to disk. IR_RESOURCE, if set, is the
// compiler's resource directory (default: libclang's). IR_FRAMEWORKS, if set, is a root shaped like System/Library (Frameworks/ and
// SubFrameworks/ under it) that the frameworks are read from instead of the SDK's; the SDK stays the sysroot. IR_TARGET, if set, is the
// triple the headers are parsed for (armv7-apple-ios6.1.3 for the port's values); the SDK's target otherwise.
// A framework's own declarations are those under its Headers/; a usr/include module's are those written in the directories of its
// headers, or in its header when that header is in the include root (the root holds other modules' headers). --target prints the target
// the rows are compiled for.
// No reviewed list is read here: every usr/include module a module map declares is swept, and every framework is read by its own
// folder. A framework with no module-map header is read from its Headers/ folder (the umbrella header, else every header there), and a
// framework with no header at all is an unparsed row.
//
// --doc (the doc-time mode, for the doc generator): the same pass and the same keys, but the output is one row per declaration
// with ten cells instead of the IR's rows: framework, kind, usr, container, name, side (the IR's own values), the parameter names
// (separated by " | "), the brief of the doc comment and its raw text as clang parses them (libclang's brief and raw comment text),
// and the declaration as written. Each cell is escaped (a backslash, a tab, a line feed and a carriage return as \\, \t, \n, \r),
// so a declaration is one line; an empty cell has no such text. Nothing is written to a file, no IR row, conflict or census is
// written, and a module that does not parse is an error (status 1, its count on stderr, no output).
//
// The preprocessor evaluates every #if (TARGET_OS_*, __has_feature, availability macros) the way the iOS compile does, so the
// AST holds the declarations of the iOS branch and nothing else. A declaration is emitted when its spelling location (or, for a
// macro, its expansion) is under <framework-root>/Headers.
//
// Output: one TSV row per declaration on stdout, 21 columns: the 16 of design-foundation.md section 5.1, the declaration as written
// (decl, display only: it is not part of any hash), the availability texts (message), and three facts the headers renderer reads
// and the shards do not keep (typeparams: a generic class's or category's type parameters, name:bound, in order; anon: a field's
// anonymous struct or union, by USR; category: the category a conforms row is written in). The three are not in the declaration hash.
// A declaration that is repeated in the framework is resolved here (the rule of section 5.2 and ruling D3): the availability of the
// defining declaration counts, a forward declaration never does, a category's own availability overrides the class's only when it is
// later. A key whose declarations still disagree is written as a row of kind conflict and all its variants follow as rows: ir.lua
// merges them by the rule of avail.lua.
// "--digest TEXT" prints the availability hash of a text, the one the rows carry.
// The rows are written only when the parse has no error diagnostic: a header that does not parse yields one unparsed row, with the
// first diagnostic as its reason. Exit status 1 is a usage or parse failure; a timeout ends the process by SIGALRM.
#include <clang-c/Index.h>
#include <CommonCrypto/CommonDigest.h>

#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <cctype>
#include <cstdio>
#include <dlfcn.h>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <map>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>

namespace {

std::string text(CXString s) {
  const char* c = clang_getCString(s);
  std::string out = c ? c : "";
  clang_disposeString(s);
  return out;
}

// A TSV cell: a tab or a line break inside a cell would split the row, so each becomes a space.
std::string cell(std::string s) {
  for (char& ch : s) {
    if (ch == '\t' || ch == '\n' || ch == '\r') ch = ' ';
  }
  return s;
}

// An empty cell is "-": a class extension has no name, and "-" is what the IR writes for "none".
std::string filled(std::string s) {
  return s.empty() ? "-" : s;
}

std::string version(CXVersion v) {
  if (v.Major == -1) return "-";
  char buf[64];
  // a version written as ios(16) has no minor part: clang reports the minor as -1
  if (v.Minor == -1) std::snprintf(buf, sizeof buf, "%d", v.Major);
  else if (v.Subminor == -1) std::snprintf(buf, sizeof buf, "%d.%d", v.Major, v.Minor);
  else std::snprintf(buf, sizeof buf, "%d.%d.%d", v.Major, v.Minor, v.Subminor);
  return buf;
}

// platform=introduced/deprecated/obsoleted/unavailable, for every platform clang has a record for.
// The availability of a declaration as libclang reports it: the two flags, the two messages, and one record per platform. The records
// are sized from the count clang reports (a first call gives the count; there is no fixed array, so none is dropped: review F24), and
// they are disposed when this goes out of scope.
struct PlatformAvailability {
  int always_deprecated = 0, always_unavailable = 0;
  std::string deprecated_message, unavailable_message;
  std::vector<CXPlatformAvailability> records;
  PlatformAvailability() = default;
  PlatformAvailability(PlatformAvailability&& other) noexcept
      : always_deprecated(other.always_deprecated), always_unavailable(other.always_unavailable),
        deprecated_message(std::move(other.deprecated_message)), unavailable_message(std::move(other.unavailable_message)),
        records(std::move(other.records)) {
    other.records.clear();
  }
  PlatformAvailability(const PlatformAvailability&) = delete;
  PlatformAvailability& operator=(const PlatformAvailability&) = delete;
  ~PlatformAvailability() {
    for (CXPlatformAvailability& r : records) clang_disposeCXPlatformAvailability(&r);
  }
};

// The room of the first call: a declaration carries one to four platform records, and the few with more are asked again below.
constexpr size_t FIRST_PLATFORM_RECORDS = 8;

PlatformAvailability platform_availability(CXCursor c) {
  PlatformAvailability out;
  // one call with room for the usual records; a declaration with more is asked again with room for exactly the count it reports.
  // (A call with no room reports a count that the filled array does not match, so the array is the one that is read.) Clang knows
  // fourteen distinct platforms (measured: seventeen spellings of them in Fixture's FXManyPlatforms give fourteen records), so the
  // second call is made for such a declaration only, and the extractor suite takes that path with it.
  out.records.resize(FIRST_PLATFORM_RECORDS);
  CXString deprecated, unavailable;
  int n = clang_getCursorPlatformAvailability(c, &out.always_deprecated, &deprecated, &out.always_unavailable, &unavailable,
                                              out.records.data(), (int)out.records.size());
  out.deprecated_message = text(deprecated);
  out.unavailable_message = text(unavailable);
  if (n > (int)out.records.size()) {
    for (CXPlatformAvailability& r : out.records) clang_disposeCXPlatformAvailability(&r);
    out.records.assign((size_t)n, CXPlatformAvailability());
    CXString deprecated2, unavailable2;
    n = clang_getCursorPlatformAvailability(c, &out.always_deprecated, &deprecated2, &out.always_unavailable, &unavailable2,
                                            out.records.data(), n);
    clang_disposeString(deprecated2);
    clang_disposeString(unavailable2);
  }
  out.records.resize(n > 0 ? (size_t)n : 0);
  return out;
}

std::string availability(CXCursor c) {
  PlatformAvailability pa = platform_availability(c);
  const int always_deprecated = pa.always_deprecated, always_unavailable = pa.always_unavailable;
  const std::vector<CXPlatformAvailability>& records = pa.records;
  int count = (int)records.size();
  // the platforms in name order: each entry begins with its platform name and '=', which sorts as the name does
  std::vector<std::string> entries;
  for (int i = 0; i < count; ++i) {
    // the record owns its platform string: it is read here and released by clang_disposeCXPlatformAvailability below
    entries.push_back(std::string(clang_getCString(records[i].Platform)) + "=" + version(records[i].Introduced) + "/" +
                      version(records[i].Deprecated) + "/" + version(records[i].Obsoleted) + "/" +
                      (records[i].Unavailable ? "1" : "0"));
  }
  std::sort(entries.begin(), entries.end());
  std::string out;
  if (always_unavailable) out += "*unavailable";
  if (always_deprecated) out += std::string(out.empty() ? "" : " ") + "*deprecated";
  for (size_t i = 0; i < entries.size(); ++i) {
    out += (out.empty() ? "" : i == 0 ? " " : ",") + entries[i];
  }
  return out.empty() ? "-" : out;
}

// The iOS introduction of a declaration as major * 10000 + minor * 100 + subminor; 0 when it names no iOS version.
int introduced_ios(CXCursor c) {
  PlatformAvailability pa = platform_availability(c);
  const std::vector<CXPlatformAvailability>& records = pa.records;
  int intro = 0;
  int count = (int)records.size();
  for (int i = 0; i < count; ++i) {
    const CXVersion& v = records[i].Introduced;
    if (std::strcmp(clang_getCString(records[i].Platform), "ios") == 0 && v.Major != -1) {
      intro = v.Major * 10000 + (v.Minor < 0 ? 0 : v.Minor) * 100 + (v.Subminor < 0 ? 0 : v.Subminor);
    }
  }
  return intro;
}

// n = nonnull, l = nullable, u = unspecified, L = nullable result, - = no nullability written
std::string nullability(CXType t) {
  switch (clang_Type_getNullability(t)) {
    case CXTypeNullability_NonNull: return "n";
    case CXTypeNullability_Nullable: return "l";
    case CXTypeNullability_Unspecified: return "u";
    case CXTypeNullability_NullableResult: return "L";
    default: return "-";
  }
}

// The name of a declaration. An anonymous enum, struct or union has none in the header; libclang spells it with the location of
// its declaration in some versions and not in others, so it is "-" in every version.
std::string declared_name(CXCursor c) {
  if (clang_Cursor_isAnonymous(c)) return "-";
  return text(clang_getCursorSpelling(c));
}

// The type without the nullability written on it, which the nullability column holds. The parse keeps the attributed type of a written
// nullability (CXTranslationUnit_IncludeAttributedTypes); its modified type is the type the spelling names. An instancetype is also
// attributed, but it has no nullability, so it keeps its spelling.
CXType unqualified(CXType t) {
  while (t.kind == CXType_Attributed && clang_Type_getNullability(t) != CXTypeNullability_Invalid) t = clang_Type_getModifiedType(t);
  return t;
}

// clang spells an anonymous type with its location and sometimes its kind: "enum (unnamed at /abs/path/NSString.h:68:1)",
// "union (unnamed union at /abs/path/...)", and "union (unnamed)" in another version. The location is the host's SDK path and a
// line of the header, and the words inside the parentheses differ between versions, so every anonymous type is spelled
// "(unnamed)" (or "(anonymous)"); the kind outside the parentheses is kept.
std::string without_location(std::string s) {
  for (const char* open : {"(unnamed", "(anonymous"}) {
    for (size_t at = s.find(open); at != std::string::npos; at = s.find(open, at + 1)) {
      size_t close = s.find(')', at);
      if (close == std::string::npos) break;
      s.replace(at, close - at + 1, std::string(open) + ")");
    }
  }
  return s;
}

std::string spelled(CXType t) { return without_location(text(clang_getTypeSpelling(unqualified(t)))); }

// The name of the macro clang prints in front of a type it keeps as a macro-qualified type (CF_REFINED_FOR_SWIFT CFStringRef, API_AVAILABLE
// NSString *const): a leading word of capitals, then the type. A type name is not all capitals followed by a type, and clang prints a
// const after such a macro, never before it.
std::string without_macro_word(std::string s) {
  // a const can come before the macro (const NS_SWIFT_NAME  const T: the macro's spaces go with it), and the const is kept once
  std::string lead = s.compare(0, 6, "const ") == 0 ? "const " : "";
  s = s.substr(lead.size());
  auto joined = [&lead](const std::string& t) {
    return lead.empty() || t.compare(0, 6, "const ") == 0 ? t : lead + t;
  };
  for (;;) {
    size_t space = s.find(' ');
    if (space == std::string::npos || space < 2 || s.size() == space + 1) return joined(s);
    bool macro = true;
    for (size_t i = 0; i < space && macro; ++i) {
      unsigned char ch = (unsigned char)s[i];
      macro = std::isupper(ch) || std::isdigit(ch) || ch == '_';
    }
    size_t word = s.find_first_not_of(' ', space);
    if (word == std::string::npos) return joined(s);
    unsigned char next = (unsigned char)s[word];
    if (!macro || !(std::isalpha(next) || next == '_')) return joined(s);
    s = s.substr(word);  // a macro can stand in front of another (NS_RETURNS_RETAINED NS_RETURNS_RETAINED id<T>)
  }
}

// The type of a declared variable or field, as the declaration has it. clang prints attribute sugar in front of the type (an
// availability macro such as API_AVAILABLE, a Swift attribute, the nullability word after it), and that sugar can drop the top-level
// const: CG_EXTERN const CFStringRef __nonnull kCGContentAverageLightLevel prints as CF_REFINED_FOR_SWIFT CFStringRef, though the
// variable is const. So the attributes are taken off, and the const is read from the canonical type (every top-level qualifier
// of the declared type is in it), not from the printed sugar. The nullability column holds the nullability; a pointer's const follows the star.
std::string declared_type(CXType t) {
  // instancetype is an attributed type whose spelling is the keyword (its nullability, if any, is in the nullability column)
  std::string printed = text(clang_getTypeSpelling(t));
  if (printed.compare(0, 12, "instancetype") == 0) return "instancetype";
  CXType bare = t;
  while (bare.kind == CXType_Attributed) bare = clang_Type_getModifiedType(bare);
  std::string s = text(clang_getTypeSpelling(bare));
  if (bare.kind == CXType_Unexposed) s = without_macro_word(s);
  // the canonical type keeps every qualifier the variable has at its top level; the printed sugar can drop one
  if (clang_isConstQualifiedType(clang_getCanonicalType(t))) {
    bool leading = s.compare(0, 6, "const ") == 0;
    bool trailing = s.size() >= 5 && s.compare(s.size() - 5, 5, "const") == 0;
    if (!leading && !trailing && !s.empty()) s = s.back() == '*' ? s + "const" : "const " + s;
  }
  return without_location(s);
}

// The type of a function as its declaration has it: the result as declared_type gives it, then the rest of the function type as clang
// spells it (the parameters). The macro in front of a result is the result's sugar, so the result is taken apart and the rest kept.
// A function type spelled from its declared parts: the result, the marker ("" for a function, ((^)) for a block, the form clang prints),
// and the parameters, each as declared_type gives it. A function with no prototype is spelled as clang spells it.
std::string function_spelling(CXType fn, const char* marker) {
  int n = clang_getNumArgTypes(fn);
  if (n < 0) return without_location(text(clang_getTypeSpelling(fn)));
  bool variadic = clang_isFunctionTypeVariadic(fn) != 0;
  std::string out = declared_type(clang_getResultType(fn)) + " " + marker + "(";
  for (int i = 0; i < n; ++i) {
    if (i) out += ", ";
    out += declared_type(clang_getArgType(fn, (unsigned)i));
  }
  if (variadic) out += n ? ", ..." : "...";
  if (n == 0 && !variadic) out += "void";
  return without_location(out + ")");
}

std::string declared_function_type(CXType fn) { return function_spelling(fn, ""); }

// The underlying type of a typedef: a block pointer's function type is spelled with the block marker, anything else is declared_type.
std::string declared_underlying_type(CXType t) {
  CXType bare = t;
  while (bare.kind == CXType_Attributed) bare = clang_Type_getModifiedType(bare);
  if (bare.kind == CXType_BlockPointer) return function_spelling(clang_getPointeeType(bare), "((^))");
  return declared_type(t);
}

// The offset in its file of a source location (the expansion, for a token a macro produced).
unsigned offset_of(CXSourceLocation loc) {
  CXFile file;
  unsigned line = 0, column = 0, offset = 0;
  clang_getExpansionLocation(loc, &file, &line, &column, &offset);
  return offset;
}

// A token of a declaration as written: its spelling, its offsets in the file, and whether it is a string literal.
struct Token {
  std::string spelling;
  unsigned start, end;
  bool literal;
};

// The tokens of a declaration's extent, comments left out. clang splits an Objective-C directive into "@" and its word ("@" "end"):
// the two are one token when they touch.
std::vector<Token> tokens_of(CXTranslationUnit tu, CXCursor c) {
  CXToken* tokens = nullptr;
  unsigned count = 0;
  clang_tokenize(tu, clang_getCursorExtent(c), &tokens, &count);
  std::vector<Token> toks;
  for (unsigned i = 0; i < count; ++i) {
    if (clang_getTokenKind(tokens[i]) == CXToken_Comment) continue;
    CXSourceRange extent = clang_getTokenExtent(tu, tokens[i]);
    Token t{text(clang_getTokenSpelling(tu, tokens[i])), offset_of(clang_getRangeStart(extent)),
            offset_of(clang_getRangeEnd(extent)), clang_getTokenKind(tokens[i]) == CXToken_Literal};
    if (!toks.empty() && toks.back().spelling == "@" && toks.back().end == t.start) {
      toks.back().spelling += t.spelling;
      toks.back().end = t.end;
      toks.back().literal = false;
      continue;
    }
    toks.push_back(t);
  }
  clang_disposeTokens(tu, tokens, count);
  return toks;
}

// The tokens of a variable as written: from its first token through the attribute macros after its name (NS_AVAILABLE_IOS(8_0),
// API_AVAILABLE(...)), which clang's extent leaves out, to the ';' that ends it. A variable a macro declares (FOUNDATION_EXPORT) has an
// extent inside the macro's expansion, which clang_tokenize reads as no tokens at all: its range runs from the expansion site to the same
// ';' in the file it is written in, read from that file. Empty when no ';' ends the declaration at the top level (a body or a brace).
std::vector<Token> variable_tokens(CXTranslationUnit tu, CXCursor c) {
  static std::map<std::string, std::string> files;  // a header is read once per run, however many variables it declares
  CXSourceRange extent = clang_getCursorExtent(c);
  CXFile file = nullptr, end_file = nullptr;
  unsigned line = 0, column = 0, begin = 0, finish = 0;
  clang_getExpansionLocation(clang_getRangeStart(extent), &file, &line, &column, &begin);
  clang_getExpansionLocation(clang_getRangeEnd(extent), &end_file, &line, &column, &finish);
  if (file == nullptr || file != end_file) return {};
  std::string path = text(clang_getFileName(file));
  auto cached = files.find(path);
  if (cached == files.end()) {
    std::ifstream in(path, std::ios::binary);
    if (!in) return {};
    cached = files.emplace(path, std::string(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>())).first;
  }
  const std::string& src = cached->second;
  int depth = 0;
  size_t semi = std::string::npos;
  for (size_t i = finish; i < src.size() && semi == std::string::npos; ++i) {
    if (src[i] == '(') ++depth;
    if (src[i] == ')') --depth;
    if (src[i] == ';' && depth == 0) semi = i;
    if ((src[i] == '{' || src[i] == '}') && depth == 0) break;
  }
  if (semi == std::string::npos) return {};
  CXSourceRange range = clang_getRange(clang_getLocationForOffset(tu, file, begin),
                                       clang_getLocationForOffset(tu, file, static_cast<unsigned>(semi)));
  CXToken* tokens = nullptr;
  unsigned count = 0;
  clang_tokenize(tu, range, &tokens, &count);
  std::vector<Token> toks;
  for (unsigned i = 0; i < count && offset_of(clang_getRangeStart(clang_getTokenExtent(tu, tokens[i]))) < semi; ++i) {
    if (clang_getTokenKind(tokens[i]) == CXToken_Comment) continue;
    CXSourceRange token_extent = clang_getTokenExtent(tu, tokens[i]);
    toks.push_back(Token{text(clang_getTokenSpelling(tu, tokens[i])), offset_of(clang_getRangeStart(token_extent)),
                         offset_of(clang_getRangeEnd(token_extent)), clang_getTokenKind(tokens[i]) == CXToken_Literal});
  }
  clang_disposeTokens(tu, tokens, count);
  return toks;
}

// The declaration as written: its tokens, with each run of whitespace or comment as one space and macros as spelled. The head of
// a class, protocol or category stops before its members; a body in braces is written as "{ ... }"; a trailing ";" is dropped.
// The deprecation text a declaration writes in its macros: the first string of API_DEPRECATED("TEXT", ...), the replacement of
// API_DEPRECATED_WITH_REPLACEMENT("NAME", ...) (read as "Use NAME instead"), or the message="TEXT" of an availability attribute.
// Consecutive string literals are one text. libclang does not report these texts for an availability attribute.
std::string written_deprecation(const std::vector<Token>& toks) {
  for (size_t i = 0; i + 2 < toks.size(); ++i) {
    const std::string& word = toks[i].spelling;
    bool macro = (word == "API_DEPRECATED" || word == "API_DEPRECATED_WITH_REPLACEMENT") && toks[i + 1].spelling == "(";
    bool attribute = word == "message" && toks[i + 1].spelling == "=";
    if (!macro && !attribute) continue;
    std::string body;
    size_t j = i + 2;
    for (; j < toks.size() && toks[j].literal; ++j) body += toks[j].spelling.substr(1, toks[j].spelling.size() - 2);
    if (j == i + 2) continue;
    return word == "API_DEPRECATED_WITH_REPLACEMENT" ? "Use " + body + " instead" : body;
  }
  return "";
}

// The texts of the availability attributes, for the message column: "deprecated: TEXT" and "unavailable: TEXT", joined by " | ".
std::string message_of(CXTranslationUnit tu, CXCursor c) {
  PlatformAvailability pa = platform_availability(c);
  std::string out;
  std::string deprecated = pa.deprecated_message;
  std::string written = written_deprecation(tokens_of(tu, c));
  if (!written.empty()) deprecated = written;
  std::string unavailable = pa.unavailable_message;
  if (!deprecated.empty()) out += "deprecated: " + deprecated;
  if (!unavailable.empty()) out += std::string(out.empty() ? "" : " | ") + "unavailable: " + unavailable;
  return cell(out);
}

// The key of a source position: its file and offset.
std::string position_key(CXSourceLocation location) {
  CXFile file = nullptr;
  unsigned line = 0, column = 0, offset = 0;
  clang_getExpansionLocation(location, &file, &line, &column, &offset);
  if (!file) return "";
  return text(clang_getFileName(file)) + ":" + std::to_string(offset);
}

std::string decl_text(CXTranslationUnit tu, const std::map<std::string, std::string>& macro_at, CXCursor c) {
  // A declaration a macro produced is written as the macro's name, as spelled at the use site (the macro uses come from the
  // preprocessing record: see collect_macro_uses).
  auto macro = macro_at.find(position_key(clang_getCursorLocation(c)));
  if (macro != macro_at.end()) return cell(macro->second);
  CXCursorKind kind = clang_getCursorKind(c);
  bool objc_head = kind == CXCursor_ObjCInterfaceDecl || kind == CXCursor_ObjCCategoryDecl || kind == CXCursor_ObjCProtocolDecl;
  std::vector<Token> toks = kind == CXCursor_VarDecl ? variable_tokens(tu, c) : std::vector<Token>();
  if (toks.empty()) toks = tokens_of(tu, c);
  std::string out;
  unsigned previous_end = 0;
  bool any = false;
  for (size_t i = 0; i < toks.size(); ++i) {
    const std::string& spelling = toks[i].spelling;
    if (objc_head && (spelling == "{" || spelling == "@end" || spelling == "-" || spelling == "+" || spelling == "@property" ||
                      spelling == "@optional" || spelling == "@required")) {
      break;
    }
    if (any && toks[i].start > previous_end) out += ' ';
    if (spelling == "{") {  // a body of a tag, typedef, function or variable: written, not spelled out
      out += "{ ... }";
      int depth = 0;
      for (; i < toks.size(); ++i) {
        if (toks[i].spelling == "{") ++depth;
        if (toks[i].spelling == "}" && --depth == 0) break;
      }
      previous_end = i < toks.size() ? toks[i].end : previous_end;
      any = true;
      continue;
    }
    out += spelling;
    previous_end = toks[i].end;
    any = true;
  }
  if (!out.empty() && out.back() == ';') out.pop_back();
  // a getter or setter clang synthesises from a property has no declaration of its own: its extent is the property's name, and the
  // property's row carries the declaration
  bool method = kind == CXCursor_ObjCInstanceMethodDecl || kind == CXCursor_ObjCClassMethodDecl;
  if (method && (out.empty() || (out[0] != '-' && out[0] != '+'))) out = "-";
  return cell(out.empty() ? "-" : out);
}

// The cells of a full IR row: the 16 of section 5.1, the declaration as written and the messages, then the three facts the renderer
// reads (typeparams, anon, category; see the header comment).
constexpr int kFullColumns = 21;

// One declaration's row (the 13 fields the extractor writes per declaration, and the decl text).
struct Row {
  std::string kind, usr, container, name, side, header, line, avail, nullab, type, params, attrs, value, decl, message;
  std::string typeparams, anon, category;  // the renderer's facts (cells 19 to 21; an empty one is "-")
  std::string brief, comment, params_names;  // the doc mode only (--doc): the doc comment and the parameter names
};

// A declaration with the facts resolution needs. defining: it is the defining declaration of its entity (a definition, or a
// member of the class's or protocol's own @interface or @protocol). extension: it is written in a category or class extension.
// intro: the iOS introduction of its availability (0 when none).
struct Record {
  Row row;
  bool defining;
  bool extension;
  int intro;
};

struct Context {
  std::string framework;
  std::vector<std::string> own;  // the directories whose headers are the framework's own, each with its trailing slash; or one header, with none
  CXTranslationUnit tu;
  std::vector<Record> records;  // every declaration in source order; resolve() writes them
  std::set<std::string> tags;   // the tags emitted, by USR: each is one declaration
  std::map<std::string, std::string> macro_at;  // file:offset of a macro use -> the macro's name
  std::string out;              // the rows, written only when the parse has no error
  bool doc = false;             // the doc mode (--doc): the doc rows of the declarations only
};

// The file and line where a declaration is written. A declaration a macro produces (AV_INIT_UNAVAILABLE expands to init and new)
// is placed at the expansion, where the header uses the macro: the spelling of its tokens is in the macro's header, and the
// spelling location differs between libclang versions.
bool in_framework(CXCursor c, const Context& ctx, std::string* file_out, unsigned* line_out) {
  CXSourceLocation loc = clang_getCursorLocation(c);
  CXFile file;
  unsigned line = 0, column = 0, offset = 0;
  clang_getExpansionLocation(loc, &file, &line, &column, &offset);
  if (!file) return false;
  // the path lexically normal: a header reached as Headers/../Frameworks/Nested.framework/... is the nested framework's, not the umbrella's
  std::string path = std::filesystem::path(text(clang_getFileName(file))).lexically_normal().string();
  for (const std::string& own : ctx.own) {
    // a directory (with its trailing slash) owns the headers under it; a header with no slash owns that header alone
    bool directory = own.back() == '/';
    if (directory ? path.compare(0, own.size(), own) == 0 : path == own) {
      *file_out = directory ? path.substr(own.size()) : path.substr(path.find_last_of('/') + 1);
      *line_out = line;
      return true;
    }
  }
  return false;
}

// The first 8 bytes of SHA-256, as 16 hex digits: the declaration hash and the availability hash.
std::string digest16(const std::string& s) {
  unsigned char d[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(s.data(), (CC_LONG)s.size(), d);
  std::string out;
  char hex[3];
  for (int i = 0; i < 8; ++i) {
    std::snprintf(hex, sizeof hex, "%02x", d[i]);
    out += hex;
  }
  return out;
}

// The declaration hash covers what the declaration says and not where it is written: no header, line, availability or decl text.
// Fields are joined with the unit separator (0x1f), which no field contains.
// The fields are the cells as the IR writes them (write_row: an empty cell is "-", a line break is a space), so a reader who recomputes
// the hash from the printed cells gets the same value (review F9).
std::string declaration_hash(const Row& r) {
  const std::string fields[] = {r.kind,           filled(cell(r.usr)),  filled(cell(r.container)), filled(cell(r.name)),
                                r.side,           filled(cell(r.type)), filled(cell(r.params)),    r.nullab,
                                filled(cell(r.attrs)), filled(cell(r.value))};
  std::string canonical;
  for (const std::string& f : fields) {
    canonical += f;
    canonical += '\x1f';
  }
  return digest16(canonical);
}

// The doc-time text of a declaration (--doc): its brief and raw doc comment as clang parses them, and the names of its parameters.
// It is attached when the record is made, while the cursor is at hand.
void attach_doc(CXCursor c, Row* r) {
  int n = clang_Cursor_getNumArguments(c);
  for (int i = 0; i < n; ++i) {
    if (i) r->params_names += " | ";
    r->params_names += text(clang_getCursorSpelling(clang_Cursor_getArgument(c, (unsigned)i)));
  }
  // the doc comment is the one clang attaches to the declaration (its own set: ///, //!, /** */ and /*! and their trailing < forms)
  r->comment = text(clang_Cursor_getRawCommentText(c));
  r->brief = text(clang_Cursor_getBriefCommentText(c));
}

// A cell of the doc mode with its backslashes, tabs and line breaks escaped, so that a declaration is one line.
std::string escaped(const std::string& s) {
  std::string out;
  for (char ch : s) {
    switch (ch) {
      case '\\': out += "\\\\"; break;
      case '\t': out += "\\t"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      default: out += ch;
    }
  }
  return out;
}

// The doc-time row of a declaration (--doc): ten escaped cells, tab separated and newline terminated.
void write_doc(Context& ctx, const Row& r) {
  const std::string cells[] = {ctx.framework, r.kind, r.usr, r.container, r.name, r.side, r.params_names, r.brief, r.comment, r.decl};
  for (size_t i = 0; i < sizeof cells / sizeof cells[0]; ++i) {
    if (i) ctx.out += '\t';
    ctx.out += escaped(cells[i]);
  }
  ctx.out += '\n';
}

// The cells of a declaration row, tab separated and newline terminated.
void write_row(Context& ctx, const Row& r) {
  if (ctx.doc) {
    write_doc(ctx, r);
    return;
  }
  const std::string cells[] = {cell(ctx.framework), r.kind,                 filled(cell(r.usr)),
                               filled(cell(r.container)), filled(cell(r.name)), r.side,
                               filled(cell(r.header)), r.line,              filled(cell(r.avail)),
                               r.nullab,            filled(cell(r.type)),   filled(cell(r.params)),
                               filled(cell(r.attrs)), filled(cell(r.value)), declaration_hash(r),
                               digest16(r.avail),   filled(cell(r.decl)),   filled(cell(r.message)),
                               filled(cell(r.typeparams)), filled(cell(r.anon)), filled(cell(r.category))};
  for (size_t i = 0; i < sizeof cells / sizeof cells[0]; ++i) {
    if (i) ctx.out += '\t';
    ctx.out += cells[i];
  }
  ctx.out += '\n';
}

// A conflict row: the key of a declaration that is declared more than once with different availability, how it was resolved
// ("defining", "stricter-extension" or "merged"), and the availability variants. ir.lua lists these for review.
void write_conflict(Context& ctx, const Row& key, const std::string& resolution, const std::string& variants) {
  if (ctx.doc) return;  // the doc mode writes declarations only
  const std::string cells[] = {cell(ctx.framework), "conflict",   filled(cell(key.usr)), filled(cell(key.container)),
                               filled(cell(key.name)), key.side,  key.kind,              "-",
                               resolution,            "-",        variants,              "-",
                               "-",                   "-",        "-",                   "-",
                               "-",                   "-",        "-",                   "-",
                               "-"};
  for (size_t i = 0; i < sizeof cells / sizeof cells[0]; ++i) {
    if (i) ctx.out += '\t';
    ctx.out += cells[i];
  }
  ctx.out += '\n';
}

void record(Context& ctx, CXCursor c, const Row& r, bool defining, bool extension, int intro) {
  Row kept = r;
  if (ctx.doc) attach_doc(c, &kept);
  ctx.records.push_back(Record{kept, defining, extension, intro});
}

// The rule of section 5.2 and the ruling D3. Records of one key are grouped in source order.
//  - all the same availability: the first is written (redeclarations that differ only in parameter names are one declaration);
//  - a defining record exists: its availability counts. A category or extension record with another availability overrides it
//    only when its iOS introduction is later (the stricter, listed as stricter-extension); an earlier one is ignored (defining).
//    Any other record with another availability is merged (ir.lua applies the rule of avail.lua to all the variants);
//  - no defining record: merged, with every availability written.
void resolve(Context& ctx) {
  std::map<std::string, std::vector<size_t>> groups;
  std::vector<std::string> order;
  for (size_t i = 0; i < ctx.records.size(); ++i) {
    const Row& r = ctx.records[i].row;
    std::string key = r.kind + "\t" + r.usr + "\t" + r.container + "\t" + r.name + "\t" + r.side;
    if (groups.find(key) == groups.end()) order.push_back(key);
    groups[key].push_back(i);
  }
  for (const std::string& key : order) {
    const std::vector<size_t>& group = groups[key];
    const Record& first = ctx.records[group[0]];
    std::vector<std::string> variants;
    std::vector<size_t> first_of_variant;
    for (size_t i : group) {
      const std::string& avail = ctx.records[i].row.avail;
      if (std::find(variants.begin(), variants.end(), avail) == variants.end()) {
        variants.push_back(avail);
        first_of_variant.push_back(i);
      }
    }
    if (variants.size() == 1) {
      write_row(ctx, first.row);
      continue;
    }
    size_t base = group.size();
    for (size_t i : group) {
      if (ctx.records[i].defining) {
        base = i;
        break;
      }
    }
    std::string resolution = "merged";
    std::vector<size_t> written = first_of_variant;
    if (base != group.size()) {
      size_t chosen = base;
      bool stricter = false, unresolved = false;
      for (size_t i : group) {
        const Record& r = ctx.records[i];
        if (r.row.avail == ctx.records[chosen].row.avail) continue;
        if (r.extension) {
          if (r.intro > ctx.records[chosen].intro) {
            chosen = i;
            stricter = true;
          }
        } else {
          unresolved = true;
        }
      }
      if (!unresolved) {
        resolution = stricter ? "stricter-extension" : "defining";
        written = {chosen};
      }
    }
    std::string joined;
    for (const std::string& v : variants) joined += (joined.empty() ? "" : " | ") + v;
    for (size_t i : written) write_row(ctx, ctx.records[i].row);
    if (variants.size() > 1) write_conflict(ctx, first.row, resolution, joined);
  }
}

// A tag is one declaration: the first declaration of its USR in the framework is the one emitted (tag_is_emitted prefers the definition).
bool first_tag(Context& ctx, CXCursor c) {
  return ctx.tags.insert(text(clang_getCursorUSR(c))).second;
}

// A tag (enum, struct, union) is one declaration: its definition where this framework writes one, otherwise its first declaration
// in the framework (an opaque type, or a definition written elsewhere). A forward declaration that the framework's own definition
// supersedes is not emitted, and neither are its children, which belong to the definition.
bool tag_is_emitted(CXCursor c, Context& ctx) {
  std::string file;
  unsigned line = 0;
  CXCursor definition = clang_getCursorDefinition(c);
  if (!clang_Cursor_isNull(definition) && in_framework(definition, ctx, &file, &line)) return clang_isCursorDefinition(c);
  return first_tag(ctx, c);
}

std::string parameters(CXCursor c, std::string* nullab) {
  int n = clang_Cursor_getNumArguments(c);
  std::string out;
  for (int i = 0; i < n; ++i) {
    CXCursor arg = clang_Cursor_getArgument(c, (unsigned)i);
    if (i) out += " | ";
    out += declared_type(clang_getCursorType(arg)) + " " + text(clang_getCursorSpelling(arg));
    if (i) *nullab += ",";
    *nullab += nullability(clang_getCursorType(arg));
  }
  return out.empty() ? "-" : out;
}

CXChildVisitResult visit(CXCursor c, CXCursor parent, CXClientData data);

// Every macro use of the translation unit, by position (the preprocessing record is parsed for this).
CXChildVisitResult collect_macro_uses(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  if (clang_getCursorKind(c) == CXCursor_MacroExpansion) {
    Context& ctx = *static_cast<Context*>(data);
    ctx.macro_at[position_key(clang_getCursorLocation(c))] = text(clang_getCursorSpelling(c));
  }
  return CXChildVisit_Continue;
}

// What a member's context says about it: an extension or category statement, or the defining @interface or @protocol of its class.
struct Nest {
  Context* ctx;
  std::string name;       // the class, protocol or tag the declarations belong to ("-" at the top level)
  std::string category;   // the name of the category they are written in ("" for a class extension, an @interface or a @protocol)
  bool extension;         // written in a category or class extension
  bool defining_context;  // written in the defining @interface or @protocol (not a forward declaration)
};

void method_row(Context& ctx, CXCursor c, bool klass, const Nest& nest) {
  std::string file;
  unsigned line = 0;
  if (!in_framework(c, ctx, &file, &line)) return;
  Row r;
  r.kind = "method";
  r.usr = text(clang_getCursorUSR(c));
  r.container = nest.category.empty() ? "-" : nest.category;
  r.name = text(clang_getCursorSpelling(c));
  r.side = klass ? "+" : "-";
  r.header = file;
  r.line = std::to_string(line);
  r.avail = availability(c);
  std::string params_nullab;
  r.params = parameters(c, &params_nullab);
  r.nullab = nullability(clang_getCursorResultType(c)) + "|" + params_nullab;
  r.type = declared_type(clang_getCursorResultType(c));
  r.attrs = clang_Cursor_isObjCOptional(c) ? "optional" : "-";
  r.value = "-";
  r.message = message_of(ctx.tu, c);
  r.decl = decl_text(ctx.tu, ctx.macro_at, c);
  // a getter or setter clang synthesises from a property is no declaration of its own: it is an accessor row (the spec's members are
  // the properties, and ir.lua keeps accessors out of the shards)
  if (r.decl == "-") r.kind = "accessor";
  record(ctx, c, r, !nest.extension && nest.defining_context, nest.extension, introduced_ios(c));
}

// Finds the NSObject attribute under a declaration (a property's __attribute__((NSObject)), which makes a CF pointer an object
// type, so retain or strong is legal on it), and stops there.
CXChildVisitResult nsobject_attribute(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  if (clang_getCursorKind(c) == CXCursor_ObjCNSObject) {
    *static_cast<bool*>(data) = true;
    return CXChildVisit_Break;
  }
  return CXChildVisit_Recurse;
}

void property_row(Context& ctx, CXCursor c, const Nest& nest) {
  std::string file;
  unsigned line = 0;
  if (!in_framework(c, ctx, &file, &line)) return;
  Row r;
  r.kind = "property";
  r.usr = text(clang_getCursorUSR(c));
  r.container = nest.category.empty() ? "-" : nest.category;
  r.name = text(clang_getCursorSpelling(c));
  r.side = "-";
  r.header = file;
  r.line = std::to_string(line);
  r.avail = availability(c);
  CXType t = clang_getCursorType(c);
  r.type = declared_type(t);
  r.nullab = nullability(t);
  r.params = "-";
  unsigned bits = clang_Cursor_getObjCPropertyAttributes(c, 0);
  std::string attrs;
  auto add = [&attrs](const std::string& s) {
    if (!attrs.empty()) attrs += ",";
    attrs += s;
  };
  if (bits & CXObjCPropertyAttr_readonly) add("readonly");
  if (bits & CXObjCPropertyAttr_copy) add("copy");
  if (bits & CXObjCPropertyAttr_retain) add("retain");
  if (bits & CXObjCPropertyAttr_assign) add("assign");
  if (bits & CXObjCPropertyAttr_weak) add("weak");
  if (bits & CXObjCPropertyAttr_strong) add("strong");
  if (bits & CXObjCPropertyAttr_nonatomic) add("nonatomic");
  if (bits & CXObjCPropertyAttr_atomic) add("atomic");
  if (bits & CXObjCPropertyAttr_class) add("class");
  if (bits & CXObjCPropertyAttr_getter) add("getter=" + text(clang_Cursor_getObjCPropertyGetterName(c)));
  if (bits & CXObjCPropertyAttr_setter) add("setter=" + text(clang_Cursor_getObjCPropertySetterName(c)));
  bool nsobject = false;
  clang_visitChildren(c, nsobject_attribute, &nsobject);
  if (nsobject) add("NSObject");
  r.attrs = attrs.empty() ? "-" : attrs;
  r.value = "-";
  r.message = message_of(ctx.tu, c);
  r.decl = decl_text(ctx.tu, ctx.macro_at, c);
  record(ctx, c, r, !nest.extension && nest.defining_context, nest.extension, introduced_ios(c));
}

void function_row(Context& ctx, CXCursor c) {
  std::string file;
  unsigned line = 0;
  if (!in_framework(c, ctx, &file, &line)) return;
  Row r;
  r.kind = "function";
  r.usr = text(clang_getCursorUSR(c));
  r.container = "-";
  r.name = text(clang_getCursorSpelling(c));
  r.side = "-";
  r.header = file;
  r.line = std::to_string(line);
  r.avail = availability(c);
  std::string params_nullab;
  r.params = parameters(c, &params_nullab);
  r.nullab = nullability(clang_getCursorResultType(c)) + "|" + params_nullab;
  r.type = declared_function_type(clang_getCursorType(c));
  r.attrs = clang_Cursor_isVariadic(c) ? "variadic" : "-";
  r.value = "-";
  r.message = message_of(ctx.tu, c);
  r.decl = decl_text(ctx.tu, ctx.macro_at, c);
  record(ctx, c, r, clang_isCursorDefinition(c), false, introduced_ios(c));
}

// A declaration with one type (a variable, typedef, field, enum or struct) or one value (an enum constant). anon is a field's
// anonymous struct or union (its USR), "-" for every other declaration.
void simple_row(Context& ctx, CXCursor c, const char* kind, const std::string& type, const std::string& nullab,
                const std::string& value, const std::string& container, bool defining, const std::string& anon = "-") {
  std::string file;
  unsigned line = 0;
  if (!in_framework(c, ctx, &file, &line)) return;
  Row r;
  r.kind = kind;
  r.usr = text(clang_getCursorUSR(c));
  r.container = container;
  r.name = declared_name(c);
  r.side = "-";
  r.header = file;
  r.line = std::to_string(line);
  r.avail = availability(c);
  r.nullab = nullab;
  r.params = "-";
  r.type = type;
  r.attrs = "-";
  r.value = value;
  r.anon = anon;
  r.message = message_of(ctx.tu, c);
  r.decl = decl_text(ctx.tu, ctx.macro_at, c);
  record(ctx, c, r, defining, false, introduced_ios(c));
}

// The class a category or class extension extends: the ObjCClassRef among its children.
CXChildVisitResult class_ref(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  if (clang_getCursorKind(c) != CXCursor_ObjCClassRef) return CXChildVisit_Continue;
  *static_cast<std::string*>(data) = text(clang_getCursorSpelling(c));
  return CXChildVisit_Break;
}

std::string category_class(CXCursor c) {
  std::string name = "-";
  clang_visitChildren(c, class_ref, &name);
  return name;
}

// A generic class's type parameters in order, each as name:bound (the bound is the declared type the parameter is bounded by, id when it
// has none). clang's Objective-C type parameter is a typedef-like declaration: its underlying type is the bound.
CXChildVisitResult type_parameter_visit(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  if (clang_getCursorKind(c) != CXCursor_TemplateTypeParameter) return CXChildVisit_Continue;
  std::string* out = static_cast<std::string*>(data);
  if (!out->empty()) *out += " | ";
  *out += text(clang_getCursorSpelling(c)) + ":" + declared_type(clang_getTypedefDeclUnderlyingType(c));
  return CXChildVisit_Continue;
}

std::string type_parameters(CXCursor c) {
  std::string out;
  clang_visitChildren(c, type_parameter_visit, &out);
  return out.empty() ? "-" : out;
}

// The USR of the anonymous struct or union a field's type is (union { struct {...} x; } gives x the inner struct's USR), or "-" when the
// type is a named tag or a typedef: the anonymous tag is what the field's type column names only as struct (unnamed ...).
std::string anonymous_tag(CXType t) {
  CXCursor decl = clang_getTypeDeclaration(t);
  CXCursorKind kind = clang_getCursorKind(decl);
  if ((kind != CXCursor_StructDecl && kind != CXCursor_UnionDecl) || !clang_Cursor_isAnonymous(decl)) return "-";
  return text(clang_getCursorUSR(decl));
}

// Whether a canonical integer type is unsigned (the character type is unsigned on some targets: Char_U).
bool is_unsigned_integer(CXTypeKind kind) {
  switch (kind) {
    case CXType_Bool:
    case CXType_Char_U:
    case CXType_UChar:
    case CXType_Char16:
    case CXType_Char32:
    case CXType_UShort:
    case CXType_UInt:
    case CXType_ULong:
    case CXType_ULongLong:
    case CXType_UInt128:
      return true;
    default:
      return false;
  }
}

// The value of an enum constant as clang evaluates it for the enum's own integer type, as text. libclang's signed accessor
// sign-extends from the width of that type, so a constant of an unsigned enum with its top bit set reads as a negative number
// (ARSegmentationClassPerson = 255 of a uint8_t enum came out as -1, kCTFontTraitClassMask = 15U << 28 as -268435456): an
// unsigned enum is read through the unsigned accessor, which holds the value the header spells.
std::string enum_constant_value(CXCursor c) {
  CXType integer = clang_getCanonicalType(clang_getEnumDeclIntegerType(clang_getCursorSemanticParent(c)));
  if (is_unsigned_integer(integer.kind)) return std::to_string(clang_getEnumConstantDeclUnsignedValue(c));
  return std::to_string(clang_getEnumConstantDeclValue(c));
}

CXChildVisitResult visit(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  Nest* nest = static_cast<Nest*>(data);
  Context& ctx = *nest->ctx;
  CXCursorKind kind = clang_getCursorKind(c);
  std::string file;
  unsigned line = 0;
  // a declaration outside the framework's headers is not emitted, and its children are not visited (they sit in that file)
  bool own = in_framework(c, ctx, &file, &line);
  switch (kind) {
    case CXCursor_ObjCInterfaceDecl:
    case CXCursor_ObjCCategoryDecl:
    case CXCursor_ObjCProtocolDecl: {
      if (!own) return CXChildVisit_Continue;
      // a class's @interface is its definition; a protocol is defined by its @protocol ... @end, and a forward declaration
      // (@protocol P;) is not a declaration of the framework (its definition is written elsewhere)
      bool definition = kind != CXCursor_ObjCProtocolDecl || clang_isCursorDefinition(c);
      if (!definition) return CXChildVisit_Continue;
      Row r;
      r.kind = kind == CXCursor_ObjCInterfaceDecl ? "interface" : kind == CXCursor_ObjCCategoryDecl ? "category" : "protocol";
      r.usr = text(clang_getCursorUSR(c));
      // a class extension's USR carries the file and offset of its declaration, which move with any edit above it: the class
      // name alone identifies it (c:objc(ext)Class)
      size_t at = r.usr.find('@', r.usr.find(')'));
      if (r.usr.compare(0, 10, "c:objc(ext") == 0 && at != std::string::npos) r.usr.resize(at);
      r.container = "-";
      r.name = text(clang_getCursorSpelling(c));
      r.side = "-";
      r.header = file;
      r.line = std::to_string(line);
      r.avail = availability(c);
      r.nullab = "-";
      r.type = "-";
      r.params = "-";
      r.attrs = "-";
      r.value = "-";
      r.typeparams = type_parameters(c);
      r.message = message_of(ctx.tu, c);
      r.decl = decl_text(ctx.tu, ctx.macro_at, c);
      record(ctx, c, r, kind != CXCursor_ObjCCategoryDecl && definition, kind == CXCursor_ObjCCategoryDecl, introduced_ios(c));
      // the protocols a category lists belong to the class it extends, not to the category
      std::string owner = kind == CXCursor_ObjCCategoryDecl ? category_class(c) : r.name;
      bool category = kind == CXCursor_ObjCCategoryDecl;
      Nest child{nest->ctx, owner, category ? r.name : "", category, !category};
      clang_visitChildren(c, visit, &child);
      return CXChildVisit_Continue;
    }
    case CXCursor_ObjCSuperClassRef:
    case CXCursor_ObjCProtocolRef: {
      // a reference outside any class, category or protocol (a forward declaration @protocol P;) is not a conformance
      if (!own || nest->name == "-") return CXChildVisit_Continue;
      Row r;
      r.kind = kind == CXCursor_ObjCSuperClassRef ? "super" : "conforms";
      // a conformance's usr is its owner's USR (the class or the protocol it is listed by): a class and a protocol can share a name
      r.usr = kind == CXCursor_ObjCProtocolRef ? text(clang_getCursorUSR(parent)) : "-";
      r.container = nest->name;
      r.name = text(clang_getCursorSpelling(c));
      r.side = "-";
      r.header = file;
      r.line = std::to_string(line);
      r.avail = "-";
      r.nullab = "-";
      r.type = "-";
      r.params = "-";
      r.attrs = "-";
      r.value = "-";
      r.decl = "-";
      r.category = nest->category.empty() ? "-" : nest->category;
      record(ctx, c, r, true, false, 0);
      return CXChildVisit_Continue;
    }
    case CXCursor_ObjCInstanceMethodDecl:
      method_row(ctx, c, false, *nest);
      return CXChildVisit_Continue;
    case CXCursor_ObjCClassMethodDecl:
      method_row(ctx, c, true, *nest);
      return CXChildVisit_Continue;
    case CXCursor_ObjCPropertyDecl:
      property_row(ctx, c, *nest);
      return CXChildVisit_Continue;
    case CXCursor_VarDecl:
      if (own && clang_getCursorLinkage(c) == CXLinkage_External) {
        CXType t = clang_getCursorType(c);
        simple_row(ctx, c, "var", declared_type(t), nullability(t), "-", "-", clang_isCursorDefinition(c));
      }
      return CXChildVisit_Continue;
    case CXCursor_FunctionDecl:
      if (own) function_row(ctx, c);
      return CXChildVisit_Continue;
    case CXCursor_TypedefDecl:
      if (own) simple_row(ctx, c, "typedef", declared_underlying_type(clang_getTypedefDeclUnderlyingType(c)),
                          nullability(clang_getTypedefDeclUnderlyingType(c)), "-", "-", false);
      return CXChildVisit_Continue;
    case CXCursor_EnumDecl:
      if (own && tag_is_emitted(c, ctx)) {
        std::string name = declared_name(c);
        simple_row(ctx, c, "enum", spelled(clang_getEnumDeclIntegerType(c)), "-", "-", "-", clang_isCursorDefinition(c));
        Nest child{nest->ctx, name, "", false, false};
        clang_visitChildren(c, visit, &child);
      }
      return CXChildVisit_Continue;
    case CXCursor_EnumConstantDecl:
      if (own) simple_row(ctx, c, "enumconst", "-", "-", enum_constant_value(c), nest->name, true);
      return CXChildVisit_Continue;
    case CXCursor_StructDecl:
    case CXCursor_UnionDecl: {
      if (!own || !tag_is_emitted(c, ctx)) return CXChildVisit_Continue;
      std::string name = declared_name(c);
      simple_row(ctx, c, kind == CXCursor_StructDecl ? "struct" : "union", "-", "-", "-", "-", clang_isCursorDefinition(c));
      Nest child{nest->ctx, name, "", false, false};
      clang_visitChildren(c, visit, &child);
      return CXChildVisit_Continue;
    }
    case CXCursor_FieldDecl:
      if (own) {
        CXType t = clang_getCursorType(c);
        simple_row(ctx, c, "field", declared_type(t), nullability(t), "-", nest->name, true, anonymous_tag(t));
      }
      return CXChildVisit_Continue;
    default:
      return CXChildVisit_Continue;
  }
}

// The typedefs the framework's declarations reference that another SDK header declares: the vector types of simd/, the types of
// sys/ and mach/. decls keeps only the declarations written under Headers/, so none of these has a row, and the generator's typedef
// index cannot resolve a name a declaration spells. Each one a declaration reaches (through its parameters, result, fields and
// properties, and the typedef chain it names) is written as a typedef row of the framework's shard, the row a framework's own typedef
// gets (main runs the walk outside the doc mode, which writes declarations only).
struct Referenced {
  Context* ctx;
  std::set<std::string> written;  // the USRs written, so each typedef is one row
};

void referenced_type(Referenced& ref, CXType t);

// A typedef another SDK header declares, as a typedef row (simple_row's form, with the file it is written in as the header).
void write_foreign_typedef(Referenced& ref, CXCursor d, CXType underlying) {
  Context& ctx = *ref.ctx;
  CXSourceLocation loc = clang_getCursorLocation(d);
  CXFile file = nullptr;
  unsigned line = 0, column = 0, offset = 0;
  clang_getExpansionLocation(loc, &file, &line, &column, &offset);
  Row r;
  r.kind = "typedef";
  r.usr = text(clang_getCursorUSR(d));
  r.container = "-";
  r.name = declared_name(d);
  r.side = "-";
  r.header = file ? text(clang_getFileName(file)) : "-";
  r.line = std::to_string(line);
  r.avail = availability(d);
  r.nullab = nullability(underlying);
  r.params = "-";
  r.type = declared_underlying_type(underlying);
  r.attrs = "-";
  r.value = "-";
  r.message = message_of(ctx.tu, d);
  r.decl = decl_text(ctx.tu, ctx.macro_at, d);
  record(ctx, d, r, true, false, introduced_ios(d));
}

// The typedefs a type reaches. A typedef the framework declares is its own row, so it is not followed here (its own declaration is
// visited, and its underlying type with it).
void referenced_type(Referenced& ref, CXType t) {
  switch (t.kind) {
    case CXType_Typedef: {
      CXCursor d = clang_getTypeDeclaration(t);
      std::string file;
      unsigned line = 0;
      if (in_framework(d, *ref.ctx, &file, &line)) return;
      if (!ref.written.insert(text(clang_getCursorUSR(d))).second) return;
      CXType underlying = clang_getTypedefDeclUnderlyingType(d);
      write_foreign_typedef(ref, d, underlying);
      referenced_type(ref, underlying);
      return;
    }
    case CXType_Attributed:
      referenced_type(ref, clang_Type_getModifiedType(t));
      return;
    case CXType_Elaborated:
      referenced_type(ref, clang_Type_getNamedType(t));
      return;
    case CXType_Pointer:
    case CXType_BlockPointer:
    case CXType_ObjCObjectPointer:
    case CXType_LValueReference:
      referenced_type(ref, clang_getPointeeType(t));
      return;
    case CXType_ConstantArray:
    case CXType_IncompleteArray:
    case CXType_VariableArray:
    case CXType_DependentSizedArray:
      referenced_type(ref, clang_getArrayElementType(t));
      return;
    case CXType_Vector:
    case CXType_ExtVector:
    case CXType_Complex:
      referenced_type(ref, clang_getElementType(t));
      return;
    case CXType_FunctionProto:
    case CXType_FunctionNoProto: {
      referenced_type(ref, clang_getResultType(t));
      int n = clang_getNumArgTypes(t);
      for (int i = 0; i < n; ++i) referenced_type(ref, clang_getArgType(t, (unsigned)i));
      return;
    }
    default:
      return;
  }
}

// Walks the framework's own declarations: the types of a function, a method, a variable, a field, a property, a parameter and a typedef,
// and the members of a class, a protocol, a category, a struct or a union (the containers the walk descends into).
CXChildVisitResult referenced_visit(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  Referenced& ref = *static_cast<Referenced*>(data);
  std::string file;
  unsigned line = 0;
  if (!in_framework(c, *ref.ctx, &file, &line)) return CXChildVisit_Continue;
  bool container = false;
  switch (clang_getCursorKind(c)) {
    case CXCursor_FunctionDecl:
    case CXCursor_ObjCInstanceMethodDecl:
    case CXCursor_ObjCClassMethodDecl: {
      referenced_type(ref, clang_getCursorResultType(c));
      int n = clang_Cursor_getNumArguments(c);
      for (int i = 0; i < n; ++i) referenced_type(ref, clang_getCursorType(clang_Cursor_getArgument(c, i)));
      break;
    }
    case CXCursor_TypedefDecl:
      referenced_type(ref, clang_getTypedefDeclUnderlyingType(c));
      break;
    case CXCursor_VarDecl:
    case CXCursor_FieldDecl:
    case CXCursor_ObjCPropertyDecl:
      referenced_type(ref, clang_getCursorType(c));
      break;
    case CXCursor_ObjCInterfaceDecl:
    case CXCursor_ObjCCategoryDecl:
    case CXCursor_ObjCProtocolDecl:
    case CXCursor_StructDecl:
    case CXCursor_UnionDecl:
      container = true;
      break;
    default:
      break;
  }
  if (container) clang_visitChildren(c, referenced_visit, data);
  return CXChildVisit_Continue;
}

// The census of the translation unit: the declarations of the kinds the extractor reads, counted by where they are written: the
// framework's own, and those of other SDK headers the translation unit reaches. One census row per parsed framework; the gaps mode of
// ir.lua classifies the frameworks that have no declaration of their own with it.
struct Census {
  Context* ctx;
  std::string sdk;
  long own;
  long foreign;
  // the foreign declarations counted by the header file each is written in: the path under the SDK root (so the rows do not depend on
  // where the SDK is installed), and the number of declarations
  std::map<std::string, long> files;
};

CXChildVisitResult census_visit(CXCursor c, CXCursor parent, CXClientData data) {
  (void)parent;
  Census* census = static_cast<Census*>(data);
  switch (clang_getCursorKind(c)) {
    case CXCursor_ObjCInterfaceDecl:
    case CXCursor_ObjCCategoryDecl:
    case CXCursor_ObjCProtocolDecl:
    case CXCursor_FunctionDecl:
    case CXCursor_VarDecl:
    case CXCursor_TypedefDecl:
    case CXCursor_EnumDecl:
    case CXCursor_StructDecl:
    case CXCursor_UnionDecl:
      break;
    default:
      return CXChildVisit_Continue;
  }
  std::string file;
  unsigned line = 0;
  if (in_framework(c, *census->ctx, &file, &line)) {
    census->own++;
    return CXChildVisit_Continue;
  }
  CXFile written = nullptr;
  unsigned column = 0, offset = 0;
  clang_getExpansionLocation(clang_getCursorLocation(c), &written, &line, &column, &offset);
  if (!written) return CXChildVisit_Continue;
  // lexically normal, as in_framework reads it: a header reached as Headers/../Frameworks/Nested.framework/... is the nested framework's
  std::string where = std::filesystem::path(text(clang_getFileName(written))).lexically_normal().string();
  std::string root = std::filesystem::path(census->sdk).lexically_normal().string();
  if (where.compare(0, root.size(), root) != 0) return CXChildVisit_Continue;
  census->foreign++;
  where.erase(0, root.size());
  while (!where.empty() && where[0] == '/') where.erase(0, 1);
  census->files[where]++;
  return CXChildVisit_Continue;
}

void usage() {
  std::fprintf(stderr,
               "usage: decls --version | --target | --digest TEXT | --list\n"
               "       decls [--doc] [--timeout SECONDS] <framework>\n"
               "The SDK is IR_SDK. IR_RESOURCE, if set,\n"
               "is the compiler's resource directory; by default libclang finds its own.\n");
}

}  // namespace

// The frameworks the sweep covers, and the rule that gives each one's headers. The sweep (ir.lua) and the doc mode (--doc) both
// resolve a framework here, so the rule is written once.
namespace fs = std::filesystem;

struct Framework {
  std::string name;  // as the rows carry it: a nested framework is Outer/Inner
  std::string base;  // the folder's name without .framework (a usr/include module's name)
  fs::path root;     // the .framework directory (a usr/include module: the usr/include directory)
  fs::path map;      // a usr/include module's module map
  bool usr = false;  // a module of usr/include
};

// A path as the rows and the imports carry it: lexically normal (no "." or "x/..").
std::string normal(const fs::path& p) { return p.lexically_normal().string(); }

std::string trim_space(const std::string& s) {
  size_t begin = s.find_first_not_of(" \t\r\n");
  if (begin == std::string::npos) return "";
  size_t end = s.find_last_not_of(" \t\r\n");
  return s.substr(begin, end - begin + 1);
}

// A failure to read the SDK's files is an error that names the path (review F11): a shorter framework list or a missing module map must
// not pass as a result. A path that does not exist is not a failure; the callers ask for that case.
[[noreturn]] void fail_path(const fs::path& p, const char* what, const std::error_code& ec) {
  std::fprintf(stderr, "decls: %s: %s%s%s\n", what, p.string().c_str(), ec ? ": " : "", ec ? ec.message().c_str() : "");
  std::exit(2);
}

bool absent(const std::error_code& ec) {
  return ec == std::errc::no_such_file_or_directory || ec == std::errc::not_a_directory;
}

bool is_file(const fs::path& p) {
  std::error_code ec;
  bool result = fs::is_regular_file(p, ec);
  if (ec && !absent(ec)) fail_path(p, "cannot read the file status of", ec);
  return result;
}

bool is_dir(const fs::path& p) {
  std::error_code ec;
  bool result = fs::is_directory(p, ec);
  if (ec && !absent(ec)) fail_path(p, "cannot read the file status of", ec);
  return result;
}

// The entries of a folder, sorted by path (none when the folder does not exist).
std::vector<fs::path> entries_of(const fs::path& dir) {
  std::vector<fs::path> out;
  std::error_code ec;
  if (!fs::exists(dir, ec)) {
    if (ec && !absent(ec)) fail_path(dir, "cannot read the folder", ec);
    return out;  // a folder that is not there has no entries
  }
  fs::directory_iterator it(dir, ec);
  if (ec) fail_path(dir, "cannot read the folder", ec);
  for (fs::directory_iterator end; it != end; it.increment(ec)) {
    if (ec) fail_path(dir, "cannot read the folder", ec);
    out.push_back(it->path());
  }
  std::sort(out.begin(), out.end());
  return out;
}

// The frameworks directly in a folder, then those nested in each one's Frameworks/ folder (named Outer/Inner). A symbolic link to a
// directory is listed as the framework it names, as it always has been (WebKit.framework links into the Cryptexes; AVFoundation's
// Frameworks/AVFAudio.framework links to the top-level AVFAudio.framework, and parses to no declaration of its own: it has no shard).
void frameworks_in(const fs::path& dir, const std::string& outer, std::vector<Framework>* out) {
  const std::string suffix = ".framework";
  for (const fs::path& p : entries_of(dir)) {
    std::string file = p.filename().string();
    if (file.size() <= suffix.size() || file.compare(file.size() - suffix.size(), suffix.size(), suffix) != 0) continue;
    if (!is_dir(p)) continue;
    Framework f;
    f.base = file.substr(0, file.size() - suffix.size());
    f.name = outer.empty() ? f.base : outer + "/" + f.base;
    f.root = p;
    out->push_back(f);
    frameworks_in(p / "Frameworks", f.name, out);
  }
}

// The name a module map line declares as a top-level module (the line starts at its first column with module or explicit module), or "".
// The text of a file. A file that cannot be opened or read is an error that names it (review F11).
std::string text_of(const fs::path& file) {
  std::ifstream in(file, std::ios::binary);
  if (!in) fail_path(file, "cannot open", std::error_code(errno, std::generic_category()));
  std::stringstream all;
  all << in.rdbuf();
  if (in.bad()) fail_path(file, "cannot read", std::error_code(errno, std::generic_category()));
  return all.str();
}

// The first string value of a JSON key in the text, or "" when the key is not there.
std::string json_string(const std::string& json, const char* key) {
  const std::regex value(std::string("\"") + key + "\"\\s*:\\s*\"([^\"]*)\"");
  std::smatch m;
  return std::regex_search(json, m, value) ? m[1].str() : std::string();
}

// The target the rows are compiled for, derived from the SDK's own record (SDKSettings.json, review F10): arm64, the one architecture
// the spec is written for; the vendor and the system of the iphoneos target; and the SDK's deployment target, which is its version. A
// record without those keys is an error that names it.
std::string target_of(const fs::path& sdk) {
  const fs::path record = sdk / "SDKSettings.json";
  const std::string json = text_of(record);
  const std::string version = json_string(json, "DefaultDeploymentTarget");
  const std::string vendor = json_string(json, "LLVMTargetTripleVendor");
  const std::string sys_name = json_string(json, "LLVMTargetTripleSys");
  if (version.empty() || vendor.empty() || sys_name.empty()) {
    std::fprintf(stderr, "decls: %s has no DefaultDeploymentTarget and LLVMTargetTriple keys\n", record.string().c_str());
    std::exit(2);
  }
  return "arm64-" + vendor + "-" + sys_name + version;
}

// The SHA-256 of the libclang this process runs: the image that holds a libclang function, read through the file it was loaded from
// (only the digest is printed; the path is not part of any output). Pins the library the shard headers record (review F8).
std::string libclang_sha256() {
  Dl_info info;
  if (dladdr(reinterpret_cast<const void*>(&clang_getClangVersion), &info) == 0 || info.dli_fname == nullptr) {
    std::fprintf(stderr, "decls: cannot find the libclang image\n");
    std::exit(2);
  }
  const fs::path image(info.dli_fname);
  std::ifstream in(image, std::ios::binary);
  if (!in) fail_path(image, "cannot open the libclang image", std::error_code(errno, std::generic_category()));
  CC_SHA256_CTX ctx;
  CC_SHA256_Init(&ctx);
  std::vector<char> buffer(1 << 20);
  while (in) {
    in.read(buffer.data(), (std::streamsize)buffer.size());
    CC_SHA256_Update(&ctx, buffer.data(), (CC_LONG)in.gcount());
  }
  if (in.bad()) fail_path(image, "cannot read the libclang image", std::error_code(errno, std::generic_category()));
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256_Final(digest, &ctx);
  std::string hex;
  char pair[3];
  for (unsigned char byte : digest) {
    std::snprintf(pair, sizeof pair, "%02x", byte);
    hex += pair;
  }
  return hex;
}

// The enum values this extractor reads (CXCursorKind, CXTypeKind) are numbers from the headers it was built with. Each must name the same
// kind in the loaded library, or the rows would be decoded wrongly: checked on every start, so the skew between the package's headers and
// the host's libclang is checked, not assumed (review F8). Returns false with the first mismatch.
bool check_enum_values(std::string* failure) {
  struct Kind {
    unsigned value;
    const char* name;
    bool type;
  };
  static const Kind kinds[] = {
      {CXCursor_ObjCInterfaceDecl, "ObjCInterfaceDecl", false},
      {CXCursor_ObjCCategoryDecl, "ObjCCategoryDecl", false},
      {CXCursor_ObjCProtocolDecl, "ObjCProtocolDecl", false},
      {CXCursor_ObjCInstanceMethodDecl, "ObjCInstanceMethodDecl", false},
      {CXCursor_ObjCClassMethodDecl, "ObjCClassMethodDecl", false},
      {CXCursor_ObjCPropertyDecl, "ObjCPropertyDecl", false},
      {CXCursor_ObjCSuperClassRef, "ObjCSuperClassRef", false},
      {CXCursor_ObjCProtocolRef, "ObjCProtocolRef", false},
      {CXCursor_ObjCClassRef, "ObjCClassRef", false},
      {CXCursor_FunctionDecl, "FunctionDecl", false},
      {CXCursor_VarDecl, "VarDecl", false},
      {CXCursor_FieldDecl, "FieldDecl", false},
      {CXCursor_TypedefDecl, "TypedefDecl", false},
      {CXCursor_EnumDecl, "EnumDecl", false},
      {CXCursor_EnumConstantDecl, "EnumConstantDecl", false},
      {CXCursor_StructDecl, "StructDecl", false},
      {CXCursor_UnionDecl, "UnionDecl", false},
      {CXCursor_MacroExpansion, "macro expansion", false},
      {CXType_Attributed, "Attributed", true},
      {CXType_Unexposed, "Unexposed", true},
      {CXType_BlockPointer, "BlockPointer", true},
  };
  for (const Kind& k : kinds) {
    std::string got = k.type ? text(clang_getTypeKindSpelling((CXTypeKind)k.value)) : text(clang_getCursorKindSpelling((CXCursorKind)k.value));
    if (got != k.name) {
      *failure = std::string("the loaded libclang names enum value ") + std::to_string(k.value) + " '" + got + "', the headers it was " +
                 "built with name it '" + k.name + "'";
      return false;
    }
  }
  return true;
}

// The lines of a text file. A file that cannot be opened or read is an error that names it (review F11): a module map that is not read
// must not look like a map that declares nothing.
std::vector<std::string> lines_of(const fs::path& file) {
  std::ifstream in(file);
  if (!in) fail_path(file, "cannot open", std::error_code(errno, std::generic_category()));
  std::vector<std::string> out;
  for (std::string line; std::getline(in, line);) out.push_back(line);
  if (in.bad()) fail_path(file, "cannot read", std::error_code(errno, std::generic_category()));
  return out;
}

std::string declared_module(const std::string& line) {
  // the name ends where it does not go on: module Darwin.POSIX declares the submodule Darwin.POSIX, not the top-level Darwin
  static const std::regex declaration(R"re(^(?:explicit\s+)?module\s+([A-Za-z0-9_]+)(?![A-Za-z0-9_.]))re");
  std::smatch m;
  return std::regex_search(line, m, declaration) ? m[1].str() : std::string();
}

// The top-level modules the usr/include module maps declare: a map is usr/include/<name>.modulemap or usr/include/<dir>/module.modulemap,
// as usr_module_map reads them. The sweep covers each of them.
std::set<std::string> usr_modules_declared(const fs::path& include) {
  std::set<std::string> names;
  auto declared_in = [&names](const fs::path& map) {
    for (const std::string& line : lines_of(map)) {
      std::string name = declared_module(line);
      if (!name.empty()) names.insert(name);
    }
  };
  for (const fs::path& p : entries_of(include)) {
    if (p.extension() == ".modulemap" && is_file(p)) declared_in(p);
    if (is_dir(p) && is_file(p / "module.modulemap")) declared_in(p / "module.modulemap");
  }
  return names;
}

// The module map of a usr/include module: the one map (usr/include/*.modulemap, or usr/include/<dir>/module.modulemap) that declares
// the module as a top-level module. Two maps that declare it are an error.
fs::path usr_module_map(const fs::path& include, const std::string& name, std::string* error) {
  std::vector<fs::path> candidates;
  for (const fs::path& p : entries_of(include)) {
    if (p.extension() == ".modulemap" && is_file(p)) candidates.push_back(p);
    if (is_dir(p) && is_file(p / "module.modulemap")) candidates.push_back(p / "module.modulemap");
  }
  std::vector<fs::path> found;
  for (const fs::path& file : candidates) {
    for (const std::string& line : lines_of(file)) {
      if (declared_module(line) == name) {
        found.push_back(file);
        break;
      }
    }
  }
  if (found.size() > 1) {
    *error = "more than one module map declares the module " + name;
    return {};
  }
  return found.empty() ? fs::path() : found[0];
}

// The public headers a module map exposes, as paths: the header lines and the umbrella header resolve in header_base, the umbrella
// directories in dir_base. A framework module nested in this one is its own framework and is skipped, and so is a module that requires
// x86 (the target is arm64). Textual, private and excluded headers are not public: an exclude removes a header an umbrella directory
// takes, unless the module names it. wanted, when set, is the one top-level module to take (a usr/include map can declare several); a
// framework's headers are in path order, a usr/include module's in the order its map names them.
std::vector<std::string> module_headers(const fs::path& map, const fs::path& header_base, const fs::path& dir_base,
                                        const std::string& wanted) {
  if (!is_file(map)) return {};
  static const std::regex framework_module(R"re(^framework\s+module\s)re");
  static const std::regex x86(R"re(^requires\s+x86)re");
  static const std::regex umbrella_header(R"re(^umbrella\s+header\s+"([^"]+)")re");
  static const std::regex header_line(R"re(^header\s+"([^"]+)")re");
  static const std::regex exclude_header(R"re(^exclude\s+header\s)re");
  static const std::regex umbrella_dir(R"re(^umbrella\s+"([^"]+)")re");
  static const std::regex quoted(R"re("([^"]+)")re");
  std::vector<std::string> headers;
  std::set<std::string> seen, named, excluded;
  auto add = [&](const std::string& file, bool is_named) {
    if (is_named) named.insert(file);
    if (seen.insert(file).second) headers.push_back(file);
  };
  int depth = 0;
  bool skipping_set = false;
  int skip_at = 0;
  for (const std::string& line : lines_of(map)) {
    std::string code = trim_space(line.substr(0, line.find("//")));
    int opens = (int)std::count(code.begin(), code.end(), '{');
    int closes = (int)std::count(code.begin(), code.end(), '}');
    bool skipping = skipping_set && depth >= skip_at;
    if (!skipping) {
      std::smatch m;
      std::string declared = declared_module(code);
      if (std::regex_search(code, framework_module) && depth >= 1) {
        skipping_set = true;
        skip_at = depth + 1;
      } else if (std::regex_search(code, x86)) {
        skipping_set = true;
        skip_at = depth;
      } else if (!wanted.empty() && depth == 0 && !declared.empty() && declared != wanted) {
        skipping_set = true;
        skip_at = depth + 1;
      } else if (std::regex_search(code, m, umbrella_header) || std::regex_search(code, m, header_line)) {
        add(normal(header_base / m[1].str()), true);
      } else if (std::regex_search(code, exclude_header)) {
        std::smatch q;
        if (std::regex_search(code, q, quoted)) excluded.insert(normal(header_base / q[1].str()));
      } else if (std::regex_search(code, m, umbrella_dir)) {
        std::vector<std::string> files;
        std::error_code ec;
        const fs::path umbrella = dir_base / m[1].str();
        fs::recursive_directory_iterator it(umbrella, ec), end;
        if (ec) fail_path(umbrella, "cannot read the umbrella directory", ec);
        for (; it != end; it.increment(ec)) {
          if (ec) fail_path(umbrella, "cannot read the umbrella directory", ec);
          if (it->path().extension() == ".h" && is_file(it->path())) files.push_back(normal(it->path()));
        }
        std::sort(files.begin(), files.end());
        for (const std::string& file : files) add(file, false);
      }
    }
    depth += opens - closes;
    if (skipping_set && depth < skip_at) skipping_set = false;
  }
  std::vector<std::string> out;
  for (const std::string& file : headers) {
    if (!excluded.count(file) || named.count(file)) out.push_back(file);
  }
  if (wanted.empty()) std::sort(out.begin(), out.end());
  return out;
}

// The headers a framework is parsed from: its module map's list. A framework with no module-map header reads every header of its Headers/
// folder (its umbrella header first): a header the umbrella does not include is the framework's own too (RealityKit and vecLib leave
// headers out of their umbrella's closure). A usr/include module has its map's list and nothing else. When there are none, *reason says why.
bool headers_of(const Framework& f, std::vector<std::string>* out, std::string* reason) {
  if (f.usr) {
    *out = module_headers(f.map, f.map.parent_path(), f.map.parent_path(), f.name);
    if (out->empty()) *reason = "no module map header";
    return true;
  }
  if (f.root.extension() == ".swiftmodule") {
    *reason = "no Objective-C or C header; Swift module only";
    return true;
  }
  *out = module_headers(f.root / "Modules" / "module.modulemap", f.root / "Headers", f.root, "");
  if (!out->empty()) return true;
  std::vector<std::string> read;
  const fs::path umbrella = f.root / "Headers" / (f.base + ".h");
  if (is_file(umbrella)) read.push_back(normal(umbrella));
  for (const fs::path& p : entries_of(f.root / "Headers")) {
    if (p.extension() == ".h" && is_file(p) && normal(p) != normal(umbrella)) read.push_back(normal(p));
  }
  if (read.empty()) {
    for (const fs::path& p : entries_of(f.root / "Modules")) {
      if (p.extension() == ".swiftmodule" && is_dir(p)) {
        *reason = "no Objective-C or C header; Swift interface only";
        return true;
      }
    }
    *reason = "no public header in Headers/ and no module map header";
    return true;
  }
  *out = read;
  return true;
}

// The frameworks the sweep covers, sorted by name: System/Library/Frameworks with those nested in each, and every usr/include module the
// maps declare. Two frameworks of one name are an error.
bool discover(const std::string& sdk, std::vector<Framework>* out, std::string* error) {
  // IR_FRAMEWORKS replaces the SDK's System/Library: a root shaped like it, with Frameworks/ and SubFrameworks/ under it (the generated
  // headers tree). The SDK stays the sysroot of the usr/include modules, which are not read from this root.
  fs::path library = fs::path(sdk) / "System" / "Library";
  if (const char* root_env = std::getenv("IR_FRAMEWORKS")) {
    library = fs::absolute(root_env);
    if (!is_dir(library / "Frameworks")) {
      *error = "IR_FRAMEWORKS names " + library.string() + ", which has no Frameworks folder";
      return false;
    }
  }
  frameworks_in(library / "Frameworks", "", out);
  // the library also holds its SubFrameworks folder (UIUtilities): the same rule, read from the same layout (ruling 1 of v-gen's open points)
  frameworks_in(library / "SubFrameworks", "", out);
  const fs::path include = fs::path(sdk) / "usr" / "include";
  for (const std::string& name : usr_modules_declared(include)) {
    Framework f;
    f.name = name;
    f.base = name;
    f.root = include;
    f.usr = true;
    out->push_back(f);  // its module map is found when it is the framework asked for (main), not for every listing
  }
  // The modules the SDK holds that no framework or module map names: the Swift modules of usr/lib/swift (a folder per module, with no C
  // header of its own) and the frameworks of Developer/Library/Frameworks. A name already listed keeps the entry it has.
  std::set<std::string> named;
  for (const Framework& f : *out) named.insert(f.name);
  for (const fs::path& p : entries_of(fs::path(sdk) / "usr" / "lib" / "swift")) {
    if (p.extension() != ".swiftmodule" || !is_dir(p)) continue;
    Framework f;
    f.name = p.stem().string();
    f.base = f.name;
    f.root = p;
    if (named.insert(f.name).second) out->push_back(f);
  }
  std::vector<Framework> developer;
  frameworks_in(fs::path(sdk) / "Developer" / "Library" / "Frameworks", "", &developer);
  for (const Framework& f : developer) {
    if (named.insert(f.name).second) out->push_back(f);
  }
  std::sort(out->begin(), out->end(), [](const Framework& a, const Framework& b) { return a.name < b.name; });
  for (size_t i = 1; i < out->size(); ++i) {
    if ((*out)[i].name == (*out)[i - 1].name) {
      *error = "two frameworks are named " + (*out)[i].name;
      return false;
    }
  }
  return true;
}

// The census rows: a row of kind census, the framework's own and foreign declaration counts in the name and type cells (ir.lua reads
// them to classify the frameworks that have no shard); then one row of kind census-file per header file a foreign declaration is written
// in, its path under the SDK root in the name cell and the declaration count in the message cell (ir.lua reads them to name the owners).
void census_row(Context& ctx, const char* sdk, CXTranslationUnit tu) {
  Census census{&ctx, sdk, 0, 0, {}};
  clang_visitChildren(clang_getTranslationUnitCursor(tu), census_visit, &census);
  std::string row = cell(ctx.framework) + "\tcensus\t-\t-\town=" + std::to_string(census.own) + "\t-\t-\t-\t-\t-\tforeign=" +
                    std::to_string(census.foreign);
  for (int i = 11; i < kFullColumns; ++i) row += "\t-";
  ctx.out += row + "\n";
  for (const auto& [where, count] : census.files) {
    std::string file_row = cell(ctx.framework) + "\tcensus-file\t-\t-\t" + cell(where) + "\t-\t-\t-\t-\t-\tcount=" + std::to_string(count);
    for (int i = 11; i < kFullColumns; ++i) file_row += "\t-";
    ctx.out += file_row + "\n";
  }
}

int main(int argc, char** argv) {
  // the identity the shard headers record: the libclang version, the SHA-256 of the dylib that runs, and (when IR_SDK names the SDK) the
  // target derived from the SDK (review F8, F10); the enum values are checked first
  if (argc == 2 && std::strcmp(argv[1], "--version") == 0) {
    std::string failure;
    if (!check_enum_values(&failure)) {
      std::fprintf(stderr, "decls: %s\n", failure.c_str());
      return 2;
    }
    std::printf("%s dylib-sha256=%s", text(clang_getClangVersion()).c_str(), libclang_sha256().c_str());
    if (const char* sdk_env = std::getenv("IR_SDK")) std::printf(" target=%s", target_of(fs::absolute(sdk_env)).c_str());
    std::printf("\n");
    return 0;
  }
  // the hash of one text, as the availability hash is computed: ir.lua hashes the availability it merges with this
  if (argc == 3 && std::strcmp(argv[1], "--digest") == 0) {
    std::printf("%s\n", digest16(argv[2]).c_str());
    return 0;
  }
  if (argc == 2 && std::strcmp(argv[1], "--target") == 0) {
    const char* sdk_env = std::getenv("IR_SDK");
    if (sdk_env == nullptr) {
      std::fprintf(stderr, "decls: --target needs IR_SDK (the target is the SDK's)\n");
      return 2;
    }
    std::printf("%s\n", target_of(fs::absolute(sdk_env)).c_str());
    return 0;
  }
  // the flags, in any order: --doc (the doc rows), --list (the frameworks), --timeout SECONDS
  int first = 1;
  bool doc = false, list = false;
  for (;;) {
    if (first < argc && std::strcmp(argv[first], "--doc") == 0) {
      doc = true;
      first += 1;
    } else if (first < argc && std::strcmp(argv[first], "--list") == 0) {
      list = true;
      first += 1;
    } else if (first + 1 < argc && std::strcmp(argv[first], "--timeout") == 0) {
      alarm((unsigned)std::atoi(argv[first + 1]));
      first += 2;
    } else {
      break;
    }
  }
  const char* sdk_env = std::getenv("IR_SDK");
  if (sdk_env == nullptr) {
    std::fprintf(stderr, "decls: IR_SDK must name the iPhoneOS SDK\n");
    return 2;
  }
  const std::string sdk = fs::absolute(sdk_env).string();
  std::vector<Framework> frameworks;
  std::string error;
  if (!discover(sdk, &frameworks, &error)) {
    std::fprintf(stderr, "decls: %s\n", error.c_str());
    return 2;
  }
  if (list) {
    for (const Framework& f : frameworks) std::printf("%s\t%s\n", f.name.c_str(), f.root.string().c_str());
    return 0;
  }
  if (argc - first != 1) {
    usage();
    return 2;
  }
  const std::string name = argv[first];
  const Framework* framework = nullptr;
  for (const Framework& f : frameworks) {
    if (f.name == name) framework = &f;
  }
  if (framework == nullptr) {
    std::fprintf(stderr, "decls: no framework named %s in the SDK\n", name.c_str());
    return 2;
  }
  std::string reason;
  Framework chosen = *framework;
  if (chosen.usr) {
    chosen.map = usr_module_map(chosen.root, chosen.name, &error);
    if (!error.empty() || chosen.map.empty()) {
      std::fprintf(stderr, "decls: %s\n", error.empty() ? ("no module map in usr/include declares the module " + name).c_str() : error.c_str());
      return 2;
    }
  }
  std::vector<std::string> headers;
  headers_of(chosen, &headers, &reason);
  Context ctx;
  ctx.doc = doc;
  ctx.framework = name;
  if (framework->usr) {
    // a header of the include root belongs to the module that names it, not to the root: the root holds other modules' headers too
    std::set<std::string> dirs;
    const std::string include = normal(framework->root);
    for (const std::string& h : headers) {
      fs::path parent = fs::path(h).parent_path();
      if (normal(parent) == include) {
        ctx.own.push_back(h);
      } else {
        dirs.insert(parent.string() + "/");
      }
    }
    ctx.own.insert(ctx.own.end(), dirs.begin(), dirs.end());
  } else {
    ctx.own.push_back(framework->root.string() + "/Headers/");
  }
  if (headers.empty()) {
    if (doc) {
      std::fprintf(stderr, "decls: %s: %s\n", name.c_str(), reason.c_str());
      return 1;
    }
    // a framework with no header is one row of kind unparsed, its reason in the name column, as a framework that does not parse is
    std::string row = name + "\tunparsed\t-\t-\t" + reason;
    for (int i = 5; i < kFullColumns; ++i) row += "\t-";
    std::printf("%s\n", row.c_str());
    return 0;
  }
  // A usr/include module decls cannot build (its module build is an error: the C standard library's obsolete module, whose map names
  // headers no module build accepts) is read a second time as plain headers, included one after another without the module build.
  for (int attempt = 0; attempt < 2; ++attempt) {
    const bool plain = attempt == 1;
    std::string imports;
    // a usr/include module is the SDK's own module, so it is imported as the module its map declares (the module build compiles the
    // headers the map names, with the conditions the module build sets); a framework's headers are included as they are listed, and so
    // are a usr/include module's in the plain attempt
    if (framework->usr && !plain) {
      imports = "@import " + name + ";\n";
    } else {
      for (const std::string& h : headers) imports += "#import \"" + h + "\"\n";
    }
    CXUnsavedFile unsaved = {"charon-module.m", imports.c_str(), (unsigned long)imports.size()};
    // IR_TARGET, if set, is the triple the headers are parsed for (the port's armv7 run, tools/found/port_values.lua); the SDK's own otherwise
    const char* triple = std::getenv("IR_TARGET");
    const std::string target = triple != nullptr ? std::string(triple) : target_of(fs::path(sdk));
    std::vector<const char*> args = {"-x", "objective-c", "-target", target.c_str(), "-isysroot", sdk.c_str()};
    // the module's own map is the one decls resolved, so the compiler is given that file, not a search of the SDK's maps
    std::string module_map_arg = framework->usr ? "-fmodule-map-file=" + chosen.map.string() : std::string();
    if (framework->usr && !plain) {
      args.push_back("-fmodules");
      args.push_back(module_map_arg.c_str());
    }
    // a framework of Developer/Library/Frameworks names its own headers as <Name/...>, which that folder (and only it) is searched for
    const std::string developer_folder = (fs::path(sdk) / "Developer" / "Library" / "Frameworks").string();
    const std::string developer_arg = framework->root.string().rfind(developer_folder, 0) == 0 ? "-F" + developer_folder : std::string();
    if (!developer_arg.empty()) args.push_back(developer_arg.c_str());
    if (const char* resource = std::getenv("IR_RESOURCE")) {
      args.push_back("-resource-dir");
      args.push_back(resource);
    }
    // The doc mode keeps the doc comments of the SDK's own headers. clang drops the comments of a system header unless the frontend is
    // told to retain them (the cc1 option -fretain-comments-from-system-headers, which the driver passes on; the SDK's headers are system
    // headers). The IR does not read comments, so the IR parse keeps the default.
    if (doc) args.push_back("-fretain-comments-from-system-headers");
    args.push_back("-Wno-everything");
    CXIndex index = clang_createIndex(0, 0);
    CXTranslationUnit tu = nullptr;
    CXErrorCode code = clang_parseTranslationUnit2(
        index, "charon-module.m", args.data(), (int)args.size(), &unsaved, 1,
        CXTranslationUnit_SkipFunctionBodies | CXTranslationUnit_DetailedPreprocessingRecord | CXTranslationUnit_IncludeAttributedTypes,
        &tu);
    if (code != CXError_Success || !tu) {
      std::fprintf(stderr, "decls: parse failed for %s (code %d)\n", name.c_str(), (int)code);
      clang_disposeIndex(index);  // every exit releases the index (review F23)
      return 1;
    }
    ctx.tu = tu;
    long errors = 0;
    std::string first_error;
    unsigned n = clang_getNumDiagnostics(tu);
    for (unsigned i = 0; i < n; ++i) {
      CXDiagnostic d = clang_getDiagnostic(tu, i);
      if (clang_getDiagnosticSeverity(d) >= CXDiagnostic_Error) {
        if (errors == 0) {
          // the first error, with the file and line it is in (the header that refused the parse)
          CXFile file = nullptr;
          unsigned line = 0, column = 0, offset = 0;
          clang_getSpellingLocation(clang_getDiagnosticLocation(d), &file, &line, &column, &offset);
          std::string where = file ? text(clang_getFileName(file)) + ":" + std::to_string(line) + ": " : "";
          first_error = cell(where + text(clang_getDiagnosticSpelling(d)));
        }
        ++errors;
      }
      clang_disposeDiagnostic(d);
    }
    // a usr/include module whose module build has errors is read as plain headers instead (the second attempt is the last)
    if (errors > 0 && framework->usr && !plain) {
      clang_disposeTranslationUnit(tu);
      clang_disposeIndex(index);
      continue;
    }
    if (errors == 0) {
      clang_visitChildren(clang_getTranslationUnitCursor(tu), collect_macro_uses, &ctx);
      Nest root{&ctx, "-", "", false, true};
      clang_visitChildren(clang_getTranslationUnitCursor(tu), visit, &root);
      if (!doc) {
        Referenced referenced{&ctx, {}};
        clang_visitChildren(clang_getTranslationUnitCursor(tu), referenced_visit, &referenced);
      }
      resolve(ctx);
      if (!doc) census_row(ctx, sdk.c_str(), tu);
      std::fwrite(ctx.out.data(), 1, ctx.out.size(), stdout);
    } else if (doc) {
      std::fprintf(stderr, "decls: %s: %ld error diagnostics\n", name.c_str(), errors);
      clang_disposeTranslationUnit(tu);
      clang_disposeIndex(index);
      return 1;
    } else {
      // A module that does not parse is one row of kind unparsed, its reason in the name column; no declaration of it is written.
      // The SDK's absolute path is redacted: the snapshot must not depend on where the SDK is installed.
      for (size_t at = first_error.find(sdk); at != std::string::npos; at = first_error.find(sdk, at)) {
        first_error.replace(at, sdk.size(), "<sdk>");
      }
      std::fprintf(stderr, "decls: %s: %ld error diagnostics, first: %s\n", name.c_str(), errors, first_error.c_str());
      // the row has the cells of every row: the reason is the name, the rest are "-"
      std::string row = name + "\tunparsed\t-\t-\t" + first_error;
      for (int i = 5; i < kFullColumns; ++i) row += "\t-";
      std::printf("%s\n", row.c_str());
    }
    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);
    break;
  }
  return 0;
}
