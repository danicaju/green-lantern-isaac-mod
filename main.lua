-- =============================================================================
--  GREEN LANTERN MOD  —  main.lua
--  "In Brightest Day, In Blackest Night..."
--  Characters: Hal Jordan (Green Lantern) | Tainted Hal (Parallax)
--  Items: Power Battery | Construct: Giant Fist | Solid Light Shield
--         The Tragedy of Coast City
--  Trinket: Yellow Impurity
-- =============================================================================

local GL = RegisterMod("GreenLanternMod", 1)

-- ---------------------------------------------------------------------------
-- SECTION 1: CONSTANTS & ID LOOKUPS
-- ---------------------------------------------------------------------------

-- IDs resolved dynamically at runtime
local ITEM_POWER_BATTERY       = nil  -- Active (Hal)
local ITEM_GIANT_FIST          = nil  -- Active 4-room
local ITEM_COAST_CITY          = nil  -- Active 4-room (Tainted Hal)
local ITEM_SOLID_LIGHT_SHIELD  = nil  -- Passive
local ITEM_POWER_RING          = nil  -- Starting Passive (Green Lantern Ring)
local TRINKET_YELLOW_IMPURITY  = nil  -- Trinket

-- Character overlay costumes (keep hair & domino mask on top of picked-up item costumes)
local COSTUME_HAL              = -1
local COSTUME_TAINTED_HAL      = -1

-- Player types
local PLAYER_HAL         = nil  -- Normal Hal Jordan
local PLAYER_TAINTED_HAL = nil  -- Tainted Hal / Parallax

-- Stat modifiers for Hal Jordan
local HAL_SPEED_BONUS         =  0.15  -- slightly above average
local HAL_DAMAGE_MULTIPLIER   =  0.80  -- 20% lower base damage (compensated by flight)
local HAL_SHOT_SPEED_BONUS    =  0.30  -- high shot speed for ring beams

-- Willpower meter constants
local WILLPOWER_MAX            = 100.0
local WILLPOWER_PER_TEAR       =  0.5   -- each tear costs 0.5% willpower

-- Tainted Hal stats
local TAINTED_DMG_MULTIPLIER   = 1.5    -- massive damage multiplier
local TAINTED_TEARS_PENALTY    = -1.5   -- tear delay modifier

-- Emerald Spark constants
local SPARK_MAX           = 100.0
local SPARK_PER_KILL      =  20.0   -- each feared kill gives 20% meter
local SPARK_DISSIPATE_MS  = 5000    -- sparks dissipate after 5 seconds
local SPARK_PICKUP_RANGE  = 60.0    -- pickup radius in world units

-- Coast City construct duration (frames, 30 fps base)
local COAST_CITY_DURATION  = 300  -- 10 seconds

-- ---------------------------------------------------------------------------
-- SECTION 2: PER-PLAYER DATA STORAGE (Entity:GetData())
-- ---------------------------------------------------------------------------

local function GetPlayerData(player)
    local d = player:GetData()
    if not d.GreenLantern then
        d.GreenLantern = {
            -- Hal Jordan
            willpower           = WILLPOWER_MAX,
            ringDepleted        = false,
            overcharge          = false,
            surgeBuff           = false,
            overchargeRoomIdx   = -1,
            oathTextTimer       = 0,
            oathText            = "",

            -- Tainted Hal
            emeraldSparks       = 0.0,
            stolenRings         = 0,
            coastCityActive     = false,
            coastCityFrame      = 0,
            coastCityBoost      = 1.0,

            -- Yellow Impurity
            fearControlTimer    = 0,

            -- Ring combat flare & hand tracking
            ringFlareTimer      = 0,
            lastRingHandOffset  = Vector(14, -8),

            -- Costume & Inspection tracking
            lastCollectibleCount = -1,
            multiShotFrame       = -1,
            multiShotIndex       = 0,
        }
    end
    return d.GreenLantern
end

-- ---------------------------------------------------------------------------
-- SECTION 3: HELPER UTILITIES
-- ---------------------------------------------------------------------------

-- Persistent state for The Tragedy of Coast City 10-second Emerald Vortex
local activeCoastCity = {
    active     = false,
    spawnFrame = 0,
    roomIdx    = -1,
    owner      = nil,
    sparkBonus = 1.0,
}

local stageApiRegistered = false
local function RegisterStageAPIGraphics()
    if stageApiRegistered then return end
    if StageAPI and StageAPI.Loaded and StageAPI.AddPlayerGraphicsInfo then
        if PLAYER_HAL and PLAYER_HAL >= 0 then
            StageAPI.AddPlayerGraphicsInfo(PLAYER_HAL, {
                Portrait    = "gfx/ui/boss/portrait_hal_jordan.png",
                Name        = "gfx/ui/boss/name_hal_jordan.png",
                PortraitBig = "gfx/ui/boss/portrait_hal_jordan.png",
                NoShake     = false,
            })
        end
        if PLAYER_TAINTED_HAL and PLAYER_TAINTED_HAL >= 0 then
            StageAPI.AddPlayerGraphicsInfo(PLAYER_TAINTED_HAL, {
                Portrait    = "gfx/ui/boss/portrait_tainted_hal.png",
                Name        = "gfx/ui/boss/name_tainted_hal.png",
                PortraitBig = "gfx/ui/boss/portrait_tainted_hal.png",
                NoShake     = false,
            })
        end
        stageApiRegistered = true
    end
end

local function LoadItemIDs()
    ITEM_POWER_BATTERY      = Isaac.GetItemIdByName("Power Battery")
    ITEM_GIANT_FIST         = Isaac.GetItemIdByName("Construct: Giant Fist")
    ITEM_COAST_CITY         = Isaac.GetItemIdByName("The Tragedy of Coast City")
    ITEM_SOLID_LIGHT_SHIELD = Isaac.GetItemIdByName("Solid Light Shield")
    ITEM_POWER_RING         = Isaac.GetItemIdByName("Green Lantern Ring")
    TRINKET_YELLOW_IMPURITY = Isaac.GetTrinketIdByName("Yellow Impurity")
    COSTUME_HAL             = Isaac.GetCostumeIdByPath("gfx/characters/hal_costume.anm2")
    COSTUME_TAINTED_HAL     = Isaac.GetCostumeIdByPath("gfx/characters/tainted_hal_costume.anm2")
    PLAYER_HAL              = Isaac.GetPlayerTypeByName("Hal Jordan", false)
    local tHal              = Isaac.GetPlayerTypeByName("Hal Jordan", true)
    if not tHal or tHal < 0 then
        tHal                = Isaac.GetPlayerTypeByName("Tainted Hal", true)
    end
    if not tHal or tHal < 0 then
        tHal                = Isaac.GetPlayerTypeByName("Tainted Hal", false)
    end
    PLAYER_TAINTED_HAL      = tHal
    RegisterStageAPIGraphics()
end

-- Resolve IDs immediately when script loads so callbacks always have valid IDs
LoadItemIDs()

local function IsHalJordan(player)
    if not PLAYER_HAL or PLAYER_HAL < 0 then LoadItemIDs() end
    return PLAYER_HAL and PLAYER_HAL >= 0 and player:GetPlayerType() == PLAYER_HAL
end

local function IsTaintedHal(player)
    if not PLAYER_TAINTED_HAL or PLAYER_TAINTED_HAL < 0 then LoadItemIDs() end
    return PLAYER_TAINTED_HAL and PLAYER_TAINTED_HAL >= 0 and player:GetPlayerType() == PLAYER_TAINTED_HAL
end

local function HasGreenLanternRing(player)
    if IsHalJordan(player) or IsTaintedHal(player) then return true end
    if not ITEM_POWER_RING or ITEM_POWER_RING < 0 then LoadItemIDs() end
    return ITEM_POWER_RING and ITEM_POWER_RING > 0 and player:HasCollectible(ITEM_POWER_RING)
end

-- Compute the world-space position of the character's outstretched Power Ring hand
local function GetRingHandOffset(player, fireVel)
    local headDir = player:GetHeadDirection()
    local dx, dy = 0, 1
    if fireVel and fireVel:Length() > 0.1 then
        local n = fireVel:Normalized()
        dx, dy = n.X, n.Y
    else
        if headDir == Direction.RIGHT then dx, dy = 1, 0
        elseif headDir == Direction.LEFT then dx, dy = -1, 0
        elseif headDir == Direction.UP then dx, dy = 0, -1
        else dx, dy = 0, 1 end
    end

    if math.abs(dx) >= math.abs(dy) then
        if dx >= 0 then
            return Vector(12, -12) -- Outstretched right ring hand
        else
            return Vector(-12, -12) -- Outstretched left ring hand (flipped)
        end
    else
        if dy >= 0 then
            return Vector(9, -10)  -- Outstretched ring hand aiming down
        else
            return Vector(9, -16)  -- Outstretched ring hand aiming up
        end
    end
end

-- Transform a tear into an intense comic-book Green Lantern energy beam originating from the Ring
local function ApplyRingBeamSprite(tear, scaleMult)
    if not tear then return end
    pcall(function()
        local ts = tear:GetSprite()
        ts:Load("gfx/effects/gl_ring_beam.anm2", true)
        ts:Play("Idle", true)
        local angle = tear.Velocity:GetAngleDegrees()
        ts.Rotation = angle
        local s = scaleMult or 1.0
        ts.Scale = Vector(s, s)
        ts.Color = Color(1, 1, 1, 1, 0, 0, 0)
        local td = tear:GetData()
        td.isGLRingBeam = true
        td.glBeamScale  = s
    end)
end

local function RefreshCharacterCostume(player)
    pcall(function()
        if IsHalJordan(player) then
            if not COSTUME_HAL or COSTUME_HAL < 0 then
                COSTUME_HAL = Isaac.GetCostumeIdByPath("gfx/characters/hal_costume.anm2")
            end
            if COSTUME_HAL and COSTUME_HAL >= 0 then
                player:TryRemoveNullCostume(COSTUME_HAL)
                player:AddNullCostume(COSTUME_HAL)
            end
        elseif IsTaintedHal(player) then
            if not COSTUME_TAINTED_HAL or COSTUME_TAINTED_HAL < 0 then
                COSTUME_TAINTED_HAL = Isaac.GetCostumeIdByPath("gfx/characters/tainted_hal_costume.anm2")
            end
            if COSTUME_TAINTED_HAL and COSTUME_TAINTED_HAL >= 0 then
                player:TryRemoveNullCostume(COSTUME_TAINTED_HAL)
                player:AddNullCostume(COSTUME_TAINTED_HAL)
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- SECTION 4: GAME & PLAYER INITIALIZATION
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
    LoadItemIDs()
    activeCoastCity.active = false
end)

GL:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
    LoadItemIDs()

    -- HAL JORDAN INIT
    if IsHalJordan(player) then
        local data = GetPlayerData(player)
        data.willpower         = WILLPOWER_MAX
        data.ringDepleted      = false
        data.overcharge        = false
        data.surgeBuff         = false
        data.overchargeRoomIdx = -1
        RefreshCharacterCostume(player)
    end

    -- TAINTED HAL INIT
    if IsTaintedHal(player) then
        local data = GetPlayerData(player)
        data.emeraldSparks   = 0.0
        data.stolenRings     = 0
        data.coastCityActive = false
        data.coastCityFrame  = 0
        RefreshCharacterCostume(player)
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    local data = GetPlayerData(player)
    if not data.initializedStartingItems then
        data.initializedStartingItems = true
        pcall(function()
            if IsHalJordan(player) then
                if player:GetSoulHearts() < 2 then
                    player:AddSoulHearts(2) -- 1 full soul heart
                end
                -- Grant starting Green Lantern Ring passive equipment + Power Battery active
                if ITEM_POWER_RING and ITEM_POWER_RING > 0 and not player:HasCollectible(ITEM_POWER_RING) then
                    player:AddCollectible(ITEM_POWER_RING, 0, false)
                end
                if ITEM_POWER_BATTERY and ITEM_POWER_BATTERY > 0 and not player:HasCollectible(ITEM_POWER_BATTERY) then
                    player:AddCollectible(ITEM_POWER_BATTERY, 3, false, ActiveSlot.SLOT_PRIMARY)
                end
                RefreshCharacterCostume(player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED)
                player:EvaluateItems()
            elseif IsTaintedHal(player) then
                -- Grant starting Green Lantern Ring passive equipment + The Tragedy of Coast City active
                if ITEM_POWER_RING and ITEM_POWER_RING > 0 and not player:HasCollectible(ITEM_POWER_RING) then
                    player:AddCollectible(ITEM_POWER_RING, 0, false)
                end
                if ITEM_COAST_CITY and ITEM_COAST_CITY > 0 and not player:HasCollectible(ITEM_COAST_CITY) then
                    player:AddCollectible(ITEM_COAST_CITY, 4, false, ActiveSlot.SLOT_PRIMARY)
                end
                RefreshCharacterCostume(player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end)
    end

    -- Keep SpriteOffset at Zero so the body sprite never detaches from or floats into the head costume
    if IsHalJordan(player) or IsTaintedHal(player) then
        player.SpriteOffset = Vector.Zero

        if data.ringFlareTimer and data.ringFlareTimer > 0 then
            data.ringFlareTimer = data.ringFlareTimer - 1
        end
    end

    -- Re-apply character hair/mask/suit overlay whenever the player picks up or swaps an item so costumes merge!
    if IsHalJordan(player) or IsTaintedHal(player) then
        local count = player:GetCollectibleCount()
        local activeId = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
        local queueEmpty = player:IsItemQueueEmpty()

        if data.lastCollectibleCount ~= count
            or data.lastActiveItem ~= activeId
            or (data.wasQueueEmpty == false and queueEmpty == true)
        then
            data.lastCollectibleCount = count
            data.lastActiveItem = activeId
            data.costumeRefreshTimer = 6
            RefreshCharacterCostume(player)
        end
        data.wasQueueEmpty = queueEmpty

        if data.costumeRefreshTimer and data.costumeRefreshTimer > 0 then
            data.costumeRefreshTimer = data.costumeRefreshTimer - 1
            if data.costumeRefreshTimer == 4 or data.costumeRefreshTimer == 0 then
                RefreshCharacterCostume(player)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 5: STAT EVALUATION (MC_EVALUATE_CACHE)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    local data = GetPlayerData(player)
    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- HAL JORDAN STATS
    if IsHalJordan(player) then
        if cacheFlag == CacheFlag.CACHE_SPEED then
            player.MoveSpeed = player.MoveSpeed + HAL_SPEED_BONUS
        end

        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            -- Scale Hal Jordan's damage with current Willpower (0.85x at 0% -> 1.15x near full, +0.10 peak bonus = 1.25x at 100%)
            local will = data.willpower or WILLPOWER_MAX
            local willRatio = math.max(0.0, math.min(1.0, will / WILLPOWER_MAX))
            local willMult = 0.85 + (0.30 * willRatio)
            if will >= 99.5 then
                willMult = willMult + 0.10 -- 1.25x DMG at 100% Willpower!
            end
            player.Damage = player.Damage * willMult

            -- Ring depleted: 50% damage penalty
            if data.ringDepleted then
                player.Damage = player.Damage * 0.5
            end
        end

        if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
            player.ShotSpeed = player.ShotSpeed + HAL_SHOT_SPEED_BONUS
        end

        if cacheFlag == CacheFlag.CACHE_FLYING then
            if not data.ringDepleted then
                player.CanFly = true
            end
        end

        if cacheFlag == CacheFlag.CACHE_TEARFLAG then
            if not data.ringDepleted then
                -- All Green Lantern Ring energy beams pass through enemies and obstacles!
                player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            end
        end
    end

    -- TAINTED HAL STATS
    if IsTaintedHal(player) then
        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            -- Base 1.5x multiplier + up to +50% more damage as Emerald Sparks reach 100% (MAX +50%)
            local sparkRatio = math.max(0.0, math.min(1.0, (data.emeraldSparks or 0.0) / SPARK_MAX))
            local sparkMult = 1.0 + (0.50 * sparkRatio)
            if data.coastCityActive and activeCoastCity.active and activeCoastCity.roomIdx == roomIdx then
                sparkMult = math.max(sparkMult, data.coastCityBoost or 1.0)
            end
            player.Damage = player.Damage * TAINTED_DMG_MULTIPLIER * sparkMult
        end

        if cacheFlag == CacheFlag.CACHE_FIREDELAY then
            player.MaxFireDelay = math.max(player.MaxFireDelay + math.abs(TAINTED_TEARS_PENALTY) * 3, 6)
        end

        if cacheFlag == CacheFlag.CACHE_FLYING then
            player.CanFly = true
        end

        if cacheFlag == CacheFlag.CACHE_TEARFLAG then
            player.TearFlags = player.TearFlags | TearFlags.TEAR_FEAR | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        end
    end

    -- POWER BATTERY OVERCHARGE / SURGE (applies to Hal Jordan or any character who activates Power Battery)
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        if data.overcharge and data.overchargeRoomIdx == roomIdx then
            player.Damage = player.Damage * 2.0
        elseif data.surgeBuff and data.overchargeRoomIdx == roomIdx then
            player.Damage = player.Damage * 1.5
        end
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        if (data.overcharge or data.surgeBuff) and data.overchargeRoomIdx == roomIdx then
            player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        end
    end

    -- GREEN LANTERN RING (when picked up by non-Hal characters, grants +1.0 DMG, +0.20 ShotSpeed, Piercing & Spectral)
    if not IsHalJordan(player) and not IsTaintedHal(player) and HasGreenLanternRing(player) then
        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + 1.0
        elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
            player.ShotSpeed = player.ShotSpeed + 0.20
        elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
            player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        end
    end

    -- TRINKET: YELLOW IMPURITY DAMAGE BUFF
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        if TRINKET_YELLOW_IMPURITY and player:HasTrinket(TRINKET_YELLOW_IMPURITY) then
            player.Damage = player.Damage * 1.5
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 6: GREEN LANTERN RING BEAM HANDLING (Hand origin + Piercing + Spectral)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
    local spawner = tear.SpawnerEntity
    if not spawner then return end
    local player = spawner:ToPlayer()
    if not player then return end

    if not HasGreenLanternRing(player) then return end

    local data = GetPlayerData(player)
    local frame = Game():GetFrameCount()

    -- Multi-shot fan offset (20/20, Inner Eye, Mutant Spider, Monstro's Lung, Conjoined)
    if data.multiShotFrame == frame then
        data.multiShotIndex = (data.multiShotIndex or 0) + 1
    else
        data.multiShotFrame = frame
        data.multiShotIndex = 0
    end

    -- 1. Snap projectile spawn position to the outstretched Power Ring hand (never from the eyes!)
    local handOffset = GetRingHandOffset(player, tear.Velocity)
    local perpOffset = Vector.Zero
    if data.multiShotIndex > 0 and tear.Velocity:Length() > 0.1 then
        local dir = tear.Velocity:Normalized()
        local perp = Vector(-dir.Y, dir.X)
        local side = (data.multiShotIndex % 2 == 1) and 1 or -1
        local tier = math.ceil(data.multiShotIndex / 2)
        perpOffset = perp * (side * math.min(tier * 5.5, 14.0))
    end

    tear.Position = player.Position + handOffset + perpOffset
    data.lastRingHandOffset = handOffset
    data.ringFlareTimer     = 6

    -- Grant ONLY Piercing (pass through enemies) + Spectral (pass through rocks/objects)
    if not (IsHalJordan(player) and data.ringDepleted) then
        tear.TearFlags = tear.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
    end
    if IsTaintedHal(player) then
        tear.TearFlags = tear.TearFlags | TearFlags.TEAR_FEAR
    end

    -- Synergy scale adjustments (Chocolate Milk, Monstro's Lung, Ipecac, Haemolacria, Soy/Almond Milk)
    local sizeFactor = math.max(0.65, math.min(1.85, tear.Scale or 1.0))

    -- 2. HAL JORDAN WILLPOWER & BEAM SCALING
    if IsHalJordan(player) then
        if data.ringDepleted then
            -- Limited range when depleted: weak sputtering spark near the ring hand
            tear.Velocity = tear.Velocity * 0.18
            ApplyRingBeamSprite(tear, 0.55)
        else
            local baseScale = data.overcharge and 1.35 or (data.surgeBuff and 1.18 or 1.0)
            ApplyRingBeamSprite(tear, baseScale * math.sqrt(sizeFactor))

            -- Scale willpower drain for multi-shot / lung / soy milk so rapid/volley synergies feel great
            local drain = WILLPOWER_PER_TEAR
            if data.multiShotIndex > 0 then
                drain = drain * 0.25 -- Multi-shot / Monstro's Lung extra beams cost 75% less willpower
            end
            if CollectibleType.COLLECTIBLE_SOY_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_SOY_MILK) then
                drain = drain * 0.20
            elseif CollectibleType.COLLECTIBLE_ALMOND_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) then
                drain = drain * 0.25
            end

            local prevWillBucket = math.floor((data.willpower or WILLPOWER_MAX) + 0.5)
            data.willpower = math.max(0, data.willpower - drain)
            local newWillBucket = math.floor(data.willpower + 0.5)

            if data.willpower <= 0 then
                data.ringDepleted = true
                data.willpower = 0
                player:AnimateSad()
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector.Zero, player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            elseif newWillBucket ~= prevWillBucket then
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                player:EvaluateItems()
            end
        end
    elseif IsTaintedHal(player) then
        -- 3. TAINTED HAL (PARALLAX): Larger, heavy emerald construct energy blast from the ring
        tear.Scale = tear.Scale * 1.35
        ApplyRingBeamSprite(tear, 1.28 * math.sqrt(sizeFactor))
    else
        -- Any other character holding Green Lantern Ring
        ApplyRingBeamSprite(tear, 1.05 * math.sqrt(sizeFactor))
    end
end)

-- Keep all Green Lantern Ring energy beams oriented along their exact flight velocity vector
GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
    local td = tear:GetData()
    if not td then return end

    if td.isGLRingBeam and tear.Velocity:Length() > 0.1 then
        local ts = tear:GetSprite()
        ts.Rotation = tear.Velocity:GetAngleDegrees()
    end
end)

-- Spawn a crisp emerald energy flash when a piercing Ring Beam slices through an enemy
GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
    local td = tear:GetData()
    if not (td and td.isGLRingBeam) then return end
    if not (collider and collider:IsActiveEnemy(false) and collider:IsVulnerableEnemy()) then return end

    local frame = Game():GetFrameCount()
    if not td.lastPierceFlashFrame or (frame - td.lastPierceFlashFrame) >= 5 then
        td.lastPierceFlashFrame = frame
        local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, collider.Position, Vector.Zero, tear)
        if fx then
            fx.Scale = 0.70
            fx:GetSprite().Color = Color(0.1, 1.0, 0.35, 0.9, 0.15, 0.85, 0.25)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 6B: GREEN LANTERN RING ITEM SYNERGIES (Tint + Piercing/Spectral Only)
-- ---------------------------------------------------------------------------

-- 1. LASER SYNERGIES: Brimstone, Tech X, Technology, Technology 2, Tech.5, Jacob's Ladder
GL:AddCallback(ModCallbacks.MC_POST_LASER_INIT, function(_, laser)
    local spawner = laser.SpawnerEntity
    local player = spawner and spawner:ToPlayer()
    if not player or not HasGreenLanternRing(player) then return end

    local ld = laser:GetData()
    if ld.glLaserSynergyInit then return end
    ld.glLaserSynergyInit = true

    local data = GetPlayerData(player)
    data.ringFlareTimer = 8

    -- Tint all player lasers into blazing Hard-Light Emerald Construct Beams!
    laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
    laser.CollisionDamage = laser.CollisionDamage * 1.25
    laser.TearFlags = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
    if IsTaintedHal(player) then
        laser.TearFlags = laser.TearFlags | TearFlags.TEAR_FEAR
    end

    -- Hal Jordan Willpower management for laser weapons
    if IsHalJordan(player) and not data.ringDepleted then
        local frame = Game():GetFrameCount()
        if data.lastLaserDrainFrame ~= frame then
            data.lastLaserDrainFrame = frame
            local prevWillBucket = math.floor((data.willpower or WILLPOWER_MAX) + 0.5)
            data.willpower = math.max(0, data.willpower - 1.2)
            local newWillBucket = math.floor(data.willpower + 0.5)
            if data.willpower <= 0 then
                data.ringDepleted = true
                data.willpower = 0
                player:AnimateSad()
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            elseif newWillBucket ~= prevWillBucket then
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                player:EvaluateItems()
            end
        end
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, function(_, laser)
    local spawner = laser.SpawnerEntity
    local player = spawner and spawner:ToPlayer()
    if not player or not HasGreenLanternRing(player) then return end

    local data = GetPlayerData(player)
    data.ringFlareTimer = 4
    laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
end)

-- 2. MOM'S KNIFE SYNERGY: Hard-Light Emerald Energy Blade
GL:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, knife)
    local spawner = knife.SpawnerEntity
    local player = spawner and spawner:ToPlayer()
    if not player or not HasGreenLanternRing(player) then return end

    knife:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.10, 0.85, 0.25)
    if knife:IsFlying() then
        local data = GetPlayerData(player)
        data.ringFlareTimer = 5
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 7: ACTIVE ITEMS (Power Battery, Giant Fist, Coast City)
-- ---------------------------------------------------------------------------

-- Power Battery
GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not ITEM_POWER_BATTERY or ITEM_POWER_BATTERY < 0 then LoadItemIDs() end
    if itemID ~= ITEM_POWER_BATTERY then return end

    local data = GetPlayerData(player)
    local prevWill = data.willpower or WILLPOWER_MAX
    local wasDepleted = data.ringDepleted

    -- 1. Always refill Willpower to 100% and restore ring power
    data.willpower         = WILLPOWER_MAX
    data.ringDepleted      = false
    data.overchargeRoomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- 2. If used at >= 50% Willpower (and not depleted), grant FULL OVERCHARGE (2.0x DMG + Piercing + Spectral).
    --    Otherwise, grant CONSTRUCT SURGE (1.5x DMG + Piercing + Spectral) so using Power Battery is ALWAYS powerful!
    if not wasDepleted and prevWill >= 50.0 then
        data.overcharge = true
        data.surgeBuff  = false
        data.oathTextTimer = 120
        data.oathText = "OVERCHARGE! (2x DMG)"
    else
        data.overcharge = false
        data.surgeBuff  = true
        data.oathTextTimer = 120
        data.oathText = "WILLPOWER SURGE! (1.5x DMG)"
    end

    -- 3. Visual & audio emerald burst around the player
    local burstFx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector.Zero, player)
    if burstFx then
        burstFx.Scale = 2.2
        burstFx:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.8, 0)
    end
    pcall(function()
        SFXManager():Play(SoundEffect.SOUND_SUPERHOLY, 1.0, 0, false, 1.0)
    end)

    -- 4. Shockwave: damage & knockback nearby enemies and clear nearby enemy projectiles
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        local dist = (ent.Position - player.Position):Length()
        if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() and dist <= 160 then
            ent:TakeDamage(player.Damage * 3.5 + 10.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
            local push = (ent.Position - player.Position)
            if push:Length() > 0.1 then
                ent.Velocity = ent.Velocity + push:Normalized() * 14.0
            end
        elseif ent.Type == EntityType.ENTITY_PROJECTILE and dist <= 180 then
            ent:Die()
        end
    end

    player:AnimateHappy()
    player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
    player:EvaluateItems()

    return true
end)

-- Construct: Giant Fist
GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not ITEM_GIANT_FIST or ITEM_GIANT_FIST < 0 then LoadItemIDs() end
    if itemID ~= ITEM_GIANT_FIST then return end

    local direction = player:GetShootingInput()
    if direction:Length() < 0.01 then
        local headDir = player:GetHeadDirection()
        local headVecs = {
            [Direction.LEFT]  = Vector(-1,  0),
            [Direction.RIGHT] = Vector( 1,  0),
            [Direction.UP]    = Vector( 0, -1),
            [Direction.DOWN]  = Vector( 0,  1),
        }
        direction = headVecs[headDir] or Vector(1, 0)
    else
        direction = direction:Normalized()
    end

    local handOffset = GetRingHandOffset(player, direction)
    local fistVelocity = direction * 20.0
    local tearVar = (TearVariant and TearVariant.TOOTH) or 0
    local ent = Isaac.Spawn(
        EntityType.ENTITY_TEAR,
        tearVar,
        0,
        player.Position + handOffset + direction * 10,
        fistVelocity,
        player
    )
    local fist = ent and ent:ToTear()

    if fist then
        fist.CollisionDamage = player.Damage * 10
        fist.Scale           = 3.5
        fist.TearFlags       = fist.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING | TearFlags.TEAR_MEGA
        fist:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
        fist:GetData().isGiantFist = true
    end

    return true
end)

-- Giant Fist rock destruction
GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for _, tear in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false)) do
        local td = tear:GetData()
        if td and td.isGiantFist then
            local room = Game():GetRoom()
            local gridIdx = room:GetGridIndex(tear.Position)
            if gridIdx >= 0 then
                local gridEntity = room:GetGridEntity(gridIdx)
                if gridEntity then
                    local gtype = gridEntity:GetType()
                    if gtype == GridEntityType.GRID_ROCK
                    or gtype == GridEntityType.GRID_ROCKB
                    or gtype == GridEntityType.GRID_ROCKT
                    or gtype == GridEntityType.GRID_ROCK_BOMB
                    or gtype == GridEntityType.GRID_ROCK_ALT
                    or gtype == GridEntityType.GRID_POOP then
                        gridEntity:Destroy(false)
                    end
                end
            end
        end
    end
end)

-- The Tragedy of Coast City
GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not ITEM_COAST_CITY or ITEM_COAST_CITY < 0 then LoadItemIDs() end
    if itemID ~= ITEM_COAST_CITY then return end

    local data = GetPlayerData(player)

    -- Stored Emerald Sparks boost vortex & player damage up to +50% (never blocks activation!)
    local sparkBonus = 1.0 + ((data.emeraldSparks or 0.0) / SPARK_MAX) * 0.5
    data.coastCityBoost  = sparkBonus
    data.emeraldSparks   = 0.0
    data.coastCityActive = true
    data.coastCityFrame  = Game():GetFrameCount()

    local room    = Game():GetRoom()
    local center  = room:GetCenterPos()
    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- Store 10-second vortex state in persistent Lua table so it lasts the full 300 frames!
    activeCoastCity.active     = true
    activeCoastCity.spawnFrame = Game():GetFrameCount()
    activeCoastCity.roomIdx    = roomIdx
    activeCoastCity.owner      = player
    activeCoastCity.sparkBonus = sparkBonus

    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    player:EvaluateItems()

    pcall(function()
        SFXManager():Play(SoundEffect.SOUND_SUPERHOLY, 1.0, 0, false, 0.85)
    end)

    -- Immediately inflict Fear AND deal an initial Emerald Cataclysm blast + beam to ALL enemies in the room!
    local beamCount = 0
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            ent:AddFear(EntityRef(player), 240)
            ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
            ent:TakeDamage(player.Damage * 3.0 * sparkBonus + 12.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
            if beamCount < 6 then
                beamCount = beamCount + 1
                local eBeam = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, ent.Position, Vector.Zero, player)
                if eBeam then
                    eBeam.Scale = 2.0
                    eBeam:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.8, 0)
                end
            end
        end
    end

    -- Spawn central Emerald Vortex beam & shockwave
    local construct = Isaac.Spawn(
        EntityType.ENTITY_EFFECT,
        EffectVariant.CRACK_THE_SKY,
        0,
        center,
        Vector.Zero,
        player
    )
    if construct then
        construct.Scale = 3.5
        construct:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 1, 0)
    end

    local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, center, Vector.Zero, player)
    if poof then
        poof.Scale = 2.5
        poof:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.8, 0)
    end

    player:AnimateHappy()
    return true
end)

-- Coast City logic: pull ALL vulnerable enemies toward center vortex & deal continuous emerald DPS for 10 seconds (300 frames)
GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    if not activeCoastCity.active then return end

    local currentFrame = Game():GetFrameCount()
    local roomIdx      = Game():GetLevel():GetCurrentRoomIndex()
    local age          = currentFrame - (activeCoastCity.spawnFrame or currentFrame)

    if roomIdx ~= activeCoastCity.roomIdx or age > COAST_CITY_DURATION then
        activeCoastCity.active = false
        for i = 0, Game():GetNumPlayers() - 1 do
            local p = Isaac.GetPlayer(i)
            if IsTaintedHal(p) then
                GetPlayerData(p).coastCityActive = false
                p:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                p:EvaluateItems()
            end
        end
        return
    end

    local room        = Game():GetRoom()
    local center      = room:GetCenterPos()
    local ownerPlayer = activeCoastCity.owner or Isaac.GetPlayer(0)
    local sparkBonus  = activeCoastCity.sparkBonus or 1.0

    -- Pulse a visible emerald vortex effect at the center of the room every 15 frames
    if age % 15 == 0 then
        local pulse = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, center, Vector.Zero, ownerPlayer)
        if pulse then
            pulse.Scale = 1.7
            pulse:GetSprite().Color = Color(0, 1, 0.3, 0.85, 0, 0.7, 0)
        end
    end
    if age % 30 == 0 then
        local sky = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, center, Vector.Zero, ownerPlayer)
        if sky then
            sky.Scale = 2.4
            sky:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.9, 0)
        end
    end

    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
        if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
            local isFeared = enemy:HasEntityFlags(EntityFlag.FLAG_FEAR)
            local toCenter = (center - enemy.Position)
            local dist     = toCenter:Length()

            -- Pull ALL vulnerable enemies toward the vortex (Feared enemies pull even faster)
            if dist > 16 then
                local pullMult = isFeared and 1.35 or 1.0
                local pullStr  = math.min(8.5, 280.0 / math.max(dist, 15)) * pullMult
                enemy.Velocity = enemy.Velocity * 0.78 + toCenter:Normalized() * pullStr
            end

            -- Deal pulsing Emerald Vortex damage every 12 frames across the room
            if age % 12 == 0 and ownerPlayer then
                enemy:AddFear(EntityRef(ownerPlayer), 90)
                enemy:AddEntityFlags(EntityFlag.FLAG_FEAR)
                local fearMult = isFeared and 1.35 or 1.1
                local distMult = (dist <= 120) and 2.2 or 1.1
                local dmg = ownerPlayer.Damage * distMult * fearMult * sparkBonus
                enemy:TakeDamage(dmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(ownerPlayer), 0)

                if dist <= 130 and math.random() < 0.40 then
                    local spark = Isaac.Spawn(
                        EntityType.ENTITY_PICKUP,
                        PickupVariant.PICKUP_COIN,
                        CoinSubType.COIN_PENNY,
                        enemy.Position + Vector(math.random(-15, 15), math.random(-15, 15)),
                        Vector.Zero,
                        ownerPlayer
                    )
                    if spark then
                        spark:GetData().isEmeraldSpark = true
                        spark:GetData().spawnFrame     = currentFrame
                        spark:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 8: SOLID LIGHT SHIELD (Passive damage reflection)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
    if entity.Type ~= EntityType.ENTITY_PLAYER then return end
    local player = entity:ToPlayer()
    if not player then return end
    if not ITEM_SOLID_LIGHT_SHIELD or ITEM_SOLID_LIGHT_SHIELD < 0 then LoadItemIDs() end
    if not (ITEM_SOLID_LIGHT_SHIELD and ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(ITEM_SOLID_LIGHT_SHIELD)) then return end

    if source and source.Entity and source.Entity.Type == EntityType.ENTITY_TEAR then
        local srcEnt  = source.Entity
        local luck    = player.Luck
        local chance  = math.min(0.25 + luck * 0.05, 0.75)

        if math.random() < chance then
            local reflectVel = (player.Position - srcEnt.Position):Normalized() * (-srcEnt.Velocity:Length())
            local tearVar    = (TearVariant and TearVariant.BLUE) or 0
            local ent        = Isaac.Spawn(
                EntityType.ENTITY_TEAR,
                tearVar,
                0,
                srcEnt.Position,
                reflectVel,
                player
            )
            local reflected  = ent and ent:ToTear()

            if reflected then
                reflected.CollisionDamage = player.Damage
                reflected.TearFlags       = reflected.TearFlags | TearFlags.TEAR_SPECTRAL
                reflected:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.5, 0)
            end

            return false -- Block damage
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 9: YELLOW IMPURITY TRINKET (Fear on damage & control confusion)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
    if entity.Type ~= EntityType.ENTITY_PLAYER then return end
    local player = entity:ToPlayer()
    if not player then return end
    if not (TRINKET_YELLOW_IMPURITY and player:HasTrinket(TRINKET_YELLOW_IMPURITY)) then return end

    local isContact   = (flags & DamageFlag.DAMAGE_CRUSH) ~= 0 or (flags & DamageFlag.DAMAGE_NOKILL) == 0
    local isExplosion = (flags & DamageFlag.DAMAGE_EXPLOSION) ~= 0

    if isContact or isExplosion then
        local data = GetPlayerData(player)
        data.fearControlTimer = 60
        player:AddEntityFlags(EntityFlag.FLAG_FEAR)
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player and TRINKET_YELLOW_IMPURITY and player:HasTrinket(TRINKET_YELLOW_IMPURITY) then
            local data = GetPlayerData(player)
            if data.fearControlTimer and data.fearControlTimer > 0 then
                data.fearControlTimer = data.fearControlTimer - 1
                player.Velocity = player.Velocity * -1

                if data.fearControlTimer <= 0 then
                    player:ClearEntityFlags(EntityFlag.FLAG_FEAR)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 10: TAINTED HAL — RED HEART CONVERSION (Flies)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, function(_, pickup)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsTaintedHal(player) then
            local isRedHeart = pickup.Variant == PickupVariant.PICKUP_HEART
                and (pickup.SubType == HeartSubType.HEART_FULL
                  or pickup.SubType == HeartSubType.HEART_HALF
                  or pickup.SubType == HeartSubType.HEART_DOUBLEPACK)

            if isRedHeart then
                local locust = Isaac.Spawn(
                    EntityType.ENTITY_FAMILIAR,
                    FamiliarVariant.ATTACK_FLY,
                    0,
                    pickup.Position,
                    Vector.Zero,
                    player
                )
                if locust then
                    locust:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
                end
                pickup:Remove()
                break
            end
        end
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsTaintedHal(player) then
            local redHearts = player:GetHearts()
            if redHearts > 0 then
                player:AddHearts(-redHearts)
                player:AddBlackHearts(redHearts)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 11: TAINTED HAL — EMERALD SPARK SYSTEM
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, function(_, entity)
    if not entity:IsEnemy() then return end

    local hasTaintedHal = false
    for i = 0, Game():GetNumPlayers() - 1 do
        if IsTaintedHal(Isaac.GetPlayer(i)) then
            hasTaintedHal = true
            break
        end
    end
    if not hasTaintedHal then return end

    -- Always drop an Emerald Spark from Feared enemies, or 40% chance from any enemy killed by Tainted Hal
    if entity:HasEntityFlags(EntityFlag.FLAG_FEAR) or math.random() < 0.40 then
        local spark = Isaac.Spawn(
            EntityType.ENTITY_PICKUP,
            PickupVariant.PICKUP_COIN,
            CoinSubType.COIN_PENNY,
            entity.Position,
            Vector.Zero,
            nil
        )
        if spark then
            local sd = spark:GetData()
            sd.isEmeraldSpark = true
            sd.spawnFrame     = Game():GetFrameCount()
            spark:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
        end
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    local currentFrame = Game():GetFrameCount()

    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsTaintedHal(player) then
            local data = GetPlayerData(player)

            for _, ent in ipairs(Isaac.FindInRadius(player.Position, SPARK_PICKUP_RANGE, EntityPartition.PICKUP)) do
                local ed = ent:GetData()
                if ed and ed.isEmeraldSpark then
                    local age = (currentFrame - (ed.spawnFrame or currentFrame)) * (1/30)
                    if age * 1000 > SPARK_DISSIPATE_MS then
                        ent:Remove()
                    else
                        data.emeraldSparks = math.min(SPARK_MAX, data.emeraldSparks + SPARK_PER_KILL)
                        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                        player:EvaluateItems()
                        -- Also grant +1 charge to Coast City active item when picking up sparks!
                        pcall(function()
                            if player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == ITEM_COAST_CITY then
                                local curCharge = player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY)
                                if curCharge < 4 then
                                    player:SetActiveCharge(math.min(4, curCharge + 1), ActiveSlot.SLOT_PRIMARY)
                                end
                            end
                        end)
                        ent:Remove()
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 12: TAINTED HAL — STOLEN RING (Angel Room)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    local room = Game():GetRoom()
    if room:GetType() ~= RoomType.ROOM_ANGEL then return end

    local hasTaintedHal = false
    for i = 0, Game():GetNumPlayers() - 1 do
        if IsTaintedHal(Isaac.GetPlayer(i)) then
            hasTaintedHal = true
            break
        end
    end
    if not hasTaintedHal then return end

    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false)) do
        ent:GetData().canBeConsumedByHal = true
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsTaintedHal(player) then
            local isUsing = Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex)
            if isUsing then
                for _, ent in ipairs(Isaac.FindInRadius(player.Position, 50, EntityPartition.PICKUP)) do
                    local ed = ent:GetData()
                    if ed and ed.canBeConsumedByHal then
                        local data = GetPlayerData(player)
                        data.stolenRings = data.stolenRings + 1

                        local ring = Isaac.Spawn(
                            EntityType.ENTITY_FAMILIAR,
                            FamiliarVariant.BLUE_FLY,
                            0,
                            player.Position,
                            Vector.Zero,
                            player
                        ):ToFamiliar()

                        if ring then
                            local rd = ring:GetData()
                            rd.isStolenRing = true
                            rd.ringIndex    = data.stolenRings
                            ring:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
                        end

                        ent:Remove()
                        player:AnimateHappy()
                        break
                    end
                end
            end
        end
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    local currentFrame = Game():GetFrameCount()

    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false)) do
        local fd = familiar:GetData()
        if fd and fd.isStolenRing then
            local owner = familiar.SpawnerEntity
            local player = owner and owner:ToPlayer()
            if player then
                local ringIdx   = fd.ringIndex or 1
                local orbitRad  = 40 + (ringIdx - 1) * 20
                local speed     = 0.12
                local angle     = currentFrame * speed + (ringIdx * math.pi / 2)
                local targetPos = player.Position + Vector(math.cos(angle) * orbitRad, math.sin(angle) * orbitRad)

                familiar.Position = targetPos
                familiar.Velocity = Vector.Zero
                familiar.Scale    = 1.3

                if currentFrame % 25 == (ringIdx * 5) % 25 then
                    local targetEnemy = nil
                    local nearestDist = 400

                    -- Prioritize Feared enemies, fallback to any vulnerable enemy
                    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
                        if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
                            local dist = (enemy.Position - familiar.Position):Length()
                            local effectiveDist = enemy:HasEntityFlags(EntityFlag.FLAG_FEAR) and (dist * 0.5) or dist
                            if effectiveDist < nearestDist then
                                nearestDist = effectiveDist
                                targetEnemy = enemy
                            end
                        end
                    end

                    if targetEnemy then
                        local dir      = (targetEnemy.Position - familiar.Position):Normalized()
                        local laserVel = dir * 18
                        local tearVar  = (TearVariant and TearVariant.BLUE) or 0
                        local ent      = Isaac.Spawn(
                            EntityType.ENTITY_TEAR,
                            tearVar,
                            0,
                            familiar.Position,
                            laserVel,
                            player
                        )
                        local laser    = ent and ent:ToTear()

                        if laser then
                            laser.CollisionDamage = player.Damage * 1.5
                            laser.TearFlags       = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
                            laser:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
                        end
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 13: FLOOR BATTERY COLLECTION (Refill Willpower)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, pickup, collider, low)
    if pickup.Variant ~= PickupVariant.PICKUP_LIL_BATTERY then return end

    local player = collider:ToPlayer()
    if not player or not IsHalJordan(player) then return end

    local data = GetPlayerData(player)

    -- Refill amount based on subtype (1=normal, 2=micro, 3=mega, 4=golden)
    local refillAmount = 50.0
    if pickup.SubType == 3 or pickup.SubType == 4 then
        refillAmount = 100.0
    elseif pickup.SubType == 2 then
        refillAmount = 25.0
    end

    data.willpower    = math.min(WILLPOWER_MAX, data.willpower + refillAmount)
    data.ringDepleted = (data.willpower <= 0)

    player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
    player:EvaluateItems()
end)

-- ---------------------------------------------------------------------------
-- SECTION 14: OVERCHARGE / SURGE / COAST CITY RESET ON NEW ROOM
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    activeCoastCity.active = false
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsHalJordan(player) or IsTaintedHal(player) then
            RefreshCharacterCostume(player)
        end
        local data = GetPlayerData(player)
        local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
        local needsEval = false
        if (data.overcharge or data.surgeBuff) and data.overchargeRoomIdx ~= roomIdx then
            data.overcharge = false
            data.surgeBuff  = false
            needsEval = true
        end
        if data.coastCityActive then
            data.coastCityActive = false
            needsEval = true
        end
        if needsEval then
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
            player:EvaluateItems()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 15: HUD RENDERING, AURA EFFECTS & ITEM INSPECTION DESCRIPTIONS
-- ---------------------------------------------------------------------------

local hudFont = nil
local function GetHudFont()
    if not hudFont and Font then
        local f = Font()
        local ok = pcall(function() f:Load("font/luaminioutlined.fnt") end)
        if ok and f:IsLoaded() then
            hudFont = f
        end
    end
    return hudFont
end

local function DrawHudText(text, x, y, r, g, b, a)
    local f = GetHudFont()
    if f and KColor then
        f:DrawStringScaled(text, x, y, 1.0, 1.0, KColor(r, g, b, a), 0, false)
    else
        Isaac.RenderScaledText(text, x, y, 0.5, 0.5, r, g, b, a)
    end
end

local eidRegistered = false
local function EnsureEIDRegistered()
    if eidRegistered or not EID then return end
    LoadItemIDs()
    if not ITEM_POWER_BATTERY or ITEM_POWER_BATTERY < 0 then return end
    pcall(function()
        for _, lang in ipairs({"en_us", "en_us_detailed", "es"}) do
            EID:addCollectible(ITEM_POWER_BATTERY,
                "Refills Willpower to 100% and unleashes a 3.5x AoE shockwave + knockback#At >=50% Willpower: Overcharge (2x DMG + Piercing + Spectral for the room)#Below 50%: 1.5x DMG Surge + Piercing + Spectral for the room",
                "Power Battery", lang)
            EID:addCollectible(ITEM_GIANT_FIST,
                "Fires a massive spectral piercing emerald fist#Deals 10x Player Damage and smashes rocks & obstacles",
                "Construct: Giant Fist", lang)
            EID:addCollectible(ITEM_COAST_CITY,
                "Fears and blasts all enemies in the room (3x DMG), then spawns a 10s Emerald Vortex#Pulls all enemies toward the center and deals continuous heavy AoE DPS#Stored Emerald Sparks boost player & vortex damage up to +50%",
                "The Tragedy of Coast City", lang)
            EID:addCollectible(ITEM_SOLID_LIGHT_SHIELD,
                "+2 Soul Hearts#Grants an orbital shield that blocks shots#25%-75% chance (scales with Luck) to reflect enemy projectiles as spectral beams",
                "Solid Light Shield", lang)
            if ITEM_POWER_RING and ITEM_POWER_RING > 0 then
                EID:addCollectible(ITEM_POWER_RING,
                    "Signature Green Lantern Power Ring worn on your hand#Projects piercing & spectral emerald construct energy bolts directly from the ring#Bolts pass cleanly through enemies and rocks/obstacles",
                    "Green Lantern Ring", lang)
            end
            if TRINKET_YELLOW_IMPURITY and TRINKET_YELLOW_IMPURITY > 0 then
                EID:addTrinket(TRINKET_YELLOW_IMPURITY,
                    "1.5x Damage multiplier (+50% DMG)#Taking contact or explosion damage briefly inflicts Fear (reversed movement for 2s)",
                    "Yellow Impurity", lang)
            end
        end
        eidRegistered = true
    end)
end

local function GetModItemInspectionInfo(isTrinket, id)
    if not ITEM_POWER_BATTERY or ITEM_POWER_BATTERY < 0 then LoadItemIDs() end
    if not isTrinket then
        if id == ITEM_POWER_BATTERY then
            return "Power Battery [3R Active]", {
                "100% Willpower + AoE emerald shockwave",
                ">=50% Will: 2x DMG | <50%: 1.5x DMG for room"
            }
        elseif id == ITEM_GIANT_FIST then
            return "Construct: Giant Fist [4R Active]", {
                "Fires a giant piercing 10x DMG emerald fist",
                "Smashes rocks, poop, and obstacles in its path"
            }
        elseif id == ITEM_COAST_CITY then
            return "The Tragedy of Coast City [4R Active]", {
                "Fears & blasts all enemies + 10s Emerald Vortex",
                "Sparks grant up to +50% Damage & Vortex boost"
            }
        elseif id == ITEM_SOLID_LIGHT_SHIELD then
            return "Solid Light Shield [Passive]", {
                "+2 Soul Hearts & orbital light shield",
                "25%-75% chance (Luck) to reflect enemy shots"
            }
        elseif id == ITEM_POWER_RING then
            return "Green Lantern Ring [Starting Passive]", {
                "Fires piercing & spectral emerald bolts from hand",
                "Passes cleanly through enemies and rocks/objects"
            }
        end
    else
        if id == TRINKET_YELLOW_IMPURITY then
            return "Yellow Impurity [Trinket]", {
                "1.5x Damage Multiplier (+50% Damage Up)",
                "Contact/explosion hits cause 2s Fear reversal"
            }
        end
    end
    return nil, nil
end

-- Cached custom Sprite instances for the Green Lantern / Parallax aura and Power Ring hand flare
local glAuraSprite = nil
local glFlareSprite = nil

local function GetGLAuraSprites()
    if not glAuraSprite and Sprite then
        local s1 = Sprite()
        local ok1 = pcall(function()
            s1:Load("gfx/effects/gl_aura.anm2", true)
            s1:Play("HalAura", true)
        end)
        if ok1 then
            glAuraSprite = s1
        end
    end
    if not glFlareSprite and Sprite then
        local s2 = Sprite()
        local ok2 = pcall(function()
            s2:Load("gfx/effects/gl_aura.anm2", true)
            s2:Play("RingFlare", true)
        end)
        if ok2 then
            glFlareSprite = s2
        end
    end
    return glAuraSprite, glFlareSprite
end

local function RenderGLPlayerAura(player)
    if not (IsHalJordan(player) or IsTaintedHal(player)) then return end
    local data = GetPlayerData(player)
    if IsHalJordan(player) and data.ringDepleted then return end

    local auraSpr, _ = GetGLAuraSprites()
    if not auraSpr then return end

    local frame = Game():GetFrameCount()
    local animName = IsTaintedHal(player) and "ParallaxAura" or "HalAura"
    local animFrame = math.floor(frame / 3) % 8
    auraSpr:SetFrame(animName, animFrame)

    local isMaxPower = (IsHalJordan(player) and ((data.willpower or 0) >= 99.5 or data.overcharge or data.surgeBuff))
        or (IsTaintedHal(player) and ((data.emeraldSparks or 0) >= 99.5 or data.coastCityActive))

    local auraScale = isMaxPower and 1.05 or 0.92
    local auraAlpha = isMaxPower and 0.92 or 0.72
    auraSpr.Scale = Vector(auraScale, auraScale)
    if data.overcharge then
        auraSpr.Color = Color(0.55, 1.0, 0.55, auraAlpha, 0.12, 0.45, 0.08)
    else
        auraSpr.Color = Color(1.0, 1.0, 1.0, auraAlpha, 0, 0, 0)
    end

    local bodyScreenPos = Isaac.WorldToScreen(player.Position)
    auraSpr:Render(bodyScreenPos, Vector.Zero, Vector.Zero)
end

-- 1. Render the animated Emerald Lantern / Parallax hover ring & aura BEHIND the player boots/body
if ModCallbacks.MC_PRE_PLAYER_RENDER then
    GL:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, renderOffset)
        if RenderMode and Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
        RenderGLPlayerAura(player)
        return nil
    end)
end

-- 2. Render crisp 4-point Power Ring star flare on the character's outstretched ring hand IN FRONT of the player
GL:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, renderOffset)
    if RenderMode and Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
    if not HasGreenLanternRing(player) then return end
    local data = GetPlayerData(player)
    if IsHalJordan(player) and data.ringDepleted then return end

    if not ModCallbacks.MC_PRE_PLAYER_RENDER then
        RenderGLPlayerAura(player)
    end

    local _, flareSpr = GetGLAuraSprites()
    local frame = Game():GetFrameCount()

    if flareSpr then
        local shootInput = player:GetShootingInput()
        local isFiring = (shootInput and shootInput:Length() > 0.1) or (data.ringFlareTimer and data.ringFlareTimer > 0)
        local handOffset = GetRingHandOffset(player, shootInput)
        local handScreenPos = Isaac.WorldToScreen(player.Position + handOffset)

        local flareFrame = math.floor(frame / (isFiring and 2 or 4)) % 4
        flareSpr:SetFrame("RingFlare", flareFrame)

        if isFiring then
            flareSpr.Scale = Vector(0.82, 0.82)
            flareSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0.10, 0.35, 0.12)
        else
            local pulse = 0.45 + 0.20 * math.sin(frame * 0.20)
            flareSpr.Scale = Vector(0.45, 0.45)
            flareSpr.Color = Color(1.0, 1.0, 1.0, pulse, 0, 0, 0)
        end
        flareSpr:Render(handScreenPos, Vector.Zero, Vector.Zero)
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
    EnsureEIDRegistered()
    RegisterStageAPIGraphics()
    if Game():GetHUD() and not Game():GetHUD():IsVisible() then return end

    local hudOffset = (Options and Options.HUDOffset) or 0
    local baseX = 48 + math.floor(hudOffset * 20)
    local baseY = 33 + math.floor(hudOffset * 12)

    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player then
            local hudX = baseX
            local hudY = baseY + (i * 14)
            local data = GetPlayerData(player)

            -- HAL JORDAN HUD (Top-left below hearts)
            if IsHalJordan(player) then
                local pct  = math.max(0.0, math.min(1.0, data.willpower / WILLPOWER_MAX))
                local BAR_W = 36

                Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)

                local r, g, b = 0.1, 0.95, 0.3
                if data.ringDepleted then
                    r, g, b = 0.95, 0.2, 0.2
                elseif data.overcharge then
                    r, g, b = 1.0, 0.88, 0.15
                elseif data.surgeBuff then
                    r, g, b = 0.35, 1.0, 0.65
                elseif pct >= 0.995 then
                    r, g, b = 0.35, 1.0, 0.55
                end

                if pct > 0 then
                    Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * pct * 0.14, 0.9, r, g, b, 0.95)
                end

                local label = string.format("%.0f%%", data.willpower)
                if data.ringDepleted then
                    label = "EMPTY"
                elseif data.overcharge then
                    label = string.format("%.0f%% 2xDMG", data.willpower)
                elseif data.surgeBuff then
                    label = string.format("%.0f%% 1.5xDMG", data.willpower)
                elseif pct >= 0.995 then
                    label = "100% +25%DMG"
                end
                DrawHudText(label, hudX + 33, hudY - 2, r, g, b, 0.95)

                if data.oathTextTimer and data.oathTextTimer > 0 then
                    data.oathTextTimer = data.oathTextTimer - 1
                end
            end

            -- TAINTED HAL HUD (Top-left below hearts)
            if IsTaintedHal(player) then
                local pct  = math.max(0.0, math.min(1.0, data.emeraldSparks / SPARK_MAX))
                local BAR_W = 36

                Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)

                local r, g, b = 0.0, 0.85, 0.4
                if pct >= 1.0 then r, g, b = 0.25, 1.0, 0.55 end

                if pct > 0 then
                    Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * pct * 0.14, 0.9, r, g, b, 0.95)
                end

                local label = pct >= 1.0 and "MAX +50%" or string.format("%.0f%%", data.emeraldSparks)
                if data.stolenRings > 0 then
                    label = string.format("%s [%d]", label, data.stolenRings)
                end
                DrawHudText(label, hudX + 33, hudY - 2, r, g, b, 0.95)
            end

            -- BUILT-IN ITEM INSPECTOR (ONLY shows when standing near a mod pedestal on the floor, or while actively holding Tab/Map)
            if i == 0 then
                local inspectTitle, inspectLines = nil, nil

                -- 1. Check nearby mod pedestals / trinkets on the floor (when EID is not installed)
                if not EID then
                    local nearestDist = 95
                    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false)) do
                        if ent.Variant == PickupVariant.PICKUP_COLLECTIBLE and ent.SubType > 0 then
                            local dist = (ent.Position - player.Position):Length()
                            if dist < nearestDist then
                                local t, l = GetModItemInspectionInfo(false, ent.SubType)
                                if t then
                                    nearestDist  = dist
                                    inspectTitle = t
                                    inspectLines = l
                                end
                            end
                        elseif ent.Variant == PickupVariant.PICKUP_TRINKET and ent.SubType > 0 then
                            local dist = (ent.Position - player.Position):Length()
                            if dist < nearestDist then
                                local t, l = GetModItemInspectionInfo(true, ent.SubType)
                                if t then
                                    nearestDist  = dist
                                    inspectTitle = t
                                    inspectLines = l
                                end
                            end
                        end
                    end
                end

                -- 2. Or if actively holding Tab (ACTION_MAP) after stage intro finishes, inspect equipped Green Lantern item
                local holdingMap = Input.IsActionPressed(ButtonAction.ACTION_MAP, player.ControllerIndex)
                    and (Game():GetFrameCount() > 60)
                if not inspectTitle and holdingMap then
                    local actId = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
                    inspectTitle, inspectLines = GetModItemInspectionInfo(false, actId)
                    if not inspectTitle and ITEM_SOLID_LIGHT_SHIELD and player:HasCollectible(ITEM_SOLID_LIGHT_SHIELD) then
                        inspectTitle, inspectLines = GetModItemInspectionInfo(false, ITEM_SOLID_LIGHT_SHIELD)
                    end
                    if not inspectTitle and TRINKET_YELLOW_IMPURITY and player:HasTrinket(TRINKET_YELLOW_IMPURITY) then
                        inspectTitle, inspectLines = GetModItemInspectionInfo(true, TRINKET_YELLOW_IMPURITY)
                    end
                end

                if inspectTitle and inspectLines then
                    local boxX = math.max(12, baseX - 28)
                    local boxY = 215
                    DrawHudText(inspectTitle, boxX, boxY, 0.25, 1.0, 0.45, 0.95)
                    for idx, line in ipairs(inspectLines) do
                        DrawHudText(line, boxX, boxY + idx * 9, 0.92, 0.96, 0.93, 0.90)
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 16: DEBUG CONSOLE COMMANDS
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, cmd, params)
    if cmd == "gl_willpower" then
        local p = Isaac.GetPlayer(0)
        if IsHalJordan(p) then
            local pct = tonumber(params) or 100
            local d = GetPlayerData(p)
            d.willpower    = pct
            d.ringDepleted = (pct <= 0)
            p:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
            p:EvaluateItems()
            Isaac.ConsoleOutput(string.format("[GL] Willpower set to %.0f%%\n", pct))
        end
        return true
    end

    if cmd == "gl_sparks" then
        local p = Isaac.GetPlayer(0)
        if IsTaintedHal(p) then
            local pct = tonumber(params) or 100
            GetPlayerData(p).emeraldSparks = pct
            p:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
            p:EvaluateItems()
            Isaac.ConsoleOutput(string.format("[GL] Emerald Sparks set to %.0f%%\n", pct))
        end
        return true
    end
end)

Isaac.ConsoleOutput("[GreenLanternMod] Loaded successfully. In brightest day, in blackest night!\n")
