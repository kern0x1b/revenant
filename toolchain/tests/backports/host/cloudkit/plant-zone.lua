local PLANT = "int RevenantPlantMarker = 1;\n\n- (NSInteger)capabilities { return 7; }\n\n"

function main(file)
    local text = io.readfile(file, {encoding = "binary"})
    local zone = text:find("@implementation CKRecordZone {", 1, true)
    if not zone then
        raise("%s has no @implementation CKRecordZone to plant in", file)
    end
    local at = text:find("- (BOOL)isEqual:(id)other", zone, true)
    if not at then
        raise("%s has no isEqual: inside CKRecordZone to plant before", file)
    end
    io.writefile(file, text:sub(1, at - 1) .. PLANT .. text:sub(at), {encoding = "binary"})
end
