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
            errors = 0
            for _, siteObject in ipairs(getObjectFromGUID(GUIDs.atlasBox).getData().ContainedObjects) do
                local siteName = siteObject.Nickname
                -- printToAll("Found site: " .. siteName)
                local mult = 100
                local sum = siteIndex[siteName]
                -- printToAll("Site index: " .. sum)
                if siteObject.ChildObjects then 
                    for _, childObject in ipairs(siteObject.ChildObjects) do
                        if childObject.Tags then
                            local objectType = ""
                            for _, tag in ipairs(childObject.Tags) do
                                objectType = ({
                                    [tags.edifice] = tags.edifice,
                                    [tags.relic] = tags.relic,
                                    [tags.card] = tags.card,
                                })[tag] or objectType
                            end
                            if objectType == tags.edifice then
                                -- printToAll("Found edifice: " .. childObject.CardID)
                                local cardId = tonumber(childObject.CardID)
                                local deckNumber = math.floor(cardId / 100)
                                if edificeDeckLookup[deckNumber] then
                                    sum = sum + (edificeIndex[edificeDeckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                    mult = mult * 1000
                                end
                            end
                            if objectType == tags.relic then
                                -- printToAll("Found relic: " .. childObject.CardID)
                                local cardId = tonumber(childObject.CardID)
                                    sum = sum + (relicIndex.cards[(cardId % 100)].id)*mult
                                    mult = mult * 1000
                            end
                            if objectType == tags.card then
                                -- printToAll("Found card: " .. childObject.CardID)
                                local cardId = tonumber(childObject.CardID)
                                local deckNumber = math.floor(cardId / 100)
                                if deckLookup[deckNumber] then
                                    sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                    mult = mult * 1000
                                end
                            end
                        end
                    end
                end
                stringSoFar = stringSoFar .. oEncode(sum) .. "#"
            end
            stringSoFar = stringSoFar .. ">"
            nextStep()
        end
    end
    if currentStep == "World" then
        errors = 0
        instruct("Backing up the Empire...")

        function processWorldObjects(objects)
            for _, object in ipairs(objects) do
                local mult = 100
                local sum = 0
                local isEmpty = true
                for _, hitItem in ipairs(object) do
                    if hitItem.hasTag(tags.site) then
                        sum = siteIndex[hitItem.getName()]
                        isEmpty = false
                        break
                    end
                end
                if not isEmpty then
                    for _, hitItem in ipairs(object) do
                        if hitItem.hasTag(tags.edifice) then
                            local cardId = tonumber(hitItem.getData().CardID)
                            local deckNumber = math.floor(cardId / 100)
                            if edificeDeckLookup[deckNumber] then
                                sum = sum + (edificeIndex[edificeDeckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                mult = mult * 1000
                            end
                        end
                        if hitItem.hasTag(tags.relic) then
                            local cardId = tonumber(hitItem.getData().CardID)
                                sum = sum + (relicIndex.cards[(cardId % 100)].id)*mult
                                mult = mult * 1000
                        end
                        if hitItem.hasTag(tags.card) then
                            local cardId = tonumber(hitItem.getData().CardID)
                            local deckNumber = math.floor(cardId / 100)
                            if deckLookup[deckNumber] then
                                sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                mult = mult * 1000
                            end
                        end
                    end
                    stringSoFar = stringSoFar .. oEncode(sum) .. "#"
                end
            end
            stringSoFar = stringSoFar .. ">"

            nextStep()
            advanceExportSteps() -- on to the World Deck instructions
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
        local sum = 0
        for i, foundation in ipairs(GUIDs.foundations) do
            local foundationCard = getObjectFromGUID(foundation.GUID)
            if foundationCard == nil then
                instruct("Could not find " .. foundation.name .. ". Make sure it's on the table and not in a deck, "
                    .. "then click the Chronicle Writer again.", true)
                return
            end
            if roundToNearest180(foundationCard.getRotation().z) == 180 then
                sum = sum + 2^(i-1)
            end
        end
        -- The section is written once the host picks the Oath (selectOath / skipOath)
        foundationMask = sum
        instruct("The host is choosing the current Oath...", false, true)
        showExporterPanel("chronicle_oath_overlay")
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

-- ---------- Oath picker ----------

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

function onObjectEnterContainer(container, object)
    if container == self then
        if currentStep == "World Deck" then
            local mult = 1
            local sum = 0
            local worldDeckString = ""
            local count = 0
            for _, cardObject in ipairs(object.getData().ContainedObjects) do
                local cardId = tonumber(cardObject.CardID)
                local deckNumber = math.floor(cardId / 100)
                if deckLookup[deckNumber] then
                    sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                    mult = mult * 400
                    count = count + 1
                    if count == 5 then
                        worldDeckString = padEncode(sum, 7) .. worldDeckString
                        mult = 1
                        sum = 0
                        count = 0
                    end
                end
            end
            if sum > 0 then
                worldDeckString = padEncode(sum, 7) .. worldDeckString
            end
            stringSoFar = stringSoFar ..worldDeckString.. ">"
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Relic Deck" then
            local mult = 1
            local sum = 0
            local relicString = ""
            local count = 0
            for _, cardObject in ipairs(object.getData().ContainedObjects) do
                local cardId = tonumber(cardObject.CardID)
                if relicIndex.cards[cardId % 100] ~= nil then
                    sum = sum + (relicIndex.cards[cardId % 100].relicId)*mult
                    mult = mult * 100
                    count = count + 1
                    if count == 5 then
                        relicString = padEncode(sum, 7) .. relicString
                        mult = 1
                        sum = 0
                        count = 0
                    end
                end
            end
            if sum > 0 then
                relicString = padEncode(sum, 7) .. relicString
            end
            stringSoFar = stringSoFar .. relicString .. ">"
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Dispossessed" then
            local mult = 1
            local sum = 0
            local disposString = ""
            local count = 0
            for _, cardObject in ipairs(object.getData().ContainedObjects) do
                local cardId = tonumber(cardObject.CardID)
                local deckNumber = math.floor(cardId / 100)
                if deckLookup[deckNumber] then
                    sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                    mult = mult * 400
                    count = count + 1
                    if count == 5 then
                        disposString = padEncode(sum, 7) .. disposString
                        mult = 1
                        sum = 0
                        count = 0
                    end
                end
            end
            if sum > 0 then
                disposString = padEncode(sum, 7) .. disposString
            end
            stringSoFar = stringSoFar ..disposString.. ">"
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Reliquary" then
            local mult = 1
            local sum = 0
            local count = 0
            if object.getData().ContainedObjects ~= nil then
                for _, cardObject in ipairs(object.getData().ContainedObjects) do
                    local cardId = tonumber(cardObject.CardID)
                    sum = sum + (relicIndex.cards[cardId % 100].relicId)*mult
                    mult = mult * 100
                    count = count + 1
                end
            elseif object.getData().CardID ~= nil then
                local cardId = tonumber(object.getData().CardID)
                sum = sum + (relicIndex.cards[cardId % 100].relicId)*mult
            end
            stringSoFar = stringSoFar .. oEncode(sum) .. ">"
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
            if object.getData().ContainedObjects ~= nil then
                local players = {}
                for _, archivedPlayer in ipairs(object.getData().ContainedObjects) do
                    players[playerBoards[JSON.decode(archivedPlayer.Memo).hotkey].order] = archivedPlayer
                end
                for i = 1, 7 do
                    local player = players[i]
                    local playerString = ""
                    -- [status: 1 digit][lineage: 2 digits][cards]#[legacies]#[relics]
                    local lineage = padEncode(lineageScores[playerColors[i]] or 0, 2)
                    if player == nil then
                        playerString = "0" .. lineage .. "##"
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
                        playerString = playerString .. oEncode(statusNum) .. lineage

                        local mult = 1
                        local sum = 0
                        local count = 0
                        for _, cardId in ipairs(cardIDs) do
                            local deckNumber = math.floor(cardId / 100)
                            if deckLookup[deckNumber] then
                                sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                mult = mult * 400
                                count = count + 1
                            end
                        end
                        if sum > 0 then
                            playerString = playerString .. oEncode(sum) .. "#"
                        else
                            playerString = playerString .. "#" 
                        end

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
                    end
                    if i == 7 then
                        stringSoFar = stringSoFar .. playerString
                    else
                        stringSoFar = stringSoFar .. playerString .. ">"
                    end
                end
            end
            instruct("Done! The host is saving the Chronicle export.", false, true)
            nextStep()
            updateButton()
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
    elseif currentStep == "Reliquary" then
        b.label = "Current Step:\n" .. currentStep
        b.width = 650
        b.position = {1.4, -0.15, 0}
        local b2 =  {
            click_function = "skipReliquary",
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

    -- elseif currentStep == "Foundations" then       
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
