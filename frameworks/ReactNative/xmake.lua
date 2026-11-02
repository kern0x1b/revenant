if get_config("component") ~= "" and get_config("component") ~= "ReactNative" then
    return
end

target("react-native-inputs")
    set_kind("phony")
    set_default(false)
    add_tests("inputs")
    on_test(function (target, opt)
        local root = os.projectdir()
        local ok = os.execv(os.programfile(), {"l", "-P", root, path.join(os.scriptdir(), "tests", "inputs.lua")}, {try = true, curdir = root})
        if ok ~= 0 then
            opt.errors = "react-native-inputs failed"
        end
        return ok == 0
    end)
target_end()
