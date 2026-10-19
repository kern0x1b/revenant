rule("check")
    on_load(function (target)
        target:set("kind", "phony")
        target:set("default", false)
        if not target:values("check.command") and not target:values("check.script") then
            raise("target(%s) is a check without set_values(\"check.script\", SCRIPT, ARGUMENTS...) or check.command", target:name())
        end
    end)
