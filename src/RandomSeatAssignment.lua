function onLoad()

end

function onPlayerConnect(player)
  -- player in gamemaster seat so they'll be randomized
  player.changeColor('Black')
end

function onPlayerChangeColor(color)
  if color == 'Black' then
    local player = Player[color]
    -- get a list of available seats
    local unseatedColors = {}
    for _, availableColor in ipairs(Player.getAvailableColors()) do
      if not Player[availableColor].seated then
        if availableColor ~= 'Black' and availableColor ~= 'Grey' then
          table.insert(unseatedColors, availableColor)
        end
      end
    end

    -- move player to a random available seat
    if #unseatedColors > 0 then
      local index = math.random(1, #unseatedColors)
      local newColor = unseatedColors[index]
      player.changeColor(newColor)
    end
  end
end
