local NAME = "org.revenant.backports"

package("backports")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The Backports libraries of revenant as the shared libraries of org.revenant.backports, which an application built outside the checkout links and depends on: each library an application uses by name, and the libraries it links from the same package, under the absolute names the device's package holds them under")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})
    add_configs("libraries", {description = "The Backports libraries the package holds, by target name, comma separated: an application links each one it uses by name, and the libraries they link from the same package come with them.", default = "FoundationBackports", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the Backports sources it builds, so a changed library is a different package.", default = backports_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        for _, name in ipairs(package:config("libraries"):split("%s*,%s*")) do
            package:add("links", name)
        end
        package:add("linkdirs", path.join("share", "root", "usr", "lib", "revenant", NAME))
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local wrapper = import("@addon.revenant.apple.wrapper", {anonymous = true})
        local macho = import("@addon.revenant.apple.macho", {anonymous = true})
        local backports = import("@addon.revenant.apple.backports_package", {anonymous = true})
        local runtime = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
        local lib = package:installdir("lib")
        local requested = package:config("libraries"):split("%s*,%s*")
        local wanted = {}
        for _, name in ipairs(requested) do
            wanted[name] = true
        end
        local targets, missing = requested, {}
        os.setenv("REVENANT_BACKPORTS_LIBRARIES", table.concat(requested, ","))
        repeat
            wrapper.install(package, {root = root, includes = {path.join(root, "frameworks", "Backports")}, targets = targets})
            missing = {}
            for _, file in ipairs(os.files(path.join(lib, "*.dylib"))) do
                for _, reference in ipairs(macho.images(macho.read(file))[1].libraries) do
                    if reference:startswith("/usr/lib/revenant/" .. NAME .. "/") then
                        local leaf = path.filename(reference)
                        local name = leaf:match("^lib(.+)%.dylib$")
                        if name and not wanted[name] and not os.isfile(path.join(lib, leaf)) then
                            wanted[name] = true
                            table.insert(missing, name)
                        end
                    end
                end
            end
            targets = missing
        until #missing == 0
        os.setenv("REVENANT_BACKPORTS_LIBRARIES", "")

        local libraries, found = os.files(path.join(lib, "*.dylib")), {}
        for _, file in ipairs(libraries) do
            table.insert(found, {leaf = path.filename(file), file = file})
        end
        runtime.stage({packages = {{name = NAME, version = backports.release(found, {}), title = "Revenant Backports",
                                    description = "The Backports libraries of one build of revenant's frameworks/Backports",
                                    depends = {}, libraries = libraries}},
                       root = path.join(package:installdir("share"), "root"),
                       metadata = path.join(package:installdir("share"), "shared-packages"), strip = {"-x"}})
        for _, library in ipairs(libraries) do
            os.rm(library)
        end
        package:setenv("REVENANT_SHARED_PACKAGE", NAME)
    end)

    on_test(function (package)
        local folder = path.join(package:installdir("share"), "root", "usr", "lib", "revenant", NAME)
        for _, name in ipairs(package:config("libraries"):split("%s*,%s*")) do
            assert(os.isfile(path.join(folder, "lib" .. name .. ".dylib")), "the package holds no lib" .. name .. ".dylib")
        end
        assert(os.isfile(path.join(package:installdir("share"), "shared-packages", NAME .. ".json")), "the package left no description of " .. NAME)
    end)
