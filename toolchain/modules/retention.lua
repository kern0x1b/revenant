local RETENTION_DAYS = 7
local STAMP = ".scratch-swept"

function free_kib(folder)
    local row = nil
    for line in os.iorunv("df", {"-k", folder}):gmatch("[^\n]+") do
        row = line
    end
    local fields = {}
    for word in row:gmatch("%S+") do
        table.insert(fields, word)
    end
    return tonumber(fields[4])
end

function worktree_names(checkout)
    local names = {[path.filename(checkout)] = true}
    local out = try { function () return os.iorunv("git", {"-C", checkout, "worktree", "list", "--porcelain"}) end }
    for line in (out or ""):gmatch("[^\n]+") do
        local root = line:match("^worktree (.+)$")
        if root then
            names[path.filename(root)] = true
        end
    end
    return names
end

function candidates(root)
    local folders = {}
    for _, entry in ipairs(os.dirs(path.join(root, "scratch", "*"))) do
        if not os.islink(entry) then
            table.insert(folders, entry)
        end
    end
    return folders
end

function touched_within(folder, days)
    local recent = true
    try
    {
        function ()
            recent = os.iorunv("find", {folder, "-mtime", "-" .. days, "-print", "-quit"}):trim() ~= ""
        end
    }
    return recent
end

function open_paths()
    local out = nil
    try
    {
        function ()
            out = os.iorunv("lsof", {"-n", "-P", "-F", "n"})
        end
    }
    if not out then
        return nil
    end
    local paths = {}
    for line in out:gmatch("[^\n]+") do
        local name = line:match("^n(/.*)$")
        if name then
            table.insert(paths, name)
        end
    end
    return paths
end

function real_path(folder)
    return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
end

function held(folder, paths)
    local real = real_path(folder)
    local prefix = real .. "/"
    for _, name in ipairs(paths) do
        if name == real or name:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function sweep(root, options)
    local days = options.days or RETENTION_DAYS
    local live = options.live or worktree_names(options.checkout)
    local report = {removed = {}, kept = {}, freed_kib = 0}
    os.mkdir(root)
    local paths = open_paths()
    if not paths then
        report.error = "lsof did not list the open files, so nothing was removed"
        if not options.dry then
            io.writefile(path.join(root, STAMP), tostring(os.time()))
        end
        return report
    end
    local before = free_kib(root)
    for _, folder in ipairs(candidates(root)) do
        local name = path.filename(folder)
        if live[name] then
            table.insert(report.kept, {folder = folder, why = "a live worktree is named after it"})
        elseif touched_within(folder, days) then
            table.insert(report.kept, {folder = folder, why = "modified in the last " .. days .. " days"})
        elseif held(folder, paths) then
            table.insert(report.kept, {folder = folder, why = "a process has files open in it"})
        else
            if not options.dry then
                os.tryrm(folder)
                if os.exists(folder) then
                    os.vrunv("rm", {"-rf", folder})
                end
            end
            table.insert(report.removed, folder)
        end
    end
    if not options.dry then
        io.writefile(path.join(root, STAMP), tostring(os.time()))
        report.freed_kib = free_kib(root) - before
    end
    return report
end
