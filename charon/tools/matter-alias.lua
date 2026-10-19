-- The Apple-prefixed spellings of the Aliro feature, as forwards to the methods this library carries.
--
-- Apple's own Matter.framework spells a command `apple<Command>` and an attribute access
-- `read/write/subscribeAttributeApple<Attribute>`, over the Aliro feature the open-source model declares under its own
-- name (measured: `AppleAliro` and `appleClearAliro` have zero occurrences in connectedhomeip master as well as in the
-- 1.6.1.0 this package builds, and master's templates/availability.yaml lists the names unprefixed). So every such row
-- is one selector forwarding to another over the same attribute or command id, and the forwarders are generated here
-- from the selectors the library actually carries rather than written out: a rename, and a rename has no per-row
-- judgement in it.
--
-- A target that the library does not carry is *not* emitted and is named here, because a forward to nothing is a
-- method that lies.
local objc = import("apple.objc", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})
-- Apple's two spellings, as the rename the SDK's surface shows.
local function target_of(selector)
    local renamed = selector:gsub("^(%a+Attribute)Apple", "%1"):gsub("^(%a+Attribute)", "%1")
    if renamed == selector then
        renamed = selector:gsub("^apple", "")
        renamed = renamed:sub(1, 1):lower() .. renamed:sub(2)
    end
    return renamed
end

-- Every header of the framework, read whole: the zap-generated ones put a class's declarations in one file
-- (MTRClusters.h holds the attribute and command methods of every cluster) and wrap a long declaration over several
-- physical lines, so a declaration is everything up to its semicolon and not one line.
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

-- The declaration of one selector, as the framework's own headers write it, or nil when none of them declares it.
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

-- The Apple spelling of a selector, which is what the SDK's surface asks for over the model's own name: the prefix
-- goes inside the attribute accesses (readAttributeAppleX) and in front of the command name (appleClearX, the first
-- word capitalised because it now follows a prefix).
local function apple_selector(selector)
    local renamed = selector:gsub("^(%a+Attribute)(%a+)", "%1Apple%2")
    if renamed == selector then
        local head, rest = selector:match("^(%a+)(%a.*)$")
        renamed = "apple" .. head:sub(1, 1):upper() .. head:sub(2) .. rest
    end
    return renamed
end

-- The unprefixed declaration with the Apple prefix put back into its selector: the method a caller sends, and the one
-- that forwards. The return type, the parameter types, the parameter names and whatever the declaration adds are the
-- unprefixed ones, unchanged, because it is the same command over the same ids.
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
    -- The parameters keep the unprefixed declaration's own text, from the character after the last selector token, so
    -- the type and the name of each are the framework's and not this script's.
    return declaration:sub(1, #head) .. table.concat(renamed, " ") .. declaration:sub(cursor)
end

function main(binary, corpus, diff, out, framework)
    assert(binary and corpus and diff and out and framework,
           "five paths: the dylib, the corpus, the differential, the output directory, the framework's CHIP directory")
    local inventory = objc.binary_inventory(binary, "armv7")
    -- A member is answered by the class or by any superclass, and by either sign: objc.lua keys a class's own method
    -- list by sign and selector, and when the same selector is a method of both kinds - which is what the zap
    -- generator writes for an attribute read with a cluster-state cache - the sign that lands in the map is whichever
    -- was recorded last, so asking for one sign and being told no is not an answer about the method.
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

    -- One category per class, so a class that gains a spelling gains only its own.
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
            "#import <Matter/Matter.h>",   -- the zap-generated classes are declared in MTRBaseClusters.h, not in a header
                                             -- of their own, so the umbrella is what names them
            "",
            "@interface " .. owner .. " (CharonAppleSpelling)",
            "@end",
            "",
            "@implementation " .. owner .. " (CharonAppleSpelling)",
            ""
        }
        -- The signature of the apple-prefixed method is the unprefixed method's, with the prefix put back: the same
        -- parameters and the same types, because it is the same command over the same ids. So it is read out of the
        -- framework's own header, which declares the unprefixed one, rather than assembled from the selector - a
        -- selector carries no types, and a forward with untyped parameters is not the same method.
        for _, f in ipairs(byowner[owner]) do
            local declaration = signature_in(headers, f.to)
            if not declaration then
                table.insert(absent, f.api .. "  ->  " .. f.to .. "  (no declaration in the header to copy the types from)")
            else
                -- The availability suffix is the declaration's, for the declaration; a definition of the same method
                -- does not need it, and the framework is compiled with the marks off in any case.
                local spelled = rename(declaration):gsub("%s+MTR_AVAILABLE%b%(%b%)*.-%)", ""):gsub("%s+;$", ";")
                table.insert(lines, spelled)
                table.insert(lines, "{")
                -- The argument names are the unprefixed declaration's own parameter names: the apple-prefixed method
                -- takes the same parameters under the same names, so it forwards them by name.
                local arguments = {}
                for name in declaration:gmatch("%)%s*([%a_][%w_]*)%s") do
                    table.insert(arguments, name)
                end
                -- The return type of the forward is the unprefixed declaration's: an appleClearAliroReaderConfigWith
                -- completion: returns the same MTRStatus the model does, because it is the same command.
                -- A forward returns what the method it forwards to returns, which is the declaration's own return
                -- type; for a void command that is a call and not a returned value.
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
    -- Two things this xmake's Lua does that cost a session, both measured here rather than assumed: a gsub in an
    -- argument position hands io.lines the substitution count as its start offset, and print does format its arguments
    -- (print("%d forwards", 33) prints "33 forwards"), so a count read back from a formatted print is the count.
    print(string.format("%d forwards over %d classes, each to a selector the library carries; %d rows with no carried target:",
                        written, classes, #absent))
    for _, row in ipairs(absent) do
        print("  no target: " .. row)
    end
end

-- The paths, in the order xmake l passes them, with the output directory last.
