import("core.base.option")
import("core.base.task")
import("core.project.config")
import("core.project.project")

function main()
    local firmware = import("apple.firmware", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
    local dyld = import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
    local action = option.get("action")
    if action == "list" then
        for _, folder in ipairs(os.dirs(path.join(dyld.root(), "*"))) do
            local held = {}
            for _, file in ipairs(os.filedirs(path.join(folder, "*"))) do
                local architecture = path.filename(file):match("^dyld_shared_cache_([%w_]+)$") or path.filename(file):match("^libraries_([%w_]+)$")
                if architecture then
                    table.insert(held, architecture)
                end
            end
            if #held > 0 then
                print("%s  %s", path.filename(folder), table.concat(held, " "))
            end
        end
        return
    end
    if action ~= "fetch" and action ~= "rootfs" and action ~= "classes" and action ~= "extract" then
        raise("xmake firmware takes fetch, rootfs, classes, extract or list, not %s", tostring(action))
    end
    local release = option.get("release") or raise("xmake firmware fetch needs the release")
    task.run("config", {}, {disable_dump = true})
    local architecture = option.get("arch") or config.arch()
    local tool = project.required_package("firmware-tools")
    if not tool then
        raise("the project requires no firmware-tools; includes(\"@addon/charon/apple-ios\") provides it")
    end
    local charon_firmware = path.join(tool:installdir(), "bin", "charon-firmware")
    if action == "rootfs" then
        local device = option.get("device") or raise("xmake firmware rootfs needs --device=IDENTIFIER, e.g. iPhone3,1")
        local folder, chosen = firmware.rootfs(device, release, {tool = charon_firmware})
        cprint("${bright}%s${clear}: %s iOS %s (%s)", folder, chosen.identifier, chosen.version, chosen.build)
        return
    end
    local held, fetched = firmware.fetch(architecture, release, {tool = charon_firmware})
    if action == "extract" then
        local library = option.get("library") or raise("xmake firmware extract needs --library=INSTALL, e.g. --library=UIKit")
        local output = option.get("output") or path.join(path.directory(held), path.filename(library))
        local taken = dyld.extract(held, library, output)
        cprint("${bright}%s${clear}: %s of iOS %s, %d segments, %d symbols of which %d are its own, %d pointers to rebase, %.1f MB",
               output, taken.install, fetched or release, #taken.segments, taken.symbols, taken.locals, taken.pointers, taken.size / 1048576)
        if taken.slide_info then
            cprint("${color.warning}note:${clear} the cache says where its pointers are in slide info version %d, which this extraction does not read, so the library carries no rebase opcodes: it is for reading, not for loading", taken.slide_info)
        end
        return
    end
    if action == "classes" then
        import("core.base.json")
        local objc = import("apple.objc", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
        local inventory = objc.inventory(held)
        local classes = {}
        for name, class in pairs(inventory.classes) do
            local function selectors(set)
                local names = {}
                for key in pairs(set) do
                    table.insert(names, key:sub(2))
                end
                table.sort(names)
                return names
            end
            classes[name] = {superclass = class.superclass, image = class.image, instance = selectors(class.instance),
                             class = selectors(class.class), protocols = table.orderkeys(class.protocols)}
        end
        local output = option.get("output") or path.join(path.directory(held), "classes_" .. architecture .. ".json")
        json.savefile(output, {release = fetched, architecture = architecture, classes = classes})
        cprint("${bright}%s${clear}: the Objective-C classes of iOS %s for %s", output, fetched, architecture)
        return
    end
    cprint("${bright}%s${clear}: iOS %s for %s", held, fetched, architecture)
end
