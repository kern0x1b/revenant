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

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local host = import("gen.host", {rootdir = TOOLS, anonymous = true})

    local warned = "warning: unused {x}\n{\n    \"project\": {\"builddir\": \"build\"}\n}\n"
    check(host.json_of(warned, "xmake show").project.builddir == "build",
          "an object is decoded after a message that holds a brace")
    check(host.json_of("{\"targetfile\": \"a/b\"}", "xmake show -t decls").targetfile == "a/b",
          "an object at the start of the output is decoded")

    local message = error_of(function()
        host.json_of("no object here", "xmake show -t decls")
    end)
    check(message ~= nil and string.find(message, "xmake show -t decls", 1, true) ~= nil
          and string.find(message, "printed no JSON object", 1, true) ~= nil
          and string.find(message, "no object here", 1, true) ~= nil,
          "an output with no object names the request and shows the output")

    message = error_of(function()
        host.json_of("\n{ \"project\": ", "xmake show")
    end)
    check(message ~= nil and string.find(message, "does not decode", 1, true) ~= nil
          and string.find(message, "{ \"project\":", 1, true) ~= nil,
          "an object that does not decode shows the head of the output, not a decoder message alone")

    local fresh = "{\n    \"targetfile\": \"..\\/..\\/build\\/macosx\\/arm64\\/decls\"\n}\n"
        .. "warning: we cannot get tool(cxx) in toolchain(xcode) with macosx/arm64, because it has been not checked yet!\n"
        .. "warning: add -v for getting more warnings ..\n"
    local value, notes = host.json_of(fresh, "xmake show -t decls")
    check(value.targetfile == "../../build/macosx/arm64/decls", "a fresh tree's object decodes past the warning after it")
    check(string.find(notes, "not checked yet", 1, true) ~= nil and string.find(notes, "{", 1, true) == nil,
          "the warning after the object comes back as the notes, and no part of the object is in them")
    local _, plain_notes = host.json_of("{\"a\": 1}", "xmake show")
    check(plain_notes == "", "an object with nothing after it has no notes")

    value = host.json_of("{\"a\": \"x}y\", \"b\": \"q\\\"}\", \"c\": {\"d\": 2}} trailing", "xmake show")
    check(value.a == "x}y" and value.b == "q\"}" and value.c.d == 2, "braces and quotes inside strings do not end the object")

    value, notes = host.json_of("note {x}\n{\"targetfile\": \"t\"}\nwarning: w", "xmake show -t decls")
    check(value.targetfile == "t" and notes == "warning: w", "a brace in a message before the object does not decide its start")

    print("host_json test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end
