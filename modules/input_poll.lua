-- modules/input_poll.lua -- RSI: polling de input de raton/teclado para render.
-- Responsabilidad unica: capturar la direccion de disparo desde raton/teclado
-- y sincronizar el estado de apuntado entre frames de render.

return function(Core)
    function Core.PollInputForRender()
        for i = 0, Game():GetNumPlayers() - 1 do
            local p = Isaac.GetPlayer(i)
            if p and (Core.IsHalJordan(p) or Core.IsTaintedHal(p)) then
                local d = Core.GetPlayerData(p)
                local shootIn = (p.GetShootingInput and p:GetShootingInput()) or nil
                if (not shootIn or (shootIn.Length and shootIn:Length() <= 0.1)) and Input and Input.IsMouseBtnPressed and Input.IsMouseBtnPressed(0) then
                    local mousePos = Input.GetMousePosition and Input.GetMousePosition(true)
                    if mousePos then
                        local diff = mousePos - p.Position
                        if diff:Length() > 5 then
                            shootIn = diff:Normalized()
                        end
                    end
                end
                local holdingNow = (shootIn and shootIn.Length and shootIn:Length() > 0.1) or false
                if holdingNow then
                    local rawDir = shootIn:Normalized()
                    if Core.HasTractorBeam and Core.HasTractorBeam(p) then
                        rawDir = Core.GetTractorBeamDirection(p, rawDir)
                    end
                    d.renderLastShootDir = Vector(rawDir.X, rawDir.Y)
                    if d.wasHoldingShootOnRender == false then
                        d.sawShootPressBetweenFrames = true
                    end
                else
                    if d.wasHoldingShootOnRender == true or (d.shootHoldFrames or 0) > 0 then
                        d.sawShootReleaseBetweenFrames = true
                    end
                    if d.isFiringContinuousBeam then
                        Core.StopContinuousBeam(d)
                    end
                end
                d.wasHoldingShootOnRender = holdingNow
            end
        end
    end
end
