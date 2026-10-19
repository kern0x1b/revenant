local GENERATED = "# Written by Charon from charon.toml. Edits here are lost on the next build."
local CMAKE_MINIMUM = "3.24"
local PORT = "${CHARON_PORT}"
local REQUIRES_PORT = 'if (NOT CHARON_PORT)\n'
    .. '    message(FATAL_ERROR\n'
    .. '        "CHARON_PORT names the folder charon.toml lives in, and every path below is written '
    .. 'against it; the build passes it")\n'
    .. 'endif ()'
local LANGUAGES = {[".c"] = "C", [".m"] = "OBJC", [".mm"] = "OBJCXX", [".cpp"] = "CXX", [".cc"] = "CXX",
                   [".swift"] = "Swift"}
local PROJECT_LANGUAGE_ORDER = {"C", "CXX", "OBJC", "OBJCXX", "Swift"}
local LANGUAGE_KEYS = {c = "C", cxx = "CXX", objc = "OBJC", objcxx = "OBJCXX"}
local LANGUAGE_KEY_ORDER = {"c", "cxx", "objc", "objcxx"}
local PROJECT_INCLUDE = "project-include.cmake"
local CROSS_TOOLCHAIN = "cross-toolchain.cmake"

local S = nil

function generate_bind(folder)
    S = import("spec", {rootdir = folder, anonymous = true})
    S.spec_bind(folder)
end

function generate_spec()
    return S
end

local function toml()
    return S.spec_toml()
end

local function truthy(value)
    if value == nil or value == false or value == "" or value == 0 then
        return false
    end
    if type(value) == "table" then
        for _ in pairs(value) do
            return true
        end
        return false
    end
    return true
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function unique_append(list, value)
    if not contains(list, value) then
        table.insert(list, value)
    end
end

local function is_map(value)
    return type(value) == "table" and toml().is_table(value)
end

local function is_list(value)
    return type(value) == "table" and toml().is_array(value)
end

local function quoted(value)
    return '"' .. tostring(value) .. '"'
end

local function port_path(value)
    local text = tostring(value)
    local first = text:sub(1, 1)
    if first == "/" or first == "$" or first == "-" then
        return text
    end
    return PORT .. "/" .. text
end

local function ordered_languages(found)
    local out = {}
    for _, language in ipairs(PROJECT_LANGUAGE_ORDER) do
        if contains(found, language) then
            table.insert(out, language)
        end
    end
    return out
end

local function has_pattern(text)
    return text:find("[%*%?%[]") ~= nil
end

local function manifest_of(declared)
    return path.join(declared.root, "charon.toml")
end

local function languages_of(sources)
    local found = {}
    for _, pattern in ipairs(sources) do
        local dot = nil
        for index = #pattern, 1, -1 do
            if pattern:sub(index, index) == "." then
                dot = index
                break
            end
        end
        local suffix = dot and pattern:sub(dot) or ""
        local language = LANGUAGES[suffix]
        if language == nil then
            raise("%s is a source Charon cannot name a language for", pattern)
        end
        unique_append(found, language)
    end
    return ordered_languages(found)
end

local function segment_matches(glob, name)
    local lua = {"^"}
    local index = 1
    while index <= #glob do
        local c = glob:sub(index, index)
        if c == "*" then
            table.insert(lua, ".*")
        elseif c == "?" then
            table.insert(lua, ".")
        elseif c == "[" then
            local close = glob:find("]", index + 1, true)
            if close == nil then
                table.insert(lua, "%[")
            else
                table.insert(lua, glob:sub(index, close))
                index = close
            end
        elseif c:match("[%^%$%(%)%%%.%]%+%-]") then
            table.insert(lua, "%" .. c)
        else
            table.insert(lua, c)
        end
        index = index + 1
    end
    table.insert(lua, "$")
    return name:match(table.concat(lua)) ~= nil
end

local function parts_match(globs, glob_at, parts, part_at)
    if glob_at > #globs then
        return part_at > #parts
    end
    local glob = globs[glob_at]
    if glob == "**" then
        for skip = part_at, #parts + 1 do
            if parts_match(globs, glob_at + 1, parts, skip) then
                return true
            end
        end
        return false
    end
    if part_at > #parts or not segment_matches(glob, parts[part_at]) then
        return false
    end
    return parts_match(globs, glob_at + 1, parts, part_at + 1)
end

local function split(text, separator)
    local out = {}
    for piece in text:gmatch("[^" .. separator .. "]+") do
        table.insert(out, piece)
    end
    return out
end

local function glob_matches(pattern, relative)
    return parts_match(split(pattern, "/"), 1, split(relative, "/"), 1)
end

local function relative_under(root, found)
    return path.relative(found, root):gsub("\\", "/")
end

local function files_matching(root, pattern, name)
    if root == nil then
        raise("%s names %s as a pattern, which needs the port folder to expand", name, pattern)
    end
    local found = {}
    for _, file in ipairs(os.files(path.join(root, "**"))) do
        local relative = relative_under(root, file)
        if glob_matches(pattern, relative) then
            table.insert(found, relative)
        end
    end
    table.sort(found)
    return found
end

local function folders_matching(root, pattern, name)
    if root == nil then
        raise("%s names %s as a pattern, which needs the port folder to expand", name, pattern)
    end
    local found = {}
    for _, folder in ipairs(os.dirs(path.join(root, "**"))) do
        local relative = relative_under(root, folder)
        if glob_matches(pattern, relative) then
            table.insert(found, relative)
        end
    end
    table.sort(found)
    return found
end

local function sources_of(target, root)
    local name = target.name
    local sources = target.sources
    if not truthy(sources) then
        raise("%s declares no sources and no cmake= to use instead", name)
    end
    local excluded = {}
    for _, pattern in ipairs(target.exclude or {}) do
        for _, file in ipairs(files_matching(root, pattern, name)) do
            unique_append(excluded, file)
        end
    end
    local expanded = {}
    for _, entry in ipairs(sources) do
        local found = {entry}
        if has_pattern(entry) then
            found = files_matching(root, entry, name)
            if #found == 0 then
                raise("%s: %s matches no file under %s", name, entry, tostring(root))
            end
        end
        local kept = {}
        for _, file in ipairs(found) do
            if not contains(excluded, file) and not contains(expanded, file) then
                table.insert(kept, file)
            end
        end
        for _, file in ipairs(kept) do
            table.insert(expanded, file)
        end
    end
    if #expanded == 0 then
        raise("%s declares sources and exclude takes every one of them", name)
    end
    return expanded
end

local function folders_of(target, key, root)
    local name = target.name
    local excluded = {}
    for _, pattern in ipairs(target[key .. "-exclude"] or {}) do
        for _, folder in ipairs(folders_matching(root, pattern, name)) do
            unique_append(excluded, folder)
        end
    end
    local expanded = {}
    for _, entry in ipairs(target[key] or {}) do
        local text = tostring(entry)
        local first = text:sub(1, 1)
        local found = {text}
        if first == "/" or first == "$" or first == "-" then
            found = {text}
        elseif has_pattern(text) then
            found = folders_matching(root, text, name)
            if #found == 0 then
                raise("%s: %s matches no folder under %s", name, text, tostring(root))
            end
        else
            if root ~= nil and not os.isdir(path.join(root, text)) then
                raise("%s names %s under %s, and there is no such folder; the compiler would drop it without a word",
                      name, text, key)
            end
            local stripped = text:gsub("/+$", "")
            found = {stripped}
        end
        for _, folder in ipairs(found) do
            if not contains(excluded, folder) and not contains(expanded, folder) then
                table.insert(expanded, folder)
            end
        end
    end
    return expanded
end

local function per_language(target, key, compiled)
    local table_value = target[key] or {}
    if not is_map(table_value) then
        raise("%s declares %s as %s; it is a table keyed by %s", target.name, key, tostring(table_value),
              table.concat(LANGUAGE_KEY_ORDER, ", "))
    end
    local entries = {}
    for _, language in ipairs(toml().keys(table_value)) do
        local values = table_value[language]
        local cmake = LANGUAGE_KEYS[language]
        if cmake == nil then
            raise("%s declares %s for %s, which is not one of %s", target.name, key, language,
                  table.concat(LANGUAGE_KEY_ORDER, ", "))
        end
        if truthy(values) and not contains(compiled, cmake) then
            raise("%s declares %s for %s, and none of its sources is %s; the values would apply to nothing",
                  target.name, key, language, language)
        end
        for _, value in ipairs(values) do
            table.insert(entries, {cmake, tostring(value)})
        end
    end
    return entries
end

local function for_language(language, value, shell)
    local body = value
    if shell and value:find(" ", 1, true) then
        body = "SHELL:" .. value
    end
    return '"$<$<COMPILE_LANGUAGE:' .. language .. '>:' .. body .. '>"'
end

local function options_of(target, key, prefix)
    local out = {}
    for _, value in ipairs(target[key] or {}) do
        table.insert(out, (prefix or "") .. tostring(value))
    end
    return out
end

local function source_properties(target)
    local lines = {}
    for _, source in ipairs(toml().keys(target["source-include"] or {})) do
        local folders = target["source-include"][source]
        local wanted = is_list(folders) and folders or {folders}
        local listed = {}
        for _, folder in ipairs(wanted) do
            table.insert(listed, port_path(folder))
        end
        table.insert(lines, string.format('set_source_files_properties(%s PROPERTIES INCLUDE_DIRECTORIES "%s")',
                                          port_path(source), table.concat(listed, ";")))
    end
    return lines
end

local function map_values(list, fn)
    local out = {}
    for _, item in ipairs(list) do
        table.insert(out, fn(item))
    end
    return out
end

local function library_block(target, kind, root)
    local name = target.name
    local declared_sources = sources_of(target, root)
    local sources = map_values(declared_sources, port_path)
    local compiled = languages_of(declared_sources)
    local lines = {}
    if kind == "application" or kind == "executable" then
        table.insert(lines, "add_executable(" .. name)
    else
        table.insert(lines, "add_library(" .. name .. " " .. (kind == "static-library" and "STATIC" or "SHARED"))
    end
    table.insert(lines, "    " .. table.concat(sources, "\n    ") .. ")")

    local properties = {}
    if kind == "device-library" then
        table.insert(properties, 'PREFIX ""')
    end
    if (kind == "device-library" or kind == "executable") and not truthy(target.install) then
        raise("%s declares no install path, and a %s has to say where it belongs on the device", name, kind)
    end
    if kind == "device-library" then
        table.insert(properties, "INSTALL_NAME_DIR " .. target.install)
        table.insert(properties, "BUILD_WITH_INSTALL_NAME_DIR ON")
    end
    if target.suffix ~= nil then
        table.insert(properties, "SUFFIX " .. quoted(target.suffix))
    end
    if target.standard ~= nil then
        table.insert(properties, "CXX_STANDARD " .. tostring(target.standard))
        table.insert(properties, "CXX_STANDARD_REQUIRED ON")
        table.insert(properties, "CXX_EXTENSIONS OFF")
    end
    if #properties > 0 then
        table.insert(lines, "set_target_properties(" .. name .. " PROPERTIES " .. table.concat(properties, " ") .. ")")
    end

    local includes = {
        {"include", "target_include_directories(" .. name .. " PRIVATE"},
        {"include-system", "target_include_directories(" .. name .. " SYSTEM PRIVATE"},
    }
    for _, entry in ipairs(includes) do
        local folders = folders_of(target, entry[1], root)
        if #folders > 0 then
            table.insert(lines, entry[2] .. "\n    " .. table.concat(map_values(folders, port_path), "\n    ") .. ")")
        end
    end
    local system_for = per_language(target, "include-system-for", compiled)
    if #system_for > 0 then
        local listed = map_values(system_for, function (pair)
            return for_language(pair[1], port_path(pair[2]), false)
        end)
        table.insert(lines, "target_include_directories(" .. name .. " SYSTEM PRIVATE\n    "
                     .. table.concat(listed, "\n    ") .. ")")
    end

    for _, line in ipairs(source_properties(target)) do
        table.insert(lines, line)
    end

    local options = options_of(target, "options")
    if #options > 0 then
        table.insert(lines, "target_compile_options(" .. name .. " PRIVATE\n    " .. table.concat(options, "\n    ") .. ")")
    end
    local options_for = per_language(target, "options-for", compiled)
    if #options_for > 0 then
        local listed = map_values(options_for, function (pair)
            return for_language(pair[1], pair[2], true)
        end)
        table.insert(lines, "target_compile_options(" .. name .. " PRIVATE\n    " .. table.concat(listed, "\n    ") .. ")")
    end
    local definitions = options_of(target, "definitions")
    if #definitions > 0 then
        table.insert(lines, "target_compile_definitions(" .. name .. " PRIVATE\n    "
                     .. table.concat(definitions, "\n    ") .. ")")
    end
    local definitions_for = per_language(target, "definitions-for", compiled)
    if #definitions_for > 0 then
        local listed = map_values(definitions_for, function (pair)
            return for_language(pair[1], pair[2], false)
        end)
        table.insert(lines, "target_compile_definitions(" .. name .. " PRIVATE\n    " .. table.concat(listed, "\n    ") .. ")")
    end
    local link_options = options_of(target, "link-options")
    if #link_options > 0 then
        table.insert(lines, "target_link_options(" .. name .. " PRIVATE\n    " .. table.concat(link_options, "\n    ") .. ")")
    end

    local linked = {}
    for _, framework in ipairs(target.frameworks or {}) do
        table.insert(linked, quoted("-framework " .. tostring(framework)))
    end
    for _, library in ipairs(target.libraries or {}) do
        table.insert(linked, tostring(library))
    end
    if #linked > 0 then
        table.insert(lines, "target_link_libraries(" .. name .. " PRIVATE\n    " .. table.concat(linked, "\n    ") .. ")")
    end
    return lines
end

local function resource_lines(target, destination)
    local lines = {}
    local files = {}
    for _, resource in ipairs(target.resources or {}) do
        if type(resource) == "string" then
            table.insert(files, port_path(resource))
        end
    end
    if #files > 0 then
        table.insert(lines, "install(FILES " .. table.concat(files, " ") .. " DESTINATION " .. destination .. ")")
    end
    for _, resource in ipairs(target.resources or {}) do
        if type(resource) ~= "string" then
            if not is_map(resource) or not truthy(resource["from"]) or not truthy(resource["as"]) then
                raise("%s declares the resource %s. A resource is a path, or a table with from and as; anything else "
                      .. "would be left out of the build without a word", target.name, tostring(resource))
            end
            local source = port_path(resource["from"])
            local renamed = resource["as"]
            if tostring(resource["from"]):sub(-1) == "/" then
                local into = renamed == "." and destination or renamed:gsub("^/+", "")
                table.insert(lines, "install(DIRECTORY " .. source .. " DESTINATION " .. into .. ")")
            elseif renamed:sub(1, 1) == "/" then
                local folder, file = renamed:match("^(.*)/([^/]*)$")
                local where = folder:gsub("^/+", "")
                if where == "" then
                    where = "."
                end
                table.insert(lines, "install(FILES " .. source .. " DESTINATION " .. where .. " RENAME " .. file .. ")")
            else
                table.insert(lines, "install(FILES " .. source .. " DESTINATION " .. destination .. " RENAME " .. renamed .. ")")
            end
        end
    end
    return lines
end

local function install_block(target, kind)
    local name = target.name
    if kind == "static-library" then
        return {}
    end
    if kind == "application" then
        local lines = {"install(TARGETS " .. name .. " RUNTIME DESTINATION .)"}
        for _, line in ipairs(resource_lines(target, ".")) do
            table.insert(lines, line)
        end
        return lines
    end
    local install = tostring(target.install):gsub("^/+", "")
    local destination = kind == "executable" and "RUNTIME" or "LIBRARY"
    local lines = {"install(TARGETS " .. name .. " " .. destination .. " DESTINATION " .. install .. ")"}
    for _, line in ipairs(resource_lines(target, install)) do
        table.insert(lines, line)
    end
    return lines
end

function generate_cmake_project(declared, kind, project)
    local targets = {}
    for _, target in ipairs(S.decl_targets(declared, kind)) do
        if S.decl_generates(target) then
            table.insert(targets, target)
        end
    end
    if #targets == 0 then
        return nil
    end
    local used = {}
    for _, target in ipairs(targets) do
        for _, language in ipairs(languages_of(sources_of(target, declared.root))) do
            unique_append(used, language)
        end
    end
    local languages = ordered_languages(used)

    local lines = {GENERATED, "cmake_minimum_required(VERSION " .. CMAKE_MINIMUM .. ")",
                   "project(" .. project .. " " .. table.concat(languages, " ") .. ")", "", REQUIRES_PORT, ""}
    local wanted = {}
    for _, target in ipairs(targets) do
        for _, cache_name in ipairs(toml().keys(target.cache or {})) do
            unique_append(wanted, cache_name)
        end
    end
    if #wanted > 0 then
        for _, line in ipairs({
            "foreach (variable " .. table.concat(wanted, " ") .. ")",
            "    if (NOT ${variable})",
            '        message(FATAL_ERROR "${variable} is named by the declaration and answered from the '
                .. 'dependency graph; configure through charon build")',
            "    endif ()",
            "endforeach ()",
            "",
        }) do
            table.insert(lines, line)
        end
    end

    local packages = {}
    for _, target in ipairs(targets) do
        for _, package in ipairs(target.packages or {}) do
            unique_append(packages, package)
        end
    end
    if #packages > 0 then
        for _, line in ipairs({
            "if (NOT CHARON_PACKAGES)",
            '    message(FATAL_ERROR "CHARON_PACKAGES names the file that finds ' .. table.concat(packages, ", ")
                .. ' under the names the dependency graph gives them; configure through charon build")',
            "endif ()",
            'include("${CHARON_PACKAGES}")',
        }) do
            table.insert(lines, line)
        end
    end
    if lines[#lines] ~= "" then
        table.insert(lines, "")
    end
    for _, target in ipairs(targets) do
        for _, line in ipairs(library_block(target, kind, declared.root)) do
            table.insert(lines, line)
        end
        table.insert(lines, "")
    end
    for _, target in ipairs(targets) do
        for _, line in ipairs(install_block(target, kind)) do
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n"):gsub("\n+$", "") .. "\n"
end

local function format_template(text, values)
    local out = {}
    local index = 1
    while index <= #text do
        local c = text:sub(index, index)
        if c == "{" and text:sub(index + 1, index + 1) == "{" then
            table.insert(out, "{")
            index = index + 2
        elseif c == "}" and text:sub(index + 1, index + 1) == "}" then
            table.insert(out, "}")
            index = index + 2
        elseif c == "{" then
            local close = text:find("}", index, true)
            local name = close and text:sub(index + 1, close - 1)
            if name == nil or values[name] == nil then
                raise("the cross toolchain template names %s, which Charon does not supply", name or text:sub(index))
            end
            table.insert(out, tostring(values[name]))
            index = close + 1
        elseif c == "}" then
            raise("the cross toolchain template has a single } that closes nothing")
        else
            table.insert(out, c)
            index = index + 1
        end
    end
    return table.concat(out)
end

function generate_cross_toolchain(declared)
    local target = S.decl_section(declared, "target")
    local platform = S.decl_platform(declared)
    if platform == nil or not truthy(platform["cross-toolchain"]) then
        raise("%s declares no [platform] with a cross toolchain, and the compiler cannot be pointed at a target "
              .. "without one", manifest_of(declared))
    end
    local defines = {}
    for _, define in ipairs(target.defines or {}) do
        table.insert(defines, " " .. tostring(define))
    end
    local text = io.readfile(platform["cross-toolchain"])
    return format_template(text, {
        generated = GENERATED,
        system = target["system-name"] or "Darwin",
        processor = target["system-processor"] or "${CHARON_ARCHITECTURE}",
        defines = table.concat(defines),
    })
end

function generate_project_include(declared)
    local packages = S.decl_get(declared, "engine", "config-packages", {})
    if #packages == 0 then
        return nil
    end
    local lines = {GENERATED}
    for _, package in ipairs(packages) do
        table.insert(lines, "find_package(" .. tostring(package) .. " REQUIRED CONFIG)")
    end
    return table.concat(lines, "\n") .. "\n"
end

function generate_written(declared, required)
    if required == nil then
        required = true
    end
    local produced = {}
    local applied = generate_project_include(declared)
    if applied ~= nil then
        produced[PROJECT_INCLUDE] = applied
    end
    if S.decl_using(declared, "toolchain") == nil and S.decl_get(declared, "engine", "user-toolchain") == nil then
        produced[CROSS_TOOLCHAIN] = generate_cross_toolchain(declared)
    end
    for _, spec in ipairs({
        {"static-library", "port-static"},
        {"device-library", "port-device"},
        {"executable", "port-executable"},
        {"application", "port-application"},
    }) do
        local text = generate_cmake_project(declared, spec[1], spec[2])
        if text ~= nil then
            produced[spec[1] .. "/CMakeLists.txt"] = text
        end
    end
    if required and next_key(produced) == nil then
        raise("%s declares nothing Charon can generate", manifest_of(declared))
    end
    return produced
end

function next_key(map)
    for key in pairs(map) do
        return key
    end
    return nil
end
