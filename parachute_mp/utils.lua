--[[
	Parachute/Basejumping Project GTA IV By LeChapellierFou, 10/09/2025
    utils functions
]]

-- Check if string is a number.
function isNumber(str)
	local num = tonumber(str)
	if not num then return false
	else return true
	end
end

LoadModels = function(model)
    
    local hash
    if isNumber(model) then 
        hash = model
    else
        hash = Game.GetHashKey(model)
    end
    
    if(Game.IsModelInCdimage(hash)) then 
        Game.RequestModel(hash)
        Game.LoadAllObjectsNow()
        while not Game.HasModelLoaded(hash) do
            Game.RequestModel(hash)
            Thread.Pause(0)
        end

        return true
    else
        Console.Log("Error, hash :"..hash.." doesnt exist")
        return false
    end
end

function IsPlayerNearCoords(x, y, z, radius)
    local pos = table.pack(Game.GetCharCoordinates(Game.GetPlayerChar(Game.GetPlayerId())))
   local dist = Game.GetDistanceBetweenCoords3d(x, y, z, pos[1], pos[2], pos[3])
   if(dist < radius) then return true
   else return false
   end
end

function LoadAnimDict(set)
	while not Game.HaveAnimsLoaded(set) do
		Game.RequestAnims(set)
		Thread.Pause(0)
	end
end

function PrintHelp(msg)
    if (not Game.IsThisHelpMessageBeingDisplayed(msg)) then
        Game.ClearHelp()
        Game.PrintHelp(msg)
    end
end

function DebugPrint(msg)
    if DebugMessage then
        Console.Log(msg)
    end
end
