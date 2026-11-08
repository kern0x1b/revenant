local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

local CLASS_HEADER = table.concat({
    "@interface Loader : NSObject",
    "@end",
    "",
    "/*!",
    " * Loads and compiles.",
    " *",
    " * @code",
    " * [Loader load]",
    " * @endcode",
    " */",
    "@interface Loader (Compilation)",
    "",
    "/*!",
    " * @code",
    " * [Loader compile]",
    " * @endcode",
    " */",
    "+ (void)loadWithHandler:(void (^)(void))handler API_AVAILABLE(macos(13.0), ios(16.0)) NS_REFINED_FOR_SWIFT;",
    "+ (void)keepWithHandler:(void (^)(void))handler API_AVAILABLE(macos(13.0), ios(16.0)) NS_REFINED_FOR_SWIFT;",
    "",
    "@property (class, readonly) NSInteger loadedCount API_AVAILABLE(macos(13.0), ios(16.0));",
    "@property (class, readonly) NSInteger keptCount API_AVAILABLE(macos(13.0), ios(16.0));",
    "",
    "@end",
    "",
}, "\n")

local PROTOCOL_HEADER = table.concat({
    "@protocol Source <NSObject>",
    "/*!",
    " * @code",
    " * [source fetch]",
    " * @endcode",
    " */",
    "- (void)fetch API_AVAILABLE(macos(13.0), ios(16.0));",
    "- (void)keep API_AVAILABLE(macos(13.0), ios(16.0));",
    "@end",
    "",
}, "\n")

local function declaration(text, name)
    return text:match("[^\n]*" .. name .. "[^\n]*")
end

function failures()
    local found = {}

    local set = {classes = {Loader = {["+loadWithHandler:"] = true, ["+loadedCount"] = true}}, functions = {}, globals = {}, protocols = {}}
    local lowered_class = lowered.lower_header(CLASS_HEADER, set)
    if declaration(lowered_class, "loadWithHandler"):find("API_AVAILABLE", 1, true) then
        table.insert(found, "a method after a doc comment with @endcode keeps its availability although the SDK-lowering set names it")
    end
    if declaration(lowered_class, "loadedCount"):find("API_AVAILABLE", 1, true) then
        table.insert(found, "a property after a doc comment with @endcode keeps its availability although the SDK-lowering set names it")
    end
    if not declaration(lowered_class, "keepWithHandler"):find("API_AVAILABLE", 1, true) then
        table.insert(found, "a method the SDK-lowering set does not name loses its availability")
    end
    if not declaration(lowered_class, "keptCount"):find("API_AVAILABLE", 1, true) then
        table.insert(found, "a property the SDK-lowering set does not name loses its availability")
    end

    local protocol_set = {classes = {}, functions = {}, globals = {}, protocols = {Source = true}, protocol_members = {Source = {["-fetch"] = true}}}
    local lowered_protocol = lowered.lower_header(PROTOCOL_HEADER, protocol_set)
    if declaration(lowered_protocol, "fetch"):find("API_AVAILABLE", 1, true) then
        table.insert(found, "a protocol member after a doc comment with @endcode keeps its availability although the SDK-lowering set names it")
    end
    if not declaration(lowered_protocol, "keep"):find("API_AVAILABLE", 1, true) then
        table.insert(found, "a protocol member the SDK-lowering set does not name loses its availability")
    end
    return found
end
