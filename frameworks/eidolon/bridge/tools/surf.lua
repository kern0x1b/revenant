-- surf.lua: the 26.2 SwiftUI + SwiftUICore surface for the types this band owns, one line per declaration.
--
--     xmake l surf.lua TYPES-FILE > surface-26.2.tsv
--
-- Reads the SDK's own `.swiftinterface` files - SwiftUI and SwiftUICore, the two halves Apple split the surface between -
-- from $APPLE_26_SDK, which defaults to the charon SDK 26.2 checkout under $HOME. Braces are counted the way ours.lua
-- counts them, by lib/braces.lua, so a depth means the same thing on both sides. gaps.lua then says what of it this
-- tree does not declare.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})
local owners = import("lib.owners", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local KEYWORDS = {"struct", "class", "enum", "protocol", "actor", "typealias"}

-- the first name a type keyword is followed by, the keyword standing on a word boundary:
--     \b(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)
local function type_name(body)
    for at = 1, #body do
        if text.boundary(body, at) then
            for _, keyword in ipairs(KEYWORDS) do
                if text.startswith(body, keyword, at) then
                    local _, space = string.find(body, "^%s+", at + #keyword)
                    local name = space and string.match(body, "^[%w_]+", space + 1)
                    if name then
                        return name
                    end
                end
            end
        end
    end
    return nil
end

-- the declaration a body line holds, the patterns in the order the Python tried them, first match wins:
--     \bsubscript\b, \binit\b, \bfunc (\w+), \bvar (\w+), \bcase (\w+), the type keywords
local function declaration(body)
    if text.has_word(body, "subscript") then
        return "subscript", "subscript"
    end
    if text.has_word(body, "init") then
        return "init", "init"
    end
    local func_name = text.name_after(body, "func ")
    if func_name then
        return "func", func_name
    end
    local var_name = text.name_after(body, "var ")
    if var_name then
        return "var", var_name
    end
    local case_name = text.name_after(body, "case ")
    if case_name then
        return "const", case_name
    end
    local type = type_name(body)
    if type then
        return "type", type
    end
    return nil
end

local function scan(file, want, out, seen)
    local lines = text.split(io.readfile(file), "\n")
    -- the @attribute line above the declaration: the one the last @-line set, and "" when none
    local pending = ""
    for _, row in ipairs(owners.walk(lines)) do
        local s = text.strip(row.line)
        if s == "" or text.startswith(s, "#") then
            pending = ""
        elseif row.owner == nil then
            if text.startswith(s, "@") then
                pending = s
            end
        else
            -- a type of ours, or a type nested in one: matched on the first component, and the owner keeps the whole
            -- path, so a member of `Image.ResizingMode` is never filed under `Image`
            local first = text.partition(row.owner, ".")
            if want[first] then
                if string.find(pending, "@available%(iOS,%s*unavailable") then
                    pending = ""
                else
                    local brace = string.find(s, "{", 1, true)
                    local body = brace and string.sub(s, 1, brace - 1) or s
                    if body ~= "" then
                        local kind, name = declaration(body)
                        if kind then
                            local key = row.owner .. "\t" .. kind .. "\t" .. name
                            if not seen[key] then
                                seen[key] = true
                                out[#out + 1] = {row.owner, kind, name}
                            end
                        end
                        pending = ""
                    end
                end
            end
        end
    end
end

function main(...)
    local args = {...}
    local env = os.getenv("APPLE_26_SDK")
    local sdk = (env and env ~= "") and env or path.join(os.getenv("HOME"), "Git", "projects", "ios", "charon",
        ".agent-work", "sdk-26.2", "iPhoneOS26.2.sdk")
    local swiftui = path.join(sdk, "System", "Library", "Frameworks", "SwiftUI.framework", "Modules",
        "SwiftUI.swiftmodule", "arm64e-apple-ios.swiftinterface")
    local swiftuicore = path.join(sdk, "System", "Library", "Frameworks", "SwiftUICore.framework", "Modules",
        "SwiftUICore.swiftmodule", "arm64e-apple-ios.swiftinterface")

    local want = {}
    for _, line in ipairs(text.split(io.readfile(args[1]), "\n")) do
        local s = text.strip(line)
        if s ~= "" and not text.startswith(s, "#") then
            want[s] = true
        end
    end

    local out, seen = {}, {}
    scan(swiftui, want, out, seen)
    scan(swiftuicore, want, out, seen)
    for _, row in ipairs(out) do
        print(text.join("\t", row))
    end
end
