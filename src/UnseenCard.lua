-- ==============================
-- THE UNSEEN CARD
--
-- One script for the Unseen card (tagged UNSEEN_TAG) and the
-- decks it goes into:
--   On the card: when the card goes into a deck with no script at
--   all, the deck gets a copy (and reloads to run it). A deck with
--   a script of its own is left alone.
--   On a deck: when a player shuffles it, an Unseen card in it goes
--   back on top once the shuffle is done; with no Unseen card in
--   it, a shuffle is just a shuffle.
-- The edifice decks have it from the start.
--
-- "On top" is the deck's physical top. TTS lists a deck's cards
-- from the same end whichever way up it lies, so for a face-down
-- deck the first card listed is on top, and for a face-up one (as
-- the edifice decks lie) the last is.
--
-- The script lives on the deck object, so a deck that's taken down
-- to one card (and formed again) no longer has it until the card
-- goes into it again. A deck shuffled by another script
-- (deck.shuffle()) isn't seen either.
-- ==============================

local UNSEEN_TAG = "Unseen"

-- What marks a script as this one, so a deck that has it already isn't given it again
local SCRIPT_MARKER = "-- THE UNSEEN CARD"

local function isUnseen(entry)
    for _, tag in ipairs(entry.tags or {}) do
        if tag == UNSEEN_TAG then
            return true
        end
    end
    return false
end

-- Whether the deck lies face up (its cards' faces point up)
local function isFaceUp()
    local rotation = self.getRotation()
    return math.cos(math.rad(rotation.x)) * math.cos(math.rad(rotation.z)) > 0
end

-- The deck's cards from its physical top down: {index (for takeObject), entry}
local function cardsFromTop()
    local cards = {}
    for i, entry in ipairs(self.getObjects() or {}) do
        table.insert(cards, {index = i - 1, entry = entry})
    end
    if isFaceUp() then
        local reversed = {}
        for i = #cards, 1, -1 do
            table.insert(reversed, cards[i])
        end
        cards = reversed
    end
    return cards
end

-- Puts every Unseen card in this deck back on top (more than one keep their order between them)
local function keepUnseenOnTop()
    local cards = cardsFromTop()
    -- the Unseen cards, from the top down, and whether they're already the top ones
    local unseen, alreadyOnTop = {}, true
    for depth, card in ipairs(cards) do
        if isUnseen(card.entry) then
            table.insert(unseen, card)
            alreadyOnTop = alreadyOnTop and depth == #unseen
        end
    end
    if #unseen == 0 or alreadyOnTop then
        return
    end
    -- taking cards out of a deck down to its last one replaces the deck, and this script with it: at least two others
    -- have to stay in
    if #cards - #unseen < 2 then
        return
    end
    -- out highest index first (so the indexes still to take don't shift), just above the deck, turned like it
    local byIndex = {}
    for _, card in ipairs(unseen) do
        table.insert(byIndex, card)
    end
    table.sort(byIndex, function(a, b)
        return a.index > b.index
    end)
    local above = self.getPosition() + Vector(0, 2, 0)
    local taken = {}
    for _, card in ipairs(byIndex) do
        taken[card] = self.takeObject({
            index = card.index,
            position = above,
            rotation = self.getRotation(),
            smooth = false,
        })
    end
    -- back on top a frame later, once they've spawned: the last one put back ends on top, so they go back from the
    -- lowest up
    Wait.frames(function()
        for i = #unseen, 1, -1 do
            local object = taken[unseen[i]]
            if object and not object.isDestroyed() then
                self.putObject(object)
            end
        end
        -- (a card put on a deck should go on its top; say so if it didn't, so it's noticed)
        Wait.frames(function()
            local top = cardsFromTop()[1]
            if top and not isUnseen(top.entry) then
            end
        end, 2)
    end, 1)
end

-- On a deck: a player shuffled it, so once the shuffle has finished any Unseen card goes back on top
function onRandomize(player_color)
    if self.type == "Deck" then
        Wait.frames(keepUnseenOnTop, 1)
    end
end

-- On the card: it went into a deck (another card dropped on it makes a new one), which gets this script if it has no
-- script at all (setLuaScript would replace one, whether this or another). Only the card listens for this, so the
-- decks aren't told about every object entering every container.
if self.type == "Card" then
    function onObjectEnterContainer(container, object)
        if object ~= self or container.type ~= "Deck" then
            return
        end
        local script = self.getLuaScript()
        if (container.getLuaScript() or "") ~= "" or not script:find(SCRIPT_MARKER, 1, true) then
            return
        end
        container.setLuaScript(script)
        container.reload()
    end
end
