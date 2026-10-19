local TRACE_INHERITED = {init = true, new = true, copy = true, mutableCopy = true}

local SCOPE_IMPLICIT = {init = true, new = true, copy = true, mutableCopy = true, dealloc = true, description = true}

function unavailable_reason(release)
    return "init/new the " .. release .. " headers declare unavailable: no override, NSObject's behaviour is what a call reaches"
end

function unavailable_state(release)
    return "init/new: not spelled by the " .. release .. " headers (implicit, or unavailable by a macro)"
end

function trace_inherited(selector)
    return TRACE_INHERITED[selector] == true
end

function declared_unavailable(availability)
    for flag in string.gmatch(availability or "", "%S+") do
        if flag == "*unavailable" then
            return true
        end
    end
    return false
end

function scope_implicit(selector)
    return SCOPE_IMPLICIT[selector] == true
end
