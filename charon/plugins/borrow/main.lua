import("core.base.option")
import("@self.store")

function main()
    local names = option.get("packages")
    if not names or #names == 0 then
        raise("xmake borrow takes the packages to bring over: xmake borrow llvm swift")
    end
    local given = option.get("from")
    local source = given and store.root(given) or store.canonical()
    local target = store.root()
    if source == target then
        raise("%s is this store itself; a store has nothing to take from itself, so name another with --from, or run this where XMAKE_GLOBALDIR points at the store that needs them", source)
    end
    if not os.isdir(source) then
        raise("%s is no store: xmake keeps what it installs in a .xmake beside a home or beside what XMAKE_GLOBALDIR names", source)
    end
    local planned = store.borrowed(source, target, names)
    for _, name in ipairs(names) do
        if #store.installs(source, name) == 0 then
            raise("%s holds no install of %s to take: a store holds what xmake built for it, and never what the machine provides of itself", source, name)
        end
    end
    if #planned == 0 then
        cprint("${dim}this store already holds every install of %s that %s has", table.concat(names, ", "), source)
        return
    end
    for _, entry in ipairs(planned) do
        cprint("${bright green}%s${clear} %s from %s", store.bring(entry), entry.at, source)
    end
end
