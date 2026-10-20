function main()
    local root = os.scriptdir() .. "/../.."
    local backports = import("apple.backports", {rootdir = path.join(root, "modules"),
                                                anonymous = true})
    local failures = {}
    for _, library in ipairs(backports.libraries()) do
        local entries = library.archives or {}
        if #entries > 0 then
            local cxx = false
            local folder = path.join(root, "..", "packages", "frameworks", "apple-backports", library.folder)
            for _, source in ipairs(os.files(path.join(folder, "*.mm"))) do
                cxx = true
            end
            for _, wanted in ipairs(entries) do
                local marked = false
                for _, name in ipairs(library.c_archives or {}) do
                    if name == wanted then marked = true end
                end
                if not marked and not cxx then
                    table.insert(failures, string.format(
                        "%s links the archive %s and keeps no .mm object in any band, so link()'s "
                        .. "cxx rule would drop it from every band; an archive whose API is C says "
                        .. "c_archives",
                        library.name, tostring(wanted)))
                end
            end
        end
    end
    if #failures > 0 then
        for _, failure in ipairs(failures) do
            print("FAIL: " .. failure)
        end
        raise("%d library archive(s) a band with no C++ object could not link", #failures)
    end
    print("archive_language: every library's archives are reachable in every band that keeps an object")
    return true
end
