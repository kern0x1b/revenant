local stream = import("stream", {anonymous = true})
local objc = import("objc", {anonymous = true})
local order = import("order", {anonymous = true})
local strings = import("strings", {anonymous = true})
local pages = import("pages", {anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local DOC_OUT = "spec-docs"
local DEFAULT_LIMIT = 5
local TIMEOUT_SECONDS = 300
local MEGABYTE = 1048576
local HEAVY_NAME = "heavy.sh"
local SUMMARY_CALLS = 40
local MILLISECONDS = 1000

local WRAP = [[exec /usr/bin/time -l timeout "$1" /bin/sh -c 'exec ipsw dyld disass "$1" --vaddr "$2" --demangle' ipsw "$2" "$3" 2>&1]]
local NOTE_LINES = 12

local MARKUP = "^0x[0-9a-f]+:%s+" .. string.rep("[0-9a-f][0-9a-f]%s+", 4) .. "(%S+)%s*(.*)$"
local CONDITIONAL = {cbz = true, cbnz = true, tbz = true, tbnz = true}
local EQUALITY = {["b.eq"] = true, ["b.ne"] = true}

function heavy_path(corpus)
    local heavy = path.join(path.directory(corpus), HEAVY_NAME)
    assert(os.isfile(heavy), "no " .. HEAVY_NAME .. " beside the corpus folder: " .. heavy)
    return heavy
end

function doc_root()
    return workspace.run(DOC_OUT)
end

function page_path(fw, files, cls)
    return path.join(doc_root(), fw, "behaviour", files[pages.key("class", cls)])
end

function page_files(corpus, sdk_release, fw)
    local seen, entries = {}, {}
    for _, m in ipairs(methods(corpus, sdk_release, fw)) do
        if not seen[m.cls] then
            seen[m.cls] = true
            table.insert(entries, {kind = "class", name = m.cls})
        end
    end
    return pages.names(entries, {})
end

function methods(corpus, sdk_release, fw)
    local out = {}
    for _, row in ipairs(objc.facts(corpus, sdk_release, fw).list) do
        if row.entity == "method" and row.address ~= "" and row.address ~= "-" then
            table.insert(out, {cls = row.owner, section = row.section, selector = row.name, address = row.address})
        end
    end
    table.sort(out, function(a, b)
        if a.cls ~= b.cls then
            return order.less(a.cls, b.cls)
        end
        if a.section ~= b.section then
            return order.less(a.section, b.section)
        end
        return order.less(a.selector, b.selector)
    end)
    return out
end

function disassemble(heavy, cache, address, each)
    local peak = 0
    local notes = {}
    local started = os.mclock()
    local status = stream.lines(heavy, {"/bin/sh", "-c", WRAP, "sh", tostring(TIMEOUT_SECONDS), cache, address}, function(line)
        local bytes = string.match(line, "(%d+)%s+maximum resident set size")
        if bytes then
            peak = tonumber(bytes) / MEGABYTE
        else
            if #notes < NOTE_LINES and not string.match(line, MARKUP) then
                table.insert(notes, line)
            end
            each(line)
        end
    end)
    return status, (os.mclock() - started) / MILLISECONDS, peak, notes
end

local function trim(text)
    return string.match(text, "^%s*(.-)%s*$")
end

function new_summary()
    return {instructions = 0, calls = {}, argument_branches = {}, strings = {}, constants = {}, error_domains = {}, last = {}}
end

local function constant_name(token)
    local name = string.sub(token, 1, 1) == "_" and string.sub(token, 2) or token
    return string.find(name, "^k[A-Z][A-Za-z0-9_]+$") ~= nil or string.find(name, "^CF[A-Z][A-Za-z0-9_]+$") ~= nil
        or string.find(name, "^NS[A-Z][A-Za-z0-9_]+$") ~= nil
end

local function add_markup(state, text)
    local mnemonic, rest = string.match(text, MARKUP)
    if mnemonic == nil then
        return
    end
    local semi = string.find(rest, ";", 1, true)
    local operands = trim(semi and string.sub(rest, 1, semi - 1) or rest)
    local comment = trim(semi and string.sub(rest, semi + 1) or "")
    state.instructions = state.instructions + 1
    if (mnemonic == "bl" or mnemonic == "blr" or mnemonic == "b") and string.sub(operands, 1, 4) ~= "loc_"
        and not string.find(operands, "loc_", 1, true) then
        local target = operands ~= "" and operands or "indirect"
        table.insert(state.calls, target)
        if string.find(target, "errorWithDomain", 1, true) and state.last.x2 ~= nil then
            table.insert(state.error_domains, state.last.x2)
        end
    elseif string.sub(mnemonic, 1, 2) == "b." or CONDITIONAL[mnemonic] then
        local tested = string.match(operands, "^([wx][0-9]+)") or string.match(operands, "^([A-Za-z0-9_]+)")
        if EQUALITY[mnemonic] and tested == nil then
            error("a conditional branch with no operand: " .. text)
        end
        table.insert(state.argument_branches, tested or "flags")
    end
    if comment ~= "" then
        for quoted in string.gmatch(comment, '"([^"]*)"') do
            table.insert(state.strings, quoted)
        end
        for token in string.gmatch(comment, "[A-Za-z0-9_]+") do
            if constant_name(token) then
                table.insert(state.constants, token)
            end
        end
        local destination = string.match(operands, "^([wx][0-9]+)")
        if destination then
            state.last["x" .. string.sub(destination, 2)] = comment
        end
    end
end

function add_line(state, line)
    for _, piece in ipairs(strings.lines(line)) do
        add_markup(state, piece)
    end
end

function page_text(fw, cls, items, sdk_release)
    local page = {"# " .. cls .. " behaviour (" .. fw .. ")", "",
                  "REFERENCE ONLY. Read from the " .. sdk_release .. " iOS cache by ipsw (markup, demangled), one function at a time: calls in the order the"
                  .. " code makes them (a straight line through the function, no branch followed), the branches that test a register, the"
                  .. " constants and strings named in comments, and the NSError domain a call passes. Nothing here is a decompilation, and"
                  .. " nothing is sent to an external service.", ""}
    local function joined(list, sep, empty)
        if #list == 0 then
            return empty
        end
        return table.concat(list, sep)
    end
    for _, item in ipairs(items) do
        local s = item.summary
        local sign = item.section == "instance" and "-" or "+"
        local calls = {}
        for i = 1, math.min(#s.calls, SUMMARY_CALLS) do
            calls[i] = s.calls[i]
        end
        table.insert(page, "## " .. sign .. "[" .. cls .. " " .. item.selector .. "]")
        table.insert(page, "")
        table.insert(page, "address " .. item.address .. ", " .. s.instructions .. " instructions")
        table.insert(page, "")
        table.insert(page, "Calls, in order: " .. joined(calls, "; ", "none"))
        table.insert(page, "")
        table.insert(page, "Argument branches on: " .. joined(s.argument_branches, ", ", "none"))
        table.insert(page, "")
        table.insert(page, "Strings: " .. joined(s.strings, "; ", "none in comments"))
        table.insert(page, "")
        table.insert(page, "Constants: " .. joined(s.constants, ", ", "none in comments"))
        table.insert(page, "")
        table.insert(page, "Error domains: " .. joined(s.error_domains, ", ", "none"))
        table.insert(page, "")
    end
    return table.concat(page, "\n") .. "\n"
end

function default_limit()
    return DEFAULT_LIMIT
end
