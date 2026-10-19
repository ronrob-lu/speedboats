-- ==============================================================================
-- SPEEDBOATS MOD FOR MINETEST / LUANTI, MINECLONIA & VOXELIBRE
-- High-speed watercraft with 7-step cruise control, open cockpit player seating,
-- ice collision sinking mechanics, lava hazards, and pickaxe-only dismantling.
-- Code: (c) 2026 ronrob-lu (MIT License)
-- 3D Models & Textures: Kenney (CC0)
-- ==============================================================================

local modname = minetest.get_current_modname() or "speedboats"
local S = minetest.get_translator and minetest.get_translator(modname) or function(s) return s end

-- Detection of game environments
local is_mcl = minetest.get_modpath("mcl_core") ~= nil
local is_default = minetest.get_modpath("default") ~= nil

-- -----------------------------------------------------------------------------
-- Helper Functions & Compatibility Layer
-- -----------------------------------------------------------------------------

local function is_water(pos)
	if not pos then return false end
	local node = minetest.get_node_or_nil(pos)
	if not node or node.name == "ignore" then return false end
	if minetest.get_item_group(node.name, "water") ~= 0 then return true end
	if node.name:find("water") then return true end
	return false
end

local function is_lava(pos)
	if not pos then return false end
	local node = minetest.get_node_or_nil(pos)
	if not node or node.name == "ignore" then return false end
	if minetest.get_item_group(node.name, "lava") ~= 0 then return true end
	if node.name:find("lava") then return true end
	return false
end

local function is_ice(nodename)
	if not nodename or nodename == "ignore" or nodename == "air" then
		return false
	end
	if minetest.get_item_group(nodename, "ice") > 0 then
		return true
	end
	if nodename:find("ice") then
		return true
	end
	return false
end

local function is_pickaxe(tool_name)
	if not tool_name or tool_name == "" then return false end
	if minetest.get_item_group(tool_name, "pickaxe") > 0 then
		return true
	end
	if tool_name:find("pick") ~= nil then
		return true
	end
	return false
end

local function play_sound(sound_name, spec)
	if minetest.sound_play then
		pcall(minetest.sound_play, sound_name, spec)
	end
end

-- Proper sitting animation for open-top cockpits across engines
local function set_player_animation(player, anim_name)
	if not player or not player:is_player() then return end

	-- Mineclonia / VoxeLibre
	if minetest.global_exists("mcl_player") and mcl_player.player_set_animation then
		pcall(mcl_player.player_set_animation, player, anim_name, 30)
		return
	end

	-- Minetest Game / player_api
	if minetest.global_exists("player_api") and player_api.set_animation then
		pcall(player_api.set_animation, player, anim_name, 30)
		return
	end

	-- Default / legacy
	if minetest.global_exists("default") and default.player_set_animation then
		pcall(default.player_set_animation, player, anim_name, 30)
		return
	end

	-- Direct player method fallback
	if player.set_animation then
		if anim_name == "sit" then
			pcall(player.set_animation, player, {x = 81, y = 160}, 30, 0)
		else
			pcall(player.set_animation, player, {x = 0, y = 79}, 30, 0)
		end
	end
end

-- Prevents engine from overriding sit animation while boat is moving
local function set_player_attached_flag(player_name, state)
	if not player_name then return end
	if minetest.global_exists("player_api") and player_api.player_attached then
		player_api.player_attached[player_name] = state
	end
	if minetest.global_exists("mcl_player") and mcl_player.player_attached then
		mcl_player.player_attached[player_name] = state
	end
	if minetest.global_exists("default") and default.player_attached then
		default.player_attached[player_name] = state
	end
end

local function get_velocity(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y or 0, z = z}
end

-- HUD Dashboard Formatter
local function get_hud_data(self)
	local step = self.speed_step or 0
	local speed = math.abs(self.v or 0)
	local bar = ""
	for i = 1, 7 do
		if i <= step then
			bar = bar .. "■"
		else
			bar = bar .. "□"
		end
	end

	if self.sinking then
		return "🚨 MAYDAY! BOAT SINKING! HULL BREACH! 🚨", 0xFF2222
	elseif step == 0 then
		return string.format("🚤 IDLE [ %s ] Step 0/7 (0.0 m/s) | [W] Accelerate  [Shift] Exit", bar), 0xCCCCCC
	elseif step == 7 then
		return string.format("⚡ MAX SPEED [ %s ] Step 7/7 (%.1f m/s) | Cruise Active", bar, speed), 0x00FFFF
	else
		return string.format("🚤 CRUISING [ %s ] Step %d/7 (%.1f m/s) | [W] Gear Up  [S] Gear Down", bar, step, speed), 0x00FF88
	end
end

-- -----------------------------------------------------------------------------
-- Single Boats Registry Data (Roofed vs Open Top)
-- -----------------------------------------------------------------------------

local single_boats = {
	{
		id = "fan",
		title = S("Fan Speedboat"),
		desc = S("Swamp Fan Airboat - Propeller powered, open cockpit watercraft."),
		mesh = "boat-fan.obj",
		icon = "boat-fan.png",
		has_roof = false,
		seat_offset = {x = 0, y = 3.2, z = -7.5},
	},
	{
		id = "speed_a",
		title = S("Speedboat Alpha"),
		desc = S("Classic Marine Cruiser - Enclosed cabin cruiser with roof and windshield."),
		mesh = "boat-speed-a.obj",
		icon = "boat-speed-a.png",
		has_roof = true,
		seat_offset = {x = 0, y = 2.0, z = -9.5},
	},
	{
		id = "speed_b",
		title = S("Speedboat Bravo"),
		desc = S("Sport Interceptor - Streamlined roofed cabin racing hull designed for open seas."),
		mesh = "boat-speed-b.obj",
		icon = "boat-speed-b.png",
		has_roof = true,
		seat_offset = {x = 0, y = 2.0, z = -9.5},
	},
	{
		id = "speed_c",
		title = S("Speedboat Charlie"),
		desc = S("Aqua Cruiser - High-acceleration watercraft with enclosed cabin and roof."),
		mesh = "boat-speed-c.obj",
		icon = "boat-speed-c.png",
		has_roof = true,
		seat_offset = {x = 0, y = 2.0, z = -9.5},
	},
	{
		id = "speed_d",
		title = S("Speedboat Delta"),
		desc = S("Offshore Predator - Extended deep-V open-top hull built for cutting through waves."),
		mesh = "boat-speed-d.obj",
		icon = "boat-speed-d.png",
		has_roof = false,
		seat_offset = {x = 0, y = 2.5, z = -9.5},
	},
	{
		id = "speed_e",
		title = S("Speedboat Echo"),
		desc = S("Hydro Jet - Compact agile open-top speedboat with rear jet thrusters."),
		mesh = "boat-speed-e.obj",
		icon = "boat-speed-e.png",
		has_roof = false,
		seat_offset = {x = 0, y = 2.5, z = -9.0},
	},
	{
		id = "speed_f",
		title = S("Speedboat Foxtrot"),
		desc = S("Vortex Runner - Broad-beam stability with open-top cockpit seating."),
		mesh = "boat-speed-f.obj",
		icon = "boat-speed-f.png",
		has_roof = false,
		seat_offset = {x = 0, y = 2.5, z = -9.0},
	},
	{
		id = "speed_g",
		title = S("Speedboat Golf"),
		desc = S("Arrowhead Sprint - Long needle-nose enclosed cabin hull for high-velocity travel."),
		mesh = "boat-speed-g.obj",
		icon = "boat-speed-g.png",
		has_roof = true,
		seat_offset = {x = 0, y = 2.0, z = -9.5},
	},
	{
		id = "speed_h",
		title = S("Speedboat Hotel"),
		desc = S("Coastal Patrol - Reinforced open-top hull equipped for long-range cruising."),
		mesh = "boat-speed-h.obj",
		icon = "boat-speed-h.png",
		has_roof = false,
		seat_offset = {x = 0, y = 2.5, z = -9.0},
	},
	{
		id = "speed_i",
		title = S("Speedboat India"),
		desc = S("Stealth Phantom - Dark racing profile with enclosed cabin and roof."),
		mesh = "boat-speed-i.obj",
		icon = "boat-speed-i.png",
		has_roof = true,
		seat_offset = {x = 0, y = 2.0, z = -9.5},
	},
	{
		id = "speed_j",
		title = S("Speedboat Juliet"),
		desc = S("Thunderbolt Edition - Deluxe performance open-top speedboat variant."),
		mesh = "boat-speed-d.obj",
		icon = "boat-speed-j.png",
		has_roof = false,
		seat_offset = {x = 0, y = 2.5, z = -9.5},
	},
}

-- -----------------------------------------------------------------------------
-- Speedboat Entity Core Logic
-- -----------------------------------------------------------------------------

local function create_boat_entity(bdef)
	local entity = {
		initial_properties = {
			physical = true,
			-- Symmetric square AABB to prevent rotation clipping / edge shaking
			collisionbox = {-0.6, -0.35, -0.6, 0.6, 0.35, 0.6},
			visual = "mesh",
			mesh = bdef.mesh,
			textures = {"colormap.png"},
			-- Mesh models are scaled in OBJ directly to 10 units = 1 node; visual_size is 1 to keep attached player at natural 1.0 scale!
			visual_size = {x = 1, y = 1, z = 1},
			makes_footstep_sound = false,
			stepheight = 0.1,
		},

		boat_id = bdef.id,
		item_name = modname .. ":" .. bdef.id,
		has_roof = bdef.has_roof or false,
		seat_offset = bdef.seat_offset or {x = 0, y = 2.5, z = -9.0},

		driver = nil,
		v = 0,
		speed_step = 0, -- 0 to 7 cruise steps
		sinking = false,
		sink_timer = 0,
		hp = 20,
		wake_timer = 0,
		anim_timer = 0,
		key_timer = 0,
		hud_id = nil,
		last_ctrl = {up = false, down = false, left = false, right = false},
		removed = false,
	}

	function entity:update_hud(player)
		if not player or not self.hud_id then return end
		local text, color = get_hud_data(self)
		player:hud_change(self.hud_id, "text", text)
		player:hud_change(self.hud_id, "number", color)
	end

	function entity:detach_driver(player)
		if not player then return end
		local name = player:get_player_name()

		if self.hud_id then
			pcall(function() player:hud_remove(self.hud_id) end)
			self.hud_id = nil
		end

		player:set_detach()
		set_player_attached_flag(name, false)

		-- Always normalize player properties upon dismounting
		player:set_properties({
			visual_size = {x = 1, y = 1, z = 1},
			is_visible = true,
		})
		player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		set_player_animation(player, "stand")

		local pos = self.object:get_pos()
		if pos then
			minetest.after(0.05, function()
				if player and player:is_player() then
					player:set_pos({x = pos.x, y = pos.y + 0.6, z = pos.z})
				end
			end)
		end

		self.driver = nil
		self.speed_step = 0
	end

	function entity:on_rightclick(clicker)
		if not clicker or not clicker:is_player() or self.removed or self.sinking then
			return
		end
		local name = clicker:get_player_name()

		-- Dismount if already the driver
		if self.driver and name == self.driver then
			self:detach_driver(clicker)
			return
		end

		-- Mount if empty
		if not self.driver then
			clicker:set_attach(self.object, "", self.seat_offset, {x = 0, y = 0, z = 0})
			self.driver = name
			set_player_attached_flag(name, true)

			if self.has_roof then
				-- On boats with roofs (speed_a, speed_b, speed_c, speed_g), hide player model completely
				clicker:set_properties({
					visual_size = {x = 0, y = 0, z = 0},
					is_visible = false,
				})
			else
				-- On open-top boats, fix player to the seat in the exact normal size
				clicker:set_properties({
					visual_size = {x = 1, y = 1, z = 1},
					is_visible = true,
				})
				minetest.after(0.1, function()
					if clicker and clicker:is_player() and self.driver == name then
						set_player_animation(clicker, "sit")
					end
				end)
			end

			-- Lower eye offset for cockpit perspective
			clicker:set_eye_offset({x = 0, y = -1.5, z = 0}, {x = 0, y = -1.5, z = 0})
			clicker:set_look_horizontal(self.object:get_yaw())

			-- Create cockpit HUD gauge
			local text, color = get_hud_data(self)
			self.hud_id = clicker:hud_add({
				hud_elem_type = "text",
				position = {x = 0.5, y = 0.83},
				alignment = {x = 0, y = 0},
				text = text,
				number = color,
				scale = {x = 100, y = 20},
			})

			play_sound("default_place_node", {pos = self.object:get_pos(), gain = 0.4})
		end
	end

	function entity:on_detach_child(child)
		if child and child:is_player() and child:get_player_name() == self.driver then
			local name = self.driver
			set_player_attached_flag(name, false)
			child:set_properties({
				visual_size = {x = 1, y = 1, z = 1},
				is_visible = true,
			})
			if self.hud_id then
				pcall(function() child:hud_remove(self.hud_id) end)
				self.hud_id = nil
			end
			self.driver = nil
			self.speed_step = 0
		end
	end

	-- Pickaxe-only destruction requirement
	function entity:on_punch(puncher)
		if not puncher or not puncher:is_player() or self.removed then
			return
		end
		local puncher_name = puncher:get_player_name()
		local wielded = puncher:get_wielded_item()
		local tool_name = wielded:get_name()

		if not is_pickaxe(tool_name) then
			-- Refuse destruction if not hit with a pickaxe
			play_sound("default_place_node", {pos = self.object:get_pos(), gain = 0.8})
			minetest.chat_send_player(puncher_name, S("⚓ Speedboats are reinforced! They can only be dismantled with a pickaxe."))
			return
		end

		-- Pickaxe confirmed: dismantle boat
		self.removed = true

		if self.driver then
			local drv = minetest.get_player_by_name(self.driver)
			if drv then
				self:detach_driver(drv)
			end
		end

		play_sound("default_dig_cracky", {pos = self.object:get_pos(), gain = 1.0})

		local inv = puncher:get_inventory()
		local is_creative = minetest.is_creative_enabled and minetest.is_creative_enabled(puncher_name)
		local item = self.item_name or (modname .. ":speed_a")

		if not is_creative then
			if inv and inv:room_for_item("main", item) then
				inv:add_item("main", item)
			else
				minetest.add_item(self.object:get_pos(), item)
			end
		end

		self.object:remove()
	end

	function entity:on_activate(staticdata, dtime_s)
		self.object:set_armor_groups({immortal = 1})
		if staticdata and staticdata ~= "" then
			local data = minetest.deserialize(staticdata)
			if type(data) == "table" then
				self.v = data.v or 0
				self.speed_step = data.speed_step or 0
				self.hp = data.hp or 20
			end
		end
	end

	function entity:get_staticdata()
		return minetest.serialize({
			v = self.v,
			speed_step = self.speed_step,
			hp = self.hp,
		})
	end

	function entity:on_step(dtime)
		local pos = self.object:get_pos()
		if not pos then return end
		local yaw = self.object:get_yaw()
		local dir = {x = -math.sin(yaw), y = 0, z = math.cos(yaw)}

		-- ---------------------------------------------------------------------
		-- 1. Lava Damage & Burning
		-- ---------------------------------------------------------------------
		if is_lava(pos) or is_lava({x = pos.x, y = pos.y - 0.5, z = pos.z}) then
			self.hp = self.hp - (dtime * 15)

			-- Spawn flames & black smoke
			minetest.add_particlespawner({
				amount = 8,
				time = 0.2,
				minpos = {x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5},
				maxpos = {x = pos.x + 0.5, y = pos.y + 0.8, z = pos.z + 0.5},
				minvel = {x = -0.3, y = 1.0, z = -0.3},
				maxvel = {x = 0.3, y = 2.5, z = 0.3},
				minexptime = 0.5,
				maxexptime = 1.2,
				minsize = 2,
				maxsize = 4,
				texture = "fire_basic_flame.png",
			})

			play_sound("fire_extinguish_flame", {pos = pos, gain = 0.7})

			-- Eject driver if boat enters lava
			if self.driver then
				local drv = minetest.get_player_by_name(self.driver)
				if drv then
					minetest.chat_send_player(self.driver, S("🔥 DANGER! Your speedboat fell into lava and is burning!"))
					self:detach_driver(drv)
				end
			end

			if self.hp <= 0 then
				play_sound("fire_fire", {pos = pos, gain = 1.0})
				self.object:remove()
				return
			end
		end

		-- ---------------------------------------------------------------------
		-- 2. Sinking Process (Hit Ice)
		-- ---------------------------------------------------------------------
		if self.sinking then
			self.sink_timer = self.sink_timer + dtime
			self.speed_step = 0
			self.v = 0

			-- Tilt pitch forward as water rushes in
			local tilt = math.min(0.40, self.sink_timer * 0.18)
			self.object:set_rotation({x = tilt, y = yaw, z = 0})

			-- Downward sinking velocity
			self.object:set_velocity({x = 0, y = -1.2, z = 0})
			self.object:set_acceleration({x = 0, y = -1.0, z = 0})

			-- Bubble particle burst
			minetest.add_particlespawner({
				amount = 6,
				time = 0.2,
				minpos = {x = pos.x - 0.6, y = pos.y - 0.2, z = pos.z - 0.6},
				maxpos = {x = pos.x + 0.6, y = pos.y + 0.4, z = pos.z + 0.6},
				minvel = {x = -0.2, y = 0.8, z = -0.2},
				maxvel = {x = 0.2, y = 2.0, z = 0.2},
				minexptime = 0.8,
				maxexptime = 1.6,
				minsize = 1.5,
				maxsize = 3.0,
				texture = "speedboats_bubble.png",
			})

			if self.driver then
				local drv = minetest.get_player_by_name(self.driver)
				if drv then
					self:update_hud(drv)
				end
			end

			-- After sinking deep underwater, eject driver and settle wreck
			if self.sink_timer >= 2.6 then
				if self.driver then
					local drv = minetest.get_player_by_name(self.driver)
					if drv then
						self:detach_driver(drv)
						minetest.chat_send_player(drv:get_player_name(), S("❄️ Your speedboat struck ice and sank to the depths!"))
					end
				end

				-- Drop wreckage fragments (iron / wood)
				if is_mcl then
					minetest.add_item(pos, "mcl_core:iron_ingot")
				elseif is_default then
					minetest.add_item(pos, "default:steel_ingot")
				end

				self.object:remove()
				return
			end
			return
		end

		-- ---------------------------------------------------------------------
		-- 3. Driver Controls & 7-Step Cruise Navigation
		-- ---------------------------------------------------------------------
		local driver_obj = nil
		if self.driver then
			driver_obj = minetest.get_player_by_name(self.driver)
			if not driver_obj then
				self.driver = nil
				self.speed_step = 0
			else
				local ctrl = driver_obj:get_player_control()

				-- Exit boat with Shift (Sneak)
				if ctrl.sneak then
					self:detach_driver(driver_obj)
					return
				end

				-- Shift speed steps (0 to 7)
				if ctrl.up then
					if not self.last_ctrl.up or (self.key_timer and self.key_timer > 0.32) then
						if self.speed_step < 7 then
							self.speed_step = self.speed_step + 1
							self.key_timer = 0
							play_sound("default_place_node", {pos = pos, gain = 0.3})
							self:update_hud(driver_obj)
						end
					else
						self.key_timer = (self.key_timer or 0) + dtime
					end
				elseif ctrl.down then
					if not self.last_ctrl.down or (self.key_timer and self.key_timer > 0.32) then
						if self.speed_step > 0 then
							self.speed_step = self.speed_step - 1
							self.key_timer = 0
							play_sound("default_place_node", {pos = pos, gain = 0.3})
							self:update_hud(driver_obj)
						end
					else
						self.key_timer = (self.key_timer or 0) + dtime
					end
				else
					self.key_timer = 0
				end

				-- Steering (Yaw)
				local steer_rate = 1.3
				if ctrl.left then
					if self.v < -0.01 then
						yaw = yaw - dtime * steer_rate
					else
						yaw = yaw + dtime * steer_rate
					end
					self.object:set_yaw(yaw)
				elseif ctrl.right then
					if self.v < -0.01 then
						yaw = yaw + dtime * steer_rate
					else
						yaw = yaw - dtime * steer_rate
					end
					self.object:set_yaw(yaw)
				end

				dir = {x = -math.sin(yaw), y = 0, z = math.cos(yaw)}

				-- Keep seated animation refreshed on open boats
				if not self.has_roof then
					self.anim_timer = (self.anim_timer or 0) + dtime
					if self.anim_timer > 0.8 then
						self.anim_timer = 0
						set_player_animation(driver_obj, "sit")
						set_player_attached_flag(self.driver, true)
						self:update_hud(driver_obj)
					end
				end

				self.last_ctrl.up = ctrl.up
				self.last_ctrl.down = ctrl.down
			end
		end

		-- ---------------------------------------------------------------------
		-- 4. Idle Check (Completely Stops Any Jitter / Shaking When Resting)
		-- ---------------------------------------------------------------------
		local velo = self.object:get_velocity()
		if not self.driver and self.v == 0 and self.speed_step == 0 and
				velo and math.abs(velo.x) < 0.01 and math.abs(velo.y) < 0.01 and math.abs(velo.z) < 0.01 then
			return
		end

		-- ---------------------------------------------------------------------
		-- 5. Cruise Throttle & Target Velocity
		-- ---------------------------------------------------------------------
		local target_v = self.speed_step * 1.0

		if self.speed_step == 0 then
			if driver_obj and driver_obj:get_player_control().down then
				self.v = math.max(-1.5, self.v - dtime * 2.0)
			else
				local drag = dtime * 2.5
				if math.abs(self.v) <= drag then
					self.v = 0
				else
					self.v = self.v - math.sign(self.v) * drag
				end
			end
		else
			if self.v < target_v then
				self.v = math.min(target_v, self.v + dtime * 2.5)
			elseif self.v > target_v then
				self.v = math.max(target_v, self.v - dtime * 3.5)
			end
		end

		-- ---------------------------------------------------------------------
		-- 6. Ice Collision Detection (Sink on Impact During Travel)
		-- ---------------------------------------------------------------------
		if self.v >= 1.0 and not self.sinking then
			local bow_pos1 = vector.add(pos, vector.multiply(dir, 1.4))
			local bow_pos2 = vector.add(pos, vector.multiply(dir, 2.0))
			local n1 = minetest.get_node_or_nil(bow_pos1)
			local n2 = minetest.get_node_or_nil(bow_pos2)
			local n1_low = minetest.get_node_or_nil({x = bow_pos1.x, y = bow_pos1.y - 0.4, z = bow_pos1.z})

			if (n1 and is_ice(n1.name)) or (n2 and is_ice(n2.name)) or (n1_low and is_ice(n1_low.name)) then
				self.sinking = true
				self.sink_timer = 0
				self.speed_step = 0
				self.v = self.v * 0.1

				play_sound("default_break_glass", {pos = pos, gain = 1.0})
				play_sound("default_water_footstep", {pos = pos, gain = 1.0})

				if self.driver then
					minetest.chat_send_player(self.driver, S("🚨 CRUNCH! You struck ice! Your speedboat is taking on water and sinking!"))
				end

				minetest.add_particlespawner({
					amount = 30,
					time = 1.0,
					minpos = {x = pos.x - 0.8, y = pos.y - 0.2, z = pos.z - 0.8},
					maxpos = {x = pos.x + 0.8, y = pos.y + 0.6, z = pos.z + 0.8},
					minvel = {x = -0.5, y = 0.5, z = -0.5},
					maxvel = {x = 0.5, y = 2.0, z = 0.5},
					minexptime = 1.0,
					maxexptime = 2.0,
					minsize = 2.0,
					maxsize = 4.0,
					texture = "speedboats_bubble.png",
				})
				return
			end
		end

		-- ---------------------------------------------------------------------
		-- 7. Rock-Solid Water Buoyancy & Shore Stop (Eliminates Shaking)
		-- ---------------------------------------------------------------------
		local p = {x = pos.x, y = pos.y - 0.5, z = pos.z}
		local new_velo = {x = 0, y = 0, z = 0}
		local new_acce = {x = 0, y = 0, z = 0}

		if not is_water(p) then
			-- On landmass or in freefall
			local nodedef = minetest.registered_nodes[minetest.get_node(p).name]
			if (not nodedef) or nodedef.walkable then
				-- Landmass stop
				self.v = 0
				self.speed_step = 0
				new_acce = {x = 0, y = 0, z = 0}
				new_velo = {x = 0, y = 0, z = 0}
				if driver_obj then
					self:update_hud(driver_obj)
				end
			else
				-- Airborne gravity
				new_acce = {x = 0, y = -9.8, z = 0}
				new_velo = get_velocity(self.v, yaw, velo and velo.y or 0)
			end
		else
			-- In water: check if submerged under water surface
			local p_above = {x = p.x, y = p.y + 1.0, z = p.z}
			if is_water(p_above) then
				-- Submerged: smooth upward buoyancy acceleration
				local y_vel = velo and velo.y or 0
				if y_vel >= 5 then
					y_vel = 5
				elseif y_vel < 0 then
					new_acce = {x = 0, y = 20, z = 0}
				else
					new_acce = {x = 0, y = 5, z = 0}
				end
				new_velo = get_velocity(self.v, yaw, y_vel)
			else
				-- At water surface: stable equilibrium (zero vertical acceleration)
				new_acce = {x = 0, y = 0, z = 0}
				local cur_vy = velo and velo.y or 0
				if math.abs(cur_vy) < 1.0 then
					-- Float naturally with bottom of hull slightly into water
					pos.y = math.floor(pos.y) + 0.35
					self.object:set_pos(pos)
					new_velo = get_velocity(self.v, yaw, 0)
				else
					new_velo = get_velocity(self.v, yaw, cur_vy)
				end

				-- Check ahead for solid land shoreline
				local front_pos = vector.add(pos, vector.multiply(dir, 1.4))
				local front_node = minetest.get_node_or_nil(front_pos)
				local fdef = front_node and minetest.registered_nodes[front_node.name]
				if fdef and fdef.walkable and not is_water(front_pos) then
					if self.v > 0 then
						self.v = 0
						self.speed_step = 0
						play_sound("default_place_node", {pos = pos, gain = 0.4})
						if driver_obj then
							self:update_hud(driver_obj)
						end
					end
				end

				-- Water wake particles when moving
				if math.abs(self.v) >= 1.5 then
					self.wake_timer = (self.wake_timer or 0) + dtime
					if self.wake_timer > 0.12 then
						self.wake_timer = 0
						local stern_pos = vector.subtract(pos, vector.multiply(dir, 1.4))
						minetest.add_particlespawner({
							amount = 4,
							time = 0.1,
							minpos = {x = stern_pos.x - 0.3, y = stern_pos.y, z = stern_pos.z - 0.3},
							maxpos = {x = stern_pos.x + 0.3, y = stern_pos.y + 0.2, z = stern_pos.z + 0.3},
							minvel = {x = -0.2, y = 0.2, z = -0.2},
							maxvel = {x = 0.2, y = 0.8, z = 0.2},
							texture = "speedboats_wake.png",
						})
					end
				end
			end
		end

		self.object:set_velocity(new_velo)
		self.object:set_acceleration(new_acce)
	end

	return entity
end

-- -----------------------------------------------------------------------------
-- Registration of Single Boats (Items & Entities)
-- -----------------------------------------------------------------------------

for _, bdef in ipairs(single_boats) do
	local item_name = modname .. ":" .. bdef.id
	local entity_name = modname .. ":entity_" .. bdef.id

	-- 1. Register Entity
	minetest.register_entity(entity_name, create_boat_entity(bdef))

	-- 2. Register Single Boat Craftitem
	minetest.register_craftitem(item_name, {
		description = bdef.title .. "\n" .. bdef.desc,
		inventory_image = bdef.icon,
		wield_image = bdef.icon,
		wield_scale = {x = 1.5, y = 1.5, z = 1.0},
		liquids_pointable = true,
		groups = {boat = 1, speedboat = 1, transport = 1, flammable = 2},

		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end

			local under = pointed_thing.under
			local above = pointed_thing.above

			-- Must be placed in or on water
			if not is_water(under) and not is_water(above) then
				return itemstack
			end

			local spawn_pos = table.copy(under)
			if not is_water(under) then
				spawn_pos = table.copy(above)
			end

			-- Center horizontally and place at water surface level
			spawn_pos.x = math.floor(spawn_pos.x) + 0.5
			spawn_pos.y = math.floor(spawn_pos.y) + 0.35
			spawn_pos.z = math.floor(spawn_pos.z) + 0.5

			local obj = minetest.add_entity(spawn_pos, entity_name)
			if obj then
				if placer and placer:is_player() then
					obj:set_yaw(placer:get_look_horizontal())
				end
				obj:set_velocity({x = 0, y = 0, z = 0})
				obj:set_acceleration({x = 0, y = 0, z = 0})

				play_sound("default_place_node", {pos = spawn_pos, gain = 0.6})

				local pname = placer and placer:is_player() and placer:get_player_name()
				local is_creative = pname and minetest.is_creative_enabled and minetest.is_creative_enabled(pname)
				if not is_creative then
					itemstack:take_item()
				end
			end

			return itemstack
		end,
	})
end

-- Convenience aliases
minetest.register_alias("speedboats:boat", "speedboats:speed_a")
minetest.register_alias("speedboats:speedboat", "speedboats:speed_a")
minetest.register_alias("speedboats:airboat", "speedboats:fan")

-- -----------------------------------------------------------------------------
-- Player Scale Normalization on Join & Command
-- -----------------------------------------------------------------------------

minetest.register_on_joinplayer(function(player)
	player:set_properties({
		visual_size = {x = 1, y = 1, z = 1},
		is_visible = true,
	})
end)

minetest.register_chatcommand("fixsize", {
	description = S("Reset player scale and visibility to normal"),
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if player then
			player:set_properties({
				visual_size = {x = 1, y = 1, z = 1},
				is_visible = true,
			})
			player:set_detach()
			set_player_animation(player, "stand")
			return true, S("Player scale and visibility normalized.")
		end
	end,
})

-- -----------------------------------------------------------------------------
-- Crafting Recipes (Mineclonia / VoxeLibre & Minetest Game)
-- -----------------------------------------------------------------------------

if is_mcl then
	-- Mineclonia & VoxeLibre recipes
	minetest.register_craft({
		output = "speedboats:speed_a",
		recipe = {
			{"mcl_core:iron_ingot", "", "mcl_core:iron_ingot"},
			{"group:wood", "mcl_core:redstone", "group:wood"},
			{"group:wood", "group:wood", "group:wood"},
		}
	})

	minetest.register_craft({
		output = "speedboats:fan",
		recipe = {
			{"", "mcl_core:iron_ingot", ""},
			{"mcl_core:iron_ingot", "mcl_core:redstone", "mcl_core:iron_ingot"},
			{"group:wood", "group:wood", "group:wood"},
		}
	})
elseif is_default then
	-- Minetest Game recipes
	minetest.register_craft({
		output = "speedboats:speed_a",
		recipe = {
			{"default:steel_ingot", "", "default:steel_ingot"},
			{"group:wood", "default:copper_ingot", "group:wood"},
			{"group:wood", "group:wood", "group:wood"},
		}
	})

	minetest.register_craft({
		output = "speedboats:fan",
		recipe = {
			{"", "default:steel_ingot", ""},
			{"default:steel_ingot", "default:copper_ingot", "default:steel_ingot"},
			{"group:wood", "group:wood", "group:wood"},
		}
	})
else
	-- Generic fallback craft
	minetest.register_craft({
		output = "speedboats:speed_a",
		recipe = {
			{"", "", ""},
			{"group:wood", "group:wood", "group:wood"},
			{"group:wood", "group:wood", "group:wood"},
		}
	})
end

-- Shapeless model conversion cycling: craft any speedboat alone to cycle models
for i = 1, #single_boats do
	local current_item = modname .. ":" .. single_boats[i].id
	local next_index = (i % #single_boats) + 1
	local next_item = modname .. ":" .. single_boats[next_index].id

	minetest.register_craft({
		type = "shapeless",
		output = next_item,
		recipe = {current_item},
	})
end

minetest.log("action", "[speedboats] Loaded " .. #single_boats .. " single speedboats successfully.")
