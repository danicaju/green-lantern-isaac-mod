-- modules/tainted_hearts.lua -- RSI: solo veto de corazones rojos en Tainted Hal. Sin Willpower, sin beam, sin sparks.
-- Responsabilidad unica: impedir contenedores rojos y pickups rojos/oseos. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  if ModCallbacks.MC_POST_PEFFECT_UPDATE then
    GL:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
      if Core.IsTaintedHal(player) then
        Core.EnforceTaintedHalNoRedHearts(player)
      end
    end)
  end

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if Core.IsTaintedHal(player) then
        Core.EnforceTaintedHalNoRedHearts(player)
      end
    end
  end)

  -- Block Tainted Hal from ever picking up red or bone hearts on the ground
  GL:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, pickup, collider, low)
    if pickup.Variant ~= PickupVariant.PICKUP_HEART then return end
    local player = collider and collider:ToPlayer()
    if not player or not Core.IsTaintedHal(player) then return end

    Core.EnforceTaintedHalNoRedHearts(player)

    local sub = pickup.SubType
    local isRedOnlyHeart = (sub == HeartSubType.HEART_FULL)
      or (sub == HeartSubType.HEART_HALF)
      or (sub == HeartSubType.HEART_DOUBLEPACK)
      or (HeartSubType.HEART_SCARED and sub == HeartSubType.HEART_SCARED)
      or (HeartSubType.HEART_ROTTEN and sub == HeartSubType.HEART_ROTTEN)
      or (HeartSubType.HEART_BONE and sub == HeartSubType.HEART_BONE)
      or (HeartSubType.HEART_BLENDED and sub == HeartSubType.HEART_BLENDED)
      or (HeartSubType.HEART_ETERNAL and sub == HeartSubType.HEART_ETERNAL)

    if isRedOnlyHeart then
      return true
    end
  end)
end
