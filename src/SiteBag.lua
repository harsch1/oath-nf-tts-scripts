require("src/Utils/HelperFunctions")
-- The site bag mesh has the site footprint baked in, so the bag and its attached site card
-- both use their natural scale and need no fixing on load
function tryObjectEnter(object)
  return (not self.locked) and (object.hasTag("Card") or object.hasTag("Edifice") or object.hasTag("Relic"))
end
