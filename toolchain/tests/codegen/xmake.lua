add_requires("revenant@node 26.13.0", {alias = "node"})
add_requires("revenant@react-native-codegen 0.86.3", {alias = "react-native-codegen"})
add_requires("revenant@react-native-screens 4.26.2", {alias = "react-native-screens"})

target("rnscreens-codegen")
    set_kind("phony")
    set_default(false)
    add_packages("node", "react-native-codegen", "react-native-screens")
    add_rules("@addon/revenant/rn-codegen")
    set_values("rn.codegen.library", "react-native-screens")
target_end()

target("codegen")
    set_kind("phony")
    set_default(false)
    add_packages("node", "react-native-codegen", "react-native-screens")
    add_tests("rnscreens_headers")
    on_test(function (target, opt)
        local output = import("core.project.project").target("rnscreens-codegen"):data("rn.codegen.output")
        local missing = {}
        for _, header in ipairs({"Props.h", "EventEmitters.h", "ComponentDescriptors.h", "RCTComponentViewHelpers.h"}) do
            local file = path.join(output, "react", "renderer", "components", "rnscreens", header)
            if not os.isfile(file) then
                table.insert(missing, file)
            end
        end
        if #missing > 0 then
            opt.errors = "the codegen of react-native-screens did not write " .. table.concat(missing, ", ")
            return false
        end
        return true
    end)
target_end()
