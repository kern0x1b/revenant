local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/overlay.lua apply APP_DIR OVERLAY_DIR TARGET_DIR
  makes TARGET_DIR, an APFS clone of the application APP_DIR (read only, never written), and copies every file of
  OVERLAY_DIR/overlay over the same path in the clone. A file the clone does not have is an error: the overlay was made for
  another version of the application. TARGET_DIR is what build/ref/app links to. OVERLAY_DIR also holds the application's
  host.json (the manifest passed to inputs.lua --manifest) and packaging/.]]

function files(root)
    local found = {}
    for _, file in ipairs(os.files(path.join(root, "**"))) do
        table.insert(found, path.relative(file, root))
    end
    table.sort(found)
    return found
end

function apply(app, overlay, target)
    local source = path.join(overlay, "overlay")
    if not os.isdir(app) or not os.isdir(source) then
        raise("%s is not an application folder or %s has no overlay folder", app, overlay)
    end
    if os.exists(target) then
        raise("%s exists; remove it first", target)
    end
    local changes = files(source)
    for _, relative in ipairs(changes) do
        if not os.isfile(path.join(app, relative)) then
            raise("%s has no %s: the overlay is for another version of the application", app, relative)
        end
    end
    os.mkdir(path.directory(target))
    os.vrunv("cp", {"-cR", app, target})
    for _, relative in ipairs(changes) do
        os.vrunv("chmod", {"u+w", path.join(target, relative)})
        os.cp(path.join(source, relative), path.join(target, relative))
    end
    print(string.format("%s: %d files replaced", target, #changes))
end

function main(...)
    local args = {...}
    if args[1] ~= "apply" or #args ~= 4 then
        print(USAGE)
        os.exit(1)
    end
    apply(path.absolute(args[2]), path.absolute(args[3]), path.absolute(args[4]))
end
