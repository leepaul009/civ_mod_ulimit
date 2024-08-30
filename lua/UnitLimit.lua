--====================================================================================================================
-- Civ6LUA_Unit_Limit
-- Author: Paul, adapted by Ex2
--====================================================================================================================

local G_IsDebug = false
local G_BaseDebug = true
local bExecuteThisFile = true

--====================================================================================================================
--	Capital Weight
--====================================================================================================================

-- capital districts and buildings will grant units equal to this number of non-capital cities' districts and buildings
-- not used
local pCapitalWeight = 2 

--====================================================================================================================
--	Land Unit Limit Variables:
--====================================================================================================================
local nLandPalaceUnitTypeQuota 	  = 5
local nLandUnitCityMultiplier 	  = 1.0
local nLandUnitDistrictMultiplier = 0 
local nLandUnitBuildingMultiplier = 0 
local pLandDistrictType = "DISTRICT_ENCAMPMENT"
local tLandDistrictBuildingsTable = GameInfo.ULE_EncampmentBuildings
local tLandFormationClassTable = GameInfo.ULE_LandCombatFormationClassUnits
local pLandUnitForcesType = "LAND COMBAT"
--====================================================================================================================
--	Sea Unit Limit Variables:
--====================================================================================================================
local nSeaPalaceUnitTypeQuota    = 5
local nSeaUnitCityMultiplier     = 0.1
local nSeaUnitDistrictMultiplier = 0
local nSeaUnitBuildingMultiplier = 0
local pSeaDistrictType = "DISTRICT_HARBOR"
local pSeaDistrictAltUniqueType = "DISTRICT_ROYAL_NAVY_DOCKYARD"
local tSeaDistrictBuildingsTable = GameInfo.ULE_HarborBuildings
local tSeaFormationClassTable = GameInfo.ULE_SeaCombatFormationClassUnits
local pSeaUnitForcesType = "NAVAL COMBAT"
--====================================================================================================================
--	Support Unit Limit Variables:
--====================================================================================================================
local nSupportPalaceUnitTypeQuota    = 5
local nSupportUnitCityMultiplier     = 0.1
local nSupportUnitDistrictMultiplier = 0
local nSupportUnitBuildingMultiplier = 0
local pSupportDistrictType = "DISTRICT_ENCAMPMENT"
local tSupportDistrictBuildingsTable = GameInfo.ULE_EncampmentBuildings
local tSupportFormationClassTable = GameInfo.ULE_SupportFormationClassUnits
local pSupportUnitForcesType = "SUPPORT"
--====================================================================================================================
--	Religious Unit Limit Variables:
--====================================================================================================================
local nHolyPalaceUnitTypeQuota    = 10
local nHolyUnitCityMultiplier     = 0.1
local nHolyUnitDistrictMultiplier = 0
local nHolyUnitBuildingMultiplier = 0
local pHolyDistrictType = "DISTRICT_HOLY_SITE"
local pHolyDistrictAltUniqueType = "DISTRICT_LAVRA"
local tHolyDistrictBuildingsTable = GameInfo.ULE_HolySiteBuildings
local tHolyFormationClassTable = GameInfo.ULE_HolyFormationClassUnits
local pHolyUnitForcesType = "RELIGIOUS"

--====================================================================================================================
--	Individual Civilian Units Limit Variables:
--====================================================================================================================
local nBuilderPalaceUnitTypeQuota = 5
local nBuilderUnitCityMultiplier  = 0.1
local pBuilderUnitForcesType = "BUILDER"
local iBuilderUnit = GameInfo.Units["UNIT_BUILDER"].Index

local nSettlerPalaceUnitTypeQuota = 2
local nSettlerUnitCityMultiplier = 0 
local pSettlerUnitForcesType = "SETTLER"
local iSettlerUnit = GameInfo.Units["UNIT_SETTLER"].Index

--====================================================================================================================
--	City States Settings
--====================================================================================================================
local tExemptPlayers = GameInfo.ULE_CityStates
local nCityStateAllowedLandUnits = 10
local nCityStateAllowedSeaUnits = 5
local nCityStateAllowedSupportUnits = 2
local nCityStateAllowedBuilderUnits = 3
local nCityStateAllowedSettlerUnits = 0

--====================================================================================================================
--	Identifiers 一种特殊建筑，用于控制“能否建造某种类型的unit”
--====================================================================================================================
local pHolyBuilding    = "BUILDING_ULE_HOLY_INTERNAL"
local pLandBuilding    = "BUILDING_ULE_LAND_INTERNAL"
local pSeaBuilding     = "BUILDING_ULE_SEA_INTERNAL"
local pSupportBuilding = "BUILDING_ULE_SUPPORT_INTERNAL"
local pBuilderBuilding = "BUILDING_ULE_BUILDER_INTERNAL"
local pSettlerBuilding = "BUILDING_ULE_SETTLER_INTERNAL"

local nEventUnitComplete = 1911
local nEventUnitChange   = 1912

function CityIsExemptCity(cityID)
	for k, v in pairs(ExposedMembers.UnitLimitProcessedCity) do
		--print("        check ExemptCity. k="..tostring(k).." v="..v); 
		if k == cityID then return true end
	end
	return false
end

function UpdateExemptCityTable(playerID, cityID)
	ExposedMembers.UnitLimitProcessedCity[cityID] = 1
end

function InitExemptCityTable(playerID)
	ExposedMembers.UnitLimitProcessedCity = {}
end

--@func: Math Functions Toolkit
function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

---------------------------------------------------------------------
-- 判断“正在建造的单位”是否匹配“目标单位类型”
function InQueueUnitMatchTargetUnitType(tFormationClassTable, unitInQueue, pUnitForcesType)
	if pUnitForcesType == "SETTLER" or pUnitForcesType == "BUILDER" then
		if tFormationClassTable == unitInQueue["index"] then
			return true;
		else
			return false;
		end
	end
	for row in tFormationClassTable() do
		-- 正在建造的单位 匹配了 当前想要限制的类型 内的某一个单位
		if GameInfo.Units[row.UnitType].Index == unitInQueue["index"] then
			if G_IsDebug then
				print("          匹配! 正在建造的单位 "..tostring(unitInQueue["type"])..
					  " 是我们要限制的单位: "..row.UnitType..", 限制的类型(组): "..pUnitForcesType);
			end
			return true;
		end
	end
	if G_IsDebug then print("          不匹配! 正在建造的单位: "..tostring(unitInQueue["type"]).." 不是我们想要限制的类型(组): "..pUnitForcesType); end
	return false;
end

function RemoveIBuilding( pPlayerID, iCity, iBuilding, tFormationClassTable, pUnitForcesType,  pPlayerCivName, pBuildingType )
	local isTargetUnitTypeOnBuilding = false;
	local cityID = iCity:GetID();
	local unitInQueue = ExposedMembers.UnitLimitInfo.GetUnitInQueue(pPlayerID, cityID); -- {type, index, name}
	if unitInQueue ~= nil then
		isTargetUnitTypeOnBuilding = InQueueUnitMatchTargetUnitType(tFormationClassTable, unitInQueue, pUnitForcesType);
	end	
	-- 保留正在建造的单位
	if isTargetUnitTypeOnBuilding then
		if G_IsDebug then
			print("        超过限制! 但是, 保留正在训练的'对应单位'. 玩家 "..pPlayerCivName..
					" 可以建造 "..pBuildingType.." 在城市 "..Locale.Lookup(iCity:GetName()) );
		end
		PlaceBuildingInCityCenter(iCity, iBuilding);
	else
		RemoveBuildingFromCityCenter(iCity, iBuilding);
	end
end

-- 对目标类型单位（陆地，海洋...）进行处理。 6 space + 8 space
---- 参数： iBuilding: “目标类型单位”对应的“启动建筑”的index
function UpdateAllCityStatus(pPlayer, targetCityID, iBuilding, nMax, nExist, tFormationClassTable, pUnitForcesType, eventID)
	if G_IsDebug then print("      [UL::UpdateAllCityStatus]") end
	local isAllowed	 = (nMax > nExist);
	local pPlayerID      = pPlayer:GetID();
	local pPlayerConfig  = PlayerConfigurations[ pPlayerID ];
	local pPlayerCivName = pPlayerConfig:GetCivilizationTypeName();
	local tPlayerCities = pPlayer:GetCities();
	local pBuildingType = GameInfo.Buildings[iBuilding].BuildingType;
	
	-- 存在target city时，表示“建设事件”，我们只处理这个城市
	-- 如果是unit complete事件, or unit change事件:
	if targetCityID ~= nil then
		local unitInQueue = ExposedMembers.UnitLimitInfo.GetUnitInQueue(pPlayerID, targetCityID); -- {type, index, name}
		local targetCity:table = pPlayer:GetCities():FindID(targetCityID);

		local isTargetUnitTypeOnBuilding = false;
		if unitInQueue ~= nil then
			isTargetUnitTypeOnBuilding = InQueueUnitMatchTargetUnitType(tFormationClassTable, unitInQueue, pUnitForcesType);
		end

		if isTargetUnitTypeOnBuilding then
			if nExist < nMax then
				PlaceBuildingInCityCenter(targetCity, iBuilding); -- 此城市启动
			elseif nExist == nMax then
				-- case unit complete + exist==max(pUnitForcesType) + not empty queue + queue item is pUnitForcesType  ==> add iBuilding to targetCity
				for i, iCity in tPlayerCities:Members() do
					local iCityID = iCity:GetID();
					if iCityID == targetCityID then
						PlaceBuildingInCityCenter(iCity, iBuilding); -- 此城市启动
					else -- city other than target city:
						-- 如果是自然的unit complete，是不需要这步的；因为后一个event必然是init，这里会计算这步的
						-- 但如果是用金币、信仰买的unit complete，exist==max表示complete前，没有到上限，所有城市可以建造；而complete后，加上queue内单位，刚好到上限，需要此步
						RemoveIBuilding( pPlayerID, iCity, iBuilding, tFormationClassTable, pUnitForcesType,  pPlayerCivName, pBuildingType )
					end
				end
			else -- nExist > nMax
				-- 这里不会发生“人为”的case unit change，因为人为的改变建设单位之前，肯定会出发init event
				-- 但是这里会发生“队列”产生的case unit change
				-- case unit complete + exist>max(pUnitForcesType) + not empty queue +  queue item is pUnitForcesType  ==> remove iBuilding to targetCity
				RemoveBuildingFromCityCenter(targetCity, iBuilding); -- 此城市禁止
				if eventID == nEventUnitComplete then
					if G_IsDebug then print("        城市"..Locale.Lookup(targetCity:GetName()).."已经超过限制:n_exist("..nExist..") > n_max("..nMax..")，但是仍然尝试制造"..pUnitForcesType); end
					status = ExposedMembers.UnitLimitInfo.RemoveUnitInQueue(pPlayerID, targetCityID)
					if not(status) then print("        Failed to remove unit in building-queue"); end
				end
			end
		else
			if nExist < nMax then -- 所有城市启动
				for i, iCity in tPlayerCities:Members() do
					PlaceBuildingInCityCenter(iCity, iBuilding);
				end
			else -- nExist >= nMax
				RemoveBuildingFromCityCenter(targetCity, iBuilding); -- 只禁止此城市，不需要禁止其他城市
			end
		end
	else -- 不存在target city时，对所有城市(init event):
		if G_IsDebug then print("      对所有城市:") end
		for i, iCity in tPlayerCities:Members() do

			local cityID = iCity:GetID();
			local is_exempt_city = false;
			is_exempt_city = CityIsExemptCity(cityID);

			if is_exempt_city then
				if G_IsDebug then print("        城市 "..Locale.Lookup(iCity:GetName()).." 在前面的unit even中处理过, 可以忽略." ); end
			else
				if isAllowed then
					PlaceBuildingInCityCenter(iCity, iBuilding);
				else
					RemoveIBuilding( pPlayerID, iCity, iBuilding, tFormationClassTable, pUnitForcesType,  pPlayerCivName, pBuildingType )
				end	-- end if
			end
		end -- end for
	end --end if
end




-- 建设“某种unit对应的特殊建筑”，以允许此种unit的建造, 8 space
function PlaceBuildingInCityCenter(pCity, iBuilding)
	local iCityPlotIndex = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex();
	-- 当前城市 没有建筑iBuilding：
	if not pCity:GetBuildings():HasBuilding(iBuilding) then
		-- if G_IsDebug then
		-- 	print ("      [UL::启动]: Attempting to add Building ID#" .. iBuilding ..
		-- 		" : " .. GameInfo.Buildings[iBuilding].BuildingType .. 
		-- 		" to the city of " .. Locale.Lookup(pCity:GetName()));
		-- end
		pCity:GetBuildQueue():CreateIncompleteBuilding(iBuilding, iCityPlotIndex, 100);
		-------------------------------------------------------------------------------
		if pCity:GetBuildings():HasBuilding(iBuilding) then
			if G_IsDebug then print ("        [UL::启动] 成功，添加'启动建筑'在城市"..Locale.Lookup(pCity:GetName())..".") end
		else
			if G_IsDebug then print ("        [UL::启动] 失败，未能添加'启动建筑'在城市"..Locale.Lookup(pCity:GetName())..".") end
		end
	-- 当前城市 有建筑iBuilding：
	else
		if G_IsDebug then
			print ("        [UL::启动] 启动建筑(ID=" .. iBuilding .. 
				", type=" .. GameInfo.Buildings[iBuilding].BuildingType .. 
				")已经存在，在城市 " .. Locale.Lookup(pCity:GetName()));
		end
		if pCity:GetBuildings():IsPillaged(iBuilding) then
			if G_IsDebug then
				print ("        [UL::启动] 建筑被焚毁，恢复此建筑.");
			end
			pCity:GetBuildings():RemoveBuilding(iBuilding);
			pCity:GetBuildQueue():CreateIncompleteBuilding(iBuilding, iCityPlotIndex, 100);
		end -- end pillaged
	end -- end building existing
end

-- 去除“某种unit对应的特殊建筑”，以禁止此种unit的建造, 8 space
function RemoveBuildingFromCityCenter(pCity, iBuilding)
	-- local iCityPlotIndex = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex();
	
	if pCity:GetBuildings():HasBuilding(iBuilding) then
		-- if G_IsDebug then
		-- 	print ("      [UL::关闭] Attempting to REMOVE Building ID#" .. iBuilding .. 
		-- 		" : " .. GameInfo.Buildings[iBuilding].BuildingType .. 
		-- 		" from the city of " .. Locale.Lookup(pCity:GetName()));
		-- end
		pCity:GetBuildings():RemoveBuilding(iBuilding);
		------------------------------------------------------------------
		if pCity:GetBuildings():HasBuilding(iBuilding) then
			if G_IsDebug then print ("        [UL::关闭] FAILED to REMOVE Building at city "..Locale.Lookup(pCity:GetName())..".") end
		else
			if G_IsDebug then print ("        [UL::关闭] 成功删除'启动建筑'在城市"..Locale.Lookup(pCity:GetName())..".") end
		end
	else
		if G_IsDebug then print ("        [UL::关闭] '启动建筑'此前已经被删除，在城市"..Locale.Lookup(pCity:GetName())..".") end
	end
end


---------------------------------------------------------------------
-- 计算陆地、海洋、辅助、宗教单位的数量:
function GetFormationClassUnitLimit(pPlayer, pPlayerCivName, 
	nUnitCityRatio, nUnitDistrictRatio, nUnitBuildingRatio, nPalaceUnitTypeQuota, 
	pDistrictType, tDistrictBuildingsTable, pUnitForcesType)
	
	local nPalaceAllotment;
	local nPlayerUnitCityAllotment;
	local nPlayerDistAllotment;
	local nPlayerBldgAllotment;
	local nPlayerCityCount = pPlayer:GetCities():GetCount();
	local totalPopulation  = 0;
	
	if nPlayerCityCount == nil or nPlayerCityCount == 0 or nPlayerCityCount == -1 then
		if G_IsDebug then print ("  [UL::计算最大单位数量] " .. pPlayerCivName .. " 没有城市, max unit = 0.") end
		return 0;
	else
		nPalaceAllotment 		 = nPalaceUnitTypeQuota;
		nPlayerUnitCityAllotment = 0;
		nPlayerDistAllotment 	 = 0;
		nPlayerBldgAllotment 	 = 0;
		local tPlayerCities 	 = pPlayer:GetCities();
		
		for i, iCity in tPlayerCities:Members() do
			local iPopulation = iCity:GetPopulation();
			totalPopulation = totalPopulation + iPopulation;
		end
		nPlayerUnitCityAllotment = totalPopulation * nUnitCityRatio;
	end

	local nTypeUnitLimitCount = nPalaceAllotment + nPlayerUnitCityAllotment + nPlayerDistAllotment + nPlayerBldgAllotment;
	local nTypeUnitLimitCountRounded = math.floor(nTypeUnitLimitCount);
	if G_IsDebug then
		print ("  [UL::计算最大单位数量] 玩家 "..pPlayerCivName.."(人口是 "..totalPopulation..") 最大单位数量="
			..nTypeUnitLimitCountRounded.."(宫殿+人口: "..nPalaceAllotment.."+"..nPlayerUnitCityAllotment..") 单位="..pUnitForcesType..".");
	end
	return nTypeUnitLimitCountRounded;
end

-- 计算工人、移民者的数量:
function GetIndividualUnitLimit(pPlayer, pPlayerCivName, nUnitCityRatio, nPalaceUnitTypeQuota, pUnitForcesType)

	local nPalaceAllotment;
	local nPlayerUnitCityAllotment;
	local nPlayerCityCount = pPlayer:GetCities():GetCount();
	local totalPopulation  = 0;
	
	if nPlayerCityCount == nil or nPlayerCityCount == 0 or nPlayerCityCount == -1 then 
		if G_IsDebug then print ("  [UL::计算最大单位数量] " .. pPlayerCivName .. " 没有城市, max unit = 0.") end
		return 0;
	else
		nPalaceAllotment 		 = nPalaceUnitTypeQuota;
		nPlayerUnitCityAllotment = 0;
		local tPlayerCities 	 = pPlayer:GetCities();
		
		for i, iCity in tPlayerCities:Members() do
			totalPopulation = totalPopulation + iCity:GetPopulation();
		end
		nPlayerUnitCityAllotment = totalPopulation * nUnitCityRatio;
	end

	local nTypeUnitLimitCount = nPalaceAllotment + nPlayerUnitCityAllotment;
	local nTypeUnitLimitCountRounded = math.floor(nTypeUnitLimitCount);
	if G_IsDebug then
		print ("  [UL::计算最大单位数量] 玩家 "..pPlayerCivName.."(人口是 "..totalPopulation..") 最大单位数量="
			..nTypeUnitLimitCountRounded.."(宫殿+人口: "..nPalaceAllotment.."+"..nPlayerUnitCityAllotment..") 单位="..pUnitForcesType..".");
	end
	return nTypeUnitLimitCountRounded;
end


---------------------------------------------------------------------

-- 单位类型'inUnitType'存在于表'tFormationClassTable'中:
function matchUnitTypeIndex(tFormationClassTable, inUnitType)
	for row in tFormationClassTable() do -- match types group in DB
		if GameInfo.Units[row.UnitType].Index == inUnitType then
			return true;
		end
	end
	return false;
end

-- 计算'正在建设的'单位数量:
function getNumOfUnitsInProductionQueue( pPlayerID )
	if G_IsDebug then print("    [UL::计算正在建设的单位数量] *************************************************************************** " ); end
	local numInQueue :table = {
		land 	= 0,
		sea 	= 0,
		support = 0,
		holy	= 0,
		builder = 0,
		settler = 0
	};
	local pPlayer = Players[ pPlayerID ];
	if pPlayer==nil then
		if G_IsDebug then print("    [UL::得到建设槽里的单位数量] Error! Invalid player instance with given playerID! " ); end
		return nil;
	end
	
	local pCities = pPlayer:GetCities();
	for i, iCity in pCities:Members() do
		if G_IsDebug then print("    [UL::计算正在建设的单位数量] 城市 "..Locale.Lookup(iCity:GetName())..":" ); end
		
		local cityID = iCity:GetID();
		local unitInQueue = ExposedMembers.UnitLimitInfo.GetUnitInQueue(pPlayerID, cityID); --{type, index, name}

		if unitInQueue == nil then
			if G_IsDebug then print("    [UL::计算正在建设的单位数量] No unit in queue. "); end
		else
			if G_IsDebug then 
				print("    [UL::计算正在建设的单位数量] Has unit in queue: 类型=" 
					..tostring(unitInQueue["type"])..
					" 序号="..tostring(unitInQueue["index"])..
					" 名字="..unitInQueue["name"]..
					" ，在城市="..Locale.Lookup(iCity:GetName()) ); 
			end
			-----------------------------------------------------------------------------------------
			if     ( matchUnitTypeIndex(tLandFormationClassTable, 	 unitInQueue["index"]) ) then
				numInQueue.land 	= numInQueue.land + 1;
			elseif ( matchUnitTypeIndex(tSeaFormationClassTable, 	 unitInQueue["index"]) ) then
				numInQueue.sea 		= numInQueue.sea + 1;
			elseif ( matchUnitTypeIndex(tSupportFormationClassTable, unitInQueue["index"]) ) then
				numInQueue.support 	= numInQueue.support + 1;
			elseif ( matchUnitTypeIndex(tHolyFormationClassTable, 	 unitInQueue["index"]) ) then
				numInQueue.holy 	= numInQueue.holy + 1;
			elseif ( iBuilderUnit == unitInQueue["index"] ) then
				numInQueue.builder 	= numInQueue.builder + 1;
			elseif ( iSettlerUnit == unitInQueue["index"] ) then
				numInQueue.settler 	= numInQueue.settler + 1;
			else
				-- do nothing
			end
			-----------------------------------------------------------------------------------------
		end
	end -- for each city
	if G_IsDebug then
		print("    [UL::计算正在建设的单位数量] Has "..numInQueue.land.." "..pLandUnitForcesType.." in queue.");
		print("                               Has "..numInQueue.sea.." "..pSeaUnitForcesType.." in queue.");
		print("                               Has "..numInQueue.support.." "..pSupportUnitForcesType.." in queue.");
		print("                               Has "..numInQueue.holy.." "..pHolyUnitForcesType.." in queue.");
		print("                               Has "..numInQueue.builder.." "..pBuilderUnitForcesType.." in queue.");
		print("                               Has "..numInQueue.settler.." "..pSettlerUnitForcesType.." in queue.");
	end
	return numInQueue;
end

-- 计算'当前存在的'单位数量:
function getNumOfUnitExist( pPlayer )
	if G_IsDebug then print("    [UL::计算exist单位] ***************************************************************************" ); end
	local numExistAndQueue :table = {
		land 	= 0,
		sea 	= 0,
		support = 0,
		holy	= 0,
		builder = 0,
		settler = 0
	};
	local tCurrentUnitSet = pPlayer:GetUnits();
	for k, iUnit in tCurrentUnitSet:Members() do -- for each unit
		local unit_type = iUnit:GetType();  -- unit type's index
		if unit_type ~= nil then
			if ( matchUnitTypeIndex(tLandFormationClassTable, unit_type) ) then
				numExistAndQueue.land = numExistAndQueue.land + 1;
			elseif ( matchUnitTypeIndex(tSeaFormationClassTable, unit_type) ) then
				numExistAndQueue.sea = numExistAndQueue.sea + 1;
			elseif ( matchUnitTypeIndex(tSupportFormationClassTable, unit_type) ) then
				numExistAndQueue.support = numExistAndQueue.support + 1;
			elseif ( matchUnitTypeIndex(tHolyFormationClassTable, unit_type) ) then
				numExistAndQueue.holy = numExistAndQueue.holy + 1;
			elseif iBuilderUnit == unit_type then
				numExistAndQueue.builder = numExistAndQueue.builder + 1;
			elseif iSettlerUnit == unit_type then
				numExistAndQueue.settler = numExistAndQueue.settler + 1;
			else
				-- do nothing
			end
		end
	end
	if G_IsDebug then 
		print ("    [UL::计算exist单位] Exist "..numExistAndQueue.land.." "..pLandUnitForcesType.." units."); 
		print ("                       Exist "..numExistAndQueue.sea.." "..pSeaUnitForcesType.." units."); 
		print ("                       Exist "..numExistAndQueue.support.." "..pSupportUnitForcesType.." units."); 
		print ("                       Exist "..numExistAndQueue.holy.." "..pHolyUnitForcesType.." units."); 
		print ("                       Exist "..numExistAndQueue.builder.." "..pBuilderUnitForcesType.." units."); 
		print ("                       Exist "..numExistAndQueue.settler.." "..pSettlerUnitForcesType.." units."); 
	end
	return numExistAndQueue;
end


---------------------------------------------------------------------
-- 判断是否是城邦
function CityStateDetecter(pPlayerCivName)
	if pPlayerCivName ~= nil then
		for row in tExemptPlayers() do
			if pPlayerCivName == row.CivilizationType then
				return true
			end
		end
	end
	return false
end


----------------------------------------------- 主函数: Event Hooks and Iterative Functions ---------------------------------------------------
-- bIsFirstTime: not used
function UpdateMaxNumberOfUnit(inPlayerID, bIsFirstTime, targetCityID, eventID)
  if inPlayerID == 63 then
		if G_IsDebug then print("[UL::主函数] ------------ 当前玩家是'野蛮人', "..tostring(inPlayerID)..", 什么都不做 ------------ ") end
		return;
  elseif inPlayerID ~= nil and inPlayerID ~= 63 and inPlayerID ~= -1 then
	local pPlayer            = Players[ inPlayerID ];
	local pPlayerConfig  	 = PlayerConfigurations[ inPlayerID ];
	local pPlayerCivName 	 = pPlayerConfig:GetCivilizationTypeName();
	local pPlayerCapitalCity = pPlayer:GetCities():GetCapitalCity();
	local isCityState = false;

	if G_IsDebug then print("[UL::主函数] 开始 ---------------------------------------------------------- ") end

	if CityStateDetecter(pPlayerCivName) then
		isCityState = true;
	end
	
	if pPlayerCapitalCity ~= nil then
		
		local numUnitTypeInQueue :table = getNumOfUnitsInProductionQueue( inPlayerID );
		local numUnitTypeExisted :table = getNumOfUnitExist( pPlayer );
		-- 现存的数量
		local nLandUnitCount 	= numUnitTypeInQueue.land 	 + numUnitTypeExisted.land;
		local nSeaUnitCount 	= numUnitTypeInQueue.sea 	 + numUnitTypeExisted.sea;
		local nSupportUnitCount = numUnitTypeInQueue.support + numUnitTypeExisted.support;
		local nHolyUnitCount 	= numUnitTypeInQueue.holy 	 + numUnitTypeExisted.holy;
		local nBuilderUnitCount = numUnitTypeInQueue.builder + numUnitTypeExisted.builder;
		local nSettlerUnitCount = numUnitTypeInQueue.settler + numUnitTypeExisted.settler;

		-- local pPlayerCapitalCityBuildings = pPlayerCapitalCity:GetBuildings();
		-- true if production is available.
		local isLandAvailable 		= true;
		local isHolyAvailable		= true;
		local isSeaAvailable		= true;
		local isSupportAvailable 	= true;
		local isBuilderAvailable 	= true;
		local isSettlerAvailable 	= true;		
		

		------ Land Unit -------------------------------------------------------------------------------------------------------------------------------------------------------
		if G_IsDebug then print("[UL::主函数] 陆地单位: ---------------------------------------------------------- ") end
		local nAllowedLandUnits = 1;
		if nLandUnitCount > 0 then
			if isCityState then	
				nAllowedLandUnits = nCityStateAllowedLandUnits;
			else
				nAllowedLandUnits = GetFormationClassUnitLimit(pPlayer, pPlayerCivName, 
					nLandUnitCityMultiplier, nLandUnitDistrictMultiplier, nLandUnitBuildingMultiplier, nLandPalaceUnitTypeQuota, 
					pLandDistrictType, tLandDistrictBuildingsTable, pLandUnitForcesType);
			end
			isLandAvailable = (nAllowedLandUnits > nLandUnitCount);
			if G_IsDebug then 
				print ("[UL::主函数] "..pPlayerCivName.." 拥有 "..nLandUnitCount.." 个'"..pLandUnitForcesType..
					"'单位((in-queue + existed). 可以建造 "..nAllowedLandUnits.." 个. 可以建造此单位吗? "..tostring(isLandAvailable).."!" );
			end
		end
		-- update each city's production queue. 0代表isNotAllow=0，表示可以制造。
		UpdateAllCityStatus(pPlayer, targetCityID, GameInfo.Buildings[pLandBuilding].Index, nAllowedLandUnits, nLandUnitCount, tLandFormationClassTable, pLandUnitForcesType, eventID);

		
		
		
		------ Sea Unit -------------------------------------------------------------------------------------------------------------------------------------------------------	
		if G_IsDebug then print("[UL::主函数] 海洋单位: ---------------------------------------------------------- ") end
		local nAllowedSeaUnits = 1;
		if nSeaUnitCount > 0 then
			if isCityState then	
				nAllowedSeaUnits = nCityStateAllowedSeaUnits;
			else
				nAllowedSeaUnits = GetFormationClassUnitLimit(pPlayer, pPlayerCivName, 
					nSeaUnitCityMultiplier, nSeaUnitDistrictMultiplier, nSeaUnitBuildingMultiplier, nSeaPalaceUnitTypeQuota, 
					pSeaDistrictType, tSeaDistrictBuildingsTable, pSeaUnitForcesType);
			end
			isSeaAvailable = (nAllowedSeaUnits > nSeaUnitCount);
			if G_IsDebug then 
				print ("[UL::主函数] "..pPlayerCivName.." 拥有 "..nSeaUnitCount.." 个'"..pSeaUnitForcesType..
					" 单位(in-queue + existed). 可以建造 "..nAllowedSeaUnits.." 个. 可以建造此单位吗? "..tostring(isSeaAvailable).."!" );
			end
		end

		UpdateAllCityStatus(pPlayer, targetCityID, GameInfo.Buildings[pSeaBuilding].Index, nAllowedSeaUnits, nSeaUnitCount, tSeaFormationClassTable, pSeaUnitForcesType, eventID);



		if G_IsDebug then print("[UL::主函数] 辅助单位: ---------------------------------------------------------- ") end
		------ Support Unit -------------------------------------------------------------------------------------------------------------------------------------------------------
		local nAllowedSupportUnits = 1;
		if nSupportUnitCount > 0 then
			
			if isCityState then	
				nAllowedSupportUnits = nCityStateAllowedSupportUnits;
			else
				nAllowedSupportUnits = GetFormationClassUnitLimit(pPlayer, pPlayerCivName, 
					nSupportUnitCityMultiplier, nSupportUnitDistrictMultiplier, nSupportUnitBuildingMultiplier, nSupportPalaceUnitTypeQuota, 
					pSupportDistrictType, tSupportDistrictBuildingsTable, pSupportUnitForcesType);
			end
			isSupportAvailable = (nAllowedSupportUnits > nSupportUnitCount);
			if G_IsDebug then 
				print ("[UL::主函数] "..pPlayerCivName.." 拥有 "..nSupportUnitCount.." 个'"..pSupportUnitForcesType..
					" 单位(in-queue + existed). 可以建造 "..nAllowedSupportUnits.." 个. 可以建造此单位吗? "..tostring(isSupportAvailable).."!" );
			end
		end
		UpdateAllCityStatus(pPlayer, targetCityID, GameInfo.Buildings[pSupportBuilding].Index, nAllowedSupportUnits, nSupportUnitCount, tSupportFormationClassTable, pSupportUnitForcesType, eventID);


		if G_IsDebug then print("[UL::主函数] 宗教单位: ---------------------------------------------------------- ") end
		------ Holy Unit -------------------------------------------------------------------------------------------------------------------------------------------------------
		local nAllowedHolyUnits = 1;
		if nHolyUnitCount > 0 then
			nAllowedHolyUnits = GetFormationClassUnitLimit(pPlayer, pPlayerCivName, 
				nHolyUnitCityMultiplier, nHolyUnitDistrictMultiplier, nHolyUnitBuildingMultiplier, nHolyPalaceUnitTypeQuota, 
				pHolyDistrictType, tHolyDistrictBuildingsTable, pHolyUnitForcesType);
			isHolyAvailable = (nAllowedHolyUnits > nHolyUnitCount);
			if G_IsDebug then 
				print ("[UL::主函数] "..pPlayerCivName.." 拥有 "..nHolyUnitCount.." 个'"..pHolyUnitForcesType..
					" 单位(in-queue + existed). 可以建造 "..nAllowedHolyUnits.." 个. 可以建造此单位吗? "..tostring(isHolyAvailable).."!" );
			end
		end
		UpdateAllCityStatus(pPlayer, targetCityID, GameInfo.Buildings[pHolyBuilding].Index, nAllowedHolyUnits, nHolyUnitCount, tHolyFormationClassTable, pHolyUnitForcesType, eventID);
		


		if G_IsDebug then print("[UL::主函数] 工人单位: ---------------------------------------------------------- ") end
		------ Builder -------------------------------------------------------------------------------------------------------------------------------------------------------
		local nAllowedBuilderUnits = 1;
		if nBuilderUnitCount > 0 then
			
			if isCityState then	
				nAllowedBuilderUnits = nCityStateAllowedBuilderUnits;
			else
				nAllowedBuilderUnits = GetIndividualUnitLimit(pPlayer, pPlayerCivName, 
					nBuilderUnitCityMultiplier, nBuilderPalaceUnitTypeQuota, pBuilderUnitForcesType);
			end
			isBuilderAvailable = (nAllowedBuilderUnits > nBuilderUnitCount);
			if G_IsDebug then 
				print ("[UL::主函数] "..pPlayerCivName.." 拥有 "..nBuilderUnitCount.." 个'"..pBuilderUnitForcesType..
					" 单位(in-queue + existed). 可以建造 "..nAllowedBuilderUnits.." 个. 可以建造此单位吗? "..tostring(isBuilderAvailable).."!" );
			end
		end
		UpdateAllCityStatus(pPlayer, targetCityID,  GameInfo.Buildings[pBuilderBuilding].Index, nAllowedBuilderUnits, nBuilderUnitCount, iBuilderUnit, pBuilderUnitForcesType, eventID);

			

		if G_IsDebug then print("[UL::主函数] 移民者单位: ---------------------------------------------------------- ") end
		------ Settler -------------------------------------------------------------------------------------------------------------------------------------------------------
		local nAllowedSettlerUnits = 1;
		if nSettlerUnitCount > 0 then
			
			if isCityState then	
				nAllowedSettlerUnits = nCityStateAllowedSettlerUnits;
			else
				nAllowedSettlerUnits = GetIndividualUnitLimit(pPlayer, pPlayerCivName, 
					nSettlerUnitCityMultiplier, nSettlerPalaceUnitTypeQuota, pSettlerUnitForcesType);
			end
			isSettlerAvailable = (nAllowedSettlerUnits > nSettlerUnitCount);
			if G_IsDebug then 
				print ("[UL::主函数] "..pPlayerCivName.." 拥有 "..nSettlerUnitCount.." 个'"..pSettlerUnitForcesType..
					" 单位(in-queue + existed). 可以建造 "..nAllowedSettlerUnits.." 个. 可以建造此单位吗? "..tostring(isSettlerAvailable).."!" );
			end
		end
		UpdateAllCityStatus(pPlayer, targetCityID, GameInfo.Buildings[pSettlerBuilding].Index, nAllowedSettlerUnits, nSettlerUnitCount, iSettlerUnit, pSettlerUnitForcesType, eventID);


		if G_BaseDebug then
			print ("[UL::主函数] "..pPlayerCivName.." 拥有:");
			print ("      陆地单位 "..nLandUnitCount.." / "..nAllowedLandUnits..""); 
			print ("      海洋单位 "..nSeaUnitCount.." / "..nAllowedSeaUnits..""); 
			print ("      辅助单位 "..nSupportUnitCount.." / "..nAllowedSupportUnits..""); 
			print ("      宗教单位 "..nHolyUnitCount.." / "..nAllowedHolyUnits..""); 
			print ("      工人单位 "..nBuilderUnitCount.." / "..nAllowedBuilderUnits..""); 
			print ("      移民者单位 "..nSettlerUnitCount.." / "..nSettlerUnitCount..""); 
		end

	end -- if 存在首都
  end -- if 合法的inPlayerID 
end


--==================================================================================================================== 



-- 此函数的运行，需要玩家ID合法，并且拥有首都(not used!)
function UpdateAllCity( playerID )
	-- 玩家（playerID=63）是BARBARIAN TRIBE，忽略他。
	if playerID ~= nil and playerID ~= 63 and playerID ~= -1 then
		local thisPlayer = Players[ playerID ] -- Players是全局变量
		-- local pPlayerConfig = PlayerConfigurations[ playerID ]
		local capitalCity = thisPlayer:GetCities():GetCapitalCity()
		-- 仅当首都存在时，才计算max_units
		if capitalCity ~= nil then
			-- 玩家=playerID, isFirstTimeThisTurn=true, cityID=nil
			UpdateMaxNumberOfUnit(playerID, true, nil, 0)
		end
	end
end

function UpdateCurrentCity( playerID, cityID, eventID )
	-- 玩家（playerID=63）是BARBARIAN TRIBE，忽略他。
	if playerID ~= nil and playerID ~= 63 and playerID ~= -1 then
		local thisPlayer = Players[ playerID ] -- Players是全局变量
		-- local pPlayerConfig = PlayerConfigurations[ playerID ]
		local capitalCity = thisPlayer:GetCities():GetCapitalCity()
		-- 仅当首都存在时，才计算max_units
		if capitalCity ~= nil then
			UpdateMaxNumberOfUnit(playerID, true, cityID, eventID)
		end
	end
end

-- Turn 每个玩家（包括电脑）在回合开始时运行
function OnPlayerTurnActivated( playerID, isFirstTimeThisTurn )
	if playerID==nil then return end
	if G_IsDebug then
		print(" ");
		print("---------------------------------------------------------------------------------------------------------------------------------------------------------------");
		print("---------------------------------------------------------------------------------------------------------------------------------------------------------------");
		local civName = PlayerConfigurations[ playerID ]:GetCivilizationTypeName();
		print( "[ UL::OnPlayerTurnActivated 回合开始事件 ] 玩家'"..tostring(playerID).."', 文明'"..civName.."'." ); print(" ");
	end
	UpdateMaxNumberOfUnit( playerID, isFirstTimeThisTurn, nil, 0 );
	InitExemptCityTable(playerID);
end

function OnUnitRemovedFromMap( playerID, unitID )
	if playerID==nil or unitID==nil then return end
	if G_IsDebug then
		print(" ");
		print("---------------------------------------------------------------------------------------------------------------------------------------------------------------");
		print("---------------------------------------------------------------------------------------------------------------------------------------------------------------");
		local civName = PlayerConfigurations[ playerID ]:GetCivilizationTypeName();
		print( "[ UL::OnUnitRemovedFromMap 单位删除事件 ] 玩家'"..tostring(playerID).."', 文明'"..civName.."', 删除单位 "..tostring(unitID).."" ); print(" ");
	end
	UpdateMaxNumberOfUnit( playerID, true, nil, 0 );
end

function ProcessProductionQueue(playerID, cityID, orderType, unitType, canceled, typeModifier, eventName, eventID)
	if playerID==nil or cityID==nil or orderType==nil or unitType==nil then return end
	-- 通过orderType计算productionName。但对于OnCityProductionChanged，orderType指的是“改变后的”
	local productionName;
	if orderType == 0  then 
		local entry = GameInfo.Units[unitType];
		if entry ~= nil then
			productionName = entry.UnitType;
		end
	elseif orderType == 1  then
		local entry = GameInfo.Buildings[unitType];
		if entry ~= nil then
			productionName = entry.BuildingType;
		end
	elseif orderType == 2  then 
		local entry = GameInfo.Districts[unitType];
		if entry ~= nil then
			productionName = entry.DistrictType;
		end
	end
	if productionName == nil then return end

	-- if G_IsDebug == true then
	-- 	print(" "); 
	-- 	print("---------------------------------------------------------------------------------------------------------------------------------------------------------------");
	-- 	print("---------------------------------------------------------------------------------------------------------------------------------------------------------------");
	-- 	local pPlayer = Players[ playerID ];
	-- 	local civName = PlayerConfigurations[ playerID ]:GetCivilizationTypeName();
	-- 	local pCity:table = pPlayer:GetCities():FindID(cityID);
	-- 	print( "[ UL::"..eventName.." 建造事件 ] 玩家("..playerID.." "..civName..
	-- 		") 城市("..cityID.." "..Locale.Lookup(pCity:GetName())..") unitType("..unitType..") OrderType("..orderType..
	-- 		") canceled("..tostring(canceled)..") typeModifier("..tostring(typeModifier)..") productionName("..productionName..")" ); print(" ");
	-- end
	-- 当productionName是以下几种时，会造成无法终止的循环。
	if productionName ~= pHolyBuilding
			and productionName ~= pLandBuilding
			and productionName ~= pSeaBuilding
			and productionName ~= pSupportBuilding
			and productionName ~= pBuilderBuilding
			and productionName ~= pSettlerBuilding then	
		UpdateCurrentCity(playerID, cityID, eventID);
		UpdateExemptCityTable(playerID, cityID);
	end
end

function OnCityProductionChanged(playerID, cityID, orderType, unitType, canceled, typeModifier)
	ProcessProductionQueue(playerID, cityID, orderType, unitType, canceled, typeModifier, "OnCityProductionChanged", nEventUnitChange );
end

-- TODO: cityID对应的城市，如果它正在建造一个违反限制的unit，终止其建造
function OnCityProductionCompleted(playerID, cityID, orderType, unitType, canceled, typeModifier)
	ProcessProductionQueue(playerID, cityID, orderType, unitType, canceled, typeModifier, "OnCityProductionCompleted", nEventUnitComplete );
end






function OnLoadScreenClose()
	Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);
	-- -- Population event might deal with "city be occupied or destroyed"
	-- -- Events.CityPopulationChanged.Add( OnCityPopulationChanged ); 
	-- -- Events.UnitAddedToMap.Add(OnNewPlayerUnitAddedToMap);
	-- Events.UnitRemovedFromMap.Add(OnUnitRemovedFromMap);
	-- -- Events.CityAddedToMap.Add(OnCityEvent);
	-- -- Events.CityRemovedFromMap.Add(OnCityEvent); -- 这种情况只发生在其他玩家的回合

	-- city production
	Events.CityProductionChanged.Add( OnCityProductionChanged );
	-- Events.CityProductionCompleted.Add( OnCityProductionCompleted );
	-- 单位完成
		-- 启动 CityProductionCompleted，之后，城市将不存在“正在建设的unit”
		-- 启动 CityProductionChanged，之后，城市将队列里的unit拿到城市“建设槽”中，此时城市“建设槽”存在unit
		-- 启动 PlayerTurnActivated，之后，此时城市“建设槽”存在unit
end



print("2.+++++++++++++++++++++++++++++++++++++ 加载文件: UnitLimit.lua...");
print("  +++ test: ExposedMembers.UnitLimitGlobalData.cnt="..ExposedMembers.UnitLimitGlobalData['cnt'])
-- for k, v in pairs(ExposedMembers.UnitLimitGlobalData) do
-- 	print(" +++ test: "..k.."="..v)
-- end

if bExecuteThisFile then
	print("bExecuteThisFile is True: Activating Game Events")
	Events.LoadScreenClose.Add(OnLoadScreenClose)
else
	print("bExecuteThisFile is False: No Game Events Activated")
end
