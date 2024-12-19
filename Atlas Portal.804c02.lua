-- Atlas Box scripts written by harsch.  Last update:  12-18-2024

tableGUID = "4ee1f2"
atlasBoxGUID = "f8bd3c"
edificesGUID = "1662f7"
relicStackGUID = "09d477"
shadowBagGUID = "1ce44a"
siteBagGUID = "12dafe"

tableObj = nil
atlasBox = nil
edificeBag = nil
relicStack = nil
shadowBag = nil
siteBag = nil

setupButtonLabel = "Setup Initial\nAtlas Box\nand Sites"
retryButtonLabel = "Fix missing objects \n and click me \n to retry"
storeButtonLabel        = "← Into Atlas Box ←"
storeButtonLabelConfirm = "←    Confirm?    ←"
retrieveButtonLabel = "→ Summon a Site →"

siteTag = "Site"
relicTag = "Relic"
edificeTag = "Edifice"
shadowTag = "Shadow"
chronicleCreatedTag = "chronicleCreated"
unlockedTag = "Unlocked"

emptyAtlasSlotBagName = "[Empty] Slot"
fullAtlasSlotBagName = "[Full] Slot"

portalSites = {}
portalRelics = {}
portalEdifices = {}
portalShadow = {}

function onLoad()
    setupTags()

    atlasBox = getObjectFromGUID(atlasBoxGUID)
    if self.hasTag(chronicleCreatedTag) then
        if atlasBox == nil then
            print("ERROR: Cannot find Atlas Box Bag by GUID")
            spawnRetryButton()
            return
        elseif atlasBox then
            spawnAtlasButtons()
            return
        end
    else
        if checkForSetupObjects() then
            spawnChronicleSetupButton()
        else 
            spawnRetryButton()
        end
    end
end

function setupTags() 
    self.addTag(siteTag)
    self.addTag(relicTag)
    self.addTag(edificeTag)
    self.addTag(shadowTag)
    self.removeTag(siteTag)
    self.removeTag(relicTag)
    self.removeTag(edificeTag)
    self.removeTag(shadowTag)
    self.addTag(unlockedTag)
    self.removeTag(unlockedTag)
    if not self.hasTag(chronicleCreatedTag) then
        self.addTag(chronicleCreatedTag)
        self.removeTag(chronicleCreatedTag)
    end
end

function checkForSetupObjects()
    tableObj = getObjectFromGUID(tableGUID)
    edificeBag = getObjectFromGUID(edificesGUID)
    relicStack = getObjectFromGUID(relicStackGUID)
    shadowBag = getObjectFromGUID(shadowBagGUID)
    siteBag = getObjectFromGUID(siteBagGUID)
    if tableObj == nil then print("ERROR: Cannot find Table by GUID") end
    if atlasBox == nil then print("ERROR: Cannot find Atlas Box Bag by GUID") end
    if edificeBag == nil then print("ERROR: Cannot find Edifices Bag by GUID") end
    if relicStack == nil then print("ERROR: Cannot find Relic Stack by GUID") end
    if shadowBag == nil then print("ERROR: Cannot find Shadow Denizens Bag by GUID") end
    if siteBag == nil then print("ERROR: Cannot find Site Bag") end

    if tableObj and atlasBox and edificeBag and relicStack and shadowBag and siteBag then
        return true
    end
    return false
end

function checkForAtlasObjects()
    atlasBox = getObjectFromGUID(atlasBoxGUID)
    if atlasBox == nil then
        print("ERROR: Cannot find Atlas Box Bag by GUID")
        spawnRetryButton()
        return false
    end
    return true
end

function spawnAtlasButtons()
    refreshStoreButton()
    params = {
        click_function = "retrieveInit",
        function_owner = self,
        label          = retrieveButtonLabel,
        position       = {-1.85, 0, 0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        color          = hexToColor("#588087"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Retrieve a Site and all objects there from the Atlas Box", 
    }
    self.createButton(params)
end

function refreshStoreButton()
    stagedStorage = (#portalSites + #portalRelics + #portalEdifices + #portalShadow) > 0
    removeButtonByLabel(self, storeButtonLabel)
    removeButtonByLabel(self, storeButtonLabelConfirm)
    params = {
        click_function = "storeInit",
        function_owner = self,
        position       = {-1.85, 0, -0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        font_color     = {1, 1, 1, 1},
        label          = stagedStorage and storeButtonLabelConfirm or storeButtonLabel,
        color          = stagedStorage and hexToColor("#4a915d") or hexToColor("#588087"),
        hover_color    = stagedStorage and hexToColor("#58b872") or nil,
        tooltip        = stagedStorage and "Confirm?" or "Move Sites, Relics, Edifices and Shadow into the Atlas box", 
        
    }
    self.createButton(params)
end

function spawnChronicleSetupButton()
    params = {
        click_function = "setupAtlasBox",
        function_owner = self,
        label          = setupButtonLabel,
        -- position       = {13.212, 10.561, 14.422},
        position       = {0, 0, 2.6},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1000,
        height         = 500,
        font_size      = 130,
        color          = hexToColor("#4a915d"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Set Up the Atlas Box for a new Chronicle", 
    }
    self.createButton(params)
end

function spawnRetryButton()
    params = {
        click_function = "retry",
        function_owner = self,
        label          = retryButtonLabel,
        position       = {0, 0, 2.6},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1000,
        height         = 500,
        font_size      = 110,
        color          = hexToColor("#823030"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Place missing objects and retry", 
    }
    self.createButton(params)
end

function retry()
    removeButtonByLabel(self, retryButtonLabel)
    onLoad()
end

--
-- CHRONICLE SETUP
--

function setupAtlasBox(obj, color, alt_click)
    if not alt_click then
        if not checkForSetupObjects() then
            removeButtonByLabel(self, setupButtonLabel)
            spawnRetryButton()
            return
        end

        if #(edificeBag.getObjects()) == 0 then
            print("Please place all Edifices in the Edifice bag and try again.")
        else
            local wasUnlocked = atlasBox.hasTag(unlockedTag)
            atlasBox.addTag(unlockedTag)
            for i = 1,20 do
                local atlasSlotBag = atlasBox.takeObject({index = 20-i})
                atlasSlotBag.putObject(getRandomSite())
                local d6roll = math.random(1,6)
                print("Slot ", (i), ", Roll ", d6roll)
                if d6roll == 1 then
                    atlasSlotBag.putObject(getRandomEdifice())
                elseif d6roll == 3 then
                    atlasSlotBag.putObject(getRandomRelic())
                elseif d6roll == 4 then
                    atlasSlotBag.putObject(getRandomRelic())
                    atlasSlotBag.putObject(getRandomRelic())
                elseif d6roll == 5 then
                    atlasSlotBag.putObject(getRandomRelic())
                    atlasSlotBag.putObject(getRandomShadow())
                elseif d6roll == 6 then
                    atlasSlotBag.putObject(getRandomRelic())
                    atlasSlotBag.putObject(getRandomRelic())
                    atlasSlotBag.putObject(getRandomShadow())
                end
                atlasSlotBag.setName(fullAtlasSlotBagName)
                atlasBox.putObject(atlasSlotBag)
            end
            dealStartingSites()
            removeButtonByLabel(self, setupButtonLabel)
            self.addTag(chronicleCreatedTag)
            spawnAtlasButtons()
            if not wasUnlocked then atlasBox.removeTag(unlockedTag) end
        end
    end
end

function dealStartingSites()
    relicVector = {x = 0, y = -3, z = -1.3}
    relicVectorDelta = {x = 0.75, y = 0, z = 0}
    for i = 1,8 do
        local relicNumber = 0;
        local denizenNumber = 0;
        local atlasSlotBag = atlasBox.takeObject({index = 0})
        for _, obj in ipairs(atlasSlotBag.getObjects()) do
            if dataTableContains(obj.tags, relicTag) then
                atlasSlotBag.takeObject({
                    guid = obj.guid,
                    position = getRelicPosition(getSitePosition(i), relicNumber),
                    rotation = {x=180, y=0, z=0},
                })
                relicNumber = relicNumber+1
            end
            if dataTableContains(obj.tags, edificeTag) or dataTableContains(obj.tags, shadowTag) then
                atlasSlotBag.takeObject({
                    guid = obj.guid, 
                    position = getDenizenPosition(getSitePosition(i), denizenNumber),
                    rotation = {x=180, y=0, z=0},
                })
                denizenNumber = denizenNumber+1
            end
        end
        for _, obj in ipairs(atlasSlotBag.getObjects()) do
            if dataTableContains(obj.tags, "Site") then
                atlasSlotBag.takeObject({
                    guid = obj.guid,
                    position = getSitePosition(i),
                    rotation = {x=0, y=180, z=0},
                })
                break
            end
        end
        atlasSlotBag.setName(emptyAtlasSlotBagName)
        atlasBox.putObject(atlasSlotBag)
    end
end

-- Spawn Positions
function getSitePosition(i)
    siteOneXPos, siteYPos, siteOneZPos = 6.75, 5, 6
    xDelta, zDelta = 20.45, -5.75
    sitePositions = {
        {x = siteOneXPos, y = siteYPos, z = siteOneZPos},
        {x = siteOneXPos, y = siteYPos, z = siteOneZPos + zDelta},
        {x = siteOneXPos + xDelta, y = siteYPos, z = siteOneZPos},
        {x = siteOneXPos + xDelta, y = siteYPos, z = siteOneZPos + zDelta},
        {x = siteOneXPos + xDelta, y = siteYPos, z = siteOneZPos + zDelta*2},
        {x = siteOneXPos + xDelta*2+.5, y = siteYPos, z = siteOneZPos},
        {x = siteOneXPos + xDelta*2+.5, y = siteYPos, z = siteOneZPos + zDelta},
        {x = siteOneXPos + xDelta*2+.5, y = siteYPos, z = siteOneZPos + zDelta*2},
    }
    return sitePositions[i]
end

function getRelicPosition(position, relicNumber)
    relicVector = {x = 0, y = -3, z = -1.3}
    subsequentRelicPos = {x = 1.15*relicNumber, y = 0.25*relicNumber, z = 0}
    return vectorSum(position, vectorSum(relicVector, subsequentRelicPos))
end

function getDenizenPosition(position, denizenNumber)
    denizenVector = {x = 5.5, y = -3, z = 0.25}
    subsequentDenizenPos = {x = 3.5*denizenNumber, y = 0, z = 0}
    return vectorSum(position, vectorSum(denizenVector, subsequentDenizenPos))
end

-- Get Elements for creating Chronicle

function getRandomShadow()
    local shadow = getRandomObjectFromContainer(shadowBag, false)
    shadow.addTag(shadowTag)
    return shadow
end

function getRandomRelic()
    local relic = getRandomObjectFromContainer(relicStack, false)
    relic.addTag(relicTag)
    return relic
end

function getRandomSite()
    local site = getRandomObjectFromContainer(siteBag, false)
    site.setColorTint(Color(0,0,0))
    -- site.setColorTint(Color(1,1,1))
    site.setRotation({x=0,y=180,z=0})
    site.addTag("Site")
    return site
end

function getRandomEdifice()
    local cardOrDeck = getRandomObjectFromContainer(edificeBag, true)

    -- Someone may have put the edifices in as a deck. If they have, remove the deck and add each individual card back to the bag (and take a card afterwards).
    if cardOrDeck.type == "Deck" then
        local deckSize = #cardOrDeck.getObjects()
        local lastCard = nil
        for index, containedObject in ipairs(cardOrDeck.getObjects()) do
            if index < deckSize then
                edificeBag.putObject(cardOrDeck.takeObject({guid = containedObject.guid}))
                lastCard = cardOrDeck.remainder
            else
                edificeBag.putObject(lastCard)
            end
        end
        cardOrDeck = getRandomObjectFromContainer(edificeBag, true)
    end

    cardOrDeck.addTag(edificeTag)
    return cardOrDeck
end

--
-- ATLAS BOX STORAGE
-- 

function storeInit()
    if checkForAtlasObjects() then
        createStoringZone()
    end
end

function createStoringZone()
    createPortalZone(store)
end

function createPortalZone(callback)
    cardSize = self.getVisualBoundsNormalized()["size"]
    spawnObject({
        type = "FogOfWarTrigger",
        -- position = {0,-10,0},
        position = vectorSum(self.getPosition(), {x = 0, y = 100, z = 0}),
        scale = {cardSize["x"], 200, cardSize["z"]},
        sound = false,
        callback_function = function(spawned_object)
            -- spawned_object.setPosition(self.getPosition())
            spawned_object.setColorTint(hexToColor("#ff00ff"))
            -- Wait.time(function() store(spawned_object) end, 0.10)
            Wait.time(function()
                callback(spawned_object)
                destroyObject(spawned_object)
            end, 0.10)
            
        end
    })
end

function store(zone)
    -- First time we validate the objects and check with the user
    if #portalSites == 0 and #portalRelics == 0 and #portalEdifices == 0 and #portalShadow == 0 then
        for _, obj in ipairs(zone.getObjects(true)) do
            if obj.hasTag(siteTag) then table.insert(portalSites, obj) end
            if obj.hasTag(relicTag) then table.insert(portalRelics, obj) end
            if obj.hasTag(edificeTag) then table.insert(portalEdifices, obj) end
            if obj.hasTag(shadowTag) then table.insert(portalShadow, obj) end
        end
        messageParts = {}
        if #portalSites > 0 then table.insert(messageParts, #portalSites .. " Site") end
        if #portalRelics > 0 then table.insert(messageParts, #portalRelics .. " Relic(s)") end    
        if #portalEdifices > 0 then table.insert(messageParts, #portalEdifices .. " Edifice") end
        if #portalShadow > 0 then table.insert(messageParts, #portalShadow .. " Shadow") end
        if #messageParts > 0 then
            print("Detected " .. table.concat(messageParts, ", ") .. " on the Atlas Portal.")
            if #portalSites < 1 then
                print("ERROR: Missing a Site. Try again after placing a Site on the Atlas Portal.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portalSites > 1 then
                print("ERROR: Too many Sites. Try again after removing Sites from the Atlas Portal until there is only one.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portalRelics > 3 then
                print("ERROR: More than 3 Relics. Try again after removing some Relics from the Atlas Portal.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portalEdifices > 1 then
                print("More than 1 Edifice. This is not typical but may be an exceptionalcase with current rules.")
            end
            if #portalShadow > 1 then
                print("More than 1 Shadow. This is not typical but may be an exceptional case with current rules.")
            end
            refreshStoreButton()
            print("Click the send button again to confirm.\n")
            return
        else
            print("No objects on the Atlas Portal to send.\n")
            return
        end
    -- Subsequent times we actually store the objects into the atlasbox
    else
        -- check for all objects matching
        local perfectMatch = true
        local itemCount = #portalSites + #portalRelics + #portalEdifices + #portalShadow
        for _, obj in ipairs(zone.getObjects(true)) do
            if obj.hasTag(siteTag) then
                perfectMatch = dataTableContains(portalSites, obj)
                itemCount = itemCount - 1 
            end
            if obj.hasTag(relicTag) then
                perfectMatch = dataTableContains(portalRelics, obj)
                itemCount = itemCount - 1 
            end
            if obj.hasTag(edificeTag) then
                perfectMatch = dataTableContains(portalEdifices, obj)
                itemCount = itemCount - 1 
            end
            if obj.hasTag(shadowTag) then
                perfectMatch = dataTableContains(portalShadow, obj)
                itemCount = itemCount - 1 
            end
            if not perfectMatch then break end
        end
        if itemCount > 0 or not perfectMatch then 
            print("ERROR: Objects on the Atlas Portal have changed since the last button press. Aborting storage.\n")
            emptyStoredPortalObjs()
            return
        end

        local foundEmptyBag = false
        local wasUnlocked = atlasBox.hasTag(unlockedTag)
        atlasBox.addTag(unlockedTag)
        for i = 1, 20 do
            atlasSlotBag = atlasBox.takeObject({index = 0})
            if not foundEmptyBag and #atlasSlotBag.getObjects() == 0 then
                foundEmptyBag = true
                for _, obj in ipairs(portalSites) do
                    obj.setColorTint(Color(0,0,0))
                    atlasSlotBag.putObject(obj)
                end
                for _, obj in ipairs(portalRelics) do atlasSlotBag.putObject(obj) end
                for _, obj in ipairs(portalEdifices) do atlasSlotBag.putObject(obj) end
                for _, obj in ipairs(portalShadow) do atlasSlotBag.putObject(obj) end
                atlasSlotBag.setName(fullAtlasSlotBagName)
                print("Stored objects in Slot number ", i, "\n")
            end
            atlasBox.putObject(atlasSlotBag)
        end
        if not wasUnlocked then atlasBox.removeTag(unlockedTag) end
        emptyStoredPortalObjs()
    end
end

function emptyStoredPortalObjs()
    portalSites = {}
    portalRelics = {}
    portalEdifices = {}
    portalShadow = {}
    refreshStoreButton()
end

--
-- ATLAS BOX RETRIEVAL
-- 

function retrieveInit()
    if checkForAtlasObjects() then
        checkRetrievalZone()
    end
end

function checkRetrievalZone()
    createPortalZone(retrieve)
end

function retrieve(zone)
    if #portalSites + #portalEdifices + #portalRelics + #portalShadow > 0 then
        print("ERROR: Cannot Summon while storing sites\n")
        return
    end
    for _, obj in ipairs(zone.getObjects(true)) do
        if obj.hasTag(siteTag) or obj.hasTag(relicTag) or obj.hasTag(edificeTag) or obj.hasTag(shadowTag) then
            print("ERROR: Cannot Summon while pieces are on the Portal\n")
            return
        end
    end
    self.setLock(true)

    local d6roll = math.random(1,6)
    local heldBag = nil
    local spawnPosition = vectorSum(self.getPosition(), {x = 0, y = 5, z= 0})
    local wasUnlocked = atlasBox.hasTag(unlockedTag)
    relicNumber, denizenNumber, edificeCount, shadowCount = 0, 0, 0, 0
    atlasBox.addTag(unlockedTag)
    for i, obj in ipairs(atlasBox.getObjects()) do
        local atlasSlotBag = atlasBox.takeObject({index = 0})
        if i == d6roll then
            heldBag = atlasSlotBag
            for _, obj in ipairs(atlasSlotBag.getObjects()) do
                if dataTableContains(obj.tags, relicTag) then
                    atlasSlotBag.takeObject({
                        guid = obj.guid,
                        position = getRelicPosition(spawnPosition, relicNumber),
                        rotation = {x=180, y=0, z=0},
                    })
                    relicNumber = relicNumber+1
                end
                if dataTableContains(obj.tags, shadowTag) then
                    atlasSlotBag.takeObject({
                        guid = obj.guid, 
                        position = getDenizenPosition(spawnPosition, denizenNumber),
                        rotation = {x=180, y=0, z=0},
                    })
                    denizenNumber = denizenNumber+1
                    shadowCount = shadowCount+1
                end
            end
            for _, obj in ipairs(atlasSlotBag.getObjects()) do
                
                if dataTableContains(obj.tags, edificeTag) then
                    atlasSlotBag.takeObject({
                        guid = obj.guid, 
                        position = getDenizenPosition(spawnPosition, denizenNumber),
                        rotation = {x=180, y=0, z=0},
                    })
                    denizenNumber = denizenNumber+1
                    edificeCount = edificeCount+1
                end
                if dataTableContains(obj.tags, siteTag) then
                    atlasSlotBag.takeObject({
                        guid = obj.guid,
                        position = spawnPosition,
                        rotation = {x=0, y=180, z=0},
                    })
                    break
                end
            end
            atlasSlotBag.setName(emptyAtlasSlotBagName)
        else
            atlasBox.putObject(atlasSlotBag)
        end
    end
    messageParts = {}
    if relicNumber > 0 then table.insert(messageParts, relicNumber .. " Relic(s)") end    
    if edificeCount > 0 then table.insert(messageParts, edificeCount .. " Edifice") end
    if shadowCount > 0 then table.insert(messageParts, shadowCount .. " Shadow") end
    if #messageParts > 0 then
        print("Summoning Site from Slot " .. d6roll .. " with " .. table.concat(messageParts, ", ") .. "\n")
    else
        print("Summoning Empty Site from Slot " .. d6roll .. "\n")

    end
    atlasBox.putObject(heldBag)
    if not wasUnlocked then atlasBox.removeTag(unlockedTag) end



end

-- Override Site Flip
function onPlayerAction(player, action, targets)
    if action == Player.Action.FlipOver and #targets == 1 and targets[1].hasTag("Site") then
        if targets[1].getColorTint() == Color(0,0,0) then
            targets[1].setColorTint(Color(1,1,1))
        else
            targets[1].setColorTint(Color(0,0,0))
        end
        return false
    end
    return true
end


-- Util

function hexToColor(hex)
    -- Remove the "#" if it exists
    hex = hex:gsub("#", "")

    -- Convert each pair of hex digits to decimal and then to float
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    -- Return the RGB values as floats
    return Color(r, g, b)
end

function dataTableContains(table, x)
    found = false
    for _, obj in ipairs(table) do
        if obj == x then found = true end
    end
    return found
end

function removeButtonByLabel(holder, label)
    local buttonIndex = nil
    for i,button in ipairs(holder.getButtons()) do
        if button.label == label then
            buttonIndex = button.index
            break
        end
    end
    if buttonIndex then holder.removeButton(buttonIndex) end
end

function getButtonByLabel(holder, label)
    local buttonIndex = nil
    for i,button in ipairs(holder.getButtons()) do
        if button.label == label then
            return button
        end
    end
end

function getRandomObjectFromContainer(container, flipped)
    return container.takeObject({
        guid = container.getObjects()[math.random(1, #container.getObjects())].guid,
        position = vectorSum(container.getPosition(), {x = 0, y = 5, z = 0}),
        rotation = flipped and vectorSum({x = 180, y = 180, z = 0},container.getRotation()) or container.getRotation(),
    })
end

function vectorSum(v1, v2)
    return {
        x = v1.x + v2.x,
        y = v1.y + v2.y,
        z = v1.z + v2.z
    }
end