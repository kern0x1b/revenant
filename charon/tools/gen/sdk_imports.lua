local sdk_info = import("sdk", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})

local CLANG = "/usr/bin/clang"

local closure_memo = {}

local function segments_of(path_text)
    local out = {}
    for segment in string.gmatch(path_text, "[^/]+") do
        table.insert(out, segment)
    end
    return out
end

local function owner_of(sdk, file)
    local prefix = sdk .. "/"
    if string.sub(file, 1, #prefix) ~= prefix then
        return nil
    end
    local seg = segments_of(string.sub(file, #prefix + 1))
    local frameworks = seg[1] == "System" and seg[2] == "Library" and (seg[3] == "Frameworks" or seg[3] == "SubFrameworks")
    local developer = seg[1] == "Developer" and seg[2] == "Library" and seg[3] == "Frameworks"
    if frameworks or developer then
        local names = {}
        local i = 4
        while seg[i] ~= nil and string.sub(seg[i], -10) == ".framework" do
            table.insert(names, string.sub(seg[i], 1, -11))
            if seg[i + 1] == "Frameworks" and seg[i + 2] ~= nil and string.sub(seg[i + 2], -10) == ".framework" then
                i = i + 2
            else
                break
            end
        end
        return #names > 0 and table.concat(names, "/") or nil
    end
    if seg[1] == "usr" and seg[2] == "include" then
        return sdk_modules.usr_owner_of(sdk, file)
    end
    return nil
end

local function base_arguments(sdk)
    local target = "arm64-apple-ios" .. sdk_info.discover(sdk).version
    return {"-E", "-M", "-x", "objective-c", "-target", target, "-isysroot", sdk,
            "-F", path.join(sdk, "System", "Library", "Frameworks"),
            "-F", path.join(sdk, "System", "Library", "SubFrameworks"),
            "-F", path.join(sdk, "Developer", "Library", "Frameworks"),
            "-I", path.join(sdk, "usr", "include")}
end

local function run(name, program, argv)
    local out, failure = nil, nil
    try {
        function()
            out = os.iorunv(program, argv)
        end,
        catch {
            function(e)
                failure = e
            end
        }
    }
    assert(failure == nil, string.format("sdk_imports: clang could not preprocess %s: %s", name, tostring(failure)))
    return out
end

local function listed(out)
    local deps = string.gsub(out, "\\\n", " ")
    local list = {}
    for item in string.gmatch(string.sub(deps, (string.find(deps, ":", 1, true) or 0) + 1), "%S+") do
        table.insert(list, item)
    end
    return list
end

local function reached_by_headers(sdk, name, headers)
    local argv = base_arguments(sdk)
    for _, header in ipairs(headers) do
        table.insert(argv, "-include")
        table.insert(argv, header)
    end
    table.insert(argv, "/dev/null")
    return listed(run(name, CLANG, argv))
end

local function quoted(word)
    return "'" .. string.gsub(word, "'", "'\\''") .. "'"
end

local function reached_by_module(sdk, name, map)
    local argv = base_arguments(sdk)
    table.insert(argv, "-fmodules")
    table.insert(argv, "-fmodule-map-file=" .. map)
    table.insert(argv, "-")
    local words = {}
    for _, word in ipairs(argv) do
        table.insert(words, quoted(word))
    end
    local command = string.format("printf '@import %s;\\n' | %s %s", name, quoted(CLANG), table.concat(words, " "))
    return listed(run(name, "/bin/sh", {"-c", command}))
end

function closure(sdk, name)
    local key = sdk .. "\t" .. name
    if closure_memo[key] ~= nil then
        return closure_memo[key]
    end
    local reached, seen = {name}, {[name] = true}
    local record = sdk_modules.module_of(sdk, name)
    local files = {}
    if record ~= nil and record.kind == "usr" then
        files = reached_by_module(sdk, name, record.map)
    else
        local headers = sdk_modules.headers_of(sdk, name)
        if headers ~= nil then
            files = reached_by_headers(sdk, name, headers)
        end
    end
    for _, file in ipairs(files) do
        local owner = owner_of(sdk, file)
        if owner ~= nil and not seen[owner] then
            seen[owner] = true
            table.insert(reached, owner)
        end
    end
    closure_memo[key] = reached
    return reached
end

function umbrella_imports(sdk, name, with_self)
    local out = {}
    for _, module in ipairs(closure(sdk, name)) do
        if with_self or module ~= name then
            local line = sdk_modules.umbrella_import(sdk, module)
            if line then
                table.insert(out, "#import " .. line)
            end
        end
    end
    return out
end
