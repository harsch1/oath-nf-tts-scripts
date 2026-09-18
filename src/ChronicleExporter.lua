require("src/Utils/ColorUtils")
require("src/Utils/HelperFunctions")
require("src/Config/GeneralConfig")
require("src/Config/CardMapping")


local steps = {"PreInit","Init", "Atlas Box", "World", "World Deck", "Relic Deck", "Dispos", "Reliquary", "Foundations", "Players"}

currentStep = ""
stringSoFar = ""


function onLoad(state)
    if state ~= null then
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
    self.createButton(getButton())
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
        printToAll("Ensure the map is cleaned up except for the current Empire and that all Foundations are correctly flipped.==",  hexToColor("#e7ce87"))  
        printToAll("Click Ready when you're ready for the next step\n===========",  hexToColor("#e7ce87"))
        nextStep()
        updateButton()
        return
    end    
        

    if currentStep == "Atlas Box" then
        if getObjectFromGUID(GUIDs.atlasBox) == null then
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
            printToAll(stringSoFar) -- TODO: Remove this debug print
            nextStep()
        end
    end
    if currentStep == "World" then
        printToAll("Backing up Empire data...\n===========",  hexToColor("#e7ce87"))
        printToAll("TODO", hexToColor("#1ccb42"))
        nextStep()
    end
    if currentStep == "World Deck" then
        updateButton()
        printToAll("Place the World Deck in the box on the desk...\n===========",  hexToColor("#e7ce87"))
    end
    if currentStep == "Relic Deck" then
        updateButton()
        printToAll("Place the Relic Deck in the box on the desk...\n===========",  hexToColor("#e7ce87"))
    end
    if currentStep == "Dispos" then
        updateButton()
        printToAll("Place the Dispossessed deck in the box on the desk...\n===========",  hexToColor("#e7ce87"))
    end
    if currentStep == "Reliquary" then
        updateButton()
        printToAll("Place the Reliquary (as a Deck if more than one) in the box on the desk...\n===========",  hexToColor("#e7ce87"))
    end
    if currentStep == "Foundations" then
        printToAll("Backing up current Foundations...\n===========",  hexToColor("#e7ce87"))
    end
    if currentStep == "Players" then
        printToAll("Unlock the Player Archive in the bottom left corner (L key as the Host).\n Place the bag in the box on the desk...\n===========",  hexToColor("#e7ce87"))
    end

end

function onObjectEnterContainer(container, object)
    if container == self then
        if currentStep == "World Deck" then
            printToAll("Backing up World Deck...\n===========",  hexToColor("#e7ce87"))
            local mult = 1
            local sum = 0
            for _, cardObject in ipairs(object.getData().ContainedObjects) do
                local cardId = tonumber(cardObject.CardID)
                local deckNumber = math.floor(cardId / 100)
                if deckLookup[deckNumber] then
                    sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                    mult = mult * 1000
                end
            end
            stringSoFar = stringSoFar .. oEncode(sum) .. ">"
            printToAll(stringSoFar)
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Relic Deck" then
            printToAll("Backing up Relic Deck...\n===========",  hexToColor("#e7ce87"))
            local mult = 1
            local sum = 0
            for _, cardObject in ipairs(object.getData().ContainedObjects) do
                local cardId = tonumber(cardObject.CardID)
                if relicIndex.cards[cardId % 100] ~= null then
                    sum = sum + (relicIndex.cards[cardId % 100].id-400)*mult
                    mult = mult * 100
                end
            end
            stringSoFar = stringSoFar .. oEncode(sum) .. ">"
            printToAll(stringSoFar)
            nextStep()
            advanceExportSteps()
            return
        end
        if currentStep == "Dispos" then
            printToAll("Backing up Dispossessed...\n===========",  hexToColor("#e7ce87"))
            local mult = 1
            local sum = 0
            for _, cardObject in ipairs(object.getData().ContainedObjects) do
                local cardId = tonumber(cardObject.CardID)
                local deckNumber = math.floor(cardId / 100)
                if deckLookup[deckNumber] then
                    sum = sum + (cardIndex[deckLookup[deckNumber]].cards[cardId % 100].id)*mult
                    mult = mult * 1000
                end
            end
            stringSoFar = stringSoFar .. oEncode(sum) .. ">"
            printToAll(stringSoFar)
            nextStep()
            advanceExportSteps()
            return
        end
    end
end

function nextStep() 
    for i, step in ipairs(steps) do
        if step == currentStep then
            if i < #steps then
                currentStep = steps[i + 1]
            else -- TODO: Finish the export process and show the actual final export string
                showExportString("test_export")
                currentStep = "PreInit"
            end
            break
        end
    end
end

function updateButton() 
    self.removeButton(0)
    self.createButton(getButton())
end

function outputString()
end

function getButton()
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
        tooltip        = "Chornicle Exporter", 
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
    -- elseif currentStep == "Foundations" then        
    -- elseif currentStep == "Dispos" then        
    -- elseif currentStep == "Players" then        
    -- elseif currentStep == "Reliquary" then    
    else
        b.label = "Current Step:\n" .. currentStep
    end
    return b
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