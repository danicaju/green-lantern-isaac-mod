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

            -- Costume & Inspection tracking
            lastCollectibleCount = -1,
            inspectTimer         = 150,
        }
    end
    return d.GreenLantern
end

-- ---------------------------------------------------------------------------
-- SECTION 3: HELPER UTILITIES
-- ---------------------------------------------------------------------------

local function LoadItemIDs()
    ITEM_POWER_BATTERY      = Isaac.GetItemIdByName("Power Battery")
    ITEM_GIANT_FIST         = Isaac.GetItemIdByName("Construct: Giant Fist")
    ITEM_COAST_CITY         = Isaac.GetItemIdByName("The Tragedy of Coast City")
    ITEM_SOLID_LIGHT_SHIELD = Isaac.GetItemIdByName("Solid Light Shield")
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
end

local function IsHalJordan(player)
    if not PLAYER_HAL or PLAYER_HAL < 0 then LoadItemIDs() end
    return PLAYER_HAL and PLAYER_HAL >= 0 and player:GetPlayerType() == PLAYER_HAL
end

local function IsTaintedHal(player)
    if not PLAYER_TAINTED_HAL or PLAYER_TAINTED_HAL < 0 then LoadItemIDs() end
    return PLAYER_TAINTED_HAL and PLAYER_TAINTED_HAL >= 0 and player:GetPlayerType() == PLAYER_TAINTED_HAL
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
    end

    -- TAINTED HAL INIT
    if IsTaintedHal(player) then
        local data = GetPlayerData(player)
        data.emeraldSparks   = 0.0
        data.stolenRings     = 0
        data.coastCityActive = false
        data.coastCityFrame  = 0
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
                if ITEM_POWER_BATTERY and ITEM_POWER_BATTERY > 0 and not player:HasCollectible(ITEM_POWER_BATTERY) then
                    player:AddCollectible(ITEM_POWER_BATTERY, 3, false, ActiveSlot.SLOT_PRIMARY)
                end
                RefreshCharacterCostume(player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED)
                player:EvaluateItems()
            elseif IsTaintedHal(player) then
                if ITEM_COAST_CITY and ITEM_COAST_CITY > 0 and not player:HasCollectible(ITEM_COAST_CITY) then
                    player:AddCollectible(ITEM_COAST_CITY, 4, false, ActiveSlot.SLOT_PRIMARY)
                end
                RefreshCharacterCostume(player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end)
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
    -- HAL JORDAN STATS
    if IsHalJordan(player) then
        local data = GetPlayerData(player)

        if cacheFlag == CacheFlag.CACHE_SPEED then
            player.MoveSpeed = player.MoveSpeed + HAL_SPEED_BONUS
        end

        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage * HAL_DAMAGE_MULTIPLIER

            local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
            if data.overcharge and data.overchargeRoomIdx == roomIdx then
                -- Full Overcharge: 2.0x damage in current room
                player.Damage = player.Damage * 2.0
            elseif data.surgeBuff and data.overchargeRoomIdx == roomIdx then
                -- Construct Surge (used when <50% Willpower): 1.35x damage in current room
                player.Damage = player.Damage * 1.35
            end

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
            local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
            if data.overcharge and data.overchargeRoomIdx == roomIdx then
                player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            elseif data.surgeBuff and data.overchargeRoomIdx == roomIdx then
                player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL
            end
        end
    end

    -- TAINTED HAL STATS
    if IsTaintedHal(player) then
        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage * TAINTED_DMG_MULTIPLIER
        end

        if cacheFlag == CacheFlag.CACHE_FIREDELAY then
            player.MaxFireDelay = math.max(player.MaxFireDelay + math.abs(TAINTED_TEARS_PENALTY) * 3, 6)
        end

        if cacheFlag == CacheFlag.CACHE_FLYING then
            player.CanFly = true
        end

        if cacheFlag == CacheFlag.CACHE_TEARFLAG then
            player.TearFlags = player.TearFlags | TearFlags.TEAR_FEAR
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
-- SECTION 6: TEAR HANDLING (Willpower drain, range, and emerald green tint)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
    local spawner = tear.SpawnerEntity
    if not spawner then return end
    local player = spawner:ToPlayer()
    if not player then return end

    -- HAL JORDAN TEARS
    if IsHalJordan(player) then
        local data = GetPlayerData(player)

        -- Bright green construct beam tint
        tear:GetSprite().Color = Color(0, 0.9, 0.2, 1, 0, 0.4, 0)

        if data.ringDepleted then
            -- Limited range when depleted: drop near the player
            tear.Velocity = tear.Velocity * 0.18
        else
            -- Drain willpower
            data.willpower = math.max(0, data.willpower - WILLPOWER_PER_TEAR)
            if data.willpower <= 0 then
                data.ringDepleted = true
                data.willpower = 0
                player:AnimateSad()
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector.Zero, player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE)
                player:EvaluateItems()
            end
        end
    end

    -- TAINTED HAL TEARS
    if IsTaintedHal(player) then
        -- Vibrant emerald green tint, enlarged tear
        tear:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
        tear.Scale = tear.Scale * 1.4
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 7: ACTIVE ITEMS (Power Battery, Giant Fist, Coast City)
-- ---------------------------------------------------------------------------

-- Power Battery
GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if itemID ~= ITEM_POWER_BATTERY then return end

    local data = GetPlayerData(player)
    local prevWill = data.willpower or WILLPOWER_MAX
    local wasDepleted = data.ringDepleted

    -- 1. Always refill Willpower to 100% and restore ring power
    data.willpower         = WILLPOWER_MAX
    data.ringDepleted      = false
    data.overchargeRoomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- 2. If used at >= 50% Willpower (and not depleted), grant FULL OVERCHARGE (2.0x DMG + Piercing + Spectral).
    --    Otherwise, still grant CONSTRUCT SURGE (1.35x DMG + Spectral) so using Power Battery is ALWAYS rewarding!
    if not wasDepleted and prevWill >= 50.0 then
        data.overcharge = true
        data.surgeBuff  = false
        data.oathTextTimer = 120
        data.oathText = "OVERCHARGE! (2x DMG + Piercing)"
    else
        data.overcharge = false
        data.surgeBuff  = true
        data.oathTextTimer = 120
        data.oathText = "WILLPOWER RESTORED! (+35% DMG Surge)"
    end

    -- 3. Unleash an immediate 8-way Emerald Construct Ring Burst + Shockwave around the player!
    for i = 1, 8 do
        local angle = (i - 1) * (math.pi / 4)
        local dir = Vector(math.cos(angle), math.sin(angle))
        local beam = Isaac.Spawn(
            EntityType.ENTITY_TEAR,
            TearVariant.BLUE_CANDLE,
            0,
            player.Position + dir * 14,
            dir * 16.0,
            player
        ):ToTear()
        if beam then
            beam.CollisionDamage = player.Damage * 2.5
            beam.Scale           = 1.6
            beam.TearFlags       = beam.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            beam:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
        end
    end

    -- Shockwave: damage & knockback nearby enemies and clear nearby enemy projectiles
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        local dist = (ent.Position - player.Position):Length()
        if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() and dist <= 130 then
            ent:TakeDamage(player.Damage * 3.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
            local push = (ent.Position - player.Position)
            if push:Length() > 0.1 then
                ent.Velocity = ent.Velocity + push:Normalized() * 12.0
            end
        elseif ent.Type == EntityType.ENTITY_PROJECTILE and dist <= 150 then
            ent:Die()
        end
    end

    player:AnimateHappy()
    player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
    player:EvaluateItems()

    return true
end, ITEM_POWER_BATTERY)

-- Construct: Giant Fist
GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
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

    local fistVelocity = direction * 20.0
    local fist = Isaac.Spawn(
        EntityType.ENTITY_TEAR,
        TearVariant.TOOTH,
        0,
        player.Position + direction * 20,
        fistVelocity,
        player
    ):ToTear()

    if fist then
        fist.CollisionDamage = player.Damage * 10
        fist.Scale           = 3.5
        fist.TearFlags       = fist.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING | TearFlags.TEAR_MEGA
        fist:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
        fist:GetData().isGiantFist = true
    end

    return true
end, ITEM_GIANT_FIST)

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
    if itemID ~= ITEM_COAST_CITY then return end

    local data = GetPlayerData(player)

    -- Stored Emerald Sparks boost vortex damage up to +50% (no longer blocks activation when <100%!)
    local sparkBonus = 1.0 + ((data.emeraldSparks or 0.0) / SPARK_MAX) * 0.5
    data.coastCityBoost  = sparkBonus
    data.emeraldSparks   = 0.0
    data.coastCityActive = true
    data.coastCityFrame  = Game():GetFrameCount()

    local room   = Game():GetRoom()
    local center = room:GetCenterPos()

    -- Immediately inflict Fear AND deal an initial Emerald Cataclysm blast to ALL enemies in the room!
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            ent:AddFear(EntityRef(player), 180)
            ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
            ent:TakeDamage(player.Damage * 2.5 * sparkBonus, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
        end
    end

    local construct = Isaac.Spawn(
        EntityType.ENTITY_EFFECT,
        EffectVariant.CRACK_THE_SKY,
        0,
        center,
        Vector.Zero,
        player
    )
    if construct then
        local cd = construct:GetData()
        cd.isCoastCity  = true
        cd.spawnFrame   = Game():GetFrameCount()
        cd.owner        = player
        cd.sparkBonus   = sparkBonus
        construct.Scale = 4.0
        construct:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 1, 0)
    end

    player:AnimateHappy()
    return true
end, ITEM_COAST_CITY)

-- Coast City logic: pull ALL vulnerable enemies toward center vortex & deal continuous emerald DPS
GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    local room         = Game():GetRoom()
    local center       = room:GetCenterPos()
    local currentFrame = Game():GetFrameCount()

    local construct = nil
    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, -1, false)) do
        local ed = ent:GetData()
        if ed and ed.isCoastCity then
            construct = ent
            break
        end
    end

    if not construct then return end

    local cd  = construct:GetData()
    local age = currentFrame - (cd.spawnFrame or currentFrame)

    if age > COAST_CITY_DURATION then
        construct:Remove()
        for i = 0, Game():GetNumPlayers() - 1 do
            local p = Isaac.GetPlayer(i)
            if IsTaintedHal(p) then
                GetPlayerData(p).coastCityActive = false
            end
        end
        return
    end

    local ownerPlayer = cd.owner or Isaac.GetPlayer(0)
    local sparkBonus  = cd.sparkBonus or 1.0

    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
        if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
            local isFeared = enemy:HasEntityFlags(EntityFlag.FLAG_FEAR)
            local toCenter = (center - enemy.Position)
            local dist     = toCenter:Length()

            -- Pull ALL vulnerable enemies toward the vortex (Feared enemies pull even faster)
            if dist > 18 then
                local pullMult = isFeared and 1.35 or 1.0
                local pullStr  = math.min(7.5, 260.0 / math.max(dist, 15)) * pullMult
                enemy.Velocity = enemy.Velocity * 0.8 + toCenter:Normalized() * pullStr
            end

            -- Deal pulsing Emerald Vortex damage every 10 frames across the vortex radius (or lighter fallout damage room-wide)
            if age % 10 == 0 and ownerPlayer then
                enemy:AddFear(EntityRef(ownerPlayer), 60)
                local fearMult = isFeared and 1.35 or 1.0
                local distMult = (dist <= 110) and 2.2 or 0.9
                local dmg = ownerPlayer.Damage * distMult * fearMult * sparkBonus
                enemy:TakeDamage(dmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(construct), 0)

                if dist <= 110 and math.random() < 0.45 then
                    local spark = Isaac.Spawn(
                        EntityType.ENTITY_PICKUP,
                        PickupVariant.PICKUP_COIN,
                        CoinSubType.COIN_PENNY,
                        enemy.Position + Vector(math.random(-15, 15), math.random(-15, 15)),
                        Vector.Zero,
                        construct
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
    if not player:HasCollectible(ITEM_SOLID_LIGHT_SHIELD) then return end

    if source and source.Entity and source.Entity.Type == EntityType.ENTITY_TEAR then
        local srcEnt  = source.Entity
        local luck    = player.Luck
        local chance  = math.min(0.25 + luck * 0.05, 0.75)

        if math.random() < chance then
            local reflectVel = (player.Position - srcEnt.Position):Normalized() * (-srcEnt.Velocity:Length())
            local reflected  = Isaac.Spawn(
                EntityType.ENTITY_TEAR,
                TearVariant.BLUE_CANDLE,
                0,
                srcEnt.Position,
                reflectVel,
                player
            ):ToTear()

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
                        local laser    = Isaac.Spawn(
                            EntityType.ENTITY_TEAR,
                            TearVariant.BLUE_CANDLE,
                            0,
                            familiar.Position,
                            laserVel,
                            player
                        ):ToTear()

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
    local prevWillpower = data.willpower

    -- Refill amount based on subtype (1=normal, 2=micro, 3=mega, 4=golden)
    local refillAmount = 50.0
    if pickup.SubType == 3 or pickup.SubType == 4 then
        refillAmount = 100.0
    elseif pickup.SubType == 2 then
        refillAmount = 25.0
    end

    data.willpower    = math.min(WILLPOWER_MAX, data.willpower + refillAmount)
    data.ringDepleted = (data.willpower <= 0)

    if prevWillpower <= 0 and data.willpower > 0 then
        data.ringDepleted = false
        player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE)
        player:EvaluateItems()
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 14: OVERCHARGE / SURGE RESET ON NEW ROOM
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsHalJordan(player) or IsTaintedHal(player) then
            RefreshCharacterCostume(player)
        end
        if IsHalJordan(player) then
            local data = GetPlayerData(player)
            local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
            if (data.overcharge or data.surgeBuff) and data.overchargeRoomIdx ~= roomIdx then
                data.overcharge = false
                data.surgeBuff  = false
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 15: HUD RENDERING & ITEM INSPECTION DESCRIPTIONS
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
        EID:addCollectible(ITEM_POWER_BATTERY,
            "Refills Willpower to 100% and fires an 8-way piercing construct burst#At >=50% Willpower: Overcharge (2x DMG + Piercing + Spectral for the room)#Below 50%: +35% DMG Surge + Spectral for the room",
            "Power Battery")
        EID:addCollectible(ITEM_GIANT_FIST,
            "Fires a massive spectral piercing emerald fist#Deals 10x Player Damage and smashes rocks & obstacles",
            "Construct: Giant Fist")
        EID:addCollectible(ITEM_COAST_CITY,
            "Fears and blasts all enemies in the room, then spawns a 10s Emerald Vortex#Pulls all enemies toward the center and deals heavy continuous DPS#Stored Emerald Sparks boost vortex damage up to +50%",
            "The Tragedy of Coast City")
        EID:addCollectible(ITEM_SOLID_LIGHT_SHIELD,
            "+2 Soul Hearts#Grants an orbital shield that blocks shots#25%-75% chance (scales with Luck) to reflect enemy projectiles as spectral beams",
            "Solid Light Shield")
        if TRINKET_YELLOW_IMPURITY and TRINKET_YELLOW_IMPURITY > 0 then
            EID:addTrinket(TRINKET_YELLOW_IMPURITY,
                "1.5x Damage multiplier (+50% DMG)#Taking contact or explosion damage briefly inflicts Fear (reversed movement for 2s)",
                "Yellow Impurity")
        end
        eidRegistered = true
    end)
end

local function GetModItemInspectionInfo(isTrinket, id)
    if not ITEM_POWER_BATTERY or ITEM_POWER_BATTERY < 0 then LoadItemIDs() end
    if not isTrinket then
        if id == ITEM_POWER_BATTERY then
            return "Power Battery [3R Active]", {
                "100% Willpower + 8-way construct burst & knockback",
                ">=50% Will: 2x DMG + Piercing | <50%: +35% DMG"
            }
        elseif id == ITEM_GIANT_FIST then
            return "Construct: Giant Fist [4R Active]", {
                "Fires a giant piercing 10x DMG emerald fist",
                "Smashes rocks, poop, and obstacles in its path"
            }
        elseif id == ITEM_COAST_CITY then
            return "The Tragedy of Coast City [4R Active]", {
                "Fears & blasts all enemies + 10s Emerald Vortex",
                "Pulls enemies in for heavy DPS (Sparks add +50% DMG)"
            }
        elseif id == ITEM_SOLID_LIGHT_SHIELD then
            return "Solid Light Shield [Passive]", {
                "+2 Soul Hearts & orbital light shield",
                "25%-75% chance (Luck) to reflect enemy shots"
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

GL:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
    EnsureEIDRegistered()
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
                    label = string.format("%.0f%% +35%%", data.willpower)
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

            -- BUILT-IN ITEM INSPECTOR (fallback when EID is NOT installed, or when holding Tab/Map with no nearby pedestal)
            if i == 0 then
                local inspectTitle, inspectLines = nil, nil

                -- 1. Check nearby pedestals / trinkets on the floor ONLY if External Item Descriptions (EID) is not active
                if not EID then
                    local nearestDist = 170
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

                -- 2. Or if holding Tab (ACTION_MAP) when EID is not displaying a pedestal, inspect equipped Green Lantern items
                local holdingMap = Input.IsActionPressed(ButtonAction.ACTION_MAP, player.ControllerIndex)
                if not inspectTitle and holdingMap and not EID then
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
                    local boxX = math.max(8, baseX - 34)
                    local boxY = hudY + 11
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
            p:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE)
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
            Isaac.ConsoleOutput(string.format("[GL] Emerald Sparks set to %.0f%%\n", pct))
        end
        return true
    end
end)

Isaac.ConsoleOutput("[GreenLanternMod] Loaded successfully. In brightest day, in blackest night!\n")
