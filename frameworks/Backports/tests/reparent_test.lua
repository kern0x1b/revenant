local backports = path.absolute(path.join(os.scriptdir(), ".."))

local function source(relative)
    return io.readfile(path.join(backports, relative))
end

local function contains(text, needle, label)
    assert(text:find(needle, 1, true), label .. " does not contain " .. needle)
end

local function absent(text, needle, label)
    assert(not text:find(needle, 1, true), label .. " still contains " .. needle)
end

function main()
    local attach = source("src/attach.c")
    contains(attach, "class_setSuperclass(proxy, release)", "the alias reparent in attach.c")
    contains(attach, "class_setSuperclass(proxy, superclass)", "the alias reparent rollback in attach.c")
    contains(attach, "revenant_has_ivars(proxy)", "the alias reparent guard in attach.c")
    contains(attach, "class_copyIvarList(cls, &count)", "the instance variable check in attach.c")
    absent(attach, "words[1]", "the alias reparent in attach.c")
    absent(attach, "meta[1]", "the alias reparent in attach.c")

    local alias = source("src/revenant_alias.h")
    contains(alias, "+ (void)load", "the alias class macro, which makes every alias non-lazy and realized before attach.c runs")
    contains(alias, "== REVENANT_ALIAS_SELF(Name) ? class_getSuperclass(found) : found", "the alias superclass answer, which skips the proxy so a class that +load registered under the alias name does not answer itself")
    absent(alias, "== REVENANT_ALIAS_SELF(Name) ? REVENANT_ALIAS_RELEASE(Name) : found", "the alias superclass answer")
end
