-- Run test for the trace layer. The layer writes the stubs of a fixture framework, the host compiler builds them into a program, and
-- the program calls each stub through the Objective-C runtime. Each call logs its selector once to stderr and returns the safe
-- default: nil for an object, 0 for a scalar, NO for BOOL, a zeroed struct, and an NSError in the framework's own domain for an
-- NSError ** parameter. Setters are the selector the property names (setScope:). FKWidget is a class the release lacks: its class
-- object is generated, since every member is a stub. The fixture's typed facts (the type, params and attrs columns of each member, the
-- functions, the typedefs, the declared names and the superclasses) are injected through headers.use, so no header is parsed; the
-- fixture header is written only so that the program compiles. The surface the stubs come from is the framework's declaration shard
-- (surface_shards.lua), which the model reads. The typed rules (the spelling of a type, the kind a type is, the parameters, the NSError
-- ** test) and the stub text are checked case by case.
-- Run: xmake l tests/gen/trace_test.lua (needs clang; exits 1 on any failure). Scratch files live in a folder under
-- .agent-work/runs of this checkout, removed when the test ends. The compile runs with warnings on: its warnings are listed below and
-- any other warning fails the test.

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local shards = import("surface_shards", {rootdir = os.scriptdir(), anonymous = true})

local FRAMEWORK = "FixtureKit"
local FUNCTION_COLUMNS = {"api", "introduced", "status", "reasons", "returns", "params", "decl"}
local LEDGER_COLUMNS = {"kind", "lang", "api", "introduced", "header-introduced", "status", "needs", "reason"}

-- The declaration row of a ledger row, introduced in 7.0: a class (its interface), a property (Class.name) or a method (-[Class sel]
-- or +[Class sel]), with the USR the dump writes for it.
local function objc_row(kind, api)
    if kind == "class" then
        return shards.objc_row("interface", "c:objc(cs)" .. api, nil, nil, nil, "ios=7.0/-/-/0")
    end
    if kind == "property" then
        local cls, name = string.match(api, "^([%w_]+)%.(.+)$")
        return shards.objc_row("property", "c:objc(cs)" .. cls .. "(py)" .. name, nil, nil, nil, "ios=7.0/-/-/0")
    end
    local sign, cls, sel = string.match(api, "^([-+])%[([%w_]+) (.+)%]$")
    local usr = "c:objc(cs)" .. cls .. (sign == "+" and "(cm)" or "(im)") .. sel
    return shards.objc_row("method", usr, nil, nil, nil, "ios=7.0/-/-/0")
end

local HEADER = [==[#import <Foundation/Foundation.h>

@interface FKThing : NSObject
@property (nonatomic, readwrite) NSInteger scope;
@property (nonatomic, readwrite, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, copy) NSString *name;
- (BOOL)setLevel:(NSInteger)level error:(NSError **)error;
- (NSArray *)items;
- (void)reset;
@end

NSInteger FKCountThings(NSInteger count, NSError **error);

// a class the release lacks: the trace layer defines it when every member is a stub
@interface FKWidget : NSObject
@property (nonatomic, readwrite) NSInteger count;
- (BOOL)refreshWithError:(NSError **)error;
- (instancetype)init;
@end

// an init the headers declare unavailable (AV_INIT_UNAVAILABLE in the class body): the trace layer leaves it out, so NSObject's answers
@interface FKRetired : NSObject
- (instancetype)init;
@end
]==]

-- The members the header declares, as the shard's typed columns give them: class, kind, api, type, params and attrs (the spelling of
-- the shard: nullability words inside the types, and the parameters as "TYPE NAME | TYPE NAME").
local MEMBERS = {
    {"FKThing", "property", "-[FKThing scope]", "NSInteger", "-", "nonatomic"},
    {"FKThing", "property", "-[FKThing enabled]", "BOOL", "-", "nonatomic,getter=isEnabled"},
    {"FKThing", "property", "-[FKThing name]", "NSString *", "-", "readonly,copy,nonatomic"},
    {"FKThing", "method", "-[FKThing setLevel:error:]", "BOOL", "NSInteger level | NSError * _Nullable * error", "-"},
    {"FKThing", "method", "-[FKThing items]", "NSArray *", "-", "-"},
    {"FKThing", "method", "-[FKThing reset]", "void", "-", "-"},
    {"FKWidget", "property", "-[FKWidget count]", "NSInteger", "-", "nonatomic"},
    {"FKWidget", "method", "-[FKWidget refreshWithError:]", "BOOL", "NSError * _Nullable * error", "-"},
    -- the 7th column is the shard's availability text: an init the headers flag unavailable on every platform, or none
    {"FKWidget", "method", "-[FKWidget init]", "instancetype", "-", "-", "-"},
    {"FKRetired", "method", "-[FKRetired init]", "instancetype", "-", "-", "*unavailable ios=-/-/-/1"},
}

-- The C function the fixture declares: its type text ("RET (PARAMS)") and its params, as the shard's function row gives them.
local FUNCTION_TYPE = "NSInteger (NSInteger, NSError * _Nullable *)"
local FUNCTION_PARAMS = "NSInteger count | NSError * _Nullable * error"

-- More C functions of the fixture, each a generable row of the snapshot with its typed fact: {name, type text, params, declaration}. The
-- hand sources (HAND_SOURCE) define FKHandMade and FKMultiLine, so no stub; FKOwed has an owed registry row and no definition, so no stub
-- either; FKStatic is static and FKProto a prototype only, so the trace layer stubs both.
local EXTRA_FUNCTIONS = {
    {"FKHandMade", "NSInteger (void)", "-", "NSInteger FKHandMade(void)"},
    {"FKMultiLine", "NSInteger (NSInteger, NSInteger)", "NSInteger a | NSInteger b", "NSInteger FKMultiLine(NSInteger a, NSInteger b)"},
    {"FKOwed", "NSInteger (void)", "-", "NSInteger FKOwed(void)"},
    {"FKStatic", "NSInteger (void)", "-", "NSInteger FKStatic(void)"},
    {"FKProto", "NSInteger (void)", "-", "NSInteger FKProto(void)"},
}

local HAND_SOURCE = [==[#import <Foundation/Foundation.h>

// the port's own definitions: a brace on the line after the parameter list, and a signature over two lines
NSInteger FKHandMade(void)
{
    return 0;
}

NSInteger FKMultiLine(NSInteger a,
                      NSInteger b)
{
    return a + b;
}

// a static definition is no public function
static NSInteger FKStatic(void)
{
    return 0;
}

// a prototype is no definition
NSInteger FKProto(void);
]==]

local OWED_REGISTRY = [==[{"framework": "FixtureKit", "entries": [
  {"api": "FKOwed()", "kind": "function", "introduced": "16.0", "status": "owed", "reason": "fixture: the port defines none",
   "effect": "fixture", "facts": "-", "source": "fixture"}
]}
]==]

-- The typed function facts the headers give: the fixture's declared function and each of EXTRA_FUNCTIONS.
local FUNCTIONS = {FKCountThings = {type = FUNCTION_TYPE, params = FUNCTION_PARAMS}}
for _, f in ipairs(EXTRA_FUNCTIONS) do
    FUNCTIONS[f[1]] = {type = f[2], params = f[3]}
end

-- The ledger rows of the release that lacks every member: the class and each member, by the api the ledger spells.
local LEDGER = {
    {"property", "FKThing.scope"}, {"property", "FKThing.enabled"}, {"property", "FKThing.name"},
    {"method", "-[FKThing setLevel:error:]"}, {"method", "-[FKThing items]"}, {"method", "-[FKThing reset]"},
    {"class", "FKWidget"}, {"property", "FKWidget.count"}, {"method", "-[FKWidget refreshWithError:]"},
    {"method", "-[FKWidget init]"}, {"method", "-[FKRetired init]"},
}

-- The lines the program must log, each once, and nothing else.
local EXPECTED_LOG = {
    "unimplemented: FixtureKit -[FKWidget count]", "unimplemented: FixtureKit -[FKWidget setCount:]",
    "unimplemented: FixtureKit -[FKWidget refreshWithError:]", "unimplemented: FixtureKit -[FKWidget init]",
    "unimplemented: FixtureKit -[FKThing setScope:]", "unimplemented: FixtureKit -[FKThing scope]",
    "unimplemented: FixtureKit -[FKThing isEnabled]", "unimplemented: FixtureKit -[FKThing setEnabled:]",
    "unimplemented: FixtureKit -[FKThing setLevel:error:]", "unimplemented: FixtureKit -[FKThing items]",
    "unimplemented: FixtureKit -[FKThing reset]", "unimplemented: FixtureKit -[FKThing name]",
    "unimplemented: FixtureKit FKCountThings",
}

-- The warnings the compile gives, by flag, with the reason each is expected (the test fails on any other). -Wincomplete-implementation: the
-- program's @implementation FKThing has none of the three methods, which the stubs define in their category in another unit. -Wobjc-
-- protocol-method-implementation: the stub category implements the three methods the header declares for FKThing (the trace layer
-- overrides a class's own method by a category, one per stub). Neither is a fault of the fixture's values; a new flag fails the test.
local EXPECTED_WARNINGS = {["-Wincomplete-implementation"] = 3, ["-Wobjc-protocol-method-implementation"] = 3}

local PROGRAM = [==[#import <FixtureKit/FixtureKit.h>
#include <stdio.h>

// the class itself is the framework's to define; every member is the trace layer's stub, in its category
@implementation FKThing
@end

// FKWidget is not defined here: the trace layer's class object is the only definition

static int failures = 0;

#define CHECK(cond, label) do { if (!(cond)) { failures++; printf("FAIL %s\n", label); } else { printf("ok   %s\n", label); } } while (0)

int main(void) {
    @autoreleasepool {
        FKThing *thing = [[FKThing alloc] init];
        CHECK([thing scope] == 0, "getter returns 0 for an integer property");
        [thing setScope:5];
        [thing setScope:6];
        CHECK([thing isEnabled] == NO, "getter with getter= returns NO for BOOL");
        [thing setEnabled:YES];
        NSError *error = nil;
        CHECK([thing setLevel:1 error:&error] == NO, "method with NSError ** returns NO");
        CHECK(error != nil && [[error domain] isEqualToString:@"FixtureKit.Unimplemented"] && [error code] == -1,
              "NSError ** is set in the framework's domain with code -1");
        CHECK([thing items] == nil, "method returning an object returns nil");
        [thing reset];
        CHECK([thing name] == nil, "readonly object property returns nil");
        NSError *countError = nil;
        // init is a stub and returns nil, the safe default for an object: the instance is kept from alloc, and init is called for its log line
        FKWidget *widget = [FKWidget alloc];
        (void)[widget init];
        CHECK([widget count] == 0, "class object: integer property returns 0");
        [widget setCount:2];
        NSError *widgetError = nil;
        CHECK([widget refreshWithError:&widgetError] == NO, "class object: method with NSError ** returns NO");
        CHECK(FKCountThings(3, &countError) == 0, "C function returns 0 for an integer result");
        CHECK(countError != nil && [[countError domain] isEqualToString:@"FixtureKit.Unimplemented"],
              "C function sets an NSError ** in the framework's domain");
    }
    return failures ? 1 : 0;
}
]==]

-- The member records the stub rule gives each case (the fields stubs.members and stubs.functions keep), and the text the stub of each
-- must have: the signature composed from the typed fields, then the body (the log line once, the error in the framework's domain, the
-- zero of the type).
local function log_of(api)
    return 'static BOOL charon_logged = NO; if (!charon_logged) { charon_logged = YES; fprintf(stderr, "unimplemented: FixtureKit %s\\n", "' .. api .. '"); }'
end
local ERROR = 'if (error) { *error = [NSError errorWithDomain:@"FixtureKit.Unimplemented" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"%s is not implemented by the port"}]; } '
local STUB_CASES = {
    {member = {api = "-[FKThing setLevel:error:]", kind = "method", sign = "-", selector = "setLevel:error:", type_text = "BOOL",
               zero = "scalar", params = {{type = "NSInteger", name = "level"}, {type = "NSError **", name = "error"}}, error_arg = "error"},
     text = '- (BOOL)setLevel:(NSInteger)level error:(NSError **)error { ' .. log_of("-[FKThing setLevel:error:]")
            .. " " .. string.format(ERROR, "-[FKThing setLevel:error:]") .. "return 0; }"},
    -- an empty keyword (the header's ":(NSInteger)h" after "resizeTo:(NSInteger)w"): the selector keeps the empty word, and each
    -- parameter stays with its own word
    {member = {api = "-[FKThing resizeTo::scale:]", kind = "method", sign = "-", selector = "resizeTo::scale:", type_text = "BOOL",
               zero = "scalar", params = {{type = "NSInteger", name = "w"}, {type = "NSInteger", name = "h"}, {type = "NSInteger", name = "s"}}},
     text = "- (BOOL)resizeTo:(NSInteger)w :(NSInteger)h scale:(NSInteger)s { " .. log_of("-[FKThing resizeTo::scale:]") .. " return 0; }"},
    {member = {api = "-[FKThing items]", kind = "method", sign = "-", selector = "items", type_text = "NSArray *", zero = "object",
               params = {}},
     text = "- (NSArray *)items { " .. log_of("-[FKThing items]") .. " return nil; }"},
    {member = {api = "-[FKThing reset]", kind = "method", sign = "-", selector = "reset", type_text = "void", zero = "void", params = {}},
     text = "- (void)reset { " .. log_of("-[FKThing reset]") .. "  }"},
    {member = {api = "-[FKThing scope]", kind = "property-get", sign = "-", selector = "scope", type_text = "NSInteger", zero = "scalar",
               params = {}, name = "scope"},
     text = "- (NSInteger)scope { " .. log_of("-[FKThing scope]") .. " return 0; }"},
    {member = {api = "-[FKThing setScope:]", kind = "property-set", sign = "-", selector = "setScope:", type_text = "NSInteger",
               zero = "void", params = {}, name = "scope"},
     text = "- (void)setScope:(NSInteger)value { " .. log_of("-[FKThing setScope:]") .. "  }"},
    {member = {api = "-[FKThing rect]", kind = "method", sign = "-", selector = "rect", type_text = "CGRect", zero = "struct", params = {}},
     text = "- (CGRect)rect { " .. log_of("-[FKThing rect]") .. " return (CGRect){0}; }"},
    {member = {api = "+[FKThing shared]", kind = "property-get", sign = "+", selector = "shared", type_text = "BOOL",
               zero = "scalar", params = {}, name = "shared"},
     text = "+ (BOOL)shared { " .. log_of("+[FKThing shared]") .. " return 0; }"},
    {member = {api = "+[FKThing setShared:]", kind = "property-set", sign = "+", selector = "setShared:", type_text = "BOOL",
               zero = "void", params = {}, name = "shared"},
     text = "+ (void)setShared:(BOOL)value { " .. log_of("+[FKThing setShared:]") .. "  }"},
    {member = {api = "FKCountThings", kind = "function", sign = "", selector = "FKCountThings", type_text = "NSInteger", zero = "scalar",
               params = {{type = "NSInteger", name = "count"}, {type = "NSError **", name = "error"}}, error_arg = "error"},
     text = "NSInteger FKCountThings(NSInteger count, NSError **error) { " .. log_of("FKCountThings") .. " "
            .. string.format(ERROR, "FKCountThings") .. "return 0; }"},
    {member = {api = "FKFill", kind = "function", sign = "", selector = "FKFill", type_text = "void", zero = "void",
               params = {{type = "CGSize[]", name = "buffer"}}},
     text = "void FKFill(CGSize buffer[]) { " .. log_of("FKFill") .. "  }"},
    {member = {api = "FKMake", kind = "function", sign = "", selector = "FKMake", type_text = "FKThing *", zero = "object", params = {}},
     text = "FKThing *FKMake(void) { " .. log_of("FKMake") .. " return NULL; }"},
    {member = {api = "-[FKThing copyWithError:]", kind = "method", sign = "-", selector = "copyWithError:", type_text = "id",
               zero = "object", params = {{type = "NSError **", name = "error"}}, error_arg = "error"},
     text = "- (id)copyWithError:(NSError **)error { " .. log_of("-[FKThing copyWithError:]") .. " "
            .. string.format(ERROR, "-[FKThing copyWithError:]") .. "return nil; }"},
}

local function checks()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    return check, function() return failures end, function() return count end
end

-- The typed rules: the canonical spelling of a type, the kind a type is through the typedefs, the parameters of a method or a
-- function, the NSError ** test, the return type of a C function, and the attributes of a property.
local function test_typed_rules(check)
    local decl = import("gen.decl", {rootdir = TOOLS, anonymous = true})
    local function same(label, got, want)
        check(got == want, string.format("%s: got %q, want %q", label, tostring(got), tostring(want)))
    end
    local index = {FKFlags = "enum FKFlags", FKBox = "struct FKBoxS", FKAlias = "FKOther", FKOther = "long", FKCount = "unsigned int",
                   FKTypedefObj = "NSString *", CFStringRef = "const struct __CFString *", CGRect = "struct CGRect",
                   CBLAS_TRANSPOSE = "enum CBLAS_TRANSPOSE", A = "B", B = "C", C = "D", D = "E", E = "F", F = "G", G = "long",
                   LOOP_A = "LOOP_B", LOOP_B = "LOOP_A", SELF = "SELF",
                   FKVector3 = "float __attribute__((ext_vector_type(3)))", FKVectorAlias = "FKVector3", FKKernel = "int"}
    same("canonical drops nullability", decl.canonical("NSString * _Nullable", index), "NSString *")
    same("canonical joins the stars of a nullable out-error", decl.canonical("NSError * _Nullable * _Nullable", index), "NSError **")
    same("canonical attached nullability", decl.canonical("NSString *_Nullable", index), "NSString *")
    same("canonical keeps a block's parameters", decl.canonical("id  _Nullable (^)(NSError * _Nonnull, NSErrorUserInfoKey _Nonnull)",
         index), "id (^)(NSError *, NSErrorUserInfoKey)")
    same("canonical drops an availability macro", decl.canonical("API_AVAILABLE NSString *", index), "NSString *")
    same("canonical drops a macro with an underscore", decl.canonical("__TVOS_PROHIBITED NSString *", index), "NSString *")
    same("canonical keeps a typedef named in capitals", decl.canonical("CBLAS_TRANSPOSE", index), "CBLAS_TRANSPOSE")
    same("canonical keeps __kindof", decl.canonical("__kindof UIView *", index), "__kindof UIView *")
    local kinds = {
        {"void", "void"}, {"NSInteger", "scalar"}, {"NSString *", "object"}, {"id", "object"}, {"instancetype", "object"},
        {"CGRect", "struct"}, {"FKFlags", "scalar"}, {"FKBox", "struct"}, {"FKAlias", "scalar"},
        -- a chain of seven typedefs (A through G, then long) is followed to its end: there is no depth cap
        {"A", "scalar"},
        -- a typedef cycle is not followed: the kind is unknown (nil), and the walk stops
        {"LOOP_A", nil}, {"SELF", nil},
        {"NSUInteger", "scalar"}, {"CBLAS_TRANSPOSE", "scalar"}, {"FKCount", "scalar"}, {"FKTypedefObj", "object"},
        {"const NSInteger", "scalar"}, {"NSArray<NSString *> *", "object"}, {"BOOL", "scalar"}, {"_Bool", "scalar"},
        {"char *", "object"}, {"enum Thing", "scalar"}, {"struct Thing", "struct"}, {"void (^)(int)", "object"},
        {"NoSuchType", nil}, {"CFStringRef", "object"},
        -- a vector typedef (simd's float3, and a typedef of it) is a value a compound literal zeroes as a struct is; a chain to int is a scalar
        {"FKVector3", "struct"}, {"FKVectorAlias", "struct"}, {"float __attribute__((ext_vector_type(3)))", "struct"},
        {"FKKernel", "scalar"},
    }
    for _, case in ipairs(kinds) do
        same("kind_of " .. case[1], decl.kind_of(case[1], index), case[2])
    end
    local params = decl.parse_params("NSInteger level | NSError * _Nullable * error", index)
    check(#params == 2 and params[1].type == "NSInteger" and params[1].name == "level" and params[2].type == "NSError **"
          and params[2].name == "error", "parse_params names the parameters and spells the out-error")
    check(decl.is_error_out("NSError * _Nullable *", index) and decl.is_error_out("NSError **", index)
          and not decl.is_error_out("NSError *", index), "is_error_out is NSError ** once the nullability words are gone")
    local unnamed = decl.parse_params("ColorSyncProfileRef | unsigned int | struct CGRect | long long count | NSString *const", index)
    check(#unnamed == 5 and unnamed[1].name == nil and unnamed[2].name == nil and unnamed[3].name == nil
          and unnamed[4].name == "count" and unnamed[5].name == nil, "parse_params leaves a type-only parameter unnamed")
    local block = decl.parse_params("void (^)(BOOL, NSError * _Nullable) completionHandler", index)
    same("a block parameter's type", block[1].type, "void (^)(BOOL, NSError *)")
    same("a block parameter's name", block[1].name, "completionHandler")
    check(#decl.parse_params("-", index) == 0 and #decl.parse_params("", index) == 0, "no params column is no parameters")
    same("function_return", decl.function_return("NSInteger (NSInteger, NSError * _Nullable *)", index), "NSInteger")
    same("function_return of a pointer", decl.function_return("FKThing * (void)", index), "FKThing *")
    same("function_return with a block parameter", decl.function_return("void (void (^)(BOOL))", index), "void")
    same("function_return of a type that closes with no group", decl.function_return("void", index), nil)
    same("attribute_value getter", decl.attribute_value("nonatomic,getter=isEnabled", "getter"), "isEnabled")
    same("attribute_value without one", decl.attribute_value("-", "getter"), nil)
    check(decl.has_attribute("readonly,copy", "readonly") and not decl.has_attribute("copy,nonatomic", "readonly"),
          "has_attribute reads the bare attribute names")
    same("member_name", decl.member_name("-[FKThing scope]"), "scope")
end

-- The selectors of the hand sources (hand.lua reads them through selector_of).
local function test_selectors(check)
    local decl = import("gen.decl", {rootdir = TOOLS, anonymous = true})
    local function same(label, got, want)
        check(got == want, string.format("%s: got %q, the oracle's %q", label, tostring(got), want))
    end
    local selectors = {
        {"- (BOOL)setLevel:(NSInteger)level error:(NSError **)error", "setLevel:error:"},
        {"+ (id)make", "make"},
        {"- (void)reset", "reset"},
        {"-(void)foo:(int)a bar:(int)b", "foo:bar:"},
        {"- (void)1x", "x"},
        {"- (void (^)(int))block:(int)a", "block:"},
        {"- (void)a(b(c))d:(x)", "d:"},
        {"- (NSString *)nameWithNullable:(nullable NSString *)s", "nameWithNullable:"},
        {"- (void)9abc:(int)q", "abc:"},
        {"- (int)x3 y_z:(int)q", "y_z:"},
        -- an empty keyword: the name before it is the previous parameter's, not a keyword
        {"+ (CIImage *)imageWithImageProvider:(id)provider size:(size_t)width :(size_t)height format:(CIFormat)format",
         "imageWithImageProvider:size::format:"},
        {"- (void)resizeTo:(int)w :(int)h scale:(int)s", "resizeTo::scale:"},
        {"- (void)size:(int)w\n :(int)h", "size::"},
        {"- (void)setA:(int)a :(int)b :(int)c", "setA:::"},
    }
    for _, case in ipairs(selectors) do
        same("selector_of " .. case[1], decl.selector_of(case[1]), case[2])
    end
end

-- A class with every member stubbed is generated unless its superclass is one of the framework's candidates that is not generated (the
-- oracle's rule: a superclass the framework does not list is taken to be in the release). The class decisions read the superclass
-- the header parse names (the injected supers), not a header.
local function test_superclass(check)
    local classes = import("gen.classes", {rootdir = TOOLS, anonymous = true})
    local surface = import("gen.surface", {rootdir = TOOLS, anonymous = true})
    local function decide(super)
        -- C1 has a stubbed member; Base, a candidate of the framework, has a member no stub answers, so Base is not generated
        local rows = {{kind = "method", api = "-[C1 m]", lang = "objc"}, {kind = "method", api = "-[Base m]", lang = "objc"}}
        local led6 = {[surface.key("class", "C1")] = "missing", [surface.key("method", "-[C1 m]")] = "missing",
                      [surface.key("class", "Base")] = "missing", [surface.key("method", "-[Base m]")] = "missing"}
        local spec = {{kind = "method", api = "-[C1 m]", cls = "C1"}, {kind = "method", api = "-[Base m]", cls = "Base"}}
        return classes.decisions({tree = "/nonexistent-tree", fw = FRAMEWORK, spec = spec, stub_keys = {["-[C1 m]"] = true},
                                  overridden = {}, surface = rows, led6 = led6, skip_reasons = {}, supers = {C1 = super}})
    end
    local under_base = decide("Base").C1
    check(under_base.generated == false and under_base.reason == "superclass Base is neither in the release nor generated",
          "a class whose superclass is a candidate that is not generated is not generated: " .. under_base.reason)
    check(decide("NSObject").C1.generated == true, "a class under a superclass the framework does not list is generated")
end

-- A class whose member the 6.1.3 ledger does not list is not generated: the member is not checked, so the class cannot claim it is a
-- stub (the member has no stub, and its reason is the stubs' not checked at 6.1.3).
local function test_unchecked_member(check)
    local classes = import("gen.classes", {rootdir = TOOLS, anonymous = true})
    local surface = import("gen.surface", {rootdir = TOOLS, anonymous = true})
    local rows = {{kind = "method", api = "-[C2 m]", lang = "objc"}, {kind = "method", api = "-[C2 n]", lang = "objc"}}
    local led6 = {[surface.key("class", "C2")] = "missing", [surface.key("method", "-[C2 m]")] = "missing"}
    local spec = {{kind = "method", api = "-[C2 m]", cls = "C2"}, {kind = "method", api = "-[C2 n]", cls = "C2"}}
    local decision = classes.decisions({tree = "/nonexistent-tree", fw = FRAMEWORK, spec = spec, stub_keys = {["-[C2 m]"] = true},
                                        overridden = {}, surface = rows, led6 = led6, skip_reasons = {["-[C2 n]"] = surface.not_checked_state()},
                                        supers = {C2 = "NSObject"}}).C2
    check(decision.generated == false and string.find(decision.reason, "not checked at 6.1.3", 1, true) ~= nil,
          "a class with a member the ledger does not list is not generated: " .. decision.reason)
end

-- The stub text is composed from the typed fields: the signature and the body of each case.
local function test_stub_text(check)
    local stubs = import("gen.stubs", {rootdir = TOOLS, anonymous = true})
    for _, case in ipairs(STUB_CASES) do
        local got = stubs.stub_text(FRAMEWORK, case.member)
        check(got == case.text, "stub text of " .. case.member.api .. " is composed from the typed fields: " .. got)
    end
end

-- Writes the fixture: the SDK header, the spec and the functions snapshot, the ledger and the surface table of the corpus, and the
-- injected facts. Returns the tree, the SDK and the corpus.
local function write_fixture(root)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local layout = import("gen.layout", {rootdir = TOOLS, anonymous = true})
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local headers = import("gen.headers", {rootdir = TOOLS, anonymous = true})
    local release_fixture = import("release_fixture", {rootdir = os.scriptdir(), anonymous = true})
    local sdk = release_fixture.write(root, {FRAMEWORK})
    emit.file(path.join(sdk, "System", "Library", "Frameworks", FRAMEWORK .. ".framework", "Headers", FRAMEWORK .. ".h"), HEADER)
    local tree = path.join(root, "tree")
    os.mkdir(tree)
    os.cp(TOOLS, path.join(tree, "tools"))
    os.cp(path.join(TOOLS, "..", "modules"), path.join(tree, "modules"))
    local rows = {}
    for _, m in ipairs(MEMBERS) do
        local cells = {}
        for _, column in ipairs(layout.constants().SPEC_COLUMNS) do
            cells[column] = "-"
        end
        cells.kind, cells.api, cells.cls = m[2], m[3], m[1]
        cells.key = (string.gsub(m[3], "[^%w]+", "_"))
        cells.hash = string.rep("0", 16)
        local row = {}
        for i, column in ipairs(layout.constants().SPEC_COLUMNS) do
            row[i] = cells[column]
        end
        table.insert(rows, row)
    end
    emit.file(layout.spec_path(tree, FRAMEWORK, "26.2"), tsv.table_text(layout.constants().SPEC_COLUMNS, rows))
    local function_rows = {{"FKCountThings", "-", "generable", "", "NSInteger", "NSInteger count; NSError **error",
                            "NSInteger FKCountThings(NSInteger count, NSError **error)"}}
    for _, f in ipairs(EXTRA_FUNCTIONS) do
        table.insert(function_rows, {f[1], "-", "generable", "", "NSInteger", f[3], f[4]})
    end
    emit.file(path.join(layout.snap_dir(tree, FRAMEWORK), "functions.tsv"), tsv.table_text(FUNCTION_COLUMNS, function_rows))
    emit.file(path.join(tree, layout.constants().SOURCES_ROOT, FRAMEWORK, "FixtureHand.m"), HAND_SOURCE)
    emit.file(path.join(tree, layout.registry_dir(FRAMEWORK), "ios16.json"), OWED_REGISTRY)
    local corpus = path.join(root, "corpus")
    local corpus_fixture = import("surface_corpus", {rootdir = os.scriptdir(), anonymous = true})
    corpus_fixture.write(corpus)
    local ledger, surface = {}, {}
    for _, row in ipairs(LEDGER) do
        table.insert(ledger, {row[1], "objc", row[2], "7.0", "7.0", "missing", "-", "fixture"})
        table.insert(surface, objc_row(row[1], row[2]))
    end
    emit.file(path.join(root, "ledger-rows", FRAMEWORK .. ".tsv"), tsv.table_text(LEDGER_COLUMNS, ledger))
    shards.write(tree, FRAMEWORK, surface, nil)
    headers.use(function(fw, sdk_dir)
        local members = {}
        for _, m in ipairs(MEMBERS) do
            table.insert(members, {cls = m[1], kind = m[2], api = m[3], type = m[4], params = m[5], attrs = m[6],
                                   availability = m[7] or "-"})
        end
        -- the base types the members spell are declared by the SDK's own shards (ObjectiveC, Foundation), so the fixture declares them too
        return {members = members, declared = {FKThing = true, FKWidget = true, FKRetired = true, NSObject = true, BOOL = true,
                NSInteger = true, NSError = true, NSArray = true, NSString = true},
                typedefs = {NSInteger = "long", NSUInteger = "unsigned long", BOOL = "signed char"},
                superclasses = {FKThing = "NSObject", FKWidget = "NSObject", FKRetired = "NSObject"},
                functions = FUNCTIONS}
    end)
    return tree, sdk, corpus
end

-- Compiles the stubs with the program, runs it, and returns the compile status, the compiler's diagnostics (its standard error), the run
-- status and the program's lines (stdout and stderr together).
local function build_and_run(root, tree, sdk)
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    local stream = import("gen.stream", {rootdir = TOOLS, anonymous = true})
    local trace_files = import("gen.trace_files", {rootdir = TOOLS, anonymous = true})
    local program = path.join(root, "main.m")
    emit.file(program, PROGRAM)
    local binary = path.join(root, "run")
    local frameworks = path.join(sdk, "System", "Library", "Frameworks")
    local compiled, diagnostics = stream.run("clang", {"-fobjc-arc", "-DCHARON_TRACE_DEFAULTS", "-F", frameworks, "-I",
                                                        path.join(frameworks, FRAMEWORK .. ".framework", "Headers"), "-framework",
                                                        "Foundation", program, trace_files.defaults_file(tree, FRAMEWORK), "-o", binary},
                                             function() end)
    local output = {}
    if compiled ~= 0 then
        return compiled, diagnostics, nil, output
    end
    local ran = stream.lines("sh", {"-c", "'" .. binary .. "' 2>&1"}, function(line)
        table.insert(output, line)
    end)
    return compiled, diagnostics, ran, output
end

-- The warnings of a compile, counted by their flag ("[-Wincomplete-implementation]" -> "-Wincomplete-implementation"). A warning with no
-- flag is counted as "(none)".
local function warnings_by_flag(diagnostics)
    local counts = {}
    for line in string.gmatch(diagnostics or "", "[^\n]+") do
        if string.find(line, ": warning: ", 1, true) then
            local flag = string.match(line, "%[(%-W[%w%-]+)%]$") or "(none)"
            counts[flag] = (counts[flag] or 0) + 1
        end
    end
    return counts
end

local function test_trace_run(check, root)
    local trace = import("gen.cmd_trace", {rootdir = TOOLS, anonymous = true})
    local nsobject = import("gen.nsobject", {rootdir = TOOLS, anonymous = true})
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local files = import("gen.files", {rootdir = TOOLS, anonymous = true})
    local trace_files = import("gen.trace_files", {rootdir = TOOLS, anonymous = true})
    local tree, sdk, corpus = write_fixture(root)
    local status = trace.run({tree = tree, framework = FRAMEWORK, sdk = sdk, coordination = corpus, ledger_rows = path.join(root, "ledger-rows")})
    check(status == 0, "the trace layer writes the fixture")
    local compiled, diagnostics, ran, output = build_and_run(root, tree, sdk)
    check(compiled == 0, "the stubs compile with CHARON_TRACE_DEFAULTS")
    if compiled ~= 0 then
        print(diagnostics)
        return
    end
    local warned = warnings_by_flag(diagnostics)
    for flag, n in pairs(warned) do
        check(EXPECTED_WARNINGS[flag] == n, string.format("compiler warnings: %d of %s, listed as %s", n, flag, tostring(EXPECTED_WARNINGS[flag])))
    end
    for flag, n in pairs(EXPECTED_WARNINGS) do
        check(warned[flag] == n, string.format("compiler warnings: the listed %s did not occur %d times", flag, n))
    end
    local logged, seen = {}, {}
    for _, line in ipairs(output) do
        if string.sub(line, 1, #"unimplemented:") == "unimplemented:" then
            table.insert(logged, line)
            seen[line] = (seen[line] or 0) + 1
        else
            print(line)
        end
    end
    local expected = {}
    for _, line in ipairs(EXPECTED_LOG) do
        expected[line] = true
        check(seen[line] == 1, string.format("log line logged %d times, expected once: %s", seen[line] or 0, line))
    end
    for _, line in ipairs(logged) do
        check(expected[line] == true, "unexpected log line: " .. line)
    end
    local decided = {}
    for _, row in ipairs(tsv.records(files.read_text(trace_files.classes_file(tree, FRAMEWORK)))) do
        decided[row.class] = row.generated
    end
    check(decided.FKWidget == "yes", "FKWidget is a generated class object: " .. tostring(decided.FKWidget))
    local skipped = {}
    for _, row in ipairs(tsv.records(files.read_text(trace_files.skipped_file(tree, FRAMEWORK)))) do
        skipped[row.api] = row.reason
    end
    check(skipped["-[FKRetired init]"] == nsobject.unavailable_reason("26.2"),
          "the init the headers declare unavailable is left out with its reason: " .. tostring(skipped["-[FKRetired init]"]))
    check(skipped["-[FKWidget init]"] == nil, "the init the surface lists and the headers declare available is kept")
    check(nsobject.declared_unavailable("*unavailable ios=-/-/-/1") and not nsobject.declared_unavailable("ios=11.0/100000/-/0"),
          "the availability flag is read from the flag column only")
    local hand = import("gen.hand", {rootdir = TOOLS, anonymous = true})
    local defined = hand.functions(tree)
    check(defined.FKHandMade and defined.FKMultiLine and not defined.FKStatic and not defined.FKProto and not defined.FKOwed,
          "the hand sources define the public functions with a body, and no static one, prototype, or owed one")
    local stubbed = {}
    for _, row in ipairs(tsv.records(files.read_text(trace_files.stubs_file(tree, FRAMEWORK)))) do
        stubbed[row.api] = row.kind
    end
    for _, name in ipairs({"FKHandMade", "FKMultiLine", "FKOwed"}) do
        check(stubbed[name .. "()"] == nil, "a C function the port defines or the registry owes gets no stub: " .. name)
        check(skipped[name .. "()"] == "override or hand implementation",
              "... and is left out with its reason: " .. tostring(skipped[name .. "()"]))
    end
    for _, name in ipairs({"FKCountThings", "FKStatic", "FKProto"}) do
        check(stubbed[name .. "()"] == "function", "a C function the port does not define publicly is stubbed: " .. name)
    end
    check(ran == 0, "the program reported no failures (exit " .. tostring(ran) .. ")")
end

function main()
    local check, failures, count = checks()
    test_typed_rules(check)
    test_selectors(check)
    test_superclass(check)
    test_unchecked_member(check)
    test_stub_text(check)
    local root = path.join(os.scriptdir(), "..", "..", ".agent-work", "runs", "trace-test-" .. tostring(os.time()) .. "-"
                           .. tostring(math.random(1000000)))
    os.mkdir(root)
    local err = nil
    try {
        function() test_trace_run(check, root) end,
        catch {
            function(e) err = e end
        }
    }
    os.rm(root)
    if err ~= nil then
        check(false, "the trace run raised: " .. tostring(err))
    end
    local verdict = failures() == 0 and "OK" or ("FAIL " .. failures())
    print(string.format("trace run test: %s (%d checks)", verdict, count()))
    if failures() > 0 then
        os.exit(1)
    end
end
