import("core.base.global")

function main()
    local root = path.absolute(path.directory(os.scriptdir()))
    local scoped = path.join(os.getenv("HOME"), ".cache", "hades", "xmake-global")
    local store = global.get("pkg_installdir") or path.join(path.translate("~"), ".xmake", "packages")
    local run = {envs = {XMAKE_GLOBALDIR = scoped}, curdir = os.tmpdir()}
    os.mkdir(scoped)
    os.execv(os.programfile(), {"g", "--pkg_installdir=" .. store}, run)
    if os.isdir(path.join(scoped, ".xmake", "addons", "charon", "latest")) then
        os.execv(os.programfile(), {"addon", "--remove", "charon"}, run)
    end
    os.execv(os.programfile(), {"addon", "--install", path.join(root, "charon")}, run)
    print("charon from %s is the addon of %s, packages in %s", path.join(root, "charon"), scoped, store)
end
