function work_tree_of(folder, ceilings)
    local stops = {}
    for entry in (ceilings or ""):gmatch("[^:]+") do
        stops[path.normalize(path.absolute(entry))] = true
    end
    local head = path.normalize(path.absolute(folder))
    while #head > 1 do
        if os.exists(path.join(head, ".git")) then
            return head
        end
        local parent = path.directory(head)
        if parent == head or stops[parent] then
            return nil
        end
        head = parent
    end
    return nil
end

function launch_problem(settings)
    local launcher = path.join(settings.checkout, "xmakew")
    if not settings.store or settings.store == "" then
        return string.format("this xmake was not started by the xmakew of the revenant checkout %s: REVENANT_STORE is unset, and only the launcher of the shared store sets it. An older xmakew builds a package store of its own inside the cache and runs the recipes of this checkout against it, with no git ceilings, so that recipe patches are skipped without an error and the packages come out unpatched. Start the build with %s, not with an xmakew found on PATH or in another checkout", settings.checkout, launcher)
    end
    if settings.globaldir and settings.globaldir ~= "" then
        local top = work_tree_of(path.join(settings.globaldir, ".xmake", "cache", "packages"), settings.ceilings)
        if top then
            return string.format("XMAKE_GLOBALDIR is %s, whose package sources are unpacked inside the git work tree %s: git apply, which xmake patches them with, skips every patch inside a work tree without an error, so the packages would come out unpatched. Start the build with %s, which keeps the store out of reach of git with GIT_CEILING_DIRECTORIES", settings.globaldir, top, launcher)
        end
    end
end
