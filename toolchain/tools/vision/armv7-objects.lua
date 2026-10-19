import("core.base.json")
import("core.project.project")
local backports = import("apple.backports", {rootdir = path.join(os.getenv("REVENANT_ROOT"), "modules"), anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local function rev(checkout, ref)
    local out = os.iorunv("git", {"rev-parse", ref}, {curdir = checkout})
    return (type(out) == "table" and table.concat(out, "") or tostring(out)):gsub("^%s+", ""):gsub("%s+$", "")
end

function main(folder, objects, release)
    local checkout = os.getenv("REVENANT_ROOT")
    local file = os.getenv("REVENANT_RESOLVE")
                 or path.join(os.getenv("HOME"), ".revenant", "cache", "gate-resolve",
                              rev(checkout, "HEAD:packages") .. "-" .. rev(checkout, "HEAD:addons") .. "-" .. release .. ".lua")
    local resolve = assert(io.load(file), "no resolve at " .. file)
    print("resolve: " .. file)

    local root = path.join(checkout, "packages", "a", "apple-backports")
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
                 store = path.join(os.getenv("HOME"), ".revenant", "cache", "objects"),
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
    io.writefile(path.join(objects, "..", "sdkdir"), opt.sdkdir)
end
