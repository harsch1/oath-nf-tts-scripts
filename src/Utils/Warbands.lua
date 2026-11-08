-- ==============================
-- WARBANDS
--
-- Shared by the warband trays and the storage boxes. A warband's
-- color is its memo. What a color's warbands look like, and how
-- many it has, is the "warband" entry in the memo of that color's
-- storage box (Purple: the Chancellor Archive's), e.g.
--   "warband": {"diffuse": "<art URL>", "specular": 0.025, "count": 14}
-- Only diffuse is needed; the rest default to WARBAND_DEFAULTS.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")

WARBAND_DEFAULTS = {
    mesh = "https://steamusercontent-a.akamaihd.net/ugc/28813714123459538/D5ACDDA8E85F34D00FE0657E58B9043B80DDC780/",
    specular = 0,
    count = 14,
}

-- The color of a warband (nil if object isn't a warband, or has no color in its memo)
function GetWarbandObjectColor(object)
    if object == nil or object.isDestroyed() or not object.hasTag(tags.warband) then
        return nil
    end
    local color = trim(object.memo)
    return color ~= "" and color or nil
end

-- The object whose memo describes colorName's warbands: its storage box, or the Chancellor Archive for Purple
local function warbandMemoHolder(colorName)
    if colorName == "Purple" then
        return getObjectFromGUID(GUIDs.playerArchives.Purple)
    end
    for _, box in ipairs(getObjectsWithTag("warbandReturn")) do
        local success, memo = pcall(JSON.decode, box.memo or "")
        if success and type(memo) == "table" and memo.color == colorName then
            return box
        end
    end
    return nil
end

-- What colorName's warbands look like and how many it has ({diffuse, mesh, specular, count}), or nil if the memo
-- holding it can't be found (a storage box is out of reach while it's stored in its archive)
function GetWarbandLook(colorName)
    local holder = warbandMemoHolder(colorName)
    local success, memo = pcall(JSON.decode, holder and holder.memo or "")
    if not success or type(memo) ~= "table" or type(memo.warband) ~= "table" or not memo.warband.diffuse then
        return nil
    end
    local look = {}
    for key, value in pairs(WARBAND_DEFAULTS) do
        look[key] = value
    end
    for key, value in pairs(memo.warband) do
        look[key] = value
    end
    return look
end

-- How close (horizontally) a warband must be to a snap point to count as filling it
local SNAP_RADIUS = 0.3

-- How high above its snap point a warband is set down, so it drops onto it
local DROP_HEIGHT = 0.5

-- Seconds a spot NextWarbandSpot handed out stays taken, while its warband glides there
local SPOT_RESERVE_SECONDS = 2

-- The spots NextWarbandSpot handed out lately: {position, time}
local reservedSpots = {}

-- Whether a spot was handed out within the last SPOT_RESERVE_SECONDS
local function isReserved(spot)
    for _, reserved in ipairs(reservedSpots) do
        if Time.time - reserved.time < SPOT_RESERVE_SECONDS
            and (reserved.position.x - spot.x) ^ 2 + (reserved.position.z - spot.z) ^ 2 <= SNAP_RADIUS ^ 2 then
            return true
        end
    end
    return false
end

-- mat's Warband snap points in the world, in the order warbands are set out on them: left to right along the top row,
-- then the next (from the player's seat)
local function warbandSpots(mat)
    local snaps = {}
    for _, snap in ipairs(mat.getSnapPoints() or {}) do
        for _, tag in ipairs(snap.tags or {}) do
            if tag:lower() == tags.warband:lower() then
                table.insert(snaps, snap.position)
                break
            end
        end
    end
    -- In the mat's own axes the far row has the lower z, and the player's left is +x
    table.sort(snaps, function(a, b)
        if math.abs(a.z - b.z) > 0.01 then
            return a.z < b.z
        end
        return a.x > b.x
    end)
    local spots = {}
    for _, snap in ipairs(snaps) do
        table.insert(spots, mat.positionToWorld(snap))
    end
    return spots
end

-- The warband sitting on a spot (and of color, if given), or nil
local function warbandOn(spot, color)
    for _, warband in ipairs(getObjectsWithTag(tags.warband)) do
        local position = warband.getPosition()
        if (position.x - spot.x) ^ 2 + (position.z - spot.z) ^ 2 <= SNAP_RADIUS ^ 2
            and (color == nil or GetWarbandObjectColor(warband) == color) then
            return warband
        end
    end
    return nil
end

-- Where the next warband set out on mat goes: just above the first free Warband snap point (in warbandSpots order).
-- nil if they're all taken. A spot handed out stays taken for a moment, so a warband still gliding to it isn't sent
-- another to join it.
function NextWarbandSpot(mat)
    for _, spot in ipairs(warbandSpots(mat)) do
        if not warbandOn(spot) and not isReserved(spot) then
            table.insert(reservedSpots, {position = spot, time = Time.time})
            return spot + Vector(0, DROP_HEIGHT, 0)
        end
    end
    return nil
end

-- The color warband set out last on mat's Warband snap points (the last filled spot, in warbandSpots order), or nil
function LastWarbandOnSpots(mat, color)
    local spots = warbandSpots(mat)
    for i = #spots, 1, -1 do
        local warband = warbandOn(spots[i], color)
        if warband then
            return warband
        end
    end
    return nil
end

-- Whether a container entry (from getObjects()) has a tag; case-insensitive, like hasTag on objects out on the table
function BagEntryHasTag(entry, wantedTag)
    if not entry or not entry.tags then
        return false
    end
    for _, tag in ipairs(entry.tags) do
        if tag:lower() == wantedTag:lower() then
            return true
        end
    end
    return false
end
