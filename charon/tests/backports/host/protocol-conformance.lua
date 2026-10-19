-- protocol-conformance.lua - the acceptance test for a protocol row marked `implemented`, in Lua.
--
--     CONF_ROOT=<checkout> CONF_SDK=<iPhoneOS16.4.sdk> CONF_CLANG=<clang> CONF_GEN=<generated headers> \
--     CONF_WORK=<run dir> xmake lua tests/backports/host/protocol-conformance.lua
--
-- protocol-conformance.sh sets those and generates the protocol headers, so a run needs no python.
-- CONF_MODE=members with CONF_PROTOCOL, CONF_CLASS and CONF_FILE (relative to the package) checks one row only.
--
-- THE CRITERION, as the python checker it replaces stated it, and this keeps it. An `implemented` row
-- claims every member of the protocol is callable, and backports.lua:664 turns that claim into a band floor. So
-- for EVERY member - required and optional instance and class methods, and every property's getter and (when
-- readwrite) its setter - some @implementation or category implementation of the class DEFINES the selector, or a
-- @synthesize binds it. The members come from the SDK's own protocol declaration in the AST, and the definitions
-- from the class's files in the package.
--
-- WHAT IS READ: clang's AST as its text dump, with -ast-dump-filter so that only the declarations whose name
-- matches are printed. The text is read by its shape: a node's depth is the number of '-' markers before its kind;
-- a definition is an ObjCMethodDecl with a CompoundStmt child; a declaration in an @interface has no body. No SDK
-- header text is read, only the compiler's declarations.
--
-- DIFFERENCES FROM THE PYTHON IT REPLACES:
--   - the class's definitions come from EVERY package file that implements the class (its @implementation and its
--     categories, which can be in other files: MTLCommandQueue8.m adds to CharonMetalQueue). The python read only
--     the one file it was given, so a category in another file could never satisfy a row.
--   - the generated protocol header is on the include path (-I), since the sources import it and the header is
--     written at build time, not kept in the tree.
--
-- A file that does not compile is refused: its declarations cannot be trusted. A protocol the SDK does not declare
-- has zero members, which is a failure and not a pass.
--
-- Exit status: 0 every row conformant and every mutant red; 1 the rows with gaps are owed work and the check is
-- working; 3 a mutant went unnoticed, so the check is broken and what it says about conformant rows is not evidence.

import("core.base.json")

local root = os.getenv("CONF_ROOT")
local pkg = root .. "/packages/a/apple-backports"
local sdk = os.getenv("CONF_SDK")
local clang = os.getenv("CONF_CLANG")
local gen = os.getenv("CONF_GEN")
local work = os.getenv("CONF_WORK")
local mode = os.getenv("CONF_MODE") or "all"

-- The protocols whose rows are checked, as the python version listed them.
local CHECKED = {
    "MTLDevice", "MTLResource", "MTLBuffer", "MTLTexture", "MTLSamplerState", "MTLFunction",
    "MTLLibrary", "MTLRenderPipelineState", "MTLCommandQueue", "MTLCommandBuffer",
    "MTLCommandEncoder", "MTLRenderCommandEncoder", "MTLDrawable",
    "MTLDepthStencilState", "MTLCaptureScope",
}

-- The rows with no @interface of their own, and the protocols 16.4 says each inherits FROM.
local INHERITED_BY = {
    MTLResource = {"MTLBuffer", "MTLTexture"},
    MTLCommandEncoder = {"MTLRenderCommandEncoder", "MTLComputeCommandEncoder"},
    MTLDrawable = {"CAMetalDrawable"},
}

-- The mutants, on the rows the criterion most often catches: protocol, class, the class's own file.
local MUTANT_ROWS = {
    {"MTLFunction", "CharonMetalFunction", "Metal/CharonMetalLibrary.m"},
    {"MTLDepthStencilState", "CharonMetalDepthStencil", "Metal/CharonMetalDepthStencil.m"},
    {"MTLCaptureScope", "CharonMTLCaptureScope", "Metal/MTLCaptureManager11.m"},
}

local function q(s)
    return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

local function read(p)
    local f = io.open(p, "r")
    if not f then return "" end
    local s = f:read("a")
    f:close()
    return s
end

local function write(p, s)
    local f = io.open(p, "w")
    f:write(s)
    f:close()
end

local function upper_first(s)
    return s:sub(1, 1):upper() .. s:sub(2)
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The files of the Metal folder with an extension, sorted, so the first match is the same on every run. Every class
-- the rows name is in that folder; the registry rows are read from the registry's own folder.
local function package_files(ext, folder)
    local out = {}
    for _, p in ipairs(os.files((folder or (pkg .. "/Metal")) .. "/*." .. ext) or {}) do
        out[#out + 1] = p
    end
    table.sort(out)
    return out
end

-- A file read once per run: the class scans look at the same files again and again.
local reads = {}
local function cached(p)
    if reads[p] == nil then reads[p] = read(p) end
    return reads[p]
end

local run_counter = 0

-- Runs clang on FILE with ARGS from CWD. The AST (stdout) and the diagnostics (stderr) are written to files of the
-- run directory and read back separately, so a diagnostic line can never be taken for a node of the tree.
local function clang_run(cwd, args, file, tag)
    run_counter = run_counter + 1
    local base = work .. "/" .. tostring(run_counter) .. "-" .. tag
    local quoted = {}
    for i, a in ipairs(args) do quoted[i] = q(a) end
    local cmd = "cd " .. q(cwd) .. " && " .. q(clang) .. " " .. table.concat(quoted, " ") .. " " .. q(file)
        .. " > " .. q(base .. ".out") .. " 2> " .. q(base .. ".err") .. "; echo $?"
    local rc = tonumber((os.iorunv("/bin/sh", {"-c", cmd}) or ""):match("(%d+)%s*$")) or -1
    return rc, read(base .. ".out"), read(base .. ".err")
end

local function base_flags()
    return {"-target", "armv7-apple-ios6.1.3", "-isysroot", sdk, "-fobjc-arc", "-Os", "-g0",
            "-Wno-unguarded-availability-new", "-Wno-unguarded-availability", "-I", gen}
end

-- The AST of one file, filtered to the declarations whose name contains FILTER. A file that does not compile gives
-- nil and its error lines: its exit status is not zero, or a line is in the form <file>:<line>:<col>: error:.
local function ast(file, filter, tag)
    local args = base_flags()
    for _, a in ipairs({"-Werror=objc-missing-property-synthesis", "-fsyntax-only", "-Xclang", "-ast-dump",
                        "-Xclang", "-ast-dump-filter=" .. filter}) do
        args[#args + 1] = a
    end
    local rc, out, err = clang_run(pkg, args, file, tag)
    local errors = {}
    for line in (err .. "\n"):gmatch("(.-)\n") do
        if line:match("^%S+:%d+:%d+: fatal error:") or line:match("^%S+:%d+:%d+: error:") then
            errors[#errors + 1] = line
        end
    end
    if rc ~= 0 or #errors > 0 then
        return nil, errors
    end
    return out, nil
end

-- The tree of a text dump: blocks named by their "Dumping NAME:" line, each holding its nodes in order with their depth.
local function parse(text)
    local blocks, block = {}, nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local name = line:match("^Dumping (.+):$")
        if name then
            block = {name = name, nodes = {}}
            blocks[#blocks + 1] = block
        elseif block and line ~= "" then
            -- every level of the tree is two columns: "|-", "`-" or "| " before the marker
            local prefix = line:match("^([| `%-]*)")
            block.nodes[#block.nodes + 1] = {depth = math.floor(#prefix / 2), text = line:sub(#prefix + 1)}
        end
    end
    return blocks
end

-- The indices of the direct children of node i.
local function children(nodes, i)
    local out = {}
    local d = nodes[i].depth
    local j = i + 1
    while j <= #nodes and nodes[j].depth > d do
        if nodes[j].depth == d + 1 then out[#out + 1] = j end
        j = j + 1
    end
    return out
end

-- The sign and the selector of an ObjCMethodDecl's text: "... - addDebugMarker:range:" gives "-", "addDebugMarker:range:".
local function selector_of(text)
    return text:match("%s([%-+]) (%S+)")
end

-- The members of a protocol: the union over every declaration of that name (a forward declaration has none).
local function protocol_members(blocks, name)
    local members = {}
    for _, b in ipairs(blocks) do
        if b.name == name and b.nodes[1] and b.nodes[1].text:match("^ObjCProtocolDecl") then
            for _, j in ipairs(children(b.nodes, 1)) do
                local t = b.nodes[j].text
                if t:match("^ObjCMethodDecl") then
                    local sign, sel = selector_of(t)
                    if sel then members[(sign == "+" and "+" or "-") .. sel] = true end
                elseif t:match("^ObjCPropertyDecl") then
                    local before = t:match("^(.-)'")
                    local getter = before and before:match("(%S+)%s*$")
                    if getter then
                        members["-" .. getter] = true
                        -- a setter is owed for a readwrite property, which the AST marks by the absence of readonly
                        if not t:find("readonly", 1, true) then
                            members["-set" .. upper_first(getter) .. ":"] = true
                        end
                    end
                end
            end
        end
    end
    return members
end

-- The selectors a class defines in one file: each method with a body in its @implementation or in one of its
-- categories, and each @synthesize binding (a getter and a setter).
-- BODIES, when given, collects only the methods defined with a body, which a mutant can remove.
local function defines_in(blocks, cls, defines, bodies)
    for _, b in ipairs(blocks) do
        local own = b.name == cls
        local category = b.name:sub(1, #cls + 2) == cls .. "::"
        if own or category then
            for i, n in ipairs(b.nodes) do
                if n.text:match("^ObjCMethodDecl") then
                    local hasBody = false
                    for _, j in ipairs(children(b.nodes, i)) do
                        if b.nodes[j].text:match("^CompoundStmt") then hasBody = true end
                    end
                    local sign, sel = selector_of(n.text)
                    if hasBody and sel then
                        local key = (sign == "+" and "+" or "-") .. sel
                        defines[key] = true
                        if bodies then bodies[key] = true end
                    end
                elseif own and n.text:match("^ObjCPropertyImplDecl") then
                    local name = n.text:match("(%S+)%s+synthesize") or n.text:match("(%S+)%s+dynamic")
                    if name then
                        defines["-" .. name] = true
                        defines["-set" .. upper_first(name) .. ":"] = true
                    end
                end
            end
        end
    end
    return defines
end

-- Every package file that implements the class: its @implementation, or a category of it. OVERRIDES maps a package
-- file to the scratch copy a mutant was written to.
local function implementing_files(cls, overrides)
    local out = {}
    for _, p in ipairs(package_files("m")) do
        if cached(p):find("@implementation%s+" .. cls .. "%f[^%w_]") then
            out[#out + 1] = (overrides and overrides[p]) or p
        end
    end
    return out
end

-- The class of a row: the one whose @interface adopts the protocol, else one that adopts a protocol inheriting it.
local function class_of(protocol)
    local inherit = INHERITED_BY[protocol] or {}
    local fallback_cls, fallback_file
    local files = package_files("h")
    for _, p in ipairs(package_files("m")) do files[#files + 1] = p end
    for _, p in ipairs(files) do
        for line in cached(p):gmatch("[^\n]+") do
            local cls, list = line:match("^@interface (%w+) : NSObject <(.-)>")
            if cls then
                for item in list:gmatch("[^,]+") do
                    local name = trim(item)
                    if name == protocol then return cls, p end
                    for _, inh in ipairs(inherit) do
                        if name == inh and not fallback_cls then fallback_cls, fallback_file = cls, p end
                    end
                end
            end
        end
    end
    return fallback_cls, fallback_file
end

-- The file of a class: the one named after it, else the first that implements it.
local function file_of(cls)
    for _, p in ipairs(package_files("m")) do
        if p:match("/" .. cls .. "%.m$") then return p end
    end
    return implementing_files(cls)[1]
end

-- The criterion for one row. Returns the missing selectors (empty when conformant) and the member count, or nil and
-- the reason. OVERRIDES maps package files to scratch copies (a mutant).
local function check(protocol, cls, overrides, tag)
    local protoFile = file_of(cls)
    if not protoFile then return nil, "has no file in the package" end
    if overrides and overrides[protoFile] then protoFile = overrides[protoFile] end
    local protoText, protoErr = ast(protoFile, protocol, tag .. "-proto")
    if not protoText then
        return nil, "does not compile, so its declarations cannot be trusted: " .. table.concat(protoErr, " | ")
    end
    local members = protocol_members(parse(protoText), protocol)
    local count = 0
    for _ in pairs(members) do count = count + 1 end
    if count == 0 then
        return nil, "is not declared by the SDK, or the headers were not read: 0 members is a pass about nothing"
    end
    local defines = {}
    for _, f in ipairs(implementing_files(cls, overrides)) do
        local text, errs = ast(f, cls, tag .. "-cls")
        if not text then
            return nil, "does not compile, so its declarations cannot be trusted: " .. table.concat(errs, " | ")
        end
        defines_in(parse(text), cls, defines)
    end
    local missing = {}
    for m in pairs(members) do
        if not defines[m] then missing[#missing + 1] = m end
    end
    table.sort(missing)
    return missing, count
end

-- The -Wprotocol cross-check, for methods: a method inherited from another class would pass the criterion above.
local function wprotocol(protocol, file)
    local args = base_flags()
    args[#args + 1] = "-Wall"
    args[#args + 1] = "-Wprotocol"
    args[#args + 1] = "-fsyntax-only"
    local _, _, err = clang_run(pkg, args, file, "wprotocol")
    local lines = {}
    for line in (err .. "\n"):gmatch("(.-)\n") do
        if line:find("in protocol '" .. protocol .. "' not implemented", 1, true) then
            lines[#lines + 1] = line
        end
    end
    return lines
end

-- The selector a method DEFINITION names, from its head: "- (BOOL)setX:(int)x y:(int)y" gives "setX:y:"; "- (id)device" "device".
local function head_selector(head)
    local rest = head:gsub("^[-+]%s*%b()", "", 1)
    local pieces = {}
    for piece in rest:gmatch("([%w_]+)%s*:%s*%b()%s*[%w_]+") do pieces[#pieces + 1] = piece .. ":" end
    if #pieces > 0 then return table.concat(pieces) end
    return rest:match("^%s*([%w_]+)%s*$")
end

-- The source without the definition of SELECTOR: its head, its body, and the comment lines above it. Works on lines.
-- Returns nil when the text has no such definition.
local function remove_definition(source, selector)
    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    for i, line in ipairs(lines) do
        if line:match("^[-+] %(") then
            -- the head runs to the line that opens the body, which starts with "{"
            local k = i
            while k <= #lines and not lines[k]:match("^{") do k = k + 1 end
            if k > #lines then return nil end
            local head = table.concat(lines, " ", i, k - 1)
            if head_selector(head) == selector then
                -- the body: from line k to the line where its braces balance
                local depth, last = 0, k
                for j = k, #lines do
                    for c in lines[j]:gmatch(".") do
                        if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
                    end
                    last = j
                    if depth == 0 then break end
                end
                -- comment lines directly above the head go with it
                local first = i
                while first > 1 and lines[first - 1]:match("^%s*//") do first = first - 1 end
                -- and the blank line the removal would leave behind
                if lines[last + 1] == "" then last = last + 1 end
                local kept = {}
                for j, l in ipairs(lines) do
                    if j < first or j > last then kept[#kept + 1] = l end
                end
                return table.concat(kept, "\n")
            end
        end
    end
    return nil
end

-- The mutants: one member the protocol requires and the class defines is removed from a scratch copy, and the check
-- must report it. Returns the number of mutants run, how many were red, and whether any failed in another way.
local function mutants()
    local tree = work .. "/tree"
    os.tryrm(tree)
    os.mkdir(tree)
    os.cp(pkg .. "/Metal", tree .. "/Metal")
    -- the Metal folder reaches the package's own headers as "../X.h" (air2cpu-abi.h), so the copy carries them too
    for _, h in ipairs(os.files(pkg .. "/*.h") or {}) do
        os.cp(h, tree .. "/" .. path.filename(h))
    end
    local runs, red, failed = 0, 0, false
    for _, row in ipairs(MUTANT_ROWS) do
        local protocol, cls, file = row[1], row[2], row[3]
        local original = pkg .. "/" .. file
        local scratch = tree .. "/" .. file
        for _, kind in ipairs({"method", "getter"}) do
            runs = runs + 1
            -- the members the protocol requires that the class defines, from the unmodified package
            local wanted = protocol_members(parse(ast(original, protocol, "mut-want") or ""), protocol)
            local defines, bodies = {}, {}
            for _, f in ipairs(implementing_files(cls)) do
                defines_in(parse(ast(f, cls, "mut-def") or ""), cls, defines, bodies)
            end
            local removable = {}
            for m in pairs(wanted) do
                if bodies[m] then removable[#removable + 1] = m end
            end
            table.sort(removable)
            local chosen
            for _, sel in ipairs(removable) do
                local isSetter = sel:match("^%-set") ~= nil
                if not chosen and kind == "method" and not isSetter and sel:match("^[-+]") then chosen = sel end
                if not chosen and kind == "getter" and sel:match("^%-") and not isSetter then chosen = sel end
            end
            if not chosen then
                print(string.format("  FAIL the %s mutant on %s via %s: the class defines no such member", kind, protocol, cls))
                failed = true
            else
                local name = chosen:gsub("^[-+]", "")
                local mutated = remove_definition(read(original), name)
                if not mutated then
                    print(string.format("  FAIL the %s mutant on %s via %s: no definition of %s", kind, protocol, cls, name))
                    failed = true
                else
                    write(scratch, mutated)
                    local missing, why = check(protocol, cls, {[original] = scratch}, "mutant-" .. kind)
                    if missing and #missing > 0 then
                        red = red + 1
                        print(string.format("  ok   %s mutant on %s via %s: removed %s -> %d selector(s) missing",
                            kind, protocol, cls, chosen, #missing))
                    elseif missing == nil then
                        -- the mutant did not get a verdict: it is not evidence either way, so it is not red
                        print(string.format("  FAIL the %s mutant on %s via %s gave no verdict: %s", kind, protocol, cls, why))
                        failed = true
                    else
                        print(string.format("  FAIL the %s mutant on %s via %s went unnoticed: removed %s", kind, protocol, cls, chosen))
                        failed = true
                    end
                end
            end
        end
    end
    return runs, red, failed
end

local function rows_from_registry()
    local rows = {}
    for _, p in ipairs(package_files("json", pkg .. "/registry/Metal")) do
        do
            local doc = json.decode(read(p))
            for _, e in ipairs(doc.entries or doc) do
                if e.kind == "protocol" then
                    for _, name in ipairs(CHECKED) do
                        if e.api == name then rows[#rows + 1] = {name, e.status, p} end
                    end
                end
            end
        end
    end
    return rows
end

local function main()
    print("the criterion: clang -ast-dump-filter; the class's files and its categories; read in place")
    local rows
    if mode == "members" then
        rows = {{os.getenv("CONF_PROTOCOL"), nil, os.getenv("CONF_FILE")}}
    else
        rows = rows_from_registry()
    end
    local conformant, gapped, selectors, failed = 0, 0, 0, false
    for _, row in ipairs(rows) do
        local protocol = row[1]
        local cls, file
        if mode == "members" then
            cls = os.getenv("CONF_CLASS")
            file = pkg .. "/" .. row[3]
        else
            cls, file = class_of(protocol)
        end
        if not cls then
            print(string.format("%s\t?\t?", protocol))
            failed = true
        else
            local missing, countOrReason = check(protocol, cls, nil, "row-" .. protocol)
            if missing == nil then
                print(string.format("  %-26s via %-28s %s", protocol, cls, countOrReason))
                failed = true
            else
                print(string.format("  %-26s via %-28s %s", protocol, cls, (file or ""):sub(#pkg + 2)))
                if #missing > 0 then
                    for _, m in ipairs(missing) do print("      missing: " .. m) end
                    gapped = gapped + 1
                    selectors = selectors + #missing
                else
                    print("      every protocol member is defined")
                    conformant = conformant + 1
                end
                for _, w in ipairs(wprotocol(protocol, file)) do
                    print("      -Wprotocol: " .. w)
                end
            end
        end
        print("")
    end
    print(string.format("protocol-conformance: %d row(s) checked, %d conformant, %d inert with %d selector(s) owed",
        #rows, conformant, gapped, selectors))
    return failed or gapped > 0, #rows
end

if mode == "mutants" then
    local runs, red, failed = mutants()
    print(string.format("mutants: %d run(s), %d red", runs, red))
    os.exit(runs ~= red and 3 or (failed and 1 or 0))
end

local gaps, _ = main()
local runs, red, failed = mutants()
print(string.format("mutants: %d run(s), %d red", runs, red))
if runs ~= red then
    print(string.format("EXIT 3 - THE CHECK IS BROKEN: %d mutant(s) went unnoticed, so its verdict on a conformant row is not evidence", runs - red))
    os.exit(3)
end
if gaps or failed then
    print("EXIT 1 - the gap rows are inert by the rule, and every mutant was red, so the check is working")
    os.exit(1)
end
print("every row conformant, and every mutant red")
os.exit(0)
