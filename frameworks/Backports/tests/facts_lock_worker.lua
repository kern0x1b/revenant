local generate = import("generate", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

function main(sdk, version, logs, ...)
    generate.ready(sdk, version, logs, {...})
end
