local root = path.absolute(path.directory(path.directory(os.scriptdir())))

function main()
    local text = io.readfile(path.join(root, "toolchain", "tests", "xmake.lua"))
    local list = text:match("local light = {(.-)}")
    if not list then
        raise("toolchain/tests/xmake.lua declares no light suites")
    end
    local addon = path.join(root, "toolchain", "tests", "addon")
    local arguments = {modules = path.join(root, "toolchain", "modules")}
    local failed, count = 0, 0
    for suite in list:gmatch('"([^"]+)"') do
        local failures = {}
        try {
            function ()
                failures = import(suite, {rootdir = addon, anonymous = true}).failures(arguments)
            end,
            catch {
                function (raised)
                    failures = {"the suite raised an error: " .. tostring(raised)}
                end
            }
        }
        count = count + 1
        for _, failure in ipairs(failures) do
            failed = failed + 1
            print("%s: %s", suite, failure)
        end
    end
    if failed > 0 then
        raise("%d failures in %d light suites", failed, count)
    end
    print("light suites: %d passed", count)
end
