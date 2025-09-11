--[[
    Parachute Project GTA IV By LeChapellierFou, 10/09/2025
]]

local version = "1.0.2"

-- Commencer la chute libre
function StartFreefall(x, y, z, vx, vy, vz)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
    
    
    startHeight = z
    
    -- Définir la physique initiale avec une meilleure détection de chute
    horizontalSpeed = Game.Vmag(vx, vy, 0.0) + 4.0 -- Augmenter la vitesse horizontale initiale
    -- S'assurer que la vitesse verticale est négative pour la chute
    if vz > -2.0 then
        verticalSpeed = -2.0  -- Commencer avec une vitesse de chute plus lente
    else
        verticalSpeed = vz
    end
    lateralSpeed = 0.0
    heading = Game.GetCharHeading(playerChar)
    
    
    if Game.IsCharPlayingAnim(playerChar, "PARACHUTE", "Free_Fall") then
        SwithParaState(3)
        SwithMod(1)
    else
        -- Jouer l'animation de chute libre
        Game.TaskPlayAnimNonInterruptable(playerChar, "Free_Fall", "PARACHUTE", 1.0, true, true, true, false, -2)
    end
    
    -- Définir les propriétés du personnage
    Game.SetCharCollision(playerChar, true)
    Game.SetBlockingOfNonTemporaryEvents(playerChar, true)
    
    -- Retirer les armes
    --Game.GiveWeaponToChar(playerChar, 0, 0, true)
    Game.BlockPedWeaponSwitching(playerChar, true)
    
    -- Jouer le son
    --soundId = Game.GetSoundId()
    SoundId_Decend = 1
    Game.PlaySoundFromPed(SoundId_Decend, "PARACHUTE_DESCEND", playerChar)
    
    -- Appliquer immédiatement la vélocité initiale
    UpdateCharacterVelocity()
end

-- Atterrir avec le parachute
local function LandParachute(x, y, z, vx, vy, vz, height)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
    
    Game.SetCharHeading(playerChar, heading)
    
    -- Réduire la vélocité
    Game.SetCharVelocity(playerChar, vx / 2.0, vy / 2.0, vz)
    
    -- Arrêter les sons
    if SoundId_Decend ~= nil then
        Game.StopSound(SoundId_Decend)
        Game.ReleaseSoundId(SoundId_Decend)
        SoundId_Decend = nil
    end
    
    -- Gérer l'objet parachute
    if parachuteObject and Game.DoesObjectExist(parachuteObject) then
        Game.DetachObject(parachuteObject, true)
        Game.SetObjectCollision(parachuteObject, false)
        Game.SetObjectDynamic(parachuteObject, true)
        Game.PlayObjectAnim(parachuteObject, "obj_crumple", "PARACHUTE", 8.0, false, true)
    end
    
    -- Jouer le son d'atterrissage
    SoundId_Land = 2
    Game.PlaySoundFromPed(SoundId_Land, "PARACHUTE_LAND", playerChar)

    if not Game.IsPedRagdoll(playerChar) then
        SwithParaState(8)
    end
    
    -- Vérifier si mort
    if Game.IsCharDead(playerChar) then
        SwithParaState(8)
        Game.SwitchPedToRagdoll(playerChar, 500, 2000, 2, false, true, false)
    end
end


-- Animation pour enlever le sac du parachute
local function AnimParaRemove()
    local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
    
    if (parachuteObjectSac ~= nil) then
        -- supprime le second sac 
		if(parachuteObjectSac2 ~= nil) then 
			Game.DeleteObject(parachuteObjectSac2)
			parachuteObjectSac2 = nil
		end
		-- Activer le sac de parachute
        Game.SetObjectDynamic(parachuteObjectSac, true)
        Game.SetObjectCollision(parachuteObjectSac, true)
        Game.SetObjectVisible(parachuteObjectSac, true)
        
        -- Jouer l'animation de retrait du sac (plus lente pour plus de réalisme)
        Game.PlayObjectAnim(parachuteObjectSac, "obj_chute_off", "PARACHUTE", 1000.0, false, true)
        if IsPlayerModelsMP() then
            Game.SetCharComponentVariation(playerChar, 8, 0, 0)
        end

        if Game.HasCharGotWeapon(playerChar, 41) then
            Game.RemoveWeaponFromChar(playerChar, 41)
        end

        -- Jouer l'animation du joueur pour enlever le sac
        if (not Game.IsCharDead(playerChar)) then
            Game.TaskPlayAnimWithFlags(playerChar, "chute_off", "PARACHUTE", 4.0, 0, 1280)
            IsPlayerLeavePara = true
        end
    end
end

-- Animation de disparition de l'objet parachute (voile qui remonte)
local function AnimParaLeave()
    if parachuteObject ~= nil and Game.DoesObjectExist(parachuteObject) then 
        local x, y, z = Game.GetObjectCoordinates(parachuteObject)
        
        -- Faire remonter la voile progressivement
        Game.SlideObject(parachuteObject, x, y, z + 20.0, 0.0, 0.0, 0.3, false)

        -- Animation de disparition progressive (fade out)
        if (not Game.IsObjectPlayingAnim(parachuteObject, "obj_crumple", "PARACHUTE")) then 
            ObjectAlpha = ObjectAlpha + 8; -- Ralentir la disparition
            if (ObjectAlpha > 255) then 
                ObjectAlpha = 255;
            end

            -- Appliquer la transparence progressive
            Game.SetObjectAlpha(parachuteObject, 255 - ObjectAlpha);
            
            -- Supprimer l'objet quand complètement transparent
            if (ObjectAlpha >= 255) then 
                Game.DeleteObject(parachuteObject)
                parachuteObject = nil
                ObjectAlpha = 0 -- Réinitialiser pour la prochaine utilisation
            end
        end
    end
end

local function ManageParachuteLeave()
	local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
	
	-- Étape 2: Gestion du sac de parachute (synchronisé avec l'animation du joueur)
	if (parachuteObjectSac ~= nil and not IsPlayerLeaveParaSac) then
        if (Game.IsObjectPlayingAnim(parachuteObjectSac, "obj_chute_off", "PARACHUTE")) then
            local animTime = Game.GetObjectAnimCurrentTime(parachuteObjectSac, "obj_chute_off", "PARACHUTE")
            -- Étape 2a: Détacher le sac quand l'animation est presque terminée (95%)
            if (animTime > 0.95) then
                if Game.IsObjectAttached(parachuteObjectSac) then
					
                    Game.DetachObject(parachuteObjectSac, true)
                    DebugPrint("ParachuteSacObject detached")
                    DebugPrint("Animation time: " .. animTime)
                end
                -- Désactiver le vêtement du parachute
                
                TimerA = Game.GetGameTimer()
                IsPlayerLeaveParaSac = true
            end
        else
            Game.PlayObjectAnim(parachuteObjectSac, "obj_chute_off", "PARACHUTE", 1000.0, false, true)
        end
	end
end

-- Gérer le ragdoll
local function HandleRagdoll(x, y, z, vx, vy, vz, height)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
    
    -- Vérifier si le ragdoll est terminé
    if not Game.IsPedRagdoll(playerChar) then
        -- Calculer les dégâts une seule fois
        if not IsDamageCalculated then
            local currentHealth = CalculateLandingDamage(height, vz)
            
            DebugPrint("currentHealth: " .. currentHealth)
            Game.SetCharHealth(playerChar, currentHealth)
            IsDamageCalculated = true
        end

        if Ptfx ~= nil then
            Game.StopPtfx(Ptfx)
            Ptfx = nil
        end
        
        -- Étape 1: Animation de disparition de la voile du parachute
        AnimParaLeave()
        -- Étape 2: Animation de disparition du sac de parachute
        if not IsPlayerLeavePara then AnimParaRemove() end  
        -- Étape 3: Gestion du sac de parachute
        ManageParachuteLeave()   

        if IsPlayerLeaveParaSac then 
            if parachuteObject == nil then
                if parachuteObjectSac ~= nil then 
					local TimerB = Game.GetGameTimer()
					if(TimerB - TimerA > 4000) then
						DebugPrint("timer > 4000")
						CleanupParachute()
					end
                else
                    DebugPrint("ParachuteSacObject nil")
                    CleanupParachute()
                end
            end
        end
		
		if (IsPlayerLeaveParaSac and not Game.IsObjectPlayingAnim(parachuteObjectSac, "obj_chute_off", "PARACHUTE") and not AnimObjIdle) then
			local ox, oy, oz = Game.GetObjectCoordinates(parachuteObjectSac)
			Game.SetObjectCoordinates(parachuteObjectSac, ox, oy, z)
			Game.FreezeObjectPosition(parachuteObjectSac, true)
			--Game.PlayObjectAnim(parachuteObjectSac, "obj_chute_off_idle", "PARACHUTE", 8.0, true, false)
			AnimObjIdle = true
			DebugPrint("AnimObjIdle = true")
			Game.ClearHelp()
		end

        if IsPlayerLeaveParaSac and parachuteObject == nil and Game.IsObjectAttached(parachuteObjectSac) then
            DebugPrint("DEBUG : Error ParachuteObject = nil")
            CleanupParachute()
        end

        if (parachuteObjectSac ~= nil and not Game.IsObjectPlayingAnim(parachuteObjectSac, "obj_chute_off", "PARACHUTE") and not Game.IsObjectAttached(parachuteObjectSac) and AnimObjIdle) then
            local TimerB = Game.GetGameTimer()
			if(TimerB - TimerA > 3000) then
				DebugPrint("timer > 3000")
				DebugPrint("DEBUG : End Parachute function")
				CleanupParachute()
			end
        end
    end
end

-- Gestion des contrôles de chute libre
local function HandleFreefallControls()
    local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
    
    -- Utiliser les variables de contrôle déjà mises à jour par UpdateControls()
    local leftX = leftStickX
    local leftY = leftStickY
    PrintHelp("PARA_FALL_MP")

    -- Ajouter des contrôles clavier supplémentaires si pas de contrôleur
    if not Game.IsUsingController() then
        -- Contrôles clavier pour la rotation gauche/droite (A/D)
        if Game.IsControlPressed(0, 65) then -- Q (gauche)
            leftX = -0.5
        elseif Game.IsControlPressed(0, 68) then -- D (droite)
            leftX = 0.5
        end
        
        -- Contrôles clavier pour avant/arrière (W/S)
        if Game.IsControlPressed(0, 87) then -- Z (avant)
            leftY = -0.5
        elseif Game.IsControlPressed(0, 83) then -- S (arrière)
            leftY = 0.5
        end
    end

    -- Gérer le contrôle gauche/droite (roulis)
    if leftX ~= 0 and leftY == 0 then
        -- Rotation du personnage

        -- Animation de roulis
        if leftX > 0 then
            -- Roulis vers la droite
            if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Free_Fall_Veer_Right" )) then 
                Game.TaskPlayAnimNonInterruptable(playerChar, "Free_Fall_Veer_Right", "PARACHUTE", 4.0, true, true, true, false, 0)
            end
            -- Sensibilité de rotation
            heading = heading - (leftX / 130)
            Game.SetCharHeading(playerChar, heading)
            --Print("Right rotation : " .. leftX)
        elseif leftX < 0 then
            -- Roulis vers la gauche
            if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Free_Fall_Veer_left" )) then 
                Game.TaskPlayAnimNonInterruptable(playerChar, "Free_Fall_Veer_left", "PARACHUTE", 4.0, true, true, true, false, 0)
            end
            -- Sensibilité de rotation
            heading = heading - (leftX / 130)
            Game.SetCharHeading(playerChar, heading)
            --Print("Left rotation : " .. leftX)
        end
    else
        leftX = 0
    end
    
    -- Gérer le contrôle avant/arrière (pitch)
    if leftY ~= 0 and leftX == 0 then
        if leftY < 0 then
            -- Inclinaison vers l'avant (piqué) - accélérer la chute
            if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Free_Fall_Fast" )) then 
                Game.TaskPlayAnimNonInterruptable(playerChar, "Free_Fall_Fast", "PARACHUTE", 4.0, true, true, true, false, 0)
            end
            -- Augmenter la vitesse verticale (chute plus rapide)
            verticalSpeed = verticalSpeed - 0.8
            -- Augmenter la vitesse horizontale
            horizontalSpeed = horizontalSpeed + 0.3
        else
            -- Inclinaison vers l'arrière (cabré) - ralentir la chute
            if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "free_fall_deccelerate" )) then 
                Game.TaskPlayAnimNonInterruptable(playerChar, "free_fall_deccelerate", "PARACHUTE", 4.0, true, true, true, false, 0)
            end
            -- Réduire la vitesse verticale (chute plus lente) avec limite maximale
            local newVerticalSpeed = verticalSpeed + 0.3
            -- Limiter le ralentissement à la vitesse minimale définie
            if newVerticalSpeed > MIN_VERTICAL_SPEED then
                verticalSpeed = MIN_VERTICAL_SPEED
            else
                verticalSpeed = newVerticalSpeed
            end
            -- Réduire la vitesse horizontale
            horizontalSpeed = horizontalSpeed - 0.2
        end
    end

    if leftY == 0 and leftX == 0 then
        if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Free_Fall" )) then 
            Game.TaskPlayAnimNonInterruptable(playerChar, "Free_Fall", "PARACHUTE", 4.0, false, true, true, false, 0)
        end
    end

    if Game.IsGameKeyboardKeyJustPressed(29) or Game.IsButtonJustPressed(0, 0x12) then
        if Ptfx ~= nil then
            Game.StopPtfx(Ptfx)
            Ptfx = nil
        else
            AddEffectsOnPlayer()
        end
    end
end

-- Gérer la chute libre
local function HandleFreefall(x, y, z, vx, vy, vz, height)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
    
    -- Vérifier l'ouverture du parachute
    if Game.IsControlJustPressed(0, 137) or Game.IsControlJustPressed(0, 1) then
        OpenParachute()
        return
    end
    
    -- Gérer les contrôles de chute libre
    HandleFreefallControls()
    --DebugPrint("HandleFreefallControls appelée - leftStickX: " .. leftStickX .. ", leftStickY: " .. leftStickY)
    
    -- Mettre à jour la physique
    UpdateFreefallPhysics()
    
   
    -- S'assurer qu'on tombe réellement
    if verticalSpeed > -0.5 then
        verticalSpeed = -1.5  -- Forcer la chute si pas déjà (vitesse réduite)
    end

    -- Mettre à jour la vélocité du personnage
    UpdateCharacterVelocity()
end

-- Gérer l'ouverture du parachute
local function HandleParachuteOpening(x, y, z)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)

    if SoundId_Decend ~= nil then
        Game.StopSound(SoundId_Decend)
        Game.ReleaseSoundId(SoundId_Decend)
        SoundId_Decend = nil
    end
    
    -- Vérifier si l'animation d'ouverture est terminée
    if Game.IsCharPlayingAnim(playerChar, "PARACHUTE", "Open_Chute") then
        local animTime = Game.GetCharAnimCurrentTime(playerChar, "PARACHUTE", "Open_Chute")
        if animTime > 0.95 then           
            
            -- Jouer l'animation d'attente
            Game.TaskPlayAnimNonInterruptable(playerChar, "Hang_Idle", "PARACHUTE", 1.0, true, true, true, false, 0)
            
            if not Game.IsUsingController() then
                PrintHelp("PAR_FLT_MP")
            else
                PrintHelp("PAR_CLSC_MP")
            end

            -- Parachute complètement ouvert
            SwithParaState(5)
        end
    else
        -- Forcer l'animation d'ouverture
        Game.TaskPlayAnimNonInterruptable(playerChar, "Open_chute", "PARACHUTE", 10.0, false, true, true, false, 0)
    end
end

-- Gestion des contrôles du parachute déployé
local function HandleDeployedControls()
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)

    local leftX = leftStickX
    local leftY = leftStickY

    -- Ajouter des contrôles clavier supplémentaires si pas de contrôleur
    if not Game.IsUsingController() then
        -- Contrôles clavier pour la rotation gauche/droite (A/D)
        if Game.IsControlPressed(0, 65) then -- Q (gauche)
            leftX = -0.5
        elseif Game.IsControlPressed(0, 68) then -- D (droite)
            leftX = 0.5
        end
        
        -- Contrôles clavier pour avant/arrière (W/S)
        if Game.IsControlPressed(0, 87) then -- Z (avant)
            leftY = -0.5
        elseif Game.IsControlPressed(0, 83) then -- S (arrière)
            leftY = 0.5
        end
    end

    -- Gérer le contrôle gauche/droite (rotation et déplacement latéral)
    if leftX ~= 0 then
        -- Sensibilité de rotation (toujours active)
        heading = heading - (leftX / 130)
        Game.SetCharHeading(playerChar, heading)
        lateralSpeed = lateralSpeed + (leftX / 130)
        
        -- Animation de roulis seulement si pas d'inclinaison
        if leftY == 0 then
            if leftX > 0 then
                -- Roulis vers la droite
                if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Steer_R" )) then 
                    Game.TaskPlayAnimNonInterruptable(playerChar, "Steer_R", "PARACHUTE", 4.0, true, true, true, true, 0)
                end
            elseif leftX < 0 then
                -- Roulis vers la gauche
                if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Steer_L" )) then 
                    Game.TaskPlayAnimNonInterruptable(playerChar, "Steer_L", "PARACHUTE", 4.0, true, true, true, true, 0)
                end
            end
        end
        
        -- Limiter la vitesse latérale
        lateralSpeed = Clamp(lateralSpeed, -3.0, 3.0)
    else
        -- Retour à zéro progressivement quand pas de rotation
        lateralSpeed = SmoothLerp(lateralSpeed, 0.0, 0.1)
    end
    
    -- Gérer le contrôle avant/arrière (pitch et vitesse)
    if leftY ~= 0 then
        if leftY < 0 then
            -- Inclinaison vers l'avant (piqué) - accélérer la descente et l'avancement
            if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Accelerate_Loop" )) then 
                Game.TaskPlayAnimNonInterruptable(playerChar, "Accelerate_Loop", "PARACHUTE", 4.0, true, true, true, true, 0)
            end
            -- Augmenter la vitesse verticale (descente plus rapide)
            verticalSpeed = verticalSpeed - 0.9
            -- Augmenter la vitesse horizontale (avancement)
            horizontalSpeed = horizontalSpeed + 0.8
            -- Incliner le parachute vers l'avant
            pitch = SmoothLerp(pitch, -10.0, 0.1)
        elseif leftY > 0 then
            -- Inclinaison vers l'arrière (cabré) - effet de planement
            if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "deccelerate" )) then 
                Game.TaskPlayAnimNonInterruptable(playerChar, "deccelerate", "PARACHUTE", 4.0, true, true, true, true, 0)
            end
            -- Réduire la vitesse verticale (planement - descente plus lente)
            verticalSpeed = verticalSpeed + 0.8
            -- Augmenter la vitesse horizontale (effet de planement)
            horizontalSpeed = horizontalSpeed + 0.8
            -- Incliner le parachute vers l'arrière
            pitch = SmoothLerp(pitch, 10.0, 0.1)
        end
        
        -- Rotation pendant l'inclinaison (sans animation)
        if leftX ~= 0 then
            -- Sensibilité de rotation
            heading = heading - (leftX / 150)
            Game.SetCharHeading(playerChar, heading)
            lateralSpeed = lateralSpeed + (leftX / 150)
        end
        
        -- Limiter les vitesses à des valeurs raisonnables
        verticalSpeed = Clamp(verticalSpeed, -12.0, -2.0)
        horizontalSpeed = Clamp(horizontalSpeed, 2.0, 15.0)
        lateralSpeed = Clamp(lateralSpeed, -3.0, 3.0)
    else
        -- Position neutre - retour à l'horizontal et aux vitesses par défaut
        pitch = SmoothLerp(pitch, 0.0, 0.05)
        -- Retour progressif aux vitesses par défaut
        verticalSpeed = SmoothLerp(verticalSpeed, -6.0, 0.1)
        horizontalSpeed = SmoothLerp(horizontalSpeed, 10.0, 0.1)
    end

    -- Animation d'attente si pas de mouvement
    if leftY == 0 and leftX == 0 then
        if (not Game.IsCharPlayingAnim( playerChar, "PARACHUTE", "Hang_Idle" )) then 
            Game.TaskPlayAnimNonInterruptable(playerChar, "Hang_Idle", "PARACHUTE", 4.0, true, true, true, true, 0)
        end
    end

    if Game.IsGameKeyboardKeyJustPressed(29) or Game.IsButtonJustPressed(0, 0x12) then
        if Ptfx ~= nil then
            Game.StopPtfx(Ptfx)
            Ptfx = nil
        else
            AddEffectsOnPlayer()
        end
    end
end

-- Gérer le parachute déployé
local function HandleParachuteDeployed(x, y, z, vx, vy, vz, height)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)

    -- Mettre à jour la physique basée sur les contrôles
    UpdateDeployedPhysics()
    
    -- Vérifier l'atterrissage
    if height < 1.2 then
        LandParachute(x, y, z, vx, vy, vz, height)
        return
    end
    
    -- Vérifier si le joueur veut quitter le parachute (touche F ou X)
    if Game.IsControlJustPressed(2, 80) then -- F ou button Y
        CleanupParachute()
        Game.ClearCharTasksImmediately(playerChar)
    end
    
    -- Gérer les contrôles
    HandleDeployedControls()
    
    -- Mettre à jour la vélocité du personnage
    UpdateCharacterVelocity()
    
    -- Mettre à jour l'objet parachute
    if parachuteObject and Game.DoesObjectExist(parachuteObject) then
        Game.AttachParachuteModelToPlayer(playerChar, parachuteObject)  
    end
end

-- Gestion des états
local function HandleParachuteState(x, y, z, vx, vy, vz, height)
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
    
    if parachuteState == 0 then
        -- État normal - vérifier les conditions de saut
        if Game.IsCharOnFoot(playerChar) then
            -- Détection améliorée de chute libre - vérifier si le joueur tombe ou est en haute altitude
            if (height > 15.0 and vz < -2.0) or (height > 25.0) then
                -- Commencer la chute libre
                StartFreefall(x, y, z, vx, vy, vz)
            end
        end
    elseif parachuteState == 3 then
        -- État de chute libre
        HandleFreefall(x, y, z, vx, vy, vz, height)
        
        -- Vérifier si le joueur touche le sol en chute libre (il meurt)
        if height < 2.0 or z < -2.0 then
            local soundId = Game.GetSoundId()
            Game.StopSound(soundId)
            Game.ReleaseSoundId(soundId)
            Game.SetCharHealth(playerChar, 0)
            CleanupParachute()
        end
    elseif parachuteState == 4 then
        -- Ouverture du parachute
        HandleParachuteOpening(x, y, z)
    elseif parachuteState == 5 then
        -- Parachute déployé
        HandleParachuteDeployed(x, y, z, vx, vy, vz, height)
    elseif parachuteState == 8 then
        -- État ragdoll
        HandleRagdoll(x, y, z, vx, vy, vz, height)
    end
end


-- Boucle principale
local function MainLoop()
    local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)

    -- Obtenir la position et vélocité actuelles
    local x, y, z = Game.GetCharCoordinates(playerChar)
    local vx, vy, vz = Game.GetCharVelocity(playerChar)
    local height = Game.GetCharHeightAboveGround(playerChar)

    Game.SetBlockingOfNonTemporaryEvents(playerChar, true)
    
    -- Mettre à jour les contrôles
    UpdateControls()
    
    -- Gérer les différents états
    HandleParachuteState(x, y, z, vx, vy, vz, height)

    if not IsPlayerModelsMP() then
        if parachuteObjectSac2 ~= nil then
            Game.SetObjectVisible(parachuteObjectSac2, true)
        end
    end
    
    -- Vérifier les conditions de nettoyage
    if Game.IsCharDead(playerChar) then
        DebugPrint("char is dead")
        CleanupParachute()
    end
end

Events.Subscribe("scriptInit", function()

	Thread.Create(function()
        InitializeParachute()
        Console.Log("parachute_player.lua version "..version)
		while true do
			Thread.Pause(0)
            local playerId = Game.GetPlayerId()
            local playerChar = Game.GetPlayerChar(playerId)

            local episode = Game.GetCurrentEpisode()

            -- only tbogt
            if episode == 2 then

                if(ScriptActivated) then 
                    MainLoop()
                end
            end
		end
	end)
end)