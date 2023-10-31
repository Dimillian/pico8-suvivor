pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
// grassland survivor 0.4

--player

player = {
	sprite_idle=1,
	sprite_move1=2,
	sprite_move2=3,
	sprite_grace=4,
	sprite_move1_up=5,
	sprite_move2_up=6,
	sprite_move1_down=7,
	sprite_move2_down=8,

	init=function(self)
		self.level=1
		self.xp=0
		self.xp_radius=16
		self.next_xp = 10
		self.health = 5
		self.max_health=5
		self.kills=0
		self.weapons={ }
		self.is_moving=false

		self.grace_delay=50
		self.grace_counter=0
		self.grace_on=false

		self.proj_delay=100
		self.proj_counter=0
		self.proj_damage_x=1
		self.proj_delay_x=0
		self.proj_speed_x=1
		self.proj_count=1
		self.proj_max_pierce=1
		self.proj={ }

		self.sword_radius_x = 0
		self.sword_speed_x = 0
		self.sword_attack_x = 0
		self.swords={ }

		self.x=512
		self.y=256
		self.speed=0.5
		self.direction=0
		self.sprite_moving_routing = cocreate(self.update_sprite_routine)
	end,

	draw=function(self)
		self:draw_ui()
		self:draw_player()
		self:draw_proj()
		self:draw_swords()
	end,

	draw_player=function(self)
		spr(self.sprite, self.x, self.y, 1, 1, self.direction == 0, false)
	end,

	draw_proj=function(self)
		for proj in all(self.proj) do
			proj:draw()
		end
	end,

	draw_swords=function(self)
		for sword in all(self.swords) do
			sword:draw()
		end
	end,

	draw_ui=function(self)
		local x = player.x-64
		local y = player.y-64
		rectfill(x+3, y+4, x + 123, y + 6, 6)
		if self.xp > 0 then
			local xp_w = flr((self.xp / self.next_xp) * 123)
			rectfill(x+4, y+5, x + xp_w, y + 5, 2)
		end
		print("lvl" .. player.level, x + 108, y + 2, 7)

		rectfill(x+3, y+9, x + 60, y + 11, 7)
		local hp_w = flr((self.health / self.max_health) * 59)
		rectfill(x+4, y+10, x + hp_w, y + 10, 8)
		print(self.health .. "/" .. self.max_health, x + 62, y + 9, 7)
		print("score:" .. self.kills,  x + 4 ,y + 120, 7)
	end,

	update=function(self)
		self:update_movements()
		self:update_grace()
		self:update_level()
		self:update_proj()
		self:update_swords()
		self:update_sprite()
		self:update_health()
	end,

	update_movements=function(self)
		if btn(0) or btn(1) or btn(2) or btn(3) then
			self.is_moving=true
			if btn(0) then
				self.direction = 0
				self.x = self.x - self.speed
			elseif btn(1) then
				self.direction = 1
				self.x = self.x + self.speed
			end

			if btn(2) then
				self.direction = 2
				self.y = self.y - self.speed
			elseif btn(3) then
				self.direction = 3
				self.y = self.y + self.speed
			end
		else
			self.is_moving=false
		end
	end,

	update_sprite=function(self)
		if costatus(self.sprite_moving_routing) != "dead" then
			coresume(self.sprite_moving_routing, self)
		end
	end,

	update_sprite_routine=function(self)
		while true do
			if self.grace_on then
				self.sprite = self.sprite_grace
				delay(2)
				self.sprite = self.sprite_idle
				delay(2)
			elseif self.is_moving then
				local move1 = self.sprite_move1
				local move2 = self.sprite_move2
				if self.direction == 2 then
					move1 = self.sprite_move1_up
					move2 = self.sprite_move2_up
				elseif self.direction == 3 then
					move1 = self.sprite_move1_down
					move2 = self.sprite_move2_down
				end

				self.sprite = move1
				delay(5)
				self.sprite = move2
				delay(5)
			else
				self.sprite = self.sprite_idle
				yield()
			end
		end
	end,

	update_level=function(self)
		if self.xp >= self.next_xp then
			sfx(sfx_level_up)
			self.xp = 0
			self.level += 1
			self.next_xp = ceil(self.next_xp * 1.5)
			state = state_lvl_up
		end
	end,

	update_proj=function(self)
		self.proj_counter = self.proj_counter + 1
		if self.proj_counter >= (self.proj_delay - self.proj_delay_x) then
			self.proj_counter = 0
			local c = cocreate(function()
				local targets = {}
				for i=1, self.proj_count do
					local foe = closest_foe(targets)
					add(targets, foe)
					self:add_projectile(foe)
					delay(10)
				end
			end)
			add(actions, c)
		end
		for proj in all(self.proj) do
			proj:update()
		end
	end,

	update_swords=function(self)
		for sword in all(self.swords) do
			sword:update()
		end
	end,

	update_grace=function(self)
		self.grace_counter = self.grace_counter + 1
		if self.grace_counter >= self.grace_delay then
			self.grace_counter = 0
			self.grace_on = false
		end
	end,

	update_health=function(self)
		if self.health <= 0 then
			if self.kills > dget(0) then
				dset(0, self.kills)
			end
			state = state_game_over
		end
	end,

	add_projectile=function(self, foe)
		local angle = atan2(foe.x - self.x, foe.y - self.y)
		local proj = {
			damage=self.proj_damage_x,
			speed=0.8 * self.proj_speed_x,
			sprite=50,
			x=flr(self.x),
			y=flr(self.y),
			distance=0,
			distance_max=100,
			angle=angle,
			pierce_count=0,
			foe_hits={},
			draw=function(self)
				spr(self.sprite, self.x, self.y)
			end,
			update=function(self)
				self.distance = self.distance + 1
				if self.distance >= self.distance_max then
					del(player.proj, self)
				end

				self.x = self.x + self.speed * cos(self.angle)
				self.y = self.y + self.speed * sin(self.angle)
				self:update_sprite()
			end,
			update_sprite=function(self)
				if costatus(self.sprite_moving_routing) != "dead" then
					coresume(self.sprite_moving_routing, self)
				end
			end,
			update_sprite_routine=function(self)
				while true do
					self.sprite = 50
					delay(5)
					self.sprite = 51
					delay(5)
					self.sprite = 50
					delay(5)
					self.sprite = 52
					delay(5)
				end
			end
		}
		sfx(sfx_proj)
		proj.sprite_moving_routing = cocreate(proj.update_sprite_routine)
		add(self.proj, proj)
	end,

	add_sword=function(self)
		local sword = {
			sprite=49,
			x=0,
			y=0,
			angle=0,
			radius=12,
			speed=0.008,
			attack=1,
			draw=function(self)
				local radius = self.radius + player.sword_radius_x
				local speed = self.speed + player.sword_speed_x
				local x_offset = cos(self.angle) * radius
				local y_offset = sin(self.angle) * radius
				self.x = player.x + x_offset
				self.y = player.y + y_offset
				spr(self.sprite, self.x, self.y)
				self.angle = (self.angle + speed) % (2 * 3.14159265)
			end,
			update=function(self)
			end
		}
		add(self.swords, sword)
	end,

	hit_by_foe=function(self, foe)
		if self.grace_on then
			return
		end
		self.grace_on=true
		self.health = self.health - foe.attack
		world:add_damage(-foe.attack, self.x, self.y)
	end,

	collect_xp=function(self, xp)
		self.xp = self.xp + xp
		world:add_damage(xp, self.x, self.y)
		sfx(sfx_xp)
	end
}

-->8
--world

xp = {
	sprite=17,
	sprite_foe=18
}

world = {
	init=function(self)
		self.foes={}
		self.xp={}
		self.foes={}
		self.damages={}
		self.chests={}
		self.last_boss = 0

		self.world_map = {
			base_sprite = {64, 64, 64, 64, 64, 64, 80, 96, 112, 81, 113, 97},
			things_sprite = {65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 82},
			things_prob = 0.05,
		}

		self:gen_random_xp()
		self:gen_random_things()
	end,

	draw=function(self)
		map(0, 0)
		for xp in all(self.xp) do
			xp:draw()
		end
		for foe in all(self.foes) do
			foe:draw()
		end
		for thing in all(self.things) do
			thing:draw()
		end
		for damage in all(self.damages) do
			damage:draw()
		end
		for chest in all(self.chests) do
			chest:draw()
		end
	end,

	update=function(self, player)
		for xp in all(self.xp) do
			xp:update(player)
		end
		for foe in all(self.foes) do
			foe:update(player)
		end
		for damage in all(self.damages) do
			damage:update()
		end
		for chest in all(self.chests) do
			chest:update()
		end
		local boss_trigger = 30
		local c = 10 + (3 * player.level - 1)
		if #self.foes <= c then
			if player.kills > 0 and player.kills > self.last_boss and player.kills % boss_trigger == 0 then
				self.last_boss = player.kills
				self:add_foe(player, true)
			else
				self:add_foe(player, false)
			end
		end
	end,

	add_foe=function(self, player, is_boss)
		local x = player.x + rnd(player.x) - 128
		local y = player.y + rnd(player.y) - 128
		local speed = 0.15 * (player.level / 2)
		local xp = 1 * player.level
		local sprites = {33, 35, 37, 39, 41, 43, 45, 59}
		local sprite = flr(rnd(sprites))
		local health = ceil(1 * (player.level / 3))
		local sprite_size = 1
		if is_boss then
			speed += 0.15
			health += 10
			sprite = 9
			sprite_size = 2
		end
		local foe = {
			health=health,
			xp=xp,
			attack=1,
			is_dead=false,
			is_boss=is_boss,
			x=x,
			y=y,
			sprite=sprite,
			sprite_size=sprite_size,
			speed=speed,
			sword_immune_counter=0,
			init=function(self)
				self.sprite_moving_routing = cocreate(self.update_sprite_routine)
				self.sprite_death_routine= cocreate(self.play_death_routine)
			end,
			draw=function(self)
				spr(self.sprite, self.x, self.y, self.sprite_size, self.sprite_size)
			end,
			update=function(self, player)
				if not self.is_dead and is_colliding(self, player) then
					player:hit_by_foe(self)
				end

				self:update_position(player)
				self:update_health()
				self:update_sprite()
			end,

			update_position=function(self, player)
				if self.is_dead then
					return
				end
				local dx = player.x - self.x
				local dy = player.y - self.y
				local distance = sqrt(dx * dx + dy * dy)

				if distance > 0 then
					dx = dx / distance
					dy = dy / distance
				end

				self.x = self.x + dx * self.speed
				self.y = self.y + dy * self.speed

			end,

			update_health=function(self)
				self:check_proj()
				self:check_swords()
				self:check_death()
			end,

			check_proj=function(self)
				for proj in all(player.proj) do
					if is_colliding(self, proj) then
						for foe in all(proj.foe_hits) do
							if self == foe then
								return
							end
						end
						if self.is_dead then
							return
						end
						add(proj.foe_hits, self)
						self.health -= proj.damage
						proj.pierce_count = proj.pierce_count + 1
						if proj.pierce_count >= player.proj_max_pierce then
							del(player.proj, proj)
						end
						world:add_damage(-proj.damage, self.x + 2, self.y - 8)
					end
				end
			end,

			check_swords=function(self)
				if self.sword_immune_counter > 0 then
					self.sword_immune_counter -= 1
				end
				if self.sword_immune_counter == 0 then
					for sword in all(player.swords) do
						if is_colliding(self, sword) then
							local dmg = sword.attack + player.sword_attack_x
							self.health -= dmg
							world:add_damage(-dmg, self.x + 2, self.y - 8)
							self.sword_immune_counter = 15
						end
					end
				end
			end,

			check_death=function(self)
				if self.health <= 0 then
					if not self.is_dead then
						self.is_dead=true
						sfx(sfx_foe_death)
						player.kills = player.kills + 1
					end
					if costatus(self.sprite_death_routine) != "dead" then
						coresume(self.sprite_death_routine, self)
					end
				end
			end,

			update_sprite=function(self)
				if costatus(self.sprite_moving_routing) != "dead" then
					coresume(self.sprite_moving_routing, self)
				end
			end,

			update_sprite_routine=function(self)
				local sprite = self.sprite
				while self.is_dead == false do
					self.sprite = sprite
					delay(10)
					if self.is_dead then
						break
					end
					self.sprite += self.sprite_size
					delay(10)
				end
			end,

			play_death_routine=function(self)
				self.sprite_size = 1
				self.sprite = 61
				delay(8)
				self.sprite = 62
				delay(8)
				self.sprite = 63
				delay(8)
				if self.is_boss then
					world:add_chest(self.x, self.y)
				else
					world:add_xp(self.x, self.y, self.xp, true)
				end
				del(world.foes, self)
			end
		}
		foe:init()
		add(self.foes, foe)
	end,

	add_xp=function(self, x, y, value, is_foe)
		local sprite = xp.sprite
		if is_foe then
			sprite = xp.sprite_foe
		end
		local xp = {
			x = flr(x),
			y = flr(y),
			speed=0.5,
			is_agro=false,
			value = ceil(value),
			sprite= sprite,
			draw=function(self)
				spr(self.sprite, self.x, self.y)
			end,
			update=function(self, player)
				if is_colliding_radius(self, player, player.xp_radius) then
					self.is_agro=true
				end
				if is_colliding(self, player) then
					player:collect_xp(self.value)
					del(world.xp, self)
				end
				self:update_position(player)
			end,
			update_position=function(self, player)
				if not self.is_agro then
					return
				end
				local dx = player.x - self.x
				local dy = player.y - self.y
				local distance = sqrt(dx * dx + dy * dy)

				if distance > 0 then
					dx = dx / distance
					dy = dy / distance
				end

				self.x = self.x + dx * self.speed
				self.y = self.y + dy * self.speed

			end,
		}
		add(self.xp, xp)
	end,

	add_damage=function(self, damage, x, y)
		local damage = {
			value = damage,
			x = x,
			y = y,
			init=function(self)
				self.update_routine = cocreate(self.update_damage_y)
			end,
			draw=function(self)
				if self.value < 0 then
					print(self.value, self.x, self.y, -8)
				else
					print("+" .. self.value, self.x, self.y, -4)
				end
			end,
			update=function(self)
				if costatus(self.update_routine) != "dead" then
					coresume(self.update_routine, self)
				end
			end,
			update_damage_y=function(self)
				for i=0, 8 do
					self.y = self.y - 0.8
					delay(3)
				end
				del(world.damages, self)
			end
		}
		damage:init()
		add(self.damages, damage)
	end,

	add_chest=function(self, x, y)
		local chest = {
			x=x,
			y=y,
			sprite=19,
			update=function(self)
				if is_colliding(self, player) then
					self:open()
				end
			end,
			draw=function(self)
				spr(self.sprite, self.x, self.y, 1, 1)
			end,
			open=function(self)
				player.xp += player.next_xp
				del(world.chests, self)
			end
		}
		add(self.chests, chest)
	end,

	gen_random_xp=function(self)
		for i=1, 256 do
			self:add_xp(rnd(1024), rnd(512), rnd(3), false)
		end
	end,

	gen_random_things=function(self)
		for y=0,64 do
			for x=0,127 do
				local random_base_sprite = rnd(self.world_map.base_sprite)
				mset(x, y, random_base_sprite)
				local sprite = mget(x, y)
				if rnd(1) < self.world_map.things_prob then
					local	random_sprite = rnd(self.world_map.things_sprite)
					mset(x, y, random_sprite)
				end
			end
		end
	end

}

-->8
-- menu

menu_lvl_up = {
	selected=1,

	options = nil,
	sword_options_added = false,

	choices = {
		{target="player", name="speed", sprite=1},
		{target="player", name="health", sprite=1},
		{target="player", name="radius", sprite=17},
		{target="proj", name="speed", sprite=50},
		{target="proj", name="dmg", sprite=50},
		{target="proj", name="delay", sprite=50},
		{target="proj", name="count", sprite=50},
		{target="proj", name="pierce", sprite=50},
		{target="sword", name="count", sprite=49}
	},

	sword_options = {
		{target="sword", name="radius", sprite=49},
		{target="sword", name="speed", sprite=49},
		{target="sword", name="dmg", sprite=49}
	},

	draw=function(self)
		local menu_width=128
		local menu_height=80
		local x0=player.x - menu_width/2
		local y0=player.y - menu_height/2
		local x1=player.x + menu_width/2
		local y1=player.y + menu_height/2
		rectfill(x0,y0,x1,y1,-15)
		line(x0, y0, x0 + menu_width, y0, 7)
		print("level up!", x0 + 48, y0 + 5, 7)
		print("")
		print("level " .. player.level)
		print("")
		local base_x = x0 + 8
		local base_y = y0 + 32
		for index, option in pairs(self.options) do
			self:draw_option(base_x, base_y , option, index == self.selected)
			base_x += 46
		end
		print("❎ to select", x0 + 40, y1 - 12, 7)
		line(x0, y1, x0 + menu_width, y1, 7)
	end,

	draw_option=function(self, x0, y0, option, selected)
		local width = 15
		local height = 15
		local col = 7
		local scale_factor = 1
		if selected then
			col = 10
			scale_factor = 1 + 0.3 * sin(time())
		end

		local scaled_width = width * scale_factor
		local scaled_height = height * scale_factor
		local xoffset = x0 + (width - scaled_width) / 2
		local yoffset = y0 + (height - scaled_height) / 2

		oval(xoffset, yoffset, xoffset + scaled_width, yoffset + scaled_height, col)
		spr(option.sprite, x0 + 4, y0 + 4)
		print(option.name, x0, y0 + height + 4, col)
	end,

	update=function(self)
		if #player.swords > 0 and not self.sword_options_added then
			self.sword_options_added = true
			for option in all(self.sword_options) do
				add(self.choices, option)
			end
		end
		if self.options == nil then
			self.options = self:make_options()
		end

		decrease_btn_buffer()

		if is_btn_ready() then
			if btn(0) and self.selected > 1 then
				self.selected = self.selected - 1
			elseif btn(1) and self.selected < 3 then
				self.selected = self.selected + 1
			end
			if btn(5) then
				self:process_lvl_up(self.options[self.selected], player)
			end
			set_btn_buffer(15)
		end

	end,

	make_options=function(self)
		local copy = {}
		for key, value in pairs(self.choices) do
			copy[key] = value
		end
		local option1 = rnd(copy)
		del(copy, option1)
		local option2 = rnd(copy)
		del(copy, option2)
		local options = {
			option1,
			option2,
			rnd(copy)
		}
		return options
	end,

	process_lvl_up=function(self, option, player)
		if option.target == "player" then
			if option.name == "health" then
				player.max_health += 5
			elseif option.name == "speed" then
				player.speed += 0.15
			elseif option.name == "radius" then
				player.xp_radius += 4
			end
		elseif option.target == "proj" then
			if option.name == "speed" then
				player.proj_speed_x += 0.2
			elseif option.name == "dmg" then
				player.proj_damage_x += 1
			elseif option.name == "delay" then
				player.proj_delay_x -= 5
			elseif option.name == "count" then
				player.proj_count += 1
			elseif option.name == "pierce" then
				player.proj_max_pierce += 1
			end
		elseif option.target == "sword" then
			if option.name == "count" then
				player:add_sword()
			elseif option.name == "radius" then
				player.sword_radius_x += 2
			elseif option.name == "speed" then
				player.sword_speed_x += 0.003
			elseif option.name == "dmg" then
				player.sword_attack_x += 1
			end
		end
		player.health = player.max_health
		self.options = nil
		state = state_game
	end
}

menu_pause = {
	draw=function(self)
		local menu_width=128
		local menu_height=80
		local x0=player.x - menu_width/2
		local y0=player.y - menu_height/2
		local x1=player.x + menu_width/2
		local y1=player.y + menu_height/2
		rectfill(x0,y0,x1,y1,-15)
		line(x0, y0, x0 + menu_width, y0, 7)
		print("pause / stats", x0 + 38, y0 + 5, 7)
		print("level:" .. player.level, x0 + 48, y0 + 16)
		local py = y0 + 32
		spr(1, x0 + 8, py)
		print("♥" .. player.health .. "/" .. player.max_health, x0 + 18, py - 4)
		print("speed:" .. player.speed, x0 + 18, py+4)
		spr(17, x0 + 60, py - 1)
		print(player.xp .. "/" .. player.next_xp, x0 + 70, py - 4)
		print("radius:" .. player.xp_radius, x0 + 70, py + 4)
		py += 22
		spr(50, x0 + 8, py)
		print("speed:" .. 0.8 + player.proj_speed_x, x0 + 18, py - 4)
		print("dmg:" .. player.proj_damage_x, x0 + 18, py + 4)
		print("delay:" .. player.proj_delay - player.proj_delay_x, x0 + 60, py - 4)
		print("count:" .. player.proj_count, x0 + 44, py + 4)
		print("pierce:" .. player.proj_max_pierce, x0 + 76, py + 4)
		print("🅾️ to resume", x0 + 40, y1 - 12, 7)
		line(x0, y1, x0 + menu_width, y1, 7)
	end,
	update=function(self)

	end
}

menu_main = {
	player_sprite = 1,
	monster_sprite = 35,
	init=function(self)
		self.sprite_update_routine = cocreate(self.update_sprite)
	end,
	draw=function(self)
		draw_logo()
		spr(self.player_sprite, 38, 60)
		spr(self.monster_sprite, 52, 60)
		spr(19, 68, 60)
		print("❎ to start", 38, 80, 7)
		line(16, 100, 112, 100, -11)
		print("by dimillian", 38, 110, 7)
	end,
	update=function(self)
		if btn(5) then
			state = state_game
		end
		if costatus(self.sprite_update_routine) != "dead" then
			coresume(self.sprite_update_routine, self)
		end
	end,
	update_sprite=function(self)
		while true do
			self.player_sprite = 2
			self.monster_sprite = 36
			delay(5)
			self.player_sprite = 3
			self.monster_sprite = 35
			delay(5)
		end
	end
}

menu_game_over = {
	draw=function(self)
		draw_logo()
		local s = "game over"
		print(s, 64-#s*2, 61, 8)

		s = "score:" .. player.kills
		print(s, 64-#s*2, 80, 7)

		s = "best:" .. dget(0)
		print(s, 64-#s*2, 90, 7)

		s = "❎ to restart"
		print(s, 62-#s*2, 116, 7)
	end,
	update=function(self)
		if btn(5) then
			world:init()
			player:init()
			state = state_game
		end
	end
}
-->8
-- helpers

sfx_xp=0
sfx_level_up=1
sfx_proj=2
sfx_foe_death=3

actions={}

btn_buffer = 0

function is_colliding(a,b)
	return (abs(a.x-b.x)+
	abs(a.y-b.y)) <= 8
end

function is_colliding_radius(a,b,r)
	return (abs(a.x-b.x)+
	abs(a.y-b.y)) <= r
end

function closest_foe(ignored)
	local closest_foe = nil
	local closest_distance = 1000
	for foe in all(world.foes) do
		local skip = false
		if foe.is_dead then
			skip = true
		end
		for ignored_foe in all(ignored) do
			if foe == ignored_foe then
				skip = true
			end
		end
		if not skip then
			local distance = sqrt((player.x - foe.x)^2 + (player.y - foe.y)^2)
			if distance < closest_distance then
				closest_distance = distance
				closest_foe = foe
			end
		end
	end
	return closest_foe
end

function delay(frames)
	for i=1,frames do
		yield()
	end
end

function execute_actions()
	for c in all(actions) do
		if (not coresume(c)) del(actions,c)
	end
end

function decrease_btn_buffer()
	if btn_buffer > 0 then
		btn_buffer -= 1
	end
end

function set_btn_buffer(buffer)
	btn_buffer = buffer
end

function is_btn_ready()
	return btn_buffer == 0
end

function draw_logo()
	rectfill(16, 20, 112, 40, -11)
	spr(90, 38, 20, 6, 3)
end
-->8
-- engine

state_game = 0
state_main_menu = 1
state_lvl_up = 2
state_pause = 3
state_game_over = 4
state = state_main_menu

function _init()
	cls()
	cartdata("bootleg_survivor_dimillian")
	world:init()
	player:init()
	menu_main:init()
	music(0)
end

function _update60()
	decrease_btn_buffer()
	if state == state_main_menu then
		menu_main:update()
	elseif state == state_game then
		player:update()
		world:update(player)
		if btn(4) and is_btn_ready() then
			state = state_pause
			set_btn_buffer(15)
		end
	elseif state == state_lvl_up then
		menu_lvl_up:update()
	elseif state == state_pause then
		menu_pause:update()
		if btn(4) and is_btn_ready() then
			state = state_game
			set_btn_buffer(15)
		end
	elseif state == state_game_over then
		menu_game_over:update()
	end
	execute_actions()
end

function _draw()
	cls()
	if state == state_main_menu then
		camera(0, 0)
		menu_main:draw()
		return
	elseif state == state_game_over then
		camera(0, 0)
		menu_game_over:draw()
		return
	end
	camera(player.x-64, player.y-64)
	world:draw()
	player:draw()
	if state == state_lvl_up then
		menu_lvl_up:draw()
	elseif state == state_pause then
		menu_pause:draw()
	end
end

-->8
-- todo

-- spawn monster farther player
-- level up screen
-- main menu
-- pause menu wth stats
-- add chest + weapons drop

-- done: better player ui
-- done: proj dmg + monster health
-- done: dmg number on hit
__gfx__
00000000000655000006550000065500000888000005550000555000000555000055500000005eeeeee5000000005eeeeee50000000000000000000000000000
000000000006ff000006ff000aa6ff00000888000006660000666000000fff0000fff00000005eeeeee5000000005eeeeee50000000000000000000000000000
00700700008a4000008a400000844000008880000688aa6006aa886006a8846006488a6000000585585000000000055555500000000000000000000000000000
000770000084600008a4600000846000008880000f8888a00a8888f0064444f00f44446060066555555660060006658585566000000000000000000000000000
0007700000846f00088466f008846f0000888800004888f00f8884000f444400004444f016066657756660060006665555666000000000000000000000000000
00700700004400008844000008440000008800000048880040888400004444000044440416056666666660610005666776666000000000000000000000000000
00000000006660000066600000660400008880000066664000666604406666004066660001666566666566106666656666656660000000000000000000000000
00000000005050000400504040500000008080004050000004000500005000400000050000166566656661006116656665666116000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000166666666661006116666666666101000000000000000000000000
00000000000700000007000000666600000000000000000000000000000000000000000008016566566661080001656656666100000000000000000000000000
00000000007c7000007c700006444460000000000000000000000000000000000000000050016656666655508501665666665500000000000000000000000000
0000000000cac00000c8c00064444446000000000000000000000000000000000000000005555166116600050585516611660508000000000000000000000000
0000000000cac00000c8c00066611666000000000000000000000000000000000000000080005111001500800550511100150050000000000000000000000000
00000000000c0000000c0000644aa446000000000000000000000000000000000000000000005100001500008004510000150808000000000000000000000000
00000000000000000000000064444446000000000000000000000000000000000000000006451100001554500064410400155450000000000000000000000000
00000000001110000011100066666666000000000000000000000000000000000000000004541000001145600004040400114560000000000000000000000000
00000000000909000000000000000c00000c00800777700007777000100000010100001000400000000400000880000008800000000009000000090000000000
0000000000929290009090008000c0080800c0000787800607878000510000151511115144400000444000000808000088080000000086000000860000000000
00000000092222290929290000cccc0000cccc08077770600777700005111150508181054c4444044c44440000660000006600100008f6e00008f6e000000000
0000000092828290922222900cccccc00cccccc0007006000070060000181800001111004444444044444440005660000056660100088f0000088f0000000000
0000000009222229928282900c7cc7c00cccccc00077706040777666001111000070700080444400804444040556100005561111008ffff0008ffff000000000
0000000092222290922222900cccccc00c7c7cc0007000000070060000070700000000008040400000404000056601014566040100f8f00000f8f00000000000
00000000092929000929290007c88c7007cccc7007740000047700000000000000000000004044000040400006060011060600100fff000000ff880000000000
000000000090900000909000008888000088880004000400000400000111111001111110004400000040400005005001500500000f00f0000f00000000000000
00000000000500000000000000000000008cc8000000000000000000000000000000000000000000000000001b0000b100000000008000000000000000000000
0000000000656000008cc8000000000000caac0000000000000000000000000000000000000000000000000001b00b1000b00b00000080000000800800000800
000000000065600000caac00008cc80000caac00000000000000000000000000000000000000000000000000000440000b1441b0008000800080000000000000
000000000065600000caac0000caac00008cc8000000000000000000000000000000000000000000000000000084480001844810800088000000880000800000
0000000060656060008cc80000caac000000000000000000000000000000000000000000000000000000000000a88a0000888800088888000088808000000800
000000001608061000000000008cc80000555500000000000000000000000000000000000000000000000000008aa80000a88a00088888088088000000008000
00000000011411000055550000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000008000808000
00000000000800000000000000555500000000000000000000000000000000000000000000000000000000000111111001111110080000000808000000000000
333333333333333333355333333333333333333333333333333333333bbbbb834333333333333633333333333333333333333333333333333333333333333333
333333333333333333555533333633333333333333933333333333333b8bbbb34443333333333333333333333388333333333333333333333333331338338333
33333333333b333335555553333633333333333339893333333337333bbbb8b33344333363333633343334336383883333ccc333c3c333331311313333ccc333
3333333333bbbb333555555336666633333333333393333337337a733bb44bb33334433363333363543534533538345633ccc3333cc3333331133333338cc333
333333333b8bb8b335555553333633333333333333b33bb37a733b3338344333333343333633333334535435654433f63ccccc3333cccc3333cc1c333ccccc33
333333333bbbbb33355555533336333333b3b33333b33b333b33b3b333344333333344333633333334333433333883333cccccc3333ccc33331c11133cc8ccc3
3333333333bb8bb3366666633bb6bbb33b3bb33333bbbb3333bb3333333443333333344333633336343334333388333333cccc3333333cc333333c1333cc8c33
33333333333bbbb366666666bbb6bbbb333b333333333bb3333b3333333443333333334433663333343334333333833333333333333333cc333333cc33333333
33333333333333333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3333333333333333333ccc3300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
333333333333333333ccbccc0000000000000000000000000000000000000000000000000000000000bbb00bbbb00b000bb000bbb0b0000b00bb0b0bb0000000
333533333333336333cb2bcc000000000000000000000000000000000000000000000000000000008b00000b00b0b0b0b0000b0000b000b0b0bb0b0b0b000000
334333333333333333ccbccc000000000000000000000000000000000000000000000000000000008b00000b0b00bbb0b0000b0000b000bbb0b0bb0b00b00000
3333333333333333333cccc3000000000000000000000000000000000000000000000000000000008b00880bb000b0b00bb000bb80b000b0b0b0bb0b00b00000
3333335333333333333ccc33000000000000000000000000000000000000000000000000000000008b008b8b0b00b0b8008b0000b0b080b8b0b00b0b0b000000
3333333333333333333333330000000000000000000000000000000000000000000000000000000008bbb80b80b0b8b0bbbb8bbbb8bbb8b0b0b80b0bb8000000
33333333333333330000000000000000000000000000000000000000000000000000000000000000080808088088080880800800880808080880808808000000
33333333333333330000000000000000000000000000000000000000000000000000000000000000008080808800808008008880808880008008088080000000
35333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000080000080008000008000000800000000000
33433333333333330000000000000000000000000000000000000000000000000000000000000000000000000000080000000008000080000008000000000000
3333333333343333000000000000000000000000000000000000000000000000000000000000000000000000000000800000088000b880000008000000000000
33333353333333330000000000000000000000000000000000000000000000000000000000000000000000000bbb0b80b0bbb0b0b008b0b00bb88bbb00000000
33343d33333333330000000000000000000000000000000000000000000000000000000000000000000000000b000b00b0b0b8b0b0b0b0b0b00b0b0b00000000
333333333333333300000000000000000000000000000000000000000000000000000000000000000000000000bb0b08b0bb00b0b0b0b0b0b00b8bb000000000
3333333333333333000000000000000000000000000000000000000000000000000000000000000000000000880b0b80b0b0b0b0b0b0b0b0b00b0b0b00000000
34333333333333330000000000000000000000000000000000000000000000000000000000000000000000000bb008bb00b0b80b00b00b000bb00b0b00000000
33363333333333330000000000000000000000000000000000000000000000000000000000000000000000008888080880808000800880880800880000000000
33433333333333330000000000000000000000000000000000000000000000000000000000000000000000008008008008080888080008080808088800000000
33333353333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000008080000000000000
33333336333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333533333d33330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555000000000000000
0000000000000000555555555555555555555555bbb55bbbb55b555bb555bbb5b5555b55bb5b5bb5555555555555555555555555555555555000000000000000
000000000000000055555555555555555555558b55555b55b5b5b5b5555b5555b555b5b5bb5b5b5b555555555555555555555555555555555000000000000000
000000000000000055555555555555555555558b55555b5b55bbb5b5555b5555b555bbb5b5bb5b55b55555555555555555555555555555555000000000000000
000000000000000055555555555555555555558b55885bb555b5b55bb555bb85b555b5b5b5bb5b55b55555555555555555555555555555555000000000000000
000000000000000055555555555555555555558b558b8b5b55b5b8558b5555b5b585b8b5b55b5b5b555555555555555555555555555555555000000000000000
0000000000000000555555555555555555555558bbb85b85b5b8b5bbbb8bbbb8bbb8b5b5b85b5bb8555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555585858588588585885855855885858585885858858555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555558585858855858558558885858885558558588585555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555555585555585558555558555555855555555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555555585555555558555585555558555555555555555555555555555555555555555000000000000000
0000000000000000555555555555555555555555555555555555855555588555b885555558555555555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555bbb5b85b5bbb5b5b558b5b55bb88bbb55555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555b555b55b5b5b8b5b5b5b5b5b55b5b5b55555555555555555555555555555555555000000000000000
000000000000000055555555555555555555555555555555bb5b58b5bb55b5b5b5b5b5b55b8bb555555555555555555555555555555555555000000000000000
0000000000000000555555555555555555555555555555885b5b85b5b5b5b5b5b5b5b5b55b5b5b55555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555bb558bb55b5b85b55b55b555bb55b5b55555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555558888585885858555855885885855885555555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555558558558558585888585558585858588855555555555555555555555555555555555000000000000000
00000000000000005555555555555555555555555555555555555555555555585555558585555555555555555555555555555555555555555000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000006550000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000006ff000000008000c00800000000006666000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000084400000000000cccc0000000000064444600000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000008460000000000cccccc000000000644444460000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000008846f000000000c7cc7c000000000666116660000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000084400000000000cccccc000000000644aa4460000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000066040000000007c88c7000000000644444460000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000405000000000000088880000000000666666660000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000077777000000777007700000077077707770777077700000000000000000000000000000000000000000000000
00000000000000000000000000000000000000770707700000070070700000700007007070707007000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000777077700000070070700000777007007770770007000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000770707700000070070700000007007007070707007000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000077777000000070077000000770007007070707007000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000777070700000770077707770777070007000777077707700000000000000000000000000000000000000000000
00000000000000000000000000000000000000707070700000707007007770070070007000070070707070000000000000000000000000000000000000000000
00000000000000000000000000000000000000770077700000707007007070070070007000070077707070000000000000000000000000000000000000000000
00000000000000000000000000000000000000707000700000707007007070070070007000070070707070000000000000000000000000000000000000000000
00000000000000000000000000000000000000777077700000777077707070777077707770777070707070000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0003010103010101010000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
__sfx__
37010000007110372106731097310b7410e741107511275114751157611677118771197711a7711a7511c7511d7512175125751297512f75132751227012770130701377013a701317013a7013a7010070100701
000300000a352053520a352133520f3520f352183521b35216352183521d35224352223521b3521f3522735229352223521b352223522e35229352223521b352223522b3522e3523535235352353523c3523f352
170100001b5511b5511b5511b5511b5511b5511b5511b5511b5511b5511b5511b5511d5511f5512255122551275512b551335513c5513f5512c501325013450134501335012f5013350133501335013250130501
05020000355533555333553305532b553295532755327553225531f5531655313553115530c6530c65307653076530a6530a653076530365300653126030f6030e6030e6030e6030d6030a603086030660302603
00010000030000100001000030000500007000090000b0000d0001000014000160001b0001d00022000250002a0002e000300003300035000370003a0003f0000000000000000000000000000000000000000000
0001000020000210002200022000220002200022000220002200021000210001f0001e0001c0001a00019000170001500014000120001200011000100000f0000e0000d0000c0000b0000a000090000700006000
010500002c0002c00023000250002800025000210001c0001d0001f0002000022000220001c0001a0001c0001d00020000210002400027000220001c000250000f0000c00011000180002d000290002600022000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000021400212002010021400e12502010021400e120020150214002120020100214002120021100e040021250211002040021200211502040021200e110020450212002110021400202002110021400e125
011000000c5431b1001b1001b1000c04322100271000f5430c54329100291002b1000c04327100241000f5430c543291002e100301000c04333100331000f5430c5432910027100221000c04324100271000f543
011000001a7301a5121d7301d5120f7300f51216730165121a7301a5121d7301d512127301251214730145121a7301a5121d7301d5120f7300f51216730165121a7301a5121d7301d51218730185121a7301a512
011000001a0001a5121d0001d5120f0000f51216000165121a0001a5121d0001d512120001251214000145121a0001a5121d0001d5120f0000f51216000165121a0001a5121d0001d51218000185121a0001a512
31100000057000570007700077000f7001370016700167000f7000c7000c7000c7000f70013700187001d7001d7001d700187001370016700187001d7002270022700227001d7001b7001b7001f7002270022700
001000002e7522e7522e7522e7522e7522e7522e7522e7522b74224742227421f7421d7421d7422274224742297422975229752297522975229752297622776224762247622275222752227621f7722476229772
001000002e7522e7522e7522e7522e7522975227752277522e742307422e74229742227421d7421b7421d742227422775229752297522975227752227621d7621b7621b7621b7521d7521f7621d772167620f772
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 0a0b4c44
00 0d0b0a44
00 0a0b0c44
00 0a0c4f44
00 500a0b44
02 0b4a4344

