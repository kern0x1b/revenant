local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local markers = import("markers", {rootdir = tools, anonymous = true})

local SOURCE = [==[
#include <stdio.h>
#define DEFINE_LITERAL(x) int CFMacro(int a) { return a; }
int CFFoo(int a) { return a; }
int CFFoo2(int a);
static int CFStatic(int a) { return a; }
__attribute__((visibility("default"))) int CFAttr(int a) { return a; }
int kGlobal = 3;
NSString *const kStr = @"x";
extern int kExt;
int kTent;
int kArr[2] = {1, 2};
const char *kFn(void) { return "int CFFake(int a) {"; }
/* int CFComment(int a) { } */
@interface Foo : NSObject { int ivar; }
@property (nonatomic) int prop;
- (void)CFMethod:(int)a { }
@end
int CFLast(void) { return 1; }
int CFVariadic(int a, ...) { return a; }
]==]

local function set_of(names)
    local out = {}
    for _, name in ipairs(names) do
        out[name] = true
    end
    return out
end

local function list_of(set)
    local out = {}
    for name in pairs(set) do
        table.insert(out, name)
    end
    table.sort(out)
    return table.concat(out, ",")
end

function main()
    local renamable = set_of({"CFFoo", "CFAttr", "kGlobal", "kStr", "kTent", "kArr", "kFn", "CFLast", "CFMacro", "CFFake", "CFComment"})
    local sdk = set_of({"CFFoo", "CFAttr", "kGlobal", "kStr", "kTent", "kArr", "kFn", "CFLast", "CFMacro", "CFFake", "CFComment",
        "CFVariadic", "CFFoo2", "kExt", "CFStatic"})

    local out, renamed, kept, unhandled = markers.rewrite(SOURCE, renamable, sdk)

    local expected = "CFAttr,CFFoo,CFLast,CFMacro,kArr,kFn,kGlobal,kStr,kTent"
    assert(list_of(set_of(renamed)) == expected, "renamed names were " .. table.concat(renamed, ","))
    assert(#kept == 1 and kept[1].name == "CFVariadic", "kept SDK-named definitions should be CFVariadic only")
    assert(#unhandled == 0, "no macro parameter should define a name here")
    assert(string.find(out, "int BACKPORT_IMPL(CFFoo)(int a) { return a; }", 1, true), "CFFoo definition was not renamed")
    assert(string.find(out, "#define DEFINE_LITERAL(x) int BACKPORT_IMPL(CFMacro)(int a) { return a; }", 1, true), "macro body was not renamed")
    assert(string.find(out, "int CFFoo2(int a);", 1, true), "a prototype must not be renamed")
    assert(string.find(out, "return \"int CFFake(int a) {\";", 1, true), "a string literal must not be renamed")
    assert(string.find(out, "/* int CFComment(int a) { } */", 1, true), "a comment must not be renamed")
    assert(string.find(out, "extern int kExt;", 1, true), "an extern declaration must not be renamed")

    local defs = markers.marked_definitions(out)
    assert(defs.CFFoo.kind == "function" and defs.CFMacro.kind == "function", "a marked function or a macro's function must be a function")
    assert(defs.kGlobal.kind == "global" and defs.kGlobal.type == "int" and not defs.kGlobal.array, "kGlobal must be an int global")
    assert(defs.kStr.type == "NSString *const", "kStr's declared type was " .. tostring(defs.kStr.type))
    assert(defs.kArr.kind == "global" and defs.kArr.type == "int" and defs.kArr.array, "kArr must be an int array")
    assert(defs.kTent.type == "int" and not defs.kTent.array, "kTent must be an int global without an initializer")
    assert(defs.kFn.kind == "function", "kFn returns a pointer and must still be a function")

    local marked = markers.marked(out)
    assert(list_of(marked) == expected, "marked names were " .. list_of(marked))
    assert(#markers.marker_arguments(out) == 0, "every marker argument must be a literal name")

    local again, renamed_again = markers.rewrite(out, renamable, sdk)
    assert(#renamed_again == 0 and again == out, "a second rewrite must change nothing")

    local USES = [==[
int kUse = 1;
int read_use(void) { return kUse; }
int kUse2 = 0;
const char *tag(void) { return "kUse"; }
]==]
    local uses = set_of({"kUse"})
    local uses_out, uses_renamed = markers.rewrite(USES, uses, uses)
    assert(list_of(set_of(uses_renamed)) == "kUse", "kUse must be renamed once")
    assert(string.find(uses_out, "int BACKPORT_IMPL(kUse) = 1;", 1, true), "the definition of kUse was not renamed")
    assert(string.find(uses_out, "return BACKPORT_IMPL(kUse);", 1, true), "a use of kUse in a body was not renamed")
    assert(string.find(uses_out, "int kUse2 = 0;", 1, true), "kUse2 is another name and must stay")
    assert(string.find(uses_out, "return \"kUse\";", 1, true), "a string literal must not be renamed")
    assert(markers.rename_uses(uses_out, uses) == uses_out, "a renamed use must not be renamed again")
    local extern_out = markers.rename_uses("extern int kE;\nint f(void) { return kE; }\n", set_of({"kE"}))
    assert(extern_out == "extern int kE;\nint f(void) { return BACKPORT_IMPL(kE); }\n", "an extern declaration stays and a body use is renamed, got " .. extern_out)

    local PROPERTIES = [==[
@implementation Bar
@dynamic width, height;
@synthesize order, title;
@end
]==]
    local properties = set_of({"width", "height", "order", "title"})
    local same, renamed_properties = markers.rewrite(PROPERTIES, properties, properties)
    assert(#renamed_properties == 0 and same == PROPERTIES, "@dynamic and @synthesize names are properties, not globals")
    local marked_properties = markers.marked_definitions("@implementation Bar\n@dynamic BACKPORT_IMPL(width), BACKPORT_IMPL(height);\n@end\n")
    local defined = 0
    for _ in pairs(marked_properties) do
        defined = defined + 1
    end
    assert(defined == 0, "a marked @dynamic name must define no global")

    local LATE = [==[
int late_user(void) { return kLate; }
int kLate = 2;
int kTwice(void) { return kLate; }
]==]
    local late_out, late_renamed = markers.rewrite(LATE, set_of({"kLate"}), set_of({"kLate"}))
    assert(list_of(set_of(late_renamed)) == "kLate", "kLate must be renamed once")
    assert(late_out == "\nextern int __revenant_fb_kLate;\nint late_user(void) { return BACKPORT_IMPL(kLate); }\nint BACKPORT_IMPL(kLate) = 2;\nint kTwice(void) { return BACKPORT_IMPL(kLate); }\n",
        "a use before the definition needs a declaration of the renamed name, got " .. late_out)
    assert(markers.rewrite(late_out, set_of({"kLate"}), set_of({"kLate"})) == late_out, "the declaration must not be added twice")

    local LATE_ARRAY = "int late_arr(void) { return kArr[0]; }\nint kArr[2] = {1, 2};\n"
    local array_out = markers.rewrite(LATE_ARRAY, set_of({"kArr"}), set_of({"kArr"}))
    assert(string.find(array_out, "\nextern int __revenant_fb_kArr[];\nint late_arr", 1, true), "an array needs an array declaration, got " .. array_out)

    local LATE_CLASS = "@implementation Baz\n- (int)m { return kImpl; }\n@end\nint kImpl = 1;\n"
    local class_out = markers.rewrite(LATE_CLASS, set_of({"kImpl"}), set_of({"kImpl"}))
    assert(string.find(class_out, "\nextern int __revenant_fb_kImpl;\n@implementation Baz", 1, true), "the declaration goes before the class, got " .. class_out)

    local ordered = "int kDone = 1;\nint use_done(void) { return kDone; }\n"
    local ordered_out = markers.rewrite(ordered, set_of({"kDone"}), set_of({"kDone"}))
    assert(not string.find(ordered_out, "extern", 1, true), "a use after the definition needs no declaration, got " .. ordered_out)

    local EXPORT = [==[
#define REVENANT_EXPORT __attribute__((visibility("default")))
REVENANT_EXPORT const mach_port_t BACKPORT_IMPL(kPort) = 0;
REVENANT_EXPORT int BACKPORT_IMPL(kCount);
REVENANT_EXPORT int BACKPORT_IMPL(CFExported)(int a) { return a; }
]==]
    local export_defs = markers.marked_definitions(EXPORT)
    assert(export_defs.kPort.kind == "global" and export_defs.kPort.type == "const mach_port_t",
        "an attributes-alone macro must leave the type of its global, got " .. tostring(export_defs.kPort.type))
    assert(export_defs.kCount.type == "int", "kCount must be an int global, got " .. tostring(export_defs.kCount.type))
    assert(export_defs.CFExported.kind == "function", "an exported function must still be a function")

    local OBJECT_MACRO = "#define KEEP_CONST const\nKEEP_CONST mach_port_t BACKPORT_IMPL(kBad) = 0;\n"
    local message
    try {
        function () markers.marked_definitions(OBJECT_MACRO) end,
        catch { function (errors) message = tostring(errors) end }
    }
    assert(message and string.find(message, "kBad", 1, true) and string.find(message, "KEEP_CONST", 1, true),
        "a marked global typed past a macro that is not attributes alone must raise, got " .. tostring(message))
    local plain = 0
    for _ in pairs(markers.marked_definitions("#define KEEP_CONST const\nKEEP_CONST mach_port_t kPlain = 0;\n")) do
        plain = plain + 1
    end
    assert(plain == 0, "a global without a marker is not read, whatever its macros")

    local EXPORT_LATE = [==[
#define REVENANT_EXPORT __attribute__((visibility("default")))
int late_port(void) { return kLatePort; }
REVENANT_EXPORT const int kLatePort = 2;
]==]
    local late_export, late_export_renamed = markers.rewrite(EXPORT_LATE, set_of({"kLatePort"}), set_of({"kLatePort"}))
    assert(list_of(set_of(late_export_renamed)) == "kLatePort", "kLatePort must be renamed once")
    assert(string.find(late_export, "extern const int __revenant_fb_kLatePort;", 1, true),
        "a forward declaration takes the type without the macro, got " .. late_export)

    local tagged = markers.marked_definitions("struct os_log_s BACKPORT_IMPL(_os_log_default);\nstruct tag_s { int a; };\nstruct fwd_s;\n")
    assert(tagged._os_log_default and tagged._os_log_default.kind == "global" and tagged._os_log_default.type == "struct os_log_s",
        "a marked global typed with a struct tag must be read, got " .. tostring(tagged._os_log_default and tagged._os_log_default.type))
    local tag_only = markers.marked_definitions("struct tag_s { int BACKPORT_IMPL(a); };\nstruct fwd_s;\n")
    local tag_globals = 0
    for _ in pairs(tag_only) do
        tag_globals = tag_globals + 1
    end
    assert(tag_globals == 0, "a marked name inside a tag definition or after a forward declaration is not a global")

    print("markers tests passed: 9 definitions renamed, a prototype, a string, a comment, an extern and a variadic left alone; @dynamic and @synthesize names left alone")
end
