import("core.base.json")

local MODULES = path.join(os.scriptdir(), "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})

DEPRECATED_NO_VERSION = {100000}
UNAVAILABLE_VERSION = {999}
INCLUDE_SKIPPED = {["c++"] = true, _modules = true, secure = true}
INCLUDE_TOP = "include"

local open_dumps = {}

function deprecated_no_version()
    return DEPRECATED_NO_VERSION
end

function unavailable_version()
    return UNAVAILABLE_VERSION
end

function parse_version(text)
    local parts = {}
    for piece in (text .. "."):gmatch("([^.]*)%.") do
        local number = piece:match("^%s*([+-]?%d+)%s*$")
        if number == nil then
            raise("invalid literal for int() with base 10: '%s'", piece)
        end
        table.insert(parts, tonumber(number))
    end
    return parts
end

function show_version(version)
    local parts = {}
    for _, part in ipairs(version) do
        table.insert(parts, part)
    end
    while #parts > 2 and parts[#parts] == 0 do
        table.remove(parts)
    end
    local shown = {}
    for _, part in ipairs(parts) do
        table.insert(shown, tostring(part))
    end
    return table.concat(shown, ".")
end

function compare(a, b)
    local shared = math.min(#a, #b)
    for index = 1, shared do
        if a[index] ~= b[index] then
            return a[index] < b[index] and -1 or 1
        end
    end
    if #a == #b then
        return 0
    end
    return #a < #b and -1 or 1
end

function same(a, b)
    return compare(a, b) == 0
end

local function smaller(a, b)
    if a == nil then
        return b
    end
    return compare(b, a) < 0 and b or a
end

local function is_zero(version)
    return #version == 1 and version[1] == 0
end

local function word_byte(byte)
    return byte ~= nil and ((byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 95)
end

local function version_token(text, at)
    local first, last = text:find("^%d+", at)
    if first == nil then
        return nil
    end
    for _ = 1, 2 do
        local _, further = text:find("^%.%d+", last + 1)
        if further == nil then
            break
        end
        last = further
    end
    return text:sub(at, last), last + 1
end

local function availability_at(text, at, word)
    if word_byte(text:byte(at - 1)) then
        return nil
    end
    local introduced, after = version_token(text, at + #word + 1)
    if introduced == nil or text:sub(after, after) ~= " " then
        return nil
    end
    local deprecated, after_deprecated = version_token(text, after + 1)
    if deprecated == nil or text:sub(after_deprecated, after_deprecated) ~= " " then
        return nil
    end
    local obsoleted, after_obsoleted = version_token(text, after_deprecated + 1)
    if obsoleted == nil then
        return nil
    end
    return {platform = word, introduced = introduced, deprecated = deprecated, obsoleted = obsoleted,
            unavailable = text:sub(after_obsoleted, after_obsoleted + 11) == " Unavailable"}
end

function availability_search(text, words)
    local from = 1
    while true do
        local best, best_word = nil, nil
        for _, word in ipairs(words) do
            local at = text:find(word .. " ", from, true)
            if at ~= nil and (best == nil or at < best) then
                best, best_word = at, word
            end
        end
        if best == nil then
            return nil
        end
        local found = availability_at(text, best, best_word)
        if found then
            return found
        end
        from = best + 1
    end
end

local ATTRIBUTE_WORDS = {"ios", "maccatalyst"}
local AVAILABILITY_WORDS = {"ios"}

function anonymous_name(name)
    return name:find("^col:%d") ~= nil or name:find("^line:%d") ~= nil or name:find("/", 1, true) ~= nil
        or name:find("%.h:%d") ~= nil
end

local function after_location(rest)
    for at = 1, #rest do
        local text = rest:match("^col:%d+%s+(.*)$", at) or rest:match("^line:%d+:%d+%s+(.*)$", at)
            or rest:match("^[%w_/.+%-]+:%d+:%d+%s+(.*)$", at)
        if text then
            return text
        end
    end
    return rest
end

local function split_space(text, limit)
    local parts, start = {}, 1
    while #parts < limit do
        local space = text:find(" ", start, true)
        if space == nil then
            break
        end
        table.insert(parts, text:sub(start, space - 1))
        start = space + 1
    end
    table.insert(parts, text:sub(start))
    return parts
end

function member_name(kind, rest)
    local text = after_location(rest)
    if kind == "ObjCMethodDecl" then
        local parts = split_space(text, 2)
        if parts[2] == nil then
            raise("surface_walk: a method line names no selector after its sign: %s", rest)
        end
        return parts[1], parts[2]
    end
    return nil, split_space(text, 1)[1]
end

local function last_word(text)
    local found = nil
    for word in text:gmatch("%S+") do
        found = word
    end
    if found == nil then
        raise("surface_walk: a declaration line holds no name: %s", text)
    end
    return found
end

local function before_quote(text)
    local quote = text:find("'", 1, true)
    return quote and text:sub(1, quote - 1) or text
end

local function second_quoted(text)
    local first = text:find("'", 1, true)
    if first == nil then
        raise("surface_walk: an interface line quotes no name: %s", text)
    end
    local second = text:find("'", first + 1, true)
    return text:sub(first + 1, second and second - 1 or #text)
end

local Surface = {}

local function with_methods(object, methods)
    for name, method in pairs(methods) do
        object[name] = method
    end
    return object
end

function new(framework, opt)
    opt = opt or {}
    local surface = {
        framework = framework,
        full = opt.full and true or false,
        owns = opt.owns,
        anonymous = {},
        anonymous_order = {},
        file = nil,
        rows = {},
        order = {},
        details = {},
        owner = nil,
        container_version = nil,
        container_detail = nil,
        target = nil,
        target_depth = nil,
        target_attrs = {},
        accessors = {},
        enum_open = false,
        pending_category = false,
    }
    return with_methods(surface, Surface)
end

function Surface:count_anonymous(kind)
    if self.anonymous[kind] == nil then
        self.anonymous[kind] = 0
        table.insert(self.anonymous_order, kind)
    end
    self.anonymous[kind] = self.anonymous[kind] + 1
end

function Surface:record(api, kind, version, detail)
    local held = self.rows[api]
    if held == nil then
        table.insert(self.order, api)
    end
    if held == nil or (held.version == nil and version ~= nil) then
        self.rows[api] = {kind = kind, version = version}
        self.details[api] = detail
    end
end

local MEMBER_KINDS = {method = true, property = true, case = true}

function Surface:resolve(kind, accessors)
    local introduced, deprecated, obsoleted = nil, nil, nil
    local unavailable, unavailable_ios = false, false
    for _, found in ipairs(self.target_attrs) do
        if found.introduced and not is_zero(found.introduced) then
            introduced = smaller(introduced, found.introduced)
        end
        if found.deprecated and not is_zero(found.deprecated) then
            deprecated = smaller(deprecated, found.deprecated)
        end
        if found.obsoleted and not is_zero(found.obsoleted) then
            obsoleted = smaller(obsoleted, found.obsoleted)
        end
        unavailable = unavailable or found.unavailable
        unavailable_ios = unavailable_ios or (found.unavailable and found.platform == "ios")
    end
    local via = introduced ~= nil and "own" or "none"
    local container = MEMBER_KINDS[kind] and self.container_detail or nil
    if container ~= nil then
        if introduced == nil then
            introduced = container.introduced
            via = introduced ~= nil and "container" or "none"
        end
        if #self.target_attrs == 0 then
            obsoleted = container.obsoleted
            unavailable = container.unavailable
            unavailable_ios = container.unavailable_ios or false
        end
    end
    local detail = {introduced = introduced, deprecated = deprecated, obsoleted = obsoleted,
                    unavailable = unavailable, unavailable_ios = unavailable_ios, via = via}
    if kind == "property" and accessors then
        for role, name in pairs(accessors) do
            detail[role] = name
        end
    end
    return detail
end

function Surface:finish_target()
    local accessors = self.accessors
    self.accessors = {}
    if self.target == nil then
        return
    end
    local api, kind, versions = self.target.api, self.target.kind, self.target.versions
    local chosen = nil
    for _, version in ipairs(versions) do
        chosen = smaller(chosen, version)
    end
    local detail = self:resolve(kind, accessors)
    if api ~= nil then
        local version = chosen
        if version == nil and MEMBER_KINDS[kind] then
            version = self.container_version
        end
        self:record(api, kind == "case" and "constant" or kind, version, detail)
    end
    if kind == "class" or kind == "protocol" or (self.full and (kind == "category" or kind == "enum")) then
        self.container_version = chosen
        self.container_detail = detail
    end
    self.target = nil
    self.target_attrs = {}
end

function Surface:set_target(api, kind, depth)
    self.target = {api = api, kind = kind, versions = {}}
    self.target_depth = depth
end

function Surface:owned()
    local file = self.file
    if file == nil then
        return false
    end
    if self.owns then
        return self.owns(file) and true or false
    end
    return file:find("/" .. self.framework .. ".framework/", 1, true) ~= nil
        or (not self.full and file:find("/SubFrameworks/", 1, true) ~= nil)
end

function Surface:accessor_line(line)
    if not line:find("etter ObjCMethod 0x", 1, true) then
        return false
    end
    local prefix, role, name = line:match("^([| ]*)[|`]%-(%a+) ObjCMethod 0x[0-9a-f]+ '([^']*)'")
    if prefix == nil or (role ~= "getter" and role ~= "setter") then
        return false
    end
    if self.target ~= nil and self.target.kind == "property" and #prefix // 2 == self.target_depth + 1 then
        self.accessors[role] = name
    end
    return true
end

function Surface:feed_line(line)
    if self:accessor_line(line) then
        return
    end
    local prefix, kind, rest = line:match("^([| ]*)[|`]%-([%w_]+) 0x[0-9a-f]+ ?(.*)$")
    if prefix == nil then
        return
    end
    local depth = #prefix // 2
    if rest:find(":", 1, true) then
        for found in rest:gmatch("(/[^%s:<>,]+%.[%w_]+):%d+:%d+") do
            self.file = found
        end
    end
    local owned = self:owned()
    if kind == "AvailabilityAttr" then
        if self.target ~= nil and depth == self.target_depth + 1 then
            local found = availability_search(rest, ATTRIBUTE_WORDS)
            if found and found.platform == "ios" and not found.unavailable then
                table.insert(self.target.versions, parse_version(found.introduced))
            elseif found and found.platform == "ios" then
                table.insert(self.target.versions, UNAVAILABLE_VERSION)
            end
            local whole = availability_search(rest, AVAILABILITY_WORDS)
            if whole then
                table.insert(self.target_attrs, {introduced = parse_version(whole.introduced),
                                                 deprecated = parse_version(whole.deprecated),
                                                 obsoleted = parse_version(whole.obsoleted),
                                                 unavailable = whole.unavailable,
                                                 platform = (found and found.platform == "ios") and "ios" or nil})
            end
        end
        return
    end
    if kind == "UnavailableAttr" or kind == "DeprecatedAttr" then
        if self.full and self.target ~= nil and depth == self.target_depth + 1 then
            if kind == "UnavailableAttr" then
                table.insert(self.target_attrs, {unavailable = true})
            else
                table.insert(self.target_attrs, {deprecated = DEPRECATED_NO_VERSION, unavailable = false})
            end
        end
        return
    end
    if depth == 0 then
        self:finish_target()
        self.owner = nil
        self.enum_open = false
        if self.full then
            self.container_detail = nil
            self.container_version = nil
        end
        if not owned then
            return
        end
        if kind == "ObjCInterfaceDecl" or kind == "ObjCProtocolDecl" then
            local name = last_word(rest)
            self.owner = name
            self.container_version = nil
            self:set_target(name, kind == "ObjCInterfaceDecl" and "class" or "protocol", 0)
        elseif kind == "ObjCCategoryDecl" then
            self.owner = nil
            self.pending_category = true
            self.container_version = nil
            self:set_target(nil, "category", 0)
        elseif self.full and kind == "EnumDecl" then
            local name = last_word(before_quote(rest))
            self.enum_open = true
            self.container_version = nil
            if anonymous_name(name) then
                self:set_target(nil, "enum", 0)
                self:count_anonymous("enum")
            else
                self:set_target(name, "enum", 0)
            end
        elseif self.full and kind == "RecordDecl" and rest:find(" definition", 1, true) and rest:find(" struct ", 1, true) then
            local name = last_word(rest:sub(1, rest:find(" definition", 1, true) - 1))
            if name == "struct" or anonymous_name(name) then
                self:set_target(nil, "struct", 0)
                self:count_anonymous("struct")
            else
                self:set_target(name, "struct", 0)
            end
        elseif kind == "VarDecl" and rest:find(" extern", 1, true) then
            self:set_target(last_word(before_quote(rest)), "constant", 0)
        elseif kind == "FunctionDecl" then
            local static = rest:find(" static", 1, true) ~= nil
            local inline = rest:find(" inline", 1, true) ~= nil
            local wanted
            if self.full then
                wanted = not static or inline
            else
                wanted = not static and not inline
            end
            if wanted then
                self:set_target(last_word(before_quote(rest)) .. "()", "function", 0)
            end
        end
        return
    end
    if depth == 1 and kind == "ObjCInterface" and self.pending_category and self.target and self.target.kind == "category" then
        self.owner = second_quoted(rest)
        self.pending_category = false
        return
    end
    if self.full and depth == 1 and kind == "EnumConstantDecl" and self.enum_open and owned then
        self:finish_target()
        self:set_target(last_word(before_quote(rest)), "case", 1)
        return
    end
    if depth == 1 and (kind == "ObjCMethodDecl" or kind == "ObjCPropertyDecl") and self.owner and owned then
        self:finish_target()
        if kind == "ObjCMethodDecl" and before_quote(rest):find(" implicit ", 1, true) then
            self.target = nil
            return
        end
        if kind == "ObjCMethodDecl" then
            local sign, name = member_name(kind, rest)
            self:set_target(string.format("%s[%s %s]", sign, self.owner, name), "method", 1)
        else
            local _, name = member_name(kind, rest)
            self:set_target(self.owner .. "." .. name, "property", 1)
        end
    end
end

function Surface:feed(lines)
    if type(lines) == "function" then
        for line in lines do
            self:feed_line(line)
        end
    else
        for _, line in ipairs(lines) do
            self:feed_line(line)
        end
    end
    self:finish_target()
end

function newest_macos_sdk()
    local found = {}
    for _, folder in ipairs(os.filedirs("/Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk")) do
        local numbers = {}
        for number in path.filename(folder):gmatch("%d+") do
            table.insert(numbers, tonumber(number))
        end
        table.insert(found, {folder = folder, numbers = numbers})
    end
    if #found == 0 then
        raise("no macOS SDK found; pass --sdk")
    end
    table.sort(found, function (a, b)
        local order = compare(a.numbers, b.numbers)
        if order ~= 0 then
            return order < 0
        end
        return byteorder.less(a.folder, b.folder)
    end)
    return found[#found].folder
end

function cryptex_frameworks(sdk)
    local folder = path.join(sdk, "System", "Cryptexes", "OS", "System", "Library", "Frameworks")
    return os.isdir(folder) and folder or nil
end

function subframeworks(sdk)
    local folder = path.join(sdk, "System", "Library", "SubFrameworks")
    return os.isdir(folder) and folder or nil
end

local function macabi(target)
    return target:sub(-#"macabi") == "macabi"
end

function framework_bases(sdk, target, full)
    local bases = {}
    if macabi(target) then
        table.insert(bases, path.join(sdk, "System", "iOSSupport", "System", "Library", "Frameworks"))
    end
    table.insert(bases, path.join(sdk, "System", "Library", "Frameworks"))
    if cryptex_frameworks(sdk) then
        table.insert(bases, cryptex_frameworks(sdk))
    end
    if full and subframeworks(sdk) then
        table.insert(bases, subframeworks(sdk))
    end
    return bases
end

function framework_headers_dir(sdk, framework, target, full)
    for _, base in ipairs(framework_bases(sdk, target, full)) do
        local bundle = path.join(base, framework .. ".framework")
        for _, headers in ipairs({path.join(bundle, "Headers"), path.join(bundle, "Versions", "A", "Headers")}) do
            if os.isdir(headers) then
                return headers
            end
        end
    end
    return nil
end

function header_files(folder)
    local names = {}
    for _, entry in ipairs(os.filedirs(path.join(folder, "*.h"))) do
        table.insert(names, path.filename(entry))
    end
    byteorder.sort(names)
    return names
end

function sdk_version(sdk)
    local settings = json.decode(io.readfile(path.join(sdk, "SDKSettings.json")))
    return settings.Version
end

function clang_command(sdk, target, full, vfs)
    local command = {"xcrun", "clang", "-x", "objective-c", "-target", target, "-isysroot", sdk, "-w", "-fsyntax-only", "-Xclang", "-ast-dump"}
    if macabi(target) then
        table.join2(command, {"-iframework", path.join(sdk, "System", "iOSSupport", "System", "Library", "Frameworks")})
    end
    if cryptex_frameworks(sdk) then
        table.join2(command, {"-iframework", cryptex_frameworks(sdk)})
    end
    if full and subframeworks(sdk) then
        table.join2(command, {"-iframework", subframeworks(sdk)})
    end
    if vfs then
        table.join2(command, {"-ivfsoverlay", vfs, "-Wno-incompatible-sysroot"})
    end
    return command
end

function cleanup()
    for folder in pairs(open_dumps) do
        os.tryrm(folder)
    end
    open_dumps = {}
end

function dump_headers(command, text)
    local folder = workspace.fresh("surface-walk")
    open_dumps[folder] = true
    local stem = path.join(folder, "dump")
    local source = stem .. ".m"
    local stdout_file, stderr_file = stem .. ".out", stem .. ".err"
    io.writefile(source, text)
    local arguments = {}
    for index = 2, #command do
        table.insert(arguments, command[index])
    end
    table.insert(arguments, source)
    local status = os.execv(command[1], arguments, {stdout = stdout_file, stderr = stderr_file, try = true})
    os.tryrm(source)
    local stderr = os.isfile(stderr_file) and io.readfile(stderr_file) or ""
    os.tryrm(stderr_file)
    return {folder = folder, stdout_file = stdout_file, stderr = stderr, status = status,
            size = os.isfile(stdout_file) and os.filesize(stdout_file) or 0}
end

function dump_lines(dump)
    return io.lines(dump.stdout_file)
end

function discard(dump)
    os.tryrm(dump.folder)
    open_dumps[dump.folder] = nil
end

local function feed_dump(surface, dump)
    surface:feed(dump_lines(dump))
    discard(dump)
end

function declared(sdk, framework, target)
    return declared_surface(sdk, framework, target).rows
end

function declared_surface(sdk, framework, target, full, failed)
    if full then
        return declared_surface_full(sdk, framework, target, failed)
    end
    local command = clang_command(sdk, target)
    local dump = dump_headers(command, string.format("#import <%s/%s.h>\n", framework, framework))
    if dump.size == 0 then
        discard(dump)
        raise("clang produced no AST for %s: %s", framework, dump.stderr:sub(1, 400))
    end
    if dump.status ~= 0 then
        discard(dump)
        local headers_dir = framework_headers_dir(sdk, framework, target)
        local headers = headers_dir and header_files(headers_dir) or {}
        if #headers == 0 then
            raise("clang failed to import %s/%s.h for target %s (returncode %d), and no fallback headers found (Headers/ dir: %s) -- %s",
                  framework, framework, target, dump.status, headers_dir or "None", dump.stderr:sub(1, 400))
        end
        local imports = {}
        for _, header in ipairs(headers) do
            table.insert(imports, string.format("#import <%s/%s>\n", framework, header))
        end
        dump = dump_headers(command, table.concat(imports))
        if dump.size == 0 then
            discard(dump)
            raise("clang produced no AST for %s even importing its %d individual headers: %s", framework, #headers, dump.stderr:sub(1, 400))
        end
        if dump.status ~= 0 then
            discard(dump)
            raise("clang still failed for %s after falling back to its %d individual headers (returncode %d): %s",
                  framework, #headers, dump.status, dump.stderr:sub(1, 400))
        end
    end
    local surface = new(framework)
    feed_dump(surface, dump)
    return surface
end

function declared_surface_full(sdk, framework, target, failed, vfs)
    local headers_dir = framework_headers_dir(sdk, framework, target, true)
    local headers = headers_dir and header_files(headers_dir) or {}
    local surface = new(framework, {full = true})
    local umbrella = framework .. ".h"
    local imports = {}
    for _, header in ipairs(headers) do
        if header == umbrella then
            table.insert(imports, 1, framework .. "/" .. header)
        end
    end
    for _, header in ipairs(headers) do
        if header ~= umbrella then
            table.insert(imports, framework .. "/" .. header)
        end
    end
    walk_imports(surface, clang_command(sdk, target, true, vfs), imports, failed)
    return surface
end

local function strip_text(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_lines(text)
    local lines = {}
    if text == "" then
        return lines
    end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, (line:gsub("\r$", "")))
    end
    return lines
end

function walk_imports(surface, command, imports, failed)
    if #imports == 0 then
        return
    end
    local text = {}
    for _, header in ipairs(imports) do
        table.insert(text, string.format("#import <%s>\n", header))
    end
    local dump = dump_headers(command, table.concat(text))
    if dump.status == 0 and dump.size > 0 then
        feed_dump(surface, dump)
        return
    end
    discard(dump)
    for _, header in ipairs(imports) do
        local single = dump_headers(command, string.format("#import <%s>\n", header))
        if single.status ~= 0 or single.size == 0 then
            discard(single)
            if failed ~= nil then
                local lines = split_lines(strip_text(single.stderr))
                local errors = {}
                for _, line in ipairs(lines) do
                    if line:find("error:", 1, true) then
                        table.insert(errors, line)
                    end
                end
                local first = errors[1] or lines[1] or "no output"
                table.insert(failed, string.format("%s: %s", header, (first:gsub("/%S-%.sdk/", "")):sub(1, 200)))
            end
        else
            feed_dump(surface, single)
            surface.file = nil
        end
    end
end

local function walk_tree(root, relative, found)
    local folder = relative == "." and root or path.join(root, relative)
    for _, entry in ipairs(os.filedirs(path.join(folder, "*"))) do
        local name = path.filename(entry)
        local child = relative == "." and name or relative .. "/" .. name
        if os.isdir(entry) then
            if not os.islink(entry) then
                table.insert(found.directories, child)
            end
        else
            table.insert(found.files, {relative = relative, name = name})
        end
    end
end

function include_libraries(sdk)
    local root = path.join(sdk, "usr", "include")
    local libraries, names = {}, {}
    local pending = {"."}
    while #pending > 0 do
        local relative = table.remove(pending, 1)
        local top = relative:match("^([^/]+)")
        if not INCLUDE_SKIPPED[top] then
            local found = {directories = {}, files = {}}
            walk_tree(root, relative, found)
            local name = relative == "." and INCLUDE_TOP or INCLUDE_TOP .. "/" .. top
            for _, file in ipairs(found.files) do
                if file.name:sub(-2) == ".h" then
                    if libraries[name] == nil then
                        libraries[name] = {}
                        table.insert(names, name)
                    end
                    table.insert(libraries[name], relative == "." and file.name or relative .. "/" .. file.name)
                end
            end
            table.join2(pending, found.directories)
        end
    end
    byteorder.sort(names)
    local ordered = {}
    for _, name in ipairs(names) do
        local headers = libraries[name]
        byteorder.sort(headers)
        local stem = name:match("^[^/]+/(.*)$") or name
        local umbrella = stem .. "/" .. stem .. ".h"
        if name ~= INCLUDE_TOP then
            for index, header in ipairs(headers) do
                if header == umbrella then
                    table.remove(headers, index)
                    table.insert(headers, 1, umbrella)
                    break
                end
            end
        end
        table.insert(ordered, {name = name, headers = headers})
    end
    return ordered
end

function library_surface(sdk, library, headers, target, failed, vfs)
    local owns
    if library == INCLUDE_TOP then
        owns = function (file)
            return file:find("/usr/include/[^/]+$") ~= nil
        end
    else
        local marker = "/usr/include/" .. library:match("^[^/]+/(.*)$") .. "/"
        owns = function (file)
            return file:find(marker, 1, true) ~= nil
        end
    end
    local surface = new(library, {full = true, owns = owns})
    walk_imports(surface, clang_command(sdk, target, true, vfs), headers, failed)
    return surface
end

local function present(value)
    return value ~= nil and value ~= json.null
end

function registry_files(root, framework)
    local files = os.files(path.join(root, framework, "*.json"))
    byteorder.sort(files)
    local flat = path.join(root, framework .. ".json")
    if os.isfile(flat) then
        table.insert(files, flat)
    end
    return files
end

function registry_names(root, framework)
    local names, told = {}, {}
    for _, file in ipairs(registry_files(root, framework)) do
        local data = json.decode(io.readfile(file))
        local entries = present(data.entries) and data.entries or data
        for _, entry in ipairs(entries) do
            if told[entry.api] then
                raise("%s is named by both %s and %s", entry.api, told[entry.api], file)
            end
            told[entry.api] = file
            local introduced = present(entry.introduced) and entry.introduced ~= "" and parse_version(entry.introduced) or nil
            names[entry.api] = {status = present(entry.status) and entry.status or "", introduced = introduced}
        end
    end
    return names
end

local Release = {}

function release_from(file, name)
    if not os.isfile(file) then
        raise("no class inventory of iOS %s at %s", name or file, file)
    end
    return with_methods({classes = json.decode(io.readfile(file)).classes}, Release)
end

function release(name)
    return release_from(path.join(os.getenv("HOME"), ".revenant", "dyld", name, "classes_armv7.json"), name)
end

local function add_all(set, list)
    if present(list) then
        for _, item in ipairs(list) do
            set[item] = true
        end
    end
end

function Release:selectors()
    if self._selectors == nil then
        local found = {}
        for _, entry in pairs(self.classes) do
            add_all(found, entry.instance)
            add_all(found, entry.class)
        end
        self._selectors = found
    end
    return self._selectors
end

function Release:protocols()
    if self._protocols == nil then
        local found = {}
        for _, entry in pairs(self.classes) do
            add_all(found, entry.protocols)
        end
        self._protocols = found
    end
    return self._protocols
end

local function property_name(api)
    local dot = api:find(".", 1, true)
    if dot == nil then
        raise("surface_walk: the property %s has no owner", api)
    end
    return api:sub(1, dot - 1), api:sub(dot + 1)
end

function Release:knows_selector(api, kind)
    local selector = api:match("^[-+]%[[%w_]+ (.+)%]$")
    if selector then
        return self:selectors()[selector] == true
    end
    if kind == "property" then
        local _, name = property_name(api)
        return self:selectors()[name] == true
    end
    return false
end

function Release:has(api, kind)
    if kind == "class" then
        return self.classes[api] ~= nil
    end
    local sign, owner, selector = api:match("^([-+])%[([%w_]+) (.+)%]$")
    if sign then
        return self:answers(owner, sign == "-" and "instance" or "class", selector)
    elseif kind == "property" then
        local owner_name, name = property_name(api)
        return self:answers(owner_name, "instance", name)
    end
    return false
end

function Release:answers(owner, side, selector)
    local seen = {}
    while present(owner) and self.classes[owner] ~= nil and not seen[owner] do
        seen[owner] = true
        local entry = self.classes[owner]
        if present(entry[side]) then
            for _, item in ipairs(entry[side]) do
                if item == selector then
                    return true
                end
            end
        end
        owner = entry.superclass
    end
    return false
end

function setter_of(name)
    return "set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"
end

function covered(api, kind, version, registry)
    if registry[api] then
        return true
    end
    local owner = api:match("^[-+]%[([%w_]+) ")
    if owner == nil and kind == "property" then
        owner = api:match("^([^.]*)")
    end
    if kind == "property" then
        local _, name = property_name(api)
        for _, candidate in ipairs({string.format("-[%s %s]", owner, name), string.format("-[%s %s]", owner, setter_of(name))}) do
            if registry[candidate] then
                return true
            end
        end
    end
    local entry = owner and registry[owner]
    if entry and (entry.status == "absent" or entry.status == "ignored") then
        return true
    end
    if entry and entry.status == "implemented" and entry.introduced and version and compare(version, entry.introduced) <= 0 then
        return true
    end
    return false
end
