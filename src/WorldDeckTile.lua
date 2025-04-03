
require("src/Config/GeneralConfig")
require("src/Utils/HelperFunctions")

local VisionBackURL = "http://tts.ledergames.com/Oath/cards/3_2_0/cardbackVision.jpg"

local map = getObjectFromGUID(GUIDs.map)
if map == nil then
    printToAll("ERROR: Cannot find Map by GUID")
end
local worldDeckPosition = getTransformStruct("worldDeck", 0, {position = map.getPosition(), rotation = map.getRotation()})
local cachedWorldDeck = nil

function FindWorldDeck()
  if cachedWorldDeck and not cachedWorldDeck.isDestroyed() then
    return cachedWorldDeck
  end
  local hitList = Physics.cast({
    origin = vectorSum(worldDeckPosition.position, vector(0, -1, 0)),
    direction = vector(0, 1, 0),
    type = 1,
    max_distance = 10,
  })
  for _, hit_info in ipairs(hitList) do
    if hit_info.hit_object.type == "Deck" then
      cachedWorldDeck = hit_info.hit_object
      return cachedWorldDeck
    end
  end
  return nil
end

function onload(save_str)
  CreateDeckSetupButtons()
  FindWorldDeck()
end

function CreateDeckSetupButtons()
  self.clearButtons()
  local params = {
      click_function = "OnShuffleFairWorldDeck",
      function_owner = self,
      label          = "Randomize\nNew Deck",
      position       = {0, 0.1001, 0},
      rotation       = {0, 90, 0},
      width          = 900,
      height         = 1350,
      font_size      = 60,
      color          = {0, 0, 0, 0.35},
      font_color     = {0, 0, 0, 0},
      tooltip        = 'Click to automatically set up deck',
  }
  self.createButton(params)

  
  local params = {
    click_function = "OnShuffleUnfairWorldDeck",
    function_owner = self,
    label          = "Randomize\nNew Deck",
    position       = {0, -0.1001, 0},
    rotation       = {180, 90, 0},
    width          = 900,
    height         = 1350,
    font_size      = 60,
    color          = {0, 0, 0, 0.35},
    font_color     = {0, 0, 0, 0},
    tooltip        = 'Click to automatically set up deck',
  }
  self.createButton(params)
end


function InsertCardInDeck(deck, card, index)
  local rotation = deck.getRotation()
  local result = nil
  local deckQuantity = deck.getQuantity()

  if index == 1 then
    -- insert at beginning
    result = group({card, deck})[1]
  elseif index == 2 then
    -- insert at second card
    local frontCard = deck.takeObject({top=true})
    result = group({frontCard, card, deck})[1]
  elseif index == deckQuantity then
    -- insert at second to last card
    local backCard = deck.takeObject({top=false})
    result = group({deck, card, backCard})[1]
  elseif index == deckQuantity + 1 then
    -- insert at end
    result = group({deck, card})[1]
  else
    -- insert somewhere in the middle
    local decks = deck.cut(deckQuantity-(index-1))
    result = group({decks[2], card, decks[1]})[1]
  end

  -- cutting and grouping can cause the deck to be rotated. This fixes that.
  result.setRotation(rotation)

  return result
end


function FindAllVisions()
  local result = {}
  for _, object in ipairs(getAllObjects()) do
    if object.type == 'Card' then
      local cardData = object.getData()
      local deckID = math.floor(cardData.CardID / 100)
      if cardData.CustomDeck[deckID].BackURL == VisionBackURL then
        table.insert(result, object) -- found vision outside deck
      end
    elseif object.type == 'Deck' then
      local deckData = object.getData()
      -- reverse iterate contained objects so that removing from the deck doesn't change indices
      for i = #deckData.ContainedObjects, 1, -1 do
        local info = deckData.ContainedObjects[i]
        local deckID = math.floor(info.CardID / 100)
        if deckData.CustomDeck[deckID].BackURL == VisionBackURL then
          table.insert(result, object.takeObject({index=i-1, smooth=false}))
        end
      end
    end
  end
  return result
end

function ShuffleTable(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end


-- this will perform world deck setup on the 'A Fair Deck' foundation
function OnShuffleFairWorldDeck(_, player_color, _)

  -- find and shuffle visions
  local visions = ShuffleTable(FindAllVisions())
  if #visions ~= 5 then
    broadcastToAll("Error: Could not find all 5 visions!")
    return
  end
  
  -- find and shuffle world deck
  local worldDeck = FindWorldDeck()
  if worldDeck == nil then
    broadcastToColor("World deck not found! Is this a new chronicle? Use the Atlas Portal to generate one.", player_color, {r=0.8, g=0, b=0})
    return
  end
  worldDeck.shuffle()

  -- insert visions at random positions according to rules

  if worldDeck.getQuantity() >= 25 then
    -- two visions go in the first 12 slots
    for i = 1, 2 do
      local index = math.random(1, 10+i)
      visions[i].tooltip = false
      worldDeck = InsertCardInDeck(worldDeck, visions[i], index)
    end

    -- three visions go between slots 13 and 30
    for i = 3, 5 do
      local index = math.random(13, 27+i)
      visions[i].tooltip = false
      worldDeck = InsertCardInDeck(worldDeck, visions[i], index)
    end
  else
    -- there aren't enough denizens to split the deck. just shuffle it all instead.
    for _, vision in ipairs(visions) do
      local index = math.random(1, worldDeck.getQuantity() + 1)
      vision.tooltip = false
      worldDeck = InsertCardInDeck(worldDeck, vision, index)
    end
  end

end


-- this will perform world deck setup on the 'A Fair Deck' foundation
function OnShuffleUnfairWorldDeck(_, player_color, _)

  -- find and shuffle visions
  local visions = ShuffleTable(FindAllVisions())
  if #visions ~= 5 then
    broadcastToAll("Error: Could not find all 5 visions!")
    return
  end
  
  -- find and shuffle world deck
  local worldDeck = FindWorldDeck()
  if worldDeck == nil then
    broadcastToColor("World deck not found! Is this a new chronicle? click the world deck slot to generate one.", player_color, {r=0.8, g=0, b=0})
    return
  end
  worldDeck.shuffle()

  -- take one vision out and give it to a random player
  local selectedVision = table.remove(visions, #visions)
  local selectedPlayer = Player.getPlayers()[math.random(#Player.getPlayers())]
  selectedVision.deal(1, selectedPlayer.color)

  -- insert visions at random positions according to rules

  if worldDeck.getQuantity() >= 25 then
    -- two visions go in the first 16 slots
    for i = 1, 2 do
      local index = math.random(1, 14+i)
      visions[i].tooltip = false
      worldDeck = InsertCardInDeck(worldDeck, visions[i], index)
    end

    -- two visions go between slots 17 and 32
    for i = 3, 4 do
      local index = math.random(13, 30+i)
      visions[i].tooltip = false
      worldDeck = InsertCardInDeck(worldDeck, visions[i], index)
    end
  else
    -- there aren't enough denizens to split the deck. just shuffle it all instead.
    for _, vision in ipairs(visions) do
      local index = math.random(1, worldDeck.getQuantity() + 1)
      vision.tooltip = false
      worldDeck = InsertCardInDeck(worldDeck, vision, index)
    end
  end
end

