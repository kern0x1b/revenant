import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("apple.macho", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local EXCLUDED = {
    "^_OBJC_IVAR_%$_",
    "^__OBJC_PROTOCOL_%$_",
    "^__OBJC_LABEL_PROTOCOL_%$_",
    "^__OBJC_PROTOCOL_REFERENCE_%$_",
    "^___block_descriptor",
    "^___block_literal_",
    "^___copy_helper_block_",
    "^___destroy_helper_block_",
    "^___NSArray%d+__$",
    "^___NSDictionary%d+__$",
    "^___kCFBooleanTrue$",
    "^___kCFBooleanFalse$",
}

local function internal(name)
    if name:find("$shim", 1, true) then
        return true
    end
    for _, pattern in ipairs(EXCLUDED) do
        if name:match(pattern) then
            return true
        end
    end
    local bare = name:match("^_OBJC_%u*CLASS_%$_(.+)$") or name:match("^_(.+)$") or name
    return bare:startswith("revenant_") or bare:startswith("Revenant")
end

local function symbols_of(object)
    local data = macho.read(object)
    local found = {}
    for _, image in ipairs(macho.images(data)) do
        if image.symtab then
            local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
            local entry = image.wide and 16 or 12
            for index = 0, nsyms - 1 do
                local strx, kind = string.unpack("<I4B", data, image.base + symoff + index * entry + 1)
                if kind & 0xE0 == 0 and kind & 0x0E ~= 0 and kind & 0x10 == 0 and kind & 0x01 ~= 0 then
                    local start = image.base + stroff + strx + 1
                    local name = data:sub(start, data:find("\0", start, true) - 1)
                    if not internal(name) then
                        found[name] = true
                    end
                end
            end
        end
    end
    return table.orderkeys(found)
end

local function ladder()
    return dyld.held_ladder({"armv7", "armv7s"})
end

local function recorded_sdk(objectsdir)
    local file = path.join(path.directory(path.absolute(objectsdir)), "sdkdir")
    if os.isfile(file) then
        return io.readfile(file):trim()
    end
end

local function check(objectsdir, output, sdkdir)
    sdkdir = sdkdir or recorded_sdk(objectsdir)
    if not sdkdir then
        raise("release-split: %s has no record of the SDK it was compiled against (objects/sdkdir, written by the build); pass SDKDIR", objectsdir)
    end
    assert(os.isdir(sdkdir), "release-split: the SDK " .. sdkdir .. " is not there; pass SDKDIR")
    print("release-split: SDK " .. sdkdir)
    local files = os.files(path.join(objectsdir, "*.o"))
    assert(#files > 0, objectsdir .. " holds no *.o")
    byteorder.sort(files)

    local by_file, all_symbols = {}, {}
    for _, file in ipairs(files) do
        local name = path.filename(file)
        by_file[name] = symbols_of(file)
        for _, symbol in ipairs(by_file[name]) do
            all_symbols[symbol] = true
        end
    end

    local first = dyld.first_releases(ladder(), sdkdir, table.orderkeys(all_symbols))

    for symbol in pairs(all_symbols) do
        local class = symbol:match("^_OBJC_METACLASS_%$_(.+)$")
        local arrived = class and first["_OBJC_CLASS_$_" .. class]
        if arrived and (not first[symbol] or dyld.compare_versions(arrived, first[symbol]) < 0) then
            first[symbol] = arrived
        end
    end

    local lines, mixed = {}, {}
    for _, file in ipairs(files) do
        local name = path.filename(file)
        local seen = {}
        for _, symbol in ipairs(by_file[name]) do
            local release = first[symbol] or "none"
            table.insert(lines, name .. "\t" .. symbol .. "\t" .. release)
            seen[release] = true
        end
        local distinct = table.orderkeys(seen)
        if #distinct > 1 then
            table.insert(lines, name .. "\tMIXED-RELEASES\t" .. table.concat(distinct, ","))
            table.insert(mixed, name)
        end
    end

    local text = table.concat(lines, "\n") .. "\n"
    if output then
        io.writefile(output, text)
    else
        print(text)
    end

    local rungs = ladder()
    for index = 2, #rungs do
        local previous, current = rungs[index - 1].release, rungs[index].release
        if tonumber(current:match("^%d+")) - tonumber(previous:match("^%d+")) > 1 then
            cprint("${color.warning}note:${clear} no release is held between %s and %s, so %s here means after %s and by %s, not a measured first release",
                   previous, current, current, previous, current)
        end
    end

    if #mixed > 0 then
        raise("release-split: %d file(s) mix more than one release's symbols: %s", #mixed, table.concat(mixed, ", "))
    end
    cprint("release-split: clean, every object file's symbols first-appear in one release (%d files, %d symbols, %d releases checked)",
           #files, table.orderkeys(all_symbols) and #table.orderkeys(all_symbols) or 0, #ladder())
end

function main(objectsdir, output, sdkdir)
    assert(objectsdir, "usage: xmake l tools/release-split.lua OBJECTSDIR [OUTPUT] [SDKDIR]")
    local record = path.join(objectsdir, "sdkdir")
    if not os.isfile(record) then
        return check(objectsdir, output, sdkdir)
    end
    sdkdir = sdkdir or (os.isfile(record) and io.readfile(record):trim()) or nil
    local failed = {}
    for _, folder in ipairs(os.dirs(path.join(objectsdir, "*"))) do
        if #os.files(path.join(folder, "*.o")) > 0 then
            print("release-split: %s", folder)
            local ok, errors = try {function () check(folder, output and (output .. "." .. path.filename(folder)), sdkdir); return true end,
                                    catch {function (errors) return errors end}}
            if ok ~= true then
                cprint("${color.error}%s${clear}", tostring(ok))
                table.insert(failed, path.filename(folder))
            end
        end
    end
    if #failed > 0 then
        raise("release-split: %d folder(s) are not clean: %s", #failed, table.concat(failed, ", "))
    end
    cprint("release-split: every folder of %s is clean", objectsdir)
end
