-- ==============================
-- CHRONICLE EXPORT
--
-- Reads the Chronicle straight off the table and encodes it as an
-- export string (encoding version 3, see chronicle-codec.js), with
-- nothing for the players to set up first. Runs in Global: the
-- "Export Chronicle" button on the right of the screen
-- (src/Global.xml) shows the string, and a summary of what went
-- into it, to whoever clicked.
--
-- Where each section comes from:
--   Atlas Box     the site bags in the Atlas Box, with their contents
--   Empire        the sites on the map's 8 slots, with the cards and relics beside them
--   World Deck    the deck on the map's World Deck spot (or one named "World Deck")
--   Relic Deck    the deck with memo "relicDeck", or the one on the map's relic spot
--   Dispossessed  the deck on the Dispossessed spot (or one named "Dispossessed")
--   Reliquary     the relics in the Imperial Reliquary, on the table or in the Chancellor Archive
--   Foundations   the face down Foundation cards, and the Oath from the "Oathkeeper of ..." tile in play
--   Players       each color's role and score from the Bookshelf, and their cards, legacies (Lineage
--                 cards, face down when dormant) and relics, from their mat if they're out on the
--                 table or from their archive if not
--
-- Cards are recognised by name (CardMapping), since every card in
-- 2.0 is its own custom deck.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Config/CardMapping")
require("src/Utils/HelperFunctions")

-- ==============================
-- FORMAT (must match chronicle-codec.js)
-- ==============================

-- Player sections, in export order (PLAYER_COLORS)
local PLAYER_COLORS = {"Red", "Blue", "Yellow", "Black", "White", "Brown", "Pink"}

-- Oath numbers (OATHS); 0 is unset
local OATH_NUMBERS = {Supremacy = 1, Devotion = 2, People = 3, Protection = 4}

-- Player status numbers (STATUSES), by Bookshelf role
local STATUS_NUMBERS = {EXILE = 0, CITIZEN = 1, CHANCELLOR = 2}

local DECK_RADIX = 400     -- card ids (World Deck, Dispossessed, player cards)
local RELIC_RADIX = 100    -- relic ids less 400
local LEGACY_RADIX = 200   -- legacy ids, plus LEGACY_FLIPPED when dormant
local LEGACY_FLIPPED = 100
local CHUNK_SIZE = 5       -- ids per deck chunk
local CHUNK_WIDTH = 7      -- base 82 digits per deck chunk
local MAX_LINEAGE = 6723   -- the most 2 base 82 digits hold

-- The most of each that still makes an exact number (below 2^53). Any more are left out, with a warning.
local MAX_SITE_ITEMS = 4      -- a site's index plus 3 digits per item
local MAX_PLAYER_CARDS = 6    -- radix 400
local MAX_PLAYER_RELICS = 7   -- radix 100 (the Reliquary too)

-- ==============================
-- WHERE THINGS ARE
-- ==============================

-- The box around map slot i's site and the cards laid out to its right: from the site's left edge to just short of
-- the next region's site, so it takes in all four spots (pos.denizen(0) to (3)) a site's items can be on. Wider than
-- the Atlas Box's site zones, which stop short of the fourth.
local SITE_AREA_OFFSET = {x = 8.25, y = 0, z = 0}
local SITE_AREA_SIZE = {x = 25.5, z = 5.4}

-- How close (horizontally) a deck must be to its spot on the map to be found there
local DECK_SPOT_TOLERANCE = 2.5

-- An Oathkeeper tile this close (horizontally) to the map is in play; the spare ones are kept further away
local OATH_IN_PLAY_RADIUS = 55

-- Names that are known not to be part of the Chronicle, so they're left out without a warning
local IGNORED_NAMES = {["grand scepter"] = true}

-- ==============================
-- NAMES TO IDS
-- ==============================

local function nameKey(name)
    return trim(name):lower():gsub("%s+", " ")
end

local lookups = nil

-- Ids by name (nameKey): cards, edifices, relics ({id, relicId}), legacies and site indexes
local function getLookups()
    if lookups then
        return lookups
    end
    lookups = {cards = {}, edifices = {}, relics = {}, legacies = {}, sites = {}}
    for _, suit in pairs(cardIndex) do
        for _, card in pairs(suit.cards) do
            lookups.cards[nameKey(card.name)] = card.id
        end
    end
    for _, suit in pairs(edificeIndex) do
        for _, card in pairs(suit.cards) do
            lookups.edifices[nameKey(card.name)] = card.id
        end
    end
    for _, relic in pairs(relicIndex.cards) do
        lookups.relics[nameKey(relic.name)] = {id = relic.id, relicId = relic.relicId}
    end
    for _, legacy in pairs(legacyIndex.cards) do
        lookups.legacies[nameKey(legacy.name)] = legacy.id
    end
    for name, index in pairs(siteIndex) do
        lookups.sites[nameKey(name)] = index
    end
    return lookups
end

-- ==============================
-- THE EXPORT IN PROGRESS
-- ==============================

-- What the current export found, for its summary: warnings, and the names it didn't know (by where they were)
local report = nil

local function warn(message)
    table.insert(report.warnings, message)
end

local function noteUnknown(where, name)
    if report.unknown[where] == nil then
        report.unknown[where] = {}
        table.insert(report.unknownOrder, where)
    end
    table.insert(report.unknown[where], name ~= "" and name or "(unnamed)")
end

-- ==============================
-- READING CARDS
-- ==============================

local function isDeckData(data)
    return data.Name == "Deck" or data.Name == "DeckCustom"
end

local function isFaceDown(rotationZ)
    return roundToNearest180(rotationZ or 0) == 180
end

-- Adds the cards in data (from getData(): a card, or a deck's cards) to out as {name, tags, guid, faceDown}.
-- Cards in a deck are face down if the deck is.
local function addCardEntries(data, out, faceDown)
    if faceDown == nil then
        faceDown = isFaceDown(data.Transform and data.Transform.rotZ)
    end
    if isDeckData(data) then
        for _, card in ipairs(data.ContainedObjects or {}) do
            addCardEntries(card, out, faceDown)
        end
        return out
    end
    table.insert(out, {name = data.Nickname or "", data = data, guid = data.GUID, faceDown = faceDown})
    return out
end

-- What a card is in the Chronicle, by its name (a Lineage card is a legacy): {kind, id, relicId}, where kind is
-- "card", "edifice", "relic" or "legacy". nil if it isn't one (where it was is noted for the summary, unless it's known
-- not to count). No name is in more than one of CardMapping's lists.
local function identify(entry, where)
    local ids = getLookups()
    local key = nameKey(entry.name)
    local result = nil
    if PieceDataHasTag(entry.data, "Lineage") then
        result = ids.legacies[key] and {kind = "legacy", id = ids.legacies[key]}
    elseif ids.relics[key] then
        result = {kind = "relic", id = ids.relics[key].id, relicId = ids.relics[key].relicId}
    elseif ids.edifices[key] then
        result = {kind = "edifice", id = ids.edifices[key]}
    elseif ids.cards[key] then
        result = {kind = "card", id = ids.cards[key]}
    end
    if result == nil and not IGNORED_NAMES[key] then
        noteUnknown(where, entry.name)
    end
    return result
end

-- The ids of a site's cards, edifices and relics (as site items), at most MAX_SITE_ITEMS
local function siteItemIds(entries, siteName)
    local ids = {}
    for _, entry in ipairs(entries) do
        local found = identify(entry, siteName)
        if found and found.kind ~= "legacy" then
            table.insert(ids, found.id)
        end
    end
    if #ids > MAX_SITE_ITEMS then
        warn(siteName .. " has " .. #ids .. " cards and relics, but only " .. MAX_SITE_ITEMS
            .. " fit in the export. The rest were left out.")
        while #ids > MAX_SITE_ITEMS do
            table.remove(ids)
        end
    end
    return ids
end

-- ==============================
-- ENCODING
-- ==============================

-- Every id in one number, in radix (packNumber in chronicle-codec.js): "" for none
local function packNumber(ids, radix)
    local n, mult = 0, 1
    for _, id in ipairs(ids) do
        n = n + id * mult
        mult = mult * radix
    end
    return n == 0 and "" or oEncode(n)
end

-- Ids in chunks of CHUNK_SIZE, each padded to CHUNK_WIDTH digits, the first chunk rightmost (packIds)
local function packIds(ids, radix)
    local result = ""
    for first = 1, #ids, CHUNK_SIZE do
        local n, mult = 0, 1
        for i = first, math.min(first + CHUNK_SIZE - 1, #ids) do
            n = n + ids[i] * mult
            mult = mult * radix
        end
        result = padEncode(n, CHUNK_WIDTH) .. result
    end
    return result
end

-- One site's token: its index in the lowest 2 digits, then each item in 3 digits above it (encodeSite)
local function encodeSite(siteNumber, itemIds)
    local n, mult = siteNumber, 100
    for _, id in ipairs(itemIds) do
        n = n + id * mult
        mult = mult * 1000
    end
    return oEncode(n)
end

-- Keeps the first max of list, warning about the rest
local function capList(list, max, what)
    if #list > max then
        warn(what .. ": " .. #list .. " found, but only " .. max .. " fit in the export. The rest were left out.")
        while #list > max do
            table.remove(list)
        end
    end
    return list
end

-- ==============================
-- FINDING THINGS
-- ==============================

local function horizontalDistance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- The deck or lone card nearest the spot pos[spotKey] on the map (within DECK_SPOT_TOLERANCE), or nil
local function findDeckAtSpot(spotKey)
    local map = getObjectFromGUID(GUIDs.map)
    if not map then
        return nil
    end
    local spot = getTransformStruct(spotKey, 0, {position = map.getPosition()}).position
    local best, bestDistance = nil, DECK_SPOT_TOLERANCE
    for _, object in ipairs(getAllObjects()) do
        if object.type == "Deck" or object.type == "Card" then
            local distance = horizontalDistance(object.getPosition(), spot)
            if distance <= bestDistance then
                best, bestDistance = object, distance
            end
        end
    end
    return best
end

-- The first deck named name, or nil
local function findDeckNamed(name)
    for _, object in ipairs(getAllObjects()) do
        if object.type == "Deck" and object.getName() == name then
            return object
        end
    end
    return nil
end

-- Everything in a box on the table: centre (world), size {x, z}, from just below the table surface upwards
local function objectsInArea(center, size, below)
    local hits = Physics.cast({
        origin = {x = center.x, y = below, z = center.z},
        direction = {x = 0, y = 1, z = 0},
        type = 3,
        size = {x = size.x, y = 0.01, z = size.z},
        max_distance = 10,
    })
    local objects, seen = {}, {}
    for _, hit in ipairs(hits) do
        local object = hit.hit_object
        if object and not seen[object] then
            seen[object] = true
            table.insert(objects, object)
        end
    end
    return objects
end

-- The data of the object with guid inside container's data (at any depth), or nil
local function findInData(containerData, guid)
    for _, data in ipairs(containerData.ContainedObjects or {}) do
        if data.GUID == guid then
            return data
        end
        local found = findInData(data, guid)
        if found then
            return found
        end
    end
    return nil
end

-- ==============================
-- SECTIONS
-- ==============================

-- Atlas Box: each site bag in the box, with what's in it
local function atlasBoxSection()
    local box = getObjectFromGUID(GUIDs.atlasBox)
    if not box then
        warn("The Atlas Box isn't on the table, so the export has no Atlas Box.")
        return ""
    end
    local ids = getLookups()
    local section = ""
    for _, siteData in ipairs(box.getData().ContainedObjects or {}) do
        local siteName = siteData.Nickname or ""
        local siteNumber = ids.sites[nameKey(siteName)]
        if siteNumber == nil then
            warn("A site in the Atlas Box isn't one the export knows (\"" .. siteName .. "\"), so it was left out.")
        else
            local entries = {}
            for _, child in ipairs(siteData.ContainedObjects or {}) do
                addCardEntries(child, entries)
            end
            for _, child in ipairs(siteData.ChildObjects or {}) do
                addCardEntries(child, entries)
            end
            section = section .. encodeSite(siteNumber, siteItemIds(entries, siteName)) .. "#"
            report.atlasSites = report.atlasSites + 1
        end
    end
    return section
end

-- Empire: the site on each map slot that has one, with the cards and relics beside it (nearest first)
local function worldSection()
    local map = getObjectFromGUID(GUIDs.map)
    if not map then
        warn("The map isn't on the table, so the export has no Empire.")
        return ""
    end
    local ids = getLookups()
    local mapTransform = {position = map.getPosition(), rotation = map.getRotation()}
    local below = map.getPosition().y - 0.5
    local section = ""
    for slot = 1, 8 do
        local center = vectorSum(getTransformStruct("site", slot, mapTransform).position, SITE_AREA_OFFSET)
        local site, pieces = nil, {}
        for _, object in ipairs(objectsInArea(center, SITE_AREA_SIZE, below)) do
            if object.hasTag(tags.site) then
                site = site or object
            elseif object.hasTag(tags.card) or object.hasTag(tags.edifice) or object.hasTag(tags.relic) then
                table.insert(pieces, object)
            end
        end
        if site then
            local siteName = site.getName()
            local siteNumber = ids.sites[nameKey(siteName)]
            if siteNumber == nil then
                warn("The site on map slot " .. slot .. " isn't one the export knows (\"" .. siteName .. "\"), so it was left out.")
            else
                local sitePosition = site.getPosition()
                table.sort(pieces, function(a, b)
                    return horizontalDistance(a.getPosition(), sitePosition) < horizontalDistance(b.getPosition(), sitePosition)
                end)
                local entries = {}
                -- anything still inside the site bag first
                for _, child in ipairs(site.getData().ContainedObjects or {}) do
                    addCardEntries(child, entries)
                end
                for _, piece in ipairs(pieces) do
                    addCardEntries(piece.getData(), entries)
                end
                section = section .. encodeSite(siteNumber, siteItemIds(entries, siteName)) .. "#"
                table.insert(report.worldSites, siteName)
            end
        end
    end
    return section
end

-- The card ids of a deck's cards (World Deck, Dispossessed)
local function cardDeckSection(deck, what)
    if not deck then
        warn("No " .. what .. " was found, so it's empty in the export.")
        return "", 0
    end
    local cardIds = {}
    for _, entry in ipairs(addCardEntries(deck.getData(), {})) do
        local found = identify(entry, what)
        if found and found.kind == "card" then
            table.insert(cardIds, found.id)
        elseif found then
            noteUnknown(what, entry.name)
        end
    end
    return packIds(cardIds, DECK_RADIX), #cardIds
end

local function worldDeckSection()
    local section, count = cardDeckSection(findDeckAtSpot("worldDeck") or findDeckNamed("World Deck"), "World Deck")
    report.worldDeck = count
    return section
end

local function dispossessedSection()
    local section, count = cardDeckSection(findDeckAtSpot("dispossessed") or findDeckNamed("Dispossessed"), "Dispossessed")
    report.dispossessed = count
    return section
end

-- The relic ids (less 400) of the relics among entries
local function relicIds(entries, where)
    local result = {}
    for _, entry in ipairs(entries) do
        local found = identify(entry, where)
        if found and found.kind == "relic" then
            table.insert(result, found.relicId)
        elseif found then
            noteUnknown(where, entry.name)
        end
    end
    return result
end

-- The Relic Deck: the deck with memo "relicDeck", or the one on the map's relic spot, or the relic pile
local function findRelicDeck()
    local deck = nil
    for _, object in ipairs(getAllObjects()) do
        if object.type == "Deck" and object.getMemo() == "relicDeck" then
            deck = object
        end
    end
    return deck or findDeckAtSpot("relicStack") or getObjectFromGUID(GUIDs.relicPile)
end

local function relicDeckSection()
    local deck = findRelicDeck()
    if not deck then
        warn("No Relic Deck was found, so it's empty in the export.")
        report.relicDeck = 0
        return ""
    end
    local ids = relicIds(addCardEntries(deck.getData(), {}), "Relic Deck")
    report.relicDeck = #ids
    return packIds(ids, RELIC_RADIX)
end

-- Reliquary: the relics in the Imperial Reliquary, on the table or stored in the Chancellor Archive
local function reliquarySection()
    local data = nil
    local reliquary = getObjectFromGUID(GUIDs.imperialReliquary)
    if reliquary then
        data = reliquary.getData()
    else
        local chancellorArchive = getObjectFromGUID(GUIDs.playerArchives.Purple)
        data = chancellorArchive and findInData(chancellorArchive.getData(), GUIDs.imperialReliquary)
    end
    if not data then
        warn("The Imperial Reliquary wasn't found, so the export has no Reliquary.")
        report.reliquary = nil
        return ""
    end
    local entries = {}
    for _, child in ipairs(data.ContainedObjects or {}) do
        addCardEntries(child, entries)
    end
    local ids = capList(relicIds(entries, "Reliquary"), MAX_PLAYER_RELICS, "Reliquary relics")
    report.reliquary = #ids
    -- an empty Reliquary is "0" (an empty section means it was skipped)
    local packed = packNumber(ids, RELIC_RADIX)
    return packed == "" and "0" or packed
end

-- The Oath on the "Oathkeeper of ..." tile in play (nearest the map), or 0 if there isn't one
local function currentOath()
    local map = getObjectFromGUID(GUIDs.map)
    local center = map and map.getPosition() or {x = 0, y = 0, z = 0}
    local found = {}
    for _, object in ipairs(getAllObjects()) do
        local oath = object.getName():match("^Oathkeeper of (.+)$")
        if oath then
            oath = oath:gsub("^the ", "")
            local distance = horizontalDistance(object.getPosition(), center)
            if OATH_NUMBERS[oath] and distance <= OATH_IN_PLAY_RADIUS then
                table.insert(found, {name = oath, distance = distance})
            end
        end
    end
    if #found == 0 then
        warn("No Oathkeeper tile is in play, so the Oath is left unset.")
        return 0
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    if #found > 1 then
        local names = {}
        for _, oath in ipairs(found) do
            table.insert(names, oath.name)
        end
        warn("More than one Oathkeeper tile is in play (" .. table.concat(names, ", ") .. "). Used "
            .. found[1].name .. ", the one nearest the map.")
    end
    report.oath = found[1].name
    return OATH_NUMBERS[found[1].name]
end

-- Foundations: [face down Foundations bitmask: 2 digits][Oath: 1 digit]
local function foundationsSection()
    local mask = 0
    for i, foundation in ipairs(GUIDs.foundations) do
        local card = getObjectFromGUID(foundation.GUID)
        if card == nil then
            warn(foundation.name .. " wasn't found (is it in a deck?), so it's exported as not flipped.")
        elseif isFaceDown(card.getRotation().z) then
            mask = mask + 2 ^ (i - 1)
            table.insert(report.foundations, foundation.name:match("^Foundation (%w+)") or foundation.name)
        end
    end
    return padEncode(mask, 2) .. oEncode(currentOath())
end

-- The tags of the pieces that count for a player (their board, warbands and the rest are left out)
local PLAYER_PIECE_TAGS = {tags.card, "Lineage", tags.relic, tags.edifice}

local function isPlayerPiece(entry)
    for _, tag in ipairs(PLAYER_PIECE_TAGS) do
        if PieceDataHasTag(entry.data, tag) then
            return true
        end
    end
    return false
end

-- Adds the cards in color's storage box (boxData, from getData()) to entries, each face up or down as it went in
local function addStorageBoxEntries(boxData, entries)
    for _, data in ipairs(boxData.ContainedObjects or {}) do
        addCardEntries(data, entries)
    end
end

-- color's cards, relics and lineage cards, as getData() entries: from their mat while they're out, otherwise from
-- their archive (with each card's face up or down as it was on the mat when they were deposited). Either way, what's
-- in their storage box counts too.
local function playerEntries(color, withdrawnMats)
    local entries = {}
    local boxGuid = GUIDs.storageBags[color]
    if withdrawnMats[color] == nil then
        local archive = getObjectFromGUID(GUIDs.playerArchives[color] or "")
        if not archive then
            warn(color .. "'s archive wasn't found, so they're exported with nothing.")
            return entries
        end
        local layout = {}
        pcall(function()
            layout = archive.call("GetCardLayout") or {}
        end)
        local boxData = nil
        for _, data in ipairs(archive.getData().ContainedObjects or {}) do
            if boxGuid and data.GUID == boxGuid then
                boxData = data
            else
                local placed = layout[data.GUID]
                local faceDown = placed and placed.rotation and isFaceDown(placed.rotation.z) or nil
                addCardEntries(data, entries, faceDown)
            end
        end
        if boxData then
            addStorageBoxEntries(boxData, entries)
        end
        return entries
    end
    local mat = getObjectFromGUID(withdrawnMats[color])
    if mat then
        local matSize = mat.getBounds().size
        for _, object in ipairs(objectsInArea(mat.getPosition(), matSize, mat.getPosition().y - 0.5)) do
            if object ~= mat and (object.type == "Card" or object.type == "Deck") then
                addCardEntries(object.getData(), entries)
            end
        end
    else
        warn(color .. " is out on the table, but their player mat wasn't found, so only their storage box was read.")
    end
    local box = getObjectFromGUID(boxGuid or "")
    if box then
        addStorageBoxEntries(box.getData(), entries)
    end
    return entries
end

-- [status: 1 digit][lineage: 2 digits][cards]#[legacies]#[relics]
local function playerSection(color, bookshelf, withdrawnMats)
    local role, score = "EXILE", 0
    if bookshelf then
        pcall(function()
            role = bookshelf.call("GetRole", color) or role
            score = tonumber(bookshelf.call("GetScore", color)) or 0
        end)
    end
    local lineage = math.floor(math.max(score, 0))
    if lineage > MAX_LINEAGE then
        warn(color .. "'s score is " .. lineage .. ", more than the export holds. It was saved as " .. MAX_LINEAGE .. ".")
        lineage = MAX_LINEAGE
    end

    local cards, legacies, relics = {}, {}, {}
    for _, entry in ipairs(playerEntries(color, withdrawnMats)) do
        local found = isPlayerPiece(entry) and identify(entry, color)
        if found and found.kind == "card" then
            table.insert(cards, found.id)
        elseif found and found.kind == "legacy" then
            table.insert(legacies, found.id + (entry.faceDown and LEGACY_FLIPPED or 0))
        elseif found and found.kind == "relic" then
            table.insert(relics, found.relicId)
        elseif found then
            noteUnknown(color, entry.name)
        end
    end
    capList(cards, MAX_PLAYER_CARDS, color .. "'s cards")
    capList(relics, MAX_PLAYER_RELICS, color .. "'s relics")

    local dormant = 0
    for _, value in ipairs(legacies) do
        if value > LEGACY_FLIPPED then
            dormant = dormant + 1
        end
    end
    table.insert(report.players, {
        color = color, role = role, lineage = lineage, cards = #cards, legacies = #legacies, dormant = dormant,
        relics = #relics, out = withdrawnMats[color] ~= nil,
    })

    local legacyField = #legacies < CHUNK_SIZE and packNumber(legacies, LEGACY_RADIX) or packIds(legacies, LEGACY_RADIX)
    return oEncode(STATUS_NUMBERS[role] or 0) .. padEncode(lineage, 2)
        .. packNumber(cards, DECK_RADIX) .. "#" .. legacyField .. "#" .. packNumber(relics, RELIC_RADIX)
end

local function playerSections()
    local bookshelf = getObjectFromGUID(GUIDs.bookshelf)
    local withdrawnMats = {}
    if bookshelf then
        withdrawnMats = bookshelf.getTable("withdrawnMats") or {}
    else
        warn("The Bookshelf isn't on the table, so every player is exported as an Exile with a score of 0.")
    end
    local sections = {}
    for _, color in ipairs(PLAYER_COLORS) do
        table.insert(sections, playerSection(color, bookshelf, withdrawnMats))
    end
    return table.concat(sections, ">")
end

-- ==============================
-- PUBLIC
-- ==============================

-- Reads the Chronicle off the table. Returns the export string, the plain (unscrambled) string and a report:
-- {warnings, unknown = {[where] = {names}}, unknownOrder, atlasSites, worldSites, worldDeck, relicDeck,
--  dispossessed, reliquary, foundations, oath, players}
function BuildChronicleExport()
    report = {
        warnings = {}, unknown = {}, unknownOrder = {}, atlasSites = 0, worldSites = {}, foundations = {},
        players = {},
    }
    local sections = {
        atlasBoxSection(),
        worldSection(),
        worldDeckSection(),
        relicDeckSection(),
        dispossessedSection(),
        reliquarySection(),
        foundationsSection(),
        playerSections(),
    }
    local plain = table.concat(sections, ">")
    local result = report
    report = nil
    return scramble(plain), plain, result
end

-- What the restore (src/ChronicleRestore) shares with the export, so the two read the format and the table the same way
ChronicleFormat = {
    PLAYER_COLORS = PLAYER_COLORS,
    OATH_NUMBERS = OATH_NUMBERS,
    STATUS_NUMBERS = STATUS_NUMBERS,
    DECK_RADIX = DECK_RADIX,
    RELIC_RADIX = RELIC_RADIX,
    LEGACY_RADIX = LEGACY_RADIX,
    LEGACY_FLIPPED = LEGACY_FLIPPED,
    CHUNK_SIZE = CHUNK_SIZE,
    CHUNK_WIDTH = CHUNK_WIDTH,
    OATH_IN_PLAY_RADIUS = OATH_IN_PLAY_RADIUS,
    SITE_AREA_OFFSET = SITE_AREA_OFFSET,
    SITE_AREA_SIZE = SITE_AREA_SIZE,
    findDeckAtSpot = findDeckAtSpot,
    findDeckNamed = findDeckNamed,
    findRelicDeck = findRelicDeck,
    nameKey = nameKey,
    getLookups = getLookups,
    isDeckData = isDeckData,
    isFaceDown = isFaceDown,
    horizontalDistance = horizontalDistance,
}

local ROLE_NAMES = {EXILE = "Exile", CITIZEN = "Citizen", CHANCELLOR = "Chancellor"}

local function plural(count, word)
    return count .. " " .. word .. (count == 1 and "" or "s")
end

-- A readable summary of an export's report, one line each
function ChronicleSummaryLines(result)
    local lines = {}
    local function add(line)
        table.insert(lines, line)
    end
    if #result.warnings > 0 or #result.unknownOrder > 0 then
        add("<b>Check these:</b>")
        for _, warning in ipairs(result.warnings) do
            add("• " .. warning)
        end
        for _, where in ipairs(result.unknownOrder) do
            add("• Left out of " .. where .. " (not in the Chronicle's card list): " .. table.concat(result.unknown[where], ", "))
        end
        add("")
    end
    add("<b>Atlas Box:</b> " .. plural(result.atlasSites, "site"))
    add("<b>Empire:</b> " .. (#result.worldSites > 0 and table.concat(result.worldSites, ", ") or "no sites"))
    add("<b>World Deck:</b> " .. plural(result.worldDeck or 0, "card")
        .. "   <b>Relic Deck:</b> " .. plural(result.relicDeck or 0, "relic")
        .. "   <b>Dispossessed:</b> " .. plural(result.dispossessed or 0, "card"))
    add("<b>Reliquary:</b> " .. (result.reliquary and plural(result.reliquary, "relic") or "not found"))
    add("<b>Oath:</b> " .. (result.oath or "unset")
        .. "   <b>Foundations flipped:</b> " .. (#result.foundations > 0 and table.concat(result.foundations, ", ") or "none"))
    add("")
    for _, player in ipairs(result.players) do
        local legacies = plural(player.legacies, "legacy"):gsub("legacys", "legacies")
        add("<b>" .. player.color .. ":</b> " .. (ROLE_NAMES[player.role] or player.role) .. ", score " .. player.lineage
            .. " (" .. (player.out and "on the table" or "in the archive") .. "). "
            .. plural(player.cards, "card") .. ", " .. legacies
            .. (player.dormant > 0 and (" (" .. player.dormant .. " dormant)") or "")
            .. ", " .. plural(player.relics, "relic"))
    end
    return lines
end
