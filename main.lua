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

-- Willpower meter & continuous emerald beam mode constants (Hal Jordan & Tainted Hal)
local WILLPOWER_MAX                 = 100.0
local WILLPOWER_PER_TEAR            =  0.5   -- each small beam tear costs 0.5% willpower
local WILLPOWER_REBOOT_THRESHOLD    = 20.0   -- willpower needed to reboot the Ring after hitting 0%
local WILLPOWER_PASSIVE_REBOOT_RATE =  0.085 -- passive willpower recovery per 30fps frame (~2.5%/sec -> ~8s reboot) while Ring is offline
local WILLPOWER_KILL_REBOOT_BONUS   =  5.0   -- +5% willpower per enemy killed while fighting without the Ring
local WILLPOWER_ROOM_REBOOT_BONUS   = 15.0   -- +15% willpower on clearing a room while Ring is offline
local HAL_CONTINUOUS_HOLD_FRAMES    = 24     -- must hold fire continuously >= 24 player-update ticks (~0.40s) to channel continuous emerald laser; clicking/spamming fires discrete beams
local HAL_CONTINUOUS_BEAM_DMG_MULT  =  0.20  -- each continuous beam tick deals 20% of small-beam damage
local HAL_CONTINUOUS_TICK_FRAMES    =  4     -- continuous beam ticks once every 4 frames (7.5/sec -> 1.5x DMG/sec)
local HAL_CONTINUOUS_WILL_DRAIN     =  0.06  -- willpower drained per update tick while Hal Jordan channels continuous beam

-- Tainted Hal stats
local TAINTED_DMG_MULTIPLIER   = 1.5    -- massive damage multiplier
local TAINTED_TEARS_PENALTY    = -1.5   -- tear delay modifier

-- Green Lantern Emblem (Emerald Spark) constants for Tainted Hal
local SPARK_MAX                = 100.0
local SPARK_PER_KILL           =  10.0  -- each picked-up Green Lantern emblem grants 10% meter
local SPARK_LIFETIME_FRAMES    = 180    -- emblems last 6 seconds (180 frames at 30fps) on the floor before vanishing on their own
local SPARK_BLINK_FRAMES       =  60    -- emblems blink during their final 2 seconds on the floor
local SPARK_COLLECT_FRAMES     =  12    -- 12-frame coin/bomb style pickup animation when walked over
local SPARK_PICKUP_RANGE       =  22.0  -- walk-over pickup radius
local SPARK_DROP_CHANCE_FEARED =  0.14  -- 14% drop rate from killed Feared enemies
local SPARK_DROP_CHANCE_NORMAL =  0.08  -- 8% drop rate from killed normal enemies

-- Coast City construct duration (frames, 30 fps base)
local COAST_CITY_DURATION  = 150  -- 5 seconds base vortex duration

-- ---------------------------------------------------------------------------
-- SECTION 2: PER-PLAYER DATA STORAGE (Entity:GetData())
-- ---------------------------------------------------------------------------

local function GetPlayerData(player)
    local d = player:GetData()
    if not d.GreenLantern then
        d.GreenLantern = {
            -- Hal Jordan
            willpower                = WILLPOWER_MAX,
            ringDepleted             = false,
            overcharge               = false,
            surgeBuff                = false,
            overchargeRoomIdx        = -1,
            oathTextTimer            = 0,
            oathText                 = "",
            shootHoldFrames          = 0,
            lastSmallBeamFrame       = -999,
            firedSmallBeamThisPress  = false,
            lastShootDir             = nil,
            bufferedClickDir         = nil,
            bufferedClickExpireFrame = 0,
            isFiringContinuousBeam   = false,
            spawningContinuousBeam   = false,
            continuousLaser          = nil,
            continuousBeamGraceTimer = 0,
            allowingTapTear          = false,

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
            lastRingHandOffset  = Vector(18, -14),

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

-- Active floor Green Lantern Emblem drops for Tainted Hal
-- Rendered directly via gl_lantern_spark.anm2 Sprite so they never spawn as coins/pickups or trigger C++ EffectVariant 0 explosions!
local activeEmeraldSparks = {}

local function SpawnLanternEmblemDrop(pos)
    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
    table.insert(activeEmeraldSparks, {
        pos          = Vector(pos.X, pos.Y),
        spawnFrame   = Game():GetFrameCount(),
        roomIdx      = roomIdx,
        collected    = false,
        collectFrame = 0,
    })
end

local function ClearAllLanternEmblemDrops()
    activeEmeraldSparks = {}
end

-- Safe helper to scale and tint any Entity userdata (since Entity uses SpriteScale, not .Scale)
local function SetEntityScaleAndColor(ent, scale, color)
    if not ent then return end
    pcall(function()
        if scale then
            ent.SpriteScale = Vector(scale, scale)
        end
        local spr = ent:GetSprite()
        if spr then
            if scale then
                spr.Scale = Vector(scale, scale)
            end
            if color then
                spr.Color = color
            end
        end
    end)
end

local stageApiRegistered = false
local function RegisterStageAPIGraphics()
    if stageApiRegistered then return end
    if StageAPI and StageAPI.Loaded and StageAPI.AddPlayerGraphicsInfo then
        if PLAYER_HAL and PLAYER_HAL >= 0 then
            StageAPI.AddPlayerGraphicsInfo(PLAYER_HAL, {
                Portrait     = "gfx/ui/stage/stage_hal_jordan.png",
                BossPortrait = "gfx/ui/boss/portrait_hal_jordan.png",
                PortraitBig  = "gfx/ui/stage/stage_hal_jordan.png",
                Name         = "gfx/ui/boss/name_hal_jordan.png",
                NoShake      = false,
            })
        end
        if PLAYER_TAINTED_HAL and PLAYER_TAINTED_HAL >= 0 then
            StageAPI.AddPlayerGraphicsInfo(PLAYER_TAINTED_HAL, {
                Portrait     = "gfx/ui/stage/stage_tainted_hal.png",
                BossPortrait = "gfx/ui/boss/portrait_tainted_hal.png",
                PortraitBig  = "gfx/ui/stage/stage_tainted_hal.png",
                Name         = "gfx/ui/boss/name_tainted_hal.png",
                NoShake      = false,
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
    if not player then return false end
    if not PLAYER_HAL or PLAYER_HAL < 0 then LoadItemIDs() end
    return PLAYER_HAL and PLAYER_HAL >= 0 and player:GetPlayerType() == PLAYER_HAL
end

local function IsTaintedHal(player)
    if not player then return false end
    if not PLAYER_TAINTED_HAL or PLAYER_TAINTED_HAL < 0 then LoadItemIDs() end
    return PLAYER_TAINTED_HAL and PLAYER_TAINTED_HAL >= 0 and player:GetPlayerType() == PLAYER_TAINTED_HAL
end

local function HasGreenLanternRing(player)
    if IsHalJordan(player) or IsTaintedHal(player) then return true end
    if not ITEM_POWER_RING or ITEM_POWER_RING < 0 then LoadItemIDs() end
    return ITEM_POWER_RING and ITEM_POWER_RING > 0 and player:HasCollectible(ITEM_POWER_RING)
end

-- Returns true only when the player has a Green Lantern Ring AND it is currently powered/online
local function IsRingActive(player)
    if not HasGreenLanternRing(player) then return false end
    if IsHalJordan(player) then
        local data = GetPlayerData(player)
        if data.ringDepleted then return false end
    end
    return true
end

local function CanUseContinuousBeam(player)
    if not (IsHalJordan(player) or IsTaintedHal(player)) then return false end
    if not IsRingActive(player) then return false end
    -- Allow charge/override weapons (Brimstone, Mom's Knife, Tech X, Technology, Monstro's Lung, etc.) to use their own mechanics
    if CollectibleType then
        local overrideItems = {
            CollectibleType.COLLECTIBLE_BRIMSTONE,
            CollectibleType.COLLECTIBLE_MOMS_KNIFE,
            CollectibleType.COLLECTIBLE_TECH_X,
            CollectibleType.COLLECTIBLE_TECHNOLOGY,
            CollectibleType.COLLECTIBLE_MONSTROS_LUNG,
            CollectibleType.COLLECTIBLE_CHOCOLATE_MILK,
            CollectibleType.COLLECTIBLE_CURSED_EYE,
            CollectibleType.COLLECTIBLE_EPIC_FETUS,
            CollectibleType.COLLECTIBLE_DR_FETUS,
            CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE,
            CollectibleType.COLLECTIBLE_SPIRIT_SWORD,
        }
        for _, itemId in ipairs(overrideItems) do
            if itemId and player:HasCollectible(itemId) then
                return false
            end
        end
    end
    return true
end

local function StopContinuousBeam(data)
    if not data then return end
    if data.continuousLaser and data.continuousLaser:Exists() then
        data.continuousLaser:Remove()
    end
    data.continuousLaser        = nil
    data.isFiringContinuousBeam = false
    data.spawningContinuousBeam = false
end

local function GetTapTearCount(player)
    local count = 1
    if not (player and CollectibleType) then return count end
    pcall(function()
        if CollectibleType.COLLECTIBLE_QUAD_SHOT and player:HasCollectible(CollectibleType.COLLECTIBLE_QUAD_SHOT) then
            count = 4
        elseif CollectibleType.COLLECTIBLE_INNER_EYE and player:HasCollectible(CollectibleType.COLLECTIBLE_INNER_EYE) then
            count = 3
        end
        if CollectibleType.COLLECTIBLE_20_20 and player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) then
            local n20 = (player.GetCollectibleNum and player:GetCollectibleNum(CollectibleType.COLLECTIBLE_20_20)) or 1
            if count == 1 then
                count = 1 + math.max(1, n20)
            else
                count = count + math.max(1, n20)
            end
        end
        if PlayerForm and PlayerForm.PLAYERFORM_BABY and player.HasPlayerForm and player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then
            count = math.max(count, 3)
        end
    end)
    return math.min(count, 8)
end

-- Raycast from startWorld along dir across the current Room until hitting a wall (passing spectrally over rocks/pits)
local function ComputeContinuousBeamEndWorld(startWorld, dir)
    if not startWorld then return Vector.Zero end
    local d = (dir and dir:Length() > 0.001) and dir:Normalized() or Vector(1, 0)
    local room = Game():GetRoom()
    if not room then
        return startWorld + d * 400.0
    end

    local function IsWallAt(p)
        if room.IsPositionInRoom and not room:IsPositionInRoom(p, 0) then
            return true
        end
        if room.GetGridCollisionAtPos and GridCollisionClass then
            local col = room:GetGridCollisionAtPos(p)
            if col == GridCollisionClass.COLLISION_WALL then
                return true
            end
        end
        return false
    end

    local maxDist        = 1600.0
    local step           = 8.0
    local hasEnteredRoom = not IsWallAt(startWorld)
    local lastValid      = 0.0
    local hitDist        = maxDist

    local dist = step
    while dist <= maxDist do
        local p = startWorld + d * dist
        if IsWallAt(p) then
            if hasEnteredRoom then
                hitDist = dist
                break
            elseif dist >= 80.0 then
                -- Started inside a wall margin while flying and aiming outward away from the room
                hitDist = 12.0
                break
            end
        else
            hasEnteredRoom = true
            lastValid      = dist
        end
        dist = dist + step
    end

    if not hasEnteredRoom then
        return startWorld + d * 12.0
    end

    local lo = lastValid
    local hi = hitDist
    for _ = 1, 5 do
        local mid = (lo + hi) * 0.5
        if IsWallAt(startWorld + d * mid) then
            hi = mid
        else
            lo = mid
        end
    end

    local finalDist = math.max(12.0, (lo + hi) * 0.5)
    return startWorld + d * finalDist
end

-- Perform continuous emerald laser beam hit/damage logic directly in Lua on tick frames (every 4 frames)
local function TickContinuousBeamDamage(player, data, startWorld, endWorld)
    local seg    = endWorld - startWorld
    local segLen = seg:Length()
    if segLen < 1.0 then return end
    local segDir = seg / segLen

    local beamScale  = IsTaintedHal(player) and 1.25 or (data.overcharge and 1.35 or (data.surgeBuff and 1.15 or 1.0))
    local baseRadius = 18.0 * beamScale
    local tickDmg    = (player.Damage or 3.5) * HAL_CONTINUOUS_BEAM_DMG_MULT
    local applyFear  = IsTaintedHal(player)
        or (TearFlags and TearFlags.TEAR_FEAR and player.TearFlags and ((player.TearFlags & TearFlags.TEAR_FEAR) ~= 0))
    local frame      = Game():GetFrameCount()

    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        if ent and ent:Exists() and not ent:IsDead() then
            local isEnemy = ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy()
            local isFire  = (EntityType and ent.Type == EntityType.ENTITY_FIREPLACE)
                and (not ent.HitPoints or ent.HitPoints > 1.0)
            if isEnemy or isFire then
                local toEnt       = ent.Position - startWorld
                local proj        = toEnt.X * segDir.X + toEnt.Y * segDir.Y
                local clampedProj = math.max(0.0, math.min(segLen, proj))
                local closestPt   = startWorld + segDir * clampedProj
                local perpDist    = (ent.Position - closestPt):Length()
                local entRadius   = math.max(8.0, ent.Size or 12.0)

                if perpDist <= (baseRadius + entRadius) then
                    if isEnemy then
                        local ed = ent.GetData and ent:GetData()
                        if not (ed and ed.lastGLContBeamTickFrame == frame) then
                            if ed then ed.lastGLContBeamTickFrame = frame end
                            local tookDmg = ent:TakeDamage(tickDmg, DamageFlag.DAMAGE_LASER, EntityRef(player), 0)
                            if tookDmg ~= false then
                                if applyFear then
                                    pcall(function()
                                        ent:AddFear(EntityRef(player), 90)
                                        ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
                                    end)
                                end
                                local splashPos = closestPt * 0.4 + ent.Position * 0.6
                                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, splashPos, Vector.Zero, player)
                                SetEntityScaleAndColor(fx, 0.45, Color(0.1, 1.0, 0.35, 0.85, 0.15, 0.85, 0.25))
                            end
                        end
                    elseif isFire then
                        pcall(function()
                            ent:TakeDamage(tickDmg, DamageFlag.DAMAGE_LASER, EntityRef(player), 0)
                        end)
                    end
                end
            end
        end
    end

    -- Damage destroyable grid entities (GRID_POOP, GRID_TNT) along the beam ray (including lateral beam width)
    local room = Game():GetRoom()
    if room and GridEntityType then
        local visitedGrid = {}
        local perp        = Vector(-segDir.Y, segDir.X)
        local edgeOffset  = baseRadius * 0.75
        local offsets     = { Vector.Zero, perp * edgeOffset, perp * (-edgeOffset) }
        local d           = 0.0
        while d <= segLen do
            local basePos = startWorld + segDir * d
            for _, off in ipairs(offsets) do
                local samplePos = basePos + off
                local gridIdx = room:GetGridIndex(samplePos)
                if gridIdx and gridIdx >= 0 and not visitedGrid[gridIdx] then
                    visitedGrid[gridIdx] = true
                    local gridEnt = room:GetGridEntity(gridIdx)
                    if gridEnt then
                        local gtype = gridEnt:GetType()
                        if gtype == GridEntityType.GRID_POOP or gtype == GridEntityType.GRID_TNT then
                            pcall(function()
                                gridEnt:Hurt(1)
                            end)
                        end
                    end
                end
            end
            if d >= segLen then break end
            d = math.min(segLen, d + 20.0)
        end
    end
end

-- Helper: returns true when the firing direction (or player head direction) is pointing UPWARD
local function IsAimingUp(player, fireVel)
    local dx, dy = 0, 1
    if fireVel and fireVel:Length() > 0.1 then
        local n = fireVel:Normalized()
        dx, dy = n.X, n.Y
    elseif player then
        local headDir = player:GetHeadDirection()
        if headDir == Direction.RIGHT then dx, dy = 1, 0
        elseif headDir == Direction.LEFT then dx, dy = -1, 0
        elseif headDir == Direction.UP then dx, dy = 0, -1
        else dx, dy = 0, 1 end
    end
    return (dy < 0) and (math.abs(dy) > math.abs(dx))
end

-- Compute the visual/screen-space offset of the character's outstretched Power Ring hand (for lasers & flares)
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
            return Vector(18, -14)  -- Outstretched right ring hand clearly in front of player
        else
            return Vector(-18, -14) -- Outstretched left ring hand clearly in front of player
        end
    else
        if dy >= 0 then
            return Vector(6, -6)    -- Outstretched ring hand aiming down in front of body
        else
            return Vector(0, -32)   -- Centered behind the head when aiming up so the beam never overlaps or bleeds past the head/neck
        end
    end
end

-- Compute the ground-plane spawn offset for EntityTear beams.
-- Note: EntityTear already renders at (Position.Y + Height * 0.65) where Height = -23.75 (~-15.4px screen Y).
local function GetRingBeamTearSpawnOffset(player, fireVel)
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

    local dir = Vector(dx, dy)
    if dir:Length() > 0.01 then
        dir = dir:Normalized()
    else
        dir = Vector(0, 1)
    end

    if math.abs(dx) >= math.abs(dy) then
        local sideX = (dx >= 0) and 18 or -18
        return Vector(sideX, 3) + dir * 4
    else
        if dy >= 0 then
            return Vector(6, 12) + dir * 4
        else
            return Vector(0, -24) + dir * 6
        end
    end
end

-- Transform a tear into an intense comic-book Green Lantern energy beam originating from the Ring
local function ApplyRingBeamSprite(tear, scaleMult)
    if not tear then return end
    pcall(function()
        -- Ensure piercing tear variant is set BEFORE loading gl_ring_beam.anm2 so C++ EntityTear::Update()
        -- never calls ChangeVariant(CUPID_BLUE) on Frame 1 and overwrites gl_ring_beam.anm2 with a vanilla circle tear!
        if TearVariant and TearVariant.CUPID_BLUE and TearVariant.BLUE and tear.Variant == TearVariant.BLUE then
            if tear.ChangeVariant then
                tear:ChangeVariant(TearVariant.CUPID_BLUE)
            else
                tear.Variant = TearVariant.CUPID_BLUE
            end
        end
        tear.DepthOffset = IsAimingUp(nil, tear.Velocity) and -20 or 25
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
        if tear.Velocity and tear.Velocity:Length() > 0.1 then
            td.glBeamVel = Vector(tear.Velocity.X, tear.Velocity.Y)
        end
    end)
end

-- Ensure Tainted Hal NEVER has Red Heart Containers (or Bone/Red/Rotten hearts) and NEVER converts red hearts into Black Hearts
local function EnforceTaintedHalNoRedHearts(player)
    if not IsTaintedHal(player) then return end
    pcall(function()
        local removedContainer = false
        local maxHearts = player:GetMaxHearts()
        if maxHearts and maxHearts > 0 then
            player:AddMaxHearts(-maxHearts, true)
            removedContainer = true
        end
        if player.GetBoneHearts and player.AddBoneHearts then
            local boneHearts = player:GetBoneHearts()
            if boneHearts and boneHearts > 0 then
                player:AddBoneHearts(-boneHearts)
                removedContainer = true
            end
        end
        local redHearts = player:GetHearts()
        if redHearts and redHearts > 0 then
            player:AddHearts(-redHearts)
        end
        if player.GetRottenHearts and player.AddRottenHearts then
            local rottenHearts = player:GetRottenHearts()
            if rottenHearts and rottenHearts > 0 then
                player:AddRottenHearts(-rottenHearts)
            end
        end
        -- Only grant a safety Black Heart if stripping a Red/Bone Heart Container left the player with 0 Soul/Black hearts
        -- (never trigger during normal combat death when removedContainer is false!)
        if removedContainer and (player:GetSoulHearts() or 0) <= 0 then
            player:AddBlackHearts(2)
        end
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

-- Power down Hal Jordan's Green Lantern Ring when Willpower reaches 0% (loses ring construct capabilities, fights with normal un-nerfed human tears)
local function TriggerHalRingDepleted(player)
    if not player or not IsHalJordan(player) then return end
    local data = GetPlayerData(player)
    data.ringDepleted             = true
    data.willpower                = 0
    data.overcharge               = false
    data.surgeBuff                = false
    data.continuousBeamGraceTimer = 0
    data.shootHoldFrames          = 0
    data.firedSmallBeamThisPress  = false
    data.bufferedClickDir         = nil
    data.allowingTapTear          = false
    data.ringFlareTimer           = 0
    data.oathTextTimer            = 95
    data.oathText                 = "RING OFFLINE! FIGHT ON!"
    StopContinuousBeam(data)
    pcall(function()
        local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYDISCHARGE or SoundEffect.SOUND_THUMBS_DOWN)) or 0
        if sfx > 0 then
            SFXManager():Play(sfx, 0.85, 0, false, 0.95)
        end
        local handPos = player.Position + (data.lastRingHandOffset or Vector(18, -14))
        local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, handPos, Vector.Zero, player)
        SetEntityScaleAndColor(fx, 0.65, Color(0.2, 1.0, 0.4, 0.9, 0.15, 0.65, 0.2))
    end)
    pcall(function()
        player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
        player:EvaluateItems()
    end)
    RefreshCharacterCostume(player)
end

-- Restore Hal Jordan's Green Lantern Ring power and cleanly reset shooting state so discrete left-click beams fire straight & true
local function RestoreHalRingPower(player, newWillpower, statusText)
    if not player or not IsHalJordan(player) then return end
    local data = GetPlayerData(player)
    local wasDepleted = data.ringDepleted
    data.willpower    = math.max(0.0, math.min(WILLPOWER_MAX, newWillpower or WILLPOWER_MAX))
    data.ringDepleted = (data.willpower <= 0)
    if wasDepleted and not data.ringDepleted then
        data.shootHoldFrames          = 0
        data.firedSmallBeamThisPress  = false
        data.bufferedClickDir         = nil
        data.allowingTapTear          = false
        data.continuousBeamGraceTimer = 0
        data.ringFlareTimer           = 16
        data.oathTextTimer            = 90
        data.oathText                 = statusText or "RING REBOOTED!"
        StopContinuousBeam(data)
        pcall(function()
            local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYCHARGE or SoundEffect.SOUND_SUPERHOLY)) or 0
            if sfx > 0 then
                SFXManager():Play(sfx, 0.85, 0, false, 1.08)
            end
            local handPos = player.Position + (data.lastRingHandOffset or Vector(18, -14))
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, handPos, Vector.Zero, player)
            SetEntityScaleAndColor(fx, 0.70, Color(0.15, 1.0, 0.45, 0.95, 0.2, 0.85, 0.3))
        end)
    end
    pcall(function()
        player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
        player:EvaluateItems()
    end)
    RefreshCharacterCostume(player)
end

-- ---------------------------------------------------------------------------
-- SECTION 4: GAME & PLAYER INITIALIZATION
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
    LoadItemIDs()
    activeCoastCity.active = false
    ClearAllLanternEmblemDrops()
end)

GL:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
    LoadItemIDs()

    -- HAL JORDAN INIT
    if IsHalJordan(player) then
        local data = GetPlayerData(player)
        data.willpower                = WILLPOWER_MAX
        data.ringDepleted             = false
        data.overcharge               = false
        data.surgeBuff                = false
        data.overchargeRoomIdx        = -1
        data.shootHoldFrames          = 0
        data.lastSmallBeamFrame       = -999
        data.firedSmallBeamThisPress  = false
        data.lastShootDir             = nil
        data.bufferedClickDir         = nil
        data.bufferedClickExpireFrame = 0
        data.isFiringContinuousBeam   = false
        data.spawningContinuousBeam   = false
        data.continuousLaser          = nil
        data.continuousBeamGraceTimer = 0
        data.allowingTapTear          = false
        pcall(function()
            player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
            player:EvaluateItems()
        end)
        RefreshCharacterCostume(player)
    end

    -- TAINTED HAL INIT
    if IsTaintedHal(player) then
        local data = GetPlayerData(player)
        data.emeraldSparks            = 0.0
        data.stolenRings              = 0
        data.coastCityActive          = false
        data.coastCityFrame           = 0
        data.shootHoldFrames          = 0
        data.lastSmallBeamFrame       = -999
        data.firedSmallBeamThisPress  = false
        data.lastShootDir             = nil
        data.bufferedClickDir         = nil
        data.bufferedClickExpireFrame = 0
        data.isFiringContinuousBeam   = false
        data.spawningContinuousBeam   = false
        data.continuousLaser          = nil
        data.continuousBeamGraceTimer = 0
        data.allowingTapTear          = false
        EnforceTaintedHalNoRedHearts(player)
        pcall(function()
            player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
            player:EvaluateItems()
        end)
        RefreshCharacterCostume(player)
    end
end)

GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    local data = GetPlayerData(player)
    if IsTaintedHal(player) then
        EnforceTaintedHalNoRedHearts(player)
    end
    if not data.initializedStartingItems then
        data.initializedStartingItems = true
        pcall(function()
            if IsHalJordan(player) then
                if player:GetSoulHearts() < 2 then
                    player:AddSoulHearts(2) -- 1 full soul heart
                end
                -- Grant starting Green Lantern Ring passive equipment + Power Battery active (4-room charge)
                if ITEM_POWER_RING and ITEM_POWER_RING > 0 and not player:HasCollectible(ITEM_POWER_RING) then
                    player:AddCollectible(ITEM_POWER_RING, 0, false)
                end
                if ITEM_POWER_BATTERY and ITEM_POWER_BATTERY > 0 and not player:HasCollectible(ITEM_POWER_BATTERY) then
                    player:AddCollectible(ITEM_POWER_BATTERY, 4, false, ActiveSlot.SLOT_PRIMARY)
                end
                RefreshCharacterCostume(player)
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            elseif IsTaintedHal(player) then
                EnforceTaintedHalNoRedHearts(player)
                if (player:GetSoulHearts() or 0) <= 0 then
                    player:AddBlackHearts(6) -- Ensure 3 starting Black Hearts if spawned/switched via console
                end
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

    -- HAL JORDAN RING LOCKOUT & WILLPOWER REBOOT MECHANIC:
    -- At 0% Willpower, Hal loses the ability to use the Power Ring (human mode, normal un-nerfed tears)
    -- while his Willpower steadily recharges through resolve (+passive regen, +enemy kills, +room clears, or battery).
    -- Once Willpower reaches WILLPOWER_REBOOT_THRESHOLD (20%), the Power Ring automatically reboots!
    if IsHalJordan(player) and data.ringDepleted then
        local frame = Game():GetFrameCount()
        if data.lastDepletedRegenFrame ~= frame then
            data.lastDepletedRegenFrame = frame
            data.willpower = math.min(WILLPOWER_MAX, (data.willpower or 0) + WILLPOWER_PASSIVE_REBOOT_RATE)
            if data.willpower >= WILLPOWER_REBOOT_THRESHOLD then
                RestoreHalRingPower(player, data.willpower, "RING REBOOTED!")
            end
        end
    end

    -- DUAL FIRING MODE FOR BOTH HAL JORDAN AND TAINTED HAL (PARALLAX):
    -- 1) Clicking / tapping (< HAL_CONTINUOUS_HOLD_FRAMES): fires high-damage discrete Ring Beam constructs.
    -- 2) Genuinely holding the shoot button (>= HAL_CONTINUOUS_HOLD_FRAMES): channels an unbroken continuous emerald laser beam.
    if IsHalJordan(player) or IsTaintedHal(player) then
        local frame = Game():GetFrameCount()
        if data.lastSmallBeamFrame and frame < data.lastSmallBeamFrame then
            data.lastSmallBeamFrame = -999
        end

        local shootInput = player:GetShootingInput()
        local isHoldingShoot = shootInput and shootInput:Length() > 0.1

        if isHoldingShoot and CanUseContinuousBeam(player) then
            local rawDir     = shootInput:Normalized()
            local shootDir   = Vector(rawDir.X, rawDir.Y)
            local handOffset = GetRingHandOffset(player, shootDir)
            data.lastShootDir       = shootDir
            data.lastRingHandOffset = handOffset

            if (data.shootHoldFrames or 0) == 0 then
                data.firedSmallBeamThisPress = false
            end

            -- Only skip hold warmup if the player was actively channeling the continuous beam and switched to a DIFFERENT
            -- cardinal shoot direction within 4 ticks (never when spamming clicks in the same direction!).
            local switchedBeamDir = false
            if (data.continuousBeamGraceTimer or 0) > 0 and data.lastContinuousBeamDir then
                local dot = shootDir.X * data.lastContinuousBeamDir.X + shootDir.Y * data.lastContinuousBeamDir.Y
                if dot < 0.75 then
                    switchedBeamDir = true
                end
            end

            if switchedBeamDir then
                data.shootHoldFrames = math.max((data.shootHoldFrames or 0) + 1, HAL_CONTINUOUS_HOLD_FRAMES)
            else
                data.shootHoldFrames = (data.shootHoldFrames or 0) + 1
            end

            if data.shootHoldFrames < HAL_CONTINUOUS_HOLD_FRAMES then
                -- Hold native FireDelay during the tap-vs-hold detection window so holding NEVER fires a discrete tear bolt first!
                player.FireDelay    = math.max(player.FireDelay, 2)
                data.ringFlareTimer = math.max(data.ringFlareTimer or 0, 3)
            else
                data.isFiringContinuousBeam   = true
                data.continuousBeamGraceTimer = 4
                data.lastContinuousBeamDir    = Vector(shootDir.X, shootDir.Y)
                data.bufferedClickDir         = nil
                -- Suppress discrete tear projectiles while channeling the continuous emerald laser beam
                player.FireDelay    = math.max(player.FireDelay, 5)
                data.ringFlareTimer = 4

                -- Tick continuous emerald beam damage every HAL_CONTINUOUS_TICK_FRAMES (4) frames directly in Lua (spectral over rocks, stops at walls)
                if frame % HAL_CONTINUOUS_TICK_FRAMES == 0 then
                    local startWorld = player.Position + handOffset
                    local endWorld   = ComputeContinuousBeamEndWorld(startWorld, shootDir)
                    local dmgStart   = IsAimingUp(player, shootDir) and (player.Position + Vector(0, -8)) or startWorld
                    TickContinuousBeamDamage(player, data, dmgStart, endWorld)
                end

                -- Drain Willpower smoothly when Hal Jordan channels the continuous beam
                if IsHalJordan(player) then
                    local drain = HAL_CONTINUOUS_WILL_DRAIN
                    if CollectibleType and CollectibleType.COLLECTIBLE_SOY_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_SOY_MILK) then
                        drain = drain * 0.35
                    elseif CollectibleType and CollectibleType.COLLECTIBLE_ALMOND_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) then
                        drain = drain * 0.40
                    end

                    local prevWillBucket = math.floor((data.willpower or WILLPOWER_MAX) + 0.5)
                    data.willpower = math.max(0, (data.willpower or WILLPOWER_MAX) - drain)
                    local newWillBucket = math.floor(data.willpower + 0.5)

                    if data.willpower <= 0 then
                        TriggerHalRingDepleted(player)
                    elseif newWillBucket ~= prevWillBucket then
                        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                        player:EvaluateItems()
                    end
                end
            end
        else
            if (data.continuousBeamGraceTimer or 0) > 0 then
                data.continuousBeamGraceTimer = data.continuousBeamGraceTimer - 1
                if data.continuousBeamGraceTimer <= 0 then
                    data.lastContinuousBeamDir = nil
                end
            end

            -- If player clicked/tapped & released (< HAL_CONTINUOUS_HOLD_FRAMES), buffer the discrete Ring Beam shot so it fires cleanly
            if (data.shootHoldFrames or 0) > 0
                and data.shootHoldFrames < HAL_CONTINUOUS_HOLD_FRAMES
                and not data.firedSmallBeamThisPress
                and data.lastShootDir
                and CanUseContinuousBeam(player)
            then
                data.bufferedClickDir         = Vector(data.lastShootDir.X, data.lastShootDir.Y)
                data.bufferedClickExpireFrame = frame + 15
            end

            if data.isFiringContinuousBeam or data.continuousLaser then
                StopContinuousBeam(data)
            end
            data.shootHoldFrames         = 0
            data.firedSmallBeamThisPress = false
        end

        -- Fire any buffered tap/click shot as soon as minimum click interval is reached (even if rapid-clicking started the next press!)
        if data.bufferedClickDir and not data.isFiringContinuousBeam then
            if frame > (data.bufferedClickExpireFrame or 0) or not CanUseContinuousBeam(player) then
                data.bufferedClickDir = nil
            else
                local minClickInterval = math.max(3, math.min(7, math.floor((player.MaxFireDelay or 10) * 0.55)))
                if (frame - (data.lastSmallBeamFrame or -999)) >= minClickInterval then
                    local dir = Vector(data.bufferedClickDir.X, data.bufferedClickDir.Y)
                    data.bufferedClickDir    = nil
                    data.lastSmallBeamFrame  = frame
                    local spawnOffset        = GetRingBeamTearSpawnOffset(player, dir)
                    local shotSpeed          = math.max(6.0, (player.ShotSpeed or 1.0) * 10.0)
                    local shotCount          = GetTapTearCount(player)
                    data.allowingTapTear     = true
                    data.firingBufferedClick = true
                    data.tapBurstCount       = shotCount
                    data.tapBurstBaseDir     = dir
                    pcall(function()
                        for sIdx = 1, shotCount do
                            data.tapBurstIndex = sIdx
                            local shotDir = dir
                            if shotCount >= 3 and dir.Rotated then
                                local spreadDeg = (sIdx - (shotCount + 1) * 0.5) * 3.5
                                shotDir = dir:Rotated(spreadDeg)
                            end
                            local vel = shotDir * shotSpeed
                            pcall(function()
                                vel = vel + player:GetTearMovementInheritance(shotDir)
                            end)
                            player:FireTear(player.Position + spawnOffset, vel, false, false, false)
                        end
                    end)
                    data.allowingTapTear     = false
                    data.firingBufferedClick = false
                    data.tapBurstCount       = nil
                    data.tapBurstIndex       = nil
                    data.tapBurstBaseDir     = nil
                    player.FireDelay         = math.max(player.MaxFireDelay or 10, 2)
                end
            end
        end

        -- Always keep native FireDelay >= 2 (even while idle!) whenever CanUseContinuousBeam(player) is true,
        -- so C++ EntityPlayer::Update() NEVER auto-fires an unbuffered discrete tear on Frame 1 when starting to hold shoot!
        if CanUseContinuousBeam(player) then
            player.FireDelay = math.max(player.FireDelay, 2)
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
            if not data.ringDepleted then
                -- While the Power Ring is active, scale damage from 1.00x -> 1.15x (+0.10 peak bonus = 1.25x at 100% Willpower)
                local will = data.willpower or WILLPOWER_MAX
                local willRatio = math.max(0.0, math.min(1.0, will / WILLPOWER_MAX))
                local willMult = 1.00 + (0.15 * willRatio)
                if will >= 99.5 then
                    willMult = willMult + 0.10 -- 1.25x DMG at 100% Willpower!
                end
                player.Damage = player.Damage * willMult
            end
            -- When ringDepleted is true, Hal loses the ability to use the Ring (no ring bonus, but NO harsh 50% damage nerf!)
        end

        if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
            if not data.ringDepleted then
                player.ShotSpeed = player.ShotSpeed + HAL_SHOT_SPEED_BONUS
            end
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

    -- TAINTED HAL STATS (no passive or active damage scaling from Emblem meter / Coast City)
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
            player.TearFlags = player.TearFlags | TearFlags.TEAR_FEAR | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        end
    end

    -- POWER BATTERY OVERCHARGE (applies to Hal Jordan when activating Power Battery at >=50% Willpower)
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        if IsHalJordan(player) and not data.ringDepleted and data.overcharge and data.overchargeRoomIdx == roomIdx then
            player.Damage = player.Damage * 1.15
        end
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        if not (IsHalJordan(player) and data.ringDepleted) and (data.overcharge or data.surgeBuff) and data.overchargeRoomIdx == roomIdx then
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

    -- When Hal's ring is depleted (0% Willpower lockout), he loses the ability to use the Power Ring and fires normal tears!
    if not IsRingActive(player) then return end

    local data = GetPlayerData(player)

    -- Suppress unbuffered C++ tears when CanUseContinuousBeam(player) is active (so holding shoot never fires a Frame-1 discrete bolt!)
    if IsHalJordan(player) or IsTaintedHal(player) then
        local td = tear:GetData()
        if not (td and td.isGiantFist) then
            if data.isFiringContinuousBeam or (CanUseContinuousBeam(player) and not data.allowingTapTear) then
                tear:Remove()
                return
            end
        end
    end

    local frame = Game():GetFrameCount()
    if IsHalJordan(player) or IsTaintedHal(player) then
        data.lastSmallBeamFrame = frame
        if not data.firingBufferedClick then
            data.firedSmallBeamThisPress = true
            data.bufferedClickDir        = nil
        end
    end

    -- Multi-shot fan offset (20/20, Inner Eye, Mutant Spider, Monstro's Lung, Conjoined)
    if data.multiShotFrame == frame then
        data.multiShotIndex = (data.multiShotIndex or 0) + 1
    else
        data.multiShotFrame = frame
        data.multiShotIndex = 0
    end

    -- 1. Snap projectile spawn position to the outstretched Power Ring hand!
    local baseDir     = (data.allowingTapTear and data.tapBurstBaseDir) or tear.Velocity
    local handOffset  = GetRingHandOffset(player, baseDir)
    local spawnOffset = GetRingBeamTearSpawnOffset(player, baseDir)
    local perpOffset  = Vector.Zero
    if data.allowingTapTear and (data.tapBurstCount or 1) > 1 and baseDir:Length() > 0.1 then
        local dir        = baseDir:Normalized()
        local perp       = Vector(-dir.Y, dir.X)
        local laneOffset = (data.tapBurstIndex or 1) - ((data.tapBurstCount or 1) + 1) * 0.5
        perpOffset       = perp * math.max(-14.0, math.min(14.0, laneOffset * 5.5))
    elseif data.multiShotIndex > 0 and tear.Velocity:Length() > 0.1 then
        local dir = tear.Velocity:Normalized()
        local perp = Vector(-dir.Y, dir.X)
        local side = (data.multiShotIndex % 2 == 1) and 1 or -1
        local tier = math.ceil(data.multiShotIndex / 2)
        perpOffset = perp * (side * math.min(tier * 5.5, 14.0))
    end

    tear.Position     = player.Position + spawnOffset + perpOffset
    tear.DepthOffset  = IsAimingUp(player, baseDir) and -20 or 25
    if baseDir and baseDir:Length() > 0.01 then
        local normDir = baseDir:Normalized()
        data.lastShootDir = Vector(normDir.X, normDir.Y)
    end
    data.lastRingHandOffset = handOffset
    data.ringFlareTimer     = 6

    -- Grant Piercing (pass through enemies) + Spectral (pass through rocks/objects)
    tear.TearFlags = tear.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
    if IsTaintedHal(player) then
        tear.TearFlags = tear.TearFlags | TearFlags.TEAR_FEAR
    end

    -- Synergy scale adjustments (Chocolate Milk, Monstro's Lung, Ipecac, Haemolacria, Soy/Almond Milk)
    local sizeFactor = math.max(0.65, math.min(1.85, tear.Scale or 1.0))

    -- 2. HAL JORDAN WILLPOWER & BEAM SCALING
    if IsHalJordan(player) then
        local baseScale = data.overcharge and 1.20 or (data.surgeBuff and 1.10 or 1.0)
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
        data.willpower = math.max(0, (data.willpower or WILLPOWER_MAX) - drain)
        local newWillBucket = math.floor(data.willpower + 0.5)

        local isFinalBurstTear = (not data.allowingTapTear) or ((data.tapBurstIndex or 1) >= (data.tapBurstCount or 1))
        if data.willpower <= 0 and isFinalBurstTear then
            TriggerHalRingDepleted(player)
        elseif newWillBucket ~= prevWillBucket and isFinalBurstTear then
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
            player:EvaluateItems()
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

-- Keep all Green Lantern Ring energy beams oriented along their straight flight vector and prevent C++ sprite/variant resets
GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
    local td = tear:GetData()
    if not (td and td.isGLRingBeam) then return end

    tear.DepthOffset = IsAimingUp(nil, tear.Velocity) and -20 or 25

    -- Keep discrete Ring Beam bolts flying straight (prevents post-depletion curve/circle artifacts unless homing/orbit is active)
    local flags = tear.TearFlags
    local hasCurvingSynergy = false
    if TearFlags then
        if (TearFlags.TEAR_HOMING and (flags & TearFlags.TEAR_HOMING) ~= 0)
            or (TearFlags.TEAR_ORBIT and (flags & TearFlags.TEAR_ORBIT) ~= 0)
            or (TearFlags.TEAR_BOOMERANG and (flags & TearFlags.TEAR_BOOMERANG) ~= 0)
            or (TearFlags.TEAR_SPIRAL and (flags & TearFlags.TEAR_SPIRAL) ~= 0)
            or (TearFlags.TEAR_WIGGLE and (flags & TearFlags.TEAR_WIGGLE) ~= 0)
        then
            hasCurvingSynergy = true
        end
    end
    if not hasCurvingSynergy and td.glBeamVel and td.glBeamVel:Length() > 0.1 and tear.Velocity:Length() > 0.1 then
        local currentSpeed = tear.Velocity:Length()
        tear.Velocity = td.glBeamVel:Normalized() * currentSpeed
    end

    local ts = tear:GetSprite()
    if ts then
        if ts:GetAnimation() ~= "Idle" then
            ts:Load("gfx/effects/gl_ring_beam.anm2", true)
            ts:Play("Idle", true)
        end
        if td.glBeamScale then
            ts.Scale = Vector(td.glBeamScale, td.glBeamScale)
        end
        ts.Color = Color(1, 1, 1, 1, 0, 0, 0)
        if tear.Velocity:Length() > 0.1 then
            ts.Rotation = tear.Velocity:GetAngleDegrees()
        end
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
        SetEntityScaleAndColor(fx, 0.70, Color(0.1, 1.0, 0.35, 0.9, 0.15, 0.85, 0.25))
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 6B: GREEN LANTERN RING ITEM SYNERGIES (Tint + Piercing/Spectral Only)
-- ---------------------------------------------------------------------------

-- 1. LASER SYNERGIES: Brimstone, Tech X, Technology, Technology 2, Tech.5, Jacob's Ladder
GL:AddCallback(ModCallbacks.MC_POST_LASER_INIT, function(_, laser)
    local spawner = laser.SpawnerEntity
    local player = spawner and spawner:ToPlayer()
    if not player or not IsRingActive(player) then return end

    local ld = laser:GetData()
    local data = GetPlayerData(player)

    -- Handle Hal Jordan / Tainted Hal held continuous Ring Beam (lower damage than small beams)
    if data.spawningContinuousBeam or ld.isGLContinuousBeam then
        ld.isGLContinuousBeam   = true
        ld.glLaserSynergyInit   = true
        pcall(function()
            laser.DepthOffset       = 35
            laser.CollisionDamage   = player.Damage * HAL_CONTINUOUS_BEAM_DMG_MULT
            local flags             = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            if IsTaintedHal(player) then
                flags = flags | TearFlags.TEAR_FEAR
            end
            laser.TearFlags         = flags
            local lSpr              = laser:GetSprite()
            if lSpr then
                lSpr:SetFrame(0)
                lSpr.Color = Color(0.1, 1.0, 0.38, 0.0, 0, 0, 0)
            end
        end)
        data.ringFlareTimer     = 4
        return
    end

    if ld.glLaserSynergyInit then return end
    ld.glLaserSynergyInit = true

    data.ringFlareTimer = 8

    -- Tint all player lasers into blazing Hard-Light Emerald Construct Beams!
    laser.DepthOffset     = 35
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
                TriggerHalRingDepleted(player)
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
    if not player or not IsRingActive(player) then return end

    local ld = laser:GetData()
    local data = GetPlayerData(player)
    data.ringFlareTimer = 4
    laser.DepthOffset   = 35
    if ld and ld.isGLContinuousBeam then
        pcall(function()
            laser.Timeout           = 60
            laser:SetTimeout(60)
            laser.OneHit            = false
            laser:SetOneHit(false)
            laser.CollisionDamage   = player.Damage * HAL_CONTINUOUS_BEAM_DMG_MULT
            local flags             = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            if IsTaintedHal(player) then
                flags = flags | TearFlags.TEAR_FEAR
            end
            laser.TearFlags         = flags
            local lSpr              = laser:GetSprite()
            if lSpr then
                lSpr:SetFrame(0)
                lSpr.Color = Color(0.1, 1.0, 0.38, 0.0, 0, 0, 0)
            end
        end)
    else
        laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
    end
end)

-- Throttle any legacy continuous beam EntityLaser hit frequency (once every HAL_CONTINUOUS_TICK_FRAMES = 4 frames per enemy)
GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
    if not entity or not entity:IsActiveEnemy(false) then return end
    if (flags & DamageFlag.DAMAGE_LASER) == 0 then return end
    if not (source and source.Entity) then return end

    local srcData = source.Entity.GetData and source.Entity:GetData()
    if not (srcData and srcData.isGLContinuousBeam) then return end

    local ed = entity:GetData()
    local frame = Game():GetFrameCount()
    if ed.lastGLContBeamHitFrame and frame >= ed.lastGLContBeamHitFrame and (frame - ed.lastGLContBeamHitFrame) < HAL_CONTINUOUS_TICK_FRAMES then
        return false
    end
    ed.lastGLContBeamHitFrame = frame
end)

-- 2. MOM'S KNIFE SYNERGY: Hard-Light Emerald Energy Blade
GL:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, knife)
    local spawner = knife.SpawnerEntity
    local player = spawner and spawner:ToPlayer()
    if not player or not IsRingActive(player) then return end

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

    -- 1. Always refill Willpower to 100% and restore ring power cleanly
    data.overchargeRoomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- 2. If used by Hal Jordan at >= 50% Willpower (and not depleted), grant modest OVERCHARGE (+15% DMG for the room).
    --    Otherwise, simply restore Willpower & Ring capabilities without a bonus damage multiplier.
    local statusMsg = "WILLPOWER RESTORED!"
    if IsHalJordan(player) and (not wasDepleted) and prevWill >= 50.0 then
        data.overcharge = true
        data.surgeBuff  = false
        statusMsg       = "OVERCHARGE! (+15% DMG)"
    else
        data.overcharge = false
        data.surgeBuff  = true
    end
    RestoreHalRingPower(player, WILLPOWER_MAX, statusMsg)

    -- 3. Modest close-range pulse: light damage & knockback to nearby enemies and clear close projectiles
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        local dist = (ent.Position - player.Position):Length()
        if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() and dist <= 105 then
            ent:TakeDamage(player.Damage * 1.0 + 3.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
            local push = (ent.Position - player.Position)
            if push:Length() > 0.1 then
                ent.Velocity = ent.Velocity + push:Normalized() * 9.0
            end
        elseif ent.Type == EntityType.ENTITY_PROJECTILE and dist <= 115 then
            ent:Die()
        end
    end

    player:AnimateHappy()
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

    local spawnOffset  = GetRingBeamTearSpawnOffset(player, direction)
    local fistVelocity = direction * 20.0
    local tearVar      = (TearVariant and TearVariant.TOOTH) or 0
    local ent = Isaac.Spawn(
        EntityType.ENTITY_TEAR,
        tearVar,
        0,
        player.Position + spawnOffset + direction * 10,
        fistVelocity,
        player
    )
    local fist = ent and ent:ToTear()

    if fist then
        fist.DepthOffset     = IsAimingUp(player, direction) and -20 or 25
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

    -- Stored Green Lantern Emblems slightly extend vortex duration & pull (NEVER increases player Damage!)
    local sparkRatio = math.max(0.0, math.min(1.0, (data.emeraldSparks or 0.0) / SPARK_MAX))
    local sparkBonus = 1.0 + sparkRatio * 0.20
    local durationBonus = math.floor(sparkRatio * 45) -- up to +1.5s vortex duration at full meter
    data.coastCityBoost  = 1.0
    data.emeraldSparks   = 0.0
    data.coastCityActive = true
    data.coastCityFrame  = Game():GetFrameCount()
    data.ringFlareTimer  = 14

    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- Store 5-second vortex state in persistent Lua table (no middle-of-the-room POOF01/CRACK_THE_SKY particles!)
    activeCoastCity.active        = true
    activeCoastCity.spawnFrame    = Game():GetFrameCount()
    activeCoastCity.roomIdx       = roomIdx
    activeCoastCity.owner         = player
    activeCoastCity.sparkBonus    = sparkBonus
    activeCoastCity.totalDuration = COAST_CITY_DURATION + durationBonus

    pcall(function()
        SFXManager():Play(SoundEffect.SOUND_SUPERHOLY, 0.85, 0, false, 0.88)
    end)

    -- Inflict Fear (3s) and a light 0.50x DMG pulse to vulnerable enemies in the room
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            ent:AddFear(EntityRef(player), 90)
            ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
            ent:TakeDamage(player.Damage * 0.50, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
        end
    end

    player:AnimateHappy()
    return true
end)

-- Coast City logic: gently pull vulnerable enemies toward center & deal light pulsing damage for 5 seconds (no center dust particles!)
GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    if not activeCoastCity.active then return end

    local currentFrame = Game():GetFrameCount()
    local roomIdx      = Game():GetLevel():GetCurrentRoomIndex()
    local age          = currentFrame - (activeCoastCity.spawnFrame or currentFrame)
    local maxDuration  = activeCoastCity.totalDuration or COAST_CITY_DURATION

    if roomIdx ~= activeCoastCity.roomIdx or age > maxDuration then
        activeCoastCity.active = false
        for i = 0, Game():GetNumPlayers() - 1 do
            local p = Isaac.GetPlayer(i)
            if IsTaintedHal(p) then
                GetPlayerData(p).coastCityActive = false
            end
        end
        return
    end

    local room        = Game():GetRoom()
    local center      = room:GetCenterPos()
    local ownerPlayer = activeCoastCity.owner or Isaac.GetPlayer(0)
    local sparkBonus  = activeCoastCity.sparkBonus or 1.0

    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
        if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
            local isFeared = enemy:HasEntityFlags(EntityFlag.FLAG_FEAR)
            local toCenter = (center - enemy.Position)
            local dist     = toCenter:Length()

            -- Pull vulnerable enemies within 250px gently toward the center
            if dist > 18 and dist <= 250 then
                local pullMult = isFeared and 1.15 or 1.0
                local pullStr  = math.min(3.8, 140.0 / math.max(dist, 22)) * pullMult * sparkBonus
                enemy.Velocity = enemy.Velocity * 0.85 + toCenter:Normalized() * pullStr
            end

            -- Deal light vortex damage every 25 frames
            if age > 0 and age % 25 == 0 and ownerPlayer and dist <= 220 then
                enemy:AddFear(EntityRef(ownerPlayer), 45)
                enemy:AddEntityFlags(EntityFlag.FLAG_FEAR)
                local distMult = (dist <= 100) and 0.35 or 0.20
                local dmg = ownerPlayer.Damage * distMult * sparkBonus
                enemy:TakeDamage(dmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(ownerPlayer), 0)
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
-- SECTION 10: TAINTED HAL — NO RED HEART CONTAINERS & NO RED HEART PICKUPS
-- ---------------------------------------------------------------------------

if ModCallbacks.MC_POST_PEFFECT_UPDATE then
    GL:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
        if IsTaintedHal(player) then
            EnforceTaintedHalNoRedHearts(player)
        end
    end)
end

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsTaintedHal(player) then
            EnforceTaintedHalNoRedHearts(player)
        end
    end
end)

-- Block Tainted Hal from ever picking up red or bone hearts on the ground
GL:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, pickup, collider, low)
    if pickup.Variant ~= PickupVariant.PICKUP_HEART then return end
    local player = collider and collider:ToPlayer()
    if not player or not IsTaintedHal(player) then return end

    EnforceTaintedHalNoRedHearts(player)

    local sub = pickup.SubType
    local isRedOnlyHeart = (sub == HeartSubType.HEART_FULL)
        or (sub == HeartSubType.HEART_HALF)
        or (sub == HeartSubType.HEART_DOUBLEPACK)
        or (HeartSubType.HEART_SCARED and sub == HeartSubType.HEART_SCARED)
        or (HeartSubType.HEART_ROTTEN and sub == HeartSubType.HEART_ROTTEN)
        or (HeartSubType.HEART_BONE and sub == HeartSubType.HEART_BONE)

    if isRedOnlyHeart then
        return true
    end
end)

-- ---------------------------------------------------------------------------
-- SECTION 11: TAINTED HAL — GREEN LANTERN EMBLEM (EMERALD SPARK) SYSTEM
-- ---------------------------------------------------------------------------

-- Only spawn Green Lantern Emblem drops on actual enemy deaths (never on room transitions),
-- with a significantly reduced drop rate (14% on Feared enemies, 8% on normal enemies).
-- Also: if Hal Jordan's ring is depleted, defeating enemies with normal tears fuels his resolve (+5% Willpower per kill) to reboot the ring faster!
GL:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc)
    if not npc or not npc:IsEnemy() or not npc:IsActiveEnemy(true) or (npc.MaxHitPoints and npc.MaxHitPoints <= 1) then return end

    local hasTaintedHal = false
    for i = 0, Game():GetNumPlayers() - 1 do
        local p = Isaac.GetPlayer(i)
        if IsTaintedHal(p) then
            hasTaintedHal = true
        elseif IsHalJordan(p) then
            local d = GetPlayerData(p)
            if d.ringDepleted then
                d.willpower = math.min(WILLPOWER_MAX, (d.willpower or 0) + WILLPOWER_KILL_REBOOT_BONUS)
                if d.willpower >= WILLPOWER_REBOOT_THRESHOLD then
                    RestoreHalRingPower(p, d.willpower, "RING REBOOTED!")
                end
            end
        end
    end
    if not hasTaintedHal then return end

    local dropChance = npc:HasEntityFlags(EntityFlag.FLAG_FEAR) and SPARK_DROP_CHANCE_FEARED or SPARK_DROP_CHANCE_NORMAL
    if math.random() < dropChance then
        SpawnLanternEmblemDrop(npc.Position)
    end
end)

-- Clearing a room while Hal's ring is depleted surges his willpower (+15%) to immediately help reboot the Power Ring!
if ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then
    GL:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, function(_)
        for i = 0, Game():GetNumPlayers() - 1 do
            local p = Isaac.GetPlayer(i)
            if IsHalJordan(p) then
                local d = GetPlayerData(p)
                if d.ringDepleted then
                    d.willpower = math.min(WILLPOWER_MAX, (d.willpower or 0) + WILLPOWER_ROOM_REBOOT_BONUS)
                    if d.willpower >= WILLPOWER_REBOOT_THRESHOLD then
                        RestoreHalRingPower(p, d.willpower, "RING REBOOTED!")
                    end
                end
            end
        end
    end)
end

GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    if #activeEmeraldSparks == 0 then return end

    local currentFrame   = Game():GetFrameCount()
    local currentRoomIdx = Game():GetLevel():GetCurrentRoomIndex()

    for idx = #activeEmeraldSparks, 1, -1 do
        local sp = activeEmeraldSparks[idx]
        if not sp or sp.roomIdx ~= currentRoomIdx then
            table.remove(activeEmeraldSparks, idx)
        elseif sp.collected then
            -- Play out the 12-frame coin/bomb style pickup animation, then remove!
            local collectAge = currentFrame - (sp.collectFrame or currentFrame)
            if collectAge < 0 or collectAge >= SPARK_COLLECT_FRAMES then
                table.remove(activeEmeraldSparks, idx)
            end
        else
            -- 1. Check walk-over pickup FIRST so any visible emblem on the floor immediately triggers pickup & grants meter!
            local pickedUpBy = nil
            for i = 0, Game():GetNumPlayers() - 1 do
                local player = Isaac.GetPlayer(i)
                if IsTaintedHal(player) then
                    local dist = (player.Position - sp.pos):Length()
                    if dist <= SPARK_PICKUP_RANGE then
                        pickedUpBy = player
                        break
                    end
                end
            end

            if pickedUpBy then
                sp.collected    = true
                sp.collectFrame = currentFrame

                local data = GetPlayerData(pickedUpBy)
                data.emeraldSparks = math.min(SPARK_MAX, (data.emeraldSparks or 0.0) + SPARK_PER_KILL)

                -- If Emblem meter reaches 100% and Tainted Hal's active item needs charge, grant +1 charge bar!
                if data.emeraldSparks >= SPARK_MAX then
                    pcall(function()
                        if ITEM_COAST_CITY and pickedUpBy:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == ITEM_COAST_CITY then
                            local curCharge = pickedUpBy:GetActiveCharge(ActiveSlot.SLOT_PRIMARY)
                            if curCharge < 4 then
                                pickedUpBy:SetActiveCharge(curCharge + 1, ActiveSlot.SLOT_PRIMARY)
                                data.emeraldSparks = 0.0
                            end
                        end
                    end)
                end

                -- Play crisp coin-style pickup chime while the emblem's Collect squash-and-stretch animation plays in front of the player
                pcall(function()
                    local sfx = (SoundEffect and (SoundEffect.SOUND_PENNYPICKUP or SoundEffect.SOUND_PLOP or SoundEffect.SOUND_BEEP)) or 24
                    SFXManager():Play(sfx, 0.75, 0, false, 1.18)
                end)
            else
                -- 2. If not walked over yet, check floor lifetime & vanish on the floor after SPARK_LIFETIME_FRAMES (6s)
                local ageFrames = currentFrame - (sp.spawnFrame or currentFrame)
                if ageFrames < 0 or ageFrames >= SPARK_LIFETIME_FRAMES then
                    table.remove(activeEmeraldSparks, idx)
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

                        local flyVar = (FamiliarVariant and FamiliarVariant.BLUE_FLY) or 43
                        local ring = Isaac.Spawn(
                            EntityType.ENTITY_FAMILIAR,
                            flyVar,
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
                SetEntityScaleAndColor(familiar, 1.3, nil)

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

    local newWill = math.min(WILLPOWER_MAX, (data.willpower or 0) + refillAmount)
    RestoreHalRingPower(player, newWill, "BATTERY RECHARGED!")
end)

-- ---------------------------------------------------------------------------
-- SECTION 14: OVERCHARGE / SURGE / COAST CITY / SPARKS RESET ON NEW ROOM
-- ---------------------------------------------------------------------------

GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    activeCoastCity.active = false
    -- Remove any uncollected Green Lantern emblems when leaving a room so they never persist or turn into coins!
    ClearAllLanternEmblemDrops()

    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if IsHalJordan(player) or IsTaintedHal(player) then
            RefreshCharacterCostume(player)
        end
        local data = GetPlayerData(player)
        if IsHalJordan(player) or IsTaintedHal(player) then
            StopContinuousBeam(data)
            data.shootHoldFrames          = 0
            data.firedSmallBeamThisPress  = false
            data.bufferedClickDir         = nil
            data.continuousBeamGraceTimer = 0
            data.lastContinuousBeamDir    = nil
        end
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
                "Refills Willpower to 100% and unleashes a close-range emerald pulse#At >=50% Willpower: Overcharge (+15% DMG + Piercing + Spectral for the room)#Below 50%: Restores Willpower & Ring capabilities",
                "Power Battery", lang)
            EID:addCollectible(ITEM_GIANT_FIST,
                "Fires a massive spectral piercing emerald fist#Deals 10x Player Damage and smashes rocks & obstacles",
                "Construct: Giant Fist", lang)
            EID:addCollectible(ITEM_COAST_CITY,
                "Inflicts Fear (3s) and spawns a 5s Emerald Vortex that pulls nearby enemies toward the center#Collecting Green Lantern Emblems recharges the item and extends vortex duration",
                "The Tragedy of Coast City", lang)
            EID:addCollectible(ITEM_SOLID_LIGHT_SHIELD,
                "+2 Soul Hearts#Grants an orbital shield that blocks shots#25%-75% chance (scales with Luck) to reflect enemy projectiles as spectral beams",
                "Solid Light Shield", lang)
            if ITEM_POWER_RING and ITEM_POWER_RING > 0 then
                EID:addCollectible(ITEM_POWER_RING,
                    "Signature Green Lantern Power Ring worn on your hand#Tap/click to fire high-damage piercing & spectral emerald bolts#Hold fire to channel a continuous lower-damage emerald laser beam",
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
            return "Power Battery [4R Active]", {
                "Refills 100% Willpower + close emerald pulse",
                ">=50% Will: +15% Overcharge DMG for room"
            }
        elseif id == ITEM_GIANT_FIST then
            return "Construct: Giant Fist [4R Active]", {
                "Fires a giant piercing 10x DMG emerald fist",
                "Smashes rocks, poop, and obstacles in its path"
            }
        elseif id == ITEM_COAST_CITY then
            return "The Tragedy of Coast City [4R Active]", {
                "Fears enemies & pulls them into a 5s vortex",
                "Lantern Emblems recharge & extend the vortex"
            }
        elseif id == ITEM_SOLID_LIGHT_SHIELD then
            return "Solid Light Shield [Passive]", {
                "+2 Soul Hearts & orbital light shield",
                "25%-75% chance (Luck) to reflect enemy shots"
            }
        elseif id == ITEM_POWER_RING then
            return "Green Lantern Ring [Starting Passive]", {
                "Click: high-DMG small beams | Hold: continuous beam",
                "Piercing & spectral emerald energy from your ring"
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

-- Cached custom Sprite instances for the Green Lantern / Parallax aura, Power Ring hand flare, Continuous Beam, and Green Lantern Emblem drops
local glAuraSprite     = nil
local glFlareSprite    = nil
local glSparkSprite    = nil
local glContBeamSprite = nil

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

local function GetGLContBeamSprite()
    if not glContBeamSprite and Sprite then
        local s = Sprite()
        local ok = pcall(function()
            s:Load("gfx/effects/gl_ring_beam.anm2", true)
            s:Play("ContinuousBeam", true)
        end)
        if ok then
            glContBeamSprite = s
        end
    end
    return glContBeamSprite
end

local function GetGLSparkSprite()
    if not glSparkSprite and Sprite then
        local s3 = Sprite()
        local ok3 = pcall(function()
            s3:Load("gfx/effects/gl_lantern_spark.anm2", true)
            s3:Play("Idle", true)
        end)
        if ok3 then
            glSparkSprite = s3
        end
    end
    return glSparkSprite
end

local function RenderGLSparkDrops(onlyCollected)
    if #activeEmeraldSparks == 0 then return end
    local sparkSpr = GetGLSparkSprite()
    if not sparkSpr then return end

    local frame = Game():GetFrameCount()
    local currentRoomIdx = Game():GetLevel():GetCurrentRoomIndex()
    for _, sp in ipairs(activeEmeraldSparks) do
        if sp and sp.roomIdx == currentRoomIdx then
            if sp.collected and (onlyCollected == true or onlyCollected == nil) then
                -- Render coin/bomb-style squash-and-upward-stretch pickup animation IN FRONT OF the player!
                local collectAge = math.max(0, frame - (sp.collectFrame or frame))
                if collectAge < SPARK_COLLECT_FRAMES then
                    local screenPos = Isaac.WorldToScreen(sp.pos)
                    sparkSpr:SetFrame("Collect", collectAge)
                    sparkSpr.Scale = Vector(1.0, 1.0)
                    sparkSpr.Color = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
                    sparkSpr:Render(screenPos, Vector.Zero, Vector.Zero)
                end
            elseif (not sp.collected) and (onlyCollected == false or onlyCollected == nil) then
                local ageFrames = math.max(0, frame - (sp.spawnFrame or frame))
                if ageFrames < SPARK_LIFETIME_FRAMES then
                    local screenPos = Isaac.WorldToScreen(sp.pos)
                    local animFrame = math.floor(ageFrames / 4) % 4
                    sparkSpr:SetFrame("Idle", animFrame)
                    local rem = SPARK_LIFETIME_FRAMES - ageFrames
                    if rem <= 15 then
                        local shrink = math.max(0.15, rem / 15.0)
                        sparkSpr.Scale = Vector(shrink, shrink)
                    else
                        sparkSpr.Scale = Vector(1.0, 1.0)
                    end
                    if ageFrames >= (SPARK_LIFETIME_FRAMES - SPARK_BLINK_FRAMES) then
                        local alpha = (math.floor(ageFrames / 3) % 2 == 0) and 0.95 or 0.22
                        sparkSpr.Color = Color(1.0, 1.0, 1.0, alpha, 0, 0, 0)
                    else
                        sparkSpr.Color = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
                    end
                    sparkSpr:Render(screenPos, Vector.Zero, Vector.Zero)
                end
            end
        end
    end
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

local function RenderGLContinuousBeam(player, data, flareSpr, frame)
    if not (data and data.isFiringContinuousBeam) then
        return
    end
    local beamSpr = GetGLContBeamSprite()
    if not beamSpr then return end

    local shootInput = player:GetShootingInput()
    local dir = data.lastShootDir
    if not (dir and dir:Length() > 0.001) then
        if shootInput and shootInput:Length() > 0.1 then
            dir = shootInput:Normalized()
        else
            dir = Vector(1, 0)
        end
    else
        dir = dir:Normalized()
    end

    local handOffset  = data.lastRingHandOffset or GetRingHandOffset(player, dir)
    local startWorld  = player.Position + handOffset
    local endWorld    = ComputeContinuousBeamEndWorld(startWorld, dir)
    local startScreen = Isaac.WorldToScreen(startWorld)
    local endScreen   = Isaac.WorldToScreen(endWorld)

    local screenDelta = endScreen - startScreen
    local totalScreenLen = screenDelta:Length()
    if totalScreenLen < 4.0 then return end

    local screenDir = screenDelta / totalScreenLen
    local screenAngle = screenDir:GetAngleDegrees()
    local thickness = IsTaintedHal(player) and 1.18 or (data.overcharge and 1.22 or (data.surgeBuff and 1.10 or 1.0))
    local segWidth = 48.0
    local segStep  = 48.0
    local dist     = 0.0
    local animFrame = math.floor(frame / 2) % 4

    while dist < totalScreenLen do
        local rem = totalScreenLen - dist
        local xScale = 1.0
        if rem < segWidth then
            xScale = math.max(0.05, rem / segWidth)
        end
        beamSpr:SetFrame("ContinuousBeam", animFrame)
        beamSpr.Rotation = screenAngle
        beamSpr.Scale = Vector(xScale, thickness)
        beamSpr.Color = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
        beamSpr:Render(startScreen + screenDir * dist, Vector.Zero, Vector.Zero)
        if rem <= segWidth then
            break
        end
        dist = dist + segStep
    end

    -- Render bright emerald construct impact flare at the beam endpoint
    if flareSpr then
        flareSpr:SetFrame("RingFlare", math.floor(frame / 2) % 4)
        flareSpr.Scale = Vector(0.95 * thickness, 0.95 * thickness)
        flareSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0.15, 0.50, 0.18)
        flareSpr:Render(endScreen, Vector.Zero, Vector.Zero)
    end
end

local function IsPlayerAimingUpForRender(player, data)
    local activeFlare = data and (data.isFiringContinuousBeam or (data.ringFlareTimer and data.ringFlareTimer > 0))
    local shootDir = (activeFlare and data.lastShootDir) or player:GetShootingInput()
    return IsAimingUp(player, shootDir)
end

local function RenderGLBeamAndFlareForPlayer(player, data, frame)
    local _, flareSpr = GetGLAuraSprites()
    RenderGLContinuousBeam(player, data, flareSpr, frame)

    if flareSpr then
        local shootInput = player:GetShootingInput()
        local hasActiveFlare = data.isFiringContinuousBeam or (data.ringFlareTimer and data.ringFlareTimer > 0)
        local isFiring = (shootInput and shootInput:Length() > 0.1) or hasActiveFlare
        local aimingUp = IsPlayerAimingUpForRender(player, data)

        -- When facing UP without firing, the ring hand is in front of the torso (hidden behind the head/body from camera view)
        if aimingUp and not isFiring then
            return
        end

        local handOffset = (hasActiveFlare and data.lastRingHandOffset) or GetRingHandOffset(player, shootInput)
        if aimingUp then
            handOffset = Vector(0, -38)
        end
        local handScreenPos = Isaac.WorldToScreen(player.Position + handOffset)

        local flareFrame = math.floor(frame / (isFiring and 2 or 4)) % 4
        flareSpr:SetFrame("RingFlare", flareFrame)

        if data.isFiringContinuousBeam then
            local fScale = aimingUp and 0.78 or 1.05
            flareSpr.Scale = Vector(fScale, fScale)
            flareSpr.Color = Color(1.0, 1.0, 1.0, 0.98, 0.15, 0.50, 0.18)
        elseif isFiring then
            local fScale = aimingUp and 0.68 or 0.85
            flareSpr.Scale = Vector(fScale, fScale)
            flareSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0.10, 0.35, 0.12)
        else
            local pulse = 0.45 + 0.20 * math.sin(frame * 0.20)
            flareSpr.Scale = Vector(0.45, 0.45)
            flareSpr.Color = Color(1.0, 1.0, 1.0, pulse, 0, 0, 0)
        end
        flareSpr:Render(handScreenPos, Vector.Zero, Vector.Zero)
    end
end

-- 1. Render uncollected floor Green Lantern Emblem drops, hover aura, AND upward-aimed Ring Beam BEHIND the player
if ModCallbacks.MC_PRE_PLAYER_RENDER then
    GL:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, renderOffset)
        if RenderMode and Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
        local p0 = Isaac.GetPlayer(0)
        if not p0 or player.Index == p0.Index then
            RenderGLSparkDrops(false)
        end
        RenderGLPlayerAura(player)

        if IsRingActive(player) then
            local data = GetPlayerData(player)
            if IsPlayerAimingUpForRender(player, data) then
                RenderGLBeamAndFlareForPlayer(player, data, Game():GetFrameCount())
            end
        end
        return nil
    end)
end

-- 2. Render collected Green Lantern Emblem pickup animation, and LEFT/RIGHT/DOWN Ring Beam & flare IN FRONT of the player
GL:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, renderOffset)
    if RenderMode and Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
    local p0 = Isaac.GetPlayer(0)
    if not p0 or player.Index == p0.Index then
        if ModCallbacks.MC_PRE_PLAYER_RENDER then
            RenderGLSparkDrops(true)
        else
            RenderGLSparkDrops(nil)
        end
    end
    if not IsRingActive(player) then return end
    local data = GetPlayerData(player)

    if not ModCallbacks.MC_PRE_PLAYER_RENDER then
        RenderGLPlayerAura(player)
    end

    if (not ModCallbacks.MC_PRE_PLAYER_RENDER) or (not IsPlayerAimingUpForRender(player, data)) then
        RenderGLBeamAndFlareForPlayer(player, data, Game():GetFrameCount())
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
                local pct  = math.max(0.0, math.min(1.0, (data.willpower or 0) / WILLPOWER_MAX))
                local BAR_W = 36

                Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)

                local r, g, b = 0.1, 0.95, 0.3
                if data.ringDepleted then
                    r, g, b = 1.0, 0.45, 0.15
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

                local label = string.format("%.0f%%", data.willpower or 0)
                if data.ringDepleted then
                    label = string.format("REBOOT %.0f%%/%.0f%%", data.willpower or 0, WILLPOWER_REBOOT_THRESHOLD)
                elseif data.overcharge then
                    label = string.format("%.0f%% +15%%DMG", data.willpower or 0)
                end
                DrawHudText(label, hudX + 33, hudY - 2, r, g, b, 0.95)

                if data.oathTextTimer and data.oathTextTimer > 0 then
                    data.oathTextTimer = data.oathTextTimer - 1
                    if data.oathText then
                        local headPos = Isaac.WorldToScreen(player.Position + Vector(0, -48))
                        local textAlpha = math.min(0.95, data.oathTextTimer / 20.0)
                        DrawHudText(data.oathText, math.floor(headPos.X - 38), math.floor(headPos.Y), r, g, b, textAlpha)
                    end
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

                local label = pct >= 1.0 and "100%" or string.format("%.0f%%", data.emeraldSparks)
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
            if pct <= 0 then
                TriggerHalRingDepleted(p)
            else
                RestoreHalRingPower(p, pct, "WILLPOWER RESTORED!")
            end
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
