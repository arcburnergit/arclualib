mods.arcutil = {}
local INT_MAX = 2147483647

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

-- Get a table for a userdata value by name
function mods.arcutil.userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

function mods.arcutil.get_random_point_in_radius(center, radius)
    r = radius * math.sqrt(math.random())
    theta = math.random() * 2 * math.pi
    return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

function mods.arcutil.get_point_local_offset(original, target, offsetForwards, offsetRight)
    local alpha = math.atan((original.y-target.y), (original.x-target.x))
    --print(alpha)
    local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
    --print(newX)
    local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
    --print(newY)
    return Hyperspace.Pointf(newX, newY)
end

function mods.arcutil.vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end
local vter = mods.arcutil.vter

-- Find ID of a room at the given location
function mods.arcutil.get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
function mods.arcutil.get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

function mods.arcutil.get_ship_crew_room(shipManager, roomId)
    local radCrewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(radCrewList, crewmem)
        end
    end
    return radCrewList
end

-- written by kokoro
function mods.arcutil.convertMousePositionToEnemyShipPosition(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local position = 0--combatControl.position -- not exposed yet
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
function mods.arcutil.get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

function mods.arcutil.get_distance(point1, point2)
    return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end

-- Copy a table recursively
--[[ taken from
https://stackoverflow.com/questions/42178768/lua-copying-a-table-efficiently-deep-copy#answer-45867020
https://gist.github.com/cpeosphoros/0aa286c6b39c1e452d9aa15d7537ac95
--]]
function mods.arcutil.table_copy_deep(value, cache, promises, copies)
    cache    = cache    or {}
    promises = promises or {}
    copies   = copies   or {}
    local copy
    if type(value) == 'table' then
        if (cache[value]) then
            copy = cache[value]
        else
            promises[value] = promises[value] or {}
            copy = {}
            for k, v in next, value, nil do
                local nKey   = promises[k] or mods.vertexutil.table_copy_deep(k, cache, promises, copies)
                local nValue = promises[v] or mods.vertexutil.table_copy_deep(v, cache, promises, copies)
                copies[nKey]   = type(k) == "table" and k or nil
                copies[nValue] = type(v) == "table" and v or nil
                copy[nKey] = nValue
            end
            local mt = getmetatable(value)
            if mt then
                setmetatable(copy, mt.__immutable and mt or mods.vertexutil.table_copy_deep(mt, cache, promises, copies))
            end
            cache[value]    = copy
        end
    else -- number, string, boolean, etc
        copy = value
    end
    for k, v in pairs(copies) do
        if k == cache[v] then
            copies[k] = nil
        end
    end
    local function correctRec(tbl)
        if type(tbl) ~= "table" then return tbl end
        if copies[tbl] and cache[copies[tbl]] then
            return cache[copies[tbl]]
        end
        local new = {}
        for k, v in pairs(tbl) do
            local oldK = k
            k, v = correctRec(k), correctRec(v)
            if k ~= oldK then
                tbl[oldK] = nil
                new[k] = v
            else
                tbl[k] = v
            end
        end
        for k, v in pairs(new) do
            tbl[k] = v
        end
        return tbl
    end
    correctRec(copy)
    return copy
end

-- Check if a given crew member is being mind controlled by a ship system
function mods.arcutil.under_mind_system(crewmem)
    local controlledCrew = nil
    local otherShipId = (crewmem.iShipId + 1)%2
    pcall(function() controlledCrew = Hyperspace.Global.GetInstance():GetShipManager(otherShipId).mindSystem.controlledCrew end)
    if controlledCrew then
        for crew in vter(controlledCrew) do
            if crewmem == crew then
                return true
            end
        end
    end
    return false
end

-- Check if a given crew member is resistant to mind control
function mods.arcutil.resists_mind_control(crewmem)
    do
        local _, telepathic = crewmem.extend:CalculateStat(Hyperspace.CrewStat.IS_TELEPATHIC)
        if telepathic then return true end
    end
    do
        local _, resistMc = crewmem.extend:CalculateStat(Hyperspace.CrewStat.RESISTS_MIND_CONTROL)
        if resistMc then return true end
    end
    return false
end

-- Check if a given crew member can be mind controlled
function mods.arcutil.can_be_mind_controlled(crewmem)
    return not (crewmem:IsDrone() or resists_mind_control(crewmem) or under_mind_system(crewmem))
end

-- Check if a weapon's current shot is its first
function mods.arcutil.is_first_shot(weapon, afterFirstShot)
    local shots = weapon.numShots
    if weapon.weaponVisual.iChargeLevels > 0 then shots = shots*(weapon.weaponVisual.boostLevel + 1) end
    if weapon.blueprint.miniProjectiles:size() > 0 then shots = shots*weapon.blueprint.miniProjectiles:size() end
    if afterFirstShot then shots = shots - 1 end
    return shots == weapon.queuedProjectiles:size()
end

local RandomList = {
    New = function(self, table)
        table = table or {}
        self.__index = self
        setmetatable(table, self)
        return table
    end,

    GetItem = function(self)
        local index = Hyperspace.random32() % #self + 1
        return self[index]
    end,
}

local userdata_table = mods.arcutil.userdata_table
local get_random_point_in_radius = mods.arcutil.get_random_point_in_radius
local get_point_local_offset = mods.arcutil.get_point_local_offset

local vter = mods.arcutil.vter
local get_room_at_location = mods.arcutil.get_room_at_location
local get_ship_crew_point = mods.arcutil.get_ship_crew_point
local get_ship_crew_room = mods.arcutil.get_ship_crew_room

local convertMousePositionToEnemyShipPosition = mods.arcutil.convertMousePositionToEnemyShipPosition

local get_adjacent_rooms = mods.arcutil.get_adjacent_rooms
local get_distance = mods.arcutil.get_distance

local table_copy_deep = mods.arcutil.table_copy_deep

local vter = mods.arcutil.under_mind_system
local vter = mods.arcutil.resists_mind_control
local vter = mods.arcutil.can_be_mind_controlled

local vter = mods.arcutil.is_first_shot

-------------------------
-- UNIVERSAL FUNCTIONS --
-------------------------

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    local teleTable = userdata_table(crewmem, "mods.arc.crewAbduction")
    if teleTable.tpTime then
        if crewmem.bDead then
            teleTable.tpTime = nil
        else
            local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
            if not commandGui.bPaused then 
                teleTable.tpTime = math.max(teleTable.tpTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if teleTable.tpTime == 0 then
                    if crewmem.intruder == true then
                        crewmem.extend:InitiateTeleport(crewmem.iShipId,0,0)
                    end
                    teleTable.tpTime = nil
                end
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local hullData = userdata_table(shipManager, "mods.arc.hullData")
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0   then
        hullData.tempHp = math.floor(shipManager:GetAugmentationValue("ARC_SUPER_HULL"))
    else
        hullData.tempHp = nil
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    --log(beamHitType)
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0 and beamHitType == 2 then
       local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - damage.iDamage
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end 
    return Defines.Chain.CONTINUE, beamHitType
end) 

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0 then
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - damage.iDamage
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end
end)

local xPos = 380
local yPos = 47
local xText = 413
local yText = 58
local tempHpImage = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/arc_tempHull.png",
    xPos,
    yPos,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then
            local hullHP = math.floor(hullData.tempHp)
            Graphics.CSurface.GL_RenderPrimitive(tempHpImage)
            Graphics.freetype.easy_print(0, xText, yText, hullHP)
        end
    end
end, function() end)
