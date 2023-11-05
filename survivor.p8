pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- game & player
game = {
	name="grassland survivors",
	version="0.7.2"
}

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

		self.grace_delay=25
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

		self.storm_on = false
		self.storm_target = nil
		self.storm_radius = 0
		self.storm_radius_x = 0
		self.storm_delay = 150
		self.storm_counter = 0
		self.storm_delay_x = 0
		self.storm_damage = 5
		self.storm_sprite_top = nil
		self.storm_sprite_bottom = nil

		self.whip_on = false
		self.whip_delay = 100
		self.whip_delay_x = 0
		self.whip_radius = 10
		self.whip_damage = 2
		self.whip_counter = 0
		self.whip_sprite = 57
		self.whip_draw_left = false
		self.whip_draw_right = false
		self.whip_striking = false
		
		self.x=512
		self.y=256
		self.speed=0.5
		self.direction=0
		self.sprite_moving_routine = cocreate(self.update_sprite_routine)
		self.storm_routine = cocreate(self.storm_sprite_routine)
		self.whip_routine = cocreate(self.whip_sprite_routine)
	end,

	draw=function(self)
		self:draw_ui()
		self:draw_player()
		self:draw_proj()
		self:draw_swords()
		self:draw_storm()
		self:draw_whip()
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

	draw_storm=function(self)
		if self.storm_target then
			local t = self.storm_target
			local r = self.storm_radius
			circ(t.x + 1, t.y + 1, r, 7)
			if r > 4 then 
				circ(t.x + 1, t.y + 1, r - 4, 7)
			end
			if r > 8 then 
				circ(t.x + 1, t.y + 1, r - 8, 7)
			end
			if self.storm_sprite_bottom then
				spr(self.storm_sprite_bottom, t.x, t.y)
			end
			if self.storm_sprite_top then
				spr(self.storm_sprite_top, t.x, t.y - 8)
			end
		end
	end,
	
	draw_whip=function(self)
		local x = self.x
		local y = self.y
		local scale = ceil(self.whip_radius / 15)
		if self.whip_draw_left then
			draw_scaled_sprite_multi(self.whip_sprite, x - 8, y - ((scale - 1) * 4), scale,  1, 1)
		elseif self.whip_draw_right then
			draw_scaled_sprite_multi(self.whip_sprite + 1, x + 8, y - ((scale - 1) * 4), scale,  1, 1)
		end
	end,

	draw_ui=function(self)
		local x = self.x-64
		local y = self.y-64
		rectfill(x+3, y+4, x + 123, y + 6, 6)
		if self.xp > 0 then
			local xp_w = flr((self.xp / self.next_xp) * 123)
			rectfill(x+4, y+5, x + xp_w + 4, y + 5, 2)
		end
		print("lvl" .. player.level, x + 108, y + 2, 7)

		rectfill(x+3, y+9, x + 60, y + 11, 7)
		local hp_w = flr((self.health / self.max_health) * 59)
		rectfill(x+4, y+10, x + hp_w, y + 10, 8)
		print(self.health .. "/" .. self.max_health, x + 62, y + 9, 7)
		print("🐱 " .. self.kills ..  " ⧗ " .. flr(time()),  x + 4 ,y + 120, 7)
	end,

	update=function(self)
		self:update_movements()
		self:update_grace()
		self:update_level()
		self:update_proj()
		self:update_swords()
		self:update_storm()
		self:update_whip()
		self:update_sprite()
		self:update_health()
	end,

	update_movements=function(self)
		if btn(0) or btn(1) or btn(2) or btn(3) then
			self.is_moving=true
			local nx = self.x
			local ny = self.y
			if btn(0) then
				self.direction = 0
				nx -= self.speed
			elseif btn(1) then
				self.direction = 1
				nx += self.speed
			end

			if btn(2) then
				self.direction = 2
				ny -= self.speed
			elseif btn(3) then
				self.direction = 3
				ny += self.speed
			end
			local map_sprite = mget(flr(nx / 8), flr(ny / 8))
			if map_sprite != sprite_wall then
				self.x = nx
				self.y = ny
			end
		else
			self.is_moving=false
		end
	end,

	update_sprite=function(self)
		if costatus(self.sprite_moving_routine) != "dead" then
			coresume(self.sprite_moving_routine, self)
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
			self.next_xp = ceil(self.next_xp * 1.2)
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

	update_storm=function(self)
		if self.storm_on then
			self.storm_counter += 1
			if self.storm_counter >= (self.storm_delay - self.storm_delay_x) then
				self.storm_counter = 0
				local first_foe = closest_foe()
				local foe = closest_foe(first_foe)
				self.storm_target = foe
			end

			if self.storm_target then
				if costatus(self.storm_routine) != "dead" then
					coresume(self.storm_routine, self)
				end
			end
		end
	end,
	
	update_whip=function(self)
		if self.whip_on then
			self.whip_counter += 1
			if self.whip_counter >= (self.whip_delay - self.whip_delay_x) then
				self.whip_counter = 0
				self.whip_striking = true
			end
			
			if self.whip_striking then
				if costatus(self.whip_routine) != "dead" then
					coresume(self.whip_routine, self)
				end
			end
		end
	end,

	storm_sprite_routine=function(self)
		while true do
			sfx(sfx_storm_hit)
			self.storm_radius = self.storm_radius_x
			self.storm_sprite_top = 32
			delay(8)
			self.storm_sprite_bottom = 48		
			for i=0, 12 do
				self.storm_radius += 1
				delay(1)
			end
			self.storm_sprite_top = nil

			delay(8)
			self.storm_target:hit(self.storm_damage)
			world:hit_foes_radius(self.storm_target, self.storm_damage, self.storm_radius + 3)

			delay(4)
			self.storm_sprite_bottom = nil
			self.storm_target = nil
			self.storm_radius = 0
		end
	end,
	
	whip_sprite_routine=function(self)
		while true do
			self.whip_draw_left = true
			world:hit_foes_coord_radius(self.whip_damage, self.x - 8, self.y, self.whip_radius)
			delay(12)
			self.whip_draw_left = false
			self.whip_draw_right = true
			world:hit_foes_coord_radius(self.whip_damage, self.x + 8, self.y, self.whip_radius)
			delay(12)
			self.whip_striking = false
			self.whip_draw_right = false
			delay(1)
		end
	end,

	update_grace=function(self)
		if self.grace_on then
			self.grace_counter +=  1
		end
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
				if costatus(self.sprite_moving_routine) != "dead" then
					coresume(self.sprite_moving_routine, self)
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
		proj.sprite_moving_routine = cocreate(proj.update_sprite_routine)
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
				self.angle = (self.angle + speed) % (2 * pi)
			end,
			update=function(self)
			end
		}
		add(self.swords, sword)
		self:reset_swords_angle()
	end,
	
	reset_swords_angle=function(self)
		local angle_increment = 1 / #self.swords
		local radius = 12 + player.sword_radius_x
		local current_angle = 0
		for s in all(self.swords) do
   s.angle = current_angle 
   s.x = player.x + cos(current_angle) * radius
   s.y = player.y + sin(current_angle) * radius    
   current_angle = current_angle + angle_increment
		end
	end,

	hit_by_foe=function(self, foe)
		if self.grace_on and not foe.is_dead then
			return
		end
		sfx(sfx_player_hit)
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
-- world

world = {
	init=function(self)
		self.foes={}
		self.xp={}
		self.foes={}
		self.damages={}
		self.chests={}
		self.last_boss = 0
		self.foe_x = 20

		self.world_map = {
			base_sprite = {64, 64, 64, 64, 64, 64, 80, 96, 112, 81, 113, 97},
			things_sprite = {65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 82, 83, 84, 85, 86, 99},
			things_prob = 0.05,
		}

		self:gen_random_xp()
		self:gen_random_things()
		self:gen_walls()
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
		local spawn_max = 200
		local spawn = self.foe_x + (3 * player.level - 1)
		spawn = min(spawn, spawn_max)
		if #self.foes <= spawn then
			if player.kills > 0 and player.kills > self.last_boss and player.kills % boss_trigger == 0 then
				self.last_boss = player.kills
				self:add_foe(player, true)
			else
				self:add_foe(player, false)
			end
		end
	end,

	add_foe=function(self, player, is_boss)
		local base_speed = 0.15
		local speed = base_speed + (0.0010 * player.level)
		local xp = 1 * ceil(player.level / 4)
		local sprites = {33, 35, 37, 39, 41, 43, 45, 59}
		local sprite = flr(rnd(sprites))
		local health = ceil(1 * (player.level / 3))
		local sprite_size = 1
		
		local margin = 256
		local min_x = max(player.x - margin, sprite_size / 2)
		local max_x = min(player.x + margin, 1024 - sprite_size / 2)
		local min_y = max(player.y - margin, sprite_size / 2)
		local max_y = min(player.y + margin, 512 - sprite_size / 2)

		local x = min_x + flr(rnd(max_x - min_x))
		local y = min_y + flr(rnd(max_y - min_y))

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
			is_hit=false,
			hit_sprite=53,
			sprite_size=sprite_size,
			speed=speed,
			sword_immune_counter=0,
			init=function(self)
				self.sprite_moving_routine=cocreate(self.update_sprite_routine)
				self.sprite_death_routine=cocreate(self.play_death_routine)
				self.sprite_hit_routine=cocreate(self.hit_routine)
			end,
			draw=function(self)
				spr(self.sprite, self.x, self.y, self.sprite_size, self.sprite_size)
				if self.is_hit then
					spr(self.hit_sprite, self.x, self.y)
				end
			end,
			update=function(self, player)
				if not self.is_dead and is_colliding(self, player) then
					player:hit_by_foe(self)
				end

				self:update_position(player)
				self:update_health()
				self:update_sprite()
				if self.is_hit and costatus(self.sprite_hit_routine) != "dead" then
					coresume(self.sprite_hit_routine, self)
				end
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

			hit=function(self, damage)
				self.health -= damage
				world:add_damage(-damage, self.x + 2, self.y - 8)
				self.is_hit = true
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
						sfx(sfx_proj_hit)
						self:hit(proj.damage)
						proj.pierce_count = proj.pierce_count + 1
						if proj.pierce_count >= player.proj_max_pierce then
							del(player.proj, proj)
						end
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
							self:hit(dmg)
							self.sword_immune_counter = 15
							sfx(sfx_sword_hit)
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
				if costatus(self.sprite_moving_routine) != "dead" then
					coresume(self.sprite_moving_routine, self)
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

			hit_routine=function(self)
				while self.is_hit do
					self.hit_sprite = 53
					delay(3)
					self.hit_sprite = 54
					delay(3)
					self.hit_sprite = 55
					delay(3)
					self.is_hit = false
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
				if mget(self.x / 8, self.y / 8) == sprite_base then
					local splatters = {114, 115, 116}
					mset(self.x / 8, self.y / 8, rnd(splatters))
				end
				del(world.foes, self)
			end
		}
		foe:init()
		add(self.foes, foe)
	end,

	add_xp=function(self, x, y, value, is_foe)
		local sprite = 17
		local is_collector = false
		if is_foe then
			if flr(rnd(200)) == 0 then
				is_collector = true
			end
			if is_collector then
				sprite = 16
			else
				sprite = 18
			end
		end
		local xp = {
			x = flr(x),
			y = flr(y),
			speed=0.7,
			is_agro=false,
			is_collector=is_collector,
			value = ceil(value),
			sprite = sprite,
			draw=function(self)
				spr(self.sprite, self.x, self.y)
			end,
			update=function(self, player)
				if is_colliding_radius(self, player, player.xp_radius) then
					self.is_agro=true
				end
				if is_colliding(self, player) then
					if self.is_collector then
						for xp in all(world.xp) do
							xp.is_agro = true
						end
					else
						player:collect_xp(self.value)
					end
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
	
	hit_foes_radius=function(self, target, damage, radius)
		for foe in all(self.foes) do
			local dx = foe.x - target.x
			local dy = foe.y - target.y
			local distance = sqrt(dx*dx + dy*dy)
			if distance <= radius then
				foe:hit(damage)
			end
		end
	end,
	
	hit_foes_coord_radius=function(self, damage, x, y, radius)
		for foe in all(self.foes) do
			local dx = foe.x - x
			local dy = foe.y - y
			local distance = sqrt(dx*dx + dy*dy)
			if distance <= radius then
				foe:hit(damage)
			end
		end
	end,

	gen_random_xp=function(self)
		for i=1, 256 do
			self:add_xp(rnd(1024), rnd(512), rnd(2), false)
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
	end,

	gen_walls=function(self)
		for y=0,64do
		for x=0,128 do
			if x == 0 or y == 0 or x == 127 or y == 63 then
				mset(x, y, sprite_wall)
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
	storm_options_added = false,
	whip_options_added = false,

	sword_options = {
		{target="sword", name="radius", subtitle="+2% sword radius", sprite=49},
		{target="sword", name="speed", subtitle="+3% sword speed", sprite=49},
		{target="sword", name="dmg", subtitle="+1 sword damage", sprite=49},
	},

	storm_options = {
		{target="storm", name="delay", subtitle="-10% storm delay", sprite=32},
		{target="storm", name="dmg", subtitle="+1 storm dmg", sprite=32},
		{target="storm", name="radius", subtitle="%10% storm radius", sprite=32},
	},
	
	whip_options = {
		{target="whip", name="delay", subtitle="-10% whip delay", sprite=56},
		{target="whip", name="dmg", subtitle="+1 whip dmg", sprite=56},
		{target="whip", name="radius", subtitle="%10% whip radius", sprite=56},
	},

	init=function(self)
		self.choices = {
			{target="player", name="speed", subtitle="+15% move speed",  sprite=1},
			{target="player", name="health", subtitle="+5 hp", sprite=1},
			{target="player", name="radius", subtitle="+4% xp radius", sprite=17},
			{target="proj", name="speed", subtitle="+2% projectile speed", sprite=50},
			{target="proj", name="dmg", subtitle="+1 projectile damage", sprite=50},
			{target="proj", name="delay", subtitle="-5% projectile delay", sprite=50},
			{target="proj", name="count", subtitle="+1 projectile fired", sprite=50},
			{target="proj", name="pierce", subtitle="+1 projectile pierce", sprite=50},
			{target="sword", name="count", subtitle="+1 spinning sword", sprite=49},
			{target="storm", name="storm", subtitle="regularly call a storm", sprite=32},
			{target="world", name="curse", subtitle="+20% monsters spawn", sprite=21},
			{target="whip", name="whip", subtitle="add a whip sriking both sides", sprite=56},
		}
	end,

	draw=function(self)
		local menu_width=128
		local menu_height=90
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
		local _option = {}
		for index, option in pairs(self.options) do
			self:draw_option(base_x, base_y , option, index == self.selected)
			if index == self.selected then
				_option = option
			end
			base_x += 46
		end
		print(_option.name, x0 + 8, y1 - 35, 7)
		print(_option.subtitle, x0 + 8, y1 - 27, 6)
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
	end,

	update=function(self)
		if #player.swords > 0 and not self.sword_options_added then
			self.sword_options_added = true
			for option in all(self.sword_options) do
				add(self.choices, option)
			end
		end
		if player.storm_on and not self.storm_options_added then
			self.storm_options_added = true
			for option in all(self.storm_options) do
				add(self.choices, option)
			end

			for option in all(self.choices) do
				if option.target == "storm" and option.name == "storm" then
					del(self.choices, option)
				end
			end
		end
	
		if player.whip_on and not self.whip_options_added then
			self.whip_options_added = true
			for option in all(self.whip_options) do
				add(self.choices, option)
			end

			for option in all(self.choices) do
				if option.target == "whip" and option.name == "whip" then
					del(self.choices, option)
				end
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
			set_btn_buffer(10)
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
			elseif option.name == "delay" and player.proj_delay_x < 90 then
				player.proj_delay_x += 5
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
		elseif option.target == "storm" then
			if option.name == "storm" then
				player.storm_on = true
			elseif option.name == "delay" and player.storm_delay_x < 80 then
				player.storm_delay_x += 5
			elseif option.name == "dmg" then
				player.storm_damage += 1
			elseif option.name == "radius" then
				player.storm_radius_x += 1
			end
		elseif option.target == "whip" then
			if option.name == "whip" then
				player.whip_on = true
			elseif option.name == "delay" and player.storm_delay_x < 80 then
				player.whip_delay_x += 5
			elseif option.name == "dmg" then
				player.whip_damage += 1
			elseif option.name == "radius" then
				player.whip_radius += 1
			end
		elseif option.target == "world" then
			if option.name == "curse" then
				world.foe_x += 2
			end
		end
		player.health = player.max_health
		self.options = nil
		state = state_game
	end
}

menu_pause = {
	state = {
		proj = 0, 
		sword = 1,
		storm = 2,
		whip = 3,
	},
	
	selected_state = 0,
	
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
		if self.selected_state == self.state.proj then
			self:draw_proj_state(x0, py)
			spr(49, x0 + 115, py + 14)
			print(">", x0 + 124, py + 15)
		elseif self.selected_state == self.state.sword then
			spr(50, x0 + 4, py + 14)
			print("<", x0 + 1, py + 15)
			self:draw_sword_state(x0, py)
			spr(32, x0 + 115, py + 14)
			print(">", x0 + 124, py + 15)
		elseif self.selected_state == self.state.storm then
			spr(49, x0 + 4, py + 14)
			print("<", x0 + 1, py + 15)
			self:draw_storm_state(x0, py)
			spr(56, x0 + 115, py + 14)
			print(">", x0 + 124, py + 15)
		elseif self.selected_state == self.state.whip then
			spr(32, x0 + 4, py + 14)
			print("<", x0 + 1, py + 15)
			self:draw_whip_state(x0, py)
		end
		print("🅾️ to resume", x0 + 40, y1 - 12, 7)
		line(x0, y1, x0 + menu_width, y1, 7)
	end,
	
	draw_proj_state=function(self, x0, py)
		spr(50, x0 + 8, py)
		print("speed:" .. 0.8 + player.proj_speed_x, x0 + 18, py - 4)
		print("dmg:" .. player.proj_damage_x, x0 + 18, py + 4)
		print("delay:" .. flr(player.proj_delay - player.proj_delay_x), x0 + 60, py - 4)
		print("count:" .. player.proj_count, x0 + 44, py + 4)
		print("pierce:" .. player.proj_max_pierce, x0 + 76, py + 4)
	end,
	
	draw_sword_state=function(self, x0, py)
		spr(49, x0 + 8, py)
		print("speed:" .. 0.8 + player.sword_speed_x, x0 + 18, py - 4)
		print("dmg:" .. 1 + player.sword_attack_x, x0 + 18, py + 4)
		print("radius:" .. 12 + player.sword_radius_x, x0 + 70, py - 4)
		print("count:" .. #player.swords, x0 + 44, py + 4)
	end,
	
	draw_storm_state=function(self, x0, py)
		spr(32, x0 + 8, py)
		print("delay:" .. flr(player.storm_delay - player.storm_delay_x), x0 + 18, py - 4)
		print("dmg:" .. player.storm_damage, x0 + 18, py + 4)
		print("radius:" .. 12 + player.storm_radius_x, x0 + 70, py - 4)
	end,
	
	draw_whip_state=function(self, x0, py)
		spr(56, x0 + 8, py)
		print("delay:" .. flr(player.whip_delay - player.whip_delay_x), x0 + 18, py - 4)
		print("dmg:" .. player.whip_damage, x0 + 18, py + 4)
		print("radius:" .. player.whip_radius, x0 + 70, py - 4)
	end,
	
	update=function(self)
		decrease_btn_buffer()
		if is_btn_ready() then
			if btn(0) then
				if self.selected_state > self.state.proj then
					self.selected_state -= 1
					set_btn_buffer(20)
				end
			end
			if btn(1) then
				if self.selected_state < self.state.whip then
					self.selected_state += 1
							set_btn_buffer(20)
				end
			end
		end
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
		line(16, 100, 112, 100, -15)
		print("v:" .. game.version .. " by dimillian", 30, 110, 7)
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
			init_game()
			state = state_game
		end
	end
}
-->8
-- helpers

// sfx
sfx_xp=0
sfx_level_up=1
sfx_proj=2
sfx_foe_death=3
sfx_sword_hit=4
sfx_player_hit=5
sfx_storm_hit=6
sfx_proj_hit=7

// sprites
sprite_wall=98
sprite_base=64

pi = 3.14159265

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
	rectfill(0, 8, 128, 53, -15)
	draw_scaled_sprite_multi(90, 18, 8, 2,  6, 3)
end

function draw_scaled_sprite_multi(spr_num, x, y, scale, width, height)
	local start_spr_x = spr_num % 16
	local start_spr_y = flr(spr_num / 16)

	for cell_x = 0, width - 1 do
		for cell_y = 0, height - 1 do
			local cell_spr_num = (start_spr_y + cell_y) * 16 + (start_spr_x + cell_x)
			for spr_x = 0, 7 do
				for spr_y = 0, 7 do
					local col = sget(cell_spr_num % 16 * 8 + spr_x, flr(cell_spr_num / 16) * 8 + spr_y)
					if col ~= 0 then
						rectfill(
						x + (cell_x * 8 + spr_x) * scale,
						y + (cell_y * 8 + spr_y) * scale,
						x + (cell_x * 8 + spr_x) * scale + scale - 1,
						y + (cell_y * 8 + spr_y) * scale + scale - 1,
						col)
					end
				end
			end
		end
	end
end

function outline_sprite(n,col_outline,x,y,w,h,flip_x,flip_y)
  -- reset palette to black
  for c=1,15 do
    pal(c,col_outline)
  end
  -- draw outline
  for xx=-1,1 do
    for yy=-1,1 do
      spr(n,x+xx,y+yy,w,h,flip_x,flip_y)
    end
  end
  -- reset palette
  pal()
  -- draw final sprite
  spr(n,x,y,w,h,flip_x,flip_y)	
end





-->8
-- engine

state_game = 0
state_main_menu = 1
state_lvl_up = 2
state_pause = 3
state_game_over = 4
state = state_main_menu

function init_game()
	world:init()
	player:init()
	menu_main:init()
	menu_lvl_up:init()
end

function _init()
	cls()
	cartdata("bootleg_survivor_dimillian")
	music(0)
	init_game()
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
-- spawn group of monsters at random locations
-- avoid monsters collapsing into each other
-- add more weapons
-- better music

-- done: better player ui
-- done: proj dmg + monster health
-- done: dmg number on hit
-- done: chest + sword weapon
-- done: main menu and pause menu
-- done: collision effect on monster hit
__gfx__
00000000000655000006550000065500000888000055500000555000005550000055500000005eeeeee5000000005eeeeee50000000000000000000000000000
000000000006ff000006ff000aa6ff0000088800006660000066600000fff00000fff00000005eeeeee5000000005eeeeee50000000000000000000000000000
00700700008a4000008a40000084400000888000068aa60006aa860006a886000688960000000585585000000000055555500000000000000000000000000000
000770000084600008a4600000846000008880000f888a000a888f0006444f000f44460060066555555660060006658585566000000000000000000000000000
0007700000846f00088466f008846f000088880008884f040f4888000f44480408444f0016066657756660060006665555666000000000000000000000000000
00700700004400008844000008440000008800000884400040448800004448000844400416056666666660610005666776666000000000000000000000000000
00000000006660000066600000660400008880000066600000666044006660004066600001666566666566106666656666656660000000000000000000000000
00000000005050000400504040500000008080004050004004005000405004000000500000166566656661006116656665666116000000000000000000000000
00aaaa00000000000000000000000000006666000777777000000000000000000000000000166666666661006116666666666101000000000000000000000000
0acccca00007000000070000006666000a0000a07000000700000000000000000000000008016566566661080001656656666100000000000000000000000000
acc88cca007c7000007c70000644446060a00a067080080700000000000000000000000050016656666655508501665666665500000000000000000000000000
ac8cc8ca00cac00000c8c00064444446600990067080080700000000000000000000000005555166116600050585516611660508000000000000000000000000
ac8cc8ca00cac00000c8c00066611666600990067000000700000000000000000000000080005111001500800550511100150050000000000000000000000000
ac5cc5ca000c0000000c0000644aa44660a00a060700007000000000000000000000000000005100001500008004510000150808000000000000000000000000
0acccca00000000000000000644444460a0000a00707707000000000000000000000000006451100001554500064410400155450000000000000000000000000
00aaaa00001110000011100066666666006886000070070000000000000000000000000004541000001145600004040400114560000000000000000000000000
15515515000909000000000000000c00000c00800777700007777000100000010100001009290000099290000880000008800000000999900000999000000000
1115515100929290009090008000c0080800c0000787800907878000910000191911119192299990922999000808000088080000009986900099869000000000
050a0105092222290929290000cccc0000cccc08077770900777700009111190908181099c2222909c2222900066000000660090009826e0009826e000000000
0000a00092828290922222900cccccc00cccccc00070090000700900001818000011110092222229822222290056600000566609099882990998829000000000
00900a0009222229928282900c9cc9c00cccccc00077709040777999001111000070700008222292092222900556900005569999098222290982222900000000
0000a00092222290922222900cccccc00c9c9cc00070000000700900000707000000000008292909092929000566090945660409092829900928299900000000
000a0000092929000929290009c88c9009cccc900774000004770000000000000000000009292290092929000606009906060090922299000922229000000000
00a00900009090000090900000888800008888000400040000040000011111100111111009229900092929000500500950050000929929009299999000000000
090a0000000500000000000000000000008cc8000000000000000000000000000444440000000000000000001b0000b100009090008000000000000000000000
00a0000000656000008cc8000000000000caac0007700770070000700000000040000040000000777777000001b00b1090b00b00000080000000800800000800
000a09000065600000caac00008cc80000caac00007007000070070000700700408840400777770000007700090440000b1441b0008000800080000000000000
0900a0000065600000caac0000caac00008cc8000000000000000000000000004000404077000000000007700084480001844810800088000000880000800000
00000a0060656060008cc80000caac000000000000000000000000000000000004440040770000000000007000a88a0000888800088888000088808000000800
0400a0041608061000000000008cc80000555500007007000070070000700700000000400770000000000770008aa80990a88a09088888088088000000008000
400a0040011411000055550000000000000000000770077007000070000000000664440000077777777770000000000000000000000008000000008000808000
04a04000000800000000000000555500000000000000000000000000000000000000000000000000000000000111111001111110080000000808000000000000
3333333333333333333553333333333333333333333334333333333333bbbb334333333333333633333333333333333333333333333333333333333333333333
333333333333333333555533333633d33d33333333933333333333333b8bbbb34443333333333333333333333388333333333333333336333333331338338333
33333333333b33333555555333363333333333333989334333d337333bbbb8b3334433d363333633343334336383883333ccc333c3c333331311313333ccc333
3333333333bbbb33355555533666663333333d333393333337337a733bb44b333334433363333363543534533538345633ccc3333cc3333331133333338cc333
333333333b8bb8b335555553333633333333333333b33bb37a733b3338344333333343333633333334535435654433f63ccccc3333cccc3333cc1c333ccccc33
333333333bbbbb33355555533336333333b3b33333b33b333b33b3b3333b4353333344333633333334333433333883333cccccc3333ccc33331c11133cc8ccc3
3333333333bb8bb3366666633bb6bbb33b3bb33333bbbb3333bb33333334b3333333344333633336343334333388333333cccc3336333cc333333c1333cc8c33
33333333333bbbb366666666bbb6bbbb333b333333333bb3333b333333344b333333334433663333343334333333833333333333333333cc333333cc33333333
333333333333333333333333333bb333333353333335333333333333000000000000000000000000000000000000000000000000000000000000000000000000
3333333333333333333ccc3333bbbb33333555333355533333333333000000000000000000000000000000000000000000000000000000000000000000000000
333333333333333333ccbccc3bbb4bb336445463334544333333313300000000000000000000000000bbb00bbbb00b000bb000bbb0b0000b00bb0b0bb0000000
333533333333336333cb2bcc3b4bb4b33644546333454433333319130000000000000000000000008b00000b00b0b0b0b0000b0000b000b0b0bb0b0b0b000000
334333333333333333ccbcccb4bbbbbb364644634346643333933b330000000000000000000000008b00000b0b00bbb0b0000b0000b000bbb0b0bb0b00b00000
3333333333333333333cccc3bbbbbbbb3644646334488643b919b3330000000000000000000000008b00880bb000b0b00bb000bb80b000b0b0b0bb0b00b00000
3333335333333333333ccc333334433336444463444688433b333b330000000000000000000000008b008b8b0b00b0b8008b0000b0b080b8b0b00b0b0b000000
33333333333333333333333333344333366666633443334333b3b33300000000000000000000000008bbb80b80b0b8b0bbbb8bbbb8bbb8b0b0b80b0bb8000000
33333333333333337555555733333333000000000000000000000000000000000000000000000000080808088088080880800800880808080880808808000000
3333333333333333675555763333b333000000000000000000000000000000000000000000000000008080808800808008008880808880008008088080000000
353333333333333366755766333b3b33000000000000000000000000000000000000000000000000000000000000080000080008000008000000800080000000
3343333333333333664444663333b333000000000000000000000000000000000000000000000000000000000000080000000008000080000008000000000000
33333333333433336644446633b333b300000000000000000000000000000000000000000000000000000000000000800000088000b880000008000008080000
3333335333333333667557663b3b3b3b000000000000000000000000000000000000000000000000000000000bbb0b80b0bbb0b0b008b0b00bb88bbb0bbb0000
33343d33333333336755557633b333b3000000000000000000000000000000000000000000000000000000000b000b00b0b0b8b0b0b0b0b0b00b0b0b0b000000
333333333333333375555557333333330000000000000000000000000000000000000000000000000000000000bb0b08b0bb00b0b0b0b0b0b00b8bb00bbb0000
3333333333333333333333333333333333333333000000000000000000000000000000000000000000000000880b0b80b0b0b0b0b0b0b0b0b00b0b0b008b0000
34333333333333333333333333333333333333330000000000000000000000000000000000000000000000000bb008bb00b0b80b00b00b000bb00b0b0bb00000
33363333333333333333838333333333333333330000000000000000000000000000000000000000000000008888080880808000800880880800880000800000
33433333333333333333333333838333333338330000000000000000000000000000000000000000000000008008008008080888080008080808088888880000
33333353333333333383333333383333338383330000000000000000000000000000000000000000000000000000000000000000080000008080000000000000
33333336333333333333383333333333333338330000000000000000000000000000000000000000000000000000000000000000000000000000000000800000
33333533333d33333833333333333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111bbbbbb1111bbbbbbbb1111bb111111bbbb111111bbbbbb11bb11111111bb1111bbbb11bb11bbbb1111111111111111111111111111
1111111111111111111111bbbbbb1111bbbbbbbb1111bb111111bbbb111111bbbbbb11bb11111111bb1111bbbb11bb11bbbb1111111111111111111111111111
11111111111111111188bb1111111111bb1111bb11bb11bb11bb11111111bb11111111bb111111bb11bb11bbbb11bb11bb11bb11111111111111111111111111
11111111111111111188bb1111111111bb1111bb11bb11bb11bb11111111bb11111111bb111111bb11bb11bbbb11bb11bb11bb11111111111111111111111111
11111111111111111188bb1111111111bb11bb1111bbbbbb11bb11111111bb11111111bb111111bbbbbb11bb11bbbb11bb1111bb111111111111111111111111
11111111111111111188bb1111111111bb11bb1111bbbbbb11bb11111111bb11111111bb111111bbbbbb11bb11bbbb11bb1111bb111111111111111111111111
11111111111111111188bb1111888811bbbb111111bb11bb1111bbbb111111bbbb8811bb111111bb11bb11bb11bbbb11bb1111bb111111111111111111111111
11111111111111111188bb1111888811bbbb111111bb11bb1111bbbb111111bbbb8811bb111111bb11bb11bb11bbbb11bb1111bb111111111111111111111111
11111111111111111188bb111188bb88bb11bb1111bb11bb88111188bb11111111bb11bb118811bb88bb11bb1111bb11bb11bb11111111111111111111111111
11111111111111111188bb111188bb88bb11bb1111bb11bb88111188bb11111111bb11bb118811bb88bb11bb1111bb11bb11bb11111111111111111111111111
1111111111111111111188bbbbbb8811bb8811bb11bb88bb11bbbbbbbb88bbbbbbbb88bbbbbb88bb11bb11bb8811bb11bbbb8811111111111111111111111111
1111111111111111111188bbbbbb8811bb8811bb11bb88bb11bbbbbbbb88bbbbbbbb88bbbbbb88bb11bb11bb8811bb11bbbb8811111111111111111111111111
11111111111111111111881188118811888811888811881188881188111188111188881188118811881188881188118888118811111111111111111111111111
11111111111111111111881188118811888811888811881188881188111188111188881188118811881188881188118888118811111111111111111111111111
11111111111111111111118811881188118888111188118811118811118888881188118888881111118811118811888811881111111111111111111111111111
11111111111111111111118811881188118888111188118811118811118888881188118888881111118811118811888811881111111111111111111111111111
11111111111111111111111111111111111111111111881111111111881111118811111111118811111111111188111111881111111111111111111111111111
11111111111111111111111111111111111111111111881111111111881111118811111111118811111111111188111111881111111111111111111111111111
11111111111111111111111111111111111111111111881111111111111111118811111111881111111111118811111111111111111111111111111111111111
11111111111111111111111111111111111111111111881111111111111111118811111111881111111111118811111111111111111111111111111111111111
1111111111111111111111111111111111111111111111881111111111118888111111bb88881111111111118811111111118811881111111111111111111111
1111111111111111111111111111111111111111111111881111111111118888111111bb88881111111111118811111111118811881111111111111111111111
111111111111111111111111111111111111bbbbbb11bb8811bb11bbbbbb11bb11bb111188bb11bb1111bbbb8888bbbbbb11bbbbbb1111111111111111111111
111111111111111111111111111111111111bbbbbb11bb8811bb11bbbbbb11bb11bb111188bb11bb1111bbbb8888bbbbbb11bbbbbb1111111111111111111111
111111111111111111111111111111111111bb111111bb1111bb11bb11bb88bb11bb11bb11bb11bb11bb1111bb11bb11bb11bb11111111111111111111111111
111111111111111111111111111111111111bb111111bb1111bb11bb11bb88bb11bb11bb11bb11bb11bb1111bb11bb11bb11bb11111111111111111111111111
11111111111111111111111111111111111111bbbb11bb1188bb11bbbb1111bb11bb11bb11bb11bb11bb1111bb88bbbb1111bbbbbb1111111111111111111111
11111111111111111111111111111111111111bbbb11bb1188bb11bbbb1111bb11bb11bb11bb11bb11bb1111bb88bbbb1111bbbbbb1111111111111111111111
1111111111111111111111111111111111888811bb11bb8811bb11bb11bb11bb11bb11bb11bb11bb11bb1111bb11bb11bb111188bb1111111111111111111111
1111111111111111111111111111111111888811bb11bb8811bb11bb11bb11bb11bb11bb11bb11bb11bb1111bb11bb11bb111188bb1111111111111111111111
111111111111111111111111111111111111bbbb111188bbbb1111bb11bb8811bb1111bb1111bb111111bbbb1111bb11bb11bbbb111111111111111111111111
111111111111111111111111111111111111bbbb111188bbbb1111bb11bb8811bb1111bb1111bb111111bbbb1111bb11bb11bbbb111111111111111111111111
11111111111111111111111111111111118888888811881188881188118811111188111188881188881188111188881111111188111111111111111111111111
11111111111111111111111111111111118888888811881188881188118811111188111188881188881188111188881111111188111111111111111111111111
11111111111111111111111111111111118811118811118811118811881188888811881111118811881188118811888888888888881111111111111111111111
11111111111111111111111111111111118811118811118811118811881188888811881111118811881188118811888888888888881111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111881111111111118811881111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111881111111111118811881111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111188111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111188111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000065500000000000c008000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000006ff000000000800c00000000000006666000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000008a400000000000cccc0800000000064444600000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000008a460000000000cccccc000000000644444460000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000088466f00000000cccccc000000000666116660000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000884400000000000c7c7cc000000000644aa4460000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000066600000000007cccc7000000000644444460000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000040050400000000088880000000000666666660000000000000000000000000000000000000000000000000000
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
00000000000000001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000070700000777000007000000077700000777070700000770077707770777070007000777077707700000000000000000000
00000000000000000000000000000070700700707000007000000070000000707070700000707007007770070070007000070070707070000000000000000000
00000000000000000000000000000070700000707000007770000077700000770077700000707007007070070070007000070077707070000000000000000000
00000000000000000000000000000077700700707000007070000000700000707000700000707007007070070070007000070070707070000000000000000000
00000000000000000000000000000007000000777007007770070077700000777077700000777077707070777077707770777070707070000000000000000000
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
0003010103000100010000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
36010000007110372106731097310b7410e741107511275114751157611677118771197711a7711a7511c7511d7512175125751297512f75132751227012770130701377013a701317013a7013a7010070100701
000300000a752057520a752137520f7520f752187521b75216752187521d75224752227521b7521f7522775229752227521b752227522e75229752227521b752227522b7522e7523575235752357523c7523f752
16010000035150352505535075350a5350f54513545165551b5651f5752457527575235752550527505295052b5052d5052f505355053a5052c505325053450534505335052f5053350533505335053250530505
04020000355533555333553305532b553295532755327553225531f5531655313553115530c6530c65307653076530a6530a653076530365300653126030f6030e6030e6030e6030d6030a603086030660302603
360100003c5513c5513c5513a5513a55137551355512e5512e5512e5512e551335513a5513f5513f5513f5512b50122501185011350111501135012e5012e5012e50100501005010050100501005010050100501
260100002235124351293512b35130351373513f3513c3512e3512e351333513c3513f351333512b35130351353513c3513f35130351373513c3513f3510f3010e3010d3010c3010b3010a301093010730106301
2702000020154241542d154321542e15433154361543c1543f1543f1542f15424154371542b1541a154101541815427154311542c154021540c1540b1540a1540f1040c10411104181042d104291042610422104
170100002f5573a5573f5573f557375573b5573f5572d55736557385573c5573c5573c5573e5573f5570050700507005070050700507005070050700507005070050700507005070050700507005070050700507
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000021400212002010021400e12502010021400e120020150214002120020100214002120021100e040021250211002040021200211502040021200e110020450212002110021400202002110021400e125
011000000c5431b1001b1001b1000c04322100271000f5430c54329100291002b1000c04327100241000f5430c543291002e100301000c04333100331000f5430c5432910027100221000c04324100271000f543
011000001a7301a5121d7301d5120f7300f51216730165121a7301a5121d7301d512127301251214730145121a7301a5121d7301d5120f7300f51216730165121a7301a5121d7301d51218730185121a7301a512
011000001a0001a5121d0001d5120f0000f51216000165121a0001a5121d0001d512120001251214000145121a0001a5121d0001d5120f0000f51216000165121a0001a5121d0001d51218000185121a0001a512
d01000001a0001a0001a5121d0001d5120f0000f51216000165121a0001a5121d0001d512120001251214000145121a0001a5121d0001d5120f0000f51216000165121a0001a5121d0001d51218000185121a000
001000001673016512147301451212730125120f7300f5120d7300d51212730125120f7300f5120d7300d5121673016512147301451212730125120f7300f5120d7300d51212730125120f7300f5120d7300d512
681000001f7301f5121d7301d5121c7301c5121a7301a51212730125120f7300f5120d7300d5120f7300f5121f7301f5121d7301d5121c7301c5121a7301a51218730185121a7301a5121c7301c5121d7301d512
001000000f7300f5121a7301a51218730185121a7301a5121d7301d5121f7301f5120d7300d5120f7300f5120f7300f5121a7301a51218730185121a7301a5121d7301d5121f7301f5120d7300d5120f7300f512
11100000062300622007232082320d2220d2300d2320d22218230182220f2320f2300f2320f222062300623006232062222421024230242321d2301d2301d23218230182321c2321c2301c2321a2321a2301a230
111000000e2300e2301023210230102320c2300c232112301123011232122301222013232142320d2220d2300d2320d2220c2300c2220f2320f2300f2320f222122301223010231102320e2310e2320c2310c232
__music__
01 0a0b4c44
00 0d0b0a44
00 0a0b0c0e
00 0a0c4f44
00 0e0a0b44
00 0b0e0f52
00 0b4a1044
00 0a0d5244
00 0a0d5344
00 0a0b4344
02 0b424344

