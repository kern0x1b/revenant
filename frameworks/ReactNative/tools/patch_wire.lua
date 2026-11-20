local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/patch_wire.lua RECIPE VERSION PATCH_FILE PATCH_NAME
  Copies PATCH_FILE to packages/<first letter>/RECIPE/patches/PATCH_NAME and registers it in the recipe's xmake.lua with its
  sha256 on the line after add_versions("VERSION", ...); a registration of the same patch is replaced, so it can be run again
  after the patch changed. Make the patch with `diff -ru a/ios b/ios` between an unpacked copy of the package and an edited one.]]

function main(recipe, version, source, name)
    if not (recipe and version and source and name) then
        print(USAGE)
        os.exit(1)
    end
    local folder = path.join("packages", recipe:sub(1, 1), recipe)
    local target = path.join(folder, "patches", name)
    os.mkdir(path.directory(target))
    os.cp(source, target)
    local file = path.join(folder, "xmake.lua")
    io.writefile(file, register(io.readfile(file), version, name, hash.sha256(target)))
    print(recipe, name, hash.sha256(target))
end

function register(text, version, name, sha)
    local line = string.format('    add_patches("%s", path.join(os.scriptdir(), "patches", "%s"), "%s")\n', version, name, sha)
    local escaped_version, escaped_name = version:gsub("%W", "%%%0"), name:gsub("%W", "%%%0")
    local pattern = '    add_patches%("' .. escaped_version .. '", path%.join%(os%.scriptdir%(%), "patches", "' .. escaped_name .. '"%), "[0-9a-f]+"%)\n'
    if text:find(pattern) then
        text = text:gsub(pattern, function () return line end)
    else
        local _, last = text:find('    add_versions%("' .. escaped_version .. '"[^\n]*\n')
        assert(last, "no add_versions line for " .. version)
        text = text:sub(1, last) .. line .. text:sub(last + 1)
    end
    return text
end
