-- Atlas Box scripts written by harsch.  Last update:  12-18-2024

-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
tableGUID = "4ee1f2"
atlasBoxGUID = "f8bd3c"
edificesGUID = "1662f7"
relicBagGUID = "c46336"
shadowBagGUID = "1ce44a"
siteBagGUID = "12dafe"
curseDeckGUID = "28df64"

-- Objects for needed items.
tableObj, atlasBox, edificeBag, relicBag, shadowBag, siteBag = nil, nil, nil, nil, nil, nil

-- Labels for buttons.
setupButtonLabel = "Setup Initial\nAtlas Box\nand Sites"
retryButtonLabel = "Fix missing objects \n and click me \n to retry"
storeButtonLabel        = "← Into Atlas Box ←"
storeButtonLabelConfirm = "←    Confirm?    ←"
retrieveButtonLabel = "→ Summon a Site →"
spawnRelicsButtonLabel = "Retrieve Lost Relics"

-- Tags to identify items
siteTag = "Site"
relicTag = "Relic"
edificeTag = "Edifice"
shadowTag = "Shadow"

-- Tag for marking that set up is complete
chronicleCreatedTag = "chronicleCreated"

-- Tag to mark the atlas box as locked or unlocked
unlockedTag = "Unlocked"

-- Name strings to use for Atlas Slots depending on their states
emptyAtlasSlotBagName = "[Empty] Slot"
fullAtlasSlotBagName = "[Full] Slot"

-- Tables to track things on the portal
portalSites = {}
portalRelics = {}
portalEdifices = {}
portalShadow = {}

function onLoad()
    setupTags()

    atlasBox = getObjectFromGUID(atlasBoxGUID)
    if self.hasTag(chronicleCreatedTag) then
        if atlasBox == nil then
            printToAll("ERROR: Cannot find Atlas Box Bag by GUID")
            spawnRetryButton()
            return
        end
        spawnAtlasButtons()
        return
    else
        if checkForSetupObjects() then
            tagAllItems()
            spawnChronicleSetupButton()
        else 
            spawnRetryButton()
        end
    end
end

-- Create all needed tags by adding them to this object and then removing them
function setupTags() 
    tags = {siteTag, relicTag, edificeTag, shadowTag, unlocked}
    for _, tag in ipairs(tags) do
        self.addTag(tag)
        self.removeTag(tag)
    end
    -- We don't want to overwrite the value if the tag is already there
    if not self.hasTag(chronicleCreatedTag) then
        self.addTag(chronicleCreatedTag)
        self.removeTag(chronicleCreatedTag)
    end
end

-- Validate that setup objects can be found 
function checkForSetupObjects()
    tableObj = getObjectFromGUID(tableGUID)
    edificeBag = getObjectFromGUID(edificesGUID)
    relicBag = getObjectFromGUID(relicBagGUID)
    shadowBag = getObjectFromGUID(shadowBagGUID)
    siteBag = getObjectFromGUID(siteBagGUID)
    if not tableObj then printToAll("ERROR: Cannot find Table by GUID") end
    if not atlasBox then printToAll("ERROR: Cannot find Atlas Box Bag by GUID") end
    if not edificeBag then printToAll("ERROR: Cannot find Edifices Bag by GUID") end
    if not relicBag then printToAll("ERROR: Cannot find Relic Bag by GUID") end
    if not shadowBag then printToAll("ERROR: Cannot find Shadow Denizens Bag by GUID") end
    if not siteBag then printToAll("ERROR: Cannot find Site Bag") end

    if tableObj and atlasBox and edificeBag and relicBag and shadowBag and siteBag then
        return true
    end
    return false
end

-- Check that the Atlas Box can be found
function checkForAtlasObjects()
    atlasBox = getObjectFromGUID(atlasBoxGUID)
    if atlasBox == nil then
        printToAll("ERROR: Cannot find Atlas Box Bag by GUID")
        spawnRetryButton()
        return false
    end
    return true
end

-- Create the Buttons for working with the AtlasBox
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
    params = {
        click_function = "spawnRelics",
        function_owner = self,
        label          = spawnRelicsButtonLabel,
        position       = {0, 0, 2.1},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1050,
        height         = 250,
        font_size      = 80,
        font_color     = hexToColor("#e6bb4a"),
        color          = hexToColor("##8a363b"),
        tooltip        = "Retrieve 10 relics from the Atlas Box if you run out", 
    }
    self.createButton(params)
end

-- Create the button for storing items in the atlas box.
--    This button is dynamic and will change text and color for confirming storage 
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

-- Create the button for setting up the initial chronicle
function spawnChronicleSetupButton()
    params = {
        click_function = "setupAtlasBox",
        function_owner = self,
        label          = setupButtonLabel,
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

-- Create the button for retrying a load if something is missing
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
        -- If items are missing we need to retry setup
        if not checkForSetupObjects() then
            removeButtonByLabel(self, setupButtonLabel)
            spawnRetryButton()
            return
        end

        -- If edifice bag is empty
        if #(edificeBag.getObjects()) == 0 then
            printToAll("Please place all Edifices in the Edifice bag and try again.")
        else
            -- Gotta unlock the Atlas Box first
            local wasUnlocked = atlasBox.hasTag(unlockedTag)
            atlasBox.addTag(unlockedTag)
            -- Take all 20 sites and put them in the Atlas Box. Roll a d6 and add additional items depending on the roll
            for i = 1,20 do
                local atlasSlotBag = atlasBox.takeObject({index = 20-i})
                atlasSlotBag.putObject(getRandomSite())
                local d6roll = math.random(1,6)
                printToAll("Slot " .. i .. ", Roll " .. d6roll)
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
                -- Rename the slot bag and put it at the back of the Atlas Box
                atlasSlotBag.setName(fullAtlasSlotBagName)
                atlasBox.putObject(atlasSlotBag)
            end
            dealStartingSites()
            
            -- Clean up the setup button, mark setup as done and spawn the new buttons
            removeButtonByLabel(self, setupButtonLabel)
            self.addTag(chronicleCreatedTag)
            destroyObject(siteBag)
            for _,_ in ipairs(edificeBag.getObjects()) do
                edificeBag.takeObject({rotation = {x=0,y=180,z=0}})
            end
            destroyObject(edificeBag)
            printToAll("SETUP COMPLETE. Don't forget to add Edifices back to the corresponding suit decks before setting up the World Deck\n")
            spawnAtlasButtons()
            -- Lock the Atlas Box if it was locked before
            if not wasUnlocked then atlasBox.removeTag(unlockedTag) end
        end
    end
end

function spawnRelics()
    local relicCount = 0    
    local wasUnlocked = atlasBox.hasTag(unlockedTag)
    atlasBox.addTag(unlockedTag)
    for i = 1, 20 do
        atlasSlotBag = atlasBox.takeObject({index = 0})
        if relicCount < 10 and #atlasSlotBag.getObjects() > 1 then
            for _, item in ipairs(atlasSlotBag.getObjects()) do
                item = atlasSlotBag.takeObject({guid = item.guid})
                if relicCount < 10 and item.hasTag(relicTag) then
                    relicBag.putObject(item)
                    relicCount = relicCount + 1
                else 
                    atlasSlotBag.putObject(item)
                end
            end
        end
        atlasBox.putObject(atlasSlotBag)
    end
    atlasBox.addTag(wasUnlocked)
    printToAll("Retrieved " .. relicCount .. " relics from the AtlasBox")
end


function dealStartingSites()
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
                if dataTableContains(obj.tags, shadowTag) then
                    if getObjectFromGUID(curseDeckGUID) then
                        getObjectFromGUID(curseDeckGUID).takeObject({
                            position = vectorSum(getDenizenPosition(getSitePosition(i), denizenNumber), {x=0, y=0, z=0.55}),
                            rotation = {x=180, y=math.random(0,1)*180, z=0},
                        })
                    else
                        printToAll("Cannot find curse deck. Please place curses under shadow denizens")
                    end
                end
                atlasSlotBag.takeObject({
                    guid = obj.guid, 
                    position = vectorSum(
                        getDenizenPosition(getSitePosition(i), denizenNumber),
                        (dataTableContains(obj.tags, shadowTag) and {x=0, y=0, z=-.9} or {x=0,y=0,z=0})),
                    rotation = dataTableContains(obj.tags, shadowTag) and {x=0, y=180, z=0} or {x=180, y=0, z=0},
                })
                denizenNumber = denizenNumber+1
            end
        end
        -- Deal Sites after since they go on top
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
        -- Rename the bag to mark as empty
        atlasSlotBag.setName(emptyAtlasSlotBagName)
        atlasBox.putObject(atlasSlotBag)
    end
end

-- Spawn Positions
function getSitePosition(i)
    siteOneXPos, siteYPos, siteOneZPos = 6.75, 2, 6
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

-- Add relic position offset based on which number relic it is
function getRelicPosition(position, relicNumber)
    relicVector = {x = 0, y = -0.5, z = -1.3}
    subsequentRelicPos = {x = 1.15*relicNumber, y = 0.25*relicNumber, z = 0}
    return vectorSum(position, vectorSum(relicVector, subsequentRelicPos))
end

-- Add denizen position offset based on which number relic it is
function getDenizenPosition(position, denizenNumber)
    denizenVector = {x = 5.5, y = -0.25, z = 0.25}
    subsequentDenizenPos = {x = 3.5*denizenNumber, y = 0, z = 0}
    return vectorSum(position, vectorSum(denizenVector, subsequentDenizenPos))
end

-- Get Elements for creating Chronicle


function getRandomShadow()
    return getRandomObjectFromContainer(shadowBag, false)
end

-- tag all relics
function getRandomRelic()
    return getRandomObjectFromContainer(relicBag, false)
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
    return getRandomObjectFromContainer(edificeBag, true)
end

function tagAllItems()
    bagTags = { 
        {bag = relicBag,    tag = relicTag},
        {bag = edificeBag,  tag = edificeTag},
        {bag = shadowBag,   tag = shadowTag} }
    for _, bagTag in ipairs(bagTags) do
        bag = bagTag.bag
        tag = bagTag.tag
        for _, item in ipairs(bag.getObjects()) do
            item = bag.takeObject({guid = item.guid})
            if item.type == "Deck" then
                deck = item
                local deckSize = #item.getObjects()
                local lastCard = nil
                for index, containedObject in ipairs(item.getObjects()) do
                    if index < deckSize then
                        containedObject = deck.takeObject({guid = containedObject.guid})
                        containedObject.addTag(tag)
                        lastCard = deck.remainder
                        bag.putObject(containedObject)
                    else
                        lastCard.addTag(tag)
                        bag.putObject(lastCard)
                    end
                end
            else
                item.addTag(tag)
                bag.putObject(item)
            end
        end
    end
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
            printToAll("Detected " .. table.concat(messageParts, ", ") .. " on the Atlas Portal.")
            if #portalSites < 1 then
                printToAll("ERROR: Missing a Site. Try again after placing a Site on the Atlas Portal.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portalSites > 1 then
                printToAll("ERROR: Too many Sites. Try again after removing Sites from the Atlas Portal until there is only one.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portalRelics > 3 then
                printToAll("ERROR: More than 3 Relics. Try again after removing some Relics from the Atlas Portal.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portalEdifices > 1 then
                printToAll("More than 1 Edifice. This is not typical but may be an exceptionalcase with current rules.")
            end
            if #portalShadow > 1 then
                printToAll("More than 1 Shadow. This is not typical but may be an exceptional case with current rules.")
            end
            refreshStoreButton()
            printToAll("Click the send button again to confirm.\n")
            return
        else
            printToAll("No objects on the Atlas Portal to send.\n")
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
            printToAll("ERROR: Objects on the Atlas Portal have changed since the last button press. Aborting storage.\n")
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
                printToAll("Stored objects in Slot number " .. i .. "\n")
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
        printToAll("ERROR: Cannot Summon while storing sites\n")
        return
    end
    for _, obj in ipairs(zone.getObjects(true)) do
        if obj.hasTag(siteTag) or obj.hasTag(relicTag) or obj.hasTag(edificeTag) or obj.hasTag(shadowTag) then
            printToAll("ERROR: Cannot Summon while pieces are on the Portal\n")
            return
        end
    end
    self.setLock(true)

    local d6roll = math.random(1,6)
    -- local heldBag = nil
    local spawnPosition = vectorSum(self.getPosition(), {x = 0, y = 5, z= 0})
    relicNumber, denizenNumber, edificeCount, shadowCount = 0, 0, 0, 0
    local wasUnlocked = atlasBox.hasTag(unlockedTag)
    atlasBox.addTag(unlockedTag)
    -- for i, obj in ipairs(atlasBox.getObjects()) do
    local atlasSlotBag = atlasBox.takeObject({index = d6roll-1})
    -- if i == d6roll then
    -- heldBag = atlasSlotBag
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
-- else
    atlasBox.putObject(atlasSlotBag)
        -- end
    -- end
    messageParts = {}
    if relicNumber > 0 then table.insert(messageParts, relicNumber .. " Relic(s)") end    
    if edificeCount > 0 then table.insert(messageParts, edificeCount .. " Edifice") end
    if shadowCount > 0 then table.insert(messageParts, shadowCount .. " Shadow") end
    if #messageParts > 0 then
        printToAll("Summoning Site from Slot " .. d6roll .. " with " .. table.concat(messageParts, ", ") .. "\n")
    else
        printToAll("Summoning Empty Site from Slot " .. d6roll .. "\n")

    end
    -- atlasBox.putObject(heldBag)
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
    if holder.getButtons() then
        for i, button in ipairs(holder.getButtons()) do
            if button and button.label == label then
                buttonIndex = button.index
                break
            end
        end
        if buttonIndex then holder.removeButton(buttonIndex) end
    end
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