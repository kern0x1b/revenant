local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local sdkfiles = import("sdk", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function failure_of(action)
    local failure
    try {
        function ()
            action()
        end,
        catch {
            function (raised)
                failure = tostring(raised)
            end
        }
    }
    return failure
end

local function expect(failure, what, parts)
    assert(failure ~= nil, what .. " did not fail")
    for _, part in ipairs(parts) do
        assert(failure:find(part, 1, true), what .. " failed without naming " .. part .. ":\n" .. failure)
    end
end

function main()
    local sdk = workspace.fresh("facts-error-sdk")
    local headers = path.join(sdk, "System", "Library", "Frameworks", "Fixture.framework", "Headers")
    os.mkdir(headers)
    io.writefile(path.join(sdk, "SDKSettings.json"), '{"Version": "99.9"}')
    local umbrella = path.join(headers, "Fixture.h")
    io.writefile(umbrella, '#error "the fixture header does not compile"\n')

    local cache = sdkfiles.cache_folder(sdk)
    local parts = {"clang failed to dump the declarations of " .. umbrella, "the fixture header does not compile", "-ast-dump", umbrella}
    expect(failure_of(function () facts.constant_intros(sdk) end), "the constant intros of an SDK whose header does not compile", parts)
    expect(failure_of(function () facts.objc_facts(sdk, "Fixture", "99.9") end), "the facts of a framework whose header does not compile", parts)
    assert(not os.isfile(path.join(cache, "constant_intros.tsv")), "the constant intros of a failed scan were cached")

    local command = "/usr/bin/clang -ast-dump fixture"
    expect(failure_of(function () facts.checked_dump(command, umbrella, nil, nil) end), "an AST dump that could not be read",
           {"exited with status 0", "unreadable", umbrella, command})
    expect(failure_of(function () facts.checked_dump(command, umbrella, "", "the pipe broke\n") end), "an empty AST dump",
           {"exited with status 0", "empty", "stderr: the pipe broke", umbrella, command})
    assert(facts.checked_dump(command, umbrella, "TranslationUnitDecl", "") == "TranslationUnitDecl", "an AST dump with content was not returned")

    os.tryrm(cache)
    os.tryrm(sdk)
    print("FACTS_ERROR_TEST passed")
end
