-- Atlas Box scripts written by harsch and Frack.  Last update:  03-07-2025

require("src/Utils/ColorUtils")
require("src/Config/GeneralConfig")
require("src/Config/AtlasPortalButtons")
require("src/Utils/HelperFunctions")

-- Objects for needed game objects.
local objects = {
    atlasBox = nil,
    relicBag = nil,
    siteBag = nil,
    table = nil,
    map = nil,
}

local mapTransform = nil

-- ==============================
-- INITIALIZATION
-- ==============================

function onLoad()
    -- Create all needed tags by adding them to this object and then removing them
    local tagsToAdd = {tags.site, tags.relic, tags.edifice, tags.unlocked}
    for _, tag in ipairs(tagsToAdd) do
        self.addTag(tag)
        self.removeTag(tag)
    end

    local chronicleExists = self.hasTag(tags.chronicleCreated)
    -- If the chronicle is already created we can skip setup
    if chronicleExists and setupAtlasBox() then
        refreshStoreButton()
        createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack)
        return
    -- If the chronicle is not created we need to spawn setup buttons
    elseif not chronicleExists then
        if setupObjects() then
            tagAllItems() -- Tag all items in the bags
            self.createButton(buttons.setup)
        else 
            self.createButton(buttons.retry)
        end
    end
end

-- Validate that setup objects can be found and set them
function setupObjects()
    local setupTable = {
        {objectName = "table", GUID = GUIDs.table, printableName = "Table"},
        {objectName = "atlasBox", GUID = GUIDs.atlasBox, printableName = "Atlas Box Bag"},
        {objectName = "relicBag", GUID = GUIDs.relicBag, printableName = "Relic Bag"},
        {objectName = "siteBag", GUID = GUIDs.siteBag, printableName = "Site Bag"},
        {objectName = "map", GUID = GUIDs.map, printableName = "Map"}
    }
    local foundAll = true
    for _, setupItem in ipairs(setupTable) do
        objects[setupItem.objectName] = getObjectFromGUID(setupItem.GUID)
        if objects[setupItem.objectName] == nil then
            printToAll("ERROR: Cannot find " .. setupItem.printableName .. " by GUID")
            foundAll = false
        end
    end
    return foundAll
end

-- Check that the Atlas Box can be found
function setupAtlasBox()
    objects.atlasBox = getObjectFromGUID(GUIDs.atlasBox)
    if objects.atlasBox == nil then
        printToAll("ERROR: Cannot find Atlas Box Bag by GUID")
        self.createButton(buttons.retry)
        return false
    end
    return true
end

-- Create the button for storing items in the atlas box.
--    This button is dynamic and will change text and color for confirming storage 
function refreshStoreButton()
    local staged = #portal.sites + #portal.relics + #portal.edifices > 0
    removeButtons(buttons.storeUnstaged, buttons.storeStaged)
    self.createButton(staged and buttons.storeStaged or buttons.storeUnstaged)
end

-- Remove all buttons
function retry()
    removeButtons(buttons.retry)
    onLoad()
end

-- Tag all items in bags
function tagAllItems()
    local bagTags = { 
        {bag = objects.relicBag,    tag = tags.relic},
    }
    for _, bagTag in ipairs(bagTags) do
        local bag, tag = bagTag.bag, bagTag.tag
        for _, item in ipairs(bag.getObjects()) do
            bag.putObject(addTagAndReturn(bag.takeObject({guid = item.guid}), tag))
        end
    end
end

-- ==============================
-- CHRONICLE SETUP
-- ==============================

function chronicleSetup(obj, color, alt_click)
    function chronicleSetupCoroutine()
        if not alt_click then
            -- If items are missing we need to retry setup
            if not setupObjects() then
                removeButtons(buttons.setup)
                self.createButton(buttons.retry)
                return
            end
            mapTransform = {position = objects.map.getPosition(), rotation = objects.map.getRotation()}
            -- Take all sites and put them in the Atlas Box. Roll a d6 and add additional items depending on the roll
            local numSites = #objects.siteBag.getObjects()
            for i = 0, #objects.atlasBox.getObjects()-1 do
                local atlasSlotBag = getAtlasBag(0)
                if i < numSites then
                    atlasSlotBag.putObject(getRandomSite())
                    coroutine.yield(0)
                end
                putAtlasBag(atlasSlotBag)
                coroutine.yield(0)
            end
            -- Deal Starting Sites
            for siteNumber = 1,8 do
                local atlasSlotBag = getAtlasBag(0)
                spawnAllFromBagAtTransform(atlasSlotBag, getTransformStruct("site", siteNumber, mapTransform), true)
                coroutine.yield(0)
            end
            destroyObject(objects.siteBag)

            createRelicDeck()
            destroyObject(objects.relicBag)
            
            generateNewWorldDeck()

            -- Clean up the bags and add the chronicle created tag
            self.addTag(tags.chronicleCreated)
            removeButtons(buttons.setup)
            printToAll("ATLAS SETUP COMPLETE.\n")
            refreshStoreButton()
            createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack)
            createDispossessed()
            printToAll("WORLD DECK SETUP COMPLETE.\n")
            
        end
        return 1
    end
    startLuaCoroutine(self, "chronicleSetupCoroutine")
end

function generateNewWorldDeck() 
    local decks = getArchiveDecks()
    local firstCard = nil
    local worldDeck = nil
    -- add 9 cards from each suit
    for _, suit in ipairs(suits) do
        local deck = decks[suit]
        deck.setRotation({0,180,180})
        deck.shuffle()
        for i=1, 9 do
            local newCard = deck.takeObject();
            coroutine.yield(0)
            if firstCard == nil then
                local deckPosition = getTransformStruct("worldDeck", 0, mapTransform)
                firstCard = newCard
                firstCard.setPosition(deckPosition.position)
                firstCard.setRotation(deckPosition.rotation)
            elseif worldDeck == nil then
                worldDeck = firstCard.putObject(newCard)
                worldDeck.setName("World Deck")
            else
                worldDeck.putObject(newCard)
            end
        end
    end
end

function createRelicDeck()
    local firstRelic = nil
    local relicDeck = nil
    for _, item in ipairs(objects.relicBag.getObjects()) do
        local relic = objects.relicBag.takeObject()
        coroutine.yield(0)
        local deckPosition = getTransformStruct("relicStack", 0, mapTransform)
        if firstRelic == nil then
            firstRelic = relic
            firstRelic.setPosition(deckPosition.position)
            firstRelic.setRotation(deckPosition.rotation)
        elseif relicDeck == nil then
            relicDeck = firstRelic.putObject(relic)
            relicDeck.setName("Relic Deck")
        else
            relicDeck.putObject(relic)
        end
        coroutine.yield(0)
    end
end

function createDispossessed() 
    local decks = getArchiveDecks()
    local firstCard = nil
    local dispossessed = nil
    -- add 2 cards from each suit
    for _, suit in ipairs(suits) do
        local deck = decks[suit]
        deck.shuffle()
        for i=1, 2 do
            local newCard = deck.takeObject();
            coroutine.yield(0)
            if firstCard == nil then
                local deckPosition = getTransformStruct("dispossessed", 0, mapTransform)
                firstCard = newCard
                firstCard.setPosition(deckPosition.position)
                firstCard.setRotation(deckPosition.rotation)
            elseif dispossessed == nil then
                dispossessed = firstCard.putObject(newCard)
                dispossessed.setName("Dispossessed")
            else
                dispossessed.putObject(newCard)
            end
        end
    end
end

-- Get Elements for creating Chronicle
function getRandomRelic()
    return getRandomObjectFromContainer(objects.relicBag, false)
end
function getRandomSite()
    local site = getRandomObjectFromContainer(objects.siteBag, false)
    addTagAndReturn(site, tags.site).setRotation({x=0,y=180,z=0})
    return site
end


-- ==============================
-- ATLAS BOX STORAGE
-- ==============================

-- Called by button
function storeInit()
    if setupAtlasBox() then
        createPortalZone(store)
    end
end

-- Creates zone for storing objects and calls the callback
function createPortalZone(callback)
    local cardSize = self.getVisualBoundsNormalized()["size"]
    spawnObject({
        type = "FogOfWarTrigger",
        position = vectorSum(self.getPosition(), {x = 0, y = 100, z = 0}),
        scale = {cardSize.x, 200, cardSize.z},
        sound = false,
        callback_function = function(spawned_object)
            spawned_object.setColorTint(hexToColor("#ff00ff"))
            Wait.time(function()
                callback(spawned_object)
                destroyObject(spawned_object)
            end, 0.10)
            
        end
    })
end

-- Store objects in the Atlas Box
function store(zone)
    local tagsAndPortalObjs = {
        {tag = tags.site, data = portal.sites, printableName = "Site", },
        {tag = tags.relic, data = portal.relics, printableName = "Relic(s)"},
        {tag = tags.edifice, data = portal.edifices, printableName = "Locked Card(s)"},
    }
    
    -- First time we validate the objects and check with the user
    if #portal.sites + #portal.relics + #portal.edifices == 0 then
        countAndValidatePortalItems(zone, tagsAndPortalObjs)
        return

    -- Subsequent times we actually store the objects into the atlasbox
    else
        -- Check that all objects match last button press
        local perfectMatch = true
        local itemCount = #portal.sites + #portal.relics + #portal.edifices
        for _, obj in ipairs(zone.getObjects(true)) do
            for _, tagAndPortalObj in ipairs(tagsAndPortalObjs) do
                if obj.hasTag(tagAndPortalObj.tag) then
                    perfectMatch = dataTableContains(tagAndPortalObj.data, obj)
                    itemCount = itemCount - 1
                end
            end
            if not perfectMatch then break end
        end
        if itemCount > 0 or not perfectMatch then 
            printToAll("ERROR: Objects on the Atlas Portal have changed since the last button press. Aborting storage.\n")
            emptyStoredPortalObjs()
            return
        end

        -- Store the objects in the Atlas Box in the empty slot closest to the front
        local foundEmptyBag = false
        for i = 1, #objects.atlasBox.getObjects() do
            local atlasSlotBag = getAtlasBag(0)
            if not foundEmptyBag and #atlasSlotBag.getObjects() == 0 then
                foundEmptyBag = true
                for _, data in ipairs(tagsAndPortalObjs) do
                    for _, obj in ipairs(data.data) do
                        atlasSlotBag.putObject(obj)
                    end
                end
                printToAll("Stored objects in Slot number " .. i .. "\n")
            end
            putAtlasBag(atlasSlotBag)
        end
        emptyStoredPortalObjs()
    end
end

function countAndValidatePortalItems(zone, tagsAndPortalObjs)
    for _, obj in ipairs(zone.getObjects(true)) do
        for _, tagAndPortalObj in ipairs(tagsAndPortalObjs) do
            if obj.hasTag(tagAndPortalObj.tag) then table.insert(tagAndPortalObj.data, obj) end
        end
    end
    local messageParts = {}
    for _, tagAndPortalObj in ipairs(tagsAndPortalObjs) do
        if #tagAndPortalObj.data > 0 then
            table.insert(messageParts, #tagAndPortalObj.data .. " " .. tagAndPortalObj.printableName)
        end
    end
    if #messageParts > 0 then
        printToAll("Detected " .. table.concat(messageParts, ", ") .. " on the Atlas Portal.")
        if not #portal.sites == 0 or #portal.relics > 3 then 
            if #portal.sites < 1 then printToAll("ERROR: Missing a Site. Try again after placing a Site on the Atlas Portal.\n") end
            if #portal.sites > 1 then printToAll("ERROR: Too many Sites. Try again after removing Sites from the Atlas Portal until there is only one.\n") end
            if #portal.relics > 3 then printToAll("ERROR: More than 3 Relics. Try again after removing some Relics from the Atlas Portal.\n") end
            emptyStoredPortalObjs()
            return
        end
        refreshStoreButton()
        printToAll("Click the send button again to confirm.\n")
    else
        printToAll("No objects on the Atlas Portal to send.\n")
    end
end

function emptyStoredPortalObjs()
    portal.sites, portal.relics, portal.edifices = {}, {}, {} 
    refreshStoreButton()
end

-- ==============================
-- ATLAS BOX RETRIEVAL
-- ==============================

function retrieveInit()
    if setupAtlasBox() then
        createPortalZone(retrieve)
    end
end

function retrieve(zone)
    if not isPortalEmpty(zone) then
        return
    end

    -- Set up variables for spawning
    local spawnTransform = getTransformStruct("portal", 0, {position= self.getPosition(), rotation = self.getRotation()})
    local countsAndTags = {
        {tag = tags.relic, data = {count = 0, printName = "Relic(s)"}},
        {tag = tags.edifice, data = {count = 0, printName = "Locked Card(s)"}},
    }

    -- Spawn the frontmost bags contents
    local atlasSlotBag = getAtlasBag(0)
    for _, obj in ipairs(atlasSlotBag.getObjects()) do
        for _, countAndTag in ipairs(countsAndTags) do
            if dataTableContains(obj.tags, countAndTag.tag) then
                countAndTag.data.count = countAndTag.data.count + 1
            end
        end
    end
    self.setLock(true)
    spawnAllFromBagAtTransform(atlasSlotBag, spawnTransform, false)
    
    -- Print message with what was summoned
    local messageParts = {}
    for _, countAndTag in ipairs(countsAndTags) do
        if countAndTag.data.count > 0 then
            table.insert(messageParts, countAndTag.data.count .. " " .. countAndTag.data.printName)
        end
    end
    printToAll(#messageParts > 0 and ("Summoning Site with " .. table.concat(messageParts, ", ") .. "\n") or ("Summoning Empty Site\n"))
end

function retrieveBackInit()
    if setupAtlasBox() then
        createPortalZone(retrieveBack)
    end
end

function retrieveBack(zone)
    if not isPortalEmpty(zone) then
        return
    end

    -- Set up variables for spawning
    local spawnTransform = getTransformStruct("portal", 0, {position= self.getPosition(), rotation = self.getRotation()})
    local countsAndTags = {
        {tag = tags.relic, data = {count = 0, printName = "Relic(s)"}},
        {tag = tags.edifice, data = {count = 0, printName = "Locked Card(s)"}},
    }

    -- Get the backmost full bag
    local lastFullBagIndex = 0
    for i = 0, #objects.atlasBox.getObjects()-1 do
        local atlasSlotBag = getAtlasBag(0)
        if #atlasSlotBag.getObjects() > 0 then
            lastFullBagIndex = i
        end
        putAtlasBag(atlasSlotBag)
    end

    -- Spawn the backmost bags contents
    local atlasSlotBag = getAtlasBag(lastFullBagIndex)
    for _, obj in ipairs(atlasSlotBag.getObjects()) do
        for _, countAndTag in ipairs(countsAndTags) do
            if dataTableContains(obj.tags, countAndTag.tag) then
                countAndTag.data.count = countAndTag.data.count + 1
            end
        end
    end
    self.setLock(true)
    spawnAllFromBagAtTransform(atlasSlotBag, spawnTransform, false)
    
    -- Print message with what was summoned
    local messageParts = {}
    for _, countAndTag in ipairs(countsAndTags) do
        if countAndTag.data.count > 0 then
            table.insert(messageParts, countAndTag.data.count .. " " .. countAndTag.data.printName)
        end
    end
    printToAll(#messageParts > 0 and ("Summoning Site with " .. table.concat(messageParts, ", ") .. "\n") or ("Summoning Empty Site\n"))
end

--- ==============================
--- ATLAS BOX RELIC RETRIEVAL
--- ==============================

-- Try to get 10 relics from the Atlas Box 
function spawnRelics()
    local relicCount = 0    
    for i = 1, #objects.atlasBox.getObjects() do
        local atlasSlotBag = getAtlasBag(0)
        local mapTransform = {position = objects.map.getPosition(), rotation = objects.map.getRotation()}
        if relicCount < 10 then
            for _, item in ipairs(atlasSlotBag.getObjects()) do
                if relicCount < 10 and dataTableContains(item.tags, tags.relic) then
                    local transform = getTransformStruct("relicStack", 0, mapTransform)
                    atlasSlotBag.takeObject({
                        guid = item.guid,
                        position = transform.position,
                        rotation = transform.rotation,
                    })
                    relicCount = relicCount + 1
                end
            end
        end
        putAtlasBag(atlasSlotBag)
    end
    printToAll("Retrieved " .. relicCount .. " relics from the Atlas Box")
end

-- ==============================
-- UTILITY
-- ==============================

-- Override Site Flip wtih recolor
function onPlayerAction(player, action, targets)
    if action == Player.Action.FlipOver and #targets == 1 and targets[1].hasTag(tags.site) then
        if targets[1].getColorTint() == Color(0,0,0) then
            targets[1].setColorTint(Color(1,1,1))
        else
            targets[1].setColorTint(Color(0,0,0))
        end
        return false
    end
    return true
end

-- Get Atlas Slot Bag from the Atlas Box and relock if needed
function getAtlasBag(i)
    local wasUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    local atlasSlotBag = objects.atlasBox.takeObject({index = i})
    if not wasUnlocked then objects.atlasBox.removeTag(tags.unlocked) end
    return atlasSlotBag
end

-- Put Atlas Slot Bag into the Atlas Box and relock if needed
function putAtlasBag(bag)
    local wasUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    if #bag.getObjects() > 0 then
        bag.setName(atlasSlotNames.full)
        bag.setColorTint(hexToColor("#9999ff"))
    else
        bag.setName(atlasSlotNames.empty)
        bag.setColorTint(hexToColor("#ff9999"))
    end
    objects.atlasBox.putObject(bag)
    if not wasUnlocked then objects.atlasBox.removeTag(tags.unlocked) end
end

-- Get transform for a given tag and index
    -- Can provide a base position
function getTransformStruct(tag, index, baseTransform)
    return {
        position = vectorSum(
            pos[tag](index or 1), 
            (baseTransform and baseTransform.position or {x=0,y=0,z=0})
        ),
        rotation = rot[tag],
    }
end

-- Spawn all objects from a bag at a given position and rotation
function spawnAllFromBagAtTransform(bag, baseTransform, duringSetup) 
    function spawnAllFromBagAtTransformCoroutine() 
        local relicNumber, denizenNumber, denizenCount = 0, 0, 0;
        local atlasObjects = bag.getObjects()
        for _, obj in ipairs(atlasObjects) do
            if dataTableContains(obj.tags, tags.edifice) then
                denizenCount = denizenCount + 1
            end
        end
        atlasObjects = bag.getObjects()
        -- Take out sites, edifices and relics
        for _, obj in ipairs(atlasObjects) do
            coroutine.yield(0)
            local transform = nil
            if dataTableContains(obj.tags, tags.site) then
                transform = baseTransform
            elseif dataTableContains(obj.tags, tags.edifice) then
                transform = getTransformStruct("denizen", denizenNumber, baseTransform)
                denizenNumber = denizenNumber+1
            elseif dataTableContains(obj.tags, tags.relic) then
                transform = getTransformStruct("relic", relicNumber, getTransformStruct("denizen", denizenCount, baseTransform))
                relicNumber = relicNumber+1
            end
            if transform then
                local bagObj = bag.takeObject({
                    guid = obj.guid, 
                    position = transform.position,
                    rotation = transform.rotation,
                })
            end
        end
        putAtlasBag(bag)
        return 1
        end
    startLuaCoroutine(self, "spawnAllFromBagAtTransformCoroutine")
end

function isPortalEmpty(zone)
    -- Validate that the portal is empty
    if #portal.sites + #portal.edifices + #portal.relics > 0 then
        printToAll("ERROR: Cannot Summon while storing sites\n")
        return false
    end
    for _, obj in ipairs(zone.getObjects(true)) do
        if obj.hasTag(tags.site) or obj.hasTag(tags.relic) or obj.hasTag(tags.edifice) then
            printToAll("ERROR: Cannot Summon while pieces are on the Portal\n")
            return false
        end
    end
    return true
end

function getArchiveDecks() 
    local decks = {} 
    for deckName, guid in pairs(GUIDs.archiveDecks) do
        decks[deckName] = getObjectFromGUID(guid)
    end
    return decks
end