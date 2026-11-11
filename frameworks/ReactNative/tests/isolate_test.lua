local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "ReactNative", "tools")

local isolate = import("isolate", {rootdir = TOOLS, anonymous = true})

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

local function refusal(check)
    local message
    try { check, catch { function (errors) message = tostring(errors) end } }
    return message
end

local SWIFT = 'add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = true}})'
local LIBCXX = 'add_requires("revenant@libcxx", {alias = "libcxx", configs = {packaged = true}})'
local LIBCXX_DEPS = 'add_requireconfs("**.libcxx", {configs = {packaged = true}})'
local WEBKIT = 'add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}})'

local APPLICATION = table.concat({
    'set_project("paseo-ios6")',
    'if not os.getenv("RN_ONLY") or os.getenv("RN_EXPO") then',
    '    add_requires("revenant@swift-runtime", {alias = "swift-runtime"})',
    'end',
    'add_requires("revenant@libcxx", {alias = "libcxx"})',
    'includes("@addon/revenant/apple-ios")',
    ""
}, "\n")

local COMPONENT = 'option("component", {type = "string", default = "", showmenu = true, description = "Configure only this component and what it needs, for example Backports or emulator; empty configures every component."})'
local COMBINE = 'add_requireconfs("combine", {override = true, configs = {shared = get_config("component") == "" or nil}})'

local ROOT_TEXT = table.concat({SWIFT, LIBCXX, LIBCXX_DEPS, WEBKIT, COMPONENT, COMBINE, ""}, "\n")

local CARRIED = table.concat({SWIFT, LIBCXX, LIBCXX_DEPS,
    'add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed", carried = "jsc"}})', ""}, "\n")

local whole = isolate.whole_requirements(APPLICATION)

expect("a plain application gets the whole requirements", #isolate.whole_missing(whole) == 0,
       "whole_missing still lists " .. #isolate.whole_missing(whole) .. " requirements after the copy carried them")
expect("the plain swift-runtime and libcxx lines are replaced", not whole:find('{alias = "swift-runtime"})', 1, true)
       and not whole:find('{alias = "libcxx"})', 1, true), "a plain requirement survives")
expect("the replaced swift-runtime keeps its condition", whole:find('if not os.getenv("RN_ONLY")', 1, true) ~= nil and whole:find(SWIFT, 1, true) ~= nil,
       "the condition or the shared swift-runtime is missing")
expect("the whole requirements are carried once", isolate.whole_requirements(whole) == whole, "a second copy changed the text")
expect("the copy declares the component option and the combine rule", whole:find('option("component"', 1, true) ~= nil and whole:find(COMBINE, 1, true) ~= nil,
       "the component option or the combine requireconf is missing from the copy")
expect("a plain application lacks all six whole requirements", #isolate.whole_missing(APPLICATION) == 6,
       "expected 6 missing, found " .. #isolate.whole_missing(APPLICATION))
expect("the root's own declarations are already whole", #isolate.whole_missing(ROOT_TEXT) == 0 and isolate.whole_requirements(ROOT_TEXT) == ROOT_TEXT,
       "the root's text is rewritten or reported missing")
local carried = isolate.whole_requirements(CARRIED)
expect("a webkit-engine that RN_WEBKIT declares keeps its own line, and the whole one is added unless RN_WEBKIT is set", #isolate.whole_missing(CARRIED) == 3
       and #isolate.whole_missing(carried) == 0 and carried:find('if not os.getenv("RN_WEBKIT") then add_requires("webkit-engine"', 1, true) ~= nil
       and isolate.whole_requirements(carried) == carried, "the RN_WEBKIT line is not kept beside the whole one, or a second pass changes the copy")

local OTHER = 'add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = false}})\n'
local message = refusal(function () isolate.whole_requirements(OTHER) end)
expect("a swift-runtime with other configs is refused", message ~= nil and message:find("swift%-runtime") ~= nil,
       "the copy was rewritten or the refusal does not name swift-runtime")
