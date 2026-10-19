import("core.base.signal")

local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})
local mutant = import("collection-mutant", {rootdir = path.join(os.scriptdir(), "..", "..", "callgen"), anonymous = true})

local HERE = os.scriptdir()
local FACTORY = "packages/a/apple-backports/Intents/IN16_0.m"
local COUNT_LINE = "^  [A-Z].*count="

local function tails(files, count)
    local shown = {}
    for _, file in ipairs(files) do
        if os.isfile(file) then
            table.insert(shown, {file, steps.tail(file, count)})
        end
    end
    if #shown == 1 then
        return shown[1][2]
    end
    local out = {}
    for _, entry in ipairs(shown) do
        table.insert(out, string.format("==> %s <==\n%s", entry[1], entry[2]))
    end
    return table.concat(out, "\n\n")
end

function counts(text)
    return steps.text(steps.matching(text, {COUNT_LINE}))
end

function verdict(work)
    local real = steps.read(path.join(work, "real.counts"))
    local mutated = steps.read(path.join(work, "mutant.counts"))
    local restored = steps.read(path.join(work, "restored.counts"))
    local real_name, mutant_name = path.join(work, "real.counts"), path.join(work, "mutant.counts")
    if real == mutated then
        print("FAIL: the mutation did not change the count table on the device")
        io.write(steps.unified(real, mutated, real_name, mutant_name))
        return false
    end
    if real ~= restored then
        print("FAIL: the restored factory does not answer as the real one did")
        io.write(steps.unified(real, restored, real_name, path.join(work, "restored.counts")))
        return false
    end
    print("the mutation turns the table red on the device, and the restored factory answers as it did:")
    io.write(steps.unified(real, mutated, real_name, mutant_name))
    return true
end

function run(opt)
    opt = opt or {}
    local root = steps.revenant()
    local device = opt.device or steps.env("COLLECTION_DEVICE") or "iPhone3,1"
    local release = opt.release or steps.env("COLLECTION_RELEASE") or "6.1.3"
    local work = opt.work or steps.env("COLLECTION_WORK") or steps.workspace().run("revenant-calls", "collection")
    local intents = path.join(root, FACTORY)
    local real = path.join(work, "IN16_0.real.m")
    os.mkdir(work)
    os.cp(intents, real)
    local envs = {CHARCALLS_ROOT = root, CHARCALLS_MINIMUM = release}
    local emulate = {"emulate", "-d", device, "-r", release}

    local function restore()
        if os.isfile(real) then
            os.cp(real, intents)
        end
    end

    local function configure()
        steps.required({what = "the port", verb = "configure", curdir = HERE, envs = envs, tail = 15,
                        argv = {"f", "-c", "-p", "iphoneos", "-a", "armv7", "-y"}, log = path.join(work, "configure.log")})
    end

    local function build(label)
        local build_log = path.join(work, "build-" .. label .. ".log")
        local install_log = path.join(work, "install-" .. label .. ".log")
        local ok = steps.spawn({curdir = HERE, envs = envs, argv = {"build", "-y", "revenantcollection"}, log = build_log}) == 0
                   and steps.spawn({curdir = HERE, envs = envs, argv = table.join(emulate, {"install"}), log = install_log}) == 0
        if not ok then
            raise("%s: build or install failed; %s says why\n%s", label, path.join(work, "*-" .. label .. ".log"),
                  tails({build_log, install_log}, 15))
        end
    end

    local function measure(label)
        local status = steps.spawn({curdir = HERE, envs = envs, log = path.join(work, label .. ".raw"),
                                    argv = table.join(emulate, {"run", "/usr/libexec/revenantcollection",
                                                      string.format("the port's own body (%s)", label)})})
        local counts_status = steps.spawn({curdir = HERE, envs = envs, log = path.join(work, label .. ".counts.raw"),
                                           argv = table.join(emulate, {"run", "/usr/libexec/revenantcollection", "counts"})})
        local transcript = path.join(work, label .. ".txt")
        local transcript_text = steps.plain(io.readfile(path.join(work, label .. ".raw")))
        local counts_text = steps.plain(io.readfile(path.join(work, label .. ".counts.raw")))
        io.writefile(transcript, transcript_text)
        io.writefile(path.join(work, label .. ".counts.all"), counts_text)
        if status ~= 0 or counts_status ~= 0 then
            raise("%s: the run exited %d and the counts run %d; %s says what came back\n%s", label, status, counts_status,
                  transcript, steps.tail(transcript, 15))
        end
        local table_text = counts(counts_text)
        io.writefile(path.join(work, label .. ".counts"), table_text)
        if table_text == "" then
            raise("FAIL: the %s run printed no count table; %s says why", label, transcript)
        end
        local shown = counts(transcript_text)
        if shown == "" then
            io.stderr:write(string.format("%s: no count line in the transcript; %s is what came back\n", label, transcript))
        else
            io.write(shown)
        end
    end

    signal.register(signal.SIGINT, function ()
        restore()
        os.exit(1)
    end)
    try {
        function ()
            print("=== the port's own body, on %s at %s", device, release)
            configure()
            build("real")
            measure("real")

            print("=== the mutant: one element fewer than the host's answer")
            local mutated = path.join(work, "IN16_0.mutant.m")
            io.writefile(mutated, mutant.mutated(io.readfile(intents, {encoding = "binary"})), {encoding = "binary"})
            os.cp(mutated, intents)
            build("mutant")
            measure("mutant")

            print("=== putting the real factory back and rebuilding the library from it")
            restore()
            build("restored")
            measure("restored")
        end,
        finally {
            function ()
                restore()
            end
        }
    }
    local changed = steps.lines(os.iorunv("git", {"status", "--short", "--", FACTORY}, {curdir = root}))
    print("--- the tree: %d changed file(s) in the factory", #changed)
    print("--- the tables are in %s, %s and %s", path.join(work, "real.txt"), path.join(work, "mutant.txt"),
          path.join(work, "restored.txt"))
    print("--- the counts the two guards compare are in %s, %s and %s", path.join(work, "real.counts"),
          path.join(work, "mutant.counts"), path.join(work, "restored.counts"))
    return {work = work, changed = #changed, ok = verdict(work)}
end

function main(...)
    steps.guard(function (...)
        local given = steps.options({...}, {["--device"] = "value", ["--release"] = "value"})
        if not run({device = given.device, release = given.release}).ok then
            os.exit(1)
        end
    end, ...)
end
