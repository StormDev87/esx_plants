ESX = nil 
TriggerEvent("esx:getSharedObject", function(obj)
    ESX = obj
end)

ESX.RegisterServerCallback("esx_plants:GetPlants", function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM plants', {}, function(result)
        cb(result)
    end)
end)


ESX.RegisterServerCallback("esx_plants:CreatePlant", function(source, cb, type, coords)
    local xPlayer = ESX.GetPlayerFromId(source)

    print("inserted plant ", type, coords)
    MySQL.Async.execute('INSERT INTO plants (owner, data) VALUES (@owner, @data)', {
        ['@owner'] = xPlayer.identifier,
        ['@data']  = json.encode({coords = coords,type = type,progress = 1}),
    })
    
    Citizen.Wait(500)

    MySQL.Async.fetchAll('SELECT max(id) FROM plants', {}, function(result)
        --print("Select = "..json.encode(result), result[1]["max(id)"])
        cb(result[1]["max(id)"])
    end)
end)

RegisterServerEvent("esx_plants:UpdatePlant")
AddEventHandler("esx_plants:UpdatePlant", function(id, type, coords, new_state)
    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.Async.execute('UPDATE plants SET data=@data WHERE id=@id', {
        ['@id']    = id,
        ['@data']  = json.encode({coords = coords,type = type,progress = new_state}),
    })
end)

RegisterServerEvent("esx_plants:DropItem")
AddEventHandler("esx_plants:DropItem", function(type, id)
    local xPlayer = ESX.GetPlayerFromId(source)

    for k,v in pairs(Config.Plants[type].drop) do
        xPlayer.addInventoryItem(k, v)
    end

    MySQL.Async.execute('DELETE FROM plants WHERE id=@id', {
        ["@id"] = id
    }, function(rowsChanged) end)
end)


AddEventHandler('onResourceStart',function(resName)
    if resName == GetCurrentResourceName() then
        for k,v in pairs(Config.Plants) do
            ESX.RegisterUsableItem(k, function(source)
                TriggerClientEvent("esx_plants:CreatePlant_c", source, k)
            end)  
        end
    end
end)