-- ==============================
-- OATH GAME BOARD
--
-- Counts the favors in each of the six favor banks (the board's
-- bottom row of snap points) and shows the count on a label
-- hovering just over that bank's stack. An empty bank shows
-- nothing. The board's memo holds each bank's snap point by suit,
-- in its own units, e.g. {"Discord": {"x": 0.3988, "y": 0.2,
-- "z": 0.8652}, ...}. Each bank has a scripting zone over it (in
-- the save, GUIDs.favorBankZones) that tells the board to recount
-- whenever something enters or leaves it.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")

-- The favor banks' suits, left to right along the board's bottom edge (as seen from its near side), in the order of
-- the labels' button indexes
local BANK_SUITS = {"Discord", "Arcane", "Order", "Hearth", "Beast", "Nomad"}

-- In world units: how far above the top of a bank's favors its count hovers
local LABEL_HOVER = 0.2

-- Label text (as on an object of scale 1; it's scaled back down from the board's scale)
local LABEL_FONT_SIZE = 400
local LABEL_FONT_COLOR = {0, 0, 0}

-- The label's color when the top of the bank is a triple favor (or a stack of them)
local TRIPLE_LABEL_FONT_COLOR = {1, 1, 1}

-- Frames to wait after something enters or leaves a bank before counting, so stacks have finished merging
local COUNT_DELAY = 0

-- Seconds to wait for something carried over a bank to be put down before counting anyway
local DROP_TIMEOUT = 10

-- What's being waited on to be put down, by GUID
local awaitingDrop = {}

-- Each bank's snap point (from the memo), by the bank's index (nil if the memo has none)
local banks = {}

-- Each bank's zone (GUIDs.favorBankZones), by the bank's index (nil if it's missing)
local bankZones = {}

-- Whether a count is already waiting to run
local countScheduled = false

-- boardState.showFavorCounts: whether the favor count labels are shown (toggled from the board's right-click menu)
boardState = {showFavorCounts = true}

function onSave()
    return JSON.encode(boardState)
end

function onLoad(savedData)
    if savedData and savedData ~= "" then
        local success, saved = pcall(JSON.decode, savedData)
        if success and type(saved) == "table" then
            for key, value in pairs(saved) do
                boardState[key] = value
            end
        end
    end
    RefreshMenu()
    -- each suit's bank snap point from the memo, by its index in BANK_SUITS
    banks = {}
    local success, memo = pcall(JSON.decode, self.memo or "")
    if not success or type(memo) ~= "table" then
        print("The game board's memo has no favor bank positions.")
    else
        for i, suit in ipairs(BANK_SUITS) do
            local position = memo[suit]
            if type(position) == "table" then
                banks[i] = {x = position.x, y = position.y, z = position.z}
            else
                print("The game board's memo has no position for the " .. suit .. " favor bank.")
            end
        end
    end
    CreateLabels()
    for i, suit in ipairs(BANK_SUITS) do
        local zone = getObjectFromGUID(GUIDs.favorBankZones[suit] or "")
        if zone then
            bankZones[i] = GiveZoneNotifier(zone, self)
        else
            print("The game board's " .. suit .. " favor bank has no zone (GUIDs.favorBankZones." .. suit .. ").")
        end
    end
    ScheduleCount()
end

-- ==============================
-- MENU
-- ==============================

-- The right-click toggle for the favor counts, labelled with what it will do
function RefreshMenu()
    self.clearContextMenu()
    self.addContextMenuItem(boardState.showFavorCounts and "Hide Favor Counts" or "Show Favor Counts", ToggleFavorCounts)
end

function ToggleFavorCounts()
    boardState.showFavorCounts = not boardState.showFavorCounts
    RefreshMenu()
    UpdateCounts()
end

-- ==============================
-- LABELS
-- ==============================

-- Clicking a label does nothing
function IgnoreClick()
end

-- One label per bank, blank until there's a count to show
function CreateLabels()
    self.clearButtons()
    local scale = self.getScale()
    -- one per suit, so a label's index is its bank's (one with no position sits at the board's centre, blank)
    for i = 1, #BANK_SUITS do
        local bank = banks[i] or {x = 0, y = 0, z = 0}
        self.createButton({
            click_function = "IgnoreClick",
            function_owner = self,
            label = "",
            -- button positions have x flipped
            position = {-bank.x, bank.y, bank.z},
            rotation = {0, 0, 0},
            scale = {1 / scale.x, 1, 1 / scale.z},
            width = 0,
            height = 0,
            font_size = LABEL_FONT_SIZE,
            font_color = LABEL_FONT_COLOR,
        })
    end
end

-- ==============================
-- COUNTS
-- ==============================

-- Bank i's favor: how much there is (triples count 3, held favor doesn't count), the top of its stack, and whether
-- the topmost piece is a triple
function BankFavor(i)
    local zone = bankZones[i]
    local count, top, topIsTriple = 0, nil, false
    for _, object in ipairs(zone and not zone.isDestroyed() and zone.getObjects() or {}) do
        if not object.isDestroyed() and object.held_by_color == nil and object.hasTag("Favor") then
            count = count + PieceValue(object)
            local bounds = object.getBounds()
            local objectTop = bounds.center.y + bounds.size.y / 2
            if not top or objectTop > top then
                top, topIsTriple = objectTop, object.hasTag("Triple")
            end
        end
    end
    return count, top, topIsTriple
end

-- For other objects (the People's Favor): each favor bank left to right, as {suit, x, y, z (its snap point in the
-- world), count}
function GetBanks()
    local result = {}
    for i, suit in ipairs(BANK_SUITS) do
        if banks[i] then
            local spot = self.positionToWorld(banks[i])
            table.insert(result, {suit = suit, x = spot.x, y = spot.y, z = spot.z, count = (BankFavor(i))})
        end
    end
    return result
end

-- Counts once things have settled, however many favors move meanwhile. The bank zones call this with the GUID of what
-- entered or left: a favor carried over a bank enters while it's held (and held favors aren't counted), and nothing
-- fires when it's put down, so it's counted again once it has been dropped and come to rest.
function ScheduleCount(guid)
    local object = guid and getObjectFromGUID(guid)
    if object and not awaitingDrop[guid] and (object.held_by_color ~= nil or not object.resting) then
        awaitingDrop[guid] = true
        local function dropped()
            awaitingDrop[guid] = nil
            ScheduleCount()
        end
        Wait.condition(dropped, function()
            return object.isDestroyed() or (object.held_by_color == nil and object.resting)
        end, DROP_TIMEOUT, dropped)
    end
    if countScheduled then
        return
    end
    countScheduled = true
    Wait.frames(function()
        countScheduled = false
        UpdateCounts()
    end, COUNT_DELAY)
end

-- Shows each bank's favors on its label, hovering over the top of the stack (blank when the bank is empty, or while
-- the counts are hidden)
function UpdateCounts()
    for i = 1, #BANK_SUITS do
        local bank = banks[i]
        local count, top, topIsTriple = BankFavor(i)
        if count == 0 or not bank or not boardState.showFavorCounts then
            self.editButton({index = i - 1, label = ""})
        else
            local spot = self.positionToWorld(bank)
            local hover = self.positionToLocal({spot.x, top + LABEL_HOVER, spot.z})
            self.editButton({
                index = i - 1,
                label = tostring(count),
                position = {-hover.x, hover.y, hover.z},
                font_color = topIsTriple and TRIPLE_LABEL_FONT_COLOR or LABEL_FONT_COLOR,
            })
        end
    end
end
