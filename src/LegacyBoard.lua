-- ==============================
-- LEGACY BOARD
--
-- The board the Legacy deck sits on: one tile
-- with a state for each side, Quiet Ambitions and Public
-- Ambitions, and this script on both.
--   When the board changes side, the Legacy deck moves onto the new
--   side's left snap point, turned to match it: straight on the
--   Quiet side, sideways on the Public side.
--   On the Quiet side, legacy cards played on the discard snap (the
--   right one) go to the bottom of the Legacy deck.
--   On the Public side, a right-click menu item deals the top
--   PUBLIC_DEAL cards of the Legacy deck face up onto the snap
--   points to the right of it (nearest the deck first).
--
-- The left snap point is the one furthest along the board's own x
-- (the board lies turned 180, so that's the side on the left as the
-- table sees it), and the discard snap the one furthest the other
-- way. The deck is found by its cards, not by GUID,
-- since a deck gets a new one whenever it's formed again: it's the
-- one nearest the board.
-- ==============================

local LEGACY_TAG = "Legacy"

-- The Quiet side's state, and the Public side's
local QUIET_STATE = 1
local PUBLIC_STATE = 2

-- How many cards the Public side's menu item deals out
local PUBLIC_DEAL = 4

-- How far from the board (horizontally) the Legacy deck can be to be found
local DECK_SEARCH_RADIUS = 15

-- How close (horizontally) to the discard snap cards have to land to count as played on it
local DISCARD_RADIUS = 2

-- How far above its snap point the deck is set down, so it settles onto it
local DROP_HEIGHT = 0.5

-- Seconds to wait for played cards to settle before giving up on them
local SETTLE_TIMEOUT = 5

-- ==============================
-- SNAP POINTS
-- ==============================

-- A snap point of this side in the world: {position, rotation}
local function inWorld(snap)
    local rotation = self.getRotation()
    local snapRotation = snap.rotation or {x = 0, y = 0, z = 0}
    return {
        position = self.positionToWorld(snap.position),
        rotation = {x = rotation.x + snapRotation.x, y = rotation.y + snapRotation.y, z = rotation.z + snapRotation.z},
    }
end

-- This side's snap point furthest along the board's own x (direction 1: the left one, where the deck goes) or the
-- other way (-1: the discard snap), in the world, or nil if it has none
local function snapFurthest(direction)
    local best = nil
    for _, snap in ipairs(self.getSnapPoints() or {}) do
        if not best or snap.position.x * direction > best.position.x * direction then
            best = snap
        end
    end
    return best and inWorld(best)
end

-- ==============================
-- THE LEGACY DECK
-- ==============================

local function isLegacyEntry(entry)
    for _, tag in ipairs(entry.tags or {}) do
        if tag == LEGACY_TAG then
            return true
        end
    end
    return false
end

-- Whether object is legacy cards: one legacy, or a deck of nothing but
local function isLegacyCards(object)
    if object.type == "Card" then
        return object.hasTag(LEGACY_TAG)
    end
    if object.type ~= "Deck" then
        return false
    end
    local entries = object.getObjects() or {}
    for _, entry in ipairs(entries) do
        if not isLegacyEntry(entry) then
            return false
        end
    end
    return #entries > 0
end

local function horizontalDistance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- The Legacy deck: the legacy cards nearest the board (within DECK_SEARCH_RADIUS), other than except, or nil
local function findLegacyDeck(except)
    local center = self.getPosition()
    local best, bestDistance = nil, DECK_SEARCH_RADIUS
    for _, object in ipairs(getAllObjects()) do
        if object ~= except and (object.type == "Deck" or object.type == "Card") and isLegacyCards(object) then
            local distance = horizontalDistance(object.getPosition(), center)
            if distance <= bestDistance then
                best, bestDistance = object, distance
            end
        end
    end
    return best
end

-- Sets object down on spot ({position, rotation}), turned to match it
local function setDownOn(object, spot)
    object.setPositionSmooth({x = spot.position.x, y = spot.position.y + DROP_HEIGHT, z = spot.position.z}, false, true)
    object.setRotationSmooth(spot.rotation, false, true)
end

-- ==============================
-- DEALING (the Public side)
-- ==============================

-- This side's snap points other than the left one (where the deck goes), nearest the deck first, in the world
local function dealingSnaps()
    local snaps = self.getSnapPoints() or {}
    table.sort(snaps, function(a, b)
        return a.position.x > b.position.x
    end)
    local spots = {}
    for i = 2, #snaps do
        table.insert(spots, inWorld(snaps[i]))
    end
    return spots
end

-- The menu item: the top PUBLIC_DEAL cards of the Legacy deck, face up, onto the snap points right of it
function DealPublicLegacies()
    local deck = findLegacyDeck()
    if not deck then
        broadcastToAll("There's no Legacy deck on the board to deal from.", Color.Orange)
        return
    end
    for i, spot in ipairs(dealingSnaps()) do
        if i > PUBLIC_DEAL or not deck or deck.isDestroyed() then
            break
        end
        local faceUp = {x = spot.rotation.x, y = spot.rotation.y, z = 0}
        local position = {x = spot.position.x, y = spot.position.y + DROP_HEIGHT, z = spot.position.z}
        if deck.type == "Card" then
            -- the last card left
            deck.setPositionSmooth(position, false, true)
            deck.setRotationSmooth(faceUp, false, true)
            deck = nil
        else
            deck.takeObject({position = position, rotation = faceUp, smooth = true})
            -- a deck left with one card turns into that card
            if deck.remainder then
                deck = deck.remainder
            end
        end
    end
end

function onLoad()
    if self.getStateId() == PUBLIC_STATE then
        self.addContextMenuItem("Deal " .. PUBLIC_DEAL .. " legacies", DealPublicLegacies)
    end
end

-- ==============================
-- CHANGING SIDES
-- ==============================

-- This side just became the board's side: the Legacy deck moves onto its left snap point
function onStateChange(old_state_guid)
    local spot = snapFurthest(1)
    local deck = findLegacyDeck()
    if spot and deck and not deck.held_by_color then
        setDownOn(deck, spot)
    end
end

-- ==============================
-- DISCARDING (the Quiet side)
-- ==============================

-- Played cards being put away, so a card that lands again while it's being handled isn't handled twice
local handling = {}

-- Puts the legacy cards played (a card or a deck) at the bottom of the Legacy deck: they go onto the deck's spot,
-- and the deck is put on top of them. With no Legacy deck, they become it.
local function sendToBottom(played)
    local spot = snapFurthest(1)
    if not spot then
        return
    end
    local deck = findLegacyDeck(played)
    played.setRotation(spot.rotation)
    if not deck then
        setDownOn(played, spot)
        return
    end
    -- the played cards where the deck is, the deck put on them: they end up under it
    local deckPosition = deck.getPosition()
    played.setPosition({x = deckPosition.x, y = deckPosition.y - 0.05, z = deckPosition.z})
    local function countOf(object)
        return object.type == "Deck" and #(object.getObjects() or {}) or 1
    end
    local expected = countOf(played) + countOf(deck)
    local bottomGuid = played.type == "Card" and played.getGUID() or nil
    Wait.frames(function()
        if played.isDestroyed() or deck.isDestroyed() then
            return
        end
        local combined = played.putObject(deck) or played
        Wait.frames(function()
            if combined.isDestroyed() then
                return
            end
            setDownOn(combined, spot)
            -- (the played cards should now be in the deck, at the bottom; say so if not, so it's noticed)
            if countOf(combined) ~= expected then
                printToAll("The legacy cards played couldn't be put under the Legacy deck.", Color.Orange)
                return
            end
            local entries = combined.type == "Deck" and combined.getObjects() or {}
            local faceUp = math.cos(math.rad(combined.getRotation().x)) * math.cos(math.rad(combined.getRotation().z)) > 0
            local bottom = faceUp and entries[1] or entries[#entries]
            if bottomGuid and bottom and bottom.guid ~= bottomGuid then
                printToAll("The legacy card played didn't end up at the bottom of the Legacy deck.", Color.Orange)
            end
        end, 2)
    end, 1)
end

-- Something landed on the board: legacy cards on the Quiet side's discard snap go to the bottom of the Legacy deck,
-- once they've settled
function onCollisionEnter(info)
    local played = info.collision_object
    if self.getStateId() ~= QUIET_STATE or not played or played.isDestroyed() or handling[played] then
        return
    end
    if (played.type ~= "Card" and played.type ~= "Deck") or not isLegacyCards(played) then
        return
    end
    local discard = snapFurthest(-1)
    if not discard or horizontalDistance(played.getPosition(), discard.position) > DISCARD_RADIUS then
        return
    end
    handling[played] = true
    Wait.condition(function()
        handling[played] = nil
        -- still there, and not picked up again
        if not played.isDestroyed() and not played.held_by_color
            and horizontalDistance(played.getPosition(), discard.position) <= DISCARD_RADIUS then
            sendToBottom(played)
        end
    end, function()
        return played.isDestroyed() or (played.resting and not played.held_by_color)
    end, SETTLE_TIMEOUT, function()
        handling[played] = nil
    end)
end
