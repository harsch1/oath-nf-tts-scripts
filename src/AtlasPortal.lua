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

local SITE_PREVIEW = "SITE PREVIEW"

local mapTransform = nil
local sitePreview = nil
local portalPosition = self.getPosition()
local retrieveInCooldown = false

-- ==============================
-- INITIALIZATION
-- ==============================

function onLoad() 
    -- Create all needed tags by adding them to this object and then removing them
    local tagsToAdd = {tags.site, tags.relic, tags.edifice, tags.unlocked, tags.protected}
    for _, tag in ipairs(tagsToAdd) do
        self.addTag(tag)
        self.removeTag(tag)
    end

    local chronicleExists = self.hasTag(tags.chronicleCreated)
    -- If the chronicle is already created we can skip setup
    if chronicleExists and setupAtlasBox() then
        setupObjects(true)
        createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack, buttons.ruinSites, buttons.unifySites)
        refreshRevisitPreview()
        return
    -- If the chronicle is not created we need to spawn setup buttons
    elseif not chronicleExists then
        if setupObjects(false) then
            tagAllItems() -- Tag all items in the bags
            self.createButton(buttons.setup)
        else 
            self.createButton(buttons.retry)
        end
    end
end

-- Validate that setup objects can be found and set them
function setupObjects(isChronicleCreated)
    local loadTable = {
        {objectName = "table", GUID = GUIDs.table, printableName = "Table"},
        {objectName = "atlasBox", GUID = GUIDs.atlasBox, printableName = "Atlas Box Bag"},
        {objectName = "map", GUID = GUIDs.map, printableName = "Map"}
    }
    local setupTable = {
        {objectName = "relicBag", GUID = GUIDs.relicBag, printableName = "Relic Bag"},
        {objectName = "siteBag", GUID = GUIDs.siteBag, printableName = "Site Bag"},
    }
    local foundAll = true
    
    for _, loadTable in ipairs(loadTable) do
        objects[loadTable.objectName] = getObjectFromGUID(loadTable.GUID)
        if objects[loadTable.objectName] == nil then
            printToAll("ERROR: Cannot find " .. loadTable.printableName .. " by GUID")
            foundAll = false
        end
    end
    if not isChronicleCreated then
        for _, setupItem in ipairs(setupTable) do
            objects[setupItem.objectName] = getObjectFromGUID(setupItem.GUID)
            if objects[setupItem.objectName] == nil then
                printToAll("ERROR: Cannot find " .. setupItem.printableName .. " by GUID")
                foundAll = false
            end
        end
    end
    if isChronicleCreated then
        for _, obj in ipairs(getAllObjects()) do
            if obj.getDescription() == SITE_PREVIEW then
                sitePreview = obj
            end
            if obj.hasTag(tags.site) then
                obj.addContextMenuItem("Preserve Site", markCard)
                obj.addContextMenuItem("Allow Site to Ruin", unMarkCard)
            end
        end
    end
    mapTransform = {position = objects.map.getPosition(), rotation = objects.map.getRotation()}
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
            printToAll("ATLAS SETUP COMPLETE.")
            createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack, buttons.ruinSites,  buttons.unifySites)
            refreshRevisitPreview()
            createDispossessed()
            printToAll("WORLD DECK SETUP COMPLETE.")
            
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
function getRandomSite()
    local site = getRandomObjectFromContainer(objects.siteBag, false)
    addTagAndReturn(site, tags.site).setRotation({x=0,y=180,z=0})
    return site
end


-- ==============================
-- ATLAS BOX STORAGE
-- ==============================

function ruinSites()
    local toStore = {{},{},{},{},{},{},{},{}};
    function getRuinableObjectsAtSite(hitObjects, index)
        function getRuinableObjectsAtSiteCoroutine()
            local isProtected = false
            local protectedSite

            for _, obj in ipairs(hitObjects) do
                if obj.hasTag(tags.site) then
                    obj.setLock(false)
                    isProtected = obj.hasTag(tags.protected)
                    unMarkCard(_,_,obj)
                end
            end
            if not isProtected then
                for _, obj in ipairs(hitObjects) do
                    if (obj.hasTag(tags.site) or obj.hasTag(tags.relic) or obj.hasTag(tags.edifice)) then
                        table.insert(toStore[index], obj)
                    elseif not (obj.getGUID() == GUIDs.map) and not (obj.getGUID() == GUIDs.table) and not (obj.getGUID() == GUIDs.scriptingTrigger) then
                        local randomOffset = {
                            x = (math.random() - 0.5) * 15,
                            y = (math.random() - 0.5) * 20,
                            z = (math.random() - 0.5) * 10
                        }
                        obj.setPositionSmooth(vectorSum(vector(73, 10, -5),randomOffset), false, false)
                    end
                end
            end
            
            return 1
        end 
        startLuaCoroutine(self, "getRuinableObjectsAtSiteCoroutine")
    end
    getObjectsAtSites(getRuinableObjectsAtSite, false)
    Wait.time(function()
        function quickStoreCoroutine()
            local i = 8
            -- Store the objects in the Atlas Box in the empty slot closest to the front
            local foundEmptyBag = false
            for j = 1, #objects.atlasBox.getObjects() do
                local atlasSlotBag = getAtlasBag(0)
                if i > 0 and #atlasSlotBag.getObjects() == 0 then
                    for _, obj in ipairs(toStore[i]) do
                        atlasSlotBag.putObject(obj)
                        coroutine.yield(0)
                    end
                    i = i - 1
                end
                putAtlasBag(atlasSlotBag)
            end
            refreshRevisitPreview()
            unifySites()
            return 1
        end
        startLuaCoroutine(self, "quickStoreCoroutine")
    end, 0.5)
end

function unifySites()
    local emptySites = {}
    function unifySitesCallback(hitObjects, slot)
        function unifySitesCoroutine()
            for j = 1, 25*slot do
                coroutine.yield(0)
            end
            local isEmpty = true
            for _, obj in ipairs(hitObjects) do
                if not (obj.getGUID() == GUIDs.map) and not (obj.getGUID() == GUIDs.table) and not (obj.getGUID() == GUIDs.scriptingTrigger) then
                    isEmpty = false
                end
            end
            if isEmpty then
                table.insert(emptySites, slot)
            elseif #emptySites > 0 then
                local destinationSlot = table.remove(emptySites, 1)
                local deltaPosition = vectorSum(
                    {
                        x = getTransformStruct("site", slot, mapTransform).position.x*-1,
                        y = getTransformStruct("site", slot, mapTransform).position.y*-1,
                        z = getTransformStruct("site", slot, mapTransform).position.z*-1,
                    },
                    getTransformStruct("site", destinationSlot, mapTransform).position
                )
                for _, obj in ipairs(hitObjects) do
                    if not (obj.getGUID() == GUIDs.map) and not (obj.getGUID() == GUIDs.table) and not (obj.getGUID() == GUIDs.scriptingTrigger) then
                        obj.setPositionSmooth(vectorSum(obj.getPosition(), deltaPosition), false)
                        coroutine.yield()
                        if obj.hasTag(tags.site) then obj.setLock(true) end
                    end
                end
                table.insert(emptySites, slot)
            end
            return 1
        end
        startLuaCoroutine(self, "unifySitesCoroutine")
    end
    getObjectsAtSites(unifySitesCallback, true)    
end

-- ==============================
-- ATLAS BOX RETRIEVAL
-- ==============================

function retrieve(owner, color, fromBack)
    local hasRetrieved = false
    function retrieveAtFirstEmptySlot(foundObjects, slotNumber)
        if not hasRetrieved then
            for _, obj in ipairs(foundObjects) do
                if obj.hasTag(tags.site) then
                    if slotNumber == 8 then
                        printToAll("No room to summon sites")
                    end
                    return
                end
            end
            hasRetrieved = true
            local countsAndTags = {
                {tag = tags.relic, data = {count = 0, printName = "Relic(s)"}},
                {tag = tags.edifice, data = {count = 0, printName = "Locked Card(s)"}},
            }
            local bagIndex = 0
            if fromBack then
            -- Get the backmost full bag otherwise we use front
                local lastFullBagIndex = 0
                for i = 0, #objects.atlasBox.getObjects()-1 do
                    local atlasSlotBag = getAtlasBag(0)
                    if #atlasSlotBag.getObjects() > 0 then
                        lastFullBagIndex = i
                    end
                    putAtlasBag(atlasSlotBag)
                end
                bagIndex = lastFullBagIndex
            end
            -- Spawn the bags contents
            local atlasSlotBag = getAtlasBag(bagIndex)
            for _, obj in ipairs(atlasSlotBag.getObjects()) do
                for _, countAndTag in ipairs(countsAndTags) do
                    if dataTableContains(obj.tags, countAndTag.tag) then
                        countAndTag.data.count = countAndTag.data.count + 1
                    end
                end
            end
            spawnAllFromBagAtTransform(atlasSlotBag, getTransformStruct("site", slotNumber, mapTransform), false)
            
            -- Print message with what was summoned
            local messageParts = {}
            for _, countAndTag in ipairs(countsAndTags) do
                if countAndTag.data.count > 0 then
                    table.insert(messageParts, countAndTag.data.count .. " " .. countAndTag.data.printName)
                end
            end
            printToAll(#messageParts > 0 and ("Summoning Site with " .. table.concat(messageParts, ", ")) or ("Summoning Empty Site"))
            if fromBack then refreshRevisitPreview() end
            return
        end
    end
    if retrieveInCooldown then
        printToAll("Wait a sec...")
    end
    if setupAtlasBox() and not retrieveInCooldown then
        retrieveInCooldown = true
        getObjectsAtSites(retrieveAtFirstEmptySlot, true)
        Wait.time(function()
            retrieveInCooldown = false
        end, 0.5)
    end
end

function retrieveBack(owner, color)
    retrieve(owner, color, true)
end

function refreshRevisitPreview()
    function refreshRevisitPreviewCoroutine()
        if sitePreview then destroyObject(sitePreview) end
        local previewPosition = vectorSum(portalPosition, vector(-8.5,0,-3))
        local lastFullBagIndex = -1
        for i = 0, #objects.atlasBox.getObjects()-1 do
            local atlasSlotBag = getAtlasBag(0)
            if #atlasSlotBag.getObjects() > 0 then
                lastFullBagIndex = i
            end
            putAtlasBag(atlasSlotBag)
        end
        local firstBag = true
        if lastFullBagIndex == -1 then
            sitePreview = nil
            return 1
        end
        local atlasSlotBag = getAtlasBag(lastFullBagIndex)
        for _, obj in ipairs(atlasSlotBag.getObjects()) do
            if dataTableContains(obj.tags, tags.site) then
                local site = atlasSlotBag.takeObject({guid = obj.guid})
                coroutine.yield(0)
                sitePreview = site.clone({position = previewPosition})
                sitePreview.setRotation(vector(0,180,0))
                sitePreview.setScale(vector(1, 0.1, 1))
                sitePreview.setLock(true)
                sitePreview.setPosition(previewPosition)
                sitePreview.setDescription(SITE_PREVIEW)
                atlasSlotBag.putObject(site)
                putAtlasBag(atlasSlotBag)
            end
        end
        for i = lastFullBagIndex, #objects.atlasBox.getObjects()-2 do
            local atlasSlotBag = getAtlasBag(lastFullBagIndex)
            putAtlasBag(atlasSlotBag)
        end
        return 1
    end
    startLuaCoroutine(self, "refreshRevisitPreviewCoroutine")
end


--- ==============================
--- ATLAS BOX RELIC RETRIEVAL
--- ==============================

-- Try to get 10 relics from the Atlas Box 
function spawnRelics()
    local relicCount = 0    
    for i = 1, #objects.atlasBox.getObjects() do
        local atlasSlotBag = getAtlasBag(0)
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

-- Get Atlas Slot Bag from the Atlas Box and relock if needed
function getAtlasBag(i)
    local wasUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    local atlasSlotBag = objects.atlasBox.takeObject({
        index = i,
        position = vector(0,10,0)
    })
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
        -- Take out sites, edifices and relics
        for _, obj in ipairs(atlasObjects) do
            coroutine.yield(0)
            local transform = nil
            if dataTableContains(obj.tags, tags.site) then
                transform = baseTransform
            elseif dataTableContains(obj.tags, tags.edifice) or dataTableContains(obj.tags, tags.relic) then
                transform = getTransformStruct("denizen", denizenNumber, baseTransform)
                denizenNumber = denizenNumber+1
            end
            if transform then
                local bagObj = bag.takeObject({
                    guid = obj.guid, 
                    rotation = transform.rotation,
                    position = transform.position,
                    callback_function = function(_obj)
                        if _obj.hasTag(tags.site) and duringSetup then
                            Wait.time(function ()
                                _obj.setLock(true)
                            end, 1.5)
                        end
                    end
                })
                if bagObj.hasTag(tags.site) then
                    bagObj.addContextMenuItem("Preserve Site", markCard)
                    bagObj.addContextMenuItem("Allow Site to Ruin", unMarkCard)
                end

            end
        end
        putAtlasBag(bag)
        return 1
        end
    startLuaCoroutine(self, "spawnAllFromBagAtTransformCoroutine")
    return
end


function getObjectsAtSites(callback, forwards)
    local startIndex, endIndex, step = 1, 8, 1
    if not forwards then
        startIndex, endIndex, step = 8, 1, -1
    end
    function getObjectsAtSitesCoroutine()
        for i = startIndex, endIndex, step do
            local zone = spawnObject({
                type = "FogOfWarTrigger",
                position = vectorSum(getTransformStruct("site", i, mapTransform).position, vector(5.65, 0, 0)),
                scale = vector(19.5,2,5.4),
                sound = false,
                callback_function = function(createdZone)
                    Wait.time(function()
                        local hitObjects = createdZone.getObjects(true);
                        callback(hitObjects,i)
                        Wait.time(function ()
                            destroyObject(createdZone)
                        end, 0.1)
                    end, 0.10)
                end
            })
            for j = 1, 15 do
                coroutine.yield(0)
            end
        end
        return 1
    end
    startLuaCoroutine(self, "getObjectsAtSitesCoroutine")
end

function getArchiveDecks() 
    local decks = {} 
    for deckName, guid in pairs(GUIDs.archiveDecks) do
        decks[deckName] = getObjectFromGUID(guid)
    end
    return decks
end

function markCard(_, _, obj)
      obj.highlightOn(hexToColor("#ff00ff"))
      obj.addTag(tags.protected)
  end
  
  function unMarkCard(_, _, obj)
    obj.highlightOff()
    obj.removeTag(tags.protected)
  end