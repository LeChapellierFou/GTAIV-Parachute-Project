-- Variables globales
parachuteState = 0 -- 0: normal, 1: véhicule, 2: transition, 3: chute libre, 4: ouverture, 5: déployé, 7: atterrissage, 8: ragdoll
parachuteObject = nil-- voile de parachute
parachuteObjectSac = nil-- sac de parachute
parachuteObjectSac2 = nil-- sac de parachute
vehicleObject = nil
soundId = -1
startHeight = 0.0
AnimObjIdle = false

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

-- Variables de contrôle
leftStickX = 0
leftStickY = 0
rightStickX = 0
rightStickY = 0
lastLeftStickX = 0
lastLeftStickY = 0

waitmoment = true -- Délai pour permettre au joueur de tomber avant l'activation
ScriptActivated = false -- Variable pour vérifier si le script est activé
ObjectAlpha = 0

IsPlayerLeavePara = false
IsPlayerLeaveParaSac = false
TimerA = 0
Ptxf = nil
AttachPara = false
SoundId_Decend = nil
SoundId_Land = nil
IsDamageCalculated = false

-- display debug print
DebugMessage = false