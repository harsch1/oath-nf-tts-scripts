require("src/Utils/ColorUtils")
require("src/Utils/HelperFunctions")
require("src/Config/GeneralConfig")
require("src/Config/CardMapping")


local steps = {"PreInit","Init", "Atlas Box", "World", "World Deck", "Relic Deck", "Dispossessed", "Reliquary", "Foundations", "Players"}

currentStep = ""
local version = 1
stringSoFar = ""

function onLoad(state)
    if state ~= nil then
        local loadedData = JSON.decode(state)
        if loadedData then
            if loadedData.currentStep then -- TODO: revert to proper save/load
                -- currentStep = loadedData.currentStep
                currentStep = "PreInit"
            end
            if loadedData.stringSoFar then
                stringSoFar = ""
            end
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
        stringSoFar = stringSoFar
    }
    return JSON.encode(dataToSave)
end

function advanceExportSteps()
    if currentStep == "PreInit" then
        printToAll("Hello and welcome to Chronicle Exporter!", hexToColor("#c69a4e"))
        printToAll("This tool will help you export your current Chronicle in a few simple steps.\n"
        .. "Please follow the instructions in this chat to complete the export process "
        .. "and create a backup of your save that you can reload if you need to recover.", hexToColor("#e7ce87"))
        printToAll("\nWhen you're ready, click 'OK' to continue to the next step.\n===========", hexToColor("#e7ce87"))
        nextStep()
        updateButton()
        return
    end    
    if currentStep == "Init" then
        printToAll("Ensure the map is cleaned up except for the current Empire and that all Foundations are correctly flipped.",  hexToColor("#e7ce87"))  
        printToAll("Click Ready when you're ready for the next step\n===========",  hexToColor("#e7ce87"))
        nextStep()
        updateButton()
        return
    end    
        

    if currentStep == "Atlas Box" then
        if getObjectFromGUID(GUIDs.atlasBox) == nil then
            printToAll("Atlas Box not found! Please ensure the Atlas Box is on the table and try again.\n===========",  hexToColor("#e7ce87"))
            return
        else
            printToAll("Backing up Atlas Box data...\n===========",  hexToColor("#e7ce87"))
            errors = 0
            for _, siteObject in ipairs(getObjectFromGUID(GUIDs.atlasBox).getData().ContainedObjects) do
                local siteName = siteObject.Nickname
                local mult = 100
                -- printToAll("site: " .. siteName)
                local sum = siteIndex[siteName]
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
                                -- printToAll("edifice: " .. childObject.CardID)
                                local cardId = tonumber(childObject.CardID)
                                local deckNumber = math.floor(cardId / 100)
                                -- printToAll("deckNumber: " .. deckNumber .. " " .. edificeDeckLookup[deckNumber])
                                if edificeDeckLookup[deckNumber] then
                                    -- printToAll(edificeIndex[edificeDeckLookup[deckNumber]].cards[cardId % 100].id)
                                    sum = sum + (edificeIndex[edificeDeckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                    mult = mult * 1000
                                end
                            end
                            if objectType == tags.relic then
                                -- printToAll("relic: " .. childObject.CardID)
                                local cardId = tonumber(childObject.CardID)
                                    sum = sum + (relicIndex.cards[(cardId % 100)].id)*mult
                                    mult = mult * 1000
                            end
                            if objectType == tags.card then
                                -- printToAll("card: " .. childObject.CardID)
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
        printToAll("Backing up Empire data...\n===========",  hexToColor("#e7ce87"))

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
                            printToAll("edifice: " .. hitItem.getData().CardID)
                            local cardId = tonumber(hitItem.getData().CardID)
                            local deckNumber = math.floor(cardId / 100)
                            -- printToAll("deckNumber: " .. deckNumber .. " " .. edificeDeckLookup[deckNumber])
                            if edificeDeckLookup[deckNumber] then
                                -- printToAll(edificeIndex[edificeDeckLookup[deckNumber]].cards[cardId % 100].id)
                                sum = sum + (edificeIndex[edificeDeckLookup[deckNumber]].cards[cardId % 100].id)*mult
                                mult = mult * 1000
                            end
                        end
                        if hitItem.hasTag(tags.relic) then
                            printToAll("relic: " .. hitItem.getData().CardID)
                            local cardId = tonumber(hitItem.getData().CardID)
                                sum = sum + (relicIndex.cards[(cardId % 100)].id)*mult
                                mult = mult * 1000
                        end
                        if hitItem.hasTag(tags.card) then
                            printToAll("card: " .. hitItem.getData().CardID)
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
            updateButton()
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
        printToAll("Place the World Deck in the box on the desk...\n===========",  hexToColor("#e7ce87"))
        -- onObjectEnter to continue
    end
    if currentStep == "Relic Deck" then
        updateButton()
        printToAll("Place the Relic Deck in the box on the desk...\n===========",  hexToColor("#e7ce87"))
        -- onObjectEnter to continue
    end
    if currentStep == "Dispossessed" then
        updateButton()
        printToAll("Place the Dispossessed deck in the box on the desk...\n===========",  hexToColor("#e7ce87"))
        -- onObjectEnter to continue
    end
    if currentStep == "Reliquary" then
        updateButton()
        printToAll("Place the Reliquary (as a Deck if more than one) in the box on the desk...\n===========",  hexToColor("#e7ce87"))
        printToAll("If there is none, click to skip \n===========",  hexToColor("#e7ce87"))
        -- onObjectEnter to continue
    end
    if currentStep == "Foundations" then
        updateButton()
        printToAll("Backing up current Foundations...\n===========",  hexToColor("#e7ce87"))
        local sum = 0
        for i, foundation in ipairs(GUIDs.foundations) do
            local foundationCard = getObjectFromGUID(foundation.GUID)
            if foundationCard == nil then
                printToAll("Could not find " .. foundation.name .. ". Make sure it's present on the table and not in a deck.", hexToColor("#ce2d2d"))
                return
            end
            if roundToNearest180(foundationCard.getRotation().z) == 180 then
                sum = sum + 2^(i-1)
            end
        end
        stringSoFar = stringSoFar .. oEncode(sum) .. ">"
        nextStep()
    end
    if currentStep == "Players" then
        updateButton()
        printToAll("Archive all Players.\n Then, unlock the Player Archive in the bottom left corner (L key as the Host)." ..
                   "\n Place the bag in the box on the desk...\n===========",  hexToColor("#e7ce87"))
    end
end

function onObjectEnterContainer(container, object)
    if container == self then
        if currentStep == "World Deck" then
            printToAll("Backing up World Deck...\n===========",  hexToColor("#e7ce87"))
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
            -- updateButton()
            advanceExportSteps()
            return
        end
        if currentStep == "Relic Deck" then
            printToAll("Backing up Relic Deck...\n===========",  hexToColor("#e7ce87"))
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
            printToAll("Backing up Dispossessed...\n===========",  hexToColor("#e7ce87"))
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
            printToAll("Backing up Reliquary...\n===========",  hexToColor("#e7ce87"))
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
                    if player == nil then
                        playerString = "0##"
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
                        playerString = playerString .. oEncode(statusNum)

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
            printToAll(scramble(stringSoFar))
            nextStep()

        end
    end
end

function nextStep() 
    for i, step in ipairs(steps) do
        if step == currentStep then
            if i < #steps then
                currentStep = steps[i + 1]
            else -- TODO: Finish the export process and show the actual final export string
                showExportString(scramble(stringSoFar))
                currentStep = "PreInit"
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
        position       = {0, -0.4, 1.2},
        width          = 700,
        height         = 500,
        font_size      = 110,
        color          = hexToColor("#97753b"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Chronicle Exporter", 
    }
    if currentStep == "PreInit" then
        b.label = "Start\nChronicle\nExport"
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
        b.position = {-0.150, -0.4, 1.2}
        local b2 =  {
            click_function = "skipReliquary",
            function_owner = self,
            label          = ">",
            position       = {0.650, -0.4, 1.2},
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
    addTextInputToXml()

    Global.UI.setAttribute("panel_text_description", "text", "Copy to the clipboard to\nexport your Chronicle state  \n(click, then press Ctrl-C)")
    Global.UI.setAttribute("panel_text_data", "text", displayString)
    Global.UI.setAttribute("ok_panel_text", "active", true)
    Global.UI.setAttribute("ok_panel_text", "textColor", "#FFFFFFFF")
    Global.UI.setAttribute("panel_text", "active", true)
end

function closePanelText(player, value, id)
    Global.UI.setAttribute("panel_text", "active", false)
    Global.UI.setAttribute("ok_panel_text", "active", false)
end

function addTextInputToXml()
    local panelTextXml = [[
     <Panel id="panel_text" offsetXY="0 0" active="false" rectAlignment="MiddleCenter" width="700" height="700" image="menu_text" allowDragging="true" returnToOriginalPositionWhenReleased="false" color="#c69a4e" >
          <Text id="panel_text_description" offsetXY="0 270" width="600" height="150" fontSize="40" fontStyle="Bold" color="#000000FF"></Text>
          <InputField id="panel_text_data" lineType="MultiLineNewLine" offsetXY="0 -30" width="670" height="400" fontSize="24" colors="#FFFFFF40|#FFFFFF40|#FFFFFF40|#FFFFFF40" textColor="#000000FF" onEndEdit="panelTextEndEdit"></InputField>
          <Button id="ok_panel_text" active="false" offsetXY="0 -290" width="134" height="54" onClick="]] .. self.getGUID() .. [[/closePanelText()" fontSize="32" colors="#444444FF|#606060FF|#747474FF|#00000000" textColor="#FFFFFFFF">OK</Button>
     </Panel>
    ]]

    local xmlTable = Global.UI.getXmlTable()
    local hasPanelAlready = false
    for _, element in ipairs(xmlTable) do
        if element.tag == "Panel" and element.attributes.id == "panel_text" then
            hasPanelAlready = true
            break
        end
    end
    if not hasPanelAlready then
        Global.UI.setXml(Global.UI.getXml() .. " " .. panelTextXml)
    end

    
end