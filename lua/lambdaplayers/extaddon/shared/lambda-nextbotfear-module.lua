local ipairs = ipairs
local IsValid = IsValid

local sanicenable = CreateLambdaConvar( "lambdaplayers_lambda_fearnextbots", 1, true, false, false, "If Lambda Players should run away from sanic type nextbots", 0, 1, { type = "Bool", name = "Fear Sanic Nextbots", category = "Lambda Server Settings" } )
local drgenable = CreateLambdaConvar( "lambdaplayers_lambda_feardrgnextbots", 1, true, false, false, "If Lambda Players should run away from DRGBase nextbots", 0, 1, { type = "Bool", name = "Fear DRGBase Nextbots", category = "Lambda Server Settings" } )



local function Initialize( self )
    self.l_nextbotfearcooldown = 0 -- Delay the code for optimization
end

local function Think( self )
    if CLIENT then return end 

    if CurTime() > self.l_nextbotfearcooldown and self:GetState() != "Retreat" then
        local near = self:FindInSphere( nil, 3000, function( ent ) return ( !ent.IsLambdaPlayer and ent:IsNextBot() and ( sanicenable:GetBool() and isfunction( ent.AttackNearbyTargets ) or drgenable:GetBool() and ent.IsDrGNextbot ) ) and self:CanSee( ent ) end )

        local closest
        local dist = math.huge

        for k, nextbot in ipairs( near ) do
            local newdist = self:GetRangeSquaredTo( nextbot )
            if newdist < dist then
                closest = nextbot 
                dist = newdist
            end
        end

        if IsValid( closest ) then
            self:RetreatFrom()
        end

        self.l_nextbotfearcooldown = CurTime() + 0.5
    end
end


hook.Add( "LambdaOnInitialize", "lambdanextbotfearmodule_init", Initialize )
hook.Add( "LambdaOnThink", "lambdanextbotfearmodule_think", Think )





if SERVER then

    -- Pretty much ported from the zetas but I really don't see anything wrong with this code.
    -- Just needed a little cleaning
    hook.Add( "OnEntityCreated", "lambdanextbotfearmodule_entitycreate", function( ent )
        timer.Simple( 0, function()
            if !IsValid( ent ) then return end

            local entClass = ent:GetClass()
            if entClass == "npc_sanic" or (ent:IsNextBot() and isfunction( ent.AttackNearbyTargets ) ) then

                local id = ent:GetCreationID()
                hook.Add( "Think", "zeta_sanicNextbotsSupport_" .. id, function()
                    if !IsValid( ent ) then hook.Remove( "Think", "zeta_sanicNextbotsSupport_" .. id ) return end
                    
                    local scanTime = GetConVar( entClass .. "_expensive_scan_interval" ):GetInt() or 1

                    if ( CurTime() - ent.LastTargetSearch ) > scanTime then
                        ent.ClosestLambda = nil
                        
                        local lastDist = math.huge
                        local chaseDist = GetConVar( entClass .. "_acquire_distance" ):GetInt() or 2500
                        local lambdas = ents.FindByClass( "npc_lambdaplayer" )

                        for i = 1, #lambdas  do
                            if !lambdas[ i ]:Alive() then continue end

                            local distSqr = ent:GetRangeSquaredTo( lambdas[ i ] )

                            if distSqr <= ( chaseDist * chaseDist ) and distSqr < lastDist then
                                ent.ClosestLambda = lambdas[ i ]
                                lastDist = distSqr
                            end
                        end
                    end

                    local closestlambda = ent.ClosestLambda
                    if !IsValid( closestlambda ) then return end 
                    
                    local curTarget = ent.CurrentTarget
                    local lambdadist = ent:GetRangeSquaredTo( closestlambda )
                    
                    if ent.CurrentTarget != closestlambda then

                        if !IsValid( curTarget ) or ( ent:GetRangeSquaredTo( curTarget ) > lambdadist and closestlambda != curTarget ) then
                            ent.CurrentTarget = closestlambda
                        end

                    elseif closestlambda:Alive() then

                        local dmgDist = GetConVar( entClass .. "_attack_distance" ):GetInt() or 80
                        if lambdadist > ( dmgDist * dmgDist ) then return end
                        
                        local startHP = closestlambda:Health()

                        local attackForce = GetConVar( entClass .. "_attack_force" ):GetInt() or 800
                        if isfunction( ent.AttackOpponent ) then
                            ent:AttackOpponent( closestlambda, ent:GetPos(), attackForce )
                        else 
                            local dmgInfo = DamageInfo()
                            dmgInfo:SetAttacker( ent )
                            dmgInfo:SetInflictor( ent )
                            dmgInfo:SetDamage( 1e8 )
                            dmgInfo:SetDamagePosition( ent:GetPos() )
                            dmgInfo:SetDamageForce( ( (closestlambda:GetPos() - ent:GetPos() ):GetNormal() * attackForce + ent:GetUp() * 500 ) * 100 )
                            closestlambda:TakeDamageInfo(dmgInfo)

                            ent:EmitSound( "physics/body/body_medium_impact_hard" .. math.random( 6 ) .. ".wav", 350, 120)
                        end

                        if closestlambda:Health() < startHP then 
                            if ent.TauntSounds and ( CurTime() - ent.LastTaunt ) > 1.2 then
                                ent.LastTaunt = CurTime()
                                local snd = ent.TauntSounds[ math.random( #ent.TauntSounds ) ]
                                if snd == nil then snd = ent.TauntSounds end
                                if isstring( snd ) then
                                    ent:EmitSound( snd, 350, 100 )
                                end
                            end

                            ent.LastTargetSearch = 0
                        end
                    end
                end)
            end
        end )
    end )

end