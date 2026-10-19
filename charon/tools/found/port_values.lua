-- The enumerator values of the port's triple: decls (the declaration extractor) run over every framework of the SDK with IR_TARGET set
-- to the port's triple, so clang evaluates each enumerator for the ABI the port is built for (armv7 is ILP32: NSIntegerMax is
-- 2147483647 there, and ~1ul is 4294967294). The headers command takes these values for the port's headers (tools/gen/port_enums.lua),
-- joined to the IR's rows by USR. The SDK's own values stay in the IR and the faithful headers.
--
-- The file written is a TSV with a header comment (the triple and the extractor's version), then one line per enumerator the run gives a
-- value, and one per enum whose underlying type the run gives (an enum with no fixed type has the type clang picks for the triple: the
-- IR's unsigned long is unsigned long long on armv7 for DISPATCH_WALLTIME_NOW):
--   enumconst <TAB> framework <TAB> usr <TAB> value
--   enumtype  <TAB> framework <TAB> usr <TAB> type
-- and one line per module that does not parse for the triple, with the first error decls names:
--   unparsed <TAB> framework <TAB> - <TAB> reason
-- A module that does not parse keeps the faithful values of its enumerators in the port's headers; the run prints it.
--
-- usage (from the repository root): IR_SDK=<iPhoneOS sdk> IR_PORT_VALUES=<out.tsv> [IR_PORT_TRIPLE=armv7-apple-ios6.1.3]
--                 [IR_TIMEOUT=300] [IR_DECLS=<decls binary>] xmake l ./tools/found/port_values.lua
-- A run of decls that does not finish (a timeout ends it by SIGALRM, a crash) raises: it is not a result, and nothing is written.
-- The file is written whole, once every framework has run.

local SDK = os.getenv("IR_SDK")
if not SDK then raise("IR_SDK must name the iPhoneOS SDK (for example .../iPhoneOS<version>.sdk)") end
SDK = path.absolute(SDK)
local OUT = os.getenv("IR_PORT_VALUES")
if not OUT then raise("IR_PORT_VALUES must name the file the port's enumerator values are written to") end
local TRIPLE = os.getenv("IR_PORT_TRIPLE") or "armv7-apple-ios6.1.3"
local TIMEOUT = os.getenv("IR_TIMEOUT") or "300"
local FOUND = path.absolute(os.scriptdir())
local TOOLS = path.directory(FOUND)
local REPO = path.directory(TOOLS)
local stream = import("gen.stream", {rootdir = TOOLS, anonymous = true})
local host = import("gen.host", {rootdir = TOOLS, anonymous = true})
local atomic = import("atomic", {rootdir = TOOLS, anonymous = true})
-- the extractor: the decls target of tools/found, where xmake puts it for this repository (the same lookup ir.lua uses)
local DECLS = os.getenv("IR_DECLS") or host.target_product(REPO, FOUND, "decls")

-- The SDK's path is redacted from what the extractor says, so the file does not depend on where the SDK is installed.
local function redact(s)
    return (s:gsub(SDK:gsub("%p", "%%%0"), "<sdk>"))
end

-- decls with the SDK and the triple in its environment: the lines it printed, its status, and its standard error.
local function decls_run(args)
    local lines = {}
    local status, errors = stream.run("/usr/bin/env", table.join({"IR_SDK=" .. SDK, "IR_TARGET=" .. TRIPLE, DECLS}, args), function (line)
        table.insert(lines, line)
    end)
    return lines, status, (errors:gsub("%s+$", ""))
end

-- The tab-separated cells of one line.
local function cells_of(line)
    local out = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(out, cell) end
    return out
end

local frameworks = {}
local listed, list_status, list_errors = decls_run({"--list"})
if list_status ~= 0 then raise(string.format("decls --list exited %d: %s", list_status, redact(list_errors))) end
for _, line in ipairs(listed) do
    table.insert(frameworks, string.match(line, "^([^\t]+)\t"))
end

local version = decls_run({"--version"})[1] or "-"
local rows = {"# triple=" .. TRIPLE .. " decls: " .. version}
local unparsed, enumerators = 0, 0
for _, name in ipairs(frameworks) do
    local lines, status, errors = decls_run({"--timeout", TIMEOUT, name})
    if status ~= 0 then
        raise(string.format("%s: decls did not finish for %s (status %d)%s", name, TRIPLE, status,
                            errors ~= "" and (": " .. redact(errors)) or ""))
    end
    local first = lines[1] and cells_of(lines[1])
    if first and first[2] == "unparsed" then
        -- the module does not parse for the triple: its reason is the name column of its unparsed row
        unparsed = unparsed + 1
        table.insert(rows, "unparsed\t" .. name .. "\t-\t" .. first[5])
        print("unparsed for " .. TRIPLE .. ": " .. name .. ": " .. first[5])
    else
        for _, line in ipairs(lines) do
            local cells = cells_of(line)
            if cells[2] == "enumconst" and cells[14] ~= "-" then
                enumerators = enumerators + 1
                table.insert(rows, "enumconst\t" .. name .. "\t" .. cells[3] .. "\t" .. cells[14])
            elseif cells[2] == "enum" and cells[11] ~= "-" then
                table.insert(rows, "enumtype\t" .. name .. "\t" .. cells[3] .. "\t" .. cells[11])
            end
        end
    end
end
atomic.write(OUT, table.concat(rows, "\n") .. "\n")
print(string.format("port values for %s: %d enumerators in %d frameworks, %d modules unparsed for it, written to %s",
    TRIPLE, enumerators, #frameworks, unparsed, OUT))
