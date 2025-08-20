-- Atlas Box scripts written by harsch and Frack and AdoptedAndy.  Last update:  05-10-2025

require("src/Utils/ColorUtils")
require("src/Config/GeneralConfig")
require("src/Config/AtlasBoxButtons")
require("src/Utils/HelperFunctions")
require("src/XmlHelper")

-- Objects for needed game objects.
local objects = {
    atlasBox = nil,
    atlasBoxModel = nil,
    banditBag = nil,
    relicBag = nil,
    relicDeck = nil,
    siteBag = nil,
    table = nil,
    map = nil,
    arcaneEdificeDeck = nil,
    beastEdificeDeck = nil,
    discordEdificeDeck = nil,
    hearthEdificeDeck = nil,
    nomadEdificeDeck = nil,
    orderEdificeDeck = nil,
}

local SITE_PREVIEW = "SITE PREVIEW"

local mapTransform = nil
local selfTransform = nil
local sitePreview = {}
local portalPosition = self.getPosition()
local retrieveInCooldown = false


-- ==============================
-- INITIALIZATION
-- ==============================

function onLoad() 
    log('mirror_game ON')
    -- Create all needed tags by adding them to this object and then removing them
    debugLog("Adding tags to game")
    local tagsToAdd = {tags.site, tags.relic, tags.edifice, tags.unlocked, tags.protected, tags.ancient, tags.card, tags.slow}
    for _, tag in ipairs(tagsToAdd) do
        self.addTag(tag)
        self.removeTag(tag)
    end
    
    if not (self.hasTag(tags.debug)) then
        self.addTag(tags.debug)
        self.removeTag(tags.debug)
    end
    debugLog("Tags added")

    local chronicleExists = self.hasTag(tags.chronicleCreated)

    debugLog("Adding Speed buttons")
    self.createButton(buttons.speedLabel)
    self.createButton(buttons.speedDisplay)
    self.createButton(buttons.speedUp)
    self.createButton(buttons.speedDown)
    debugLog("Speed buttons added")
    
    -- If the chronicle is already created we can skip setup
    if chronicleExists then
        setupObjects(true)

        debugLog("Adding Atlas Box context menu items and Foundation 9 button")
        self.addContextMenuItem("RUIN and unify Sites", ruinSites)
        self.addContextMenuItem("EXPLORE new Sites", retrieveRest)
        self.addContextMenuItem("REVISIT an old Site", retrieveBack)
        self.addContextMenuItem("EXPLORE a new Site", retrieveOnce)
        self.addContextMenuItem("Retrieve lost Relics", spawnRelics)
        self.addContextMenuItem("Search (Debug)", search)
        debugLog("Atlas Box context menu items added and Foundation 9 button")

        refreshRevisitPreview()
    -- If the chronicle is not created we need to spawn setup buttons
    elseif not chronicleExists then
        if setupObjects(false) then
            tagAllItems() -- Tag all items in the bags
            self.createButton(buttons.setup)
        else 
            self.createButton(buttons.retry)
        end
    end

    debugLog("Setting up internal Atlas Box Container")
    -- objects.atlasBox.setLock(true)
    objects.atlasBox.interactable = false
    objects.atlasBox.setPosition(vectorSum(objects.atlasBoxModel.getPosition(), {x=0, y=0, z=2}))
    objects.atlasBox.setRotation(objects.atlasBoxModel.getRotation())
    objects.atlasBoxModel.jointTo(objects.atlasBox, {
        ["type"]        = "Fixed",
        ["collision"]   = false,
        ["break_force"]  = 10000000.0,
        ["break_torgue"] = 10000000.0,
    })
    debugLog("Setting up internal Atlas Box Container complete")

end

-- Validate that setup objects can be found and set them
function setupObjects(isChronicleCreated)
    local loadTable = {
        {objectName = "table", GUID = GUIDs.table, printableName = "Table"},
        {objectName = "atlasBox", GUID = GUIDs.atlasBox, printableName = "Atlas Box Bag"},
        {objectName = "atlasBoxModel", GUID = GUIDs.newAtlasBox, printableName = "Atlas Box Model"},
        {objectName = "map", GUID = GUIDs.map, printableName = "Map"},
        {objectName = "banditBag", GUID = GUIDs.banditBag, printableName = "Bandit Bag"},
        {objectName = "arcaneEdificeDeck", GUID = GUIDs.edificeDecks.Arcane, printableName = "Arcane Edifice Deck"},
        {objectName = "beastEdificeDeck", GUID = GUIDs.edificeDecks.Beast, printableName = "Beast Edifice Deck"},
        {objectName = "discordEdificeDeck", GUID = GUIDs.edificeDecks.Discord, printableName = "Discord Edifice Deck"},
        {objectName = "hearthEdificeDeck", GUID = GUIDs.edificeDecks.Hearth, printableName = "Hearth Edifice Deck"},
        {objectName = "nomadEdificeDeck", GUID = GUIDs.edificeDecks.Nomad, printableName = "Nomad Edifice Deck"},
        {objectName = "orderEdificeDeck", GUID = GUIDs.edificeDecks.Order, printableName = "Order Edifice Deck"},
    }
    local setupTable = {
        {objectName = "arcaneEdificeDeck", GUID = GUIDs.edificeDecks.Arcane, printableName = "Arcane Edifice Deck"},
        {objectName = "beastEdificeDeck", GUID = GUIDs.edificeDecks.Beast, printableName = "Beast Edifice Deck"},
        {objectName = "discordEdificeDeck", GUID = GUIDs.edificeDecks.Discord, printableName = "Discord Edifice Deck"},
        {objectName = "hearthEdificeDeck", GUID = GUIDs.edificeDecks.Hearth, printableName = "Hearth Edifice Deck"},
        {objectName = "nomadEdificeDeck", GUID = GUIDs.edificeDecks.Nomad, printableName = "Nomad Edifice Deck"},
        {objectName = "orderEdificeDeck", GUID = GUIDs.edificeDecks.Order, printableName = "Order Edifice Deck"},
        {objectName = "relicBag", GUID = GUIDs.relicBag, printableName = "Relic Bag"},
        {objectName = "siteBag", GUID = GUIDs.siteBag, printableName = "Site Bag"},
    }
    local foundAll = true
    
    debugLog("Detecting object group 1")
    for _, loadTable in ipairs(loadTable) do
        objects[loadTable.objectName] = getObjectFromGUID(loadTable.GUID)
        if objects[loadTable.objectName] == nil then
            printToAll("ERROR: Cannot find " .. loadTable.printableName .. " by GUID")
            foundAll = false
        end
    end
    debugLog("Detecting  object group 1 complete")

    if not isChronicleCreated then
        debugLog("Detecting setup objects")
        for _, setupItem in ipairs(setupTable) do
            objects[setupItem.objectName] = getObjectFromGUID(setupItem.GUID)
            if objects[setupItem.objectName] == nil then
                printToAll("ERROR: Cannot find " .. setupItem.printableName .. " by GUID")
                foundAll = false
            end
        end
        debugLog("Detecting setup objects complete")
    else
        debugLog("Detecting site objects and adding context menu items")
        for _, obj in ipairs(getAllObjects()) do
            if obj.getDescription() == SITE_PREVIEW then
                table.insert(sitePreview, obj)
            end
            if obj.hasTag(tags.site) then
                obj.addContextMenuItem("Preserve Site", markCard)
                obj.addContextMenuItem("Allow Site to Ruin", unMarkCard)
            end
            if obj.getMemo() == "relicDeck" then
                objects.relicDeck = obj
            end
        end
        debugLog("Detecting site objects and adding context menu items complete")
    end
    selfTransform = {position = self.getPosition(), rotation = self.getRotation()}
    mapTransform = {position = objects.map.getPosition(), rotation = objects.map.getRotation()}
    return foundAll
end

-- Remove all buttons
function retry()
    removeButtons(buttons.retry)
    onLoad()
end

-- Tag all items in bags
function tagAllItems()
    debugLog("Tagging all relics")
    local bagTags = { 
        {bag = objects.relicBag,    tag = tags.relic},
    }
    for _, bagTag in ipairs(bagTags) do
        local bag, tag = bagTag.bag, bagTag.tag
        for _, item in ipairs(bag.getObjects()) do
            bag.putObject(addTagAndReturn(bag.takeObject({guid = item.guid}), tag))
        end
    end
    debugLog("Tagging all relics complete")
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
            debugLog("Tagging all archive cards")
            for _, deck in pairs(getArchiveDecks()) do
                function tagAllCardsInDeck(_deck)
                    local deckSize = #deck.getObjects()
                    for i = deckSize-1, 0, -1 do
                        local card = deck.takeObject({index = i})
                        for i = 0, 1*getSpeedScale() do
                            coroutine.yield(0)
                        end
                        card.addTag(tags.card)
                        for i = 0, 1*getSpeedScale() do
                            coroutine.yield(0)
                        end
                        deck.putObject(card)
                    end
                    decksDone = decksDone+1
                    return 1
                end
                startLuaCoroutine(self, "tagAllCardsInDeck")
            end
            debugLog("Tagging all archive cards complete")
            while decksDone < 6 do
                coroutine.yield(0)
            end
            for _, deck in pairs(getArchiveDecks()) do
                deck.setRotation({0,180,180})
                deck.shuffle()
            end
            -- Take all sites and put them in the Atlas Box. Roll a d6 and add additional items depending on the roll
            printToAll("creating the world...")
            debugLog("Attaching edifices and enduring tag to homeland sites")
            for i = 1,  #objects.siteBag.getObjects() do
                local site = getRandomSite()
                for i = 0, 2*getSpeedScale() do
                    coroutine.yield(0)
                end
                for _, tag in ipairs({"ArcaneHomeland", "BeastHomeland", "DiscordHomeland", "HearthHomeland", "NomadHomeland", "OrderHomeland"}) do
                    if getSiteScriptTag(site, tag) == 1 then
                        site.addTag(tags.ancient)
                        local edifice = nil
                        if tag == "ArcaneHomeland" then
                            edifice = getRandomObjectFromContainer(objects.arcaneEdificeDeck, false)
                        elseif tag == "BeastHomeland" then
                            edifice = getRandomObjectFromContainer(objects.beastEdificeDeck, false)
                        elseif tag == "DiscordHomeland" then
                            edifice = getRandomObjectFromContainer(objects.discordEdificeDeck, false)
                        elseif tag == "HearthHomeland" then
                            edifice = getRandomObjectFromContainer(objects.hearthEdificeDeck, false)
                        elseif tag == "NomadHomeland" then
                            edifice = getRandomObjectFromContainer(objects.nomadEdificeDeck, false)
                        elseif tag == "OrderHomeland" then
                            edifice = getRandomObjectFromContainer(objects.orderEdificeDeck, false)
                        end
                        edifice.setPosition(
                            getTransformStruct("denizen",
                            0,
                            { position= site.getPosition(), rotation= site.getRotation()}
                        ).position)
                        site.addAttachment(edifice)
                    end
                end

                
                if getSiteScriptTag(site, "Enduring") == 1 then
                    site.addTag(tags.ancient)
                end
                for i = 0, 1*getSpeedScale() do
                    coroutine.yield(0)
                end
                putSiteIntoAtlasBox(site)
            end
            debugLog("Attaching edifices and enduring tag to homeland sites complete")

            createRelicDeck()
            destroyObject(objects.relicBag)

            unifyEdificeDecks()
            
            -- Deal Starting Sites
            debugLog("Dealing starting sites")
            for siteNumber = 1,8 do
                local siteAndAttachments = getFromAtlasBox(0)
                spawnSiteAndAttachmentsAtTransform(siteAndAttachments, getTransformStruct("site", siteNumber, mapTransform), true)
                for i = 0, 1*getSpeedScale() do
                    coroutine.yield(0)
                end
            end
            debugLog("Dealing starting sites complete. Destroying site bag")
            destroyObject(objects.siteBag)
            
            generateNewWorldDeck()

            debugLog("Creating world deck complete. Adding context menu items")
            self.addTag(tags.chronicleCreated)
            removeButtons(buttons.setup)
            -- createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack, buttons.ruinSites,  buttons.unifySites)
            self.addContextMenuItem("RUIN and unify Sites", ruinSites)
            self.addContextMenuItem("EXPLORE new Sites", retrieveRest)
            self.addContextMenuItem("REVISIT an old Site", retrieveBack)
            self.addContextMenuItem("EXPLORE a new Site", retrieveOnce)
            self.addContextMenuItem("Retrieve lost Relics", spawnRelics)
            self.addContextMenuItem("Search (Debug)", search)
            debugLog("Adding context menu items complete")
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

    debugLog("Creating world deck with 9 cards of each suit")
    for _, suit in ipairs(suits) do
        local deck = decks[suit]
        for i=1, 9 do
            local newCard = deck.takeObject()
            for i = 0, 1*getSpeedScale() do
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
    worldDeck.shuffle()
    debugLog("Creating world deck complete")
end

function createRelicDeck()
    local firstRelic = nil
    local relicDeck = nil
    debugLog("Creating relic deck")
    for _, item in ipairs(objects.relicBag.getObjects()) do
        local relic = objects.relicBag.takeObject()
        for i = 0, 1*getSpeedScale() do
            coroutine.yield(0)
        end
        local deckPosition = getTransformStruct("relicStack", 0, mapTransform)
        if firstRelic == nil then
            firstRelic = relic
            firstRelic.setPosition(deckPosition.position)
            firstRelic.setRotation(deckPosition.rotation)
        elseif relicDeck == nil then
            relicDeck = firstRelic.putObject(relic)
            relicDeck.setName("Relic Deck")
            relicDeck.setMemo("relicDeck")
        else
            relicDeck.putObject(relic)
        end
        -- for i = 0, 1*getSpeedScale() do
        --     coroutine.yield(0)
        -- end
    end
    debugLog("Creating relic deck complete")
    objects.relicDeck = relicDeck
end

function createDispossessed() 
    local decks = getArchiveDecks()
    local firstCard = nil
    local dispossessed = nil
    -- add 2 cards from each suit
    debugLog("Creating dispossessed deck with 2 cards of each suit")
    for _, suit in ipairs(suits) do
        local deck = decks[suit]
        for i=1, 2 do
            local newCard = deck.takeObject()
            for i = 0, 1*getSpeedScale() do
                coroutine.yield(0)
            end
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
    debugLog("Creating dispossessed deck complete")
end

-- Get Elements for creating Chronicle
function getRandomSite()
    local site = getRandomObjectFromContainer(objects.siteBag, false)
    site.setRotation({x=0,y=180,z=180})
    return site
end


-- ==============================
-- ATLAS BOX STORAGE
-- ==============================

function ruinSites()
    local toStore = {}
    local completedSites = 0
    local storedSites = 0
    function quickStoreCoroutine()
        printToAll("ruining and unifying sites...")
        local i = #toStore
        -- Store the objects in the Atlas Box in the empty slot closest to the frontwa
        local foundEmptyBag = false
        debugLog("Storing objects in Atlas Box")
        for i = 1, #toStore do
            putIntoAtlasBox(toStore[i])
            storedSites = storedSites + 1
        end
        debugLog("Storing objects in Atlas Box complete")
        refreshRevisitPreview()
        unifySites()
        return 1
    end

    function getRuinableObjectsAtSite(hitObjects, index)
        local isProtected = false
        local isAncient = false
        local protectedSite

        debugLog("Checking for ruinable objects at site " .. index)
        for _, obj in ipairs(hitObjects) do
            if obj.hasTag(tags.site) then
                obj.setLock(false)
                isProtected = obj.hasTag(tags.protected)
                unMarkCard(_,_,obj)
                if obj.hasTag(tags.ancient) then
                    isAncient = true
                end
                for _, tag in ipairs({"ArcaneHomeland", "BeastHomeland", "DiscordHomeland", "HearthHomeland", "NomadHomeland", "OrderHomeland"}) do
                    if getSiteScriptTag(obj, tag) == 1 then
                        isAncient = true
                    end
                end
            end
        end
        debugLog("Checking for ruinable objects at site " .. index .. " complete")
        if not isProtected then
            local toStoreSlot = {}
            debugLog("Getting storable objects at site " .. index)
            for _, obj in ipairs(hitObjects) do
                if (obj.hasTag(tags.site) or obj.hasTag(tags.relic)) then
                    table.insert(toStoreSlot, obj)
                    obj.setRotation({x= obj.getRotation().x, y= roundToNearest180(obj.getRotation().y), z=roundToNearest180(obj.getRotation().z)})
                elseif (obj.hasTag(tags.edifice) and (obj.getRotation().z < 10 or obj.getRotation().z > 350)) then
                    table.insert(toStoreSlot, obj)
                    obj.setRotation({x= obj.getRotation().x, y= roundToNearest180(obj.getRotation().y), z=roundToNearest180(obj.getRotation().z)})
                elseif (obj.hasTag(tags.card) and isAncient) then
                    table.insert(toStoreSlot, obj)
                elseif (obj.hasTag(tags.bandit)) then
                    objects.banditBag.putObject(obj)
                elseif not (obj.getGUID() == GUIDs.map) and
                       not (obj.getGUID() == GUIDs.table) and
                       not (obj.getGUID() == GUIDs.scriptingTrigger) and
                       not (obj.memo == "trigger") then
                        if  obj.hasTag(tags.edifice) then
                            if not (nil == getEdificeDeck()) then
                                getEdificeDeck().putObject(obj)
                                getEdificeDeck().shuffle()
                            end
                        end
                    local randomOffset = {
                        x = (math.random() - 0.5) * 15,
                        y = (math.random() - 0.5) * 20,
                        z = (math.random() - 0.5) * 10
                    }
                    obj.setPositionSmooth(vectorSum(vector(73, 10, -5),randomOffset), false, false)
                end
            end
            if #toStoreSlot > 0 then
                table.insert(toStore, toStoreSlot)
            end
            debugLog("Getting storable objects at site " .. index .. " complete")
        end
        completedSites = completedSites + 1

        local waitCount = 0
        if index == 1 then
            while completedSites < 8 do
                debugLog("Waiting for " .. waitCount)
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
            debugLog("Getting storable objects at site " .. slot)
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
                debugLog("Site " .. slot .. " is empty")
                table.insert(emptySites, slot)
            elseif #emptySites > 0 then
                
                debugLog("Moving objects from site " .. slot .. " to site " .. emptySites[1])
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
                debugLog("Moving objects from site " .. slot .. " to site " .. destinationSlot .. " complete")
                for i = 0, 40*getSpeedScale() do
                    coroutine.yield(0)
                end
                table.insert(emptySites, slot)
            end
            currentSlot = slot+1
            if currentSlot > 8 then
                printToAll("RUIN AND UNIFY COMPLETE")
            end
            return 1
        end
        startLuaCoroutine(self, "unifySitesCallbackCoroutine")
    end
    getObjectsAtSites(unifySitesCallback, true)    
end

function unifyEdificeDecks()
    debugLog("Unifying Edifice decks")
    local decks = getEdificeDecks()
    local firstDeck = decks.Arcane
    for _, deck in pairs(decks) do
        if deck ~= firstDeck then
            firstDeck.putObject(deck)
            for i = 0, 1*getSpeedScale() do
                coroutine.yield(0)
            end
        end
    end
    for i = 0, 3*getSpeedScale() do
        coroutine.yield(0)
    end
    firstDeck.setName("Edifice Deck")
    firstDeck.shuffle()
    debugLog("Unifying Edifice decks complete")
end

-- ==============================
-- ATLAS BOX RETRIEVAL
-- ==============================

function retrieve(player_color, object_position, object, retrieveIndexOrFalse, continual)
    debugLog("Retrieving site(s) from Atlas Box")
    local retrieveIndex = (retrieveIndexOrFalse == nil) and 0 or retrieveIndexOrFalse
    local hasRetrieved = false
    local retrieveBack = retrieveIndex == (#objects.atlasBox.getObjects())-1
    function retrieveAtFirstEmptySlot(foundObjects, slotNumber)
        if not hasRetrieved or continual then
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
            local bagIndex = retrieveIndex
            debugLog("Retrieving site " .. bagIndex)
            local siteWithAttachments = getFromAtlasBox(bagIndex)
            for _, obj in ipairs(siteWithAttachments.getAttachments()) do
                for _, countAndTag in ipairs(countsAndTags) do
                    if dataTableContains(obj.tags, countAndTag.tag) then
                        countAndTag.data.count = countAndTag.data.count + 1
                    end
                end
            end
            debugLog("Retrieving site " .. bagIndex .. " complete")
            spawnSiteAndAttachmentsAtTransform(siteWithAttachments, getTransformStruct("site", slotNumber, mapTransform), false)
            
            local messageParts = {}
            for _, countAndTag in ipairs(countsAndTags) do
                if countAndTag.data.count > 0 then
                    table.insert(messageParts, countAndTag.data.count .. " " .. countAndTag.data.printName)
                end
            end
            if isDebug() then
                printToAll(#messageParts > 0 and ("Summoning Site with " .. table.concat(messageParts, ", ")) or ("Summoning Empty Site"))
            end
            if retrieveBack then
                refreshRevisitPreview()
            end
            return
        end
    end
    if retrieveInCooldown then
        printToAll("Wait a sec...")
    end
    if not retrieveInCooldown then
        retrieveInCooldown = true
        getObjectsAtSites(retrieveAtFirstEmptySlot, true)
        Wait.time(function()
            retrieveInCooldown = false
        end, 0.5)
    end
end

function retrieveBack(player_color, object_position, object)
    retrieve(player_color, object_position, object, (#objects.atlasBox.getObjects())-1, false)
end

function retrieveRest(player_color, object_position, object)
    retrieve(player_color, object_position, object, 0, true)
end

function retrieveOnce(player_color, object_position, object)
    retrieve(player_color, object_position, object, 0, false)
end

function refreshRevisitPreview()
    function refreshRevisitPreviewCoroutine()
        debugLog("Refreshing Atlas Box site preview")
        local previewTransform = getTransformStruct("preview", 0, selfTransform)
        if sitePreview then 
            debugLog("Destroy old site preview")
            for _, obj in ipairs(sitePreview) do
                destroyObject(obj)
            end
            sitePreview = {}
            debugLog("Destroy old site preview complete")
        end
        debugLog("Loading new site to preview")
        local toStore = {}
        local lastSite = getFromAtlasBox(#objects.atlasBox.getObjects()-1)
        local denizenCount = 0
        local relicCount = 0
        local totalCardCount = 0
        debugLog("Getting attachments for site " .. lastSite.getName())
        for _, obj in ipairs(lastSite.getAttachments()) do
            if dataTableContains(obj.tags, tags.edifice) or dataTableContains(obj.tags, tags.relic) or dataTableContains(obj.tags, tags.card) then
                totalCardCount = totalCardCount + 1
            end
        end
        local attachments = lastSite.removeAttachments()
        local siteClone = lastSite.clone()
        debugLog("Creating attachment previews")
        for _, obj in ipairs(attachments) do
            if obj.hasTag(tags.edifice) or obj.hasTag(tags.card) then
                denizenClone = obj.clone()
                lastSite.addAttachment(obj)
                denizenClone.setLock(true)
                local denizen_z = roundToNearest180(denizenClone.getRotation().z)
                denizenClone.setRotation(vectorSum(
                    previewTransform.rotation,
                    {x=0, y=180+180, z=denizen_z}
                ))
                denizenClone.setScale(vector(1.5, 0.001, 1.5))
                denizenClone.setPosition(vectorSum(previewTransform.position,vector(2.15 - 1*denizenCount, -0.75-.1*denizenCount, -0.02 - 0.001*denizenCount)))
                denizenClone.setDescription(SITE_PREVIEW)
                denizenCount = denizenCount + 1
                table.insert(sitePreview, denizenClone)
            end
        end
        for _, obj in ipairs(attachments) do
            if obj.hasTag(tags.relic) then
                relicClone = obj.clone()
                lastSite.addAttachment(obj)
                relicClone.setLock(true)
                relicClone.setRotation(vectorSum(previewTransform.rotation, vector(0,180,0)))
                relicClone.setScale(vector(0.75, 0.001, 0.75))
                relicClone.setPosition(vectorSum(previewTransform.position, vector(2.35 - 1.5*relicCount, -1.75, -0.03 - 0.001*relicCount)))
                relicClone.setDescription(SITE_PREVIEW)
                relicCount = relicCount + 1
                table.insert(sitePreview, relicClone)
            end
        end
        debugLog("Creating attachment previews complete")
        for i = 0, 5*getSpeedScale() do
            coroutine.yield(0)
        end
        debugLog("Putting site into Atlas Box")
        putSiteIntoAtlasBox(lastSite)
        debugLog("Putting site into Atlas Box complete")

        debugLog("Final site preview adjustments")
        siteClone.setLock(true)
        siteClone.setRotation(previewTransform.rotation)
        siteClone.setScale(vector(1.8, 0.00001, 1.8))
        siteClone.setPosition(previewTransform.position)
        siteClone.setName("New Atlas Box")
        siteClone.setDescription(SITE_PREVIEW)
        siteClone.addContextMenuItem("RUIN and unify Sites", ruinSites)
        siteClone.addContextMenuItem("EXPLORE new Sites", retrieveRest)
        siteClone.addContextMenuItem("REVISIT an old Site", retrieveBack)
        siteClone.addContextMenuItem("EXPLORE a new Site", retrieveOnce)
        siteClone.addContextMenuItem("Retrieve lost Relics", spawnRelics)
        siteClone.addContextMenuItem("Search (Debug)", search)
        table.insert(sitePreview, siteClone)
        debugLog("Final site preview adjustments complete")
        return 1
    end
    startLuaCoroutine(self, "refreshRevisitPreviewCoroutine")
end


--- ==============================
--- ATLAS BOX RELIC RETRIEVAL
--- ==============================

-- Try to get 10 relics from the Atlas Box 
function spawnRelics()
    debugLog("Spawning relics from Atlas Box")
    function spawnRelicsCoroutine()
        for i = 1, #objects.atlasBox.getObjects() do
            local relicCount = 0    
            local siteWithAttachments = getFromAtlasBox(0)
            for i = 0, 1*getSpeedScale() do
                coroutine.yield(0)
            end
            if relicCount < 10 then
                for _, item in ipairs(siteWithAttachments.getAttachments()) do
                    debugLog("Checking site " .. siteWithAttachments.getName() .. " for relics")
                    local foundRelic = false
                    if relicCount < 10 and dataTableContains(item.tags, tags.relic) then
                        debugLog("Found relic at site")
                        foundRelic = true
                    end
                    if foundRelic then
                        debugLog("Detaching relic from site " .. siteWithAttachments.getName())
                        local attachments = siteWithAttachments.removeAttachments()
                        local transform = getTransformStruct("relicStack", 0, mapTransform)
                        for _, obj in ipairs(attachments) do
                            if obj.hasTag(tags.relic) and relicCount < 10 then
                                relicCount = relicCount + 1
                                obj.setScale(vector(0.96, 1.0, 0.96)) --Sometimes attaching skews the scale
                                obj.setPosition(transform.position)
                                obj.setRotation(transform.rotation)
                            else
                                siteWithAttachments.addAttachment(obj)
                            end
                        end
                        debugLog("Detaching relic from site " .. siteWithAttachments.getName() .. " complete")
                    end
                end
            end
            for i = 0, 5*getSpeedScale() do
                coroutine.yield(0)
            end
            putSiteIntoAtlasBox(siteWithAttachments)
        end
        printToAll("Retrieved " .. relicCount .. " relics from the Atlas Box")
        refreshRevisitPreview()
        debugLog("Spawning relics from Atlas Box complete")
        return 1
    end
    startLuaCoroutine(self, "spawnRelicsCoroutine")
end

-- ==============================
-- UTILITY
-- ==============================

function roundToNearest180(z)
    -- Round z rotation to nearest 0, 180, or 360
    local nearest = 0
    if math.abs(z - 180) < math.abs(z - 0) and math.abs(z - 180) < math.abs(z - 360) then
        nearest = 180
    elseif math.abs(z - 360) < math.abs(z - 0) then
        nearest = 360
    end
    return nearest
end

-- Get object from Atlas Box at a given index
function getFromAtlasBox(i)
    local isUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    local toSpawn = objects.atlasBox.takeObject({
        index = i,
        position = vectorSum(objects.atlasBoxModel.getPosition(),vector(0,0,-5)),
        rotation = vectorSum(objects.atlasBoxModel.getRotation(),vector(180,0,0))
    })
    if not isUnlocked
        then objects.atlasBox.removeTag(tags.unlocked)
    end
    return toSpawn
end

-- Put site into the Atlas Box with attachments
function putSiteIntoAtlasBox(site)
    local isUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    site.setRotation({x=0,y=180,z=180})
    objects.atlasBox.putObject(site)
    if not isUnlocked then
        objects.atlasBox.removeTag(tags.unlocked)
    end
end

-- Put object into the Atlas Box with attachments
function putIntoAtlasBox(objs, shouldRefreshPreview)
    local isUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    local site = nil
    for _, obj in ipairs(objs) do
        if obj.hasTag(tags.site) then
            site = obj
            site.setRotation({x=0,y=180,z=180})
            for i = 0, 3*getSpeedScale() do
                coroutine.yield(0)
            end
            break
        end
    end
    for _, obj in ipairs(objs) do
        if not (obj.hasTag(tags.site)) then
            site.addAttachment(obj)
        end
    end
    for i = 0, 10*getSpeedScale() do
        coroutine.yield(0)
    end
    objects.atlasBox.putObject(site)
    if shouldRefreshPreview then
        refreshRevisitPreview()
    end
    if not isUnlocked then
        objects.atlasBox.removeTag(tags.unlocked)
    end
    return true
end

-- Spawn all objects from a list at a given position and rotation
function spawnSiteAndAttachmentsAtTransform(site, baseTransform, duringSetup) 
    function spawnSiteAndAttachmentsAtTransformCoroutine() 
        debugLog("Spawning site and attachments at given location")
        local relicNumber, denizenNumber, denizenCount = 0, 0, 0
        local siteAttachments = site.removeAttachments()
        site.setPositionSmooth(baseTransform.position, false)
        site.setRotationSmooth(baseTransform.rotation, false)
        site.addContextMenuItem("Preserve Site", markCard)
        site.addContextMenuItem("Allow Site to Ruin", unMarkCard)
        if(duringSetup) then
            site.setLock(true)
        end
        -- Take out edifices and relics
           -- Count edifices first but take relics out first since they can collide
        debugLog("Counting attachments for site " .. site.getName())
        for _, obj in ipairs(siteAttachments) do
            local transform = nil
            if obj.hasTag(tags.edifice) or obj.hasTag(tags.card) then
                denizenNumber = denizenNumber+1
            end
        end
        for _, obj in ipairs(siteAttachments) do
            local transform = nil
            if obj.hasTag(tags.relic) then
                transform = getTransformStruct("relic", denizenNumber, baseTransform)
                denizenNumber = denizenNumber + 1
                relicNumber = relicNumber + 1
            end
            if transform then
                for i = 0, 1*getSpeedScale() do
                    coroutine.yield(0)
                end
                obj.setRotationSmooth(rot.relic, false)
                obj.setPositionSmooth(transform.position, false)
                obj.setScale(vector(0.96, 1.0, 0.96)) --Sometimes attaching skews the scale
            end
        end
        denizenNumber = 0
        debugLog("Spawning denizen attachments for site " .. site.getName())
        for _, obj in ipairs(siteAttachments) do
            local transform = nil
            if obj.hasTag(tags.edifice) or obj.hasTag(tags.card) then
                transform = getTransformStruct("denizen", denizenNumber, baseTransform)
                denizenNumber = denizenNumber+1
            end
            if transform then
                for i = 0, 1*getSpeedScale() do
                    coroutine.yield(0)
                end
                obj.setPositionSmooth(transform.position, false)
                obj.setRotationSmooth({x=roundToNearest180(obj.getRotation().x), y=roundToNearest180(transform.rotation.y), z=roundToNearest180(obj.getRotation().z)}, false)
                obj.setScale(vector(1.65, 1.0, 1.65)) --Sometimes attaching skews the scale
            end
        end
        debugLog("Spawning denizen attachments for site " .. site.getName() .. " complete")
        denizenNumber = denizenNumber + relicNumber
        local relicSlots = getSiteScriptTag(site, "RelicSlots")
        local banditSlots = 3-relicSlots
        -- Add any new relics
        debugLog("Adding relics for site " .. site.getName());
        if relicNumber < relicSlots then
            if objects.relicDeck == nil then
                printToAll("Cannot find Relic Deck. Get more relics from the Atlas Box")
            else
                for i = relicNumber, relicSlots-1 do
                    local transform = getTransformStruct("relic", denizenNumber, baseTransform)
                    local newRelic = getRandomObjectFromContainer(objects.relicDeck, false)
                    for i = 0, 1*getSpeedScale() do
                        coroutine.yield(0)
                    end
                    newRelic.setPositionSmooth(transform.position, false)
                    newRelic.setRotationSmooth(rot.relic)
                    denizenNumber = denizenNumber + 1  
                end
            end
        end
        debugLog("Adding relics for site " .. site.getName() .. " complete")
        debugLog("Adding bandits for site " .. site.getName())
        --Add bandits
        if banditSlots > 0 then
            for i = 0, banditSlots-1 do
                local transform = getTransformStruct("bandit", i, baseTransform)
                local newBandit = getRandomObjectFromContainer(objects.banditBag, false)
                for i = 0, 1*getSpeedScale() do
                    coroutine.yield(0)
                end
                newBandit.setPositionSmooth(transform.position)
            end
        end
        debugLog("Adding bandits for site " .. site.getName() .. " complete")
        debugLog("Spawning site and attachments complete")
        return 1
    end
    startLuaCoroutine(self, "spawnSiteAndAttachmentsAtTransformCoroutine")
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
                    local hitObjects = createdZone.getObjects(true)
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

function getEdificeDecks() 
    local decks = {} 
    for deckName, guid in pairs(GUIDs.edificeDecks) do
        decks[deckName] = getObjectFromGUID(guid)
    end
    return decks
end

function getEdificeDeck()
    debugLog("Getting Edifice Deck")
    if not (nil == getObjectFromGUID(GUIDs.edificeDeck)) then
        return getObjectFromGUID(GUIDs.edificeDeck)
    else
        debugLog("Edifice Deck not found, getting by position")
        for _, obj in ipairs(getAllObjects()) do
            -- If the object is a deck and it's position is between -67.15, 18.75 and -63.35,13.45, return that and set it as the Edifice Deck
            if obj.type == "Deck" and 
               obj.getPosition().x > -67.15 and obj.getPosition().x < -63.35 and
               obj.getPosition().z > 13.45 and obj.getPosition().z < 18.75 then
                debugLog("Found Edifice Deck by position")
                return obj
            end
        end
    end
    printToAll("Edifice Deck not found. Please place Edifices on the denoted area of the Archives")
    return nil
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

function debugLog(msg)
    if isDebug() then
        printToAll("--" .. msg)
    end
end

function getSiteScriptTag(site, tag)
    return tonumber(string.match(site.getLuaScript(), (tag .. "=(%d+)")))
end

function getSpeedScale()
    if (getSpeedDisplayButton() ~= nil) then
        return 30/getSpeedDisplayButton().label
    end
    return 3
end

function getSpeedDisplayButton()
    for _, obj in ipairs(self.getButtons()) do
        if obj.tooltip == "speedDisplay" then
            return obj
        end
    end
    return nil
end

function speedUp(obj, color, alt_click)
    local speedDisplayButton = getSpeedDisplayButton()
    if speedDisplayButton ~= nil then
        local newSpeed = math.min(30, speedDisplayButton.label + 1)
        self.editButton({
            index = speedDisplayButton.index,
            label = newSpeed
        })
    end
end

function speedDown(obj, color, alt_click)
    local speedDisplayButton = getSpeedDisplayButton()
    if speedDisplayButton ~= nil then
        local newSpeed = math.max(2, speedDisplayButton.label - 1)
        self.editButton({
            index = speedDisplayButton.index,
            label = newSpeed
        })
    end
end

function nothing()
end


-- ==============================
-- EVENT HANDLERS
-- ==============================
function tryRandomize(object)
    return false
end

-- function onObjectLeaveContainer(container, leave_object)
--     -- debugLog(container.getGUID())
--     -- debugLog(objects.atlasBox.getGUID())
--     -- debugLog(tostring(container == objects.atlasBox))
--     -- debugLog(tostring(objects.atlasBoxModel.hasTag(tags.unlocked)))
--     -- printToAll(tostring((container.getGUID() == objects.atlasBox.getGUID()) and (not (objects.atlasBoxModel.hasTag(tags.unlocked)))))
--     if ((container.getGUID() == objects.atlasBox.getGUID()) and (not (objects.atlasBoxModel.hasTag(tags.unlocked)))) then
--         printToAll("Atlas Box manipulation is handled by scripting.\nIf you really want to manually change things, change tags on the Atlas Box to remove its lock.\n")
--         container.putObject(leave_object)
--     end
-- end

-- function tryObjectEnter(object)
--     if self.hasTag(tags.unlocked) then
--         return true
--     else
--         printToAll("Atlas Box manipulation is handled by scripting.\nIf you really want to manually change things, change tags on the Atlas Box to remove its lock.\n")
--         return false
--     end
-- end

-- function peek(obj, player_clicker_color, alt_click)
--     showAtlasBoxPreview(player_clicker_color)
-- end

-- --TODO: Add an interface and show attachments
-- function showAtlasBoxPreview(player_color)
--     function showAtlasBoxPreviewCoroutine()
--         -- Set up globals to track image URLs
--         local imageAndAttachments = {}
--         local numSites = #objects.atlasBox.getObjects();

--         -- Pull the last 2 items
--         for i = 1, numSites do
--             local siteWithAttachments = getFromAtlasBox(0)
--             for j = 0, 2*getSpeedScale() do
--                 coroutine.yield(0)
--             end
--             if i == 1 or i == 2 then
--                 local relicCount = 0
--                 local edificeCount = 0
--                 for _, obj in ipairs(siteWithAttachments.getAttachments()) do
--                     if dataTableContains(obj.tags, tags.relic) then
--                         relicCount = relicCount + 1
--                     elseif dataTableContains(obj.tags, tags.edifice) then
--                         edificeCount = edificeCount + 1
--                     end
--                 end
--                 table.insert(imageAndAttachments, {image = getImageFromObject(siteWithAttachments), relicCount = relicCount, edificeCount = edificeCount, object = siteWithAttachments})
--             end
--             putSiteIntoAtlasBox(siteWithAttachments)
--         end

--         showPreviewUI(player_color, imageAndAttachments)
--         return 1
--     end
--     startLuaCoroutine(self, "showAtlasBoxPreviewCoroutine")
-- end

function getImageFromObject(obj)
    local custom = obj.getCustomObject()
    if custom.face then
        return custom.face
    elseif custom.image then
        return custom.image
    else
        return "https://via.placeholder.com/300x300.png?text=No+Image"
    end
end

function search(player_color)
    if self.hasTag(tags.debug) then
        objects.atlasBox.Container.search(player_color)
    end 
end