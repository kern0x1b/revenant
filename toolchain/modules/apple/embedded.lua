local EMBEDDABLE = {"swift-runtime", "swift-crypto", "cryptokit", "uniformtypeidentifiers"}

function libraries(all, aliases)
    for _, alias in ipairs(aliases) do
        if not table.contains(EMBEDDABLE, alias) then
            raise("revenant.embed names %s, and only %s can be carried by an application", alias, table.concat(EMBEDDABLE, ", "))
        end
    end
    local embedded, taken = {}, {}
    for _, package in ipairs(all) do
        if table.contains(aliases, package.alias) then
            taken[package.name] = true
            for _, file in ipairs(os.files(path.join(package.root, "usr", "lib", "revenant", package.name, "*.dylib"))) do
                table.insert(embedded, {name = path.filename(file), source = file, package = package.alias})
            end
        end
    end
    for _, package in ipairs(all) do
        if not taken[package.name] and package.needs and taken[package.needs] then
            raise("revenant.embed carries %s, and %s stays on the device and is linked against it: carry both, or a process loads two copies", package.needs, package.name)
        end
    end
    return embedded, taken
end
