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
local ITEM_POWER_BATTERY       = nil  -- Pocket active (Hal)
local ITEM_GIANT_FIST          = nil  -- Active 4-room
local ITEM_COAST_CITY          = nil  -- Tainted Hal pocket active
local ITEM_SOLID_LIGHT_SHIELD  = nil  -- Passive
local TRINKET_YELLOW_IMPURITY  = nil  -- Trinket

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
            overchargeRoomIdx   = -1,
            oathTextTimer       = 0,
            oathText            = "",

            -- Tainted Hal
            emeraldSparks       = 0.0,
            stolenRings         = 0,
            coastCityActive     = false,
            coastCityFrame      = 0,

            -- Yellow Impurity
            fearControlTimer    = 0,
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
                if ITEM_POWER_BATTERY and ITEM_POWER_BATTERY > 0 then
                    player:SetPocketActiveItem(ITEM_POWER_BATTERY, ActiveSlot.SLOT_POCKET, true)
                end
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED)
                player:EvaluateItems()
            elseif IsTaintedHal(player) then
                if ITEM_COAST_CITY and ITEM_COAST_CITY > 0 then
                    player:SetPocketActiveItem(ITEM_COAST_CITY, ActiveSlot.SLOT_POCKET, true)
                end
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end)
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

            -- Overcharge: double damage in current room
            local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
            if data.overcharge and data.overchargeRoomIdx == roomIdx then
                player.Damage = player.Damage * 2.0
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
    if not IsHalJordan(player) then return end

    local data = GetPlayerData(player)

    if data.ringDepleted or data.willpower < WILLPOWER_MAX then
        data.willpower    = WILLPOWER_MAX
        data.ringDepleted = false
        data.overcharge   = false

        player:AnimateHappy()
        player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
        player:EvaluateItems()

        data.oathTextTimer = 150
        data.oathText = "In brightest day, in blackest night,\nNo evil shall escape my sight!"
    else
        -- Overcharge
        data.overcharge        = true
        data.overchargeRoomIdx = Game():GetLevel():GetCurrentRoomIndex()

        player:AnimateHappy()
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
        player:EvaluateItems()

        data.oathTextTimer = 150
        data.oathText = "OVERCHARGE!\nBeware my power — Green Lantern's light!"
    end

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
    if not IsTaintedHal(player) then return end

    local data = GetPlayerData(player)

    if data.emeraldSparks < SPARK_MAX then
        player:AnimateSad()
        return false
    end

    data.emeraldSparks   = 0.0
    data.coastCityActive = true
    data.coastCityFrame  = Game():GetFrameCount()

    local room   = Game():GetRoom()
    local center = room:GetCenterPos()

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
        construct.Scale = 4.0
        construct:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 1, 0)
    end

    player:AnimateHappy()
    return true
end, ITEM_COAST_CITY)

-- Coast City logic: pull feared enemies & deal DPS
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

    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
        if enemy:IsEnemy() and enemy:HasEntityFlags(EntityFlag.FLAG_FEAR) then
            local toCenter = (center - enemy.Position)
            local dist     = toCenter:Length()

            if dist > 8 then
                local pullStr = math.min(8.0, 300.0 / math.max(dist, 10))
                enemy.Velocity = enemy.Velocity + toCenter:Normalized() * pullStr
            else
                if age % 10 == 0 and ownerPlayer then
                    local dmg = ownerPlayer.Damage * 3.0
                    enemy:TakeDamage(dmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(construct), 0)

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

    if entity:HasEntityFlags(EntityFlag.FLAG_FEAR) then
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
                    local nearestFeared = nil
                    local nearestDist   = 400

                    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
                        if enemy:IsEnemy() and enemy:HasEntityFlags(EntityFlag.FLAG_FEAR) then
                            local dist = (enemy.Position - familiar.Position):Length()
                            if dist < nearestDist then
                                nearestDist   = dist
                                nearestFeared = enemy
                            end
                        end
                    end

                    if nearestFeared then
                        local dir      = (nearestFeared.Position - familiar.Position):Normalized()
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
-- SECTION 14: OVERCHARGE RESET ON NEW ROOM
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsHalJordan(player) then
            local data = GetPlayerData(player)
            local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
            if data.overcharge and data.overchargeRoomIdx ~= roomIdx then
                data.overcharge = false
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 15: HUD RENDERING (Willpower Bar & Emerald Spark Meter)
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player then
            -- HAL JORDAN HUD
            if IsHalJordan(player) then
                local data = GetPlayerData(player)
                local pct  = data.willpower / WILLPOWER_MAX
                local BAR_W = 50
                local BAR_H = 4
                local screenPos = Isaac.WorldToScreen(player.Position) - Vector(BAR_W / 2, 28)

                -- Dark background
                Isaac.RenderScaledText("_", screenPos.X, screenPos.Y, BAR_W * 0.15, BAR_H * 0.5, 0.1, 0.1, 0.1, 0.8)

                -- Dynamic color: Green -> Red (depleted) -> Gold (overcharge)
                local r, g, b = 0.0, 0.9, 0.2
                if data.ringDepleted then
                    r, g, b = 0.9, 0.1, 0.1
                elseif data.overcharge then
                    r, g, b = 1.0, 0.85, 0.0
                end

                Isaac.RenderScaledText("_", screenPos.X, screenPos.Y, BAR_W * pct * 0.15, BAR_H * 0.5, r, g, b, 0.9)

                local label = data.ringDepleted and "RING DEPLETED" or string.format("Willpower: %.0f%%", data.willpower)
                Isaac.RenderText(label, screenPos.X, screenPos.Y - 6, r, g, b, 0.9)

                if data.oathTextTimer and data.oathTextTimer > 0 then
                    data.oathTextTimer = data.oathTextTimer - 1
                    local alpha = math.min(1.0, data.oathTextTimer / 30)
                    local oathPos = Isaac.WorldToScreen(player.Position) - Vector(60, 50)
                    Isaac.RenderText(data.oathText or "", oathPos.X, oathPos.Y, 0.1, 0.9, 0.2, alpha)
                end
            end

            -- TAINTED HAL HUD
            if IsTaintedHal(player) then
                local data = GetPlayerData(player)
                local pct  = data.emeraldSparks / SPARK_MAX
                local BAR_W = 50
                local BAR_H = 4
                local screenPos = Isaac.WorldToScreen(player.Position) - Vector(BAR_W / 2, 28)

                Isaac.RenderScaledText("_", screenPos.X, screenPos.Y, BAR_W * 0.15, BAR_H * 0.5, 0.05, 0.05, 0.05, 0.8)

                local r, g, b = 0.0, 0.8, 0.35
                if pct >= 1.0 then r, g, b = 0.2, 1.0, 0.5 end

                Isaac.RenderScaledText("_", screenPos.X, screenPos.Y, BAR_W * pct * 0.15, BAR_H * 0.5, r, g, b, 0.9)

                local label = pct >= 1.0 and "COAST CITY READY!" or string.format("Emerald: %.0f%%", data.emeraldSparks)
                Isaac.RenderText(label, screenPos.X, screenPos.Y - 6, r, g, b, 0.9)

                if data.stolenRings > 0 then
                    local ringLabel = string.format("Rings: %d", data.stolenRings)
                    Isaac.RenderText(ringLabel, screenPos.X, screenPos.Y + 6, 0.1, 0.9, 0.3, 0.85)
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
