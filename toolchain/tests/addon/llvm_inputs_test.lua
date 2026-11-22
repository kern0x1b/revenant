import("fixtures")

local ALLOWED = {
    ["@addon.revenant.prebuilt"] = true, ["@addon.revenant.checkout"] = true, ["@addon.revenant.parallel"] = true,
    ["git"] = true, ["cmake"] = true,
    ["patches"] = true, ["libraries"] = true, ["iphoneos-sdk"] = true,
    ["build-clang"] = true, ["build-builtins"] = true,
    ["bin"] = true, ["lib"] = true, ["licenses"] = true, ["clang"] = true, ["llvm"] = true, ["compiler-rt"] = true, ["LICENSE.TXT"] = true,
    ["Developer.app"] = true, ["Contents"] = true, ["Developer"] = true, ["Platforms"] = true, ["iPhoneOS.platform"] = true,
    ["SDKs"] = true, ["iPhoneOS"] = true, [".sdk"] = true,
    ["{([%w_]+)}"] = true,
    ["llvm: the inputs name {%s}, which the build does not give"] = true
}

local MODULES = {["inputs.lua"] = true, ["xmake.lua"] = true, ["digest.lua"] = true}

local PROVIDED = {"build", "install", "arch", "link_jobs", "patch", "clang", "host_linker", "llvm_cmake_dir", "resource_install", "sysroot", "sdk_version"}

local OPENERS = {["function"] = true, ["if"] = true, ["do"] = true, ["repeat"] = true}
local CLOSERS = {["end"] = true, ["until"] = true}

local function lex(source)
    local tokens = {}
    local at, size = 1, #source
    while at <= size do
        local char = source:sub(at, at)
        if source:sub(at, at + 1) == "--" then
            local level = source:match("^%-%-%[(=*)%[", at)
            if level then
                local close = "]" .. level .. "]"
                local stop = source:find(close, at, true)
                at = stop and stop + #close or size + 1
            else
                at = source:find("\n", at, true) or size + 1
            end
        elseif char == '"' or char == "'" then
            local cursor = at + 1
            while cursor <= size do
                local next = source:sub(cursor, cursor)
                if next == "\\" then
                    cursor = cursor + 2
                elseif next == char then
                    break
                else
                    cursor = cursor + 1
                end
            end
            table.insert(tokens, {kind = "string", text = source:sub(at + 1, cursor - 1), first = at, last = cursor})
            at = cursor + 1
        elseif char == "[" and source:match("^%[(=*)%[", at) then
            local close = "]" .. source:match("^%[(=*)%[", at) .. "]"
            local stop = source:find(close, at, true)
            local last = stop and stop + #close - 1 or size
            table.insert(tokens, {kind = "string", text = source:sub(at, last), first = at, last = last})
            at = last + 1
        elseif char:match("[%a_]") then
            local word = source:match("^[%w_]+", at)
            table.insert(tokens, {kind = "word", text = word, first = at, last = at + #word - 1})
            at = at + #word
        else
            at = at + 1
        end
    end
    return tokens
end

local function literals(source)
    local found = {}
    for _, token in ipairs(lex(source)) do
        if token.kind == "string" then
            table.insert(found, token.text)
        end
    end
    return found
end

local function body(source, header)
    local first = source:find(header, 1, true)
    if not first then
        return nil
    end
    local start = source:find("\n", first, true)
    local depth = 0
    for _, token in ipairs(lex(source)) do
        if token.kind == "word" and token.first >= first then
            if OPENERS[token.text] then
                depth = depth + 1
            elseif CLOSERS[token.text] then
                depth = depth - 1
                if depth == 0 then
                    return source:sub(start, token.last)
                end
            end
        end
    end
    return source:sub(start)
end

local function lua_files(folder)
    local found = {}
    for _, file in ipairs(os.files(path.join(folder, "**.lua"))) do
        table.insert(found, path.relative(file, folder))
    end
    table.sort(found)
    return found
end

local function problems(recipe, files)
    local found = {}
    for _, header in ipairs({"on_download(function", "on_install(\"@macosx\", function"}) do
        local text = body(recipe, header)
        if not text then
            table.insert(found, "llvm/xmake.lua has no " .. header .. " to check")
        else
            for _, literal in ipairs(literals(text)) do
                if not ALLOWED[literal] then
                    table.insert(found, string.format("llvm/xmake.lua writes \"%s\" in its build code: put it in packages/l/llvm/port/inputs.lua so the recipe digest reads it (or add it to ALLOWED in llvm_inputs_test.lua if it only names a program, a folder or a module)", literal))
                end
            end
        end
    end
    local before_test = recipe:sub(1, (recipe:find("\n    on_test(", 1, true) or #recipe))
    for _, literal in ipairs(literals(before_test)) do
        if (literal:find("^https?://") and literal ~= "https://llvm.org") or literal:find("^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$") or literal:find("%.patch$") or literal:find("^llvmorg") then
            table.insert(found, string.format("llvm/xmake.lua writes \"%s\": a url, a commit or a patch belongs in packages/l/llvm/port/inputs.lua", literal))
        end
        if (literal:find("%.lua$") or literal:find("^@addon")) and not ALLOWED[literal] and not MODULES[literal] then
            table.insert(found, string.format("llvm/xmake.lua names the module \"%s\": a flag or a step that comes from another file escapes the recipe digest; put it in packages/l/llvm/port/inputs.lua (or add the module to ALLOWED or MODULES in llvm_inputs_test.lua if it can change no output)", literal))
        end
    end
    for _, file in ipairs(files) do
        if file ~= "xmake.lua" and file ~= path.join("port", "inputs.lua") then
            table.insert(found, string.format("packages/l/llvm/%s is a file of the recipe that the digest does not read: put what the build reads in port/inputs.lua", file))
        end
    end
    if not recipe:find("default = llvm_recipe_key(os.scriptdir())", 1, true) then
        table.insert(found, "llvm/xmake.lua's recipe config is not llvm_recipe_key(os.scriptdir()), the digest of port/inputs.lua")
    end
    return found
end

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local duplicate = {}
    for key, item in pairs(value) do
        duplicate[key] = copy(item)
    end
    return duplicate
end

local function placeholders(value, names)
    if type(value) == "table" then
        for _, item in pairs(value) do
            placeholders(item, names)
        end
    elseif type(value) == "string" then
        for name in value:gmatch("{([%w_]+)}") do
            names[name] = true
        end
    end
    return names
end

function failures(opt)
    local found = {}
    local root = path.join(opt.modules, "..", "..")
    local folder = path.join(root, "packages", "l", "llvm")
    local module = import("inputs", {rootdir = path.join(folder, "port"), anonymous = true})
    local inputs = module.llvm_inputs()
    local recipe = io.readfile(path.join(folder, "xmake.lua"))
    local files = lua_files(folder)

    for _, problem in ipairs(problems(recipe, files)) do
        table.insert(found, problem)
    end

    local function reported(name, text, listed, fragment)
        for _, problem in ipairs(problems(text, listed)) do
            if problem:find(fragment, 1, true) then
                return
            end
        end
        table.insert(found, name .. ": the check does not report it")
    end
    local function inserted(text, after, added)
        local first, last = text:find(after, 1, true)
        return text:sub(1, last) .. added .. text:sub(last + 1)
    end
    local evil = "        os.vrunv(\"sh\", {\"-c\", \"evil-flag\"})\n"
    reported("a flag read through a second module that the recipe includes",
             inserted(recipe, "port\", \"inputs.lua\"))", "\n    includes(path.join(os.scriptdir(), \"port\", \"extra.lua\"))"), files, "extra.lua")
    reported("a second file in the recipe's folder", recipe, table.join(files, {path.join("port", "extra.lua")}), path.join("port", "extra.lua"))
    local helper = "@addon.revenant." .. "flags"
    reported("an addon module imported at the top of the recipe", inserted(recipe, "local inputs = llvm_build_inputs", "\n    local extra = import(\"" .. helper .. "\", {anonymous = true})"),
             files, helper)
    reported("a literal after a nested block that closes at the indent of the build function's end",
             inserted(recipe, "on_install(\"@macosx\", function (package)\n", "        table.sort({}, function (a, b)\n            return a < b\n    end)\n" .. evil), files, "evil-flag")
    local reindented = recipe:gsub("\n    end%)", "\n  end)")
    if #problems(reindented, files) > 0 then
        table.insert(found, "a recipe whose blocks end at another indent reports a problem that the original does not have")
    end
    reported("a literal in a recipe whose blocks end at another indent", inserted(reindented, "on_download(function (package, opt)\n", evil), files, "evil-flag")

    local install = body(recipe, "on_install(\"@macosx\", function")
    local provided = {}
    for _, name in ipairs(PROVIDED) do
        provided[name] = true
    end
    for name in pairs(placeholders(inputs, {})) do
        if not provided[name] then
            table.insert(found, string.format("port/inputs.lua uses {%s}, which the build does not give (llvm_inputs_test.lua lists what it gives)", name))
        end
    end
    for _, name in ipairs(PROVIDED) do
        if install and name ~= "patch" and not install:find(name, 1, true) then
            table.insert(found, string.format("the build does not give {%s}, which llvm_inputs_test.lua says it gives", name))
        end
    end

    local digest = module.llvm_recipe_digest(folder)
    local moved = {
        ["procedure"] = function (changed) changed.procedure = changed.procedure + 1 end,
        ["url"] = function (changed) changed.url = changed.url .. "x" end,
        ["version"] = function (changed) changed.version = "23.1.4" end,
        ["commit"] = function (changed) changed.commit = changed.commit:reverse() end,
        ["tag prefix"] = function (changed) changed.tag_prefix = "llvm-" end,
        ["a sparse entry"] = function (changed) changed.sparse[2] = "/*/" end,
        ["the patch list"] = function (changed) table.remove(changed.patches) end,
        ["how a patch is applied"] = function (changed) changed.apply[3] = "-p1" end,
        ["a compiler flag"] = function (changed) changed.compiler.configure[7] = "-DCMAKE_BUILD_TYPE=Debug" end,
        ["a flag only the libraries build passes"] = function (changed) changed.compiler.libraries[1] = "-DLLVM_BUILD_LLVM_DYLIB=OFF" end,
        ["a cmake target"] = function (changed) changed.compiler.targets[1] = "install-clang-format" end,
        ["a target only the libraries build builds"] = function (changed) changed.compiler.libraries_targets[1] = "install-distribution-stripped" end,
        ["a builtins flag"] = function (changed) changed.builtins.configure[8] = "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld" end,
        ["the host linker lookup"] = function (changed) changed.host_linker.arguments[2] = "ld64" end,
        ["a cmake build argument"] = function (changed) changed.cmake.build[1] = "--rebuild" end
    }
    for name, change in pairs(moved) do
        local changed = copy(inputs)
        change(changed)
        if module.llvm_recipe_digest(folder, changed) == digest then
            table.insert(found, name .. " must change the recipe digest")
        end
    end
    local work = fixtures.scratch()
    local copied = path.join(work, "llvm")
    os.cp(folder, copied)
    io.writefile(path.join(copied, "xmake.lua"), "-- a new comment\n" .. recipe:gsub("os.tryrm%(compiler%)", "os.tryrm(compiler) -- again\n        os.tryrm(compiler)") .. "\nlocal layout_only = 1\n")
    if module.llvm_recipe_digest(copied) ~= digest then
        table.insert(found, "a change of the build code's layout moves the recipe digest; it must read only port/inputs.lua and the patches")
    end
    for _, patch in ipairs(inputs.patches) do
        local file = path.join(copied, "patches", patch)
        local original = io.readfile(file)
        io.writefile(file, original .. "\n")
        if module.llvm_recipe_digest(copied) == digest then
            table.insert(found, patch .. " changed by a byte and the recipe digest did not move")
        end
        io.writefile(file, original)
    end
    if module.llvm_recipe_digest(copied) ~= digest then
        table.insert(found, "the copy with every patch restored has another digest than the original")
    end

    local aliases = module.llvm_aliases()
    for key, value in pairs(aliases) do
        if key ~= digest then
            table.insert(found, string.format("the alias %s no longer matches the inputs (digest %s): delete the entry, an input has changed since it was written", key, digest))
        end
        if not value:find("^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$") then
            table.insert(found, string.format("the alias %s names \"%s\", which is not a recipe digest", key, value))
        end
    end
    local pinned = {[digest] = "4c6acdde5d0e3e4b5da9051c33454e22"}
    if module.llvm_recipe_key(folder, nil, pinned) ~= "4c6acdde5d0e3e4b5da9051c33454e22" then
        table.insert(found, "the exact inputs of an alias do not give its key")
    end
    if module.llvm_recipe_key(folder, nil, {}) ~= digest then
        table.insert(found, "without an alias the key is not the digest of the inputs")
    end
    for name, change in pairs(moved) do
        local changed = copy(inputs)
        change(changed)
        local key = module.llvm_recipe_key(folder, changed, pinned)
        if key == "4c6acdde5d0e3e4b5da9051c33454e22" then
            table.insert(found, name .. " changed and the alias still gave the old key")
        elseif key ~= module.llvm_recipe_digest(folder, changed) then
            table.insert(found, name .. " changed and the key is not the digest of the new inputs")
        end
    end
    local file = path.join(copied, "patches", inputs.patches[1])
    local original = io.readfile(file)
    io.writefile(file, original .. "\n")
    if module.llvm_recipe_key(copied, nil, pinned) == "4c6acdde5d0e3e4b5da9051c33454e22" then
        table.insert(found, "a patch changed and the alias still gave the old key")
    end
    io.writefile(file, original)
    os.tryrm(work)
    return found
end
