-- Atlas Box scripts written by harsch.  Last update:  02-01-2025


-- ==============================
-- CONFIGURATION
-- ==============================

-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
local GUIDs = {
    atlasBox = "f8bd3c",
    edifices = "1662f7",
    relicBag = "c46336",
    shadowBag = "1ce44a",
    siteBag = "12dafe",
    table = "4ee1f2",
    map = "d5dacf",
}

-- Objects for needed game objects.
local objects = {
    atlasBox = nil,
    edificeBag = nil,
    relicBag = nil,
    shadowBag = nil,
    siteBag = nil,
    table = nil,
    map = nil
}

-- Function to convert hex color to Color object (added early to not break buttons store)
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

-- Buttons
local buttons = {
    retry = {
        click_function = "retry",
        function_owner = self,
        label          = "Fix missing objects \n and click me \n to retry",
        position       = {0, 0, 2.6},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1000,
        height         = 500,
        font_size      = 110,
        color          = hexToColor("#823030"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Place missing objects and retry", 
    },
    retrieve = {
        click_function = "retrieveInit",
        function_owner = self,
        label          = "→ Summon a Site →",
        position       = {-1.85, 0, 0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        color          = hexToColor("#588087"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Retrieve a Site and all objects there from the front of the Atlas Box", 
    },
    retrieveBack = {
        click_function = "retrieveBackInit",
        function_owner = self,
        label          = "→ (from the back) →",
        position       = {-1.85, 0, 2.},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 100,
        font_size      = 50,
        color          = hexToColor("#588087"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Retrieve a Site and all objects there from the back of the Atlas Box", 
    },
    setup = {
        click_function = "chronicleSetup",
        function_owner = self,
        label          = "Setup Initial\nAtlas Box\nand Sites",
        position       = {0, 0, 2.6},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1000,
        height         = 500,
        font_size      = 130,
        color          = hexToColor("#4a915d"),
        font_color     = {1, 1, 1, 1},
        tooltip        = "Set Up the Atlas Box for a new Chronicle", 
    },
    spawnRelics = {
        click_function = "spawnRelics",
        function_owner = self,
        label          = "Retrieve Lost Relics",
        position       = {0, 0, 2.1},
        scale          = {1.0,   1.0, 2.0 },
        rotation       = {0, 0, 0},
        width          = 1050,
        height         = 250,
        font_size      = 80,
        font_color     = hexToColor("#e6bb4a"),
        color          = hexToColor("#8a363b"),
        tooltip        = "Retrieve 10 relics from the Atlas Box if you run out", 
    },
    storeStaged = {
        click_function = "storeInit",
        function_owner = self,
        position       = {-1.85, 0, -0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        font_color     = {1, 1, 1, 1},
        label          = "←    Confirm?    ←",
        color          = hexToColor("#4a915d"),
        hover_color    = hexToColor("#58b872"),
        tooltip        = "Confirm?", 
    },
    storeUnstaged = {
        click_function = "storeInit",
        function_owner = self,
        position       = {-1.85, 0, -0.85},
        scale          = {1.0,   1.0,   2.0 },
        rotation       = {0, 0, 0},
        width          = 725,
        height         = 400,
        font_size      = 77,
        font_color     = {1, 1, 1, 1},
        label          = "← Into Atlas Box ←",
        color          = hexToColor("#588087"),
        hover_color    = nil,
        tooltip        = "Move Sites, Relics, Edifices and Shadow into the Atlas box", 
    }
}

-- Tags to identify items
local tags = {
    chronicleCreated = "chronicleCreated",
    edifice = "Edifice",
    relic = "Relic",
    shadow = "Shadow",
    site = "Site",
    unlocked = "Unlocked",
}

-- Name strings to use for Atlas Slots depending on their states
local atlasSlotNames = {
    empty = "[Empty] Slot",
    full = "[Full] Slot"
}

-- Tables to track things on the portal
local portal = {
    edifices = {},
    relics = {},
    shadow = {},
    sites = {},
}

-- {33.30, 1.45, 1.00}
-- {33.30, 1.50, 0.00}

-- Positions
local pos = {
    -- relative to site
    denizen =       function(i) return {x = 5.35+3.3*i, y = 0.25, z = 0} end,
    relic =         function(i) return {x = -0.15, y = 0.25*i, z = -1.3+1.3*i} end,
    shadow =        function(i) return {x = -2.275, y = 1, z = 0.570} end,
    -- relative to atlas portal
    portal =        function(i) return {x = 0, y = 5, z = 0} end,
    -- relative to map
    relicStack =    function(i) return {x = -19.7, y = 0.55,  z = -9.9} end,
    site =          function(i)
                        local sitePositions = {
                            { x = -26.55, y = 0.21, z =  5.00 },
                            { x = -26.55, y = 0.21, z = -0.75 },
                            { x = -06.10, y = 0.21, z =  5.00 },
                            { x = -06.10, y = 0.21, z = -0.75 },
                            { x = -06.10, y = 0.21, z = -6.50 },
                            { x =  14.85, y = 0.21, z =  5.00 },
                            { x =  14.85, y = 0.21, z = -0.75 },
                            { x =  14.85, y = 0.21, z = -6.50 }
                        }
                        return sitePositions[i]
                    end,
}

-- Rotations
local rot = {
    denizen =       {x = 180, y = 0,   z = 0},
    portal =        {x = 0,   y = 180, z = 0},
    relic =         {x = 180, y = 0,   z = 0},
    relicStack =    {x = 180, y = 0,   z = 0},
    shadow =        {x = 0,   y = 180, z = 0},
    site =          {x = 0, y = 180,   z = 0},
}

-- ==============================
-- INITIALIZATION
-- ==============================

function onLoad()
    -- Create all needed tags by adding them to this object and then removing them
    local tagsToAdd = {tags.site, tags.relic, tags.edifice, tags.shadow, tags.unlocked}
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
        {objectName = "edificeBag", GUID = GUIDs.edifices, printableName = "Edifices Bag"},
        {objectName = "relicBag", GUID = GUIDs.relicBag, printableName = "Relic Bag"},
        {objectName = "shadowBag", GUID = GUIDs.shadowBag, printableName = "Shadow Denizens Bag"},
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
    local staged = #portal.sites + #portal.relics + #portal.edifices + #portal.shadow > 0
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
        {bag = objects.edificeBag,  tag = tags.edifice},
        {bag = objects.shadowBag,   tag = tags.shadow}
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
    if not alt_click then
        -- If items are missing we need to retry setup
        if not setupObjects() then
            removeButtons(buttons.setup)
            self.createButton(buttons.retry)
            return
        end
        local mapTransform = {position = objects.map.getPosition(), rotation = objects.map.getRotation()}
        -- Take all sites and put them in the Atlas Box. Roll a d6 and add additional items depending on the roll
        local numSites = #objects.siteBag.getObjects()
        for i = 1, numSites do
            local atlasSlotBag = getAtlasBag(numSites-i)
            rollAndAddItems(atlasSlotBag, i)
            putAtlasBag(atlasSlotBag)
        end
        -- Deal Starting Sites
        for siteNumber = 1,8 do
            local atlasSlotBag = getAtlasBag(0)
            spawnAllFromBagAtTransform(atlasSlotBag, getTransformStruct("site", siteNumber, mapTransform))
            putAtlasBag(atlasSlotBag)
        end
        -- Clean up contents of remaining bags
        local bagsAndTransforms = {
            {bag = objects.edificeBag, transform = {position = objects.edificeBag.getPosition(), rotation = {x=0,y=180,z=0}}},
            {bag = objects.relicBag, transform = getTransformStruct("relicStack", 0, mapTransform)}
        }
        for _, bagAndTransform in ipairs(bagsAndTransforms) do
            for _, item in ipairs(bagAndTransform.bag.getObjects()) do
                bagAndTransform.bag.takeObject(bagAndTransform.transform)
            end
        end

        -- Clean up the bags and add the chronicle created tag
        self.addTag(tags.chronicleCreated)
        removeButtons(buttons.setup)
        destroyObject(objects.siteBag)
        destroyObject(objects.edificeBag)
        destroyObject(objects.relicBag)
        printToAll("SETUP COMPLETE. Don't forget to add Edifices back to the corresponding suit decks before setting up the World Deck\n")
        refreshStoreButton()
        createButtons(buttons.retrieve, buttons.spawnRelics, buttons.retrieveBack)
    end
end

function rollAndAddItems(atlasSlotBag, i)
    local rollResults = {
        [1] = {getRandomEdifice},
        [2] = {},
        [3] = {getRandomRelic},
        [4] = {getRandomRelic, getRandomRelic},
        [5] = {getRandomShadow, getRandomRelic},
        [6] = {getRandomShadow, getRandomRelic, getRandomRelic}
    }
    local d6roll = math.random(1,6)
    printToAll("Slot " .. i .. ", Roll " .. d6roll)
    atlasSlotBag.putObject(getRandomSite())
    for _, func in ipairs(rollResults[d6roll] or {}) do
        atlasSlotBag.putObject(func())
    end
end

-- Get Elements for creating Chronicle
function getRandomShadow()
    return getRandomObjectFromContainer(objects.shadowBag, false)
end
function getRandomRelic()
    return getRandomObjectFromContainer(objects.relicBag, false)
end
function getRandomSite()
    local site = getRandomObjectFromContainer(objects.siteBag, false)
    addTagAndReturn(site, tags.site).setRotation({x=0,y=180,z=0})
    return site
end
function getRandomEdifice()
    return getRandomObjectFromContainer(objects.edificeBag, true)
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
        {tag = tags.edifice, data = portal.edifices, printableName = "Edifice"},
        {tag = tags.shadow, data = portal.shadow, printableName = "Shadow"},
    }
    
    -- First time we validate the objects and check with the user
    if #portal.sites + #portal.relics + #portal.edifices + #portal.shadow == 0 then
        countAndValidatePortalItems(zone, tagsAndPortalObjs)
        return

    -- Subsequent times we actually store the objects into the atlasbox
    else
        -- Check that all objects match last button press
        local perfectMatch = true
        local itemCount = #portal.sites + #portal.relics + #portal.edifices + #portal.shadow
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
        if #portal.shadow > 1 then printToAll("More than 1 Shadow. This is not typical but may be an exceptional case with current rules.") end
        refreshStoreButton()
        printToAll("Click the send button again to confirm.\n")
    else
        printToAll("No objects on the Atlas Portal to send.\n")
    end
end

function emptyStoredPortalObjs()
    portal.sites, portal.relics, portal.edifices, portal.shadow = {}, {}, {}, {} 
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
        {tag = tags.edifice, data = {count = 0, printName = "Edifice"}},
        {tag = tags.shadow, data = {count = 0, printName = "Shadow"}},
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
    spawnAllFromBagAtTransform(atlasSlotBag, spawnTransform)
    putAtlasBag(atlasSlotBag)
    
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
        {tag = tags.edifice, data = {count = 0, printName = "Edifice"}},
        {tag = tags.shadow, data = {count = 0, printName = "Shadow"}},
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
    spawnAllFromBagAtTransform(atlasSlotBag, spawnTransform)
    putAtlasBag(atlasSlotBag)
    
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
    else
        bag.setName(atlasSlotNames.empty)
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
function spawnAllFromBagAtTransform(bag, baseTransform) 
    local relicNumber, denizenNumber, denizenCount = 0, 0, 0;
    local atlasObjects = bag.getObjects()
    for _, obj in ipairs(atlasObjects) do
        if dataTableContains(obj.tags, tags.edifice) then
            denizenCount = denizenCount + 1
        end
    end
    for _, obj in ipairs(atlasObjects) do
        local transform = nil
        if dataTableContains(obj.tags, tags.site) then
            transform = baseTransform
        elseif dataTableContains(obj.tags, tags.shadow) then
            transform = getTransformStruct("shadow", 0, baseTransform)
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
            -- it takes the sites a moment to load so lock objects for a moment so colliders work properly
            Wait.condition(
                function()
                    bagObj.setLock(true)
                    Wait.time(function()
                        bagObj.setLock(false)
                    end, 3)
                end,
                function()
                    return not bagObj.isSmoothMoving()
                end
            )
            if dataTableContains(obj.tags, tags.site) then bagObj.setColorTint(Color(0,0,0)) end
        end
    end
end

function isPortalEmpty(zone)
    -- Validate that the portal is empty
    if #portal.sites + #portal.edifices + #portal.relics + #portal.shadow > 0 then
        printToAll("ERROR: Cannot Summon while storing sites\n")
        return false
    end
    for _, obj in ipairs(zone.getObjects(true)) do
        if obj.hasTag(tags.site) or obj.hasTag(tags.relic) or obj.hasTag(tags.edifice) or obj.hasTag(tags.shadow) then
            printToAll("ERROR: Cannot Summon while pieces are on the Portal\n")
            return false
        end
    end
    return true
end

-- ==============================
-- GENERAL ULILTIY
-- ==============================

function dataTableContains(table, x)
    for _, obj in ipairs(table) do
        if obj == x then return true end
    end
    return false
end

function getRandomObjectFromContainer(container, flipped)
    local objects = container.getObjects()
    if #objects == 0 then return nil end  -- Prevent errors when bag is empty
    local selected = objects[math.random(1, #objects)]

    return container.takeObject({
        guid = selected.guid,
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

function removeButtons(...)
    local buttonsToRemove = {...}
    for _, buttonToRemove in ipairs(buttonsToRemove) do
        local buttonIndex = nil
        if self.getButtons() then
            for i, button in ipairs(self.getButtons()) do
                if button and button.label == buttonToRemove.label then
                    buttonIndex = button.index
                    break
                end
            end
            if buttonIndex then self.removeButton(buttonIndex) end
        end
    end
end

function createButtons(...)
    local buttonsToCreate = {...}
    for _, buttonToCreate in ipairs(buttonsToCreate) do
        self.createButton(buttonToCreate)
    end
end

function addTagAndReturn(item, tag)
    item.addTag(tag)
    return item
end