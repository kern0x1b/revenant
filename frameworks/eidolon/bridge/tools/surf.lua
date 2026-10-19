local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})
local owners = import("lib.owners", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local KEYWORDS = {"struct", "class", "enum", "protocol", "actor", "typealias"}

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
