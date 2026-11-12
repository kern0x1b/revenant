set_project("shared-packages")
set_version("0.0.1")
local root = os.getenv("SHARED_PACKAGES_ROOT") or path.join(os.scriptdir(), "../../..")
add_repositories("revenant " .. root)
add_addons("revenant v0.8.17")
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = true}})
add_requires("revenant@libcxx", {alias = "libcxx", configs = {packaged = true}})
add_requireconfs("**.libcxx", {configs = {packaged = true}})
local PACKAGES = {"swift-crypto", "cryptokit", "uniformtypeidentifiers", "swiftui"}
for _, name in ipairs(PACKAGES) do
    add_requires("revenant@" .. name, {alias = name, configs = {shared = true}})
end

target("probe")
    set_kind("phony")
    for _, name in ipairs(PACKAGES) do
        add_packages(name)
    end
    on_config(function (target)
        local lines = {}
        for _, name in ipairs(PACKAGES) do
            table.insert(lines, name .. "=" .. target:pkg(name):installdir())
        end
        io.writefile(os.getenv("SHARED_PACKAGES_PROBE"), table.concat(lines, "\n") .. "\n")
    end)
