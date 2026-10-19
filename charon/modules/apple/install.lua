function prune(package, patterns)
    for _, pattern in ipairs(table.wrap(patterns)) do
        for _, found in ipairs(os.filedirs(path.join(package:installdir(), pattern))) do
            os.tryrm(found)
        end
    end
end

function licenses(package, files, opt)
    opt = opt or {}
    for _, file in ipairs(table.wrap(files)) do
        local source = path.absolute(file, opt.sourcedir or os.curdir())
        if not os.isfile(source) then
            raise("%s names license file %s, and there is no such file", package:name(), file)
        end
        os.vcp(source, package:installdir("licenses") .. "/")
    end
end

function finish(package, opt)
    prune(package, opt.prune)
    licenses(package, opt.licenses, opt)
    if package:is_plat("iphoneos") and opt.verify ~= false then
        import("platform").verify_installed(package)
    end
end
