--put this in a seperate file at some point
if SERVER then
	local function _kyle_Prop_TryUnNoclip(z)
		-- simple gross fix for the collision group not staying noclipped for whatever reason
		-- if it needs to be unnoclipped it should be noclipped in the first place right?
		-- props are still collidable right after spawn for some reason
		z:SetCollisionGroup(COLLISION_GROUP_WORLD)
		-- added for when this is called when the vehicle isnt actually noclipped but this is called anyway causing the object to be noclipped forever  ?
		z.buildnoclipped = true

		timer.Simple(0.5, function()
			-- Exit if the prop stops existing or isnt noclipped or has already attempted unnoclipping for too long
			if not (z:IsValid() and z.buildnoclipped and z.buildmode_unnoclip_attempt < 100) then
				z.buildmode_unnoclip_attempt = 0
				return
			end
			z.buildmode_unnoclip_attempt = z.buildmode_unnoclip_attempt + 1

			local d = false
			local reason = ""
			local preventUnNoclip = {}

			preventUnNoclip["DriverInBuildmode"] = z:IsVehicle() and z:GetDriver().buildmode
			preventUnNoclip["MovingTooQuickly"] = z:GetVelocity():Length() > 2
			preventUnNoclip["Physgunned"] = z.buildphysgunned
			preventUnNoclip["BuildparentNoclipped"] = IsValid(z.buildparent) and z.buildparent.buildnoclipped
			preventUnNoclip["SCarParentNoclipped"] = IsValid(z.SCarOwner) and z.SCarOwner.buildphysgunned

			for i, bool in pairs(preventUnNoclip) do
				d = d or bool
				if bool then
					reason = reason .. i .. ";"
				end
			end

			-- entity interference
			if not d then
				--Check to see if there is anything inside the props bounds
				local a,b = z:GetCollisionBounds()
				local c = ents.FindInBox(z:LocalToWorld(a), z:LocalToWorld(b))
				for _, ab in pairs(c) do
					--if e then ignore this blocking entity
					local e = false

					if z == ab	then
						e = true
					end

					local ignoreCheck = {}

					ignoreCheck["IsntSolid"] = not ab:IsSolid()
					ignoreCheck["IsParentCheckChildParent"] = z:GetParent() == ab
					ignoreCheck["IsParentCheckChildOwner"] = z:GetOwner() == ab
					ignoreCheck["IsChildCheckChildOnwer"] = z == ab:GetOwner()
					ignoreCheck["IsChildCheckChilldParent"] = z == ab:GetParent()
					ignoreCheck["IsDriver"] = z:IsVehicle() and ab == z:GetDriver()
					ignoreCheck["IsWacHitDetector"] = ab:GetClass() == "wac_hitdetector"
					ignoreCheck["IsWeapon"] = ab:IsWeapon()
					ignoreCheck["CommonFounder"] = z.Founder and z.Founder == ab.Founder
					--SCars Support
					--check to see if we are the parent of the blocking prop
					ignoreCheck["IsSCarChild"] = z == ab:GetParent().SCarOwner

					if CPPI then
				--		ignoreCheck["CommonCPPIOwner"] = z:CPPIGetOwner() == ab:CPPIGetOwner() and ab:GetClass() == "prop_physics"
				--		ignoreCheck["CommonBuildOwner"] = z.buildOwner == ab.buildOwner and ab:GetClass() == "prop_physics"
						ignoreCheck["CommonFounder-CPPIOwner"] = z:CPPIGetOwner() and z:CPPIGetOwner() == ab.Founder
						ignoreCheck["CommonFounder-BuildOwner"] = z.buildOwner and z.buildOwner == ab.Founder
					end

					--simfphys support
					if simfphys and simfphys.IsCar then
						--if we are a wheel of a the simfphys car that is blocking us
						ignoreCheck["IsSimfphysCarWhileSimfphysWheel"] = simfphys.IsCar(ab) and table.HasValue(ab.Wheels, z)
						--if we are a prop that is owned by a simfphys car
						ignoreCheck["IsSimfphysCarChild"] = simfphys.IsCar(ab:GetOwner())
						--if we are a simfphys car and the blocking entity is the driver
						ignoreCheck["IsDriverWhileSimfphysCar"] = simfphys.IsCar(z) and ab == z:GetDriver()
						--if we are a simfphys car wheel and the blocking entity is a part of our car
						--if the blocking entity's parent is a simfphys car and we are a wheel from that car
						ignoreCheck["IsCarPartWhileSimfphysWheel"] = simfphys.IsCar(ab:GetParent()) and table.HasValue(ab:GetParent().Wheels, z)
					end

					for _, bool in pairs(ignoreCheck) do
						e = e or bool
					end

					--check to see if the we have any constraints on the blocking entity
					--check e to avoid any unnecessary overhead
					if not e and z.Constraints then
						for aa in pairs(z.Constraints) do
							if IsValid(z.Constraints[aa]) and z.Constraints[aa]:IsConstraint() then
								local a, b = z.Constraints[aa]:GetConstrainedEntities()
								if ab == a or ab == b then
									e = true
									break
								end
							end
						end
					end

					if not e then
						reason = reason .. ab:GetClass() .. " entity interference;"
						d = true

						break
					end
				end
			end

			--finally un noclip or try again
			if not d then
				--Recall the old attributes
				z:SetColor(Color(z:GetColor()["r"], z:GetColor()["g"], z:GetColor()["b"], z.buildmode_alpha))
				z:SetRenderMode(z.buildmode_rendermode)
				z:SetCollisionGroup(z.buildmode_collisiongroup)
				z.buildnoclipped = false
				z.buildparent = nil
				z.buildmode_unnoclip_attempt = 0
			else
				--if it fails, try again
				_kyle_Prop_TryUnNoclip(z)
			end
		end )
	end

	local function _kyle_Prop_Noclip_Sub(z)
		if not IsEntity(z) or z.buildnoclipped then print("kyle buildmode wtf") return end

		--Store the old attributes (to be recalled later)
		z.buildmode_rendermode = z:GetRenderMode()
		z.buildmode_alpha = z:GetColor()["a"]
		z.buildmode_collisiongroup = z:GetCollisionGroup()
		--Set the new attributes
		z:SetCollisionGroup(COLLISION_GROUP_WORLD)
		z:SetRenderMode(1)
		z:SetColor(Color(z:GetColor()["r"], z:GetColor()["g"], z:GetColor()["b"], 200))
		z.buildnoclipped = true
		z.buildmode_unnoclip_attempt = 0

		--Try to un noclip asap if its not a vehicle being driven by a builder
		_kyle_Prop_TryUnNoclip(z)
	end

	local function _kyle_Prop_Noclip(z)
		if (not IsEntity(z)) or z.buildnoclipped then return end

		_kyle_Prop_Noclip_Sub(z)

		if IsValid(z:GetParent()) then
			_kyle_Prop_Noclip(z:GetParent())
		end

		--simfphys
		if simfphys and simfphys.IsCar and z:GetClass() == "gmod_sent_vehicle_fphysics_wheel" then

			local a
			--run through all the constraints to find the car
			for aa in pairs(z.Constraints) do
				local b = z.Constraints[aa]:GetConstrainedEntities()
				if b ~= nil and simfphys.IsCar(b) then a = b break end
			end

			--noclip the car
			_kyle_Prop_Noclip_Sub(a)

			--noclip all the wheels
			for _, ab in pairs(a.Wheels) do
				_kyle_Prop_Noclip_Sub(ab)
			end

			return
		end

		--noclip constrained props
		if z.Constraints then
			for _, ab in pairs(z.Constraints) do
				if IsValid(ab) then
					local a, b = ab:GetConstrainedEntities()
					local c

					--if the consraint isnt just an entity to itself
					--set c to the entity that isnt z
					if a ~= b then
						c = z == a and b or a
					end

					--if we found a valid entity constrained to z
					if c and not c.buildphysgunned and not IsValid(c.buildparent) and z.buildparent ~= c  then
						c.buildparent = z
						_kyle_Prop_Noclip(c)
					end
				end
			end
		end
	end

	local function hasValue(tbl, value)
		if table.HasValue(tbl, value) then return true end

		for _, v in pairs(tbl) do
			if string.find(v, "*") and string.match(value, "^(" .. string.sub(v, 1, -2) .. ")" ) then
				return true
			end
		end

		return false
	end

	local function _kyle_builder_spawn_weapon(y, z)
		local restrictweapons = _Kyle_Buildmode["restrictweapons"] == "1" and y.buildmode

		if restrictweapons then
			local restrictionmet = (_Kyle_Buildmode["weaponlistmode"] == "0") == hasValue(_Kyle_Buildmode["buildloadout"], z)
			local adminbypass = y:IsAdmin() and _Kyle_Buildmode["adminsbypassrestrictions"] == "1"
			return restrictionmet or adminbypass
		else
			return true
		end
	end

	local function _kyle_builder_spawn_entity(y, z)
		local restrictsents = _Kyle_Buildmode["restrictsents"] == "1" and y.buildmode

		if restrictsents then
			local restrictionmet = (_Kyle_Buildmode["entitylistmode"] == "0") == hasValue(_Kyle_Buildmode["builderentitylist"], z)
			local adminbypass = y:IsAdmin() and _Kyle_Buildmode["adminsbypassrestrictions"] == "1"
			return restrictionmet or adminbypass
		else
			return true
		end
	end

	local function _kyle_builder_allow_vehicle(y, z)
		if _Kyle_Buildmode["restrictvehicles"] ~= "1" then return true end
		if not y.buildmode then return true end

		if isentity(z) then
			local entTable = z:GetTable()

			if simfphys and simfphys.IsCar and entTable.base and simfphys.IsCar(entTable.base) then
				z = entTable.base
			end

			if IsValid(z:GetParent()) then
				z = z:GetParent()
			end

			if IsValid(entTable.EntOwner) then
				z = entTable.EntOwner
			end

			if IsEntity(z) and entTable.VehicleName then
				z = entTable.VehicleName
			end

			if IsEntity(z) and z:GetClass() then
				z = z:GetClass()
			end

			-- ignore wac for now because theyre sents and not vehicles
			if string.StartWith(z, "wac") then
				return true
			end
		end

		local restrictionmet = (_Kyle_Buildmode["vehiclelistmode"] == "0") == hasValue(_Kyle_Buildmode["buildervehiclelist"], z)
		local adminbypass = y:IsAdmin() and _Kyle_Buildmode["adminsbypassrestrictions"] == "1"

		return restrictionmet or adminbypass
	end

	local function _kyle_Buildmode_Enable(z)
		if z:Alive() then
			if _Kyle_Buildmode["restrictweapons"] == "1" then
				--save the players loadout for when they exit buildmode
				ULib.getSpawnInfo(z)
				--remove their weapons
				z:StripWeapons()
				--give them whitelisted weapons
				for _, y in pairs(_Kyle_Buildmode["buildloadout"]) do
					z:Give(y)
				end
			end

			z.buildmode = true

			--noclip their vehicle so they cant run anyone anyone over while in buildmode
			if _Kyle_Buildmode["antipropkill"] == "1" and z:InVehicle() then
				if _kyle_builder_allow_vehicle(z, z:GetVehicle()) then
					_kyle_Prop_Noclip(z:GetVehicle())
				else
					z:ExitVehicle()
					z:SendLua("GAMEMODE:AddNotify(\"You cannot enter this vehicle while in Buildmode.\", NOTIFY_GENERIC, 5)")
				end
			end
		end

		if _Kyle_Buildmode["npcignore"] == "1" then
			z:SetNoTarget(true)
		end

		--some say that sendlua is lazy and wrong but idc
		z:SendLua("GAMEMODE:AddNotify(\"Buildmode enabled. Type !pvp to disable\", NOTIFY_GENERIC, 5)")

		--second buildmode variable for halos and status text on hover
		z:SetNWBool("_Kyle_Buildmode", true)

		--boolean to say if buildmode was enabled because the player had just spawned
		z.buildmode_onspawn = z.buildmode_died

		hook.Run("OnPlayerSwitchModePVPBUILD", z, true)
	end

	local function _kyle_Buildmode_Disable(z)
		local timername = "_Kyle_Buildmode_spawnprotection_" .. z:GetName()
		if timer.Exists(timername) then
			timer.Remove(timername)
		end

		z:SetNoTarget(false)

		z.buildmode = false

		--second buildmode variable for halos and status text on hover
		z:SetNWBool("_Kyle_Buildmode", false)

		--some say that sendlua is lazy and wrong but idc
		z:SendLua("GAMEMODE:AddNotify(\"Buildmode disabled.\", NOTIFY_GENERIC, 5)")

		if z:Alive() then
			--if they are in a vehicle try to un noclip their vehicle and kick them out of it if they need to return to spawn
			if _Kyle_Buildmode["antipropkill"] == "1" and z:InVehicle() then
				if IsValid(z:GetVehicle()) and z:GetVehicle().buildnoclipped then
					_kyle_Prop_TryUnNoclip(z:GetVehicle())
				end

				if _Kyle_Buildmode["returntospawn"] == "1" then
					z:ExitVehicle()
				end
			end

			if _Kyle_Buildmode["restrictweapons"] == "1" then
				--save their position incase they dont need to return to spawn on exit
				local pos = z:GetPos()

				local buildOnSpawn = z.buildmode_onspawn
				ULib.spawn(z, not buildOnSpawn)

				if buildOnSpawn then
					z:ConCommand("kylebuildmode defaultloadout")
				end

				--ULIB.spawn moves the player to spawn, this will return the player to where they where while in buildmode
				if _Kyle_Buildmode["returntospawn"] == "0" then
					z:SetPos(pos)
				end
			end

			--disable noclip if they had it in build
			if z.buildmode_noclipped then
				z:ConCommand("noclip")
			end
		end

		hook.Run("OnPlayerSwitchModePVPBUILD", z, false)
	end


	hook.Add("PlayerSpawnProp", "KylebuildmodePropSpawnBlock", function(y, z)
		local adminbypass = y:IsAdmin() and _Kyle_Buildmode["adminsbypassrestrictions"] == "1"

		if _Kyle_Buildmode["anitpropspawn"] == "1" and (not y.buildmode) and (not adminbypass) then
			y:SendLua("GAMEMODE:AddNotify(\"You can only spawn props in Buildmode\", NOTIFY_ERROR, 5)")
			return false
		end
	end)

	hook.Add("PlayerSpawnedProp", "KylebuildmodePropKill", function(x, y, z)
		if not CPPI then
			z.buildOwner = x
		end

		if x.buildmode and _Kyle_Buildmode["antipropkill"] == "1" then
			_kyle_Prop_Noclip(z)
		end

		if not x.buildmode and _Kyle_Buildmode["antipropkillpvper"] == "1" then
			_kyle_Prop_Noclip(z)
		end
	end)

	hook.Add("PlayerSpawnedSENT", "KylebuildmodePropKillSENT", function(y, z)
		if not CPPI then
			z.buildOwner = y
		end

		if y.buildmode and _Kyle_Buildmode["antipropkill"] == "1" then
			_kyle_Prop_Noclip(z)
		end

		if not y.buildmode and _Kyle_Buildmode["antipropkillpvper"] == "1" then
			_kyle_Prop_Noclip(z)
		end
	end)

	hook.Add("PlayerSpawnedVehicle", "KylebuildmodePropKill", function(y, z)
		if not CPPI then
			z.buildOwner = x
		end

		if y.buildmode and _Kyle_Buildmode["antipropkill"] == "1" then
			_kyle_Prop_Noclip(z)
		end

		if not y.buildmode and _Kyle_Buildmode["antipropkillpvper"] == "1" then
			_kyle_Prop_Noclip(z)
		end
	end)

	hook.Add("PlayerEnteredVehicle", "KylebuildmodePropKill", function(y, z)
		if y.buildmode and _Kyle_Buildmode["antipropkill"] == "1" then
			_kyle_Prop_Noclip(z)
		end

		-- if not y.buildmode and _Kyle_Buildmode["antipropkillpvper"] == "1" then
		--	_kyle_Prop_Noclip(z)
		-- end
	end)

	hook.Add("PlayerLeaveVehicle", "KylebuildmodePropKill", function(y, z)
		if IsValid(z) and z.buildnoclipped then
			_kyle_Prop_TryUnNoclip(z)
		end
	end)

	hook.Add("PhysgunPickup", "KylebuildmodePropKill", function(ply, ent)
		if not IsValid(ent) then return end
		if ent:IsPlayer() then return end

		local inBuild = ply.buildmode

		if inBuild and _Kyle_Buildmode["antipropkill"] == "1" then
			ent.buildphysgunned = true
			_kyle_Prop_Noclip(ent)
		end

		if not inBuild and _Kyle_Buildmode["antipropkillpvper"] == "1" then
			ent.buildphysgunned = true
			_kyle_Prop_Noclip(ent)
		end
	end, HOOK_MONITOR_LOW)

	hook.Add("PhysgunDrop", "KylebuildmodePropKill", function(ply, ent)
		if not IsValid(ent) then return end
		if ent:IsPlayer() then return end

		local inBuild = ply.buildmode

		if inBuild and _Kyle_Buildmode["antipropkill"] == "1" then
			ent.buildphysgunned = false

			--Kill the prop's velocity so it can not be thrown
			ent:SetPos(ent:GetPos())
		end

		if not inBuild and _Kyle_Buildmode["antipropkillpvper"] == "1" then
			ent.buildphysgunned = false

			--Kill the prop's velocity so it can not be thrown
			ent:SetPos(ent:GetPos())
		end

		if ent.buildnoclipped then
			_kyle_Prop_TryUnNoclip(ent)
		end
	end)

	hook.Add("PlayerNoClip", "KylebuildmodeNoclip", function(y, z)
		if _Kyle_Buildmode["allownoclip"] == "1" and ULib.ucl.query(y, "kylebuildmodenoclip", true) then
			--allow players to use default sandbox noclip
			y.buildmode_noclipped = z
			return z == false or z == y.buildmode
		elseif _Kyle_Buildmode["allownoclip"] == "1" then
			y:SendLua("GAMEMODE:AddNotify(\"You do not have permission to use noclip in Buildmode\", NOTIFY_ERROR, 5)")
		end
	end, HOOK_HIGH)

	hook.Add("PlayerSpawn", "kyleBuildmodePlayerSpawn",  function(z)
		--z.buildmode_died makes sure that the player is spawning after an actual death and not the ulib respawn function
		if ((_Kyle_Buildmode["spawnwithbuildmode"] == "1" and _Kyle_Buildmode["persistpvp"] == "0") or z:GetNWBool("_Kyle_Buildmode")) and z.buildmode_died then
			_kyle_Buildmode_Enable(z)
		elseif (not z:GetNWBool("_Kyle_Buildmode")) and z.buildmode_died then
			if tonumber(_Kyle_Buildmode["spawnprotection"]) > 0 then
				z:SendLua("GAMEMODE:AddNotify(\"" .. _Kyle_Buildmode["spawnprotection"] .. " seconds of Spawn Protection enabled. Type !pvp to disable\", NOTIFY_GENERIC, 5)")
				z.buildmode = true
				z:SetNWBool("_Kyle_Buildmode", true)
				local timername = "_Kyle_Buildmode_spawnprotection_" .. z:GetName()
				if timer.Exists(timername) then
					timer.Remove(timername)
				end
				timer.Create(timername, _Kyle_Buildmode["spawnprotection"], 1, function()
					z:SetNWBool("_Kyle_Buildmode", false)
					z.buildmode = false
					if _Kyle_Buildmode["restrictweapons"] == "1" then
						z:ConCommand("kylebuildmode defaultloadout")
					end
					z:SendLua("GAMEMODE:AddNotify(\"Spawn protection ended\", NOTIFY_GENERIC, 5)")
				end)
			end
		end
		z.buildmode_died = false

		-- set z.buildmode to false if its nil. otherwise keep it at z.buildmode
		z.buildmode = z.buildmode or false;
	end)

	hook.Add("PlayerInitialSpawn", "kyleBuildmodePlayerInitialSpawn", function(ply)
		ply.buildmode_died = true
		if _Kyle_Buildmode["spawnwithbuildmode"] == "1" then
			ply:SetNWBool("_Kyle_Buildmode", true)
		end
	end)

	hook.Add("PostPlayerDeath", "kyleBuildmodePostPlayerDeath",  function(ply)
		ply.buildmode_died = true
		local timername = "_Kyle_Buildmode_spawnprotection_" .. ply:GetName()
		if timer.Exists(timername) then
			ply:SetNWBool("_Kyle_Buildmode", false)
			ply.buildmode = false
			timer.Remove(timername)
		end
	end, HOOK_HIGH)

	hook.Add("GetFallDamage", "kyleBuildmodeFallDamage", function(ply)
		if ply.buildmode then return 0 end
	end)

	hook.Add("PlayerGiveSWEP", "kylebuildmoderestrictswep", function(y, z)
		if not _kyle_builder_spawn_weapon(y, z) then
			--some say that sendlua is lazy and wrong but idc
			y:SendLua("GAMEMODE:AddNotify(\"You cannot give yourself this weapon while in Buildmode.\", NOTIFY_GENERIC, 5)")
			return false
		end
	end)

	hook.Add("PlayerSpawnSWEP", "kylebuildmoderestrictswep", function(y, z)
		if not _kyle_builder_spawn_weapon(y, z) then
			--some say that sendlua is lazy and wrong but idc
			y:SendLua("GAMEMODE:AddNotify(\"You cannot spawn this weapon while in Buildmode.\", NOTIFY_GENERIC, 5)")
			return false
		end
	end)

	hook.Add("PlayerCanPickupWeapon", "kylebuildmoderestrictswep", function(y, z)
		if not _kyle_builder_spawn_weapon(y, string.Split(string.Split(tostring(z),"][", true)[2],"]", true)[1]) then
			return false
		end
	end)

	hook.Add("PlayerSpawnVehicle", "kylebuildmoderestrictvehicle", function(x, y, z, a)
		if not _kyle_builder_allow_vehicle(x, z) then
			--some say that sendlua is lazy and wrong but idc
			x:SendLua("GAMEMODE:AddNotify(\"You cannot spawn this vehicle while in Buildmode.\", NOTIFY_GENERIC, 5)")
			return false
		end
	end)

	hook.Add("CanPlayerEnterVehicle", "kylebuildmoderestrictvehicleentry", function(y, z)
		if not _kyle_builder_allow_vehicle(y, z) then
			--some say that sendlua is lazy and wrong but idc
			y:SendLua("GAMEMODE:AddNotify(\"You cannot enter this vehicle while in Buildmode.\", NOTIFY_GENERIC, 5)")
			return false
		end
	end)

	hook.Add("PlayerSpawnSENT", "kylebuildmoderestrictsent", function(y, z)
		if not _kyle_builder_spawn_entity(y, z) then
			--some say that sendlua is lazy and wrong but idc
			y:SendLua("GAMEMODE:AddNotify(\"You cannot spawn this SENT while in Buildmode.\", NOTIFY_GENERIC, 5)")
			return false
		end
	end)

	hook.Add("PlayerSpawnProp", "kylebuildmoderestrictpropspawn", function(y, z)
		if _Kyle_Buildmode["pvppropspawn"] == "0" and not y.buildmode and not y:IsAdmin() then
			--some say that sendlua is lazy and wrong but idc
			y:SendLua("GAMEMODE:AddNotify(\"You cannot spawn props while in PVP.\", NOTIFY_GENERIC, 5)")
			return false
		end
	end)
	--[[
	hook.Add("OnEntityCreated", "kylebuildmodeentitycreated", function(z)
		if z:GetClass() == "prop_combine_ball" then
			z:SetCustomCollisionCheck( true )
		end
	end)

	hook.Add("ShouldCollide", "kylebuildmodeShouldCollide", function(y, z)
		if y:GetClass() == "prop_combine_ball" and z:IsPlayer() then
			if y:GetOwner().buildmode or z.buildmode then
				return false
			end
		end
	end)
	]]
	local function canDamageNPC(target)
		return _Kyle_Buildmode["allownpcdamage"] == "1" and (target:IsNPC() or target:IsNextBot())
	end

	hook.Add("EntityTakeDamage", "kyleBuildmodeTryTakeDamage", function(target, dmg)
		if target.buildmode then return true end
		if target.buildnoclipped then return true end
		if canDamageNPC(target) then return end

		local attacker = dmg:GetAttacker()
		local validattacker = IsValid(attacker)

		if validattacker then
			if attacker:IsPlayer() and attacker.buildmode then return true end

			local owner = attacker:GetOwner()
			if IsValid(owner) and owner.buildmode then return true end

			local cppiOwner = attacker:CPPIGetOwner()
			if IsValid(cppiOwner) and cppiOwner.buildmode then return true end

			if simfphys and simfphys.IsCar and simfphys.IsCar(attacker) and attacker:GetDriver().buildmode or attacker.buildnoclipped then return true end

			if attacker.buildnoclipped then return true end
		end

		local inflictor = dmg:GetInflictor()
		local validinflictor = IsValid(inflictor)

		if validinflictor then
			local owner = inflictor:GetOwner()
			if IsValid(owner) and owner.buildmode then return true end

			local cppiOwner = inflictor:CPPIGetOwner()
			if IsValid(cppiOwner) and cppiOwner.buildmode then return true end
		end

		-- Prevent builders from causing world damage by crushing things with physics objects
		if not validattacker and not validinflictor and dmg:IsDamageType(DMG_CRUSH) then return true end

		if target:IsPlayer() then
			local adminbypass = target:IsAdmin() and _Kyle_Buildmode["adminsbypassrestrictions"] == "1"

			if not adminbypass and (target:Health() > target:GetMaxHealth()) then
				dmg:AddDamage(2 * (target:Health() - target:GetMaxHealth()))
			end
		end
	end, HOOK_HIGH)

	local kylebuildmode = ulx.command("_Kyle_1", "ulx build", function(calling_ply, should_revoke)
		if not calling_ply.buildmode and not should_revoke and not calling_ply.pendingbuildchange then
			if _Kyle_Buildmode["builddelay"] ~= "0" then
				local delay = tonumber(_Kyle_Buildmode["builddelay"])
				calling_ply:SendLua("GAMEMODE:AddNotify(\"Enabling Buildmode in " .. delay .. " seconds.\", NOTIFY_GENERIC, 5)")
				calling_ply.pendingbuildchange = true
				ulx.fancyLogAdmin(calling_ply, "#A entering Buildmode in " .. delay .. " seconds.")
				timer.Simple(delay, function()
						_kyle_Buildmode_Enable(calling_ply)
						calling_ply.pendingbuildchange = false
						ulx.fancyLogAdmin(calling_ply, "#A entered Buildmode")
				end)
			else
				_kyle_Buildmode_Enable(calling_ply)
				ulx.fancyLogAdmin(calling_ply, "#A entered Buildmode")
			end
		elseif calling_ply.buildmode and should_revoke and not calling_ply.pendingbuildchange then
			if _Kyle_Buildmode["pvpdelay"] ~= "0" then
				local delay = tonumber(_Kyle_Buildmode["pvpdelay"])
				calling_ply:SendLua("GAMEMODE:AddNotify(\"Disabling Buildmode in " .. delay .. " seconds.\", NOTIFY_GENERIC, 5)")
				ulx.fancyLogAdmin(calling_ply, "#A exiting Buildmode in " .. delay .. " seconds.")
				calling_ply.pendingbuildchange = true
				timer.Simple(delay, function()
					_kyle_Buildmode_Disable(calling_ply)
					calling_ply.pendingbuildchange = false
					ulx.fancyLogAdmin(calling_ply, "#A exited Buildmode")
				end)
			else
				_kyle_Buildmode_Disable(calling_ply)
				ulx.fancyLogAdmin(calling_ply, "#A exited Buildmode")
			end
		end
	end, "!build")
	kylebuildmode:defaultAccess(ULib.ACCESS_ALL)
	kylebuildmode:addParam{type = ULib.cmds.BoolArg, invisible = true}
	kylebuildmode:help("Grants Buildmode to self.")
	kylebuildmode:setOpposite("ulx pvp", {_, true}, "!pvp")

	local kylebuildmodeadmin = ulx.command("_Kyle_1", "ulx fbuild", function(calling_ply, target_plys, should_revoke)
		local affected_plys = {}
		for _, z in pairs(target_plys) do
			if not z.buildmode and not should_revoke then
				_kyle_Buildmode_Enable(z)
			elseif z.buildmode and should_revoke then
				_kyle_Buildmode_Disable(z)
			end
			table.insert(affected_plys, z)
		end

		if should_revoke then
			ulx.fancyLogAdmin(calling_ply, "#A revoked Buildmode from #T", affected_plys)
		else
			ulx.fancyLogAdmin(calling_ply, "#A granted Buildmode upon #T", affected_plys)
		end
	end, "!fbuild")
	kylebuildmodeadmin:addParam{type = ULib.cmds.PlayersArg}
	kylebuildmodeadmin:defaultAccess(ULib.ACCESS_OPERATOR)
	kylebuildmodeadmin:addParam{type = ULib.cmds.BoolArg, invisible = true}
	kylebuildmodeadmin:help("Forces Buildmode on target(s).")
	kylebuildmodeadmin:setOpposite("ulx fpvp", {_, _, true}, "!fpvp")
end

hook.Add("PreDrawHalos", "KyleBuildmodehalos", function()
	local w = {}
	local x = {}

	if _Kyle_Buildmode["highlightonlywhenlooking"] == "0" then
		local z = {}
		for _, z in ipairs(player.GetAll()) do
			if z:Alive() and z:GetRenderMode() ~= RENDERMODE_TRANSALPHA  then
				if z:GetNWBool("_Kyle_Buildmode") then
					table.insert(w, z)
				else
					table.insert(x, z)
				end
			end
		end
	else
		local z = LocalPlayer():GetEyeTrace().Entity
		if z:IsPlayer() and z:Alive() and z:GetRenderMode() ~= RENDERMODE_TRANSALPHA then
			if z:GetNWBool("_Kyle_Buildmode") then
				table.insert(w, z)
			else
				table.insert(x, z)
			end
		end
	end

	-- add setting later for render mode
	if _Kyle_Buildmode["highlightbuilders"] == "1" and next(w) then
		z = string.Split(_Kyle_Buildmode["highlightbuilderscolor"], ",")
		halo.Add(w, Color(z[1], z[2], z[3]), 4, 4, 1, true)
	end

	if _Kyle_Buildmode["highlightpvpers"] == "1" and next(x) then
		z = string.Split(_Kyle_Buildmode["highlightpvperscolor"], ",")
		halo.Add(x, Color(z[1], z[2], z[3]), 4, 4, 1, true)
	end
end)

hook.Add("HUDPaint", "KyleBuilderhudpaint", function()
	if _Kyle_Buildmode["showtextstatus"] ~= "1" then return end
	local z = LocalPlayer():GetEyeTrace().Entity
	if z:IsValid() and z:IsPlayer() and z:Alive() and z:GetRenderMode() ~= RENDERMODE_TRANSALPHA then
		local x, y = gui.MousePos()
		y = y + ScrH() * 0.07414

		if x == 0 or y == 0 then
			x = ScrW() / 2
			y = (ScrH() / 2) + 107 -- ScrH() / 1.74
		end

		-- local col = string.Split(_Kyle_Buildmode["highlightpvperscolor"], ",")
		local mode = "PVP"
		if z:GetNWBool("_Kyle_Buildmode") then
			mode = "Build"
			-- col = string.Split(_Kyle_Buildmode["highlightbuilderscolor"], ",")
		end

		draw.TextShadow({text = mode .. "er", font = "TargetID", pos = {x, y}, xalign = TEXT_ALIGN_CENTER, yalign = TEXT_ALIGN_CENTER, color = team.GetColor(z:Team())}, 1)
	end
end)