local PlayerData = nil
local ESX = nil
local Plants = {
    --[[
    [123123] = {
        age = 1,
        type = "patata",
        progress = 0,
        id = 1
    }
    ]]
}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end

	PlayerData = ESX.GetPlayerData()
    SpawnSavedPlants()
end)

-- On start
function SpawnSavedPlants()
    --This trigger return all plants on the world.
    ESX.TriggerServerCallback("esx_plants:GetPlants", function(plants)
        for i=1, #plants do
            local data = json.decode(plants[i].data) --get the db column that contains data of plants ()
            local modelHash = GetHashKey(Config.Plants[data.type].states[data.progress]) --get modelhash using a the db results
            _CreateObject(data.type, data.progress, plants[i].id, modelHash, vector3(data.coords.x, data.coords.y, data.coords.z))
            --print("Creating object "..modelHash, data.coords.x, data.coords.y, data.coords.z)         
            --SetEntityAsMissionEntity(obj)
           -- SetModelAsNoLongerNeeded(modelHash)
        end
    end)
end

-- Seed
RegisterNetEvent("esx_plants:CreatePlant_c")
AddEventHandler("esx_plants:CreatePlant_c", function(type)
	
    local ped = PlayerPedId()
    local hashGroung = GetGroundHash(ped)
    print("hashGroung - ", hashGroung)


    local okGround = false
    for k,v in pairs(Config.Material) do
        print("v - ", v)

        if v == hashGroung then
            okGround = true
            break
        end
    end

    if okGround then

        TaskStartScenarioInPlace(PlayerPedId(), "world_human_gardener_plant", 0, true)
        Citizen.Wait(10000)
        ClearPedTasks(PlayerPedId())
        Citizen.Wait(1500)

        print(type, 1, GetHashKey(Config.Plants[type].states[1]), GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0))
        local obj = _CreateObject(type, 1, 0, GetHashKey(Config.Plants[type].states[1]), GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0))

        --SetEntityAsMissionEntity(obj)
        --PlaceObjectOnGroundProperly(obj)
        local id = CreatePlant(type, GetEntityCoords(obj))

        while id == nil do
            Citizen.Wait(50)
        end
        
        Plants[obj].id = id
    else
        ESX.ShowNotification("Il terreno non è adatto!")
    end
end)

--this is used for insert plant on the db
function CreatePlant(type, coords)
    local _cb = nil
    ESX.TriggerServerCallback("esx_plants:CreatePlant", function(id) 
        _cb = id
    end, type, coords)

    while _cb == nil do
        Citizen.Wait(30)
    end
    return _cb
end

--Phisically creating the object(entity)
function _CreateObject(type, progress, id, hash, coords)
    RequestModel(hash);
    while not HasModelLoaded(hash) do Citizen.Wait(5); end  

    --obj = entity
    local obj = CreateObject(hash, coords, true)
    --Add plant on local table
    Plants[obj] = {
        age = 0,
        type = type,
        progress = progress,
        id = id
    }
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(obj)
    PlaceObjectOnGroundProperly(obj)
    return obj
end

--Called when the plant change state of progress
function GrowPlant(entity, type, id, new_state)
    local coords = GetEntityCoords(entity) --get the coords of entity to create the new in the same place
    Plants[entity] = {} --remove entity from local table
    
    DeleteEntity(entity) --delete the entity
    _CreateObject(type, new_state, id, GetHashKey(Config.Plants[type].states[new_state]), coords) --create new entity
    TriggerServerEvent("esx_plants:UpdatePlant", id, type, coords, new_state) --used for update the state of plant on db
end


Citizen.CreateThread(function()
    while true do
       -- print(json.encode(Plants))
        for k,v in pairs(Plants) do
            if json.encode(v) ~= "[]" then --Used for prevent the access at nil value. problem caused by async call (del / create entity)
                -- k = entity
                -- v = data
                if v.age >= Config.Plants[v.type].age then --OKKIO cambiato da == a >= sicurezza, non necessario ma mutanda di latta
                    print("Last age ", v.age)
                    -- On end
                    if v.progress >= #Config.Plants[v.type].states then
                        
                    else -- Grow
                        print("Growing")
                        v.age = 0
                        GrowPlant(k, v.type, v.id, v.progress + 1)
                    end
                else
                    v.age = v.age + 1
                    print("Growing age ", v.age)
                end

            end
        end
        Citizen.Wait(1000)
    end
end)

--this is necessary to the interact 
Citizen.CreateThread(function()
    while true do
        local founded = false

        for k,v in pairs(Plants) do
            if json.encode(v) ~= "[]" then
                if v.progress == #Config.Plants[v.type].states then
                    founded = true
                    local distance = GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), GetEntityCoords(k), true)

                    if distance < 3.0 then
                        DrawText3Ds(GetEntityCoords(k), "Premi [~g~E~w~] per raccogliere la pianta", 0.35)

                        if IsControlJustPressed(0, 38) then
                            print("Dropping")
                            Plants[k] = {}

                            SetEntityAsMissionEntity(k)
                            DeleteEntity(k)
                            TriggerServerEvent("esx_plants:DropItem", v.type, v.id)
                        end
                    end
                end
            end
        end

        if not founded then
            Citizen.Wait(2000)
        end
        Citizen.Wait(5)
    end
end)

RegisterCommand("dioPlant", function()
    local obj = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 150.0, GetHashKey("prop_weed_01"))
    local obj2 = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 150.0, GetHashKey("prop_weed_02"))
    local obj3 = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 150.0, GetHashKey("bkr_prop_weed_lrg_01b"))

    SetEntityAsMissionEntity(obj)
    DeleteEntity(obj)

    SetEntityAsMissionEntity(obj2)
    DeleteEntity(obj2)

    SetEntityAsMissionEntity(obj3)
    DeleteEntity(obj3)
end)


function GetGroundHash(ped)
    local posped = GetEntityCoords(ped)
    local num = StartShapeTestCapsule(posped.x,posped.y,posped.z+4,posped.x,posped.y,posped.z-2.0, 2, 1, ped, 7)
    local arg1, arg2, arg3, arg4, arg5 = GetShapeTestResultEx(num)
    return arg5
end


DrawText3Ds = function(coords, text, scale)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextEntry("STRING")
        SetTextCentre(1)

        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end
