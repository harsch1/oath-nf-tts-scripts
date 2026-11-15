require("src/Utils/ColorUtils")
require("src/Utils/HelperFunctions")
require("src/Config/GeneralConfig")
require("src/Config/CardMapping")


local steps = {"PreInit","Init", "Atlas Box", "World", "World Deck", "Relic Deck", "Dispossessed", "Reliquary", "Foundations", "Players"}

-- Oath numbers in the export (must match OATHS in chronicle-codec.js). 0 means unset. Listed in the order shown in the picker
local oaths = {
    {name = "Supremacy",  id = 1, image = "https://cardcdn.buriedgiant.com/cards/oath/en-US/Supremacy%20Oath%20(NF).png"},
    {name = "People",     id = 3, image = "https://cardcdn.buriedgiant.com/cards/oath/en-US/People%20Oath%20(NF).png"},
    {name = "Protection", id = 4, image = "https://cardcdn.buriedgiant.com/cards/oath/en-US/Protection%20Oath%20(NF).png"},
    {name = "Devotion",   id = 2, image = "https://cardcdn.buriedgiant.com/cards/oath/en-US/Devotion%20Oath%20(NF).png"},
}
-- Player sections in export order (must match PLAYER_COLORS in chronicle-codec.js)
local playerColors = {"Red", "Blue", "Yellow", "Black", "White", "Brown", "Pink"}
local maxLineage = 6723 -- the most 2 base 82 digits hold

currentStep = ""
local version = 1
stringSoFar = ""
lastExport = nil     -- the last finished export string, kept so the host can show it again
foundationMask = nil -- flipped Foundations, read at the Foundations step and written once the Oath is picked
lineageScores = nil  -- {[color] = score}, set when the host saves the lineage scores at the Players step
lineageInputs = {}   -- {[color] = text} typed so far in the lineage inputs

-- Placeholder replacement (see that section)
local pendingSlots = nil    -- slots found by the scan in progress
local requests = nil        -- replacements still asked for: {kind = "denizen"|"relic", suit, slots}
local onRequestsDone = nil  -- the step's continuation
local absorbing = {}        -- GUIDs of replacement cards the script itself is putting into the box
local pickupPositions = {}  -- where objects were picked up from, to put a rejected or used Card Archive back

function onLoad(state)
    if state ~= nil then
        local loadedData = JSON.decode(state)
        if loadedData then
            if loadedData.currentStep then
                currentStep = loadedData.currentStep
            end
            if loadedData.stringSoFar then
                stringSoFar = loadedData.stringSoFar
            end
            lineageScores = loadedData.lineageScores
            lineageInputs = loadedData.lineageInputs or {}
            lastExport = loadedData.lastExport
        else
            currentStep = "PreInit"
            stringSoFar = ""
        end
    end
    makeButton()
end

function onSave()
    local dataToSave = {
        currentStep = currentStep,
        stringSoFar = stringSoFar,
        lineageScores = lineageScores,
        lineageInputs = lineageInputs,
        lastExport = lastExport,
    }
    return JSON.encode(dataToSave)
end

-- Styled after the 2.0 start screen: teal panel, cream title, brown buttons
local uiColors = {
    panel = "#5B8F80FF",
    title = "#F4E6C5FF",
    problem = "#FFC2A8FF",
    text = "#FFFFFFFF",
    button = "#56372F|#75493E|#3F2923|#333333",
}

local allColors = {"White", "Brown", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Grey", "Black"}

-- Visibility for the instruction popup: everyone, or everyone but the host (while the host has their own window open).
-- If the host is a spectator (Grey), other spectators are left out too, since visibility only goes by color
local function instructionVisibility(hideFromHost)
    local hostColor = nil
    if hideFromHost then
        for _, player in ipairs(Player.getPlayers()) do
            if player.host then hostColor = player.color end
        end
    end
    local colors = {}
    for _, color in ipairs(allColors) do
        if color ~= hostColor then table.insert(colors, color) end
    end
    return table.concat(colors, "|")
end

-- Shows this step's instructions in the instruction popup, reopening it if it was closed.
-- It replaces the previous instructions, so the popup follows the export as it moves through the steps.
-- hideFromHost: the host is working in their own window (Oath, lineage scores, export), so only everyone else sees the message
function instruct(message, isProblem, hideFromHost)
    withExporterUi(function()
        Global.UI.setAttribute("chronicle_instructions", "visibility", instructionVisibility(hideFromHost))
        Global.UI.setAttribute("chronicle_instructions_title", "text", isProblem and "CHRONICLE EXPORT: PROBLEM" or "CHRONICLE EXPORT")
        Global.UI.setAttribute("chronicle_instructions_title", "color", isProblem and uiColors.problem or uiColors.title)
        Global.UI.setAttribute("chronicle_instructions_text", "text", message)
        Global.UI.setAttribute("chronicle_instructions", "active", "true")
    end)
end

function advanceExportSteps()
    if requests then
        instructRequest() -- waiting on a placeholder replacement
        return
    end
    if currentStep == "PreInit" then
        instruct("Welcome! This exports your current Chronicle in a few steps. Follow the instructions in this window, "
            .. "and keep a backup of your save that you can reload if you need to recover.\n\n"
            .. "When you're ready, click OK on the Chronicle Writer.")
        nextStep()
        updateButton()
        return
    end
    if currentStep == "Init" then
        instruct("Clean up the map except for the current Empire, and make sure all Foundations are flipped correctly.\n\n"
            .. "Then click Ready on the Chronicle Writer.")
        nextStep()
        updateButton()
        return
    end


    if currentStep == "Atlas Box" then
        if getObjectFromGUID(GUIDs.atlasBox) == nil then
            instruct("Atlas Box not found! Make sure the Atlas Box is on the table, then click the Chronicle Writer again.", true)
            return
        else
            instruct("Backing up the Atlas Box...")
            -- One value per site: [site index][card ids * 100, 100 000, ...]
            local sites = {}
            for _, siteObject in ipairs(getObjectFromGUID(GUIDs.atlasBox).getData().ContainedObjects or {}) do
                local siteName = siteObject.Nickname
                local vals = {siteIndex[siteName]}
                local mult = 100
                local where = "the Atlas Box (" .. tostring(siteName) .. ")"
                for _, childObject in ipairs(siteObject.ChildObjects or {}) do
                    if childObject.Tags then
                        local objectType = ""
                        for _, tag in ipairs(childObject.Tags) do
                            objectType = ({
                                [tags.edifice] = tags.edifice,
                                [tags.relic] = tags.relic,
                                [tags.card] = tags.card,
                            })[tag] or objectType
                        end
                        local kind = ({[tags.edifice] = "edifice", [tags.relic] = "relic", [tags.card] = "denizen"})[objectType]
                        if kind and addCardTerm(kind, childObject.CardID, vals, 1, mult, where, "id", true) then
                            mult = mult * 1000
                        end
                    end
                end
                table.insert(sites, vals)
            end
            resolvePlaceholders(function()
                for _, vals in ipairs(sites) do
                    stringSoFar = stringSoFar .. oEncode(vals[1]) .. "#"
                end
                stringSoFar = stringSoFar .. ">"
                nextStep()
                advanceExportSteps() -- on to the Empire
            end)
            return
        end
    end
    if currentStep == "World" then
        instruct("Backing up the Empire...")

        function processWorldObjects(objects)
            local sites = {}
            for _, object in ipairs(objects) do
                local vals = nil
                for _, hitItem in ipairs(object) do
                    if hitItem.hasTag(tags.site) then
                        vals = {siteIndex[hitItem.getName()]}
                        break
                    end
                end
                if vals then
                    local mult = 100
                    for _, hitItem in ipairs(object) do
                        local cardId = nil
                        for _, kind in ipairs({{tags.edifice, "edifice"}, {tags.relic, "relic"}, {tags.card, "denizen"}}) do
                            if hitItem.hasTag(kind[1]) then
                                cardId = cardId or hitItem.getData().CardID
                                if addCardTerm(kind[2], cardId, vals, 1, mult, "the Empire", "id", true) then
                                    mult = mult * 1000
                                end
                            end
                        end
                    end
                    table.insert(sites, vals)
                end
            end
            resolvePlaceholders(function()
                for _, vals in ipairs(sites) do
                    stringSoFar = stringSoFar .. oEncode(vals[1]) .. "#"
                end
                stringSoFar = stringSoFar .. ">"
                nextStep()
                advanceExportSteps() -- on to the World Deck instructions
            end)
        end

        local objects = {}
        local mapTransform = {position = getObjectFromGUID("d5dacf").getPosition(), rotation = getObjectFromGUID("d5dacf").getRotation()}
        for i = 1, 8, 1 do
            local zone = spawnObject({
                type = "FogOfWarTrigger",
                position = vectorSum(getTransformStruct("site", i, mapTransform).position, vector(5.65, 0, 0)),
                scale = vector(19.5,2,5.4),
                sound = false,
                callback_function = function(createdZone)
                    createdZone.memo = "trigger"
                    Wait.time(function()
                        local hitObjects = createdZone.getObjects(true)
                        objects[i] = hitObjects
                        if i == 8 then
                            processWorldObjects(objects)
                        end
                        Wait.time(function ()
                            destroyObject(createdZone)
                        end, 0.2)
                    end, 0.1)
                end
            })
        end
        return
    end
    if currentStep == "World Deck" then
        updateButton()
        instruct("Place the World Deck in the box on the desk.")
        -- onObjectEnter to continue
    end
    if currentStep == "Relic Deck" then
        updateButton()
        instruct("Place the Relic Deck in the box on the desk.")
        -- onObjectEnter to continue
    end
    if currentStep == "Dispossessed" then
        updateButton()
        instruct("Place the Dispossessed deck in the box on the desk.")
        -- onObjectEnter to continue
    end
    if currentStep == "Reliquary" then
        updateButton()
        instruct("Place the Reliquary in the box on the desk (as a deck if there is more than one).\n\n"
            .. "If there is none, click > on the Chronicle Writer to skip.")
        -- onObjectEnter to continue
    end
    if currentStep == "Foundations" then
        updateButton()
        readFoundations(false)
        return
    end
    if currentStep == "Players" then
        updateButton()
        if lineageScores == nil then
            instruct("The host is entering each player's lineage score...", false, true)
            showLineagePanel()
            return
        end
        instructPlayers()
    end
end

function instructPlayers(note)
    instruct((note and (note .. "\n\n") or "")
        .. "Archive all Players. Then unlock the Player Archive in the bottom left corner (L key as the Host) "
        .. "and place the bag in the box on the desk.\n"
        .. "(If the player boards glitch out and get in your way, save and reload.)")
end

-- ---------- Foundations and Oath picker ----------

-- Reads which Foundations are flipped, then opens the Oath picker. skipMissing: Foundations that can't be found
-- count as unflipped (the > button) instead of stopping the export
function readFoundations(skipMissing)
    local sum = 0
    local missing = {}
    for i, foundation in ipairs(GUIDs.foundations) do
        local foundationCard = getObjectFromGUID(foundation.GUID)
        if foundationCard == nil then
            if not skipMissing then
                instruct("Could not find " .. foundation.name .. ". Make sure it's on the table and not in a deck, "
                    .. "then click the Chronicle Writer again.\n\n"
                    .. "To skip the Foundations that can't be found, click > on the Chronicle Writer. "
                    .. "Skipped Foundations will be on their default side.", true)
                return
            end
            table.insert(missing, foundation.name)
        elseif roundToNearest180(foundationCard.getRotation().z) == 180 then
            sum = sum + 2^(i-1)
        end
    end
    if #missing > 0 then
        printToAll("Chronicle export: skipped " .. table.concat(missing, ", ") .. " (they will be on their default side).",
            hexToColor("#E8A33D"))
    end
    -- The section is written once the host picks the Oath (selectOath / skipOath)
    foundationMask = sum
    instruct("The host is choosing the current Oath...", false, true)
    showExporterPanel("chronicle_oath_overlay")
end

function skipFoundations()
    if currentStep ~= "Foundations" then return end
    readFoundations(true)
end

-- Foundations section: [flipped Foundations bitmask: 2 digits][Oath: 1 digit]
function writeFoundations(oathId)
    if currentStep ~= "Foundations" or foundationMask == nil then return end -- guards against a double click
    stringSoFar = stringSoFar .. padEncode(foundationMask, 2) .. oEncode(oathId) .. ">"
    foundationMask = nil
    Global.UI.setAttribute("chronicle_oath_overlay", "active", "false")
    nextStep()
    advanceExportSteps()
end

function selectOath(player, oathName, id)
    if not player.host then
        broadcastToColor("Only the host can pick the Oath.", player.color, hexToColor("#ce2d2d"))
        return
    end
    for _, oath in ipairs(oaths) do
        if oath.name == oathName then
            writeFoundations(oath.id)
            return
        end
    end
end

function skipOath(player, value, id)
    if not player.host then
        broadcastToColor("Only the host can pick the Oath.", player.color, hexToColor("#ce2d2d"))
        return
    end
    writeFoundations(0)
end

-- ---------- Lineage scores ----------

function showLineagePanel()
    showExporterPanel("chronicle_lineage_overlay", function()
        for _, color in ipairs(playerColors) do
            Global.UI.setAttribute("chronicle_lineage_" .. color, "text", lineageInputs[color] or "")
        end
    end)
end

-- id is "chronicle_lineage_<Color>"
function setLineageInput(player, value, id)
    lineageInputs[id:sub(#"chronicle_lineage_" + 1)] = value
end

function submitLineage(player, value, id)
    if not player.host then
        broadcastToColor("Only the host can enter the lineage scores.", player.color, hexToColor("#ce2d2d"))
        return
    end
    if currentStep ~= "Players" then return end
    local scores = {}
    local capped = {}
    for _, color in ipairs(playerColors) do
        local score = math.floor(math.max(tonumber(lineageInputs[color] or "") or 0, 0))
        if score > maxLineage then
            table.insert(capped, color)
            score = maxLineage
        end
        scores[color] = score
    end
    lineageScores = scores
    Global.UI.setAttribute("chronicle_lineage_overlay", "active", "false")
    instructPlayers(#capped > 0
        and ("Note: lineage scores above " .. maxLineage .. " were saved as " .. maxLineage .. " (" .. table.concat(capped, ", ") .. ").")
        or nil)
end

-- ---------- Card lookups ----------
-- They return nil for anything not in CardMapping, so the export skips it instead of crashing.
-- Placeholder cards (see placeholderCards in CardMapping) are checked separately, since they get replaced

local function skipped(what, cardId, where)
    printToAll("Chronicle export: skipped an unknown " .. what .. (where and (" in " .. where) or "")
        .. " (card ID " .. tostring(cardId) .. ").", hexToColor("#E8A33D"))
end

-- The suit of a denizen placeholder card, or nil if it isn't one
function placeholderSuit(cardId)
    cardId = tonumber(cardId)
    if cardId == nil then return nil end
    local suit = deckLookup[math.floor(cardId / 100)]
    local slots = suit and placeholderCards.denizens[suit]
    return (slots and slots[cardId % 100]) and suit or nil
end

function isPlaceholderRelic(cardId)
    cardId = tonumber(cardId)
    return cardId ~= nil and placeholderCards.relics[cardId % 100] == true
end

-- Returns the export id of a denizen card. Silent when where is nil
function denizenExportId(cardId, where)
    cardId = tonumber(cardId)
    if cardId == nil or placeholderSuit(cardId) then return nil end
    local suit = deckLookup[math.floor(cardId / 100)]
    if suit == nil then return nil end -- not a denizen deck (e.g. Visions), skipped as before
    local entry = cardIndex[suit] and cardIndex[suit].cards[cardId % 100]
    if entry == nil then
        if where then skipped("card", cardId, where) end
        return nil
    end
    return entry.id
end

-- Every edifice sheet slot is mapped, so only the deck needs checking
function edificeExportId(cardId)
    cardId = tonumber(cardId)
    local suit = cardId and edificeDeckLookup[math.floor(cardId / 100)]
    if suit == nil then return nil end
    return edificeIndex[suit].cards[cardId % 100].id
end

-- Returns the relicIndex entry (with .id and .relicId). Silent when where is nil
function relicExportEntry(cardId, where)
    cardId = tonumber(cardId)
    if cardId == nil or isPlaceholderRelic(cardId) then return nil end
    local entry = relicIndex.cards[cardId % 100]
    if entry == nil and where then skipped("relic", cardId, where) end
    return entry
end

-- ---------- Placeholder replacement ----------
-- Every section is a sum of id * mult terms, so a placeholder's term can be added once its replacement is known.
-- While scanning, a placeholder registers its slot (vals[key], mult). resolvePlaceholders then asks for the replacements
-- (the suit's Card Archive for denizens, relics for relics) and runs the step's continuation once all are filled in

local function addPlaceholder(kind, suit, vals, key, mult, field)
    pendingSlots = pendingSlots or {}
    table.insert(pendingSlots, {kind = kind, suit = suit, vals = vals, key = key, mult = mult, field = field})
end

-- Adds one card's term to vals[key] (or registers its placeholder). Returns true if the card takes a place in the section.
-- kind: "denizen", "edifice" or "relic". relicField: which relic id the section uses ("id" or "relicId").
-- replace: whether placeholders here get replaced or just left out. Placeholder denizens are replaced everywhere but
-- the Dispossessed, placeholder relics only in the Atlas Box and on the map
function addCardTerm(kind, cardId, vals, key, mult, where, relicField, replace)
    if kind == "denizen" then
        local suit = placeholderSuit(cardId)
        if suit then
            if not replace then return false end
            addPlaceholder("denizen", suit, vals, key, mult)
            return true
        end
        local id = denizenExportId(cardId, where)
        if id then
            vals[key] = vals[key] + id * mult
            return true
        end
    elseif kind == "edifice" then
        local id = edificeExportId(cardId)
        if id then
            vals[key] = vals[key] + id * mult
            return true
        end
    elseif kind == "relic" then
        if isPlaceholderRelic(cardId) then
            if not replace then return false end
            addPlaceholder("relic", nil, vals, key, mult, relicField)
            return true
        end
        local relic = relicExportEntry(cardId, where)
        if relic then
            vals[key] = vals[key] + relic[relicField] * mult
            return true
        end
    end
    return false
end

local function requestMessage(req)
    local count = #req.slots
    local what = req.kind == "denizen" and ("the " .. req.suit .. " Card Archive")
        or (count .. " Relic" .. (count == 1 and "" or "s"))
    return "Detected a placeholder card. Please put " .. what .. " into the box to replace " .. (count == 1 and "it." or "them.")
end

function instructRequest(problem)
    instruct((problem and (problem .. "\n\n") or "") .. requestMessage(requests[1]), problem ~= nil)
end

-- Asks for replacements for the placeholders found by the scan, then calls onDone
function resolvePlaceholders(onDone)
    local slots = pendingSlots or {}
    pendingSlots = nil
    if #slots == 0 then
        onDone()
        return
    end
    requests = {}
    local byKind = {}
    for _, slot in ipairs(slots) do
        local key = slot.kind .. (slot.suit or "")
        if byKind[key] == nil then
            byKind[key] = {kind = slot.kind, suit = slot.suit, slots = {}}
            table.insert(requests, byKind[key])
        end
        table.insert(byKind[key].slots, slot)
    end
    onRequestsDone = onDone
    instructRequest()
end

function onObjectPickUp(playerColor, object)
    if requests then pickupPositions[object.getGUID()] = object.getPosition() end
end

-- Takes an object back out of the box, to where it was picked up from (or beside the box)
local function ejectFromBox(guid, callback)
    local position = pickupPositions[guid]
    if position == nil then
        local bounds = self.getBounds()
        position = self.getPosition() + Vector(bounds.size.x / 2 + 3, 2, 0)
    else
        position = position + Vector(0, 1, 0)
    end
    pickupPositions[guid] = nil
    self.takeObject({guid = guid, position = position, smooth = false, callback_function = callback})
end

local function finishRequest(req)
    for _ = 1, #req.slots do
        broadcastToAll("A placeholder " .. (req.kind == "denizen" and (req.suit .. " Card") or "Relic")
            .. " was found and replaced with another unused replacement")
    end
    table.remove(requests, 1)
    if #requests > 0 then
        instructRequest()
        return
    end
    local onDone = onRequestsDone
    requests = nil
    onRequestsDone = nil
    pickupPositions = {}
    onDone()
end

-- An object put in the box while replacements are asked for
local function handleReplacement(object)
    local req = requests[1]
    local data = object.getData()
    local cards = data.ContainedObjects or {data}
    local guid = object.getGUID()

    if req.kind == "denizen" then
        -- Must be that suit's Card Archive: only cards of the suit, with enough real cards to pick from
        local candidates = {}
        local onlySuit = true
        for _, card in ipairs(cards) do
            local cardId = tonumber(card.CardID)
            local suit = cardId and deckLookup[math.floor(cardId / 100)]
            if suit ~= req.suit then onlySuit = false end
            local id = denizenExportId(cardId)
            if id and suit == req.suit then table.insert(candidates, {id = id, guid = card.GUID}) end
        end
        if not onlySuit or #candidates < #req.slots then
            ejectFromBox(guid)
            instructRequest("That isn't the " .. req.suit .. " Card Archive.")
            return
        end
        local chosen = {}
        for _, slot in ipairs(req.slots) do
            local pick = table.remove(candidates, math.random(#candidates))
            slot.vals[slot.key] = slot.vals[slot.key] + pick.id * slot.mult
            table.insert(chosen, pick.guid)
        end
        -- Put the archive back, keeping the replacement cards in the box since they're now in use
        ejectFromBox(guid, function(archive)
            for _, cardGuid in ipairs(chosen) do
                archive.takeObject({
                    guid = cardGuid, position = archive.getPosition() + Vector(0, 2, 0), smooth = false,
                    callback_function = function(card)
                        absorbing[card.getGUID()] = true
                        self.putObject(card)
                    end,
                })
            end
        end)
    else
        -- Exactly the number of relics asked for, all real relics. They stay in the box
        local relics = {}
        for _, card in ipairs(cards) do
            local relic = relicExportEntry(card.CardID)
            if relic then table.insert(relics, relic) end
        end
        if #relics ~= #req.slots or #cards ~= #req.slots then
            ejectFromBox(guid)
            instructRequest("That wasn't " .. #req.slots .. " relic" .. (#req.slots == 1 and "" or "s") .. ".")
            return
        end
        for i, slot in ipairs(req.slots) do
            slot.vals[slot.key] = slot.vals[slot.key] + relics[i][slot.field] * slot.mult
        end
    end
    finishRequest(req)
end

-- Sections of cards packed 5 to a 7 digit chunk (World Deck, Dispossessed, Relic Deck). Returns the chunk values
local function chunkedTerms(cards, kind, base, where, relicField, replace)
    local chunks = {}
    local mult, count = 1, 0
    for _, card in ipairs(cards) do
        if count == 0 then table.insert(chunks, 0) end
        if addCardTerm(kind, card.CardID, chunks, #chunks, mult, where, relicField, replace) then
            mult = mult * base
            count = count + 1
            if count == 5 then mult, count = 1, 0 end
        elseif count == 0 then
            table.remove(chunks) -- nothing went into the chunk just started
        end
    end
    return chunks
end

-- Later chunks come first in the export
local function chunkString(chunks)
    local s = ""
    for _, value in ipairs(chunks) do s = padEncode(value, 7) .. s end
    return s
end

function onObjectEnterContainer(container, object)
    if container == self then
        if absorbing[object.getGUID()] then
            absorbing[object.getGUID()] = nil -- a replacement card the script put in the box itself
            return
        end
        if requests then
            handleReplacement(object)
            return
        end
        if currentStep == "World Deck" then
            local chunks = chunkedTerms(object.getData().ContainedObjects or {}, "denizen", 400, "the World Deck", nil, true)
            resolvePlaceholders(function()
                stringSoFar = stringSoFar .. chunkString(chunks) .. ">"
                nextStep()
                advanceExportSteps()
            end)
            return
        end
        if currentStep == "Relic Deck" then
            -- Placeholder relics in the deck are just left out (the card says to delete it and draw another)
            local chunks = chunkedTerms(object.getData().ContainedObjects or {}, "relic", 100, "the Relic Deck", "relicId")
            stringSoFar = stringSoFar .. chunkString(chunks) .. ">"
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Dispossessed" then
            -- Placeholder cards in the Dispossessed are just left out
            local chunks = chunkedTerms(object.getData().ContainedObjects or {}, "denizen", 400, "the Dispossessed", nil, false)
            stringSoFar = stringSoFar .. chunkString(chunks) .. ">"
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Reliquary" then
            local data = object.getData()
            local vals = {0}
            local mult = 1
            for _, cardObject in ipairs(data.ContainedObjects or {data}) do
                if addCardTerm("relic", cardObject.CardID, vals, 1, mult, "the Reliquary", "relicId", false) then
                    mult = mult * 100
                end
            end
            stringSoFar = stringSoFar .. oEncode(vals[1]) .. ">"
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Players" then
            if lineageScores == nil then
                instruct("Enter the lineage scores first, then take the bag out and place it in the box again.", true)
                showLineagePanel()
                return
            end
            local playerBoards = {
                    {color = "Red", order=1},
                    {color = "Blue", order=2},
                    {color = "White", order=5},
                    {color = "Yellow", order=3},
                    {color = "Black", order=4},
                    {color = "Brown", order=6},
                    {color = "Pink", order=7},
            }
            -- [status: 1 digit][lineage: 2 digits][cards]#[legacies]#[relics]. The cards are a value
            -- (cardVals[i][1]) filled in after any placeholder replacements, so each player is a head, cards and tail
            local heads, cardVals, tails = {}, {}, {}
            if object.getData().ContainedObjects ~= nil then
                local players = {}
                for _, archivedPlayer in ipairs(object.getData().ContainedObjects) do
                    players[playerBoards[JSON.decode(archivedPlayer.Memo).hotkey].order] = archivedPlayer
                end
                for i = 1, 7 do
                    local player = players[i]
                    local playerString = ""
                    local lineage = padEncode(lineageScores[playerColors[i]] or 0, 2)
                    if player == nil then
                        heads[i] = "0" .. lineage
                        tails[i] = "#"
                    else
                        local status = "Exile"
                        local cardIDs = {}
                        local relicIDs = {}
                        local legacies = {}
                        for _, attachment in ipairs(player.ChildObjects) do
                            if attachment.Name == "Card" then
                                local deckNumber = math.floor(tonumber(attachment.CardID) / 100)
                                local cardNumber = tonumber(attachment.CardID) % 100
                                if cardNumber == 0 and attachment.CustomDeck[deckNumber].FaceURL == "https://dl.dropboxusercontent.com/scl/fi/8z39ph40afhr4zv1z5n1j/player.jpg?rlkey=56pylu5somf5lporrtegdldr9&dl=0" then
                                    status = "Chancellor"
                                elseif attachment.CustomDeck[deckNumber].FaceURL == "https://dl.dropboxusercontent.com/scl/fi/whwjimllmyaim9fcs4276/player2.jpg?rlkey=5wsqhp7b8lavz9hxf9uh95ndq&dl=0" then
                                    status = "Citizen"
                                elseif attachment.CustomDeck[deckNumber].FaceURL == "https://dl.dropboxusercontent.com/scl/fi/07eglj8gu44allbbywycx/legacy.jpg?rlkey=rrseahcgk1ii2nksch45rjklr&dl=0" then
                                    table.insert(legacies, attachment)
                                elseif attachment.Tags then
                                    local objectType = ""
                                    for _, tag in ipairs(attachment.Tags) do
                                        objectType = ({
                                            [tags.relic] = tags.relic,
                                            [tags.card] = tags.card,
                                        })[tag] or objectType
                                    end
                                    if objectType == tags.relic then
                                        table.insert(relicIDs, cardNumber)
                                    end
                                    if objectType == tags.card then
                                        table.insert(cardIDs, attachment.CardID)
                                    end
                                end
                            end
                        end
                        
                        local statusNum = ({
                            ["Exile"] = 0,
                            ["Citizen"] = 1,
                            ["Chancellor"] = 2
                        })[status]
                        heads[i] = oEncode(statusNum) .. lineage

                        local vals = {0}
                        local mult = 1
                        for _, cardId in ipairs(cardIDs) do
                            if addCardTerm("denizen", cardId, vals, 1, mult, playerColors[i] .. "'s archive", nil, true) then
                                mult = mult * 400
                            end
                        end
                        cardVals[i] = vals

                        local mult = 1
                        local sum = 0
                        local count = 0
                        local playerlegacyString = ""
                        for _, legacy in ipairs(legacies) do
                            local legacyID = tonumber(legacy.CardID) % 100
                            local isDormant = (roundToNearest180(legacy.Transform.rotZ) == 180)
                            if legacyIndex.cards[legacyID] ~= nil then
                                sum = sum + (legacyIndex.cards[legacyID].id)*mult
                                if isDormant then sum = sum + 100*mult end
                                mult = mult * 200
                                count = count + 1
                                if count == 5 then
                                    playerlegacyString = padEncode(sum, 7) .. playerlegacyString
                                    mult = 1
                                    sum = 0
                                    count = 0
                                end
                            end
                        end
                        if #playerlegacyString == 0 then
                            if sum > 0 then
                                playerString = playerString .. oEncode(sum) .. "#"
                            else 
                                playerString = playerString .. "#"
                            end
                        else
                            if sum > 0 then
                                playerlegacyString = padEncode(sum, 7) .. playerlegacyString
                            end
                            playerString = playerString .. playerlegacyString .. "#"
                        end

                        local mult = 1
                        local sum = 0
                        local count = 0
                        for _, relicID in ipairs(relicIDs) do
                            if relicIndex.cards[relicID] ~= nil then
                                sum = sum + (relicIndex.cards[relicID].relicId)*mult
                                mult = mult * 100
                                count = count + 1
                            end
                        end
                        if sum > 0 then
                            playerString = playerString .. oEncode(sum)
                        end
                        tails[i] = playerString
                    end
                end
            end
            resolvePlaceholders(function()
                for i = 1, 7 do
                    if heads[i] then
                        local cards = (cardVals[i] and cardVals[i][1] > 0) and oEncode(cardVals[i][1]) or ""
                        stringSoFar = stringSoFar .. heads[i] .. cards .. "#" .. tails[i] .. (i < 7 and ">" or "")
                    end
                end
                instruct("Done! The host is saving the Chronicle export.", false, true)
                nextStep()
                updateButton()
            end)
        end
    end
end

function nextStep() 
    for i, step in ipairs(steps) do
        if step == currentStep then
            if i < #steps then
                currentStep = steps[i + 1]
            else
                lastExport = scramble(stringSoFar)
                showExportString(lastExport)
                currentStep = "PreInit"
                stringSoFar = ""
                foundationMask = nil
                lineageScores = nil
                lineageInputs = {}
            end
            break
        end
    end
end

function updateButton() 
    for _, button in ipairs(self.getButtons()) do
        self.removeButton(button.index)
    end
    makeButton()
end

function outputString()
end

function skipReliquary()
    if requests then
        instructRequest()
        return
    end
    stringSoFar = stringSoFar .. ">"
    nextStep()
    advanceExportSteps()
end

function makeButton()
    local b =  {
        click_function = "advanceExportSteps",
        function_owner = self,
        label          = "",
        position       = {1.25, -0.15, 0},
        rotation       = {0, 180, 0},
        scale          = {2/4.519321, 2/1.61203337, 2/3.20494151},
        width          = 700,
        height         = 500,
        font_size      = 110,
        color          = hexToColor("#97753b"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Chronicle Exporter", 
    }
    if currentStep == "PreInit" then
        b.label = "Start\nChronicle\nExport"
        if lastExport then
            -- Small button just below the main one (with the button's 180 rotation, +z is down the label)
            self.createButton({
                click_function = "showLastExport",
                function_owner = self,
                label          = "Show Last Export",
                position       = {1.25, -0.15, 0.45},
                rotation       = {0, 180, 0},
                scale          = {2/4.519321, 2/1.61203337, 2/3.20494151},
                width          = 500,
                height         = 120,
                font_size      = 60,
                color          = hexToColor("#56372F"),
                font_color     = {1, 1, 1, 1},
                tooltip        = "Show the last Chronicle export (host only)",
            })
        end
    elseif currentStep == "Init" then
        b.label = "Ok"
    elseif currentStep == "Atlas Box" then  
        b.label = "Ready"      
    -- elseif currentStep == "World" then        
    -- elseif currentStep == "World Deck" then        
    -- elseif currentStep == "Relic Deck" then        
    -- elseif currentStep == "Dispossessed" then       
    elseif currentStep == "Reliquary" or currentStep == "Foundations" then
        b.label = "Current Step:\n" .. currentStep
        b.width = 650
        b.position = {1.4, -0.15, 0}
        local b2 =  {
            click_function = currentStep == "Reliquary" and "skipReliquary" or "skipFoundations",
            function_owner = self,
            label          = ">",
            position       = {1.05, -0.15, 0},
            rotation       = {0, 180, 0},
            scale          = {2/4.519321, 2/1.61203337, 2/3.20494151},
            width          = 100,
            height         = 500,
            font_size      = 110,
            color          = hexToColor("#8c2b29"),
            font_color     = {1, 1, 1, 1},
            tooltip        = "Skip", 
        }
        self.createButton(b2)

    -- elseif currentStep == "Players" then
    else
        b.label = "Current Step:\n" .. currentStep
    end
    self.createButton(b)
end

function showExportString(displayString)
    showExporterPanel("panel_text", function()
        Global.UI.setAttribute("panel_text_data", "text", displayString)
    end)
end

-- Object button: reopens the last export in the host's export window
function showLastExport(obj, playerColor, altClick)
    local player = Player[playerColor]
    if not (player and player.host) then
        broadcastToColor("Only the host can show the last Chronicle export.", playerColor, hexToColor("#ce2d2d"))
        return
    end
    if lastExport then showExportString(lastExport) end
end

function closePanelText(player, value, id)
    Global.UI.setAttribute("panel_text", "active", "false")
end

-- X buttons: panelId is the popup to close
function closePopup(player, panelId, id)
    Global.UI.setAttribute(panelId, "active", "false")
end

-- ---------- Global UI ----------
-- The exporter's popups are merged into the Global UI so the rest of the table's UI is kept.
-- They have no full screen overlay, so the table stays usable behind them, and each has an X to close it

local function el(tag, attributes, children, value)
    return {tag = tag, attributes = attributes, children = children or {}, value = value}
end

-- Calls this object's function from the Global UI, with an optional argument
local function handler(fn, arg)
    return self.getGUID() .. "/" .. fn .. (arg and ("(" .. arg .. ")") or "")
end

local function closeButton(panelId)
    return el("Button", {
        id = panelId .. "_close", text = "X", onClick = handler("closePopup", panelId),
        width = 40, height = 40, rectAlignment = "UpperRight", offsetXY = "-10 -10",
        fontSize = 20, fontStyle = "Bold", textColor = "#FFFFFFFF", colors = uiColors.button,
    })
end

-- A draggable popup with an X. visibility "Host" shows it (and lets it be used) only by the host
local function popup(id, width, height, rectAlignment, offsetXY, children, visibility)
    table.insert(children, closeButton(id))
    local attributes = {
        id = id, width = width, height = height, rectAlignment = rectAlignment, offsetXY = offsetXY,
        color = uiColors.panel, active = "false", allowDragging = "true", returnToOriginalPositionWhenReleased = "false",
    }
    if visibility then attributes.visibility = visibility end
    return el("Panel", attributes, children)
end

local function title(text, width, id, offsetY)
    return el("Text", {
        id = id, text = text, width = width, height = 50, rectAlignment = "UpperCenter", offsetXY = "0 " .. (offsetY or -25),
        fontSize = 28, fontStyle = "Bold", alignment = "MiddleCenter", color = uiColors.title,
    })
end

local function subtitle(text, width)
    return el("Text", {
        text = text, width = width, height = 40, rectAlignment = "UpperCenter", offsetXY = "0 -78",
        fontSize = 20, alignment = "MiddleCenter", color = uiColors.text,
    })
end

local function button(id, text, onClick, width, rectAlignment, offsetXY)
    return el("Button", {
        id = id, text = text, onClick = onClick, width = width, height = 56,
        rectAlignment = rectAlignment, offsetXY = offsetXY, fontSize = 21, fontStyle = "Bold",
        textColor = "#FFFFFFFF", colors = uiColors.button,
    })
end

-- Sits at the top of the screen for everyone and follows the export through its steps (see instruct)
local function instructionsPanel()
    return popup("chronicle_instructions", 720, 200, "UpperCenter", "0 -20", {
        title("CHRONICLE EXPORT", 600, "chronicle_instructions_title", -18),
        el("Text", {
            id = "chronicle_instructions_text", text = "", width = 660, height = 125, rectAlignment = "UpperCenter",
            offsetXY = "0 -65", fontSize = 20, alignment = "UpperCenter", color = uiColors.text,
        }),
    })
end

local function oathPanel()
    local children = {
        title("CHOOSE THE CURRENT OATH", 900),
        subtitle("Click the button matching the current Oath, or skip to leave it unset.", 960),
    }
    local spacing = 245
    for i, oath in ipairs(oaths) do
        local x = (i - (#oaths + 1) / 2) * spacing
        table.insert(children, el("Image", {
            id = "chronicle_oath_image_" .. oath.name, image = oathAssetName(oath), preserveAspect = "true",
            width = 225, height = 310, rectAlignment = "MiddleCenter", offsetXY = x .. " 15",
            raycastTarget = "false", -- the images are display only, the buttons below pick the Oath
        }))
        table.insert(children, button("chronicle_oath_" .. oath.name, string.upper(oath.name),
            handler("selectOath", oath.name), 225, "MiddleCenter", x .. " -175"))
    end
    table.insert(children, button("chronicle_oath_skip", "SKIP", handler("skipOath"), 220, "LowerCenter", "0 25"))
    return popup("chronicle_oath_overlay", 1040, 620, "MiddleCenter", "0 -40", children, "Host")
end

-- Dark text on light player colors, light text on dark ones
local function swatchTextColor(hex)
    local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
    return (0.299 * r + 0.587 * g + 0.114 * b) > 140 and "#35271FFF" or "#FFFFFFFF"
end

local function lineagePanel()
    local rowHeight = 58
    local children = {
        title("LINEAGE SCORES", 480),
        subtitle("Enter each player's lineage score (blank is 0).", 540),
    }
    for i, color in ipairs(playerColors) do
        local hex = GetOathColorHex(color) or "#FFFFFF"
        local y = -130 - (i - 1) * rowHeight
        table.insert(children, el("Panel", {
            width = 220, height = 48, rectAlignment = "UpperCenter", offsetXY = "-120 " .. y, color = hex,
        }, {
            el("Text", {
                text = string.upper(color), fontSize = 22, fontStyle = "Bold", alignment = "MiddleCenter",
                color = swatchTextColor(hex),
            }),
        }))
        table.insert(children, el("InputField", {
            id = "chronicle_lineage_" .. color, width = 220, height = 48, rectAlignment = "UpperCenter",
            offsetXY = "120 " .. y, fontSize = 24, alignment = "MiddleCenter", characterValidation = "Integer",
            characterLimit = 4, placeholder = "0", textColor = "#35271FFF", colors = "#F4E6C5|#FFFFFF|#FFFFFF|#AAAAAA",
            onValueChanged = handler("setLineageInput"),
        }))
    end
    table.insert(children, button("chronicle_lineage_save", "SAVE SCORES", handler("submitLineage"), 260, "LowerCenter", "0 25"))
    return popup("chronicle_lineage_overlay", 620, 130 + #playerColors * rowHeight + 95, "MiddleCenter", "0 -40", children, "Host")
end

local function exportStringPanel()
    return popup("panel_text", 720, 620, "MiddleCenter", "0 -40", {
        title("YOUR CHRONICLE EXPORT", 600),
        subtitle("Click the text, press Ctrl-A then Ctrl-C, and save it somewhere safe!", 680),
        el("InputField", {
            id = "panel_text_data", lineType = "MultiLineNewLine", rectAlignment = "UpperCenter", offsetXY = "0 -125",
            width = 680, height = 390, fontSize = 22, textColor = "#35271FFF", colors = "#F4E6C5|#FFFFFF|#FFFFFF|#AAAAAA",
        }),
        button("panel_text_ok", "OK", handler("closePanelText"), 200, "LowerCenter", "0 25"),
    }, "Host")
end

local exporterPanelIds = {
    chronicle_instructions = true, chronicle_oath_overlay = true, chronicle_lineage_overlay = true, panel_text = true,
}

-- XML UI images are referenced by custom asset name (and only PNG/JPG load in the UI, not webp)
function oathAssetName(oath)
    return "ChronicleWriter_Oath_" .. oath.name
end

-- Adds the Oath images to the Global UI's custom assets, keeping the ones already there.
-- Returns true if the assets changed (and are now downloading)
local function registerOathAssets()
    local assets = {}
    local byName = {}
    for _, asset in ipairs(Global.UI.getCustomAssets() or {}) do
        table.insert(assets, asset)
        byName[asset.name] = asset
    end
    local changed = false
    for _, oath in ipairs(oaths) do
        local name = oathAssetName(oath)
        if byName[name] == nil then
            table.insert(assets, {name = name, url = oath.image})
            changed = true
        elseif byName[name].url ~= oath.image then
            byName[name].url = oath.image
            changed = true
        end
    end
    if changed then Global.UI.setCustomAssets(assets) end
    return changed
end

local function whenUiLoaded(fn)
    Wait.condition(fn, function() return not Global.UI.loading end)
end

-- Replaces any earlier copy of the exporter's popups in the Global UI, keeping everything else, then calls onReady once loaded.
-- The XML is only set once the Oath images have finished downloading, since reloading the UI mid-download can drop some of them
function installExporterUi(onReady)
    local function setXml()
        local xmlTable = {}
        for _, element in ipairs(Global.UI.getXmlTable() or {}) do
            if not (element.attributes and exporterPanelIds[element.attributes.id]) then
                table.insert(xmlTable, element)
            end
        end
        table.insert(xmlTable, instructionsPanel())
        table.insert(xmlTable, oathPanel())
        table.insert(xmlTable, lineagePanel())
        table.insert(xmlTable, exportStringPanel())
        Global.UI.setXmlTable(xmlTable)
        whenUiLoaded(onReady)
    end
    whenUiLoaded(function()
        if registerOathAssets() then
            whenUiLoaded(setXml)
        else
            setXml()
        end
    end)
end

-- The popups are installed once and then reused. Global can replace its whole UI (and drop them), so check they're still there
local function exporterUiPresent()
    if Global.UI.loading then return false end
    for _, element in ipairs(Global.UI.getXmlTable() or {}) do
        if element.attributes and element.attributes.id == "chronicle_instructions" then return true end
    end
    return false
end

local uiWaiting = nil -- callbacks waiting for an install in progress, run in the order they came in

-- Runs fn once the exporter's popups are in the Global UI, installing them first if needed
function withExporterUi(fn)
    if uiWaiting then
        table.insert(uiWaiting, fn)
        return
    end
    if exporterUiPresent() then
        fn()
        return
    end
    uiWaiting = {fn}
    installExporterUi(function()
        local waiting = uiWaiting
        uiWaiting = nil
        for _, callback in ipairs(waiting) do callback() end
    end)
end

-- Runs setup (to fill in values) and shows the popup with this id
function showExporterPanel(id, setup)
    withExporterUi(function()
        if setup then setup() end
        Global.UI.setAttribute(id, "active", "true")
    end)
end
