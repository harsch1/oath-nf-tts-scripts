require("src/Utils/HelperFunctions")
function tryObjectEnter(object)
  return object.hasTag("Card") or object.hasTag("Edifice") or object.hasTag("Relic")
end

function onLoad()
  self.setScale({x=6.97, y=0.03, z=5.39})
end