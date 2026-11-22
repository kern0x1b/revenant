local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/overlay.lua update CHECKOUT URL [--main]
       ./xmakew l -P . frameworks/ReactNative/tools/overlay.lua apply APP_DIR OVERLAY_DIR TARGET_DIR
  update  fetches the upstream URL into CHECKOUT (cloned shallow when absent) and checks out, detached, the newest release tag
          (vMAJOR.MINOR.PATCH) or, with --main, the head of the default branch. It prints the tag and the commit. Nothing is
          committed, pushed or edited in CHECKOUT and no process stays behind: run it at the start of every build of the application.
  apply   makes TARGET_DIR, an APFS clone of the application APP_DIR (read only, never written), and copies every file of
          OVERLAY_DIR/overlay over the same path in the clone. A file the clone does not have is an error: the overlay was made
          for another version of the application. TARGET_DIR is what build/ref/app links to. OVERLAY_DIR also holds the
          application's host.json (the manifest passed to inputs.lua --manifest) and packaging/.
          Then the clone gets the application's own patches: when it has scripts/postinstall-patches.mjs, that script runs in the clone with
          node_modules/.bin first on PATH, as npm runs a postinstall. The application is installed with --ignore-scripts, which skips it; the
          patches (bottom-sheet exports, enriched-markdown, gesture-handler and others) are part of what the application is. The script
          applies a patch once and leaves an applied one alone, and a patch that does not apply stops apply with its output.]]

function git(checkout, args)
    local argv = {"-C", checkout}
    for _, arg in ipairs(args) do
        table.insert(argv, arg)
    end
    return (os.iorunv("git", argv):gsub("%s+$", ""))
end

function version_key(tag)
    local major, minor, patch = tag:match("^v(%d+)%.(%d+)%.(%d+)$")
    if not major then
        return nil
    end
    return tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)
end

function newest_tag(url)
    local best, best_key
    for line in os.iorunv("git", {"ls-remote", "--tags", "--refs", url}):gmatch("[^\n]+") do
        local tag = line:match("refs/tags/(.+)$")
        local key = tag and version_key(tag)
        if key and (not best_key or key > best_key) then
            best, best_key = tag, key
        end
    end
    if not best then
        raise("%s has no release tag vMAJOR.MINOR.PATCH", url)
    end
    return best
end

function update(checkout, url, head)
    if not os.isdir(path.join(checkout, ".git")) then
        os.mkdir(checkout)
        os.vrunv("git", {"-C", checkout, "init", "-q"})
        os.vrunv("git", {"-C", checkout, "remote", "add", "origin", url})
    end
    git(checkout, {"remote", "set-url", "origin", url})
    git(checkout, {"remote", "set-url", "--push", "origin", "no-push"})
    local name
    if head then
        os.vrunv("git", {"-C", checkout, "fetch", "-q", "--depth", "1", "origin", "HEAD"})
        name = "main"
    else
        name = newest_tag(url)
        os.vrunv("git", {"-C", checkout, "fetch", "-q", "--depth", "1", "origin", "tag", name})
    end
    os.vrunv("git", {"-C", checkout, "checkout", "-q", "--detach", head and "FETCH_HEAD" or name})
    print(string.format("%s %s", name, git(checkout, {"rev-parse", "HEAD"})))
end

function files(root)
    local found = {}
    for _, file in ipairs(os.files(path.join(root, "**"))) do
        table.insert(found, path.relative(file, root))
    end
    table.sort(found)
    return found
end

function patch_application(target)
    local script = path.join(target, "scripts", "postinstall-patches.mjs")
    if not os.isfile(script) then
        print(target .. ": no scripts/postinstall-patches.mjs, no patches applied")
        return
    end
    local bin = path.join(target, "node_modules", ".bin")
    local env = {PATH = bin .. ":" .. (os.getenv("PATH") or "")}
    os.vrunv("node", {path.join("scripts", "postinstall-patches.mjs")}, {curdir = target, envs = env})
    print(target .. ": the application's patches applied")
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
    patch_application(target)
end

function main(...)
    local args = {...}
    if args[1] == "update" and (#args == 3 or (#args == 4 and args[4] == "--main")) then
        update(path.absolute(args[2]), args[3], args[4] == "--main")
    elseif args[1] == "apply" and #args == 4 then
        apply(path.absolute(args[2]), path.absolute(args[3]), path.absolute(args[4]))
    else
        print(USAGE)
        os.exit(1)
    end
end
