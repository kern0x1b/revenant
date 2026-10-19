-- probe_types.lua - asks the compiler what each type is, and writes the table the generator reads. A port of
-- probe-types.py, which says what the two signals are and why the probe is built for the host.
--
--     VT_SDK=<an iPhoneOS*.sdk> xmake l probe_types.lua
--
-- The table is written beside this script, as type-branches.tsv, and it is committed: the generator reads
-- that file. A run overwrites it, which is what the Python did. The probe's own build output goes under the
-- worktree's .agent-work/runs/vt, which is four levels above this directory (the worktree root).
--
-- Subprocesses are run through sh, so the exit status of the compile and the stderr of the compile can be
-- read: os.iorunv raises on a nonzero exit, and the Python did not stop on the run's exit status at all.

local G = import("gen_body", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})

-- os.path.abspath: an absolute path with "." and ".." resolved as text, which is what Python does.
local function abspath(p)
    if string.sub(p, 1, 1) ~= "/" then
        p = (os.getenv("PWD") or ".") .. "/" .. p
    end
    local parts = {}
    for piece in string.gmatch(p, "[^/]+") do
        if piece == ".." then
            parts[#parts] = nil
        elseif piece ~= "." then
            parts[#parts + 1] = piece
        end
    end
    return "/" .. table.concat(parts, "/")
end

-- os.makedirs: every missing directory on the way to path.
local function makedirs(path)
    local current = ""
    for piece in string.gmatch(path, "[^/]+") do
        current = current .. "/" .. piece
        if not os.isdir(current) then
            os.mkdir(current)
        end
    end
end

-- Writes a file, or ends the run with exit 1 where the Python's open(path, "w") raised.
local function write_or_fail(path, text)
    try {
        function()
            V.write_file(path, text)
        end,
        catch {
            function(err)
                V.fail("probe_types.lua: cannot write " .. path .. ": " .. tostring(err))
            end
        }
    }
end

-- A word in single quotes for sh, with any single quote in it written as '\''.
local function shell_quote(s)
    local escaped = string.gsub(s, "'", "'\\''")
    return "'" .. escaped .. "'"
end

-- Python's str.split(sep) for a one-character sep: every piece, empty ones included.
local function split_on(s, sep)
    local out = {}
    local start = 1
    while true do
        local at = string.find(s, sep, start, true)
        if not at then
            out[#out + 1] = string.sub(s, start)
            break
        end
        out[#out + 1] = string.sub(s, start, at - 1)
        start = at + 1
    end
    return out
end

-- Python: collect_types(gen_body, sdk). Every type the store line will be asked about, from the SDK's own
-- declarations: the argument types of the initialisers, then the type of every property, each once, in
-- order. A property's type is its type, with " *" when it is an object.
local function collect_types(sdk)
    local headers = V.join_path(sdk, "System/Library/Frameworks/VideoToolbox.framework/Headers")
    local text = V.header_text(headers)
    local protocols, classes = G.parse(text)
    local ordered, seen = {}, {}

    local function add(type_name)
        if type_name ~= nil and type_name ~= "" and not seen[type_name] then
            seen[type_name] = true
            ordered[#ordered + 1] = type_name
        end
    end

    local function property_type(prop)
        return prop.type .. (prop.obj and " *" or "")
    end

    for _, cls in ipairs(G.ORDER()) do
        for _, initialiser in ipairs(G.initialisers(text, cls)) do
            for _, argument in ipairs(initialiser[2]) do
                add(argument[2])
            end
        end
    end
    for _, cls in ipairs(G.ORDER()) do
        local entry = classes[cls]
        -- inherited = [protocols[proto][name] for proto in entry["protocols"] for name in protocols[proto]]
        local inherited = {}
        for _, proto in ipairs(entry.protocols) do
            local pm = protocols[proto]
            if pm == nil then
                V.fail("probe_types.lua: KeyError: " .. V.py_repr(proto))
            end
            for _, name in ipairs(pm.keys) do
                inherited[#inherited + 1] = pm.map[name]
            end
        end
        -- list(entry["own"].items()) + list(zip(entry["own"], inherited)): the own properties, then each own
        -- name paired with the inherited property at the same position, for as far as both go
        for _, name in ipairs(entry.own.keys) do
            add(property_type(entry.own.map[name]))
        end
        for i = 1, math.min(#entry.own.keys, #inherited) do
            add(property_type(inherited[i]))
        end
    end
    return ordered
end

function main()
    local sdk = os.getenv("VT_SDK") or ""
    if sdk == "" then
        V.fail("probe_types.lua: set VT_SDK to an iPhoneOS*.sdk")
    end
    local types
    try {
        function()
            types = collect_types(sdk)
        end,
        catch {
            function(err)
                V.fail(tostring(err))
            end
        }
    }

    -- HERE and WORKTREE as Python computed them: abspath of this directory, and of four levels above it
    local here = abspath(os.scriptdir())
    local worktree = abspath(here .. "/../../../..")
    local out_dir = worktree .. "/.agent-work/runs/vt"
    local table_path = here .. "/type-branches.tsv"

    if not os.isdir(out_dir) then
        makedirs(out_dir)
    end
    local source = out_dir .. "/classify.m"
    local classify = out_dir .. "/classify"
    local build_err = out_dir .. "/classify.err"

    local lines = {
        "// GENERATED by probe-types.py - one line per type, two signals.",
        "#import <VideoToolbox/VideoToolbox.h>",
        "#import <CoreMedia/CoreMedia.h>",
        "#import <CoreVideo/CVBuffer.h>",
        "#import <CoreVideo/CVPixelBuffer.h>",
        "#include <stdio.h>",
        "int main(void)",
        "{",
    }
    for _, t in ipairs(types) do
        lines[#lines + 1] = "    printf(\"%s\\t%d\\t%s\\n\", \"" .. t .. "\", __builtin_classify_type(*("
            .. t .. " *)0), (@encode(" .. t .. ")[0] == '@' ? \"objc\" : \"not-objc\"));"
    end
    lines[#lines + 1] = "    return 0;"
    lines[#lines + 1] = "}"
    write_or_fail(source, table.concat(lines, "\n") .. "\n")

    -- The build is the Python's subprocess.run: no shell, the compiler's stdout discarded, its stderr kept,
    -- and a nonzero status is the "did not build" exit. The status is printed by the shell and read back.
    local status_text = os.iorunv("sh", {"-c", "xcrun clang -framework CoreMedia -framework CoreVideo "
        .. shell_quote(source) .. " -o " .. shell_quote(classify) .. " >/dev/null 2>" .. shell_quote(build_err)
        .. "; echo $?"})
    local status = tonumber(string.match(status_text, "%d+"))
    if status ~= 0 then
        local stderr = V.read_text(build_err)
        V.fail("the probe did not build:\n" .. string.sub(stderr, 1, 2000))
    end

    -- The run's stdout, whatever its status: the Python ignored the run's returncode too.
    local stdout = os.iorunv("sh", {"-c", "\"$0\" 2>/dev/null; true", classify})
    local text = string.match(stdout, "^%s*(.-)%s*$")
    local rows, disagree = {}, {}
    for _, line in ipairs(split_on(text, "\n")) do
        local fields = split_on(line, "\t")
        if #fields ~= 3 then
            V.fail("probe_types.lua: a probe line does not have three fields: " .. V.py_repr(line))
        end
        local name, klass_text, encode = fields[1], fields[2], fields[3]
        if not string.match(klass_text, "^[+-]?%d+$") then
            V.fail("probe_types.lua: invalid literal for int() with base 10: " .. V.py_repr(klass_text))
        end
        local klass = math.tointeger(tonumber(klass_text))
        if (klass == -1) ~= (encode == "objc") then
            disagree[#disagree + 1] = line
        end
        rows[#rows + 1] = {name, klass, encode}
    end

    print("table: " .. table_path)
    local written = {}
    for _, row in ipairs(rows) do
        written[#written + 1] = row[1] .. "\t" .. string.format("%d", row[2]) .. "\t" .. row[3] .. "\n"
    end
    write_or_fail(table_path, table.concat(written))
    print("probe: " .. #rows .. " types, from the initialisers AND the properties")
    if #disagree > 0 then
        for _, line in ipairs(disagree) do
            print("DISAGREE the two signals say different things: " .. line)
        end
        os.exit(1)
    end

    -- classes: how many rows each __builtin_classify_type class has, in numeric order of the class
    local counts, class_numbers = {}, {}
    for _, row in ipairs(rows) do
        if counts[row[2]] == nil then
            counts[row[2]] = 0
            class_numbers[#class_numbers + 1] = row[2]
        end
        counts[row[2]] = counts[row[2]] + 1
    end
    table.sort(class_numbers)
    local parts = {}
    for _, k in ipairs(class_numbers) do
        parts[#parts + 1] = string.format("%d x%d", k, counts[k])
    end
    print("classes the compiler printed: " .. table.concat(parts, ", "))
    print("the two signals agree on all " .. #rows)
    print("table: " .. table_path)
end
