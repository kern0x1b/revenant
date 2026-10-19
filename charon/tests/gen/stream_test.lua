local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")

local function error_of(f)
    local message = nil
    try {
        function()
            f()
        end,
        catch {
            function(e)
                message = tostring(e)
            end
        }
    }
    return message
end

local function running(text)
    local found = {}
    for line in string.gmatch(os.iorunv("ps", {"-axo", "pid=,state=,command="}), "[^\n]+") do
        if string.find(line, text, 1, true) and not string.find(line, "^%s*%d+%s+Z") then
            table.insert(found, line)
        end
    end
    return found
end

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local stream = import("gen.stream", {rootdir = TOOLS, anonymous = true})

    local got = {}
    local status = stream.lines("sh", {"-c", "echo a; echo b; printf c; exit 3"}, function(line)
        table.insert(got, line)
    end)
    check(status == 3, "lines: the exit status of the program is returned")
    check(table.concat(got, "|") == "a|b|c", "lines: lines come in order, and a last line with no line feed is passed on")

    local out = {}
    local run_status, err = stream.run("sh", {"-c", "echo out; echo err 1>&2; exit 4"}, function(line)
        table.insert(out, line)
    end)
    check(run_status == 4 and table.concat(out, "|") == "out" and err == "err\n",
          "run: the exit status and the standard error are returned, the standard output is the lines")

    local whole_status, whole, whole_err = stream.text("sh", {"-c", "printf abc; exit 3"})
    check(whole_status == 3 and whole == "abc" and whole_err == "", "text: the exit status is returned and the output is whole")
    local big_status, big = stream.text("sh", {"-c", "yes | head -c 3000000"})
    check(big_status == 0 and #big == 3000000 and big == string.rep("y\n", 1500000),
          "text: a three megabyte output comes back whole, the sentinel cut out of its last read")
    local mixed_status, mixed, mixed_err = stream.text("sh", {"-c", "echo out; echo err 1>&2"})
    check(mixed_status == 0 and mixed == "out\n" and mixed_err == "err\n", "text: the standard error is returned apart from the output")

    local secs = tostring(math.random(3000, 3999))
    local message = error_of(function()
        stream.lines("sh", {"-c", "echo first; sleep " .. secs}, function(line)
            raise("boom from the callback")
        end)
    end)
    check(message ~= nil and string.find(message, "boom from the callback", 1, true) ~= nil,
          "kill: the callback's error goes on")
    check(#running("sleep " .. secs) == 0, "kill: no sleep of the program is left running after the error")

    print("stream test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end
