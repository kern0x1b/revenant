import("fixtures")

local function install(store, name, version, digest, finished)
    local folder = path.join(store, "packages", name:sub(1, 1):lower(), name, version, digest)
    os.mkdir(path.join(folder, "bin"))
    io.writefile(path.join(folder, "bin", name), "#!/bin/sh\necho " .. digest .. "\n")
    if finished ~= false then
        io.writefile(path.join(folder, "manifest.txt"), "{ name = \"" .. name .. "\" }\n")
    end
    return folder
end

function failures(opt)
    local store = import("store", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local source, target = path.join(folder, "source", ".xmake"), path.join(folder, "target", ".xmake")
    install(source, "llvm", "23.1.1", "aaaa")
    install(source, "llvm", "23.1.1", "bbbb")
    install(source, "swift", "6.4.0", "cccc")
    install(source, "swift", "6.4.0", "dddd", false)
    install(target, "llvm", "23.1.1", "bbbb")

    -- An install without a manifest is one that was interrupted, not one to take.
    local listed = store.installs(source, "swift")
    if #listed ~= 1 or not listed[1]:endswith("cccc") then
        table.insert(found, "a store holds the installs whose manifest says they finished, not " .. table.concat(listed, " "))
    end
    if #store.installs(target, "nothing") ~= 0 then
        table.insert(found, "a package no store holds is no install")
    end

    local planned = store.borrowed(source, target, {"llvm", "swift"})
    local named = {}
    for _, entry in ipairs(planned) do
        table.insert(named, entry.at)
    end
    table.sort(named)
    local wanted = {path.join("packages", "l", "llvm", "23.1.1", "aaaa"), path.join("packages", "s", "swift", "6.4.0", "cccc")}
    if table.concat(named, " ") ~= table.concat(wanted, " ") then
        table.insert(found, "a store takes what it lacks and leaves what it holds: planned " .. table.concat(named, " "))
    end

    -- What is brought over answers under the same digest, which is what xmake
    -- looks an install up by, and the bytes are the ones it was built with.
    for _, entry in ipairs(planned) do
        store.bring(entry)
    end
    local brought = store.installs(target, "llvm")
    if #brought ~= 2 then
        table.insert(found, string.format("the target holds both installs after taking one, not %d", #brought))
    end
    local carried = path.join(target, "packages", "l", "llvm", "23.1.1", "aaaa", "bin", "llvm")
    if not os.isfile(carried) or not io.readfile(carried):find("aaaa", 1, true) then
        table.insert(found, "an install that is taken carries what is inside it")
    end
    if #store.borrowed(source, target, {"llvm", "swift"}) ~= 0 then
        table.insert(found, "a store that already holds every install takes nothing")
    end
    -- The plugin is what a session runs, and it runs in xmake's sandbox: the
    -- step installs the repository as an addon in a store of its own and asks
    -- it to take a package from another store of its own, so nothing of the
    -- machine's is touched and the task itself is what answers.
    local work = path.join(folder, "plugin")
    local held = path.join(work, "target")
    os.mkdir(held)
    local envs = {XMAKE_GLOBALDIR = held}
    os.iorunv("xmake", {"addon", "--install", "-y", path.absolute(path.join(opt.modules, ".."))}, {curdir = work, envs = envs})
    local answered = path.join(work, "borrow.log")
    local code = os.execv("xmake", {"borrow", "--from=" .. path.join(folder, "source"), "swift"},
                          {curdir = work, envs = envs, try = true, stdout = answered, stderr = answered})
    local told = (io.readfile(answered) or ""):trim()
    if code ~= 0 or not os.isfile(path.join(held, ".xmake", "packages", "s", "swift", "6.4.0", "cccc", "bin", "swift")) then
        table.insert(found, "the task takes the install it is asked for, and answered " .. tostring(code) .. ": " .. told:gsub("\n", " | "):sub(1, 400))
    end
    code = os.execv("xmake", {"borrow", "--from=" .. path.join(folder, "source"), "nothing"},
                    {curdir = work, envs = envs, try = true, stdout = answered, stderr = answered})
    if code == 0 then
        table.insert(found, "a package the source store holds nothing of is refused, not passed over")
    end
    os.tryrm(folder)
    return found
end
