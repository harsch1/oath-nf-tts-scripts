function BidirectionalMap(nameA, nameB, AToB)
  local result = {
    [nameA..'To'..nameB] = AToB,
    [nameB..'To'..nameA] = {},
  }
  for A, B in pairs(AToB) do
    result[nameB..'To'..nameA][B] = A
  end

  return result
end