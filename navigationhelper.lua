function navigation_helper()
	local self = {
		target_menu_option = 0,
		delay_between_keypress = 0.3,
		delay_between_key_down_and_up = 0.1,
		debugging = false,
		resetting = false
	}
	
	local current_menu_option = 1
	local last_action_time = nil
	local next_action_type = ""
	local next_action_time = 0
	local next_action = ""
	local reset_delay = 2 -- hold left for 2 sec to reset position
	
	function self.reset_key_states()
		windower.send_command('setkey left up')
		windower.send_command('setkey enter up')
		windower.send_command('setkey down up')
		windower.send_command('setkey right up')
	end
	
	function self.reset_position()
		last_action_time = os.clock()
		current_menu_option = 0
		next_action = 'left'
		next_action_type = 'down'
		next_action_time = last_action_time + self.delay_between_keypress
		self.target_menu_option = 1
		resetting = true
	end
	
	function self.press_enter()
		last_action_time = os.clock()
		current_menu_option = 1
		self.target_menu_option = 1
		self.set_next_action()
	end
	
	function self.navigate_to_menu_option(option, override_delay, starting_position)
		if self.target_menu_option == 0 then 
			current_menu_option = starting_position or 1
			self.target_menu_option = option
			local delay = override_delay or 0
			last_action_time = os.clock() + delay
			self.set_next_action()
		end
	end
	
	function self.set_next_action()
		if current_menu_option < self.target_menu_option then
			if next_action_type == "" or next_action_type == "up" then
				next_action_type = "down"
				next_action_time = last_action_time + self.delay_between_keypress
				if self.target_menu_option - current_menu_option >= 3 then
					next_action = 'right'
				else
					next_action = 'down'
				end
			else
				next_action_type = 'up'
				if next_action == 'left' then 
					next_action_time = last_action_time + reset_delay
				else
					next_action_time = last_action_time + self.delay_between_key_down_and_up
				end
			end
		elseif current_menu_option == self.target_menu_option then
			if next_action_type == "" or next_action_type == "up" then 
				next_action = 'enter'
				next_action_type = 'down'
				next_action_time = last_action_time + self.delay_between_keypress
			else
				next_action_type = 'up'
				next_action_time = last_action_time + self.delay_between_key_down_and_up
			end
		end
		if self.debugging then 
			windower.add_to_chat(122, "Setting next action " .. next_action .. " " .. next_action_type .. " [" .. next_action_time .. "]")
		end
	end
	
	function self.update(time_now)
		if next_action_time <= time_now and self.target_menu_option > 0 then
			local command = "setkey " .. next_action .. " " .. next_action_type
			if next_action_type == 'up' then
				if next_action == 'enter' then self.target_menu_option = 0
				elseif	next_action == 'left' then 
					current_menu_option = 1
					self.target_menu_option = 0
					self.resetting = false
				elseif next_action == 'right' then current_menu_option = current_menu_option + 3
				elseif next_action == 'down' then current_menu_option = current_menu_option + 1
				end
			end
			if self.debugging then windower.add_to_chat(122, "[" .. time_now .. "] Sending setkey " .. command) end
			windower.send_command(command)
			last_action_time = time_now
			if self.target_menu_option > 0 then self.set_next_action() end
		end
	end
	
	return self
end