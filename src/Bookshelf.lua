
require("src/Utils/ColorUtils")
require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")
require("src/Utils/Warbands")
require("src/Utils/Stamps")



-- Under each book is a strip of controls, from the shelf out towards the table: its withdraw/deposit button, a name
-- field, then the score with - and + buttons. The name and score controls are turned to read along the strip.
local STRIP_ROTATION = {0, 90, 0}

-- The withdraw and deposit arrows: out of the book, and back into it (the newline keeps the arrow towards the end
-- of the button nearest the book)
local WITHDRAW_LABEL = "⬇\n"

local DEPOSIT_LABEL = "\n⬆"

-- Each book's strip: the first book's x, and the step to the next (in the shelf's own units, as button positions)
local STRIP_FIRST_X = -10.125
local STRIP_STEP_X = 4.025

-- Where each control sits along the strip (z, in the shelf's own units), and its length along it and width across
-- it (button units: a turned control's width is along the strip)
local WITHDRAW_Z = 10
local NAME_Z, NAME_LENGTH = 19.25, 5000
local MINUS_Z, PLUS_Z, SCORE_BUTTON_LENGTH = 22.6+3.25, 26.6+3.25, 400
local SCORE_Z, SCORE_LENGTH = 24.6+3.25, 1400
local STRIP_HEIGHT = 585

-- The status column, after the score: the white citizen stamp under a Citizen's book, or the chancellor stamp under the
-- Chancellor's. Decals named STATUS_PREFIX .. color; the stamp's height is in world units,
-- across the strip.
local STATUS_Z = 32.2
local STATUS_STAMP_Y = 0.05
local STATUS_STAMP_HEIGHT = 1.2
local STATUS_PREFIX = "status:"

-- The column headers: past the last book's strip (the top of the turned text), as a button x
local HEADER_X = STRIP_FIRST_X + STRIP_STEP_X * 6.5
local HEADER_FONT_SIZE = 450
local HEADER_FONT_COLOR = {1, 1, 1}

-- Buttons
buttons = {
    withdraw = {
        click_function = "withdraw_",
        label          = WITHDRAW_LABEL,
        function_owner = self,
        scale          = {1.0, 1.0, 1.0},
        rotation       = {0, 0, 0},
        width          = 1500,
        height         = 3000,
        font_size      = 800,
        tooltip        = "Pick a player Color",
    }
}


-- Bookshelf colors in button order; each color's button index is its position here minus 1
bookshelfColors = {"Red", "Blue", "Yellow", "White", "Black", "Brown", "Pink"}

-- The player mat GUID each withdrawn color was laid out on, by color
withdrawnMats = {}

-- Colors with a withdraw or deposit still running; their button does nothing until it finishes
busyColors = {}

-- Tells player_clicked to wait if playerColor's withdraw or deposit is still running
function isColorBusy(playerColor, player_clicked)
    if busyColors[playerColor] then
        Player[player_clicked].broadcast(playerColor .. " is still being moved. Try again in a moment.")
    end
    return busyColors[playerColor]
end

-- Each color's player name and score, typed under their book
playerNames = {}
playerScores = {}

function onSave()
    return JSON.encode({withdrawnMats = withdrawnMats, names = playerNames, scores = playerScores})
end

function onLoad(savedData)
    local saved = {}
    if savedData and savedData ~= "" then
        saved = JSON.decode(savedData) or {}
    end
    withdrawnMats = saved.withdrawnMats or {}
    playerNames = saved.names or {}
    playerScores = saved.scores or {}

    -- The withdraw/deposit buttons come first, so each color's is button index (its place in bookshelfColors - 1)
    for i, player in ipairs(bookshelfColors) do
        local button = {}
        for k, v in pairs(buttons.withdraw) do button[k] = v end
        button.click_function = "withdraw_" .. player
        button.color = GetOathColor(player)
        button.position = {StripX(i), 0, WITHDRAW_Z}
        if player == "Black" then
            button.font_color = hexToColor("#838383")
        end
        self.createButton(button)
        _G["withdraw_" .. player] = function(_, player_clicker_color) withdraw(player, player_clicker_color) end
        _G["deposit_" .. player] = function(_, player_clicker_color) deposit(player, player_clicker_color) end
    end
    -- a name field, then the score with - and + buttons, under each book
    for i, player in ipairs(bookshelfColors) do
        local x = StripX(i)
        local color = GetOathColor(player)
        -- a dark sign on light colors, a white one on the rest
        local light = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b > 0.6
        local signColor = light and {0, 0, 0} or {1, 1, 1}

        _G["nameInput_" .. player] = function(_, _, value)
            playerNames[player] = value
        end
        _G["scoreInput_" .. player] = function(_, _, value)
            playerScores[player] = tonumber(value) or playerScores[player] or 0
        end
        _G["scoreDown_" .. player] = function()
            ChangeScore(i, -1)
        end
        _G["scoreUp_" .. player] = function()
            ChangeScore(i, 1)
        end

        self.createInput({
            input_function = "nameInput_" .. player,
            function_owner = self,
            label = player .. " player",
            value = playerNames[player] or "",
            position = {x, 0, NAME_Z},
            rotation = STRIP_ROTATION,
            width = NAME_LENGTH,
            height = STRIP_HEIGHT,
            font_size = 500,
            alignment = 3,
            tooltip = player .. "'s player name",
        })
        self.createInput({
            input_function = "scoreInput_" .. player,
            function_owner = self,
            label = "0",
            value = tostring(playerScores[player] or 0),
            position = {x, 0, SCORE_Z},
            rotation = STRIP_ROTATION,
            width = SCORE_LENGTH,
            height = STRIP_HEIGHT,
            font_size = 500,
            alignment = 3,
            validation = 2,
            tooltip = player .. "'s score",
        })
        for _, sign in ipairs({{label = "-", z = MINUS_Z, fn = "scoreDown_"}, {label = "+", z = PLUS_Z, fn = "scoreUp_"}}) do
            self.createButton({
                click_function = sign.fn .. player,
                function_owner = self,
                label = sign.label,
                position = {x, 0, sign.z},
                rotation = STRIP_ROTATION,
                width = SCORE_BUTTON_LENGTH,
                height = STRIP_HEIGHT-200,
                font_size = 400,
                alignment = 3,
                color = color,
                font_color = signColor,
            })
        end
    end
    -- "Name", "Score" and "Status" over their columns
    for _, header in ipairs({{label = "Name", z = NAME_Z}, {label = "Score", z = SCORE_Z}, {label = "Status", z = STATUS_Z}}) do
        self.createButton({
            click_function = "IgnoreClick",
            function_owner = self,
            label = header.label,
            position = {HEADER_X, 0, header.z},
            rotation = STRIP_ROTATION,
            width = 0,
            height = 0,
            font_size = HEADER_FONT_SIZE,
            font_color = HEADER_FONT_COLOR,
        })
    end
    -- once the archives have loaded and can report their roles
    Wait.frames(UpdateStatus, 30)

    self.addContextMenuItem("Unlock books (Debug)", function()
        for _, guid in pairs(GUIDs.playerArchives) do
            local archive = getObjectFromGUID(guid)
            if archive then
                archive.setLock(false)
                archive.interactable = true
                -- the archive's tryObjectEnter refuses everything unless this is set
                archive.setVar("allowEnter", true)
            end
        end
    end)

    self.addContextMenuItem("Lock books (Debug)", function()
        for _, guid in pairs(GUIDs.playerArchives) do
            local archive = getObjectFromGUID(guid)
            if archive then
                archive.setLock(true)
                archive.interactable = false
                archive.setVar("allowEnter", false)
            end
        end
    end)

    -- Colors withdrawn before the last save keep their deposit buttons
    for playerColor in pairs(withdrawnMats) do
        setArchiveWithdrawn(playerColor, true)
    end

    -- TODO: Detect which player boards are already out on the table on load, and show their archives as
    -- withdrawn (hidden, with a deposit button) automatically
end

-- Shows playerColor's archive as withdrawn (hidden, with a deposit button) or not (visible, with a withdraw button)
function setArchiveWithdrawn(playerColor, withdrawn)
    local playerArchive = getObjectFromGUID(GUIDs.playerArchives[playerColor])
    playerArchive.setColorTint({1, 1, 1, withdrawn and 0 or 1})
    -- its stamps don't follow the tint, so the archive hides them itself (it also saves this, in case its
    -- script hasn't loaded yet as the game loads)
    pcall(function()
        playerArchive.call("SetWithdrawn", withdrawn)
    end)

    for i, color in ipairs(bookshelfColors) do
        if color == playerColor then
            self.editButton({
                index          = i - 1,
                click_function = (withdrawn and "deposit_" or "withdraw_") .. playerColor,
                label          = withdrawn and DEPOSIT_LABEL or WITHDRAW_LABEL,
                tooltip        = withdrawn and "Deposit this player back into their archive" or buttons.withdraw.tooltip,
            })
        end
    end
end

-- ==============================
-- MOVING THE SHELF
--
-- When the shelf is put down, once it has come to rest, each
-- archive goes to its place on it (shelfArchiveLayout), turned
-- with it.
-- ==============================

-- Seconds to wait for the shelf to settle after it's put down before placing the archives anyway
local SHELF_SETTLE_TIMEOUT = 5

function onDrop()
    Wait.condition(PlaceArchivesOnShelf, function()
        return self.resting
    end, SHELF_SETTLE_TIMEOUT, PlaceArchivesOnShelf)
end

-- Puts each archive in its place on the shelf, locked there
function PlaceArchivesOnShelf()
    local yaw = self.getRotation().y
    for color, place in pairs(shelfArchiveLayout) do
        local archive = getObjectFromGUID(GUIDs.playerArchives[color] or "")
        if archive then
            -- locked, so it glides straight there without knocking into the shelf or the other archives
            archive.setLock(true)
            archive.setPositionSmooth(self.positionToWorld(place), false, true)
            archive.setRotationSmooth({
                shelfArchiveRotation.x,
                yaw + shelfArchiveRotation.y,
                shelfArchiveRotation.z,
            }, false, true)
        end
    end
end

-- ==============================
-- PLAYER NAMES AND SCORES
-- ==============================

-- The x of book i's strip (as a button position)
function StripX(i)
    return STRIP_FIRST_X + STRIP_STEP_X * (i - 1)
end

-- Clicking a header does nothing
function IgnoreClick()
end

-- Puts each player's role stamp in the status column (the archives call this when a role changes)
function UpdateStatus()
    local decals = {}
    for _, decal in ipairs(self.getDecals() or {}) do
        if decal.name:sub(1, #STATUS_PREFIX) ~= STATUS_PREFIX then
            table.insert(decals, decal)
        end
    end
    for i, player in ipairs(bookshelfColors) do
        local archive = getObjectFromGUID(GUIDs.playerArchives[player])
        local success, role = pcall(function()
            return archive.call("GetRole")
        end)
        role = success and role or nil
        local key = role == "CHANCELLOR" and "Chancellor" or role == "CITIZEN" and "CitizenWhite" or nil
        local image = key and stampImages[key]
        if image then
            -- in the strip's status column, facing up, its top towards the top of the turned text (decal positions
            -- aren't flipped like button positions)
            table.insert(decals, MakeDecal(self, STATUS_PREFIX .. player, image.url, {
                position = Vector(-StripX(i), STATUS_STAMP_Y, STATUS_Z),
                normal = Vector(0, 1, 0),
                up = Vector(-1, 0, 0),
                width = STATUS_STAMP_HEIGHT * image.width / image.height,
                height = STATUS_STAMP_HEIGHT,
            }))
        end
    end
    self.setDecals(decals)
end

-- Adds delta to book i's score and shows it in its score field
function ChangeScore(i, delta)
    local player = bookshelfColors[i]
    playerScores[player] = (playerScores[player] or 0) + delta
    -- each color's score field is input (its place in bookshelfColors - 1) * 2 + 1, after its name field
    self.editInput({index = (i - 1) * 2 + 1, value = tostring(playerScores[player])})
end

-- Returns everything in playerMat's play area that belongs in a player's archive.
-- TODO: Once the new player mats are coded, ask the mat instead (e.g. playerMat.call("getObjectsOnMat")):
-- it should return everything on it grouped in a smart way (board, tray, warbands, cards, ...), and
-- deposit can then store each group in the order it needs.
function getObjectsOnMat(playerMat)
    -- Everything over the mat, from just below its surface (some pieces sit slightly sunk into it) upwards
    local matSize = playerMat.getBounds().size
    local hits = Physics.cast({
        origin       = vectorSum(playerMat.getPosition(), vector(0, -0.5, 0)),
        direction    = vector(0, 1, 0),
        type         = 3,
        size         = vector(matSize.x, 0.01, matSize.z),
        max_distance = 10,
    })
    local objects = {}
    for _, hit in ipairs(hits) do
        local object = hit.hit_object
        if object ~= playerMat and object.getGUID() ~= GUIDs.table and not object.hasTag("DoNotArchive") then
            table.insert(objects, object)
        end
    end
    return objects
end

-- Pieces that keep their place on the mat between deposit and withdraw, by tag
cardLayoutTags = {"Lineage", "Relic", "Card"}

-- object's position and rotation relative to board: the offset from the board turned into the board's yaw,
-- and the rotation with the board's yaw taken off. Turned back into the world by TransformFromBoard.
function TransformOnBoard(object, board)
    local position, boardPosition = object.getPosition(), board.getPosition()
    local rotation, boardYaw = object.getRotation(), board.getRotation().y
    local yaw = math.rad(boardYaw)
    local dx, dz = position.x - boardPosition.x, position.z - boardPosition.z
    return {
        position = {
            x = dx * math.cos(yaw) - dz * math.sin(yaw),
            y = position.y - boardPosition.y,
            z = dx * math.sin(yaw) + dz * math.cos(yaw),
        },
        rotation = {x = rotation.x, y = rotation.y - boardYaw, z = rotation.z},
    }
end

-- The world position and rotation for a TransformOnBoard result, with the board at boardPosition turned to boardYaw
function TransformFromBoard(relative, boardPosition, boardYaw)
    local yaw = math.rad(boardYaw)
    local x, z = relative.position.x, relative.position.z
    return {
        position = {
            x = boardPosition.x + x * math.cos(yaw) + z * math.sin(yaw),
            y = boardPosition.y + relative.position.y,
            z = boardPosition.z - x * math.sin(yaw) + z * math.cos(yaw),
        },
        rotation = {x = relative.rotation.x, y = relative.rotation.y + boardYaw, z = relative.rotation.z},
    }
end

-- Gives playerArchive the position and rotation of each card, relic and lineage card among objects (its player's mat,
-- about to be deposited) relative to the player board, by GUID, for withdraw to put them back the same way
function recordCardLayout(objects, playerArchive)
    local board
    for _, object in ipairs(objects) do
        if object.hasTag("PlayerBoard") then
            board = object
        end
    end
    if not board then
        playerArchive.call("SetCardLayout", {})
        return
    end
    local layout = {}
    for _, object in ipairs(objects) do
        local guid = object.getGUID()
        -- a Chancellor's regalia too, so they come back out where they were
        local keep = guid == GUIDs.grandScepter or guid == GUIDs.imperialReliquary
        for _, tag in ipairs(cardLayoutTags) do
            keep = keep or object.hasTag(tag)
        end
        if keep then
            layout[guid] = TransformOnBoard(object, board)
        end
    end
    playerArchive.call("SetCardLayout", layout)
end

-- For other objects (the storage box's "Deposit to Shelf"): bookshelf.call("Deposit", {color = "Red", player = "Red"}),
-- where player is the TTS color of whoever asked
function Deposit(params)
    deposit(params.color, params.player)
end

-- Puts everything in playerColor's play area back into their archive
function deposit(playerColor, player_clicked)
    if isColorBusy(playerColor, player_clicked) then return end
    local playerArchive = getObjectFromGUID(GUIDs.playerArchives[playerColor])
    local playerMat = withdrawnMats[playerColor] and getObjectFromGUID(withdrawnMats[playerColor])
    if not playerMat then
        Player[player_clicked].broadcast("Couldn't find the player mat " .. playerColor .. " was withdrawn to.")
        return
    end

    busyColors[playerColor] = true
    local toStore = getObjectsOnMat(playerMat)

    -- Their pawn goes too, wherever it is on the table. A Chancellor's pawn (theirs is already stored) and the
    -- regalia go back to the Chancellor Archive.
    local storing = {}
    for _, object in ipairs(toStore) do
        storing[object.getGUID()] = true
    end
    local function alsoStore(object)
        if object and not storing[object.getGUID()] then
            storing[object.getGUID()] = true
            table.insert(toStore, object)
        end
    end
    alsoStore(FindPawn(playerColor))
    if playerArchive.call("GetRole") == "CHANCELLOR" then
        alsoStore(FindPawn("Purple"))
        alsoStore(getObjectFromGUID(GUIDs.grandScepter))
        alsoStore(getObjectFromGUID(GUIDs.imperialReliquary))
    end
    recordCardLayout(toStore, playerArchive)

    -- A Chancellor's mat also holds the shared Chancellor tray and Purple warbands; those, the Chancellor's pawn and
    -- the regalia go back to the Chancellor Archive rather than the player's
    local chancellorArchive = getObjectFromGUID(GUIDs.playerArchives.Purple)
    local function archiveFor(object)
        local isChancellorTray = object.hasTag(tags.warbandTray) and object.memo == "Purple"
        local isPurpleWarband = GetWarbandObjectColor(object) == "Purple"
        local isChancellorPawn = object.hasTag(tags.pawn) and trim(object.memo) == "Purple"
        local isRegalia = object.getGUID() == GUIDs.grandScepter or object.getGUID() == GUIDs.imperialReliquary
        local chancellors = isChancellorTray or isPurpleWarband or isChancellorPawn or isRegalia
        return chancellors and chancellorArchive or playerArchive
    end

    -- Stores the pieces one per frame; the archives refuse anything unless allowEnter is set.
    -- Named per color so deposits of different colors can run at once.
    _G["depositCoroutine_" .. playerColor] = function()
        playerArchive.setVar("allowEnter", true)
        chancellorArchive.setVar("allowEnter", true)
        for _, object in ipairs(toStore) do
            -- Everyone keeps their role in storage; only the Chancellor's pieces go to the Chancellor Archive
            if not object.isDestroyed() then
                archiveFor(object).putObject(object)
            end
            coroutine.yield(0)
        end
        coroutine.yield(0)
        coroutine.yield(0)
        playerArchive.setVar("allowEnter", false)
        chancellorArchive.setVar("allowEnter", false)

        withdrawnMats[playerColor] = nil
        setArchiveWithdrawn(playerColor, false)
        busyColors[playerColor] = nil
        return 1
    end
    startLuaCoroutine(self, "depositCoroutine_" .. playerColor)
end

function withdraw(newPlayerColor, player_clicked)
    if isColorBusy(newPlayerColor, player_clicked) then return end

    local toChange = TTSColorMap.OathColorToTTSColor[newPlayerColor]
    local player_hand
    if player_clicked == "Black" then
        -- The Game Master stays Game Master: newPlayerColor goes to the mat in front of its own hand
        for _, hand in ipairs(Hands.getHands()) do
            if hand.getValue() == toChange then
                player_hand = hand
                break
            end
        end
        if player_hand == nil then
            Player[player_clicked].broadcast("No seat has the " .. newPlayerColor .. " hand.")
            return
        end
    else
        -- Block if that player already has assets
        local playerClickedColor = TTSColorMap.TTSColorToOathColor[player_clicked]
        local currentMat = withdrawnMats[playerClickedColor] and getObjectFromGUID(withdrawnMats[playerClickedColor])
        if currentMat then
            Player[player_clicked].broadcast("You already have a ".. playerClickedColor .." player mat.\nDeposit it before withdrawing another mat.")
            return
        end

        -- Swap hand colors so the clicking player becomes newPlayerColor without changing seats
        for _, hand in ipairs(Hands.getHands()) do
            local handColor = hand.getValue()
            if handColor == player_clicked then
                hand.setValue(toChange)
                player_hand = hand
            elseif handColor == toChange then
                hand.setValue(player_clicked)
            end
        end
        if player_hand == nil then return end
    end

    -- Find which player hand matches player_hand and highlight the corresponding player mat
    local playerMat
    for i, handGUID in ipairs(GUIDs.handZones) do
        if handGUID == player_hand.getGUID() then
            playerMat = getObjectFromGUID(GUIDs.playerMats[i])
            break
        end
    end
    if player_clicked == "Black" then
        -- a mat can only hold one player's pieces
        for otherColor, matGUID in pairs(withdrawnMats) do
            if matGUID == playerMat.getGUID() then
                Player[player_clicked].broadcast(otherColor .. " is already on the " .. newPlayerColor .. " seat's mat.")
                return
            end
        end
    else
        Player[player_clicked].changeColor(toChange)
    end
    busyColors[newPlayerColor] = true
    local playerArchive = getObjectFromGUID(GUIDs.playerArchives[newPlayerColor])
    playerMat.highlightOn(GetOathColor(newPlayerColor), 1)
    playerArchive.highlightOn(GetOathColor(newPlayerColor), 1)
    withdrawnMats[newPlayerColor] = playerMat.getGUID()
    setArchiveWithdrawn(newPlayerColor, true)

    -- The warband tile treats this archive as its warband bag and waits while this is set
    playerArchive.setVar("withdrawing", true)

    -- Takes everything out of the archive, warbands one at a time.
    -- Named per color so withdraws of different colors can run at once.
    -- A Citizen's or the Chancellor's own warbands stay in their archive: they use the Chancellor's instead
    local warbandsStayStored = playerArchive.call("GetRole") ~= "EXILE"
    -- The Chancellor's own pawn stays in their archive too: the storage box puts the Chancellor's pawn out instead
    local pawnStaysStored = playerArchive.call("GetRole") == "CHANCELLOR"

    -- Cards, relics and lineage cards go back where they were relative to the board, which lands at its layout spot
    local cardLayout = playerArchive.call("GetCardLayout") or {}
    local boardPosition = vectorSum(playerMat.getPosition(), pos.playerBoard(1))

    _G["withdrawCoroutine_" .. newPlayerColor] = function()
        -- Everything else (including the warband tile) comes out before the warbands
        local entries = {}
        for _, entry in ipairs(playerArchive.getObjects()) do
            if dataTableContains(entry.tags or {}, "Warband") then
                if not warbandsStayStored then
                    table.insert(entries, entry)
                end
            elseif dataTableContains(entry.tags or {}, tags.pawn) then
                if not pawnStaysStored then
                    table.insert(entries, 1, entry)
                end
            else
                table.insert(entries, 1, entry)
            end
        end

        local warbandCount = 0
        local takenObjects = {}
        local wasInteractable = {}
        -- nobody can grab a piece until everything has landed
        local function holdStill(object)
            table.insert(takenObjects, object)
            wasInteractable[object] = object.interactable
            object.interactable = false
        end
        for _, entry in ipairs(entries) do
            local isWarband = dataTableContains(entry.tags or {}, "Warband")
            local slot = 1
            if isWarband then
                warbandCount = warbandCount + 1
                slot = warbandCount
            end

            -- Its playerMatLayout position (or the mat's centre if it has none). Each piece goes straight
            -- there: taking them all out at one spot drops warbands into the storage bag, which returns
            -- them to the archive.
            local transform = {position = vectorSum(playerMat.getPosition(), vector(0, 1, 0))}
            for tag, key in pairs(playerMatLayout) do
                for _, entryTag in ipairs(entry.tags or {}) do
                    if entryTag:lower() == tag:lower() then
                        transform = getTransformStruct(key, slot, {position = playerMat.getPosition()})
                    end
                end
            end
            if cardLayout[entry.guid] then
                transform = TransformFromBoard(cardLayout[entry.guid], boardPosition, rot.playerBoard.y)
            end

            -- set up straight away, from the object takeObject returns: its callback only runs once a smooth take has
            -- glided all the way there, and the piece could be grabbed in the meantime
            local takenObject = playerArchive.takeObject({
                guid = entry.guid,
                position = transform.position,
                rotation = transform.rotation,
                smooth = true,
            })
            if takenObject then
                holdStill(takenObject)
                if isWarband then
                    -- every warband starts in the bank; the warband tile only manages pieces tagged as bank
                    takenObject.addTag("WarbandBank")
                end
                -- The warband tray, player board and storage bag lock once they've glided all the way to their spot
                if takenObject.hasTag(tags.warbandTray) or takenObject.hasTag("playerBoard") or takenObject.hasTag("warbandReturn") then
                    LockAtPosition(takenObject, transform.position)
                end
            end
            -- One piece a frame (warbands ten frames apart): each one loads its model and script as it comes out, and
            -- taking them all at once stalls the game while it does
            if isWarband then
                for i = 0, 10 do
                    coroutine.yield(0)
                end
            else
                coroutine.yield(0)
            end
        end

        -- A Chancellor's regalia come out of the Chancellor Archive where they were at their deposit (or onto their
        -- spots on the mat), before the storage box would put them on their spots
        if pawnStaysStored then
            local chancellorArchive = getObjectFromGUID(GUIDs.playerArchives.Purple)
            local spots = {[GUIDs.grandScepter] = "grandScepter", [GUIDs.imperialReliquary] = "imperialReliquary"}
            for _, entry in ipairs(chancellorArchive and chancellorArchive.getObjects() or {}) do
                local spot = spots[entry.guid]
                if spot then
                    local transform = cardLayout[entry.guid]
                        and TransformFromBoard(cardLayout[entry.guid], boardPosition, rot.playerBoard.y)
                        or getTransformStruct(spot, 1, {position = playerMat.getPosition()})
                    local regalia = chancellorArchive.takeObject({
                        guid = entry.guid,
                        position = transform.position,
                        rotation = transform.rotation,
                        smooth = true,
                    })
                    if regalia then
                        holdStill(regalia)
                    end
                    coroutine.yield(0)
                end
            end
        end

        -- Let everything land first (giving up after ~5s): the tile's repack fast-moves every bank warband,
        -- even ones still in the air, and a Chancellor's tile brings the Chancellor tray out next to itself
        for i = 0, 300 do
            local settled = #takenObjects >= #entries
            for _, object in ipairs(takenObjects) do
                if not object.isDestroyed() and (object.isSmoothMoving() or not object.resting) then
                    settled = false
                    break
                end
            end
            if settled then break end
            coroutine.yield(0)
        end
        for _, object in ipairs(takenObjects) do
            if not object.isDestroyed() then
                object.interactable = wasInteractable[object]
            end
        end

        -- The tile now finishes loading and arranges the bank warbands onto itself
        playerArchive.setVar("withdrawing", false)
        busyColors[newPlayerColor] = nil

        -- The cards are back in place, so the archive can forget the layout (the next deposit records a new one)
        playerArchive.call("SetCardLayout", {})
        return 1
    end
    startLuaCoroutine(self, "withdrawCoroutine_" .. newPlayerColor)


    -- TODO: Spawn objects for that color
end