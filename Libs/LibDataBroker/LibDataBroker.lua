-- LibDataBroker-1.1
-- A minimal data broker implementation for WoW addons
-- Based on the LibDataBroker-1.1 specification

local MAJOR, MINOR = "LibDataBroker-1.1", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.dataObjects = lib.dataObjects or {}

local function ValidateDataObject(dataObj)
    assert(type(dataObj) == "table", "Data object must be a table")
    assert(type(dataObj.type) == "string", "Data object must have a type field")
    -- type can be: launcher, data source, etc.
    return true
end

function lib:NewDataObject(name, dataObj)
    assert(type(name) == "string", "Name must be a string")
    assert(not lib.dataObjects[name], "Data object already exists: " .. name)
    ValidateDataObject(dataObj)
    lib.dataObjects[name] = dataObj
    lib.callbacks:Fire("LibDataBroker_DataObjectCreated", name, dataObj)
    return dataObj
end

function lib:GetDataObject(name)
    return lib.dataObjects[name]
end

function lib:GetDataObjectList()
    local list = {}
    for name in pairs(lib.dataObjects) do
        table.insert(list, name)
    end
    return list
end

function lib:GetDataObjectByField(field, value)
    for name, obj in pairs(lib.dataObjects) do
        if obj[field] == value then
            return obj, name
        end
    end
    return nil
end

return lib