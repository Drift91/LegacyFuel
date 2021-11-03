-- variebles
local isNearPump = false
local isFueling = false
local currentFuel = 0.0
local currentCost = 0.0
local currentCash = 1000
local fuelSynced = false
local inBlacklisted = false

-- hud
local barHeight = 0.010 -- Height of Bar Variable
local barWidth = 0.141 -- Width of Bar Variable
local barPos = { x = 0.0855, y = 0.8 } -- Position On Screen (Above Mini Map)

if Config.AndyyyCurrencySystem then
	RegisterNetEvent('fuel:pay')
	AddEventHandler('fuel:pay', function(price)
		local amount = math.floor(price)

		if price > 0 then
			exports.Money_Script:RemoveCash(amount)
		end
	end)
end

function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))

		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end

Citizen.CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)

	for index = 1, #Config.Blacklist do
		if type(Config.Blacklist[index]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[index])] = true
		else
			Config.Blacklist[Config.Blacklist[index]] = true
		end
	end

	for index = #Config.Blacklist, 1, -1 do
		table.remove(Config.Blacklist, index)
	end

	while true do
		ped = PlayerPedId()

		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)

			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end

			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end

			if inBlacklisted then
				inBlacklisted = false
			end
		end
		Citizen.Wait(1000)
	end
end)

Citizen.CreateThread(function()
	while true do
		local pumpObject, pumpDistance = FindNearestFuelPump()

		if pumpDistance < 4.5 then
			isNearPump = pumpObject
		else
			isNearPump = false

			Citizen.Wait(math.ceil(pumpDistance * 20))
		end
		Citizen.Wait(250)
	end
end)

AddEventHandler('fuel:startFuelUpTick', function(pumpObject, ped, vehicle)
	currentFuel = GetVehicleFuelLevel(vehicle)

	nozle = CreateObject(GetHashKey("prop_cs_fuel_nozle"), 0, 0, 0, true, true, true) -- creates object
	AttachEntityToEntity(nozle, ped, GetPedBoneIndex(ped, 0x49D9), 0.1, 0.02, 0.02, 90.0, 40.0, 170.0, true, true, false, true, 1, true) -- object is attached to left hand

	while isFueling do
		Citizen.Wait(500)

		local oldFuel = DecorGetFloat(vehicle, Config.FuelDecor)
		local fuelToAdd = math.random(10, 20) / 10.0
		local extraCost = fuelToAdd / 1.5 * Config.CostMultiplier

		if not pumpObject then
			if GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100 >= 0 then
				currentFuel = oldFuel + fuelToAdd

				SetPedAmmo(ped, 883325847, math.floor(GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100))
			else
				isFueling = false
			end
		else
			currentFuel = oldFuel + fuelToAdd
		end

		if currentFuel > 100.0 then
			currentFuel = 100.0
			isFueling = false
		end

		currentCost = currentCost + extraCost

		if currentCash >= currentCost then
			SetFuel(vehicle, currentFuel)
		else
			isFueling = false
		end
	end

	if pumpObject then
		if Config.AndyyyCurrencySystem then TriggerEvent('fuel:pay', currentCost) end
	end

	DeleteEntity(nozle) -- deletes nozle

	-- reset cost
	currentCost = 0.0
end)

AddEventHandler('fuel:refuelFromPump', function(pumpObject, ped, vehicle)
	TaskTurnPedToFaceEntity(ped, vehicle, 1000)
	Citizen.Wait(1000)
	SetCurrentPedWeapon(ped, -1569615261, true)
	LoadAnimDict("timetable@gardener@filling_can")
	TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)

	TriggerEvent('fuel:startFuelUpTick', pumpObject, ped, vehicle)

	while isFueling do
		for _, controlIndex in pairs(Config.DisableKeys) do
			DisableControlAction(0, controlIndex)
		end

		local vehicleCoords = GetEntityCoords(vehicle)

		if pumpObject then
			local stringCoords = GetEntityCoords(pumpObject)
			local extraString = ""

			if Config.AndyyyCurrencySystem then
				extraString = "\n" .. Config.Strings.TotalCost .. ": ~g~$" .. Round(currentCost, 1)
			end

			DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.CancelFuelingPump .. extraString)
			DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(currentFuel, 1) .. "%")
		else
			DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Config.Strings.CancelFuelingJerryCan .. "\nGas can: ~g~" .. Round(GetAmmoInPedWeapon(ped, 883325847) / 4500 * 100, 1) .. "% | Vehicle: " .. Round(currentFuel, 1) .. "%")
		end

		if not IsEntityPlayingAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 3) then
			TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
		end

		if IsControlJustReleased(0, 38) or DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) or (isNearPump and GetEntityHealth(pumpObject) <= 0) then
			isFueling = false
		end

		Citizen.Wait(0)
	end

	ClearPedTasks(ped)
	RemoveAnimDict("timetable@gardener@filling_can")
end)

Citizen.CreateThread(function()
	while true do

		if not isFueling and ((isNearPump and GetEntityHealth(isNearPump) > 0) or (GetSelectedPedWeapon(ped) == 883325847 and not isNearPump)) then
			if IsPedInAnyVehicle(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped), -1) == ped then
				local pumpCoords = GetEntityCoords(isNearPump)

				DrawText3Ds(pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.2, Config.Strings.ExitVehicle)
			else
				local vehicle = GetPlayersLastVehicle()
				local vehicleCoords = GetEntityCoords(vehicle)

				if DoesEntityExist(vehicle) and GetDistanceBetweenCoords(GetEntityCoords(ped), vehicleCoords) < 2.5 then
					if not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
						local stringCoords = GetEntityCoords(isNearPump)
						local canFuel = true

						if GetSelectedPedWeapon(ped) == 883325847 then
							stringCoords = vehicleCoords

							if GetAmmoInPedWeapon(ped, 883325847) < 100 then
								canFuel = false
							end
						end

						if GetVehicleFuelLevel(vehicle) < 95 and canFuel then
							if currentCash > 0 then
								DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.EToRefuel)

								if IsControlJustReleased(0, 38) then
									isFueling = true

									TriggerEvent('fuel:refuelFromPump', isNearPump, ped, vehicle)
									LoadAnimDict("timetable@gardener@filling_can")
								end
							else
								DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.NotEnoughCash)
							end
						elseif not canFuel then
							DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.JerryCanEmpty)
						else
							DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.FullTank)
						end
					end
				elseif isNearPump then
					local stringCoords = GetEntityCoords(isNearPump)

					if currentCash >= Config.JerryCanCost then
						if not HasPedGotWeapon(ped, 883325847) then
							DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.PurchaseJerryCan)

							if IsControlJustReleased(0, 38) then
								GiveWeaponToPed(ped, 883325847, 4500, false, true)

								if Config.AndyyyCurrencySystem then TriggerEvent('fuel:pay', Config.JerryCanCost) end
							end
						else
							if Config.AndyyyCurrencySystem then
								local refillCost = Round(Config.RefillCost * (1 - GetAmmoInPedWeapon(ped, 883325847) / 4500))

								if refillCost > 0 then
									if currentCash >= refillCost then
										DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.RefillJerryCan .. refillCost)

										if IsControlJustReleased(0, 38) then
											if Config.AndyyyCurrencySystem then TriggerEvent('fuel:pay', refillCost) end
											SetPedAmmo(ped, 883325847, 4500)
										end
									else
										DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.NotEnoughCashJerryCan)
									end
								else
									DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.JerryCanFull)
								end
							else
								DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.RefillJerryCan)

								if IsControlJustReleased(0, 38) then
									SetPedAmmo(ped, 883325847, 4500)
								end
							end
						end
					else
						DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.NotEnoughCash)
					end
				else
					Citizen.Wait(350)
				end
			end
		else
			Citizen.Wait(350)
		end

		Citizen.Wait(0)
	end
end)

if Config.ShowNearestGasStationOnly then
	Citizen.CreateThread(function()
		local currentGasBlip = 0

		while true do
			local coords = GetEntityCoords(ped)
			local closest = 1000
			local closestCoords

			for _, gasStationCoords in pairs(Config.GasStations) do
				local dstcheck = GetDistanceBetweenCoords(coords, gasStationCoords)

				if dstcheck < closest then
					closest = dstcheck
					closestCoords = gasStationCoords
				end
			end

			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end

			currentGasBlip = CreateBlip(closestCoords)

			Citizen.Wait(10000)
		end
	end)
elseif Config.ShowAllGasStations then
	Citizen.CreateThread(function()
		for _, gasStationCoords in pairs(Config.GasStations) do
			CreateBlip(gasStationCoords)
		end
	end)
end

if Config.EnableHUD then
	Citizen.CreateThread(function()
		while true do
			local vehicle = GetVehiclePedIsIn(ped) -- Is The Player in a vehicle?
			local driver = GetPedInVehicleSeat(vehicle, -1) -- Is The Player in the Driver Seat?
			local dead = IsPedDeadOrDying(ped, true) -- Is The Player dead or dying?
			local class = GetVehicleClass(vehicle) -- What class of vehicle? Ignore bikes.

			if (vehicle ~= 0) and (class ~= 13) and not inBlacklisted then
				-- If IN a vehicle, and NOT a bike, and vehicle engine IS running then
				if driver and not dead then
					-- If The Player is in the Driver Seat and IS NOT dead
					local currentFuel = GetVehicleFuelLevel(vehicle) -- Current Fuel In Vehicle
					local fuelWidth = (barWidth * currentFuel) / 100 -- Fuel Value x Max Bar Width Show The Level Range Within The Bar

					DrawRect(barPos.x, barPos.y, barWidth, barHeight + 0.006, 40, 40, 40, 150)  -- Bar Background (Black)
					DrawRect(barPos.x, barPos.y, barWidth, barHeight, 206, 145, 40, 100)  -- Bar Background (lighter yellow)
					DrawRect(barPos.x - (barWidth - fuelWidth) / 2, barPos.y, fuelWidth, barHeight, 206, 145, 0, 255)  -- Current Fuel (Yellow)
				else
					Wait(500) -- Wait and don't crash
				end
			end
			Citizen.Wait(0)
		end
	end)
end
