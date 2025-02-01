-- Atlas Box scripts written by harsch.  Last update:  01-31-2025


--
-- CONFIGS
--

-- GUIDs for needed items. IF SOMETHING IS BROKEN LIKELY THESE ARE NO LONGER CORRECT
local GUIDs = {
    atlasBox = "f8bd3c",
    edifices = "1662f7",
    relicBag = "c46336",
    shadowBag = "1ce44a",
    siteBag = "12dafe",
    table = "4ee1f2",
}

-- Objects for needed game objects.
local objects = {
    atlasBox = nil,
    edificeBag = nil,
    relicBag = nil,
    shadowBag = nil,
    siteBag = nil,
    table = nil,
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
        tooltip        = "Retrieve a Site and all objects there from the Atlas Box", 
    },
    setup = {
        click_function = "setupAtlasBox",
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

-- Positions
local pos = {
    denizen =       function(i) return {x = 5.35+3.3*i, y = 0.25, z = 0} end,
    portal =        function(i) return {x = 0, y = 5, z = 0} end,
    relic =         function(i) return {x = -0.15, y = 0.25*i, z = -1.3+1.3*i} end,
    relicStack =    function(i) return {x = 13.6, y = 2,  z = -8.9} end,
    shadow =        function(i) return {x = -2.275, y = 10, z = 0.570} end,
    site =          function(i)
                        local sitePositions = {
                            { x = 6.75,     y = 2, z =  6.00 },
                            { x = 6.75,     y = 2, z =  0.25 },
                            { x = 27.20,    y = 2, z =  6.00 },
                            { x = 27.20,    y = 2, z =  0.25 },
                            { x = 27.20,    y = 2, z = -5.50 },
                            { x = 48.15,   y = 2, z =  6.00 },
                            { x = 48.15,   y = 2, z =  0.25 },
                            { x = 48.15,   y = 2, z = -5.50 }
                        }
                        return sitePositions[i]
                    end,                   
}

-- Rotations
local rot = {
    denizen =       {x = 180, y = 0,   z = 0},
    portal =        {x = 0,   y = 0, z = 0},
    relic =         {x = 180, y = 0,   z = 0},
    relicStack =    {x = 180, y = 0,   z = 0},
    shadow =        {x = 0,   y = 180, z = 0},
    site =          {x = 180, y = 0,   z = 0},
}

local fromGUID = getObjectFromGUID

function onLoad()
    -- Create all needed tags by adding them to this object and then removing them
    local tagsToAdd = {tags.site, tags.relic, tags.edifice, tags.shadow, tags.unlocked}
    for _, tag in ipairs(tagsToAdd) do
        self.addTag(tag)
        self.removeTag(tag)
    end
    -- We don't want to overwrite the value if the tag is already there
    if not self.hasTag(tags.chronicleCreated) then
        self.addTag(tags.chronicleCreated)
        self.removeTag(tags.chronicleCreated)
    end

    -- If the chronicle is already created we can skip setup
    if self.hasTag(tags.chronicleCreated) then
        if not checkForAtlasObjects() then return end -- Return early if atlas box is missing
        refreshStoreButton()
        self.createButton(buttons.retrieve)
        self.createButton(buttons.spawnRelics)
        return
    -- If the chronicle is not created we need to spawn setup buttons
    else
        if checkForSetupObjects() then
            tagAllItems() -- Tag all items in the bags
            self.createButton(buttons.setup)
        else 
            self.createButton(buttons.retry)
        end
    end
end

-- Validate that setup objects can be found 
function checkForSetupObjects()
    local setupTable = {
        {objectName = "table", GUID = GUIDs.table, printableName = "Table"},
        {objectName = "atlasBox", GUID = GUIDs.atlasBox, printableName = "Atlas Box Bag"},
        {objectName = "edificeBag", GUID = GUIDs.edifices, printableName = "Edifices Bag"},
        {objectName = "relicBag", GUID = GUIDs.relicBag, printableName = "Relic Bag"},
        {objectName = "shadowBag", GUID = GUIDs.shadowBag, printableName = "Shadow Denizens Bag"},
        {objectName = "siteBag", GUID = GUIDs.siteBag, printableName = "Site Bag"}
    }
    local foundAll = true
    for _, setupItem in ipairs(setupTable) do
        objects[setupItem.objectName] = fromGUID(setupItem.GUID)
        if objects[setupItem.objectName] == nil then
            printToAll("ERROR: Cannot find " .. setupItem.printableName .. " by GUID")
            foundAll = false
        end
    end
    return foundAll
end

-- Check that the Atlas Box can be found
function checkForAtlasObjects()
    objects.atlasBox = fromGUID(GUIDs.atlasBox)
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
    local stagedForStorage = (#portal.sites + #portal.relics + #portal.edifices + #portal.shadow) > 0
    removeButton(buttons.storeUnstaged)
    removeButton(buttons.storeStaged)
    self.createButton(stagedForStorage and buttons.storeStaged or buttons.storeUnstaged)
end

-- Remove all buttons
function retry()
    removeButton(buttons.retry)
    onLoad()
end

--
-- CHRONICLE SETUP
--
function setupAtlasBox(obj, color, alt_click)
    if not alt_click then
        -- If items are missing we need to retry setup
        if not checkForSetupObjects() then
            removeButton(buttons.setup)
            self.createButton(buttons.retry)
            return
        end
        -- Take all 20 sites and put them in the Atlas Box. Roll a d6 and add additional items depending on the roll
        for i = 1,20 do
            local d6roll = math.random(1,6)
            printToAll("Slot " .. i .. ", Roll " .. d6roll)
            local atlasSlotBag = getAtlasBag(20-i)
            atlasSlotBag.putObject(getRandomSite())
            if d6roll == 1 then
                atlasSlotBag.putObject(getRandomEdifice())
            elseif d6roll == 2 then
                -- do nothing
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
            atlasSlotBag.setName(atlasSlotNames.full)
            putAtlasBag(atlasSlotBag)
        end
        dealStartingSites()
        
        -- Clean up the setup button, mark setup as done and spawn the new buttons
        removeButton(buttons.setup)
        self.addTag(tags.chronicleCreated)
        destroyObject(objects.siteBag)
        for _,_ in ipairs(objects.edificeBag.getObjects()) do
            objects.edificeBag.takeObject({rotation = {x=0,y=180,z=0}})
        end
        destroyObject(objects.edificeBag)
        for _,_ in ipairs(objects.relicBag.getObjects()) do
            objects.relicBag.takeObject(getTransformStruct("relicStack"))
        end
        destroyObject(objects.relicBag)
        printToAll("SETUP COMPLETE. Don't forget to add Edifices back to the corresponding suit decks before setting up the World Deck\n")
        refreshStoreButton()
        self.createButton(buttons.retrieve)
        self.createButton(buttons.spawnRelics)
    end
end

function spawnRelics()
    local relicCount = 0    
    for i = 1, 20 do
        local atlasSlotBag = getAtlasBag(0)
        if relicCount < 10 then
            for _, item in ipairs(atlasSlotBag.getObjects()) do
                if relicCount < 10 and dataTableContains(item.tags, tags.relic) then
                    atlasSlotBag.takeObject({
                        guid = item.guid,
                        position = getTransformStruct("relicStack").position,
                        rotation = getTransformStruct("relicStack").rotation,
                    })
                    relicCount = relicCount + 1
                end
            end
        end
        putAtlasBag(atlasSlotBag)
    end
    printToAll("Retrieved " .. relicCount .. " relics from the Atlas Box")
end


function dealStartingSites()
    for siteNumber = 1,8 do
        local atlasSlotBag = getAtlasBag(0)
        local siteTransform = getTransformStruct("site", siteNumber)
        -- Deal All objects from the bag
        spawnAllFromBagAtTransform(atlasSlotBag, siteTransform)
        -- Rename the bag to mark as empty
        atlasSlotBag.setName(atlasSlotNames.empty)
       putAtlasBag(atlasSlotBag)
    end
end

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
            bag.takeObject({
                guid = obj.guid, 
                position = transform.position,
                rotation = transform.rotation,
            })
        end
    end
end

-- Get Elements for creating Chronicle

function getRandomShadow()
    return getRandomObjectFromContainer(objects.shadowBag, false)
end

-- tag all relics
function getRandomRelic()
    return getRandomObjectFromContainer(objects.relicBag, false)
end

function getRandomSite()
    local site = getRandomObjectFromContainer(objects.siteBag, false)
    site.setColorTint(Color(0,0,0))
    -- site.setColorTint(Color(1,1,1))
    site.setRotation({x=0,y=180,z=0})
    site.addTag(tags.site)
    return site
end

function getRandomEdifice()
    return getRandomObjectFromContainer(objects.edificeBag, true)
end

-- Tag all items in the bags
function tagAllItems()
    local bagTags = { 
        {bag = objects.relicBag,    tag = tags.relic},
        {bag = objects.edificeBag,  tag = tags.edifice},
        {bag = objects.shadowBag,   tag = tags.shadow} }
    for _, bagTag in ipairs(bagTags) do
        local bag, tag = bagTag.bag, bagTag.tag
        for _, item in ipairs(bag.getObjects()) do
            item = bag.takeObject({guid = item.guid})
            -- If we have a Deck we need to handle last card
            if item.type == "Deck" then
                local deck = item
                local deckSize = #deck.getObjects()
                local lastCard = nil
                for index, containedObject in ipairs(deck.getObjects()) do
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
    local cardSize = self.getVisualBoundsNormalized()["size"]
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
    if #portal.sites == 0 and #portal.relics == 0 and #portal.edifices == 0 and #portal.shadow == 0 then
        for _, obj in ipairs(zone.getObjects(true)) do
            if obj.hasTag(tags.site) then table.insert(portal.sites, obj) end
            if obj.hasTag(tags.relic) then table.insert(portal.relics, obj) end
            if obj.hasTag(tags.edifice) then table.insert(portal.edifices, obj) end
            if obj.hasTag(tags.shadow) then table.insert(portal.shadow, obj) end
        end
        local messageParts = {}
        if #portal.sites > 0 then table.insert(messageParts, #portal.sites .. " Site") end
        if #portal.relics > 0 then table.insert(messageParts, #portal.relics .. " Relic(s)") end    
        if #portal.edifices > 0 then table.insert(messageParts, #portal.edifices .. " Edifice") end
        if #portal.shadow > 0 then table.insert(messageParts, #portal.shadow .. " Shadow") end
        if #messageParts > 0 then
            printToAll("Detected " .. table.concat(messageParts, ", ") .. " on the Atlas Portal.")
            if #portal.sites < 1 then
                printToAll("ERROR: Missing a Site. Try again after placing a Site on the Atlas Portal.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portal.sites > 1 then
                printToAll("ERROR: Too many Sites. Try again after removing Sites from the Atlas Portal until there is only one.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portal.relics > 3 then
                printToAll("ERROR: More than 3 Relics. Try again after removing some Relics from the Atlas Portal.\n")
                emptyStoredPortalObjs()
                return
            end
            if #portal.edifices > 1 then
                printToAll("More than 1 Edifice. This is not typical but may be an exceptionalcase with current rules.")
            end
            if #portal.shadow > 1 then
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
        local itemCount = #portal.sites + #portal.relics + #portal.edifices + #portal.shadow
        for _, obj in ipairs(zone.getObjects(true)) do
            if obj.hasTag(tags.site) then
                perfectMatch = dataTableContains(portal.sites, obj)
                itemCount = itemCount - 1 
            end
            if obj.hasTag(tags.relic) then
                perfectMatch = dataTableContains(portal.relics, obj)
                itemCount = itemCount - 1 
            end
            if obj.hasTag(tags.edifice) then
                perfectMatch = dataTableContains(portal.edifices, obj)
                itemCount = itemCount - 1 
            end
            if obj.hasTag(tags.shadow) then
                perfectMatch = dataTableContains(portal.shadow, obj)
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
        for i = 1, 20 do
            local atlasSlotBag = getAtlasBag(0)
            if not foundEmptyBag and #atlasSlotBag.getObjects() == 0 then
                foundEmptyBag = true
                for _, obj in ipairs(portal.sites) do
                    obj.setColorTint(Color(0,0,0))
                    atlasSlotBag.putObject(obj)
                end
                for _, obj in ipairs(portal.relics) do atlasSlotBag.putObject(obj) end
                for _, obj in ipairs(portal.edifices) do atlasSlotBag.putObject(obj) end
                for _, obj in ipairs(portal.shadow) do atlasSlotBag.putObject(obj) end
                atlasSlotBag.setName(atlasSlotNames.full)
                printToAll("Stored objects in Slot number " .. i .. "\n")
            end
            putAtlasBag(atlasSlotBag)
        end
        emptyStoredPortalObjs()
    end
end

function emptyStoredPortalObjs()
    portal.sites = {}
    portal.relics = {}
    portal.edifices = {}
    portal.shadow = {}
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
    if #portal.sites + #portal.edifices + #portal.relics + #portal.shadow > 0 then
        printToAll("ERROR: Cannot Summon while storing sites\n")
        return
    end
    for _, obj in ipairs(zone.getObjects(true)) do
        if obj.hasTag(tags.site) or obj.hasTag(tags.relic) or obj.hasTag(tags.edifice) or obj.hasTag(tags.shadow) then
            printToAll("ERROR: Cannot Summon while pieces are on the Portal\n")
            return
        end
    end
    self.setLock(true)

    local d6roll = math.random(1,6)
    local spawnTransform = getTransformStruct("portal", 0, {position= self.getPosition(), rotation = self.getRotation()})
    local countsAndTags = {
        {tag = tags.relic, data = {count = 0, printName = "Relic(s)"}},
        {tag = tags.edifice, data = {count = 0, printName = "Edifice"}},
        {tag = tags.shadow, data = {count = 0, printName = "Shadow"}},
    }
    local atlasSlotBag = getAtlasBag(d6roll-1)
    for _, obj in ipairs(atlasSlotBag.getObjects()) do
        for _, countAndTag in ipairs(countsAndTags) do
            if dataTableContains(obj.tags, countAndTag.tag) then
                countAndTag.data.count = countAndTag.data.count + 1
            end
        end
    end
    spawnAllFromBagAtTransform(atlasSlotBag, spawnTransform)
    atlasSlotBag.setName(atlasSlotNames.empty)
    putAtlasBag(atlasSlotBag)
    local messageParts = {}
    for _, countAndTag in ipairs(countsAndTags) do
        if countAndTag.data.count > 0 then
            table.insert(messageParts, countAndTag.data.count .. " " .. countAndTag.data.printName)
        end
    end
    if #messageParts > 0 then
        printToAll("Summoning Site from Slot " .. d6roll .. " with " .. table.concat(messageParts, ", ") .. "\n")
    else
        printToAll("Summoning Empty Site from Slot " .. d6roll .. "\n")
    end
end

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
    objects.atlasBox.putObject(bag)
    if not wasUnlocked then objects.atlasBox.removeTag(tags.unlocked) end
    return
end

-- Get transform for a given tag and index
    -- Can provide a base tag and index to use a base position
function getTransformStruct(tag, index, baseTransform)
    return {
        position = vectorSum(
            pos[tag](index or 1), 
            (baseTransform and baseTransform.position or {x=0,y=0,z=0})
        ),
        rotation = rot[tag],
    }
end

-- General Util

function dataTableContains(table, x)
    local found = false
    for _, obj in ipairs(table) do
        if obj == x then found = true end
    end
    return found
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

function removeButton(input)
    local buttonIndex = nil
    if self.getButtons() then
        for i, button in ipairs(self.getButtons()) do
            if button and button.label == input.label then
                buttonIndex = button.index
                break
            end
        end
        if buttonIndex then self.removeButton(buttonIndex) end
    end
end