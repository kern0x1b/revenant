-- The armv7 objects of ONE library, compiled with the flags modules/apple/backports.lua's own
-- compile_arguments() produces for them, so that tools/release-split.lua and nm have something to
-- read for that library alone. The gate (coordination/build-gate.lua) compiles every library and
-- links every dylib; this is the seven files of one, in seconds, and it is what the Vision facts
-- page's member counts and release-split runs are measured from.
--
-- It is NOT a gate and does not replace one: it does not run the registry check, does not choose
-- bands, does not link, and writes no library. What it does is compile, and it does that through
-- backports.compile() rather than through a command line of its own, so the flags are the build's.
--
--   CHARON_ROOT=<checkout> xmake l tools/vision/armv7-objects.lua <library folder> <objects folder> <release>
--
-- <library folder> is relative to packages/a/apple-backports, or absolute -- an absolute path is
-- how one library's sources are compiled from somewhere other than the tree, which is how the
-- before-and-after comparison in facts/Vision/Absence.md section 7.2 was measured.
--
-- The resolve it reads is the machine's compiler, SDK and archives for a release; the file is keyed
-- by the tree that produced it, so a tree whose packages/ has moved since has no file of its own and
-- CHARON_RESOLVE names one. Whichever is read is printed, because a flag set that is not the one the
-- gate would use answers a different question than the gate does.
import("core.base.json")
import("core.project.project")
local backports = import("apple.backports", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local function rev(checkout, ref)
    local out = os.iorunv("git", {"rev-parse", ref}, {curdir = checkout})
    return (type(out) == "table" and table.concat(out, "") or tostring(out)):gsub("^%s+", ""):gsub("%s+$", "")
end

function main(folder, objects, release)
    local checkout = os.getenv("CHARON_ROOT")
    local file = os.getenv("CHARON_RESOLVE")
                 or path.join(os.getenv("HOME"), ".charon", "cache", "gate-resolve",
                              rev(checkout, "HEAD:packages") .. "-" .. rev(checkout, "HEAD:addons") .. "-" .. release .. ".lua")
    local resolve = assert(io.load(file), "no resolve at " .. file)
    print("resolve: " .. file)

    local root = path.join(checkout, "packages", "a", "apple-backports")
    -- The folder's own path is on the include list as well, or a library whose headers sit beside
    -- its sources compiles against a different copy of them whenever one exists elsewhere.
    local base = folder:startswith("/") and folder or path.join(root, folder)
    os.mkdir(objects)
    local opt = {root = root,
                 architecture = "armv7",
                 deployment = release,
                 triple = "armv7-apple-ios" .. release,
                 sdkdir = resolve.sdkdir,
                 ld = resolve.ld,
                 cc = resolve.cc,
                 archives = resolve.archives,
                 store = path.join(os.getenv("HOME"), ".charon", "cache", "objects"),
                 includes = {root, base}}
    local sources = table.join(os.files(path.join(base, "*.m")), os.files(path.join(base, "*.c")))
    assert(#sources > 0, base .. " holds no source to compile")
    byteorder.sort(sources)
    for _, source in ipairs(sources) do
        local object = path.join(objects, path.filename(source) .. ".o")
        backports.compile(opt, source, object)
        assert(os.isfile(object), source .. " did not compile")
        print(object)
    end
    -- release-split reads the SDK these were compiled against out of <objects>/../sdkdir, and it
    -- refuses a folder with no such record rather than guessing which SDK was meant.
    io.writefile(path.join(objects, "..", "sdkdir"), opt.sdkdir)
end
