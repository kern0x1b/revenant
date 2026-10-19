import("core.base.json")

function main(file, what)
    local document = json.decode(io.readfile(file))
    if what == "runner" then
        print(document.output == 1 and "tree" or "installed")
    else
        local value = document[what]
        if type(value) == "number" and value == math.floor(value) then
            value = string.format("%d", value)
        end
        print(value == nil and "" or tostring(value))
    end
end
