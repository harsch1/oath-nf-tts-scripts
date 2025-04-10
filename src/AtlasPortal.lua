-- Atlas Box scripts written by harsch and Frack.  Last update:  04-10-2025

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
local sitePreview = {}
local portalPosition = self.getPosition()
local retrieveInCooldown = false

-- ==============================
-- INITIALIZATION
-- ==============================

function onLoad() 
    -- Create all needed tags by adding them to this object and then removing them
    local tagsToAdd = {tags.site, tags.relic, tags.edifice, tags.unlocked, tags.protected, tags.ancient, tags.card}
    for _, tag in ipairs(tagsToAdd) do
        self.addTag(tag)
        self.removeTag(tag)
    end
    
    if not (self.hasTag(tags.debug)) then
        self.addTag(tags.debug)
        self.removeTag(tags.debug)
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
    else
        for _, obj in ipairs(getAllObjects()) do
            if obj.getDescription() == SITE_PREVIEW then
                table.insert(sitePreview, obj)
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
            -- Tag all cards
            printToAll("organizing cards...")
            local decksDone = 0
            for _, deck in pairs(getArchiveDecks()) do
                function tagAllCardsInDeck(_deck)
                    local deckSize = #deck.getObjects()
                    for i = deckSize-1, 0, -1 do
                        local card = deck.takeObject({index = i})
                        for i = 0, 10 do
                            coroutine.yield(0)
                        end
                        card.addTag(tags.card)
                        for i = 0, 10 do
                            coroutine.yield(0)
                        end
                        deck.putObject(card)
                    end
                    decksDone = decksDone+1;
                    return 1
                end
                startLuaCoroutine(self, "tagAllCardsInDeck")
            end
            while decksDone < 6 do
                coroutine.yield(0)
            end
            for _, deck in pairs(getArchiveDecks()) do
                deck.setRotation({0,180,180})
                deck.shuffle()
            end
            -- Take all sites and put them in the Atlas Box. Roll a d6 and add additional items depending on the roll
            printToAll("creating the world...")
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
        for i=1, 9 do
            local newCard = deck.takeObject();
            for i = 0, 10 do
                coroutine.yield(0)
            end
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
    local toStore = {};
    local completedSites = 0
    local storedSites = 0
    function quickStoreCoroutine()
        local i = #toStore
        -- Store the objects in the Atlas Box in the empty slot closest to the front
        local foundEmptyBag = false
        for j = 1, #objects.atlasBox.getObjects() do
            local atlasSlotBag = getAtlasBag(0)
            if i > 0 and #atlasSlotBag.getObjects() == 0 then
                for _, obj in ipairs(toStore[i]) do
                    atlasSlotBag.putObject(obj)
                    storedSites = storedSites + 1
                    for k = 0, 10 do
                        coroutine.yield(0)
                    end
                end
                i = i - 1
                if isDebug() then
                    printToAll("Storing objects in bag " .. j)
                end
            elseif isDebug() then
                printToAll("Skipping bag " .. j .. " because full")
            end
            putAtlasBag(atlasSlotBag)
        end
        refreshRevisitPreview()
        unifySites()
        return 1
    end
    function getRuinableObjectsAtSite(hitObjects, index)
        local isProtected = false
        local isAncient = false
        local protectedSite

        for _, obj in ipairs(hitObjects) do
            if obj.hasTag(tags.site) then
                obj.setLock(false)
                isProtected = obj.hasTag(tags.protected)
                unMarkCard(_,_,obj)
                if obj.hasTag(tags.ancient) then
                    isAncient = true
                end
            end
        end
        if not isProtected then
            local toStoreSlot = {}
            for _, obj in ipairs(hitObjects) do
                if (obj.hasTag(tags.site) or obj.hasTag(tags.relic) or obj.hasTag(tags.edifice)) then
                    table.insert(toStoreSlot, obj)
                elseif (obj.hasTag(tags.card) and isAncient) then
                    table.insert(toStoreSlot, obj)
                elseif not (obj.getGUID() == GUIDs.map) and
                       not (obj.getGUID() == GUIDs.table) and
                       not (obj.getGUID() == GUIDs.scriptingTrigger) and
                       not (obj.memo == "trigger") then
                    local randomOffset = {
                        x = (math.random() - 0.5) * 15,
                        y = (math.random() - 0.5) * 20,
                        z = (math.random() - 0.5) * 10
                    }
                    obj.setPositionSmooth(vectorSum(vector(73, 10, -5),randomOffset), false, false)
                end
            end
            if #toStoreSlot > 0 then
                table.insert(toStore, 1, toStoreSlot)
            end
        end
        completedSites = completedSites + 1

        local waitCount = 0
        if index == 1 then
            while completedSites < 8 do
                printToAll("Waiting for " .. waitCount)
                waitCount = waitCount + 1
            end
            startLuaCoroutine(self, "quickStoreCoroutine")
        end
    end
    getObjectsAtSites(getRuinableObjectsAtSite, false)
end

function unifySites()
    local emptySites = {}
    local currentSlot = 1
    function unifySitesCallback(hitObjects, slot)
        function unifySitesCallbackCoroutine()
            local waitCount = 0
            while not (slot == currentSlot) do
                coroutine.yield(0)
                if isDebug() and waitCount%20 == 0 then printToAll("Waiting for " .. waitCount/20 .. ", " .. currentSlot .. " " .. slot) end
                waitCount = waitCount + 1
            end
            local isEmpty = true
            for _, obj in ipairs(hitObjects) do
                if not (obj.getGUID() == GUIDs.map) and
                not (obj.getGUID() == GUIDs.table) and
                not (obj.getGUID() == GUIDs.scriptingTrigger) and
                not (obj.memo == "trigger")  then
                    if obj.hasTag(tags.site) then
                        obj.setLock(true)
                        isEmpty = false
                    end
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
                        obj.setPositionSmooth(vectorSum(obj.getPosition(), deltaPosition), false, true)
                    end
                end
                for i = 0, 200 do
                    coroutine.yield(0)
                end
                table.insert(emptySites, slot)
            end
            currentSlot = slot+1
            return 1
        end
        startLuaCoroutine(self, "unifySitesCallbackCoroutine")
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
                {tag = tags.edifice, data = {count = 0, printName = "Edifice(s)"}},
                {tag = tags.card, data = {count = 0, printName = "Card(s)"}},
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
            if isDebug() then
                printToAll(#messageParts > 0 and ("Summoning Site with " .. table.concat(messageParts, ", ")) or ("Summoning Empty Site"))
            end
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
    local portalPosition = self.getPosition()
    function refreshRevisitPreviewCoroutine()
        if sitePreview then 
            for _, obj in ipairs(sitePreview) do
                destroyObject(obj)
            end
            sitePreview = {}
        end
        local previewPosition = vectorSum(portalPosition, vector(-8.75,0,-3))
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
            sitePreview = {}
            return 1
        end
        local atlasSlotBag = getAtlasBag(lastFullBagIndex)
        local denizenCount = 0
        local totalDenizenCount = 0
        for _, obj in ipairs(atlasSlotBag.getObjects()) do
            if dataTableContains(obj.tags, tags.edifice) or dataTableContains(obj.tags, tags.relic) then
                totalDenizenCount = totalDenizenCount + 1
            end
        end
        for _, obj in ipairs(atlasSlotBag.getObjects()) do
            if dataTableContains(obj.tags, tags.site) then
                local site = atlasSlotBag.takeObject({guid = obj.guid})
                coroutine.yield(0)
                siteClone = site.clone({position = previewPosition})
                siteClone.setRotation(vector(0,180,0))
                siteClone.setScale(vector(1, 0.1, 1))
                siteClone.setLock(true)
                siteClone.setPosition(previewPosition)
                siteClone.setDescription(SITE_PREVIEW)
                table.insert(sitePreview, siteClone)
                atlasSlotBag.putObject(site)
            end
            if dataTableContains(obj.tags, tags.edifice) then
                local denizen = atlasSlotBag.takeObject({guid = obj.guid})
                coroutine.yield(0)
                denizenClone = denizen.clone({position = previewPosition})
                denizenClone.setRotation(vector(0,180,0))
                denizenClone.setScale(vector(0.5, 0.1, 0.5))
                denizenClone.setLock(true)
                denizenClone.setPosition(vectorSum(
                    previewPosition,
                    vector(2.65, .001*denizenCount, totalDenizenCount>1 and 0.6/(4-totalDenizenCount) - (0.6*denizenCount) or 0)
                ))
                denizenClone.setDescription(SITE_PREVIEW)
                denizenCount = denizenCount + 1
                table.insert(sitePreview, denizenClone)
                atlasSlotBag.putObject(denizen)
            end
        end
        
        for _, obj in ipairs(atlasSlotBag.getObjects()) do
            if dataTableContains(obj.tags, tags.relic) then
                local relic = atlasSlotBag.takeObject({guid = obj.guid})
                coroutine.yield(0)
                relicClone = relic.clone({position = previewPosition})
                relicClone.setRotation(vector(0,180,180))
                relicClone.setScale(vector(0.275, 0.1, 0.275))
                relicClone.setLock(true)
                relicClone.setPosition(vectorSum(
                    previewPosition,
                    vector(2.65, .001*denizenCount, totalDenizenCount>1 and 0.6/(4-totalDenizenCount) - (0.6*denizenCount) or 0)
                ))
                relicClone.setDescription(SITE_PREVIEW)
                denizenCount = denizenCount + 1
                table.insert(sitePreview, relicClone)
                atlasSlotBag.putObject(relic)
            end
        end
        putAtlasBag(atlasSlotBag)
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
    refreshRevisitPreview()
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
            elseif dataTableContains(obj.tags, tags.edifice) or dataTableContains(obj.tags, tags.card) then
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
        for _, obj in ipairs(bag.getObjects()) do
            coroutine.yield(0)
            local transform = nil
            if dataTableContains(obj.tags, tags.relic) then
                transform = getTransformStruct("relic", denizenNumber, baseTransform)
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
    function getObjectAtSite(callback, index, endIndex, step)
        local zone = spawnObject({
            type = "FogOfWarTrigger",
            position = vectorSum(getTransformStruct("site", index, mapTransform).position, vector(5.65, 0, 0)),
            scale = vector(19.5,2,5.4),
            sound = false,
            callback_function = function(createdZone)
                createdZone.memo = "trigger"
                Wait.time(function()
                    local hitObjects = createdZone.getObjects(true);
                    callback(hitObjects, index)
                    if not (index == endIndex) then
                        getObjectAtSite(callback, index + step, endIndex, step)
                    end
                    Wait.time(function ()
                        destroyObject(createdZone)
                    end, 0.2)
                end, 0.1)
            end
        })
    end

    
    local s, e, c = 1, 8, 1
    if not forwards then
        s, e, c = 8, 1, -1
    end
    getObjectAtSite(callback, s, e, c)    
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

function isDebug()
    return self.hasTag(tags.debug)
end