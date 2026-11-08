
require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")
require("src/Utils/Warbands")

-- The labels, top to bottom. Clicking one does nothing.
local LABELS = {"0", "0", "0"}

-- In world units: the gap from the mat's top and right edges to the top label's edges, and between labels
local LABEL_TOP_MARGIN = -0.5
local LABEL_RIGHT_MARGIN = 2.1
local LABEL_GAP = 3.33+0.5

local LABEL_FONT_SIZE = 400

-- Roughly a label's size in world units at the sizes above, for keeping it off the mat's edges


-- How far (world units) the scripting zone reaches above the mat's bounding box
local ZONE_HEADROOM = 4.3

-- Name each mat's scripting zone starts with (one sits over every mat in the save). Zones are found by name, not
-- tag: a tagged zone only notices objects sharing one of its tags.
local ZONE_NAME = "Player Mat Zone"

-- Seconds to wait for a dropped mat to settle before refitting its zone wherever it is
local SETTLE_TIMEOUT = 1

-- Which label (button index) shows each count
local SECRET_LABEL = 0
local FAVOR_LABEL = 1
local WARBAND_LABEL = 2

-- Frames to wait after something enters or leaves the zone before counting, so stacks have finished merging
local COUNT_DELAY = 5

-- This mat's scripting zone, found on load
local zone = nil

-- Whether a count is already waiting to run
local countScheduled = false

function onLoad()
    CreateLabels()
    zone = FindZone()
    if zone then
        zone = GiveZoneNotifier(zone, self)
        FitZone()
        ScheduleCount()
    else
        print(self.getName() .. " " .. self.getGUID() .. " has no \"" .. ZONE_NAME .. "\" zone over it.")
    end
end

-- When this mat is put down somewhere else, its zone follows it once it settles
function onDrop()
    if not zone or zone.isDestroyed() then
        return
    end
    Wait.condition(FitZone, function()
        return self.resting
    end, SETTLE_TIMEOUT, FitZone)
end

-- ==============================
-- PUBLIC API
-- ==============================

-- This mat's scripting zone (nil if it has none)
function GetZone()
    return zone
end

-- ==============================
-- LABELS
-- ==============================

-- Clicking a label does nothing
function IgnoreClick()
end

-- Adds each label that isn't on the mat already
function CreateLabels()
    local existing = {}
    for _, button in ipairs(self.getButtons() or {}) do
        existing[button.label] = true
    end
    local scale = self.getScale()
    for i, label in ipairs(LABELS) do
        if not existing[label] then
            -- In world units from the top right corner, then into the mat's own units. The mat's top edge is its
            -- -z, and the seat's right is its -x (+x for a button, as button positions have x flipped).
            local fromRight = LABEL_RIGHT_MARGIN + (i - 1) * (LABEL_GAP)
            local fromTop = LABEL_TOP_MARGIN
            self.createButton({
                click_function = "IgnoreClick",
                function_owner = self,
                label = label,
                position = {2.215 - fromRight / scale.x, 0.1, -1.575 + fromTop / scale.z},
                -- turned to read the right way up from the seat (the mat's top edge is its -z)
                rotation = {0, 0, 0},
                scale = {1 / scale.x, 1, 1 / scale.z},
                width = 0,
                height = 0,
                font_size = LABEL_FONT_SIZE,
                color = {0, 0, 0, 1},
                font_color = {1,1,1,1},
            })
        end
    end
end

-- ==============================
-- FAVOR AND SECRET COUNTS
-- ==============================

-- Counts once things have settled, however many enter or leave meanwhile
function ScheduleCount()
    if countScheduled then
        return
    end
    countScheduled = true
    Wait.frames(function()
        countScheduled = false
        UpdateCounts()
    end, COUNT_DELAY)
end

-- Shows the secrets, favors and loyal warbands in the zone on their labels (only while the zone is over this mat).
-- The labels are blank while there's no player board on the mat.
function UpdateCounts()
    if not zone or zone.isDestroyed() or not IsOverMat(zone.getPosition()) then
        return
    end
    -- the colors of warband loyal to this mat's player: their lineage's, and Purple too while they're a Citizen or the
    -- Chancellor (their role from their storage box)
    local loyal = {}
    local color = GetPlayerColor()
    if color then
        loyal[color] = true
        local box = FindStorageBox(color)
        local role = box and box.call("GetRole")
        if role == "CITIZEN" or role == "CHANCELLOR" then
            loyal.Purple = true
        end
    end
    -- the favor and secrets on the banners (by GUID), which aren't counted as the player's
    local onBanners = {}
    for _, entry in pairs(GUIDs.banners) do
        local banner = getObjectFromGUID(entry.banner)
        local success, guids = pcall(function()
            return banner.call("GetPieceGUIDs")
        end)
        for guid in pairs(success and guids or {}) do
            onBanners[guid] = true
        end
    end
    local secrets, favors, warbands = 0, 0, 0
    local hasBoard = false
    for _, object in ipairs(zone.getObjects()) do
        if not object.isDestroyed() and not onBanners[object.getGUID()] then
            if object.hasTag("PlayerBoard") then
                hasBoard = true
            elseif object.hasTag("Secret") then
                secrets = secrets + PieceValue(object)
            elseif object.hasTag("Favor") then
                favors = favors + PieceValue(object)
            elseif loyal[GetWarbandObjectColor(object) or ""] then
                warbands = warbands + 1
            end
        end
    end
    -- less the bank warbands on the trays on this mat: the Chancellor tray's, and a lineage tray's while it's an Exile's
    -- bank (a Citizen's or the Chancellor's own tray is hidden and holds none; its GetBankCount would report the
    -- Chancellor tray's, wherever that is)
    for _, tray in ipairs(getObjectsWithTag(tags.warbandTray)) do
        if IsOverMat(tray.getPosition()) then
            local isChancellorTray = trim(tray.memo) == "Purple"
            if isChancellorTray or tray.call("GetMode") == "EXILE" then
                warbands = warbands - (tray.call("GetBankCount") or 0)
            end
        end
    end
    warbands = math.max(0, warbands)
    local function show(count)
        return hasBoard and tostring(count) or ""
    end
    self.editButton({index = SECRET_LABEL, label = show(secrets)})
    self.editButton({index = FAVOR_LABEL, label = show(favors)})
    self.editButton({index = WARBAND_LABEL, label = show(warbands)})
end

-- ==============================
-- LOYAL WARBANDS
-- ==============================

-- The color withdrawn onto this mat (from the Bookshelf), or nil if none is
function GetPlayerColor()
    local bookshelf = getObjectFromGUID(GUIDs.bookshelf)
    for color, matGUID in pairs(bookshelf and bookshelf.getTable("withdrawnMats") or {}) do
        if matGUID == self.getGUID() then
            return color
        end
    end
    return nil
end

-- color's storage box out on the table, by its memo
function FindStorageBox(color)
    for _, box in ipairs(getObjectsWithTag("warbandReturn")) do
        local success, memo = pcall(JSON.decode, box.memo or "")
        if success and type(memo) == "table" and memo.color == color then
            return box
        end
    end
    return nil
end

-- ==============================
-- SCRIPTING ZONE
-- ==============================

-- The player mat zone sitting over this mat
function FindZone()
    for _, candidate in ipairs(getAllObjects()) do
        if candidate.getName():sub(1, #ZONE_NAME) == ZONE_NAME and IsOverMat(candidate.getPosition()) then
            return candidate
        end
    end
    return nil
end

-- Whether a position is over this mat (horizontally)
function IsOverMat(position)
    local bounds = self.getBounds()
    return math.abs(position.x - bounds.center.x) <= bounds.size.x / 2
        and math.abs(position.z - bounds.center.z) <= bounds.size.z / 2
end

-- Fits the zone to the mat: its footprint, from the bottom of its bounding box to ZONE_HEADROOM above the top
function FitZone()
    local bounds, size = self.getBounds(), self.getBoundsNormalized().size
    local bottom = bounds.center.y - bounds.size.y / 2
    zone.setPosition({bounds.center.x, bottom + (size.y + ZONE_HEADROOM) / 2, bounds.center.z})
    zone.setRotation({0, self.getRotation().y, 0})
    zone.setScale({size.x, size.y + ZONE_HEADROOM, size.z})
end
