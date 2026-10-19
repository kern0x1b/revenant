-- xmake l third_party/fetch.lua <name> [<outputdir>]
--
-- Prepares one third-party source from its pin: third_party/<name>/UPSTREAM names where it comes from, and
-- third_party/<name>/patches/*.patch, applied in order, are ours. Nothing of upstream is kept in this repository.
--
-- UPSTREAM holds "key value" lines:
--   url <git url> and commit <full hash>    a git source, fetched at that commit only, our patches committed on top
--   url <archive url> and sha256 <digest>   an archive, checked against the digest; "extract <path>" names the part
--                                           of it that is wanted
--
-- The output (default .deps/<name> at the top of the repository, never tracked) is made again only when the pin
-- or a patch changed: <output>.stamp holds the digest of everything it was made from. The patches are committed
-- with a fixed identity and their own dates, so the same pin and patches give the same commit, and a build that
-- keys on that commit (Shade's IR artifacts do) sees a different source as a different build.

local function readpin(dir)
    local file = path.join(dir, "UPSTREAM")
    assert(os.isfile(file), "no pin: " .. file)
    local pin = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        local key, value = line:match("^(%S+)%s+(%S+)$")
        assert(key, "a pin line is \"key value\": " .. line)
        pin[key] = value
    end
    assert(pin.url, "the pin names no url: " .. file)
    assert(pin.commit or pin.sha256, "the pin names neither a commit nor a sha256: " .. file)
    return pin
end

local function git(dir, args)
    os.vrunv("git", table.join({"-C", dir}, args))
end

local function fetch_git(pin, patches, output)
    os.mkdir(output)
    git(output, {"init", "-q"})
    -- through a remote named origin: submodules named by a relative url resolve against it
    git(output, {"remote", "add", "origin", pin.url})
    git(output, {"fetch", "-q", "--depth", "1", "origin", pin.commit})
    git(output, {"-c", "advice.detachedHead=false", "checkout", "-q", "FETCH_HEAD"})
    if os.isfile(path.join(output, ".gitmodules")) then
        git(output, {"submodule", "update", "-q", "--init", "--recursive", "--depth", "1"})
    end
    if #patches > 0 then
        git(output, table.join({"-c", "user.name=hades", "-c", "user.email=hades@invalid", "am", "-q",
                                "--committer-date-is-author-date"}, patches))
    end
end

local function fetch_archive(pin, patches, output)
    local cache = path.join(path.directory(output), "downloads")
    local archive = path.join(cache, path.filename(pin.url))
    if not (os.isfile(archive) and hash.sha256(archive) == pin.sha256) then
        os.mkdir(cache)
        os.vrunv("curl", {"-fsSL", "-o", archive, pin.url})
    end
    local got = hash.sha256(archive)
    assert(got == pin.sha256, string.format("%s has sha256 %s, the pin says %s", archive, got, pin.sha256))
    local unpacked = output .. ".unpack"
    os.tryrm(unpacked)
    os.mkdir(unpacked)
    local args = {"-xf", archive, "-C", unpacked}
    if pin.extract then
        table.insert(args, pin.extract)
    end
    os.vrunv("tar", args)
    -- the archive's top folder becomes the output, holding only what "extract" named inside it
    local top = os.dirs(path.join(unpacked, "*"))
    assert(#top == 1, "the archive " .. archive .. " has no single top folder")
    os.mv(top[1], output)
    os.tryrm(unpacked)
    for _, patch in ipairs(patches) do
        os.vrunv("git", {"apply", patch}, {curdir = output})
    end
end

function main(name, outputdir)
    assert(name, "usage: xmake l third_party/fetch.lua <name> [<outputdir>]")
    local root = path.directory(os.scriptdir())
    local dir = path.join(os.scriptdir(), name)
    local pin = readpin(dir)
    local patches = {}
    for _, patch in ipairs(os.files(path.join(dir, "patches", "*.patch"))) do
        table.insert(patches, path.absolute(patch))
    end
    table.sort(patches)
    local output = path.absolute(outputdir or path.join(root, ".deps", name))
    local parts = {io.readfile(path.join(dir, "UPSTREAM"))}
    for _, patch in ipairs(patches) do
        table.insert(parts, path.filename(patch) .. "=" .. hash.sha256(patch))
    end
    local key = hash.strhash128(table.concat(parts, "\n"))
    local stamp = output .. ".stamp"
    if os.isdir(output) and os.isfile(stamp) and io.readfile(stamp) == key then
        print("%s is up to date at %s", name, output)
        return output
    end
    os.tryrm(output)
    os.tryrm(stamp)
    os.mkdir(path.directory(output))
    if pin.commit then
        fetch_git(pin, patches, output)
    else
        fetch_archive(pin, patches, output)
    end
    io.writefile(stamp, key)
    print("%s prepared at %s", name, output)
    return output
end
