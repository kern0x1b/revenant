-- The host programs of the differential and of the probe are xmake build products (design-spec-driven.md D5): the project
-- tools/gen/host/xmake.lua declares the oracle (the fixed probe source), the constants dylib (the framework's <F>Constants*.m
-- objects) and the reference program (the source this module writes for the framework's names). This module configures that
-- project for one framework, asks xmake where its build directory and products are, and builds them. xmake decides what is
-- rebuilt. Generated sources are written through emit into the build directory xmake reports; nothing is copied and no run
-- deletes a product. Every call configures the project for the framework it is given, so a run for one framework leaves no
-- configuration that another run reads.

local emit = import("emit", {anonymous = true})
local stream = import("stream", {anonymous = true})
local strings = import("strings", {anonymous = true})
local json = import("core.base.json")

-- The project folder, as an absolute path taken when the module loads (xmake reports paths relative to the working folder).
local PROJECT = path.absolute(path.join(os.scriptdir(), "host"))
local HOST = "/System/Library/Frameworks"

local builddir_cache = nil
local product_cache = {}

-- The text without the colour codes xmake puts in its messages.
local function plain(text)
    return (string.gsub(text or "", "\27%[[%d;]*m", ""))
end

-- The last n bytes of the text without its surrounding white space (the tail the messages quote).
function tail(text, n)
    local stripped = string.gsub(string.gsub(text or "", "^%s+", ""), "%s+$", "")
    return string.sub(stripped, -n)
end

-- The first 200 bytes of xmake's output, for an error message that must show what was printed.
local function head(text)
    return string.sub(string.gsub(text or "", "%s+$", ""), 1, 200)
end

-- The index of the brace that closes the JSON object opened at text[start], a brace inside a string not counted; nil when the text
-- does not close it.
local function object_end(text, start)
    local depth, in_string, i = 0, false, start
    while i <= #text do
        local c = string.sub(text, i, i)
        if in_string then
            if c == "\\" then
                i = i + 1
            elseif c == "\"" then
                in_string = false
            end
        elseif c == "\"" then
            in_string = true
        elseif c == "{" then
            depth = depth + 1
        elseif c == "}" then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
        i = i + 1
    end
    return nil
end

-- The JSON object xmake printed on its standard output, decoded, and the text xmake printed after it (trimmed; "" when none). The
-- object starts at the beginning of a line: a message xmake prints before it may hold a brace (the first "{" of the text is then not
-- the object's), so the search is for a line that opens with one. xmake may print a warning after the object (a target of a project
-- that is not configured yet: "not checked yet"), so only the object is decoded, and the warning comes back for the caller to report.
-- A text with no such line, or an object that does not decode, is an error that names what was asked and shows the head of the
-- output, never a decode error on a substring of it.
function json_of(text, what)
    local start = nil
    if string.sub(text, 1, 1) == "{" then
        start = 1
    else
        local at = string.find(text, "\n{", 1, true)
        start = at and at + 1 or nil
    end
    assert(start, what .. ": xmake printed no JSON object; its output begins: " .. head(text))
    local finish = object_end(text, start) or #text
    local body = string.sub(text, start, finish)
    local notes = string.gsub(string.gsub(string.sub(text, finish + 1), "^%s+", ""), "%s+$", "")
    local value = nil
    try {
        function()
            value = json.decode(body)
        end,
        catch {
            function(e)
                raise(what .. ": the JSON object does not decode (" .. tostring(e) .. "); its output begins: " .. head(text))
            end
        }
    }
    return value, notes
end

-- Runs a program and returns ok (exit status 0), its standard output (one line per line of the program, each ended by a line feed),
-- its standard error, and its exit status. The output goes through a pipe (stream.lua): no file is written for it.
function run(program, argv)
    local out = {}
    local status, err = stream.run(program, argv or {}, function(line)
        table.insert(out, line)
    end)
    local text = #out > 0 and (table.concat(out, "\n") .. "\n") or ""
    return status == 0, text, err, status
end

-- Runs xmake on a project from a folder. xmake takes its configuration and its build directory from the folder it runs in (when that
-- folder holds a .xmake folder), so the folder is part of the call. Returns ok, stdout, stderr; on failure, ok is false and stderr is
-- the error text.
local function xmake_at(cwd, project, argv)
    local here = os.curdir()
    local ok, out, err = true, "", ""
    local command = table.join({argv[1]}, {"-P", project}, table.slice(argv, 2))
    try {
        function()
            os.cd(cwd)
            ok, out, err = run(os.programfile(), command)
        end,
        catch {
            function(e)
                ok, out, err = false, "", tostring(e)
            end
        }
    }
    os.cd(here)
    return ok, plain(out), plain(err)
end

-- Runs xmake on the host project, from the project folder.
local function xmake(argv)
    return xmake_at(PROJECT, PROJECT, argv)
end

-- The product xmake reports for a target of a project, absolute: asked from the folder cwd, so it is the product of the build folder
-- cwd's configuration names (the same answer a build from cwd gives). The product is not checked: it may not be built yet. Also returns
-- what xmake printed after the object (json_of): a warning such as "not checked yet" says the project is not configured in cwd.
function target_product(cwd, project, name)
    local ok, out, err = xmake_at(cwd, project, {"show", "-t", name, "--format=json"})
    assert(ok, "xmake show failed for " .. name .. " of " .. project .. ": " .. tail(err, 300))
    local shown, notes = json_of(out, "xmake show -t " .. name .. " of " .. project)
    local file = shown.targetfile
    if not path.is_absolute(file) then
        file = path.join(project, file)
    end
    return path.normalize(path.absolute(file)), notes
end

-- Configures the project for one framework and its constants folder (the .gen folder of the framework in the tree).
function configure(framework, sources)
    local ok, _, err = xmake({"f", "-y", "-q", "--framework=" .. framework, "--sources=" .. sources})
    assert(ok, "xmake configure failed: " .. tail(err, 300))
end

-- The build directory xmake reports for the project, absolute.
function builddir()
    if builddir_cache == nil then
        local ok, out, err = xmake({"show", "--format=json"})
        assert(ok, "xmake show failed: " .. tail(err, 300))
        local dir = json_of(out, "xmake show").project.builddir
        if not path.is_absolute(dir) then
            dir = path.join(PROJECT, dir)
        end
        builddir_cache = path.absolute(dir)
    end
    return builddir_cache
end

-- The product xmake builds for a target, absolute. The project must be configured.
function product(name)
    if product_cache[name] == nil then
        product_cache[name] = target_product(PROJECT, PROJECT, name)
    end
    return product_cache[name]
end

-- Builds one target. xmake rebuilds only what its inputs changed; with force, the target is rebuilt whole (used when a generated
-- source of the target was just rewritten: xmake compares whole-second mtimes, so a source rewritten in the second its object was
-- built is not seen as newer). Returns true, or false and the error text. The build output goes to stderr, where the compile
-- lines of a rebuild show.
function build(name, force)
    local argv = {"build", "-y"}
    if force then
        table.insert(argv, "-r")
    end
    table.insert(argv, name)
    local ok, out, err = xmake(argv)
    io.stderr:write(out)
    if not ok then
        -- xmake ends an error with "> in <absolute path>" lines, which name a host path; the message keeps the rest of the text.
        local kept = {}
        for _, line in ipairs(strings.lines(err ~= "" and err or out)) do
            if not string.find(line, "^%s*>%s+in%s") then
                table.insert(kept, line)
            end
        end
        return false, table.concat(kept, "\n")
    end
    io.stderr:write(err)
    return true, ""
end

-- Writes a generated source of the build directory through emit: gen/<name> under the build directory. Returns its path, and
-- whether the file changed (emit writes nothing when the text is the file's own).
function write_generated(name, text)
    local filepath = path.join(builddir(), "gen", name)
    local changed = emit.file(filepath, text)
    return filepath, changed
end

-- The framework's binary on this host, and whether the host carries the framework at all.
function framework_binary(framework)
    return path.join(HOST, framework .. ".framework", framework), os.isdir(path.join(HOST, framework .. ".framework"))
end
