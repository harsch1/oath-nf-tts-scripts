require('src/Utils/ColorUtils')

local playerArchive = "130c82"

local matSize = vector(29.75, 0.01, 21.10)

local handleOffset = vector(0,1,0)

local activeButtons = {
  ArchivePlayer = true,
  AssociateWithSteamName = false
};

local buttonIndices = {
  OnArchive = 0,
  OnSaveSteamName = 1,
  OnLoadSteamProfile = 2,
}

local AssociateWithSteamNameButtonText = "Associate With Steam Name"

function onLoad(save_str)

  local params = {
      click_function = "OnArchive",
      function_owner = self,
      label          = "Archive Player",
      position       = {-10, 0.01, 0.5*matSize.z},
      rotation       = {0, 0, 0},
      width          = 2600,
      height         = 400,
      font_size      = 300,
      color          = Color.fromHex('#E0E2E1E7'),
      font_color     = Color.fromHex('#000000'),
      tooltip        = 'Move this player to the archive',
  }
  self.createButton(params)

  local params = {
      click_function = "OnSaveSteamName",
      function_owner = self,
      label          = AssociateWithSteamNameButtonText,
      position       = {0, 0.01, 0.5*matSize.z},
      rotation       = {0, 0, 0},
      width          = 4500,
      height         = 400,
      font_size      = 300,
      color          = Color.fromHex('#E0E2E1E7'),
      font_color     = Color.fromHex('#000000'),
      tooltip        = 'Claim this color as your own!',
  }
  self.createButton(params)

  local params = {
      click_function = "OnLoadSteamProfile",
      function_owner = self,
      label          = "Load Steam Profile",
      position       = {10, 0.01, 0.5*matSize.z},
      rotation       = {0, 0, 0},
      width          = 2600,
      height         = 400,
      font_size      = 300,
      color          = Color.fromHex('#E0E2E1E7'),
      font_color     = Color.fromHex('#000000'),
      tooltip        = "If you've associated a color with your steam name, load it",
  }
  self.createButton(params)

  playerArchive = getObjectFromGUID(playerArchive)
  self.max_typed_number = 9
end



function CastForObjects()
  return Physics.cast({
    origin = self.getPosition() + vector(0,2*matSize.y,0),
    direction = vector(0,1,0),
    type=3,
    size=matSize
  })
end

function NextHotkeyValue()
  local max = 0
  for _, handle in ipairs(getObjectsWithTag('archivedPlayer')) do
    local memoTable = {}
    
    if handle.memo ~= nil and handle.memo ~= "" then
      memoTable = JSON.decode(handle.memo)
    end
    local usedHotkey = memoTable.hotkey
    if usedHotkey ~= nil then
      max = math.max(max, usedHotkey)
    end
  end

  for _, data in ipairs(playerArchive.getObjects()) do
    local memoTable = {}
    if data.memo ~= nil and data.memo ~= "" then
      memoTable = JSON.decode(data.memo)
    end
    local usedHotkey = memoTable.hotkey
    if usedHotkey ~= nil then
      max = math.max(max, usedHotkey)
    end
  end

  return max + 1
end

function FindOrCreateHandle(hits)
  for _, info in ipairs(hits) do
    if info.hit_object.hasTag('archivedPlayer') then
      return info.hit_object
    end
  end

  local handle = spawnObject({
    type ='BlockSquare',
    position = self.getPosition() + handleOffset,
    rotation = self.getRotation(),
    scale = vector(0.00001,0.00001,0.00001)
  })
  handle.addTag('archivedPlayer')
  handle.setLock(true)
  handle.setColorTint({0,0,0,0})
  handle.interactable = false

  handle.memo = JSON.encode({['hotkey'] = NextHotkeyValue()})

  return handle
end

function OnArchive(_, player_color, _)
  local hits = CastForObjects()

  local toAttach = {}
  for _, info in ipairs(hits) do
    if not info.hit_object.hasTag('archivedPlayer') and not info.hit_object.hasTag('DoNotArchive') then
      table.insert(toAttach, info.hit_object)
    end
  end

  if #toAttach == 0 then
    return
  end

  -- attach found objects to a cube for easy handling
  local handle = FindOrCreateHandle(hits)
  
  -- attach all the objects so they can be stored in a state
  for _, object in ipairs(toAttach) do
    handle.addAttachment(object)
  end

  handle = handle.reload()
  handle.setPosition(playerArchive.getPosition() + handleOffset + vector(0, 5, 0))

  -- put into player archive bag
  playerArchive.putObject(handle)

  self.editButton({
    index = buttonIndices.OnSaveSteamName,
    label = AssociateWithSteamNameButtonText
  })
end

function onObjectDrop(player_color, object)
  if not object.isDestroyed() and object.hasTag('archivedPlayer') then
    local hits = Physics.cast({
      origin = object.getPosition(),
      direction = vector(0,-1,0),
      type=1
    })
    for _, info in ipairs(hits) do
      if info.hit_object == self then
        object.setPosition(self.getPosition() + handleOffset)
        object = object.reload()
        object.removeAttachments()
        object.setScale(vector(0.01,0.01,0.01))
        object.setColorTint({0,0,0,256})
        object.interactable = false
        object.setLock(true)
        UpdateNametag(object)
        UpdatePlayerColor()
        break
      end
    end
  end
end

function onObjectLeaveContainer(container, object)
  if object.hasTag('archivedPlayer') then
    object.setLock(false)
    Wait.frames(function()
      -- when dragging from a bag's "search" menu, onObjectDrop doesn't get called automatically. call it manually 
      if object.held_by_color == nil then
        onObjectDrop(nil, object)
      end
    end, 1)
  end
end

function getHandleGuidForHotkey(hotKey)
  for _, data in ipairs(playerArchive.getObjects()) do
    local memoTable = {}
    if data.memo ~= nil and data.memo ~= "" then
      memoTable = JSON.decode(data.memo)
    end
    if memoTable.hotkey == hotKey then
      return data.guid
    end
  end
  return nil
end

function getHandleGuidForSteamId(steam_id)
  for _, data in ipairs(playerArchive.getObjects()) do
    local memoTable = {}
    if data.memo ~= nil and data.memo ~= "" then
      memoTable = JSON.decode(data.memo)
    end
    if memoTable.steam_id == steam_id then
      return data.guid
    end
  end
  return nil
end

local onNumberTypedIsRunning = false
function LoadPlayerFromArchive(handleGuid)
  if not handleGuid then
    return
  end

  if onNumberTypedIsRunning then
    return
  end

  onNumberTypedIsRunning = true

  function helper_coroutine()

    OnArchive(nil, player_color, nil)
    coroutine.yield(0)

    local handle = playerArchive.takeObject({
      position = self.getPosition() + handleOffset,
      rotation = self.getRotation(),
      smooth = false,
      guid = handleGuid
    })
    handle.setLock(true)
    coroutine.yield(0)
    onObjectDrop(player_color, handle);

    for i = 1, 15 do
      coroutine.yield(0)
    end
    onNumberTypedIsRunning = false
    return 1
  end
  startLuaCoroutine(self, "helper_coroutine")

end

function onNumberTyped(player_color, number)

  local handleGuid = getHandleGuidForHotkey(number)
  LoadPlayerFromArchive(handleGuid)
end

function UpdateNametag(handle)
  if not handle then
    local hits = CastForObjects()
    if #hits == 0 then
      return
    end
  
    -- attach found objects to a cube for easy handling
    handle = FindOrCreateHandle(hits)
  end
  
  local memo = {}
  if handle ~= nil and handle.memo ~= nil and handle.memo ~= "" then
    memo = JSON.decode(handle.memo)
  end

  if memo.steam_name ~= nil then
    self.editButton({
      index = buttonIndices.OnSaveSteamName,
      label = memo.steam_name
    })
  else
    self.editButton({
      index = buttonIndices.OnSaveSteamName,
      label = AssociateWithSteamNameButtonText
    })
  end
end

function OnSaveSteamName(_, player_color, right_click)

  local hits = CastForObjects()
  if #hits == 0 then
    return
  end

  -- attach found objects to a cube for easy handling
  local handle = FindOrCreateHandle(hits)
  local memo = {}
  if handle ~= nil and handle.memo ~= nil and handle.memo ~= "" then
    memo = JSON.decode(handle.memo)
  end

  if right_click or memo.steam_id == Player[player_color].steam_id then
    memo.steam_id = nil
    memo.steam_name = nil
  else
    memo.steam_id = Player[player_color].steam_id
    memo.steam_name = Player[player_color].steam_name
  end
  handle.memo = JSON.encode(memo)
  handle.setName(memo.steam_name)
  
  UpdateNametag(handle)
end

function OnLoadSteamProfile(_, player_color, right_click)

  local handleGuid = getHandleGuidForSteamId(Player[player_color].steam_id)
  LoadPlayerFromArchive(handleGuid)
end

function GetNearestPlayer()
  local position = self.getPosition()
  local shortestDistance = 1000000000
  local result = nil
  for _, color in ipairs(Player.getAvailableColors()) do
    local player = Player[color]
    local distance = position:distance(player.getHandTransform().position)
    if (distance < shortestDistance) then
      shortestDistance = distance
      result = player
    end
  end
  return result
end

function GetWarbandBag()
  local hits = CastForObjects()
  for _, info in ipairs(hits) do
    if info.hit_object.type == 'Bag' and info.hit_object.getName() == "Warbands" then
      return info.hit_object
    end
  end
  return nil
end

function UpdatePlayerColor()
  local hands = {}
  local unusedColors = {
    ["Brown"] = true,
    ["Orange"] = true,
    ["Red"] = true,
    ["Yellow"] = true,
    ["White"] = true,
    ["Green"] = true,
    ["Teal"] = true,
    ["Blue"] = true,
    ["Purple"] = true,
    ["Pink"] = true,
  }
  for _, object in ipairs(getObjectFromGUID('84ebee').getObjects(true)) do
    if object.type == 'Hand' then
      hands[object.getData().FogColor] = object
      unusedColors[object.getData().FogColor] = nil
    end
  end



  local warbandBag = GetWarbandBag()
  local player = GetNearestPlayer()
  if warbandBag and player then
    local playerColor = GetBestFitTTSColor(warbandBag.getColorTint())
    if playerColor ~= player.color then
      if hands[player.color] ~= nil then
        if hands[playerColor] ~= nil then
          for color, _ in pairs(unusedColors) do
            hands[playerColor].setValue(color)
            break
          end
        end

        hands[player.color].setValue(playerColor)
      end
      player.changeColor(playerColor)
    end
  end
end
