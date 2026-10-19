local objc = import("apple.objc", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})
local function target_of(selector)
    local renamed = selector:gsub("^(%a+Attribute)Apple", "%1"):gsub("^(%a+Attribute)", "%1")
    if renamed == selector then
        renamed = selector:gsub("^apple", "")
        renamed = renamed:sub(1, 1):lower() .. renamed:sub(2)
    end
    return renamed
end

local function headers_of(framework)
    local found = {}
    for _, directory in ipairs({"", "zap-generated", "ServerEndpoint"}) do
        local place = path.join(framework, directory)
        if os.isdir(place) then
            for _, header in ipairs(os.files(path.join(place, "*.h"))) do
                found[#found + 1] = header
            end
        end
    end
    byteorder.sort(found)
    return found
end

local function signature_in(headers, selector)
    local wanted = {}
    for token in (selector .. ":"):gmatch("([%a_][%w_]*:)") do
        wanted[#wanted + 1] = token
    end
    for _, header in ipairs(headers) do
        for declaration in io.readfile(header):gmatch("([-+]%s*%b()%s*[^;]-;)") do
            do
                local flattened = declaration:gsub("%s*\n%s*", " "):gsub("^%s+", ""):gsub("%s+$", "")
                local head = flattened:match("^[-+]%s*%b()%s*")
                if head then
                    local cursor = #head + 1
                    local tokens = {}
                    while true do
                        local token = flattened:sub(cursor):match("^([%a_][%w_]*:)")
                        if not token then
                            break
                        end
                        tokens[#tokens + 1] = token
                        cursor = cursor + #token
                        cursor = cursor + #(flattened:sub(cursor):match("^%s*") or "")
                    end
                    if #tokens == #wanted then
                        local same = true
                        for index = 1, #wanted do
                            if tokens[index] ~= wanted[index] then
                                same = false
                                break
                            end
                        end
                        if same then
                            return flattened
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function apple_selector(selector)
    local renamed = selector:gsub("^(%a+Attribute)(%a+)", "%1Apple%2")
    if renamed == selector then
        local head, rest = selector:match("^(%a+)(%a.*)$")
        renamed = "apple" .. head:sub(1, 1):upper() .. head:sub(2) .. rest
    end
    return renamed
end

local function rename(declaration)
    local head = declaration:match("^[-+]%s*%b()%s*")
    local cursor = #head + 1
    local renamed = {}
    while true do
        local token = declaration:sub(cursor):match("^([%a_][%w_]*:)")
        if not token then
            break
        end
        renamed[#renamed + 1] = apple_selector(token:sub(1, -2)) .. ":"
        cursor = cursor + #token
        cursor = cursor + #(declaration:sub(cursor):match("^%s*") or "")
    end
    if #renamed == 0 then
        return nil
    end
    return declaration:sub(1, #head) .. table.concat(renamed, " ") .. declaration:sub(cursor)
end

function main(binary, corpus, diff, out, framework)
    assert(binary and corpus and diff and out and framework,
           "five paths: the dylib, the corpus, the differential, the output directory, the framework's CHIP directory")
    local inventory = objc.binary_inventory(binary, "armv7")
    local function carried(owner, sign, selector)
        local seen, name = {}, owner
        while name and inventory.classes[name] and not seen[name] do
            seen[name] = true
            local entry = inventory.classes[name]
            if entry.instance[sign .. selector] or entry.class[sign .. selector] or
               entry.instance[(sign == "-" and "+" or "-") .. selector] or
               entry.class[(sign == "-" and "+" or "-") .. selector] then
                return true
            end
            name = entry.superclass
        end
        return false
    end
    local hostmembers = {}
    for line in io.lines(diff) do
        local f = {}
        for field in (line:gsub("\n$", "") .. "\t"):gmatch("([^\t]*)\t") do
            table.insert(f, field)
        end
        if f[1] == "host_carries" and f[2] == "method" then
            hostmembers[f[3]] = true
        end
    end
    local headers = headers_of(framework)
    local forwards, absent = {}, {}
    for line in io.lines(corpus) do
        local f = {}
        for field in (line:gsub("\n$", "") .. "\t"):gmatch("([^\t]*)\t") do
            table.insert(f, field)
        end
        if f[1] == "Matter" and f[2] == "method" and hostmembers[f[4]] then
            local sign, owner, selector = f[4]:match("^([-+])%[([%w_]+) (.+)%]$")
            if sign and not carried(owner, sign, selector) then
                local to = target_of(selector)
                if carried(owner, sign, to) then
                    table.insert(forwards, {sign = sign, owner = owner, selector = selector, to = to, api = f[4]})
                else
                    table.insert(absent, f[4] .. "  ->  " .. to)
                end
            end
        end
    end
    table.sort(forwards, function (a, b) return byteorder.less(a.owner .. a.selector, b.owner .. b.selector) end)

    local byowner = {}
    for _, f in ipairs(forwards) do
        byowner[f.owner] = byowner[f.owner] or {}
        table.insert(byowner[f.owner], f)
    end
    os.mkdir(out)
    local written, classes = 0, 0
    for _, owner in ipairs(table.orderkeys(byowner)) do
        local lines = {
            "/*",
            " *    The Apple-prefixed spellings of the Aliro feature, forwarding to the methods this library carries.",
            " *",
            " *    Generated by tools/matter-alias.lua from the selectors the library carries, not written out: the",
            " *    SDK's surface spells these commands `apple<Command>` and these attribute accesses",
            " *    `read/write/subscribeAttributeApple<Attribute>` over the Aliro feature the open-source model declares",
            " *    under its own name, and a rename has no per-row judgement in it. Each forward reaches the same",
            " *    attribute or command id as the method it forwards to, because it is that method's own encoder call.",
            " *",
            " *    Measured: `AppleAliro` and `appleClearAliro` have zero occurrences in connectedhomeip master as well as",
            " *    in the tag this package builds, and the framework's own metadata carries the unprefixed methods.",
            " */",
            "",
            "#import <Foundation/Foundation.h>",
            "#import <Matter/Matter.h>",
            "",
            "@interface " .. owner .. " (RevenantAppleSpelling)",
            "@end",
            "",
            "@implementation " .. owner .. " (RevenantAppleSpelling)",
            ""
        }
        for _, f in ipairs(byowner[owner]) do
            local declaration = signature_in(headers, f.to)
            if not declaration then
                table.insert(absent, f.api .. "  ->  " .. f.to .. "  (no declaration in the header to copy the types from)")
            else
                local spelled = rename(declaration):gsub("%s+MTR_AVAILABLE%b%(%b%)*.-%)", ""):gsub("%s+;$", ";")
                table.insert(lines, spelled)
                table.insert(lines, "{")
                local arguments = {}
                for name in declaration:gmatch("%)%s*([%a_][%w_]*)%s") do
                    table.insert(arguments, name)
                end
                local returns = declaration:match("^%s*[-+]%s*%b()%s*([%w_%* ]*)%s*%(")
                if returns and returns:match("^void$") then
                    returns = nil
                end
                table.insert(lines, string.format("    %s[self %s%s];", returns and ("return ") or "",
                                                  f.to, #arguments > 0 and (table.concat(arguments, ":"):gsub(":", ": "):gsub(": $", "")) or ""))
                table.insert(lines, "}")
                table.insert(lines, "")
                written = written + 1
            end
        end
        table.insert(lines, "@end")
        table.insert(lines, "")
        io.writefile(path.join(out, owner .. ".mm"), table.concat(lines, "\n"))
        classes = classes + 1
    end
    print(string.format("%d forwards over %d classes, each to a selector the library carries; %d rows with no carried target:",
                        written, classes, #absent))
    for _, row in ipairs(absent) do
        print("  no target: " .. row)
    end
end
