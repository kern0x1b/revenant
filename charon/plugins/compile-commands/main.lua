import("core.base.option")
import("core.base.task")
import("core.base.json")
import("core.project.project")
import("core.tool.compiler")

function main()
    task.run("config", {}, {disable_dump = true})
    local wanted = option.get("targets")
    local entries = {}
    for _, target in ipairs(project.ordertargets()) do
        if not wanted or table.contains(wanted, target:name()) then
            for _, sourcebatch in table.orderpairs(target:sourcebatches()) do
                local sourcekind = sourcebatch.sourcekind
                if sourcekind and sourcebatch.objectfiles then
                    for index, sourcefile in ipairs(sourcebatch.sourcefiles) do
                        local objectfile = sourcebatch.objectfiles[index]
                        local argv = table.join(compiler.compargv(sourcefile, objectfile, {target = target, sourcekind = sourcekind, rawargs = true}))
                        table.insert(entries, {directory = os.projectdir(), file = path.absolute(sourcefile, os.projectdir()), arguments = argv})
                    end
                end
            end
        end
    end
    if wanted and #entries == 0 then
        raise("no source of %s", table.concat(wanted, ", "))
    end
    local output = path.absolute(option.get("output"), os.projectdir())
    json.savefile(output, entries)
    cprint("${bright green}%d commands${clear} %s", #entries, output)
end
