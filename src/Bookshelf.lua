
require("src/Utils/ColorUtils")
require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")
require("src/Utils/Warbands")



-- Buttons
buttons = {
    withdraw = {
        click_function = "withdraw_",
        label          = "⬇\n",
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

function onSave()
    return JSON.encode({withdrawnMats = withdrawnMats})
end

function onLoad(savedData)
    local buttonPosition = -10.125
    for _, player in ipairs(bookshelfColors) do
        local button = {}
        for k, v in pairs(buttons.withdraw) do button[k] = v end
        button.click_function = "withdraw_" .. player
        button.color = GetOathColor(player)
        button.position = {buttonPosition, 0, 10}
        if player == "Black" then
            button.font_color = hexToColor("#838383")
        end
        self.createButton(button)
        _G["withdraw_" .. player] = function(_, player_clicker_color) withdraw(player, player_clicker_color) end
        _G["deposit_" .. player] = function(_, player_clicker_color) deposit(player, player_clicker_color) end
        buttonPosition = buttonPosition + 4.025
    end

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
    if savedData and savedData ~= "" then
        withdrawnMats = JSON.decode(savedData).withdrawnMats or {}
    end
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
                label          = withdrawn and "\n⬆" or "⬇\n",
                tooltip        = withdrawn and "Deposit this player back into their archive" or buttons.withdraw.tooltip,
            })
        end
    end
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
        for _, tag in ipairs(cardLayoutTags) do
            if object.hasTag(tag) then
                layout[object.getGUID()] = TransformOnBoard(object, board)
                break
            end
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
    recordCardLayout(toStore, playerArchive)

    -- A Chancellor's mat also holds the shared Chancellor tray and Purple warbands; those go back to the
    -- Chancellor Archive rather than the player's
    local chancellorArchive = getObjectFromGUID(GUIDs.playerArchives.Purple)
    local function archiveFor(object)
        local isChancellorTray = object.hasTag(tags.warbandTray) and object.memo == "Purple"
        local isPurpleWarband = GetWarbandObjectColor(object) == "Purple"
        return (isChancellorTray or isPurpleWarband) and chancellorArchive or playerArchive
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
            else
                table.insert(entries, 1, entry)
            end
        end

        local warbandCount = 0
        local takenObjects = {}
        local wasInteractable = {}
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

            playerArchive.takeObject({
                guid = entry.guid,
                position = transform.position,
                rotation = transform.rotation,
                smooth = true,
                callback_function = function(takenObject)
                    table.insert(takenObjects, takenObject)
                    -- nobody can grab it until everything has landed
                    wasInteractable[takenObject] = takenObject.interactable
                    takenObject.interactable = false
                    if isWarband then
                        -- every warband starts in the bank; the warband tile only manages pieces tagged as bank
                        takenObject.addTag("WarbandBank")
                    end
                    -- The warband tray, player board and storage bag lock once they've glided all the way to their spot
                    if takenObject.hasTag(tags.warbandTray) or takenObject.hasTag("playerBoard") or takenObject.hasTag("warbandReturn") then
                        LockAtPosition(takenObject, transform.position)
                    end
                end
            })
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

        -- Let everything land first (giving up after ~5s): the tile's repack fast-moves every bank warband,
        -- even ones still in the air, and a Chancellor's tile brings the Chancellor tray out next to itself
        for i = 0, 300 do
            local settled = #takenObjects == #entries
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