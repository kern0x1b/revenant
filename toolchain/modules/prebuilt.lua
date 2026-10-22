import("byteorder")

local function source()
    local repository = os.getenv("REVENANT_PREBUILT")
    if repository and repository ~= "" then
        return repository
    end
end

local function only(package)
    local named = os.getenv("REVENANT_PREBUILT_ONLY") or ""
    if named == "1" then
        return true
    end
    for name in named:gmatch("[^,%s]+") do
        if name == package:name() then
            return true
        end
    end
    return false
end

function wanted(package)
    return source() ~= nil
end

function key(package)
    local parts = {package:name(), package:version_str() or "latest", package:plat(), package:arch(), package:buildhash()}
    local deps = {}
    for _, dep in ipairs(package:librarydeps() or {}) do
        table.insert(deps, dep:name() .. "=" .. dep:buildhash())
    end
    byteorder.sort(deps)
    local value = hash.strhash128(table.concat(table.join(parts, deps), ";"))
    if os.getenv("REVENANT_PREBUILT_TRACE") then
        local configs = {}
        for name, setting in pairs(package:_configs_for_buildhash() or {}) do
            table.insert(configs, name .. "=" .. (type(setting) == "table" and string.serialize(setting, {strip = true, indent = false}) or tostring(setting)))
        end
        byteorder.sort(configs)
        local urls = {}
        for _, url in ipairs(package:urls() or {}) do
            table.insert(urls, url .. "@" .. tostring(package:sourcehash(package:url_alias(url))))
        end
        print("prebuilt-trace %s parts=%s", package:name(), table.concat(parts, " | "))
        print("prebuilt-trace %s configs=%s", package:name(), table.concat(configs, " ; "))
        print("prebuilt-trace %s urls=%s label=%s", package:name(), table.concat(urls, " ; "), tostring(package:label()))
        print("prebuilt-trace %s deps=%s", package:name(), table.concat(deps, " | "))
        print("prebuilt-trace %s key=%s", package:name(), value)
    end
    return value
end

function tag(package)
    return "prebuilt-" .. package:name() .. "-" .. key(package)
end

function asset(package)
    return package:name() .. "-" .. key(package) .. "-" .. package:plat() .. "-" .. package:arch() .. ".tar.xz"
end

local function archive_of(package)
    return path.join(package:cachedir(), "prebuilt", asset(package))
end

local function ready(package)
    os.mkdir(path.join(package:cachedir(), "source"))
    return true
end

function fetch(package)
    local repository = source()
    if not repository then
        if only(package) then
            raise("%s: REVENANT_PREBUILT_ONLY needs REVENANT_PREBUILT, the repository whose release holds the prebuilt %s", package:name(), key(package))
        end
        return false
    end
    local archive = archive_of(package)
    if os.isfile(archive) then
        return ready(package)
    end
    local url = string.format("https://github.com/%s/releases/download/%s/%s", repository, tag(package), asset(package))
    local partial = archive .. ".part"
    local listed = archive .. ".sha256"
    os.mkdir(path.directory(archive))
    local fetched = try { function ()
        os.vrunv("curl", {"-fsSL", "--retry", "2", "-o", listed, url .. ".sha256"})
        os.vrunv("curl", {"-fsSL", "--retry", "2", "-o", partial, url})
        return true
    end }
    if not fetched then
        os.tryrm(partial)
        os.tryrm(listed)
        if only(package) then
            raise("%s: no release holds the prebuilt %s at %s, and REVENANT_PREBUILT_ONLY forbids building it from source", package:name(), key(package), repository)
        end
        print("%s: no prebuilt %s at %s, building from source", package:name(), key(package), repository)
        return false
    end
    local expected = io.readfile(listed):match("^(%x+)")
    local actual = hash.sha256(partial)
    os.tryrm(listed)
    if expected ~= actual then
        os.tryrm(partial)
        raise("%s: the prebuilt %s has the sha256 %s, its release lists %s", package:name(), url, actual, tostring(expected))
    end
    os.mv(partial, archive)
    return ready(package)
end

function install(package)
    if not fetch(package) then
        return false
    end
    local archive = archive_of(package)
    os.mkdir(package:installdir())
    os.vrunv("tar", {"-xJf", archive, "-C", package:installdir()})
    os.tryrm(archive)
    print("%s: installed the prebuilt %s from %s", package:name(), key(package), source())
    return true
end

function pack(package)
    local outdir = os.getenv("REVENANT_PREBUILT_OUT")
    if not outdir or outdir == "" then
        return
    end
    os.mkdir(outdir)
    local pinned = (try { function () return os.iorunv("grep", {"-rlF", package:installdir(), package:installdir()}) end } or "") ..
                   os.iorunv("find", {package:installdir(), "-type", "l", "-lname", package:installdir() .. "*"})
    if pinned:trim() ~= "" then
        raise("%s: these files name the install folder %s, so the archive would not work under another one:\n%s",
              package:name(), package:installdir(), pinned)
    end
    local archive = path.join(outdir, asset(package))
    os.vrunv("tar", {"-cJf", archive, "--exclude", "manifest.txt", "-C", package:installdir(), "."})
    io.writefile(archive .. ".sha256", hash.sha256(archive) .. "  " .. path.filename(archive) .. "\n")
    io.writefile(path.join(outdir, package:name() .. ".tag"), tag(package) .. "\n")
    print("%s: packed %s as %s", package:name(), key(package), archive)
end
