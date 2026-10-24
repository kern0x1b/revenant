local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local PROGRAM = "emulateinstall"
local PROJECT = "org.revenant.emulateinstall"
local INSTALLED = path.join("/usr/libexec", PROGRAM)

function main(device, release)
    device = device or "iPhone2,1"
    release = release or "6.1.3"
    local here = os.scriptdir()
    local out = runs.folder("emulate-install")
    os.mkdir(out)
    os.setenv("REVENANT_EMULATOR_ROOT", path.join(out, "emulator"))

    local existing = runs.images_of(PROJECT)[1]
    if existing then
        raise("the image for this project is already there: %s\n"
              .. "remove it to run this case against a fresh one, or run it against a device and release whose image\n"
              .. "this project has not got yet", existing)
    end

    local configure = path.join(out, "configure.log")
    local install = path.join(out, "install.log")
    os.execv(os.programfile(), {"f", "-p", "iphoneos", "-a", "armv7", "-y"},
             {curdir = here, stdout = configure, stderr = configure})
    os.execv(os.programfile(), {"emulate", "install", "-d", device, "-r", release},
             {curdir = here, stdout = install, stderr = install})
    local output = runs.lines(install)
    for index = math.max(1, #output - 2), #output do
        print("  " .. output[index])
    end

    local built
    for _, file in ipairs(os.files(path.join(here, "build", "**", PROGRAM))) do
        if os.isfile(file) then
            built = file
            break
        end
    end
    if not built then
        raise("the project was not built, so there is nothing to look for in the image; see %s", configure)
    end

    local image = runs.images_of(PROJECT)[1]
    if not image then
        raise("the install wrote no image.json, so it placed nothing it named; see %s", install)
    end
    local rootfs = path.join(image, "rootfs")
    print("the image is " .. rootfs)

    local target = path.join(rootfs, INSTALLED)
    local problems = {}
    if not os.exists(target) then
        table.insert(problems, "the directory the program belongs in is not there: " .. target)
        local usr = path.join(rootfs, "usr", "*")
        local listed = {}
        for _, entry in ipairs(os.files(usr)) do
            table.insert(listed, entry)
        end
        for _, entry in ipairs(os.dirs(usr)) do
            table.insert(listed, entry)
        end
        table.sort(listed)
        for _, entry in ipairs(listed) do
            table.insert(problems, "  " .. entry)
        end
        table.insert(problems, "the install reported success and placed nothing")
    elseif not os.isfile(target) then
        table.insert(problems, target .. " is not a file")
    else
        print("the program is at " .. target .. ", " .. os.filesize(target) .. " B")
        local built_uuid = runs.uuid(built)
        local installed_uuid = runs.uuid(target)
        print("  built     " .. (built_uuid or "no LC_UUID"))
        print("  installed " .. (installed_uuid or "no LC_UUID"))
        if not built_uuid or not installed_uuid then
            table.insert(problems, "  one of the two has no LC_UUID, so they cannot be told apart")
        elseif built_uuid == installed_uuid then
            print("  MATCH: the image holds this build's program")
        else
            table.insert(problems, "  MISMATCH: the image holds another build's program")
        end
    end
    if #problems > 0 then
        raise("%s", table.concat(problems, "\n"))
    end
end
