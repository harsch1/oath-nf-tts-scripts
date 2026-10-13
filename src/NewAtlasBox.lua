-- Atlas Box scripts written by harsch and Frack and AdoptedAndy.  Last update:  05-10-2025

require("src/Utils/ColorUtils")
require("src/Config/GeneralConfig")
require("src/Config/AtlasBoxButtons")
require("src/Utils/HelperFunctions")
require("src/XmlHelper")

-- Objects for needed game objects.
local objects = {
    atlasBox = nil,
    banditBag = nil,
    relicDeck = nil,
    relicPile = nil,
    map = nil,
    relicBag = nil,
    favorBag = nil,
    secretBag = nil,
    edificeDecks = {
        Arcane = nil,
        Beast = nil,
        Discord = nil,
        Hearth = nil,
        Nomad = nil,
        Order = nil
    }
}

local SITE_PREVIEW = "SITE PREVIEW"

local mapTransform = nil
local selfTransform = nil
local sitePreview = {}         -- denizen/relic preview cards, respawned on each refresh
local sitePreviewSite = nil     -- the site preview model, kept up permanently
local SITE_PREVIEW_MEMO = "sitePreviewSite"
local retrieveInCooldown = false
local pendingScriptTakes = 0    -- scripted takes from the Atlas Box not yet seen by onObjectLeaveContainer


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
    updateStarsButton()
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
        self.addContextMenuItem("ALL RECENT Sites", retrieveBackAll)
        self.addContextMenuItem("ALL FORGOTTEN Sites", retrieveRest)
        self.addContextMenuItem("1 RECENT Site", retrieveBack)
        self.addContextMenuItem("1 FORGOTTEN Site", retrieveOnce)
        debugLog("Atlas Box context menu items added and Foundation 9 button")

        refreshRevisitPreview()
    -- If the chronicle is not created we need to spawn setup buttons
    elseif not chronicleExists then
        if setupObjects(false) then
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
        {objectName = "atlasBox", GUID = GUIDs.atlasBox, printableName = "Atlas Box"},
        {objectName = "map", GUID = GUIDs.map, printableName = "Map"},
        {objectName = "banditBag", GUID = GUIDs.banditBag, printableName = "Bandit Bag"},
        {objectName = "favorBag", GUID = GUIDs.favorBag, printableName = "Favor Bag"},
        {objectName = "secretBag", GUID = GUIDs.secretBag, printableName = "Secret Bag"},
    }
    local setupTable = {
        {objectName = "edificeDecks/Arcane", GUID = GUIDs.edificeDecks.Arcane, printableName = "Arcane Edifice Deck"},
        {objectName = "edificeDecks/Beast", GUID = GUIDs.edificeDecks.Beast, printableName = "Beast Edifice Deck"},
        {objectName = "edificeDecks/Discord", GUID = GUIDs.edificeDecks.Discord, printableName = "Discord Edifice Deck"},
        {objectName = "edificeDecks/Hearth", GUID = GUIDs.edificeDecks.Hearth, printableName = "Hearth Edifice Deck"},
        {objectName = "edificeDecks/Nomad", GUID = GUIDs.edificeDecks.Nomad, printableName = "Nomad Edifice Deck"},
        {objectName = "edificeDecks/Order", GUID = GUIDs.edificeDecks.Order, printableName = "Order Edifice Deck"},
        {objectName = "relicPile", GUID = GUIDs.relicPile, printableName = "Relic Pile"}
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
            if setupItem.objectName:find("/") then
                local parts = {}
                for part in string.gmatch(setupItem.objectName, "[^/]+") do
                    table.insert(parts, part)
                end
                objects[parts[1]][parts[2]] = getObjectFromGUID(setupItem.GUID)
                if objects[parts[1]][parts[2]] == nil then
                    printToAll("ERROR: Cannot find " .. setupItem.printableName .. " by GUID")
                    foundAll = false
                end
            else
                objects[setupItem.objectName] = getObjectFromGUID(setupItem.GUID)
                if objects[setupItem.objectName] == nil then
                    printToAll("ERROR: Cannot find " .. setupItem.printableName .. " by GUID")
                    foundAll = false
                end
            end
        end
        debugLog("Detecting setup objects complete")
    else
        debugLog("Detecting site objects and adding context menu items")
        for _, obj in ipairs(getAllObjects()) do
            if obj.getDescription() == SITE_PREVIEW then
                if obj.memo == SITE_PREVIEW_MEMO and sitePreviewSite == nil then
                    sitePreviewSite = obj
                    addSitePreviewMenu(obj)
                else
                    table.insert(sitePreview, obj)
                end
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
            -- Take all sites and put them in the Atlas Box.
            printToAll("creating the world...")
            for _, edificeDeck in pairs(objects.edificeDecks) do
                edificeDeck.shuffle()
            end
            debugLog("Shuffling sites and attaching edifices")
            -- The Atlas Box can't be shuffled, so shuffle the GUIDs
            -- ourselves. putObject adds to the back, so taking each site in this order and putting
            -- it back leaves the box in this order.
            math.randomseed(os.time())
            local siteGuids = {}
            for _, entry in ipairs(objects.atlasBox.getObjects()) do
                table.insert(siteGuids, entry.guid)
            end
            for i = #siteGuids, 2, -1 do
                local j = math.random(i)
                siteGuids[i], siteGuids[j] = siteGuids[j], siteGuids[i]
            end
            for _, siteGuid in ipairs(siteGuids) do
                local site = getFromAtlasBox(nil, nil, siteGuid)
                for i = 0, 2*getSpeedScale() do
                    coroutine.yield(0)
                end
                local denizenCount = 0
                if dataTableContains(getSiteScriptTag(site, "Tags"), "Homeland") then
                    local edifice = nil
                    -- Get the non-homeland tag to determine which edifice deck to draw from
                    edifice = getRandomObjectFromContainer(objects.edificeDecks[getSiteScriptTag(site, "Tags")[2]], false)
                    edifice.setPosition(
                        getTransformStruct("denizen",
                        0,
                        { position= site.getPosition(), rotation= site.getRotation()}
                    ).position)
                    site.putObject(edifice)
                    denizenCount = denizenCount + 1
                end
                for i = 0, 1*getSpeedScale() do
                    coroutine.yield(0)
                end
                putSiteIntoAtlasBox(site)
            end
            debugLog("Shuffling sites and attaching edifices complete")

            debugLog("Moving Relic Deck")
            objects.relicPile.shuffle()
            objects.relicDeck = objects.relicPile
            objects.relicDeck.setPosition(getTransformStruct("relicStack", 0, mapTransform).position)
            objects.relicDeck.setRotation(getTransformStruct("relicStack", 0, mapTransform).rotation)
            objects.relicDeck.setName("Relic Deck")
            objects.relicDeck.setMemo("relicDeck")
            
            -- Deal Starting Sites
            debugLog("Dealing starting sites")
            for siteNumber = 1,8 do
                local site = getFromAtlasBox(0, function(spawnedObject)
                    spawnSiteAndContainedItemsAtTransform(spawnedObject, getTransformStruct("site", siteNumber, mapTransform))
                end
                )
                for i = 0, 2*getSpeedScale() do
                    coroutine.yield(0)
                end
            end
            
            generateNewWorldDeck()

            debugLog("Creating world deck complete. Adding context menu items")
            self.addTag(tags.chronicleCreated)
            removeButtons(buttons.setup)
            -- createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack, buttons.ruinSites,  buttons.unifySites)
            self.addContextMenuItem("RUIN and unify Sites", ruinSites)
            self.addContextMenuItem("ALL RECENT Sites", retrieveBackAll)
            self.addContextMenuItem("ALL FORGOTTEN Sites", retrieveRest)
            self.addContextMenuItem("1 RECENT Site", retrieveBack)
            self.addContextMenuItem("1 FORGOTTEN Site", retrieveOnce)
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
    -- add 10 cards from each suit

    debugLog("Creating world deck with 10 cards of each suit")
    for _, suit in ipairs(suits) do
        local deck = decks[suit]
        for i=1, 10 do
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
    dispossessed.shuffle()
    debugLog("Creating dispossessed deck complete")
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
        -- Store the objects in the Atlas Box in the empty slot closest to the front
        debugLog("Storing objects in Atlas Box")
        for i = 1, #toStore do
            putIntoAtlasBox(toStore[i], true)
            storedSites = storedSites + 1
        end
        debugLog("Storing objects in Atlas Box complete")
        refreshRevisitPreview()
        unifySites()
        return 1
    end

    function getRuinableObjectsAtSite(hitObjects, index)
        local isProtected = false
        local isEnduring = false
        local protectedSite

        debugLog("Checking for ruinable objects at site " .. index)
        for _, obj in ipairs(hitObjects) do
            if obj.hasTag(tags.site) then
                obj.setLock(false)
                isProtected = obj.hasTag(tags.protected)
                unMarkCard(_,_,obj)
                if dataTableContains(getSiteScriptTag(obj, "Tags"), "Enduring") then
                    isEnduring = true
                end
            end
        end
        debugLog("Checking for ruinable objects at site " .. index .. " complete")
        local toStoreSlot = {}
        debugLog("Getting storable objects at site " .. index)
        for _, obj in ipairs(hitObjects) do
            -- The site itself or a relic
            if obj.hasTag(tags.favor) or obj.hasTag(tags.secret) then
                obj.destruct()
            end
            if not isProtected then
                if (obj.hasTag(tags.site) or obj.hasTag(tags.relic)) then
                    table.insert(toStoreSlot, obj)
                    obj.setRotation({x= obj.getRotation().x, y= roundToNearest180(obj.getRotation().y), z=roundToNearest180(obj.getRotation().z)})
                -- Any cards or edifices if the site is enduring
                elseif ((obj.hasTag(tags.card) or obj.hasTag(tags.edifice)) and isEnduring) then
                    table.insert(toStoreSlot, obj)
                -- Any edifices that are right side up
                elseif (obj.hasTag(tags.edifice) and (obj.getRotation().z < 10 or obj.getRotation().z > 350)) then
                    table.insert(toStoreSlot, obj)
                    obj.setRotation({x= obj.getRotation().x, y= roundToNearest180(obj.getRotation().y), z=roundToNearest180(obj.getRotation().z)})
                -- Bandits
                elseif (obj.hasTag(tags.bandit)) then
                    objects.banditBag.putObject(obj)
                -- Ruined edifices
                elseif obj.hasTag(tags.edifice) or obj.hasTag(tags.card) then
                    local suit = getScriptTag(obj, "Suit")
                    if suit then
                        if obj.hasTag(tags.edifice) then
                            if getEdificeDeck(suit) ~= nil then
                                getEdificeDeck(suit).putObject(obj)
                            else 
                                obj.setPositionSmooth(getArchiveBoardPosition(pos.edificeDeck, suit), false, true)
                                obj.setRotation({x=0.0, y=180.0, z=0.0})
                            end
                        else
                            if getArchiveDeck(suit) ~= nil then
                                getArchiveDeck(suit).putObject(obj)
                            else 
                                obj.setPositionSmooth(getArchiveBoardPosition(pos.archiveDeck, suit), false, true)
                                obj.setRotation({x=0.0, y=180.0, z=180.0})
                            end
                        end
                    else
                        printToAll("ERROR: Cannot find suit for card " .. obj.getName())
                        obj.setPositionSmooth(vector(-55, 2.0, 13.8), false, true)
                    end
                elseif obj.hasTag(tags.favor) or obj.hasTag(tags.secret) then
                    obj.destruct()
-- TODO: Warbands, Pawns, Clockwork
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
        end
        if #toStoreSlot > 0 then
            table.insert(toStore, toStoreSlot)
        end
        debugLog("Getting storable objects at site " .. index .. " complete")
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
    getObjectsAtSitesThenCallbackForEach(getRuinableObjectsAtSite, false)
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
            local site = nil
            for _, obj in ipairs(hitObjects) do
                if not (obj.getGUID() == GUIDs.map) and
                not (obj.getGUID() == GUIDs.table) and
                not (obj.getGUID() == GUIDs.scriptingTrigger) and
                not (obj.memo == "trigger")  then
                    if obj.hasTag(tags.site) then
                        obj.setLock(true)
                        site = obj
                        isEmpty = false
                    end
                    if obj.hasTag(tags.edifice) then
                        obj.setRotation({x= obj.getRotation().x, y= roundToNearest180(obj.getRotation().y), z=0})
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
                
                debugLog("Adding starting resources for site " .. site.getName())
                local startingResources = getSiteScriptTag(site, "Starting")
                local hasSecrets = 0
                for _, resource in ipairs(startingResources) do
                    if resource == "Secret" then
                        local transform = getTransformStruct("secret", 0, getTransformStruct("site", destinationSlot, mapTransform))
                        objects.secretBag.takeObject({
                            position = transform.position,
                            rotation = {x = 0, y = 180, z = 0}
                        })
                        hasSecrets = 1
                    end
                end

                for _, resource in ipairs(startingResources) do
                    if resource == "Favor" then
                        local transform = getTransformStruct("favor", hasSecrets, getTransformStruct("site", destinationSlot, mapTransform))
                        objects.favorBag.takeObject({
                            position = transform.position,
                            rotation = {x = 0, y = 180, z = 0}
                        })
                    end
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
    getObjectsAtSitesThenCallbackForEach(unifySitesCallback, true)    
end

-- ==============================
-- ATLAS BOX RETRIEVAL
-- ==============================

function retrieve(player_color, object_position, object, retrieveForgotten, continual)
    debugLog("Retrieving site(s) from Atlas Box")
    local retrieveIndex = retrieveForgotten and 0 or (#objects.atlasBox.getObjects())-1
    local hasRetrieved = false
    function retrieveAtFirstEmptySlot(foundObjects, slotNumber)
        if not retrieveForgotten then
            retrieveIndex = #objects.atlasBox.getObjects()-1
        end
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
            local siteWithAttachments = getFromAtlasBox(bagIndex, function(spawnedObject)
                spawnSiteAndContainedItemsAtTransform(spawnedObject, getTransformStruct("site", slotNumber, mapTransform))
            end)
            for _, obj in ipairs(siteWithAttachments.getAttachments()) do
                for _, countAndTag in ipairs(countsAndTags) do
                    if dataTableContains(obj.tags, countAndTag.tag) then
                        countAndTag.data.count = countAndTag.data.count + 1
                    end
                end
            end
            debugLog("Retrieving site " .. bagIndex .. " complete")
            
            local messageParts = {}
            for _, countAndTag in ipairs(countsAndTags) do
                if countAndTag.data.count > 0 then
                    table.insert(messageParts, countAndTag.data.count .. " " .. countAndTag.data.printName)
                end
            end
            if isDebug() then
                printToAll(#messageParts > 0 and ("Summoning Site with " .. table.concat(messageParts, ", ")) or ("Summoning Empty Site"))
            end
            if not retrieveForgotten then
                retrieveIndex = #objects.atlasBox.getObjects()-1
            end
            return
        end
    end
    if retrieveInCooldown then
        printToAll("Wait a sec...")
    end
    if not retrieveInCooldown then
        retrieveInCooldown = true
        getObjectsAtSitesThenCallbackForEach(function(foundObjects, slotNumber)
            retrieveAtFirstEmptySlot(foundObjects, slotNumber)
            -- Refresh preview is cheap now, lets do it on each retrieval
            if not retrieveForgotten then
                refreshRevisitPreview()
            end
        end, true)
        Wait.time(function()
            retrieveInCooldown = false
        end, 0.5)
    end
end

-- "back = recent sites"
function retrieveBack(player_color, object_position, object)
    retrieve(player_color, object_position, object, false, false)
end

function retrieveBackAll(player_color, object_position, object)
    retrieve(player_color, object_position, object, false, true)
end

-- "front = forgotten sites"
function retrieveRest(player_color, object_position, object)
    retrieve(player_color, object_position, object, true, true)
end

function retrieveOnce(player_color, object_position, object)
    retrieve(player_color, object_position, object, true, false)
end

-- Decals for a site bag model: the given image on top, the card back underneath
function getSiteDecals(frontURL)
    local size = siteBagConfig.size
    local surface = size.y / 2 + 0.002
    return {
        {name = "Site front", url = frontURL, position = {0, surface, 0}, rotation = {90, 180, 0}, scale = {size.x, size.z, 1}},
        {name = "Site back", url = siteBagConfig.backURL, position = {0, -surface, 0}, rotation = {270, 0, 0}, scale = {size.x, size.z, 1}},
    }
end

-- Spawn the permanent site preview: a locked site bag model (not a container) showing frontURL
function spawnSitePreview(transform, frontURL)
    local s = sitePreviewConfig.siteScale
    sitePreviewSite = spawnObjectData({
        data = {
            Name = "Custom_Model",
            Nickname = "New Atlas Box",
            Description = SITE_PREVIEW,
            Memo = SITE_PREVIEW_MEMO,
            Locked = true,
            ColorDiffuse = {r = 1, g = 1, b = 1},
            CustomMesh = {
                MeshURL = siteBagConfig.meshURL, DiffuseURL = "", NormalURL = "", ColliderURL = "",
                Convex = true, MaterialIndex = 3, TypeIndex = 0, CastShadows = true,
            },
            Transform = {posX = 0, posY = 0, posZ = 0, rotX = 0, rotY = 0, rotZ = 0, scaleX = s, scaleY = s, scaleZ = s},
        },
        position = transform.position,
        rotation = transform.rotation,
        scale = {x = s, y = s, z = s},
        callback_function = function(preview)
            preview.setDecals(getSiteDecals(frontURL))
            addSitePreviewMenu(preview)
        end,
    })
    self.setLock(true)
end

function addSitePreviewMenu(preview)
    preview.addContextMenuItem("RUIN and unify Sites", ruinSites)
    preview.addContextMenuItem("ALL RECENT Sites", retrieveBackAll)
    preview.addContextMenuItem("ALL FORGOTTEN Sites", retrieveRest)
    preview.addContextMenuItem("1 RECENT Site", retrieveBack)
    preview.addContextMenuItem("1 FORGOTTEN Site", retrieveOnce)
end

-- Show the most recent site in the Atlas Box. Reads the site's data rather than taking it out.
function refreshRevisitPreview()
    debugLog("Refreshing Atlas Box site preview")
    for _, obj in ipairs(sitePreview) do
        destroyObject(obj)
    end
    sitePreview = {}

    -- Use the box's current position, not the one cached at load, in case it has moved since
    local previewTransform = getTransformStruct("preview", 0, {position = self.getPosition()})

    -- The site preview stays up permanently showing the card back; only its front decal changes
    local boxContents = objects.atlasBox.getData().ContainedObjects or {}
    local siteData = boxContents[#boxContents]
    local decals = siteData and siteData.AttachedDecals or {}
    local frontURL = decals[1] and decals[1].CustomDecal.ImageURL or siteBagConfig.backURL
    if sitePreviewSite == nil then
        spawnSitePreview(previewTransform, frontURL)
    else
        sitePreviewSite.setPosition(previewTransform.position)
        sitePreviewSite.setRotation(previewTransform.rotation)
        sitePreviewSite.setDecals(getSiteDecals(frontURL))
    end
    if siteData == nil then return end

    local denizens, relics = {}, {}
    for _, item in ipairs(siteData.ContainedObjects or {}) do
        if item.CustomDeck ~= nil then
            local itemTags = item.Tags or {}
            if dataTableContains(itemTags, tags.relic) then
                table.insert(relics, item)
            elseif dataTableContains(itemTags, tags.edifice) or dataTableContains(itemTags, tags.card) then
                table.insert(denizens, item)
            end
        end
    end

    -- Spawn a locked, tagless copy of a card's face, tracked right away so a quick second refresh still destroys it
    local function spawnPreview(card, scale, offset, rotation)
        table.insert(sitePreview, spawnObjectData({
            data = {
                Name = "CardCustom",
                Nickname = card.Nickname,
                Description = SITE_PREVIEW,
                CardID = card.CardID,
                CustomDeck = card.CustomDeck,
                SidewaysCard = card.SidewaysCard or false,
                HideWhenFaceDown = false,
                Hands = false,
                Locked = true,
                Transform = {posX = 0, posY = 0, posZ = 0, rotX = 0, rotY = 0, rotZ = 0,
                             scaleX = scale.x, scaleY = scale.y, scaleZ = scale.z},
            },
            position = vectorSum(previewTransform.position, offset),
            rotation = rotation,
            scale = scale,
        }))
    end

    -- Denizens/edifices fan across the lower right of the site, keeping whether they're face up or down.
    -- Edifices face the opposite way to denizens
    for i, card in ipairs(denizens) do
        local yRotation = dataTableContains(card.Tags or {}, tags.edifice) and 180 or 360
        local rotation = vectorSum(previewTransform.rotation, {x = 0, y = yRotation, z = roundToNearest180(card.Transform.rotZ)})
        spawnPreview(card, sitePreviewConfig.denizenScale, sitePreviewConfig.denizenOffset(i - 1), rotation)
    end
    -- Relics in a row below them
    for i, card in ipairs(relics) do
        local rotation = vectorSum(previewTransform.rotation, {x = 0, y = 180, z = 0})
        spawnPreview(card, sitePreviewConfig.relicScale, sitePreviewConfig.relicOffset(i - 1), rotation)
    end
end


-- --- ==============================
-- --- ATLAS BOX RELIC RETRIEVAL (deprecated)
-- --- ==============================

-- -- Try to get 10 relics from the Atlas Box 
-- function spawnRelics()
--     debugLog("Spawning relics from Atlas Box")
--     function spawnRelicsCoroutine()
--         for i = 1, #objects.atlasBox.getObjects() do
--             local relicCount = 0    
--             local siteWithAttachments = getFromAtlasBox(0)
--             for i = 0, 1*getSpeedScale() do
--                 coroutine.yield(0)
--             end
--             if relicCount < 10 then
--                 for _, item in ipairs(siteWithAttachments.getAttachments()) do
--                     debugLog("Checking site " .. siteWithAttachments.getName() .. " for relics")
--                     local foundRelic = false
--                     if relicCount < 10 and dataTableContains(item.tags, tags.relic) then
--                         debugLog("Found relic at site")
--                         foundRelic = true
--                     end
--                     if foundRelic then
--                         debugLog("Detaching relic from site " .. siteWithAttachments.getName())
--                         local attachments = siteWithAttachments.removeAttachments()
--                         local transform = getTransformStruct("relicStack", 0, mapTransform)
--                         for _, obj in ipairs(attachments) do
--                             if obj.hasTag(tags.relic) and relicCount < 10 then
--                                 relicCount = relicCount + 1
--                                 obj.setScale(vector(0.96, 1.0, 0.96)) --Sometimes attaching skews the scale
--                                 obj.setPosition(transform.position)
--                                 obj.setRotation(transform.rotation)
--                             else
--                                 siteWithAttachments.addAttachment(obj)
--                             end
--                         end
--                         debugLog("Detaching relic from site " .. siteWithAttachments.getName() .. " complete")
--                     end
--                 end
--             end
--             for i = 0, 5*getSpeedScale() do
--                 coroutine.yield(0)
--             end
--             putSiteIntoAtlasBox(siteWithAttachments)
--         end
--         printToAll("Retrieved " .. relicCount .. " relics from the Atlas Box")
--         refreshRevisitPreview()
--         debugLog("Spawning relics from Atlas Box complete")
--         return 1
--     end
--     startLuaCoroutine(self, "spawnRelicsCoroutine")
-- end

-- ==============================
-- UTILITY
-- ==============================

-- Get object from Atlas Box at a given index
-- Take a site from the Atlas Box by index, or by guid if one is given
function getFromAtlasBox(i, callback, guid)
    local isUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    local takeParams = {
        position = vectorSum(objects.atlasBox.getPosition(),vector(0,0,-5)),
        rotation = vectorSum(objects.atlasBox.getRotation(),vector(180,0,0))
    }
    if guid ~= nil then
        takeParams.guid = guid
    else
        takeParams.index = i
    end
    if callback ~= nil then
        takeParams.callback_function = callback
    end
    -- Let onObjectLeaveContainer know this take came from a script
    pendingScriptTakes = pendingScriptTakes + 1
    local toSpawn = objects.atlasBox.takeObject(takeParams)
    if not isUnlocked
        then objects.atlasBox.removeTag(tags.unlocked)
    end
    return toSpawn
end

-- Put site into the Atlas Box with attachments
function putSiteIntoAtlasBox(site, shouldRefreshPreview)
    local isUnlocked = objects.atlasBox.hasTag(tags.unlocked)
    objects.atlasBox.addTag(tags.unlocked)
    site.setRotation({x=0,y=180,z=180})
    objects.atlasBox.putObject(site)
    if not isUnlocked then
        objects.atlasBox.removeTag(tags.unlocked)
    end
    if shouldRefreshPreview then
        refreshRevisitPreview()
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
            site.setLock(false)
            site.putObject(obj)
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
function spawnSiteAndContainedItemsAtTransform(site, baseTransform) 
    function spawnSiteAndContainedItemsAtTransformCoroutine() 
        debugLog("Spawning site and attachments at given location")
        local relicNumber, denizenNumber, denizenCount = 0, 0, 0
        site.setPosition(baseTransform.position)
        site.setRotation(baseTransform.rotation)
        site.addContextMenuItem("Preserve Site", markCard)
        site.addContextMenuItem("Allow Site to Ruin", unMarkCard)
        for i = 0, 3*getSpeedScale() do
            coroutine.yield(0)
        end
        local siteObjects = site.getObjects()
        -- Take out edifices and relics
           -- Count edifices first but take relics out first since they can collide
        debugLog("Counting attachments for site " .. site.getName())
        for _, obj in ipairs(siteObjects) do
            for _, tag in ipairs(obj.tags) do
                if tag == tags.edifice or tag == tags.card then
                    denizenCount = denizenCount + 1
                    break
                end
            end
        end
        debugLog("Spawning relics for site " .. site.getName())
        for _, obj in ipairs(siteObjects) do
            for _, tag in ipairs(obj.tags) do
                if tag == tags.relic then
                    local transform = getTransformStruct("relic", denizenNumber, baseTransform)
                    denizenNumber = denizenNumber + 1
                    relicNumber = relicNumber + 1
                    site.takeObject({
                        guid = obj.guid,
                        rotation = rot.relic,
                        position = transform.position,
                    })
                    -- obj.setScale(vector(0.96, 1.0, 0.96)) --Sometimes attaching skews the scale
                    break
                end
            end
        end
        denizenNumber = 0
        debugLog("Spawning denizen attachments for site " .. site.getName())
        for _, obj in ipairs(siteObjects) do
            local transform = nil
            for _, tag in ipairs(obj.tags) do
                if tag == tags.edifice or tag == tags.card then
                    transform = getTransformStruct("denizen", denizenNumber, baseTransform)
                    denizenNumber = denizenNumber+1
                    for i = 0, 1*getSpeedScale() do
                        coroutine.yield(0)
                    end
                    site.takeObject({
                        guid = obj.guid,
                        rotation = {x = 180.0, y = 0.0, z = 0.0},
                        position = transform.position,
                    })
                    break
                end
            end
        end
        debugLog("Spawning denizen attachments for site " .. site.getName() .. " complete")
        denizenNumber = denizenNumber + relicNumber
        local relicSlots = getSiteScriptTag(site, "RelicSlots")
        local banditSlots = getSiteScriptTag(site, "DenizenSlots")
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
        if relicNumber > relicSlots then
            printToAll("!!!!Too many relics were attached to the site. Shuffle any excess relics into the Relic Deck!!!!")
        end
        debugLog("Adding relics for site " .. site.getName() .. " complete")
        debugLog("Adding bandits for site " .. site.getName())
        --Add bandits
        if banditSlots > 0 then
            for i = 0, banditSlots-1 do
                local transform = getTransformStruct("bandit", i, baseTransform)
                local newBandit = objects.banditBag.takeObject({
                    position = transform.position,
                    rotation = {x = 0, y = 180, z = 0}
                })
            end
        end
        debugLog("Adding bandits for site " .. site.getName() .. " complete")
        -- Add favor and secrets
        debugLog("Adding starting resources for site " .. site.getName())
        local startingResources = getSiteScriptTag(site, "Starting")
        local hasSecrets = 0
        for _, resource in ipairs(startingResources) do
            if resource == "Secret" then
                local transform = getTransformStruct("secret", 0, baseTransform)
                objects.secretBag.takeObject({
                    position = transform.position,
                    rotation = {x = 0, y = 180, z = 0}
                })
                hasSecrets = 1
            end
        end

        for _, resource in ipairs(startingResources) do
            if resource == "Favor" then
                local transform = getTransformStruct("favor", hasSecrets, baseTransform)
                objects.favorBag.takeObject({
                    position = transform.position,
                    rotation = {x = 0, y = 180, z = 0}
                })
            end
        end
        site.setLock(true)

        debugLog("Adding starting resources for site " .. site.getName() .. " complete")
        debugLog("Spawning site and attachments complete")
        return 1
    end
    startLuaCoroutine(self, "spawnSiteAndContainedItemsAtTransformCoroutine")
    return
end

function getObjectsAtSitesThenCallbackForEach(callback, forwards)
    function getObjectAtSite(callback, index, endIndex, step)
        function getObjectAtSiteCoroutine()
            for i = 0, 3*getSpeedScale() do
                coroutine.yield(0)
            end
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
            return 1
        end
        startLuaCoroutine(self, "getObjectAtSiteCoroutine")
    end

    
    local s, e, c = 1, 8, 1
    if not forwards then
        s, e, c = 8, 1, -1
    end
    getObjectAtSite(callback, s, e, c)    
end

function getArchiveDecks() 
    local decks = {} 
    for suit, guid in pairs(GUIDs.archiveDecks) do
        decks[suit] = getArchiveDeck(suit)
    end
    return decks
end

function getArchiveDeck(suit) 
    local deck = getObjectFromGUID(GUIDs.archiveDecks[suit])
    if deck ~= nil then
        return deck
    end
    -- If the deck is missing we can find it by its position relative to the archive board
    return findDeckNear(getArchiveBoardPosition(pos.archiveDeck, suit))
end

function getEdificeDeck(suit) 
    local deck = getObjectFromGUID(GUIDs.edificeDecks[suit])
    if deck ~= nil then
        return deck
    end
    -- If the deck is missing we can find it by its position relative to the archive board
    return findDeckNear(getArchiveBoardPosition(pos.edificeDeck, suit))
end

-- Returns the world position of a suit's deck on the archive board.
function getArchiveBoardPosition(posFunc, suit)
    local archiveBoard = getObjectFromGUID(GUIDs.archiveBoard)
    if archiveBoard == nil then
        return nil
    end
    local offset = posFunc(suit)
    if offset == nil then
        return nil
    end
    local boardPos = archiveBoard.getPosition()
    return {x = boardPos.x + offset.x, y = boardPos.y + offset.y, z = boardPos.z + offset.z}
end

-- Returns the first deck within 1 unit (on x and z) of the given position
function findDeckNear(position)
    if position == nil then
        return nil
    end
    for _, obj in ipairs(getAllObjects()) do
        if obj.type == "Deck" then
            local objPos = obj.getPosition()
            if math.abs(objPos.x - position.x) < 1 and math.abs(objPos.z - position.z) < 1 then
                return obj
            end
        end
    end
    return nil
end

-- function getEdificeDecks() 
--     local decks = {} 
--     for deckName, guid in pairs(GUIDs.edificeDecks) do
--         decks[deckName] = getObjectFromGUID(guid)
--     end
--     return decks
-- end

-- function getEdificeDeck()
--     debugLog("Getting Edifice Deck")
--     if not (nil == getObjectFromGUID(GUIDs.edificeDeck)) then
--         return getObjectFromGUID(GUIDs.edificeDeck)
--     else
--         debugLog("Edifice Deck not found, getting by position")
--         for _, obj in ipairs(getAllObjects()) do
--             -- If the object is a deck and it's position is between -67.15, 18.75 and -63.35,13.45, return that and set it as the Edifice Deck
--             if obj.type == "Deck" and 
--                obj.getPosition().x > -67.15 and obj.getPosition().x < -63.35 and
--                obj.getPosition().z > 13.45 and obj.getPosition().z < 18.75 then
--                 debugLog("Found Edifice Deck by position")
--                 return obj
--             end
--         end
--     end
--     printToAll("Edifice Deck not found. Please place Edifices on the denoted area of the Archives")
--     return nil
-- end

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

-- Parse a "Key=value" line from script-style text: {"a", "b"} lists, numbers, "strings" or raw text
function parseScriptTag(text, tag)
    if not text then return nil end
    local raw = string.match(text, tag .. "=([^\n]+)")
    if not raw then return nil end
    if string.match(raw, "^%s*{") then
        local list = {}
        for str in string.gmatch(raw, "\"([^\"]*)\"") do
            table.insert(list, str)
        end
        return list
    end
    local num = tonumber(raw)
    if num then return num end
    local str = string.match(raw, "^%s*\"(.*)\"%s*$")
    if str then return str end
    return raw
end

-- Site data (RelicSlots, Tags, Starting, ...) is kept in the site bag's GM Notes
function getSiteScriptTag(site, tag)
    return parseScriptTag(site.getGMNotes(), tag)
end

-- Card data (Card_id, Suit, ...) is kept in the card's script
function getScriptTag(obj, tag)
    return parseScriptTag(obj.getLuaScript(), tag)
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

-- Fires for every container in the game, after the object has already left. Put back anything a
-- player takes out of the Atlas Box; takes made by getFromAtlasBox are counted and let through.
function onObjectLeaveContainer(container, leave_object)
    if container ~= objects.atlasBox then return end
    if pendingScriptTakes > 0 then
        pendingScriptTakes = pendingScriptTakes - 1
        return
    end
    if not self.hasTag(tags.debug) then
        printToAll("Atlas Box manipulation is handled by scripting.\nIf you really want to manually change things, add the Debug tag to the Atlas Box.\n")
        container.putObject(leave_object)
    end
end

function tryObjectEnter(object)
    if self.hasTag(tags.debug) then
        return true
    else
        printToAll("Atlas Box manipulation is handled by scripting.\nIf you really want to manually change things, add the Debug tag to the Atlas Box.\n")
        return false
    end
end

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


function updateStarsButton()
    if (getObjectFromGUID(GUIDs.starsCard) == null) then
        return
    end
    if not (getObjectFromGUID(GUIDs.starsCard).getButtons() == null) then
        for i, button in ipairs(getObjectFromGUID(GUIDs.starsCard).getButtons()) do
            oldColor = button.color
            if not (oldColor == hexToColorAlpha("#00000088")) then
                getObjectFromGUID(GUIDs.starsCard).removeButton(button.index)
                getObjectFromGUID(GUIDs.starsCard).createButton(buttons.starsButtonHidden)
                return
            else
                getObjectFromGUID(GUIDs.starsCard).removeButton(button.index)
                getObjectFromGUID(GUIDs.starsCard).createButton(buttons.starsButton)
                return
            end
        end
    end
    getObjectFromGUID(GUIDs.starsCard).createButton(buttons.starsButton)
end