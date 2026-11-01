rule("rn-codegen")
    on_config(function (target)
        import("core.project.project")
        import("core.base.json")
        local node_package = project.required_package("node")
        local tool_package = project.required_package("react-native-codegen")
        local library_package = project.required_package(target:values("rn.codegen.library"))
        local node_root = node_package and node_package:installdir()
        local tool = tool_package and tool_package:installdir()
        local library = library_package and library_package:installdir()
        if not (node_root and tool and library) then
            return
        end
        local manifest = json.decode(io.readfile(path.join(library, "package.json")))
        local specs = path.join(library, manifest.codegenConfig.jsSrcsDir)
        local inputs = {node_root, tool, library, hash.sha256(path.join(library, "package.json"))}
        for _, file in ipairs(table.join(os.files(path.join(specs, "*")), os.files(path.join(specs, "**")))) do
            table.insert(inputs, file .. " " .. hash.sha256(file))
        end
        local folder = path.join(target:autogendir(), "rn-codegen")
        os.mkdir(target:autogendir())
        local listing = path.join(target:autogendir(), "rn-codegen-inputs.txt")
        io.writefile(listing, table.concat(inputs, "\n"))
        local digest = hash.sha256(listing)
        local output = path.join(folder, digest)
        if not (os.isfile(path.join(output, "digest.txt")) and io.readfile(path.join(output, "digest.txt")) == digest) then
            os.rm(folder)
            local runtime = path.join(output, "runtime")
            os.mkdir(runtime)
            os.vcp(path.join(tool, "*"), runtime .. "/")
            local app = path.join(output, "app")
            os.mkdir(path.join(app, "node_modules"))
            io.writefile(path.join(app, "package.json"), json.encode({name = "app", private = true,
                dependencies = {[manifest.name] = manifest.version, ["react-native"] = "0.86.3"}}))
            os.ln(library, path.join(app, "node_modules", manifest.name))
            os.ln(path.join(runtime, "react-native"), path.join(app, "node_modules", "react-native"))
            os.vrunv(path.join(node_root, "bin", "node"), {path.join(runtime, "react-native", "scripts", "generate-codegen-artifacts.js"),
                     "-p", app, "-t", "ios", "-o", path.join(output, "out"), "-s", "app"})
            io.writefile(path.join(output, "digest.txt"), digest)
        end
        local headers = path.join(output, "out", "build", "generated", "ios", "ReactCodegen")
        target:data_set("rn.codegen.output", headers)
        target:add("includedirs", headers)
    end)
