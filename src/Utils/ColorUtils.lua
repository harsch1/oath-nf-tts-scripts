require('src/Utils/BidirectionalMap')

-- converts to and from oath color strings and rgb colors
local oathColors = BidirectionalMap(
  'Name', 'Color', 
  {
    ['Red'] = Color.fromHex('F84713'),
    ['Yellow'] = Color.fromHex('FFE600'),
    ['Black'] = Color.fromHex('3F3F3F'),
    ['Blue'] = Color.fromHex('36B4E6'),
    ['Brown'] = Color.fromHex('B45D00'),
    ['White'] = Color.fromHex('FFFFFF'),
    ['Pink'] = Color.fromHex('E57BA6'),
    ['Purple'] = Color.fromHex('CD41FF'),
})

-- converts to and from oath player colors, and TTS color names
local TTSColorMap = BidirectionalMap(
  'OathColor', 'TTSColor',
  {
  ['Red'] = 'Red',
  ['Yellow'] = 'Yellow',
  ['Black'] = 'Green', -- black can't be used because it's assigned to the gamemaster
  ['Blue'] = 'Blue',
  ['Brown'] = 'Brown',
  ['White'] = 'White',
  ['Pink'] = 'Pink',
  ['Purple'] = 'Purple',
})

function ColorAsVector(color)
  return Vector(color.r, color.g, color.b)
end

-- given any rgb color, find the closest oath color name
function GetBestFitOathColor(color)
  local shortestDistance = 1000000000
  local foundColor = nil
  local colorVector = ColorAsVector(color)
  for colorName, oathColor in pairs(oathColors.NameToColor) do
    local distance = colorVector:distance(ColorAsVector(oathColor))
    if distance < shortestDistance then
      shortestDistance = distance
      foundColor = colorName
    end
  end
  return foundColor
end

-- given any rgb color, pick a TTS player color for it
function GetBestFitTTSColor(color)
  return TTSColorMap.OathColorToTTSColor[GetBestFitOathColor(color)]
end
