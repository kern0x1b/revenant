function backports_package_required(component, selected)
    if (selected or "") ~= "" then
        return false
    end
    return (component or "") ~= "Backports"
end
