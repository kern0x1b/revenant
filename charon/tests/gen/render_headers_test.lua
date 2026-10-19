-- The round trip of the headers renderer (tools/gen/render_headers.lua, cmd_headers.lua) on a small SDK of our own: its headers are
-- written here (no SDK text), decls reads them to give the IR, the headers command renders the IR into a tree, and decls reads the
-- tree (IR_FRAMEWORKS) and must give back the IR's rows by key and declhash. A mutant, the same IR with one nullability changed,
-- must come back with exactly that difference, named by its cause.
--
-- Needs the extractor built (xmake build -P tools/found). Run, from any folder: xmake l tests/gen/render_headers_test.lua
local REPO = path.directory(path.directory(path.absolute(os.scriptdir())))
local TOOLS = path.join(REPO, "tools")
local FOUND = path.join(TOOLS, "found")
local SCRATCH = path.join(REPO, "build", "gen", "headers-test")
local FRAMEWORK = "HeadersFixture"
local host = import("gen.host", {rootdir = TOOLS, anonymous = true})
local render = import("gen.render_headers", {rootdir = TOOLS, anonymous = true})
local cmd = import("gen.cmd_headers", {rootdir = TOOLS, anonymous = true})
local DECLS = host.target_product(REPO, FOUND, "decls")
local checks = 0

local function expect(condition, message)
    checks = checks + 1
    if not condition then raise("test failed: " .. message) end
end

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"))
    handle:write(text)
    handle:close()
end

-- The port's enumerator values for the write mode: an empty run (no enumerator declared for the triple), so the port keeps the IR's values.
-- The values of the port's triple are tested by tests/gen/port_enums_test.lua and tests/gen/port_values_test.lua.
local PORT_VALUES = path.join(SCRATCH, "port-values-empty.tsv")

local function read(filepath)
    local handle = assert(io.open(filepath, "rb"), "cannot open " .. filepath)
    local text = handle:read("a")
    handle:close()
    return text
end

-- The fixture SDK: a framework with a module map (its header list), a root class, a protocol with a required and an optional member,
-- a subclass that conforms, a category, a block typedef, an enum with constants, a function with a nullable result, and a variable.
-- Every header is a system header, as the SDK's are (the typedef USRs of the IR depend on it).
local SYSTEM = "#pragma clang system_header\n"
local FIXTURE = {
    ["Headers/HFTypes.h"] = SYSTEM .. [[
typedef long HFInteger;
enum HFMode : HFInteger {
  HFModeFirst = 1,
  HFModeSecond = 2,
};
typedef void (^HFBlock)(HFInteger value);
typedef float HFVector __attribute__((ext_vector_type(3)));
typedef struct HFBridged * HFBridgedRef;
typedef HFInteger HFRetired __attribute__((availability(ios,unavailable)));
struct __attribute__((availability(ios,unavailable))) HFRetiredRecord {
  HFRetired tag;
  HFInteger length;
};
#define HF_SWIFT_NAME(name) __attribute__((swift_name(#name)))
typedef HFInteger * HFAliasPointer;
extern HFAliasPointer const HFAliasValue HF_SWIFT_NAME(alias);
enum HFOpaque : HFInteger;
extern const HFInteger HFVersionValue;
extern HFInteger HFOverload(HFInteger a) __attribute__((overloadable));
extern HFInteger HFOverload(double a) __attribute__((overloadable));
HFInteger HFCompute(HFInteger a, HFInteger b);
HFInteger HFPick(HFInteger values[_Nonnull 4]);
typedef struct HFPacket {
  HFInteger kind;
  union {
    struct { HFInteger x; HFInteger y; } point;
    float scale;
  } value;
} HFPacket;
typedef struct HFSample {
  HFInteger kind;
  union {
    HFInteger count;
    float weight;
  };
} HFSample;
]],
    ["Headers/HFObject.h"] = SYSTEM .. [[
#import "HFTypes.h"

@class HFRoot;

@protocol HFCopying
- (nullable HFRoot *)snapshot;
@optional
- (void)prepare;
@property (nonatomic, readonly, getter=isReady) HFInteger ready;
@property (class, nonatomic, readonly, getter=isShared) HFInteger shared;
@end

@protocol HFNamed
- (nullable HFRoot *)name;
@end
typedef id<HFNamed> HFNamed;

@protocol HFRoot <HFCopying>
- (void)describe;
@end

__attribute__((objc_root_class))
@interface HFRoot <HFNamed>
@property (nonatomic, readonly, copy, nullable) HFRoot *parent;
@property (nonatomic, readonly) HFInteger * _Nonnull * _Nullable table;
@property (nonatomic, copy, null_resettable) HFRoot *resettable;
@property (nonatomic, retain) HFBridgedRef bridge __attribute__((NSObject));
- (nonnull instancetype)initWithValue:(HFInteger)value __attribute__((availability(macos,introduced=10.15)));
+ (nullable HFRoot *)rootNamed:(nonnull HFRoot *)other;
@end

__attribute__((availability(ios,introduced=17)))
@interface HFObject : HFRoot <HFCopying>
- (void)runWithBlock:(void (^ _Nonnull)(HFInteger value))block;
- (id<HFRoot>)asRoot;
@end

extern HFRoot * _Nullable HFRootWithTag(HFInteger tag, HFRoot * _Nonnull fallback);

@interface HFBox<Element : HFRoot *, Tag> : HFRoot
- (nullable Element)item;
@property (nonatomic, readonly, nullable) HFBox<HFRoot *, HFRoot *> *peer;
@end

@interface HFBag : HFRoot {
  union {
    HFInteger count;
    float weight;
  };
}
@end
]],
    ["Headers/HFExtras.h"] = SYSTEM .. [[
#import "HFObject.h"

@interface HFRoot (HFExtras) <HFCopying>
- (HFInteger)extraValue;
@end

@interface HFBox<Element : HFRoot *, Tag> (HFBoxExtras)
- (nullable Element)first;
@end
]],
    ["Headers/HFDeclared.h"] = SYSTEM .. [[
#import "HFTypes.h"
#import <stdarg.h>

typedef enum HFMode HFMode;
extern void HFLogArguments(const char * _Nonnull format, va_list arguments);
]],
    ["Headers/HFCycleA.h"] = SYSTEM .. [[
typedef struct HFCycleA * HFCycleARef;
#import "HFCycleB.h"
extern HFCycleBRef _Nullable HFCycleAPair(HFCycleARef _Nullable a);
]],
    ["Headers/HFCycleB.h"] = SYSTEM .. [[
typedef struct HFCycleB * HFCycleBRef;
#import "HFCycleA.h"
extern HFCycleARef _Nullable HFCycleBPair(HFCycleBRef _Nullable b);
]],
    ["Headers/HeadersFixture.h"] = SYSTEM .. [[
#import "HFTypes.h"
#import "HFObject.h"
#import "HFExtras.h"
#import "HFCycleA.h"
#import "HFCycleB.h"
#import "HFDeclared.h"
]],
    ["Modules/module.modulemap"] = [[
framework module HeadersFixture {
  umbrella header "HeadersFixture.h"
  export *
  header "HFTypes.h"
  header "HFObject.h"
  header "HFExtras.h"
  header "HFDeclared.h"
  header "HFCycleA.h"
  header "HFCycleB.h"
}
]],
}

local SDK = path.join(SCRATCH, "sdk")
local IR_SDK_ENV = {IR_SDK = SDK, IR_CONFIG = path.join(SCRATCH, "config")}
-- A framework with no module map (vecLib's kind, listed in fallback.tsv): its umbrella is read first and it reaches a subfolder's header
local PLAIN = "HeadersPlain"
local PLAIN_FIXTURE = {
    ["Headers/HeadersPlain.h"] = SYSTEM .. '#import "HPTop.h"\n#import "Sub/HPSub.h"\n',
    ["Headers/HPTop.h"] = SYSTEM .. "typedef long HPSize;\n",
    ["Headers/Sub/HPInner.h"] = SYSTEM .. "typedef int HPCount;\n",
    ["Headers/Sub/HPSub.h"] = SYSTEM .. [[
#import "../HPTop.h"
#import "HPInner.h"
HPSize HPLength(HPCount a);
int HPSum(HPCount a, HPCount b);
]],
}

os.tryrm(SCRATCH)
for relative, text in pairs(FIXTURE) do
    write(path.join(SDK, "System", "Library", "Frameworks", FRAMEWORK .. ".framework", relative), text)
end
for relative, text in pairs(PLAIN_FIXTURE) do
    write(path.join(SDK, "System", "Library", "Frameworks", PLAIN .. ".framework", relative), text)
end
write(path.join(SDK, "SDKSettings.json"), read(path.join(FOUND, "tests", "fixture", "sdk", "SDKSettings.json")))
write(PORT_VALUES, "# triple=armv7-apple-ios6.1.3 (no values)\n")
write(path.join(SCRATCH, "config", "usr-modules.tsv"), "# no usr/include modules in this fixture\n")
write(path.join(SCRATCH, "config", "fallback.tsv"), "# the frameworks with no module map: the umbrella is read first\n"
    .. PLAIN .. "\tfixture: no module map, its umbrella is read first\n")

-- 1. the IR of the fixture: decls' own rows for the framework (the census row included)
local ir_file = path.join(SCRATCH, "ir.tsv")
local ir_text = os.iorunv(DECLS, {FRAMEWORK}, {envs = IR_SDK_ENV})
write(ir_file, ir_text)
local ir_rows = render.rows_of(ir_text)
local declared = 0
for _, row in ipairs(ir_rows) do
    if row[2] ~= "census" then declared = declared + 1 end
end
expect(declared > 20, "the fixture's IR has its declarations (got " .. declared .. ")")
-- the hash the comparison recomputes is the extractor's: it reproduces the stored hash of every row whose USR has no offset
local stored, reproduced = 0, 0
for _, row in ipairs(ir_rows) do
    local declaration = row[2] ~= "census" and row[2] ~= "unparsed" and row[2] ~= "meta" and row[2] ~= "conflict"
    local located = string.find(row[3], "@[US]@[^@]+@%d+") ~= nil
    if declaration and not located then
        stored = stored + 1
        if render.declaration_hash(row) == row[15] then reproduced = reproduced + 1 end
    end
end
expect(stored > 20 and reproduced == stored,
    "the recomputed declaration hash is the stored one for every row with no offset in its USR (" .. reproduced .. " of " .. stored .. ")")

-- 2. the headers command writes the tree from the IR
local tree = path.join(SCRATCH, "tree")
-- the framework with no module map is written to the same tree (decls reads the tree's frameworks, and fallback.tsv lists it there)
local plain_text = os.iorunv(DECLS, {PLAIN}, {envs = IR_SDK_ENV})
local plain_rows = render.rows_of(plain_text)
local plain_file = path.join(SCRATCH, "plain.tsv")
write(plain_file, plain_text)
expect(cmd.run({tree = REPO, ir = plain_file, sdk = SDK, out = tree, port_values = PORT_VALUES}) == 0, "the headers command writes the framework with no module map")
expect(cmd.run({tree = REPO, ir = ir_file, sdk = SDK, out = tree, port_values = PORT_VALUES}) == 0, "the headers command writes the tree")
local base = path.join(tree, "Frameworks", FRAMEWORK .. ".framework")
local module_map = read(path.join(base, "Modules", "module.modulemap"))
expect(module_map:find('umbrella header "HeadersFixture.h"', 1, true) ~= nil, "the generated module map names the umbrella")
expect(module_map:find('header "HFObject.h"', 1, true) ~= nil, "the generated module map lists HFObject.h")
local object = read(path.join(base, "Headers", "HFObject.h"))
expect(object:find("@interface HFObject : HFRoot <HFCopying>", 1, true) ~= nil,
    "the subclass names its superclass and its protocol")
expect(object:find("@optional", 1, true) ~= nil, "an optional member sits in an @optional section")
expect(object:find("@interface HFBag : HFRoot {\n  union {\n    HFInteger count;\n    float weight;\n  };\n}", 1, true) ~= nil,
    "a class's anonymous union is its ivar block (the IR's anonymous tag with no field naming it)")
expect(read(path.join(base, "Headers", "HFTypes.h")):find("  union {\n    struct {\n      HFInteger x;\n      HFInteger y;\n    } point;\n    float scale;\n  } value;", 1, true) ~= nil,
    "a field whose type is an anonymous struct or union is written in place, with its name after the tag")
expect(read(path.join(base, "Headers", "HFTypes.h")):find("typedef struct HFSample {\n  HFInteger kind;\n  union {\n    HFInteger count;\n    float weight;\n  };\n} HFSample;", 1, true) ~= nil
    or read(path.join(base, "Headers", "HFTypes.h")):find("struct HFSample {\n  HFInteger kind;\n  union {\n    HFInteger count;\n    float weight;\n  };\n};", 1, true) ~= nil,
    "an unnamed struct or union member of a struct is written in it, with no name after its tag (C11)")
expect(object:find("@interface HFBox<Element : HFRoot *, Tag> : HFRoot", 1, true) ~= nil,
    "a generic class declares its type parameters with their bounds, in order (the IR's typeparams)")
expect(read(path.join(base, "Headers", "HFTypes.h")):find("(^HFBlock)", 1, true) ~= nil,
    "a block typedef puts its name in the declarator")
expect(read(path.join(base, "Headers", "HFObject.h")):find("@property (retain, nonatomic) HFBridgedRef bridge __attribute__((NSObject));", 1, true) ~= nil,
    "a property with the NSObject attribute keeps it after its name (the SDK's form), so retain is legal on a CF pointer")
expect(read(path.join(base, "Headers", "HFCycleA.h")):find("typedef struct HFCycleB * HFCycleBRef;", 1, true) ~= nil
    and read(path.join(base, "Headers", "HFCycleA.h")):find('#import "HFCycleB.h"', 1, true) == nil,
    "a pointer typedef of a header that imports this one is written here, not imported (the import would be a cycle)")
expect(read(path.join(base, "Headers", "HFDeclared.h")):find("#import <stdarg.h>", 1, true) ~= nil,
    "a typedef clang's own header gives (va_list) is imported by the public header clang names it for (stdarg.h)")
expect(read(path.join(base, "Headers", "HFCycleB.h")):find("typedef struct HFCycleA * HFCycleARef;", 1, true) ~= nil
    and read(path.join(base, "Headers", "HFCycleB.h")):find('#import "HFCycleA.h"', 1, true) == nil,
    "the other way round: the header that is imported back writes the typedef it uses here")
expect(read(path.join(base, "Headers", "HFObject.h")):find("@protocol HFRoot <HFCopying>", 1, true) ~= nil,
    "a protocol keeps its own conformances when a class of its name lists others (each owner is its USR's kind)")
expect(read(path.join(base, "Headers", "HFObject.h")):find("@interface HFRoot <HFNamed>", 1, true) ~= nil,
    "a class keeps its own conformances when a protocol of its name lists others (each owner is its USR's kind)")
expect(read(path.join(base, "Headers", "HFTypes.h")):find("typedef float HFVector __attribute__((ext_vector_type(3)));", 1, true) ~= nil,
    "a vector typedef puts its name before its attribute, not in front of it")
expect(read(path.join(base, "Headers", "HFTypes.h")):find("struct __attribute__((availability(ios,unavailable))) HFRetiredRecord {", 1, true) ~= nil,
    "a named struct's availability follows its keyword: before the keyword a field's unavailable type is reported")
expect(read(path.join(base, "Headers", "HFExtras.h")):find("@interface HFRoot (HFExtras) <HFCopying>", 1, true) ~= nil,
    "a category lists its own protocols")
expect(object:find("@interface HFRoot <HFNamed>", 1, true) ~= nil and object:find("@interface HFRoot <HFCopying", 1, true) == nil,
    "the class takes its own protocols, not the one its category lists")
expect(read(path.join(base, "Headers", "HFExtras.h")):find("@interface HFBox<Element : HFRoot *, Tag> (HFBoxExtras)", 1, true) ~= nil,
    "a category of a generic class declares its own type parameters")
-- an overload (two declarations of one name, one USR each) is written overloadable on each of its declarations; a function of one
-- declaration is not, and the round trip reads the overloads back as the IR has them
local types_text = read(path.join(base, "Headers", "HFTypes.h"))
expect(string.find(types_text, "HFOverload(HFInteger a) __attribute__((overloadable))", 1, true) ~= nil
    and string.find(types_text, "HFOverload(double a) __attribute__((overloadable))", 1, true) ~= nil
    and string.find(types_text, "HFCompute(HFInteger a, HFInteger b);", 1, true) ~= nil,
    "an overloaded function is declared overloadable on each declaration, and a function of one declaration is not")
local declared_text = read(path.join(base, "Headers", "HFDeclared.h"))
expect(declared_text:find('#import "HFTypes.h"\n', 1, true) ~= nil and declared_text:find("typedef enum HFMode HFMode;", 1, true) ~= nil,
    "a typedef of a tag another header defines imports that header (it does not define the tag)")
local types_text = read(path.join(base, "Headers", "HFTypes.h"))
expect(types_text:find("enum HFOpaque : HFInteger;", 1, true) ~= nil and types_text:find("enum HFOpaque : HFInteger {", 1, true) == nil,
    "an enum the IR gives no constants is declared with its fixed type, not defined")
expect(object:find("@protocol HFNamed;", 1, true) ~= nil and object:find("typedef id<HFNamed> HFNamed;", 1, true) ~= nil,
    "a protocol and a typedef of the same name are both declared")
expect(object:find("@class HFRoot;\n@protocol HFRoot;", 1, true) ~= nil,
    "a class and a protocol of one name are both declared when a header uses both (NSObject is one)")
expect(object:find("@property (readonly, nonatomic, nullable) HFBox<HFRoot *,HFRoot *> * peer", 1, true) ~= nil,
    "a pointer inside a generic's arguments is not a level of the property's own pointer: its nullability is an attribute")
expect(object:find("@property (copy, nonatomic, null_resettable) HFRoot * resettable", 1, true) ~= nil,
    "a null_resettable property keeps its attribute (it has no keyword to take its place)")
expect(object:find("@property (readonly, nonatomic) HFInteger * _Nonnull * _Nullable table;", 1, true) ~= nil,
    "a property of a multi-level pointer takes its nullability in the declarator (a property attribute is rejected there)")
local optional_at = object:find("@optional", 1, true)
local ready_at = object:find("@property (readonly, nonatomic, getter=isReady) HFInteger ready;", 1, true)
expect(optional_at ~= nil and ready_at ~= nil and ready_at > optional_at,
    "an optional property with a getter= is found through its getter's selector, so it sits in the @optional section")
local shared_at = object:find("@property (readonly, nonatomic, class, getter=isShared) HFInteger shared;", 1, true)
expect(optional_at ~= nil and shared_at ~= nil and shared_at > optional_at,
    "an optional class property with a getter= is found through its class getter's selector (a class method), so it sits in @optional")
expect(read(path.join(base, "Headers", "HFTypes.h")):find("HFInteger HFPick(HFInteger values[_Nonnull 4]);", 1, true) ~= nil,
    "an array parameter's nullability is kept in its size's brackets (the SDK's form for a sized array)")

-- 3. the round trip: decls reads the tree and gives back the IR's rows by key and declhash
local decl_text = os.iorunv(DECLS, {FRAMEWORK}, {envs = {IR_SDK = SDK, IR_CONFIG = IR_SDK_ENV.IR_CONFIG, IR_FRAMEWORKS = tree}})
local report = render.compare(ir_rows, render.rows_of(decl_text))
expect(report.ir == report.decls and report.equal == report.ir,
    "the tree reads back every row (IR " .. report.ir .. ", decls " .. report.decls .. ", equal " .. report.equal .. ")")
expect(report.located > 0, "the anonymous struct and union rows match through their USRs, with the offset taken out (" .. report.located .. ")")
local differences = 0
for _, n in pairs(report.causes) do differences = differences + n end
expect(differences == 0, "no difference between the IR and decls over the tree")

-- 4. the mutant: the same IR with the nullability of HFRootWithTag's result changed (l to n) is rendered, and the round trip names it
local mutant_text = ir_text:gsub("[^\n]*\tfunction\t[^\n]*HFRootWithTag[^\n]*", function (line)
    local changed = line:gsub("\tl|", "\tn|", 1)
    expect(changed ~= line, "the mutant changes a nullability cell")
    return changed
end, 1)
local mutant_file = path.join(SCRATCH, "mutant.tsv")
write(mutant_file, mutant_text)
local mutant_tree = path.join(SCRATCH, "mutant-tree")
expect(cmd.run({tree = REPO, ir = mutant_file, sdk = SDK, out = mutant_tree, port_values = PORT_VALUES}) == 0 and cmd.run({tree = REPO, ir = plain_file, sdk = SDK, out = mutant_tree, port_values = PORT_VALUES}) == 0, "the headers command writes the mutant tree")
local mutant_decls = os.iorunv(DECLS, {FRAMEWORK}, {envs = {IR_SDK = SDK, IR_CONFIG = IR_SDK_ENV.IR_CONFIG, IR_FRAMEWORKS = mutant_tree}})
local mutant_report = render.compare(ir_rows, render.rows_of(mutant_decls))
expect(mutant_report.causes["declhash differs, function: nullability"] == 1 and mutant_report.equal == mutant_report.ir - 1,
    "the mutant gives exactly one difference, its nullability (got " .. tostring(mutant_report.causes["declhash differs, function: nullability"]) .. ")")

-- 5. the renderer takes the bound from the IR's typeparams cell: the same IR with HFBox's Element bounded by id renders it unbounded
local unbounded_text, bounds_changed = ir_text:gsub("Element:HFRoot %*", "Element:id")
expect(bounds_changed == 2, "the IR has the bound of HFBox's Element in its class and its category (got " .. bounds_changed .. ")")
local unbounded_file = path.join(SCRATCH, "unbounded.tsv")
write(unbounded_file, unbounded_text)
local unbounded_tree = path.join(SCRATCH, "unbounded-tree")
expect(cmd.run({tree = REPO, ir = unbounded_file, sdk = SDK, out = unbounded_tree, port_values = PORT_VALUES}) == 0 and cmd.run({tree = REPO, ir = plain_file, sdk = SDK, out = unbounded_tree, port_values = PORT_VALUES}) == 0, "the headers command writes the unbounded tree")
local unbounded_base = path.join(unbounded_tree, "Frameworks", FRAMEWORK .. ".framework", "Headers")
expect(read(path.join(unbounded_base, "HFObject.h")):find("@interface HFBox<Element, Tag> : HFRoot", 1, true) ~= nil,
    "an unbounded type parameter of a class is written bare, from the IR's bound")
expect(read(path.join(unbounded_base, "HFExtras.h")):find("@interface HFBox<Element, Tag> (HFBoxExtras)", 1, true) ~= nil,
    "an unbounded type parameter of a category is written bare, from the IR's bound")

-- 6. the framework with no module map: its umbrella is generated from the IR's subfolder headers, and decls reads the subfolder's
-- header back through it (its declarations come back equal)
local plain_umbrella = read(path.join(tree, "Frameworks", PLAIN .. ".framework", "Headers", PLAIN .. ".h"))
expect(plain_umbrella:find('#import "Sub/HPSub.h"', 1, true) ~= nil,
    "a framework with no module map gets an umbrella that includes its subfolder headers (the IR's)")
local plain_sub = read(path.join(tree, "Frameworks", PLAIN .. ".framework", "Headers", "Sub", "HPSub.h"))
expect(plain_sub:find('#import "HPInner.h"\n', 1, true) ~= nil and plain_sub:find('#import "../HPTop.h"\n', 1, true) ~= nil,
    "a header of a subfolder names an import of its own folder's header by that name, and of the top by ../ (the SDK's form)")
local plain_decls = os.iorunv(DECLS, {PLAIN}, {envs = {IR_SDK = SDK, IR_CONFIG = IR_SDK_ENV.IR_CONFIG, IR_FRAMEWORKS = tree}})
local plain_report = render.compare(plain_rows, render.rows_of(plain_decls))
expect(plain_report.ir > 0 and plain_report.decls == plain_report.ir and plain_report.equal == plain_report.ir,
    "the subfolder's rows come back through the umbrella (IR " .. plain_report.ir .. ", decls " .. plain_report.decls .. ", equal " .. plain_report.equal .. ")")

-- 7. a typedef's own row can come first in the IR (PDFKit's PDFDocument.h sorts before PDFSelection.h): the same IR with HFMode's
-- typedef row moved before its enum's row. The typedef's header is not the enum's, so the typedef imports the enum's header; the
-- typedef's own definition is not the one it needs
local ordered = {}
for line in string.gmatch(ir_text, "[^\n]+") do ordered[#ordered + 1] = line end
local enum_at, typedef_at
for i, line in ipairs(ordered) do
    if string.find(line, "^HeadersFixture\tenum\tc:@E@HFMode\t", 1) then enum_at = i end
    if string.find(line, "^HeadersFixture\ttypedef\tc:@T@HFMode\t", 1) then typedef_at = i end
end
expect(enum_at ~= nil and typedef_at ~= nil and typedef_at > enum_at, "the IR has HFMode's enum and its typedef, the enum first")
table.insert(ordered, enum_at, table.remove(ordered, typedef_at))
local order_file = path.join(SCRATCH, "order.tsv")
write(order_file, table.concat(ordered, "\n") .. "\n")
local order_tree = path.join(SCRATCH, "order-tree")
expect(cmd.run({tree = REPO, ir = order_file, sdk = SDK, out = order_tree, port_values = PORT_VALUES}) == 0, "the headers command writes the reordered IR")
expect(read(path.join(order_tree, "Frameworks", FRAMEWORK .. ".framework", "Headers", "HFDeclared.h")):find('#import "HFTypes.h"\n', 1, true) ~= nil,
    "a typedef of a tag another header defines imports that header, when the typedef's own row comes first in the IR")

os.tryrm(SCRATCH)
print("headers_test: " .. checks .. " checks passed")
