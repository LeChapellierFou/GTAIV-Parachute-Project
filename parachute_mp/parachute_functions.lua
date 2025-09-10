--[[
    Parachute Project GTA IV By LeChapellierFou, 10/09/2025
    functions pour parachute_player
]]

-- Fonctions d'aide pour la physique
SmoothLerp = function(current, target, speed)
    local diff = target - current
    if Game.Absf(diff) < 0.01 then
        return target
    end
    return current + (diff * speed)
end

Clamp = function(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function SwithParaState(I)
    if(parachuteState ~= I) then
        parachuteState = I
        DebugPrint("ParachuteState: " .. parachuteState)
    end
end

-- Initialisation principale
function InitializeParachute()
    -- Charger les ressources requises
    local episode = Game.GetCurrentEpisode()

    if episode == 2 then
        LoadAnimDict("PARACHUTE")
        Game.RequestAmbientAudioBank("EP2_SFX\\PARACHUTE")
    end
end

-- Fonction de mise à jour de la vélocité (équivalent à sub_6947 dans le script original)
function UpdateCharacterVelocity()
    local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
    
    if Game.IsCharInjured(playerChar) then
        return
    end
    
    -- Variables pour les effets aléatoires
    local randomX = 0.0
    local randomY = 0.0
    
    -- Ajouter des effets aléatoires selon l'état
    if parachuteState == 3 then
        -- Chute libre - ajouter des vibrations
        randomX = (math.random() - 0.5) * 2.0
        randomY = (math.random() - 0.5) * 1.0
    elseif parachuteState == 5 then
        -- Parachute déployé - légères variations
        randomX = (math.random() - 0.5) * 1.0
        randomY = (math.random() - 0.5) * 1.0
    end
    
    -- Mettre à jour la rotation du personnage
    Game.SetCharRotation(playerChar, pitch, roll, heading)
    
    -- Calculer la nouvelle vélocité basée sur la physique
    local newVx = (horizontalSpeed * -Game.Sin(heading)) + (lateralSpeed * Game.Cos(heading)) + randomX
    local newVy = (horizontalSpeed * Game.Cos(heading)) + (lateralSpeed * Game.Sin(heading)) + randomY
    local newVz = verticalSpeed
    
    -- Appliquer la vélocité au personnage
    Game.SetCharVelocity(playerChar, newVx, newVy, newVz)
    
    -- En chute libre, appliquer une force vers l'avant pour plus de réalisme
    if parachuteState == 3 then
        -- Calculer la direction vers l'avant basée sur le cap du personnage
        local forwardX = -Game.Sin(heading)
        local forwardY = Game.Cos(heading)
        
        -- Appliquer une force vers l'avant (force de l'air)
        local forceMagnitude = 15.0 -- Force de propulsion vers l'avant
        Game.ApplyForceToPed(playerChar, 3, forwardX * forceMagnitude, forwardY * forceMagnitude, 0.0, 0.0, 0.0, 0.0, 0, false, true, true)
    end
end

-- Nettoyage principal
function CleanupParachute()
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)

    -- Réinitialiser l'état
    SwithParaState(0)
    SwithMod(1)

    Game.ClearHelp()

    -- Arrêter les sons
    if SoundId_Land ~= nil then
        Game.StopSound(SoundId_Land)
        Game.ReleaseSoundId(SoundId_Land)
        SoundId_Land = nil
    end

    if SoundId_Decend ~= nil then
        Game.StopSound(SoundId_Decend)
        Game.ReleaseSoundId(SoundId_Decend)
        SoundId_Decend = nil
    end

    --Game.AmbientAudioBankNoLongerNeeded()
    
    -- Nettoyer le véhicule
    if vehicleObject and Game.IsVehDriveable(vehicleObject) then
        Game.SetCarCollision(vehicleObject, true)
        Game.MarkCarAsNoLongerNeeded(vehicleObject)
    end
    vehicleObject = nil

    Game.BlockPedWeaponSwitching(playerChar, false)
    Game.UnlockRagdoll(playerChar, true)
    Game.SetBlockingOfNonTemporaryEvents(playerChar, false)
    Game.SetCharInvincible(playerChar, false)

    if parachuteObject and Game.DoesObjectExist(parachuteObject) then
        Game.DetachObject(parachuteObject, true)
        Game.DeleteObject(parachuteObject)
        parachuteObject = nil
    end

    if parachuteObjectSac and Game.DoesObjectExist(parachuteObjectSac) then
        Game.DetachObject(parachuteObjectSac, true)
        Game.DeleteObject(parachuteObjectSac)
        parachuteObjectSac = nil
    end

    Game.SetCharComponentVariation(playerChar, 8, 0, 0)
	
	AnimObjIdle = false
    
    -- Variables globales
    parachuteObject = nil-- voile de parachute
    startHeight = 0.0

    -- Variables de physique
    horizontalSpeed = 0.0
    verticalSpeed = 0.0
    lateralSpeed = 0.0
    rotation = 0.0
    heading = 0.0
    pitch = 0.0
    roll = 0.0

    -- Constantes de physique
    -- Pour un ralentissement plus important : Réduire la vitesse de chute
    MIN_VERTICAL_SPEED = -20.0 -- Vitesse minimale de chute (ralentissement maximum)
    -- Pour un ralentissement moins important : Augmenter la vitesse de chute
    MAX_VERTICAL_SPEED = -30.0 -- Vitesse maximale de chute (accélération maximum)

    waitmoment = true -- Délai pour permettre au joueur de tomber avant l'activation
    ObjectAlpha = 0

    IsPlayerLeavePara = false
    IsPlayerLeaveParaSac = false
    TimerA = 0
    Ptxf = nil
    AttachPara = false
    IsDamageCalculated = false
    
    ScriptActivated = false
    DebugPrint("End Script parachute_player.lua")
end

-- Mise à jour des contrôles
function UpdateControls()
    -- Obtenir l'entrée du contrôleur
    local leftX, leftY, rightX, rightY = Game.GetPositionOfAnalogueSticks(0)
    
    -- Raccourci clavier
    if not Game.IsUsingController() then
        local keyboardX, keyboardY = Game.GetKeyboardMoveInput()
        leftX = keyboardX
        leftY = keyboardY
    end
    
    -- Stocker les dernières valeurs
    lastLeftStickX = leftStickX
    lastLeftStickY = leftStickY
    
    leftStickX = leftX
    leftStickY = leftY
end

-- Fonctions utilitaires
function CalculateLandingDamage(height, velocity)
    local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
    local damage = 0
    local maxHealth = 300 -- Vie maximale du joueur
    
    -- Vérifier si le joueur atterrit en piqué (angle négatif)
    if pitch < -8.0 then
        -- Dégâts basés sur la vélocité (seulement en piqué)
        if velocity < -12.0 then
            -- Calculer des dégâts très réduits basés sur la vélocité
            local velocityDamage = Game.Floor((-12.0 - velocity) * 0.2) -- Réduit de 2.0 à 0.2
            damage = damage + velocityDamage
        end
        
        -- Dégâts basés sur la différence de hauteur (seulement en piqué)
        local heightDiff = startHeight - height
        if heightDiff > 30.0 then
            -- Calculer des dégâts très réduits basés sur la hauteur
            local heightDamage = Game.Round((heightDiff - 30.0) * 0.05) -- Réduit de 0.5 à 0.05
            damage = damage + heightDamage
        end
        
        -- Dégâts basés sur l'angle d'atterrissage (piqué)
        -- Si le joueur atterrit en piqué fort (angle négatif), ajouter des dégâts minimes
        local pitchDamage = Game.Floor(Game.Absf(pitch) * 0.01) -- 0.01 dégâts par degré de piqué
        damage = damage + pitchDamage
        DebugPrint("DEBUG : Pitch damage: " .. pitchDamage .. " (pitch: " .. pitch .. ")")
    else
        -- Si le joueur n'est pas en piqué, aucun dégât
        DebugPrint("DEBUG : No damage - player not in dive (pitch: " .. pitch .. ")")
    end
    
    -- Limiter les dégâts à 80% de la vie maximale (pour éviter la mort instantanée)
    local maxDamage = Game.Floor(maxHealth * 0.8)
    if damage > maxDamage then
        damage = maxDamage
    end
    
    -- Appliquer les dégâts au joueur et retourner la vie restante
    if damage > 0 then
        local currentHealth = Game.GetCharHealth(playerChar)
        local newHealth = currentHealth - damage
        
        -- S'assurer que la vie ne descend pas en dessous de 1
        if newHealth < 1 then
            newHealth = 1
        end
        
        --Game.SetCharHealth(playerChar, newHealth)
        --DebugPrint("DEBUG : Damage: " .. damage .. ", Health: " .. newHealth)
        return newHealth
    else
        -- Aucun dégât, retourner la vie actuelle
        local currentHealth = Game.GetCharHealth(playerChar)
        return currentHealth
    end
end

function CreateFakeParachuteSac()
	local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
	local x, y, z = Game.GetCharCoordinates(playerChar)
	LoadModels(1276771907)
	
	parachuteObjectSac2 = Game.CreateObject(1276771907, x, y, z - 25.0, false)
	if(parachuteObjectSac2 ~= nil) then 
		Game.AttachObjectToPed(parachuteObjectSac2, playerChar, 1202, 0.2980, 0.0025, 0.0, 0.0, 1.5900, 0.0, true)
		Game.SetObjectDynamic(parachuteObjectSac2, false)
		Game.SetObjectCollision(parachuteObjectSac2, false)
		Game.SetObjectVisible(parachuteObjectSac2, true)
		DebugPrint("ParachuteSacObject fake created")
	end
end

function CreateParachuteSacObject()
	local playerId = Game.GetPlayerId()
    local playerChar = Game.GetPlayerChar(playerId)
	local x, y, z = Game.GetCharCoordinates(playerChar)
	LoadModels(1276771907)
	
	parachuteObjectSac = Game.CreateObject(1276771907, x, y, z - 25.0, false)
	if(parachuteObjectSac ~= nil) then 
		Game.AttachObjectToPed(parachuteObjectSac, playerChar, 1202, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true)
		Game.SetObjectDynamic(parachuteObjectSac, false)
		Game.SetObjectCollision(parachuteObjectSac, false)
		Game.SetObjectVisible(parachuteObjectSac, false)
		--Game.SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(parachuteObjectSac, true)
		Game.MarkModelAsNoLongerNeeded(1276771907)
        DebugPrint("ParachuteSacObject created")
	end
end

function AttachParachuteObject()
	local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
	local x, y, z = Game.GetCharCoordinates(playerChar)
	
	if not parachuteObject then
		if( not Game.HasModelLoaded(1490460832)) then 
			LoadModels(1490460832)
		end
        parachuteObject = Game.CreateObject(1490460832, x, y, z + 10.0, true)
        if parachuteObject then
            Game.AttachObjectToPed(parachuteObject, playerChar, 0, 0.025, -0.125, 5.45, 0.0, 0.0, 0.0, true)
            --Game.SetObjectCollision(parachuteObject, true)
            DebugPrint("ParachuteObject attached to ped")
        end
    end
end

-- Physique de base pour le parachute déployé (vitesses par défaut)
function UpdateDeployedPhysics()
    
    -- Vitesse de descente constante par défaut
    local defaultVerticalSpeed = -6.0
    local defaultHorizontalSpeed = 10.0 -- Augmenter la vitesse d'avancement par défaut
    
    -- Maintenir une vitesse de descente constante (seulement si pas de contrôle actif)
    if verticalSpeed > defaultVerticalSpeed - 1.0 and verticalSpeed < defaultVerticalSpeed + 1.0 then
        verticalSpeed = SmoothLerp(verticalSpeed, defaultVerticalSpeed, 0.1)
    end
    
    -- Maintenir une vitesse horizontale minimale pour l'avancement
    if horizontalSpeed < defaultHorizontalSpeed then
        horizontalSpeed = SmoothLerp(horizontalSpeed, defaultHorizontalSpeed, 0.05)
    end
    
    -- Appliquer la traînée latérale progressivement
    lateralSpeed = SmoothLerp(lateralSpeed, 0.0, 0.2)
    
    -- Normaliser le cap
    while heading > 180.0 do heading = heading - 360.0 end
    while heading < -180.0 do heading = heading + 360.0 end
    
    -- Gérer le roulis basé sur le mouvement latéral
    roll = SmoothLerp(roll, (lateralSpeed * 15.0), 0.05)
end

-- Ouvrir le parachute
function OpenParachute()
    local playerId = Game.GetPlayerId()
	local playerChar = Game.GetPlayerChar(playerId)
    
    SwithParaState(4)
    
    -- Jouer l'animation d'ouverture
    Game.TaskPlayAnimNonInterruptable(playerChar, "Open_chute", "PARACHUTE", 10.0, false, true, true, false, 0)
    
    -- Créer l'objet parachute
    AttachParachuteObject()
    
    -- Jouer le son d'ouverture
    Game.PlaySoundFromPed(-1, "PARACHUTE_OPEN", playerChar)
    
    -- Arrêter le son de chute libre
    if soundId ~= -1 then
        Game.StopSound(soundId)
        Game.ReleaseSoundId(soundId)
    end
    
    -- Commencer le son de descente
    soundId = Game.GetSoundId()
    Game.PlaySoundFromPed(soundId, "PARACHUTE_DESCEND", playerChar)
	DebugPrint("parachute ouvert")
end

-- Mises à jour de physique en chute libre
function UpdateFreefallPhysics()
    -- Appliquer la gravité (réduite pour une chute plus lente)
    verticalSpeed = verticalSpeed - 0.01
    
    -- Limiter la vitesse verticale à des valeurs réalistes de chute libre
    verticalSpeed = Clamp(verticalSpeed, MAX_VERTICAL_SPEED, MIN_VERTICAL_SPEED)
    
    -- Maintenir une vitesse horizontale minimale pour l'avancement
    if horizontalSpeed < 3.0 then
        horizontalSpeed = SmoothLerp(horizontalSpeed, 3.0, 0.05)
    end
    
    -- Appliquer la traînée horizontale plus progressivement (mais maintenir l'avancement)
    horizontalSpeed = SmoothLerp(horizontalSpeed, 2.5, 0.02)
    
    -- Appliquer la traînée latérale
    lateralSpeed = SmoothLerp(lateralSpeed, 0.0, 0.3)
end