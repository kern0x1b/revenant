local driver = import("driver", {rootdir = os.scriptdir(), anonymous = true})

local function expect(name, condition)
    if not condition then
        raise("%s", name)
    end
end

local function write(file, text)
    os.mkdir(path.directory(file))
    io.writefile(file, text)
end

function main()
    local root = path.join(import("@addon.revenant.workspace", {anonymous = true}).scratch(), "runtime-fingerprint-test")
    os.tryrm(root)
    local program = path.join(root, "emulator")
    local app = path.join(root, "app", "backports_runtime_app")
    local library = path.join(root, "libs", "libFoundationBackports.dylib")
    local firmware = path.join(root, "firmware")
    write(program, "emulator bytes")
    write(app, "app bytes")
    write(library, "library bytes")
    write(path.join(firmware, "System", "Library", "CoreServices", "SystemVersion.plist"), "version")
    local libraries = {library}

    local function install(name, runner, manifest)
        write(path.join(root, name, "usr", "libexec", "revenant-runner"), runner)
        write(path.join(root, name, "manifest.txt"), manifest)
        return path.join(root, name)
    end
    local first = install("guest-first", "runner bytes", "installdir = guest-first")
    local moved = install("guest-moved", "runner bytes", "installdir = guest-moved")
    local changed = install("guest-changed", "other runner bytes", "installdir = guest-first")

    local function key(guest, application)
        return driver.fingerprint(application, guest, libraries, program, firmware).key
    end

    local base = key(first, app)
    expect("two invocations with no change give one key", key(first, app) == base)
    expect("the same payload in another install folder gives the same key", key(moved, app) == base)
    expect("a changed runner in the guest payload gives another key", key(changed, app) ~= base)

    write(app, "app bytes rebuilt")
    expect("a rebuilt app gives another key", key(first, app) ~= base)
    write(app, "app bytes")
    expect("restoring the app restores the key", key(first, app) == base)

    os.tryrm(root)
end
