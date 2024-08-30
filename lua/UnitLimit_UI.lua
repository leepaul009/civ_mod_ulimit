--====================================================================================================================
-- Civ6LUA_Unit_Limit
-- Author: Paul, adapted by Ex2
--====================================================================================================================
include( "ProductionHelper" );
local G_Debug = false;

-- 仅当有调试需求的时候运行
function GetProductions(playerID)
	print("  -----------------------------------------------------------------------------------------");
	local pPlayer = Players[playerID]
	local pPlayerConfig = PlayerConfigurations[ playerID ];
	local pPlayerCivName = pPlayerConfig:GetCivilizationTypeName();
	print("  [UnitLimit::GetProductions] Player(" .. pPlayerCivName .. ") has following productions:");
	
    local playerCities :table = pPlayer:GetCities()

	--local outputs = {};
	local outputsID = 1;
	
	for i, iCity in playerCities:Members() do
		print("   -[UnitLimit::GetProductions] city id:" .. iCity:GetID() .. ", idx:"..i..", city name: " .. Locale.Lookup(iCity:GetName()));

		local pBuildQueue :table = iCity:GetBuildQueue();
		if pBuildQueue == nil then
			print("        [UnitLimit::GetProductions] Error! No production queue in city!");
		end
		if(not iCity:GetID()) then 
			print("        [UnitLimit::GetProductions] Error! No ID for city!");
		end
		if (iCity:GetID()) and (pBuildQueue ~= nil) then		
			local currentProductionHash: number = pBuildQueue:GetCurrentProductionTypeHash();
			local hash:number = 0;
			
			if currentProductionHash == 0 then
				print("        [UnitLimit::GetProductions] no current production from city " .. Locale.Lookup(iCity:GetName()) );
			else
				hash = currentProductionHash;				
				local buildingDef	:table = GameInfo.Buildings[hash];
				local districtDef	:table = GameInfo.Districts[hash];
				local unitDef		:table = GameInfo.Units[hash];
				local projectDef	:table = GameInfo.Projects[hash];
				local prodTurnsLeft		:number = -1;
				local productionName	:string = "";
				local description		:string = "";
				local progress			:number = 0;
				local percentComplete	:number = 0;
				local cost				:number = 0;
				local prodType;

				if( buildingDef ~= nil ) then
					prodTurnsLeft   = pBuildQueue:GetTurnsLeft(buildingDef.BuildingType);
					productionName	= Locale.Lookup(buildingDef.Name);
					description		= buildingDef.Description;
					progress		= pBuildQueue:GetBuildingProgress(buildingDef.Index);
					percentComplete	= progress / pBuildQueue:GetBuildingCost(buildingDef.Index);
					cost			= pBuildQueue:GetBuildingCost(buildingDef.Index);
					prodType		= "BUILDING";
				elseif( districtDef ~= nil ) then
					prodTurnsLeft 	= pBuildQueue:GetTurnsLeft(districtDef.DistrictType);
					productionName	= Locale.Lookup(districtDef.Name);
					description		= districtDef.Description;
					progress		= pBuildQueue:GetDistrictProgress(districtDef.Index);
					percentComplete	= progress / pBuildQueue:GetDistrictCost(districtDef.Index);
					cost			= pBuildQueue:GetDistrictCost(districtDef.Index);
					prodType		= "DISTRICT";
				elseif( unitDef ~= nil ) then
					prodTurnsLeft   = pBuildQueue:GetTurnsLeft(unitDef.UnitType);
					local eMilitaryFormationType :number = pBuildQueue:GetCurrentProductionTypeModifier();
					productionName	= Locale.Lookup(unitDef.Name);
					description		= unitDef.Description;
					progress		= pBuildQueue:GetUnitProgress(unitDef.Index);
					prodTurnsLeft	= pBuildQueue:GetTurnsLeft(unitDef.UnitType, eMilitaryFormationType);
					prodType		= unitDef.UnitType;
					-- statString	= GetFilteredUnitStatString(FilterUnitStats(hash));
					-- outputs[outputsID] = {unitDef.UnitType, unitDef.Index};
					-- outputsID = outputsID + 1;
				elseif (projectDef ~= nil) then
					prodTurnsLeft 	= pBuildQueue:GetTurnsLeft(projectDef.ProjectType);
					productionName	= Locale.Lookup(projectDef.Name);
					description		= projectDef.Description;
					progress		= pBuildQueue:GetProjectProgress(projectDef.Index);
					cost			= pBuildQueue:GetProjectCost(projectDef.Index);
					percentComplete	= progress / pBuildQueue:GetProjectCost(projectDef.Index);
					prodType		= "PROJECT";
				else
					print("        [UnitLimit::GetProductions] Game database does not contain information that matches what the city "
						..Locale.Lookup(iCity:GetName()).." is producing!");
				end

				print("        [UnitLimit::GetProductions] production=" ..productionName.. 
					 " prodType=" ..prodType..
					" left_turn=" ..prodTurnsLeft.. 
					 " progress=" ..progress.. 
					     " cost=" ..cost.. 
					" from city " ..Locale.Lookup(iCity:GetName()) );						
			end
		end -- if cityID & pBuildQueue		
	end -- end city loop
	
	print("  -----------------------------------------------------------------------------------------");

end


function GetUnitInQueue(playerID, cityID)

	if playerID==nil or cityID==nil then
		print("      [UnitLimit::EM::GetUnitInQueue] Error! Invalid playerID or cityID! " );
		return nil;
	end
	
	local output = {};
	local pPlayer = Players[playerID];
	if pPlayer==nil then
		print("      [UnitLimit::EM::GetUnitInQueue] Error! Invalid player instance with given playerID! " );
		return nil;
	end
	
	local pCity:table = pPlayer:GetCities():FindID(cityID);
	if pCity == nil then
		local pPlayerConfig  = PlayerConfigurations[ playerID ];
		local pPlayerCivName = pPlayerConfig:GetCivilizationTypeName();
		print("      [UnitLimit::EM::GetUnitInQueue] Error! For civ="..pPlayerCivName..", cityID="..cityID..
					" get invalid city="..Locale.Lookup(pCity:GetName()).."!" );
		return nil;
	end
	
	if G_Debug then
		local pPlayerConfig = PlayerConfigurations[ playerID ];
		local pPlayerCivName = pPlayerConfig:GetCivilizationTypeName();
		print("        [UnitLimit::EM::GetUnitInQueue] 城市 "..Locale.Lookup(pCity:GetName())..":");
	end

	local pBuildQueue:table = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		print("        [UnitLimit::EM::GetUnitInQueue] Error! No production queue in city "..Locale.Lookup(pCity:GetName()).."!");
		return nil;
	end

	--
	if G_Debug then print("                                      + 建造队列数量："..pBuildQueue:GetSize()); end
	for i = 0, pBuildQueue:GetSize()-1 do
		local entry:table = pBuildQueue:GetAt(i);
		if entry then
			if entry.Directive == CityProductionDirectives.TRAIN then
				local pUnitDef:table = GameInfo.Units[entry.UnitType];
				local unitName:string = Locale.Lookup(pUnitDef.Name);
				if G_Debug then print("                                      + 队列第"..i.."个项目："..unitName); end
			end
		end
		if i >= 1 then
			if G_Debug then print("                                      + 删除队列第"..i.."个项目"); end
			RemoveQueueItem(i);
		end
	end
	-- local unit_type = GameInfo.Units["UNIT_SCOUT"].Index
	-- local unit_progress = pBuildQueue:GetUnitProgress(unit_type)
	-- print("                                      + 建造池中存在scout,"..unit_progress);
	-- local unit_type = GameInfo.Units["UNIT_WARRIOR"].Index
	-- local unit_progress = pBuildQueue:GetUnitProgress(unit_type)
	-- print("                                      + 建造池中存在warrior,"..unit_progress);
	-- local unit_type = GameInfo.Units["UNIT_BUILDER"].Index
	-- local unit_progress = pBuildQueue:GetUnitProgress(unit_type)
	-- print("                                      + 建造池中存在builder,"..unit_progress);
	--

	local hash: number = pBuildQueue:GetCurrentProductionTypeHash();
	--  pBuildQueue:GetPreviousProductionTypeHash();
	if hash == 0 then -- has=0时表示Nothing being produced.
		if G_Debug then
			print("                                      + No production from city" );
		end
		return nil;
	else
		-- 如果hash不属于Units，比如hash属于建筑物，则GameInfo.Units[hash]得到的变量是nil
		local unitDef:table = GameInfo.Units[hash];
		
		if( unitDef ~= nil ) then -- this city has building in queue
			--output = { 	unitDef.UnitType,  unitDef.Index,  Locale.Lookup(unitDef.Name)  }; -- {type, index, name}
			output["type"] = unitDef.UnitType;	-- UNIT_??
			output["index"] = unitDef.Index;	-- 数字
			output["name"] = Locale.Lookup(unitDef.Name); -- 名字
			if G_Debug then
				print("                                      + 建造池中存在的单位： ("
					   ..tostring(unitDef.UnitType)..
					" "..tostring(unitDef.Index)..
					" "..Locale.Lookup(unitDef.Name) ..").");
			end
			return output;
		else
			if G_Debug then
				print("                                      + 建造池中不存在单位 " 
					.. Locale.Lookup(pCity:GetName()) );
			end
			return nil;
		end
		
	end

	--return output;
end

function RemoveUnitInQueue(playerID, cityID)
	if playerID==nil or cityID==nil then
		print("      [UnitLimit::EM::RemoveUnitInQueue] Error! Invalid playerID or cityID! " );
		return false;
	end
	
	local pPlayer = Players[playerID];
	if pPlayer==nil then
		print("      [UnitLimit::EM::RemoveUnitInQueue] Error! Invalid player instance with given playerID! " );
		return false;
	end
	
	local pCity:table = pPlayer:GetCities():FindID(cityID);
	if pCity == nil then
		local pPlayerConfig  = PlayerConfigurations[ playerID ];
		local pPlayerCivName = pPlayerConfig:GetCivilizationTypeName();
		print("      [UnitLimit::EM::GetUnitInQueue] Error! For civ="..pPlayerCivName..", cityID="..cityID..
					" get invalid city="..Locale.Lookup(pCity:GetName()).."!" );
		return false;
	end
	
	if G_Debug then print("        [UnitLimit::EM::RemoveUnitInQueue] 城市 "..Locale.Lookup(pCity:GetName())..":"); end

	local pBuildQueue:table = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		print("        [UnitLimit::EM::RemoveUnitInQueue] Error! No production queue in city "..Locale.Lookup(pCity:GetName()).."!");
		return false;
	end

	if G_Debug then print("                                      + 建造队列数量："..pBuildQueue:GetSize()); end
	for i = 0, pBuildQueue:GetSize()-1 do
		local entry:table = pBuildQueue:GetAt(i);
		if entry then
			if entry.Directive == CityProductionDirectives.TRAIN then
				local pUnitDef:table = GameInfo.Units[entry.UnitType];
				local unitName:string = Locale.Lookup(pUnitDef.Name);
				if G_Debug then print("                                      + 队列第"..i.."个项目："..unitName); end
			end
		end
		if G_Debug then print("                                      + 删除队列第"..i.."个项目"); end
		RemoveQueueItem(i);
	end
	return true
end

--[[
function Initialize()
	if not ExposedMembers.Revolutionist then 
		--ExposedMembers.Revolutionist = {} 
		print("+++++++++++++++++++++++++++++++++++++ no ");
		ExposedMembers.Revolutionist.GetCurrentGovernment = GetCurrentGovernment;
	end
end
Initialize();
]]--

print("3.+++++++++++++++++++++++++++++++++++++ Loading UnitLimit_UI.lua...");
ExposedMembers.UnitLimitInfo.GetProductions    = GetProductions;
ExposedMembers.UnitLimitInfo.GetUnitInQueue    = GetUnitInQueue;
ExposedMembers.UnitLimitInfo.RemoveUnitInQueue = RemoveUnitInQueue;

