-- ==============================
-- OATH PLAYER STORAGE BOX
--
-- Each color's "Storage and Warband Return" box: the player's
-- main interface while they're out on the table, and the
-- authority on their role. Its right-click menu changes role
-- and returns the player to the shelf. A role change goes to
-- the archive boxes, the player board and the warband tray, and
-- swaps the player's pawn (and the Chancellor's regalia).
--
-- Every warband dropped into it is sent to the tray banking its
-- color, or into that color's archive box if no tray is.
--
-- Its memo is JSON: its color, and the diffuse and normal URLs
-- for each role ("exile", "citizen", "chancellor"). The model
-- and collider are the player foldbox, or the Chancellor
-- foldbox while it's the Chancellor.
-- ==============================

require("src/Config/GeneralConfig")
require("src/Utils/ColorUtils")
require("src/Utils/HelperFunctions")
require("src/Utils/Warbands")
require("src/Utils/Stamps")

local ROLES = {EXILE = true, CITIZEN = true, CHANCELLOR = true}

-- The role changes in the right-click menu, by current role
local ROLE_CHANGES = {
    EXILE = {"CITIZEN", "CHANCELLOR"},
    CITIZEN = {"EXILE", "CHANCELLOR"},
    CHANCELLOR = {"EXILE", "CITIZEN"},
}

-- Seconds to wait for the tray and board to finish a role change before giving up on them
local ROLE_CHANGE_TIMEOUT = 15

-- Frames after loading before the box takes calls and pushes its role to the others
local LOAD_FRAMES = 60

-- Each role's pawn state (the Chancellor's own pawn is stored)
local PAWN_STATE = {EXILE = 1, CITIZEN = 2}

-- The regalia: their GUIDs and their spots on the Chancellor's mat (pos and rot in GeneralConfig)
local REGALIA = {
    {guid = GUIDs.grandScepter, layout = "grandScepter"},
    {guid = GUIDs.imperialReliquary, layout = "imperialReliquary"},
}

-- ==============================
-- STATE
-- ==============================

local color = nil
local role = "EXILE"
local initialized = false
local busy = false
local reloading = false

-- ==============================
-- SAVE
-- ==============================

function GetSaveState()
    return {
        role = role,
    }
end

function SaveState()
    self.script_state = JSON.encode(GetSaveState())
end

function onSave()
    return JSON.encode(GetSaveState())
end

-- ==============================
-- LOAD
-- ==============================

function onLoad(savedData)
    -- Custom model should remain untinted.
    self.setColorTint(Color(1, 1, 1))

    color = ReadMemo().color
    if not GetOathColor(color) or color == "Purple" then
        print(self.getName() .. " has no lineage color in its memo (expected e.g. {\"color\": \"Red\"}).")
        return
    end

    local saved = nil
    if savedData and savedData ~= "" then
        local success, decoded = pcall(JSON.decode, savedData)
        saved = success and decoded or nil
    end
    if saved then
        -- currentMode is what older versions of this script saved
        local savedRole = saved.role or saved.currentMode
        if ROLES[savedRole] then
            role = savedRole
        end
    else
        -- First load: the archive box remembers the role
        local archive = GetArchive(color)
        local archiveRole = archive and archive.call("GetRole")
        if ROLES[archiveRole] then
            role = archiveRole
        end
    end
    SaveState()
    RefreshControls()

    -- Wait until the box is on its spot on the mat and locked (a new look reloads the box, which loses the lock
    -- the Bookshelf gave it, and would stop it gliding out of the archive). Then let the tray, board and
    -- archives load, and take over as the authority on the role.
    LockAtLayoutPosition(self, color, "warbandReturn", function()
        Wait.frames(function()
            initialized = true
            -- placed again now the box is on its spot
            RefreshControls()
            -- bring the archives, board and tray in line with this box's role
            local archive = GetArchive(color)
            if archive then
                archive.call("SetRole", role)
            end
            local chancellorArchive = GetArchive("Purple")
            if role == "CHANCELLOR" and chancellorArchive and not GetChancellorColor() then
                chancellorArchive.call("SetChancellor", color)
            end
            SyncBoard()
            local tray = FindTray(color)
            if tray and not tray.call("IsBusy") and tray.call("GetMode") ~= role then
                tray.call("ApplyRole", role)
            end
            -- A Chancellor withdrawn from the shelf: their own pawn stayed in their archive
            if role == "CHANCELLOR" then
                if not FindPawn("Purple") then
                    TakePawnFromArchive(GetArchive("Purple"), PawnSpot())
                end
                TakeOutRegalia()
            end
            UpdateAppearance()
        end, LOAD_FRAMES)
    end)
end

-- ==============================
-- PUBLIC API
-- ==============================

function GetColor()
    return color
end

function GetRole()
    return role
end

function IsBusy()
    return busy
end

-- Changes this player's role. fromBoard (default true) means the player board asked, its state already
-- showing the role, so it isn't flipped back. The board calls box.call("SetRole", "CITIZEN"), which can only
-- pass the role; this box's own menu passes fromBoard = false. Returns true if the change started.
function SetRole(newRole, fromBoard)
    if fromBoard == nil then
        fromBoard = true
    end
    newRole = newRole and string.upper(tostring(newRole))
    if not ROLES[newRole] or not color then
        return false
    end
    -- Still loading or mid-change: the board is put back in line once that's done
    if not initialized or busy then
        return false
    end
    if newRole == role then
        return false
    end

    -- Only one Chancellor at a time
    if newRole == "CHANCELLOR" then
        local chancellor = GetChancellorColor()
        if chancellor and chancellor ~= color then
            broadcastToAll(color .. " can't become the Chancellor: " .. chancellor .. " already is.", GetOathColor(color))
            if fromBoard then
                SyncBoard()
            end
            return false
        end
    end

    busy = true
    local oldRole = role
    role = newRole
    SaveState()
    RefreshControls()

    -- The archive boxes remember the role while this box is stored
    local archive = GetArchive(color)
    if archive then
        archive.call("SetRole", role)
    end
    local chancellorArchive = GetArchive("Purple")
    if chancellorArchive then
        if role == "CHANCELLOR" then
            chancellorArchive.call("SetChancellor", color)
        elseif oldRole == "CHANCELLOR" then
            chancellorArchive.call("SetChancellor", "")
        end
    end

    if not fromBoard then
        SyncBoard()
    end
    local tray = FindTray(color)
    if tray then
        tray.call("ApplyRole", role)
    end
    -- put out the pawn for the new role
    if role == "CHANCELLOR" then
        -- theirs goes into their archive, and the Chancellor's takes its place
        SwapPawn(FindPawn(color), GetArchive(color), GetArchive("Purple"), nil)
    elseif oldRole == "CHANCELLOR" then
        -- the Chancellor's goes back, and theirs takes its place, showing their new role
        SwapPawn(FindPawn("Purple"), GetArchive("Purple"), GetArchive(color), PAWN_STATE[role])
    else
        local pawn = FindPawn(color)
        if pawn then
            SetPawnState(pawn, PAWN_STATE[role])
        end
    end
    if role == "CHANCELLOR" then
        TakeOutRegalia()
    elseif oldRole == "CHANCELLOR" then
        -- whichever regalia are out on the table go back into the Chancellor Archive
        local archive = GetArchive("Purple")
        for _, regalia in ipairs(REGALIA) do
            local object = getObjectFromGUID(regalia.guid)
            if archive and object then
                archive.call("StoreObject", object)
            end
        end
    end

    -- Wait for the tray and board to finish, giving up after ROLE_CHANGE_TIMEOUT seconds
    Wait.condition(FinishRoleChange, function()
        return IsRoleChangeDone(tray)
    end, ROLE_CHANGE_TIMEOUT, function()
        broadcastToAll(color .. "'s role change to " .. TitleCase(role) .. " timed out; check their tray and board.", Color.Red)
        FinishRoleChange()
    end)
    return true
end

-- Sends a warband to the tray banking its color, or into its color's archive box if no tray is.
-- Returns false if it had nowhere to go (it's set down beside the box).
function RouteWarband(object)
    if object == nil or object.isDestroyed() then
        return false
    end
    local warbandColor = GetWarbandObjectColor(object)
    if warbandColor then
        object.setVelocity({0, 0, 0})
        object.setAngularVelocity({0, 0, 0})
        local tray = FindBankingTray(warbandColor)
        if tray and tray.call("AcceptWarband", object) then
            return true
        end
        local archive = GetArchive(warbandColor)
        if archive then
            object.removeTag(tags.warbandBank)
            return archive.call("StoreObject", object)
        end
    end
    object.setPosition(self.getPosition() + Vector(3, 2, 0))
    return false
end

-- ==============================
-- ROLE CHANGE
-- ==============================

function IsRoleChangeDone(tray)
    if tray and not tray.isDestroyed() and tray.call("IsBusy") then
        return false
    end
    local board = FindPlayerBoard(color)
    return not board or board.call("GetRole") == role
end

function FinishRoleChange()
    busy = false
    SaveState()
    -- The board may have been flipped while the change ran
    SyncBoard()
    RefreshControls()
    UpdateAppearance()
end

function SyncBoard()
    local board = FindPlayerBoard(color)
    if board and board.call("GetRole") ~= role then
        board.call("ApplyRole", role)
    end
end

-- ==============================
-- CONTROLS
--
-- The right-click menu, and the Citizen's button for taking
-- the Chancellor's warbands, which sits where the warband tray
-- would be.
-- ==============================

function RefreshControls()
    self.clearContextMenu()
    for _, target in ipairs(ROLE_CHANGES[role] or {}) do
        self.addContextMenuItem("Become " .. TitleCase(target), function(playerColor)
            if busy then
                Player[playerColor].broadcast(color .. " is still changing role. Try again in a moment.")
                return
            end
            SetRole(target, false)
        end)
    end
    self.addContextMenuItem("Deposit to Shelf", DepositToShelf)

    self.clearButtons()
    if role == "CITIZEN" then
        -- button positions use the object's local axes with x flipped
        local spot = self.positionToLocal(CitizenButtonSpot())
        spot.x = -spot.x
        self.createButton({
            click_function = "TakeChancellorWarband",
            function_owner = self,
            label = "Gain an\nImperial\nWarband",
            tooltip = "Gain one of the Chancellor's Imperial warbands",
            position = spot,
            -- the box lies upside down, so the button faces its underside, turned to read the right way up
            rotation = {0, 180, 180},
            width = 1200,
            height = 900,
            font_size = 200,
            color = Color.fromHex("9F3083"),
            font_color = {1, 1, 1},
        })
    end
end

-- Where the warband tray sits on the mat (pos.warbandTray), as seen from this box (pos.warbandReturn)
function CitizenButtonSpot()
    local tray, box = pos.warbandTray(1), pos.warbandReturn(1)
    return self.getPosition() + Vector(tray.x - box.x, tray.y - box.y + 0.1, tray.z - box.z)
end

-- The Citizen's button: one of the Chancellor's warbands, from the Chancellor tray if it's out,
-- otherwise straight from the Chancellor Archive, set down upright on the next free snap point
function TakeChancellorWarband(_, playerColor)
    -- the next free warband spot on the mat (NextWarbandSpot), or just above the button if they're all taken
    local mat = FindPlayerMatUnder(self)
    local spot = (mat and NextWarbandSpot(mat)) or CitizenButtonSpot() + Vector(0, 1, 0)
    local chancellorTray = FindBankingTray("Purple")
    local warband = chancellorTray and chancellorTray.call("WithdrawPurpleFromTray")
    if warband then
        warband.setRotationSmooth({0, 0, 0}, false, false)
        warband.setPositionSmooth(spot, false, false)
        return
    end
    local archive = GetArchive("Purple")
    if not (archive and archive.call("TakeWarband", {position = spot, rotation = {0, 0, 0}})) then
        Player[playerColor].broadcast("The Chancellor has no warbands left.")
    end
end

-- Same as the Bookshelf's deposit button: everything on this player's mat back into their archive
function DepositToShelf(playerColor)
    if busy then
        Player[playerColor].broadcast(color .. " is still changing role. Try again in a moment.")
        return
    end
    local bookshelf = getObjectFromGUID(GUIDs.bookshelf)
    if bookshelf then
        bookshelf.call("Deposit", {color = color, player = playerColor})
    end
end

-- ==============================
-- PAWNS AND REGALIA
--
-- A player's pawn shows their role: state 1 as an Exile, state 2
-- as a Citizen. While they're the Chancellor their pawn waits in
-- their archive and the Chancellor's pawn (memo "Purple") stands
-- where it stood. The Grand Scepter and Imperial Reliquary come
-- out of the Chancellor Archive with the role and go back with it.
-- ==============================

-- Seconds to wait for a pawn to land before changing its state
local PAWN_SETTLE_TIMEOUT = 5

-- Where a piece goes on this player's mat (pos[layout] and rot[layout]), or beside the box if it isn't on one
function MatSpot(layout)
    local mat = FindPlayerMatUnder(self)
    if not mat then
        return {position = self.getPosition() + Vector(3, 2, 0), rotation = {0, 180, 0}}
    end
    return getTransformStruct(layout, 1, {position = mat.getPosition()})
end

function PawnSpot()
    return MatSpot("playerPawn")
end

-- Stores the leaving pawn in its archive and takes the pawn out of comingArchive where it stood (or onto this
-- player's pawn spot if it wasn't out), turning it to state if given
function SwapPawn(leaving, leavingArchive, comingArchive, state)
    local spot = PawnSpot()
    if leaving then
        spot = {position = leaving.getPosition() + Vector(0, 0.5, 0), rotation = leaving.getRotation()}
        if leavingArchive then
            leavingArchive.call("StoreObject", leaving)
        end
    end
    TakePawnFromArchive(comingArchive, spot, state)
end

-- Takes the pawn out of archive (each archive holds at most one) onto spot, turning it to state if given
function TakePawnFromArchive(archive, spot, state)
    for _, entry in ipairs(archive and archive.getObjects() or {}) do
        if BagEntryHasTag(entry, tags.pawn) then
            archive.takeObject({
                guid = entry.guid,
                position = spot.position,
                rotation = spot.rotation,
                smooth = true,
                callback_function = function(pawn)
                    -- a new state replaces the object, so it waits until the pawn has landed
                    Wait.condition(function()
                        SetPawnState(pawn, state)
                    end, function()
                        return pawn.isDestroyed() or not pawn.isSmoothMoving()
                    end, PAWN_SETTLE_TIMEOUT)
                end,
            })
            return
        end
    end
end

function SetPawnState(pawn, state)
    if state and not pawn.isDestroyed() and pawn.getStateId() ~= state then
        pawn.setState(state)
    end
end

-- Takes whichever regalia are in the Chancellor Archive out onto their spots on this player's mat
function TakeOutRegalia()
    local archive = GetArchive("Purple")
    if not archive then
        return
    end
    for _, entry in ipairs(archive.getObjects()) do
        for _, regalia in ipairs(REGALIA) do
            if entry.guid == regalia.guid then
                local spot = MatSpot(regalia.layout)
                archive.takeObject({guid = entry.guid, position = spot.position, rotation = spot.rotation, smooth = true})
            end
        end
    end
end

-- ==============================
-- APPEARANCE
-- ==============================

-- Puts on the model for the current role, with that role's diffuse and normal from the memo, then its stamp.
-- A new look reloads the box (which stamps itself once it has loaded again), so this is always the last step.
function UpdateAppearance()
    if reloading then
        return
    end
    local look = ReadMemo()[string.lower(role)]
    if type(look) ~= "table" or (look.diffuse or "") == "" then
        print(self.getName() .. " has no " .. TitleCase(role) .. " look in its memo.")
        UpdateStamp()
        return
    end
    -- the player's foldbox, or the Chancellor's while this player is the Chancellor
    local model = role == "CHANCELLOR" and foldboxModels.chancellor or foldboxModels.player
    local custom = self.getCustomObject()
    local normal = look.normal or ""
    if custom.mesh == model.mesh and custom.collider == model.collider and custom.diffuse == look.diffuse and custom.normal == normal then
        UpdateStamp()
        return
    end
    custom.mesh = model.mesh
    custom.collider = model.collider
    custom.diffuse = look.diffuse
    custom.normal = normal
    reloading = true
    SaveState()
    self.setCustomObject(custom)
    self.reload()
end

-- The stamp on the box's face-up cover: the player's color as the Chancellor, the citizen stamp as a Citizen.
-- Placed from the box's current model, so only once it has the look for its role.
function UpdateStamp()
    local key = role == "CHANCELLOR" and color or role == "CITIZEN" and "Citizen" or nil
    SetStamp(self, key, StampOnCover)
end

-- ==============================
-- WARBANDS DROPPED IN
-- ==============================

-- Warbands never go in: they're sent to their tray or archive instead
function tryObjectEnter(object)
    if object.hasTag(tags.warband) then
        Wait.frames(function()
            RouteWarband(object)
        end, 1)
        return false
    end
    return true
end

-- ==============================
-- LOOKUPS
-- ==============================

-- This box's memo, decoded ({} if it isn't JSON)
function ReadMemo()
    local success, memo = pcall(JSON.decode, self.memo or "")
    return success and type(memo) == "table" and memo or {}
end

function GetArchive(archiveColor)
    local guid = GUIDs.playerArchives[archiveColor]
    return guid and getObjectFromGUID(guid)
end

-- Who is the Chancellor, as the Chancellor Archive remembers it
function GetChancellorColor()
    local archive = GetArchive("Purple")
    return archive and archive.call("GetChancellor")
end

-- The warband tray out on the table whose memo is trayColor ("Purple" is the Chancellor tray)
function FindTray(trayColor)
    for _, tray in ipairs(getObjectsWithTag(tags.warbandTray)) do
        if not tray.isDestroyed() and trim(tray.memo) == trayColor then
            return tray
        end
    end
    return nil
end

-- The tray banking warbandColor right now: the Chancellor tray for Purple, or that color's tray while its player is an Exile
function FindBankingTray(warbandColor)
    local tray = FindTray(warbandColor)
    if tray and (warbandColor == "Purple" or tray.call("GetMode") == "EXILE") then
        return tray
    end
    return nil
end

-- ==============================
-- HELPERS
-- ==============================

function TitleCase(text)
    return text:sub(1, 1):upper() .. text:sub(2):lower()
end
