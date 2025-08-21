require('src/Utils/ColorUtils')

local bagColorLookup = {
  [Color.fromHex('CD41FF')] = 'Purple',
  [Color.fromHex('F84713')] = 'Red',
  [Color.fromHex('FFE600')] = 'Yellow',
  [Color.fromHex('3F3F3F')] = 'Black',
  [Color.fromHex('36B4E6')] = 'Blue',
  [Color.fromHex('B45D00')] = 'Brown',
  [Color.fromHex('FFFFFF')] = 'White',
  [Color.fromHex('E57BA6')] = 'Pink',
}

local nameToBagColor = {
  ['Purple'] = Color.fromHex('CD41FF'),
  ['Red'] = Color.fromHex('F84713'),
  ['Yellow'] = Color.fromHex('FFE600'),
  ['Black'] = Color.fromHex('3F3F3F'),
  ['Blue'] = Color.fromHex('36B4E6'),
  ['Brown'] = Color.fromHex('B45D00'),
  ['White'] = Color.fromHex('FFFFFF'),
  ['Pink'] = Color.fromHex('E57BA6'),
}

local warbandAssetLookup = {
  ['Purple'] = "https://dl.dropboxusercontent.com/scl/fi/age6wjmfad10gsrdc8oqi/Warband-Purple.png?rlkey=nth3zrj7w37ch9keoqol731ad&dl=0",
  ['Red'] = "https://dl.dropboxusercontent.com/scl/fi/wjjocnvlb9bh505t6wur3/Warband-Red.png?rlkey=qv08yyw9jtk8ysnwuho56yu8y&dl=0",
  ['Yellow'] = "https://dl.dropboxusercontent.com/scl/fi/8je0moel7pkjsqi141d4q/Warband-Yellow.png?rlkey=lzjmugumgp2j7tn1p4bq1ce5l&dl=0",
  ['Black'] = "https://dl.dropboxusercontent.com/scl/fi/6x8nqx1xxtpkadrxjqvh0/Warband-Black.png?rlkey=y8yr9j317dp6yptd5s5ffvzwr&dl=0",
  ['Blue'] = "https://dl.dropboxusercontent.com/scl/fi/xjkj5t4s4m4oq6m95a6l4/Warband-Blue.png?rlkey=gpotyd5meuuzb7y71cwdk7sxa&dl=0",
  ['Brown'] = "https://dl.dropboxusercontent.com/scl/fi/dd2ut6h0hn73axi0wanv9/Warband-Brown.png?rlkey=1390z50o9520m4xevau62bz2d&dl=0",
  ['White'] = "https://dl.dropboxusercontent.com/scl/fi/jshke5j0ldd63wxib5py3/Warband-White.png?rlkey=xp87qwm3jq9tife9sp04jxl8j&dl=0",
  ['Pink'] = "https://dl.dropboxusercontent.com/scl/fi/jpczwrg2s992iii7cee6p/Warband-Pink.png?rlkey=tw5l5bpadh08v0j0vm4loffd9&dl=0",
}

local warbandSpecularIntensityLookup = {
  ['Purple'] = 0,
  ['Red'] = 0,
  ['Yellow'] = 0,
  ['Black'] = 0.025,
  ['Blue'] = 0,
  ['Brown'] = 0,
  ['White'] = 0,
  ['Pink'] = 0,
}

local desiredWarbandCountLookup = {
  ['Purple'] = 24,
  ['Red'] = 14,
  ['Yellow'] = 14,
  ['Black'] = 14,
  ['Blue'] = 14,
  ['Brown'] = 14,
  ['White'] = 14,
  ['Pink'] = 14,
}

function GetWarbandSpawnData()
  local oathColor = GetBestFitOathColor(self.getColorTint())
  local Texture = warbandAssetLookup[oathColor]
  local SpecularIntensity = warbandSpecularIntensityLookup[oathColor]

  return {
    Name = "Custom_Model",
    Transform = {
      posX = 51.9613838,
      posY = 3.56626487,
      posZ = 32.4041443,
      rotX = 0.0145088211,
      rotY = 178.769623,
      rotZ = 0.0126960343,
      scaleX = 1.0,
      scaleY = 1.0,
      scaleZ = 1.0
    },
    Nickname = "Warband",
    Tags = {"Warband"},
    Description = "",
    GMNotes = "",
    AltLookAngle = Vector(0,0,0),
    ColorDiffuse = Color(1,1,1),
    LayoutGroupSortIndex = 0,
    Value = 0,
    Locked = false,
    Grid = true,
    Snap = true,
    IgnoreFoW = false,
    MeasureMovement = false,
    DragSelectable = true,
    Autoraise = true,
    Sticky = true,
    Tooltip = false,
    GridProjection = false,
    HideWhenFaceDown = false,
    Hands = false,
    CustomMesh = {
      MeshURL = "https://steamusercontent-a.akamaihd.net/ugc/28813714123459538/D5ACDDA8E85F34D00FE0657E58B9043B80DDC780/",
      DiffuseURL = Texture,
      NormalURL = "",
      ColliderURL = "",
      Convex = true,
      MaterialIndex = 3,
      TypeIndex = 1,
      CustomShader = {
        SpecularColor = Color(1,1,1),
        SpecularIntensity = SpecularIntensity,
        SpecularSharpness = 2.0,
        FresnelStrength = 0.0
      },
      CastShadows = true
    },
  }
end

function CountWarbandsOnTable()
  local result = 0
  local warbandTexture = warbandAssetLookup[GetBestFitOathColor(self.getColorTint())]
  for _, object in ipairs(getObjectsWithTag("Warband")) do
    local data = object.getData()
    if data.CustomMesh and data.CustomMesh.DiffuseURL == warbandTexture then
      result = result + 1
    end
  end
  return result
end

function BagNeedsRebuild(ContainedObjects, warbandCountOnTable)
  local oathColor = GetBestFitOathColor(self.getColorTint())
  local warbandTexture = warbandAssetLookup[oathColor]
  local desiredWarbandCount = desiredWarbandCountLookup[oathColor]
  if self.getQuantity() + warbandCountOnTable ~= desiredWarbandCount then
    return true
  end

  if ContainedObjects then
    for _, object in ipairs(ContainedObjects) do
      if not object.CustomMesh then
        return true; -- foreign object found
      end
      if object.CustomMesh.DiffuseURL ~= warbandTexture then
        return true;
      end
    end
  end
  return false;
end

function UpdateWarbandCountAndColor()
  local data = self.getData()
  local warbandCountOnTable = CountWarbandsOnTable()
  local oathColor = GetBestFitOathColor(self.getColorTint())
  local desiredWarbandCount = desiredWarbandCountLookup[oathColor]
  
  if BagNeedsRebuild(data.ContainedObjects, warbandCountOnTable) then
    local containedObjects = {}
    local warbandSpawnData = GetWarbandSpawnData()
    for i = 1, desiredWarbandCount - warbandCountOnTable do
      table.insert(containedObjects, warbandSpawnData)
    end
    data.ContainedObjects = containedObjects
    self.destruct()
    spawnObjectData({data = data})
    return true
  end
  return false
end

-- stops a function from being called more than one time per frame
guard = {}
function RepeatGuard(func)
  if not guard[func] then
    guard[func] = true
    Wait.frames(
      function ()
        func()
        guard[func] = nil
      end, 1)
  end
end

function onObjectSpawn(object)
  if object.type == 'Card' then
    local cardData = object.getData()
    local deckID = math.floor(cardData.CardID / 100)
    local cardIndex = cardData.CardID % 100
    local deckInfo = cardData.CustomDeck[deckID]
    -- look for player board assets
    if string.find(deckInfo.FaceURL, "/player.jpg") then
      -- this is an exile or a chancellor
      if (getPlayerMat(object) == getPlayerMat(self)) then
        local assetColors = {"Purple", "Pink", "Red", "Blue", "Black", "White", "Yellow", "Brown"}
        self.setColorTint(nameToBagColor[assetColors[cardIndex + 1]])
      end
    elseif string.find(deckInfo.FaceURL, "/player2.jpg") then
      -- this is a citizen
        if (getPlayerMat(object) == getPlayerMat(self)) then
          self.setColorTint(nameToBagColor['Purple'])
        end
    end
  end
end

function getPlayerMat(object)
  local hits = Physics.cast({
      origin = object.getPosition() +  vector(0,5,0),
      direction = vector(0,-1,0),
      type=1
    })
  for _, info in ipairs(hits) do
    if info.hit_object.getName() == 'PlayerMat' then
      return info.hit_object
    end
  end
  return
end

function onHover(player_color)
  RepeatGuard(UpdateWarbandCountAndColor)
end

