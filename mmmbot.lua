_addon.name = 'Mandragora Mania Madness Bot'
_addon.author = 'Dabidobido'
_addon.version = '1.2.5'
_addon.commands = {'mmmbot'}

packets = require('packets')
require('functions')
require('logger')
socket = require('socket')
require('navigationhelper')

local navigation_helper = navigation_helper()
debugging = false
player_action_started = false
player_action_start_time = 0
need_to_reset = false

npc_ids = 
{
	[230] = { npc_id = 17719722, menu_id = 3631, game_menu_id = 3633 }, -- Southern Sandoria
	[235] = { npc_id = 17740023, menu_id = 690, game_menu_id = 692 }, -- Bastok Mines
	[238] = { npc_id = 17752429, menu_id = 1170, game_menu_id = 1172 }, -- Windurst Waters
}

option_indexes =
{
	[1] = 3,
	[2] = 515,
	[3] = 1027,
	[4] = 1539,
	[5] = 2051,
	[6] = 2563,
	[7] = 3075,
	[8] = 3587,
	[9] = 4099,
	[10] = 4611,
	[11] = 5123,
	[12] = 5635,
	[13] = 6147,
	[14] = 6659,
	[15] = 7171,
	[16] = 7683,
}

quit_option_index = 5
buy_key = 0
buy_key_fo_option_index = 6
interact_distance_square = 5*5
npc_index = 0

zone = nil -- get zone from the incoming and use it for outgoing

game_state = 0 -- 0 = init, 1 = started, 2 = finished
player_turn = false -- it's random who goes first
game_board = { -- 0 = empty, 1 = player, 10 = enemy
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 0,
	[8] = 0,
	[9] = 0,
	[10] = 0,
	[11] = 0,
	[12] = 0,
	[13] = 0,
	[14] = 0,
	[15] = 0,
	[16] = 0,
}
current_zone_id = 0
started = false
game_started_time = 0
last_board_update = 0
opponent_move_time = 0

windower.register_event('addon command', function(...)
	local args = {...}
	if args[1] == "debug" then
		if args[2] and args[2] == "nav" then
			navigation_helper.debugging = not navigation_helper.debugging
			notice("Navigation Debug output: " .. tostring(navigation_helper.debugging))
		else
			debugging = not debugging
			notice("Debug output: " ..tostring(debugging))
		end
	elseif args[1] == "start" then
		started = true
		math.randomseed(os.clock())
		notice("Started")
	elseif args[1] == "stop" then
		started = false
		game_state = 2
		reset_state()
		notice("Stopping.")
	elseif args[1] == "setdelay" and args[2] and args[3] then
		local number = tonumber(args[3])
		if number then
			if args[2] == "keypress" then
				navigation_helper.delay_between_keypress = number
				notice("Delay Between Keypress:" .. navigation_helper.delay_between_keypress)
			elseif args[2] == "keydownup" then
				navigation_helper.delay_between_key_down_and_up = number
				notice("Delay Between Key Down and Up:" .. navigation_helper.delay_between_key_down_and_up)
			end
		end
	elseif args[1] == "buykey" and args[2] then
		local number = tonumber(args[2])
		if number and number > 0 then
			buy_key = number
			poke_chacharoon()
			notice("Buying " .. buy_key .. " Dial Key #FO")
		else
			notice("buykey needs an argument more than 0: " .. args[2])
		end
	elseif args[1] == "test" then
		notice("Started: " .. tostring(started))
		notice("Game State: " .. tostring(game_state))
		notice("Target Menu Option: " .. tostring(navigation_helper.target_menu_option))
		notice("Player Action Started: " .. tostring(player_action_started))
		notice("Game Started Time: " .. tostring(game_started_time))
		notice("Last Board Update: " .. tostring(last_board_update))
		notice("Time Now: " .. tostring(os.clock()))
	elseif args[1] == "help" then
		notice("//mmmbot start <number_of_jingly_to_get>: Starts automating until you get the amount of jingly specified. 300 is default. Set to 0 automate until you tell it to stop.")
		notice("//mmmbot stop: Stops automation")
		notice("//mmmbot setdelay <keypress / keydownup / ack / waitforack> <number>: Configures the delay for the various events")
		notice("//mmmbot buykey <number>: Buys <number> of Dial Key #FO.")
		notice("//mmmbot debug: Toggles debug output")
	end
end)

windower.register_event('incoming chunk', function(id, data)
	if id == 0x34 then
		local p = packets.parse('incoming',data)
		if p then
			if wait_for_chacharoon_0x034 then
				if buy_key > 0 then
					buy_key_routine:schedule(1)
					return true
				end
			else
				current_zone_id = p['Zone']
				if npc_ids[current_zone_id] then 
					if p['NPC'] == npc_ids[current_zone_id].npc_id then
						if debugging then notice("Got menu packet menu id " .. p['Menu ID']) end
						if game_state == 1 then game_state = 2 end
						if game_state == 0 or game_state == 2 then
							if p['Menu ID'] == npc_ids[current_zone_id].game_menu_id then
								if debugging then notice("Game State Start") end
								game_state = 1
								reset_state()
								game_started_time = os.clock()
							elseif p['Menu ID'] == npc_ids[current_zone_id].menu_id and started and game_state == 2 then
								navigate_to_menu_option(1, 3)
							end
						end
					end
				elseif debugging then
					notice("Couldn't find zone_id defined in npc_ids " .. current_zone_id)
				end
			end
		end
	elseif id == 0x02A then
		if npc_ids[current_zone_id] then
			local p = packets.parse('incoming',data)
			if p then
				if p["Player"] == npc_ids[current_zone_id].npc_id then
					if p["Param 2"] > 0 then -- round ended
						reset_state()
						game_started_time = os.clock()
						if p["Param 2"] == 9999 then -- mandy capped
							started = false
							game_state = 2
							notice("Mandy capped.")
						end
					end
				end
			end
		end
	end
end)

function reset_state()
	if debugging then notice("reset_state") end
	player_turn = false
	game_board = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 0,
	[8] = 0,
	[9] = 0,
	[10] = 0,
	[11] = 0,
	[12] = 0,
	[13] = 0,
	[14] = 0,
	[15] = 0,
	[16] = 0,
	}
	last_board_update = 0
	opponent_move_time = 0
	wait_for_chacharoon_0x034 = false
	player_action_started = false
	navigation_helper.reset_key_states()
end

windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
	if injected or blocked then return end
	if id == 0x5b then
		local p = packets.parse("outgoing", original)
		if p then
			if npc_ids[current_zone_id] then
				if p['Menu ID'] == npc_ids[current_zone_id].game_menu_id and started then
					if p['Option Index'] == 5 then -- quit
						reset_state()
						game_state = 0
					else
						for k,v in pairs(option_indexes) do
							if v == p['Option Index'] then
								update_game_board(k)
							end
						end
					end
				elseif p['Menu ID'] == npc_ids[current_zone_id].menu_id and  p['Option Index'] == 0 then --escaped out
					reset_state()
					game_state = 0
				end
			end
		end
	end
end)

function do_player_turn()
	if game_state ~= 1 or not player_turn then return end
	row_1 = game_board[1] + game_board[2] + game_board[3] + game_board[4]
	row_2 = game_board[5] + game_board[6] + game_board[7] + game_board[8]
	row_3 = game_board[9] + game_board[10] + game_board[11] + game_board[12]
	row_4 = game_board[13] + game_board[14] + game_board[15] + game_board[16]
	column_1 = game_board[1] + game_board[5] + game_board[9] + game_board[13]
	column_2 = game_board[2] + game_board[6] + game_board[10] + game_board[14]
	column_3 = game_board[3] + game_board[7] + game_board[11] + game_board[15]
	column_4 = game_board[4] + game_board[8] + game_board[12] + game_board[16]
	row_4 = game_board[13] + game_board[14] + game_board[15] + game_board[16]
	right_diag = game_board[1] + game_board[6] + game_board[11] + game_board[16]
	left_diag = game_board[4] + game_board[7] + game_board[10] + game_board[13]
	local selected_option = false
	-- win simple 
	if row_1 == 12 and game_board[1] == 1 and game_board[4] == 1 then
		fill_empty(1,2,3,4)
		selected_option = true
	elseif row_2 == 12 and game_board[5] == 1 and game_board[8] == 1 then
		fill_empty(5,6,7,8)
		selected_option = true
	elseif row_3 == 12 and game_board[9] == 1 and game_board[12] == 1 then
		fill_empty(9,10,11,12)
		selected_option = true
	elseif row_4 == 12 and game_board[13] == 1 and game_board[16] == 1 then
		fill_empty(13,14,15,16)
		selected_option = true
	elseif column_1 == 12 and game_board[1] == 1 and game_board[13] == 1 then
		fill_empty(1,5,9,13)
		selected_option = true
	elseif column_2 == 12 and game_board[2] == 1 and game_board[14] == 1 then
		fill_empty(2,6,10,14)
		selected_option = true
	elseif column_3 == 12 and game_board[3] == 1 and game_board[15] == 1 then
		fill_empty(3,7,11,15)
		selected_option = true
	elseif column_4 == 12 and game_board[4] == 1 and game_board[16] == 1 then
		fill_empty(4,8,12,16)
		selected_option = true
	elseif right_diag == 12 and game_board[1] == 1 and game_board[16] == 1 then
		fill_empty(1,6,11,16)
		selected_option = true
	elseif left_diag == 12 and game_board[4] == 1 and game_board[13] == 1 then
		fill_empty(4,7,10,13)
		selected_option = true
	elseif row_1 == 3 then
		fill_empty(1,2,3,4)
		selected_option = true
	elseif column_1 == 3 then
		fill_empty(1,5,9,13)
		selected_option = true
	elseif column_4 == 3 then
		fill_empty(4,8,12,16)
		selected_option = true
	elseif row_4 == 3 then
		fill_empty(13,14,15,16)
		selected_option = true
	elseif right_diag == 3 then
		fill_empty(1,6,11,16)
		selected_option = true
	elseif left_diag == 3 then
		fill_empty(4,7,10,13)
		selected_option = true
	end
	if not selected_option then
		-- block enemy
		if row_1 == 30 then selected_option = block_without_bust(1,2,3,4) end
		if not selected_option and row_2 == 30 then selected_option = block_without_bust(5,6,7,8) end
		if not selected_option and row_3 == 30 then selected_option = block_without_bust(9,10,11,12) end
		if not selected_option and row_4 == 30 then selected_option = block_without_bust(13,14,15,16) end
		if not selected_option and column_1 == 30 then selected_option = block_without_bust(1,5,9,13) end
		if not selected_option and column_2 == 30 then selected_option = block_without_bust(2,6,10,14) end
		if not selected_option and column_3 == 30 then selected_option = block_without_bust(3,7,11,15) end
		if not selected_option and column_4 == 30 then selected_option = block_without_bust(4,8,12,16) end
		if not selected_option and right_diag == 30 then selected_option = block_without_bust(1,6,11,16) end
		if not selected_option and left_diag == 30 then selected_option = block_without_bust(4,7,10,13) end
		
		if not selected_option then
			-- skip getting corner under this condition
			local three_corners = game_board[1] + game_board[4] + game_board[13] + game_board[16] == 3 
			local top_bottom = row_1 == 22 and row_4 == 11
			local bottom_top = row_1 == 11 and row_4 == 22
			local left_right = column_1 == 22 and column_4 == 11
			local right_left = column_1 == 11 and column_4 == 22
			local center = game_board[6] + game_board[7] + game_board[10] + game_board[11]
			local skip_corner_pick = three_corners and (top_bottom or bottom_top or left_right or right_left) and center == 0
			
			if skip_corner_pick then 
				if debugging then 
					notice("Skipping corner pick: " .. tostring(top_bottom)..tostring(bottom_top)..tostring(left_right)..tostring(right_left)) 
				end
				if game_board[1] == 0 then
					if row_1 == 1 then
						navigate_to_menu_option(3)
						selected_option = true
					elseif column_1 == 1 then
						navigate_to_menu_option(9)
						selected_option = true
					end
				elseif game_board[4] == 0 then
					if row_1 == 1 then
						navigate_to_menu_option(2)
						selected_option = true
					elseif column_4 == 1 then
						navigate_to_menu_option(12)
						selected_option = true
					end
				elseif game_board[13] == 0 then
					if row_4 == 1 then
						navigate_to_menu_option(15)
						selected_option = true
					elseif column_1 == 1 then
						navigate_to_menu_option(5)
						selected_option = true
					end
				elseif game_board[16] == 0 then
					if row_4 == 1 then
						navigate_to_menu_option(14)
						selected_option = true
					elseif column_4 == 1 then
						navigate_to_menu_option(8)
						selected_option = true
					end
				end
			end
			
			if not skip_corner_pick then
				if row_1 == 11 then -- try to get corner that forces a move
					if game_board[1] == 0 then 
						navigate_to_menu_option(1)
						selected_option = true
					elseif game_board[4] == 0 then
						navigate_to_menu_option(4)
						selected_option = true
					end
				elseif row_4 == 11 then
					if game_board[13] == 0 then 
						navigate_to_menu_option(13)
						selected_option = true
					elseif game_board[16] == 0 then
						navigate_to_menu_option(16)
						selected_option = true
					end
				elseif column_1 == 11 then
					if game_board[1] == 0 then 
						navigate_to_menu_option(1)
						selected_option = true
					elseif game_board[13] == 0 then
						navigate_to_menu_option(13)
						selected_option = true
					end
				elseif column_4 == 11 then
					if game_board[4] == 0 then 
						navigate_to_menu_option(4)
						selected_option = true
					elseif game_board[16] == 0 then
						navigate_to_menu_option(16)
						selected_option = true
					end
				elseif right_diag == 11 then
					if game_board[1] == 0 then 
						navigate_to_menu_option(1)
						selected_option = true
					elseif game_board[16] == 0 then
						navigate_to_menu_option(16)
						selected_option = true
					end
				elseif left_diag == 11 then
					if game_board[4] == 0 then 
						navigate_to_menu_option(4)
						selected_option = true
					elseif game_board[13] == 0 then
						navigate_to_menu_option(13)
						selected_option = true
					end
				end
			end
			
			-- get corners
			if not selected_option and not skip_corner_pick then
				if game_board[1] == 0 then 
					navigate_to_menu_option(1)
					selected_option = true
				elseif game_board[4] == 0 then 
					navigate_to_menu_option(4)
					selected_option = true
				elseif game_board[13] == 0 then 
					navigate_to_menu_option(13)
					selected_option = true
				elseif game_board[16] == 0 then 
					navigate_to_menu_option(16)
					selected_option = true
				end
			end
		end
		if not selected_option then
			-- fill up 
		
			-- fill up row or diagonal
			if not selected_option and right_diag == 2 then selected_option = fill_up_diagonal(1,6,11,16) end
			if not selected_option and left_diag == 2 then selected_option = fill_up_diagonal(4,7,10,13) end
			if not selected_option and row_1 == 2 then selected_option = fill_up_sides(1,2,3,4) end
			if not selected_option and column_1 == 2 then selected_option = fill_up_sides(1,5,9,13) end
			if not selected_option and column_4 == 2 then selected_option = fill_up_sides(4,8,12,16) end
			if not selected_option and row_4 == 2 then selected_option = fill_up_sides(13,14,15,16) end
			
			-- just get random
			if not selected_option then
				local free_areas = {}
				for k,v in pairs(game_board) do
					if v == 0 then 
						table.insert(free_areas, #free_areas+1, k)
					end
				end
				for i = #free_areas, 2, -1 do
					local j = math.random(i)
					free_areas[i], free_areas[j] = free_areas[j], free_areas[i]
				end
				for k,v in pairs(free_areas) do
					selected_option = fill_without_bust(v)
					if selected_option then break end
				end
				if not selected_option then
					-- probably lose now
					navigate_to_menu_option(free_areas[math.random(#free_areas)])
				end
			end
		end
	end
end

function fill_empty(area1, area2, area3, area4)
	if game_board[area1] == 0 then navigate_to_menu_option(area1)
	elseif game_board[area2] == 0 then navigate_to_menu_option(area2)
	elseif game_board[area3] == 0 then navigate_to_menu_option(area3)
	elseif game_board[area4] == 0 then navigate_to_menu_option(area4)
	end
end

function enemy_wins_next_move(area)
	if area == 6 then 
		return (game_board[5] == 0 and game_board[7] == 10 and game_board[8] == 10)
		or (game_board[5] == 10 and game_board[7] == 0 and game_board[8] == 10)
		or (game_board[2] == 0 and game_board[10] == 10 and game_board[14] == 10)
		or (game_board[2] == 10 and game_board[10] == 0 and game_board[14] == 10)
	elseif area == 7 then
		return (game_board[8] == 0 and game_board[5] == 10 and game_board[6] == 10)
		or (game_board[8] == 10 and game_board[5] == 10 and game_board[6] == 0)
		or (game_board[3] == 0 and game_board[11] == 10 and game_board[15] == 10)
		or (game_board[3] == 10 and game_board[11] == 0 and game_board[15] == 10)
	elseif area == 10 then
		return (game_board[9] == 0 and game_board[11] == 10 and game_board[12] == 10)
		or (game_board[9] == 10 and game_board[11] == 0 and game_board[12] == 10)
		or (game_board[14] == 0 and game_board[2] == 10 and game_board[6] == 10)
		or (game_board[14] == 10 and game_board[2] == 10 and game_board[6] == 0)
	elseif area == 11 then
		return (game_board[12] == 0 and game_board[9] == 10 and game_board[10] == 10)
		or (game_board[12] == 10 and game_board[9] == 10 and game_board[10] == 0)
		or (game_board[15] == 0 and game_board[3] == 10 and game_board[7] == 10)
		or (game_board[15] == 10 and game_board[3] == 10 and game_board[7] == 0)
	end
end

function two_enemies_besides_area(area)
	if area == 6 then 
		return game_board[2] == 10 and game_board[5] == 10 and game_board[7] == 0 and game_board[10] == 0
	elseif area == 7 then
		return game_board[3] == 10 and game_board[8] == 10 and game_board[6] == 0 and game_board[11] == 0
	elseif area == 10 then
		return game_board[9] == 10 and game_board[14] == 10 and game_board[6] == 0 and game_board[11] == 0
	elseif area == 11 then
		return game_board[12] == 10 and game_board[15] == 10 and game_board[7] == 0 and game_board[10] == 0
	end
end

-- 4 areas should be in a line
function fill_up_diagonal(area1, area2, area3, area4)
	if game_board[area1] == 1 and game_board[area4] == 1 then 
		if game_board[area2] == 0 and two_enemies_besides_area(area2) and not enemy_wins_next_move(area2) and not enemy_gets_3_in_a_line_next_move(area2) then 
			navigate_to_menu_option(area2)
			return true
		elseif game_board[area3] == 0 and two_enemies_besides_area(area3) and not enemy_wins_next_move(area3) and not enemy_gets_3_in_a_line_next_move(area3) then 
			navigate_to_menu_option(area3)
			return true
		end
	end
	return false
end

function enemy_gets_3_in_a_line_next_move(area)
	if area == 2 and row_1 == 2 and column_3 == 20 and game_board[7] == 0 then return true
	elseif area == 3 and row_1 == 2 and column_2 == 20 and game_board[6] == 0 then return true
	elseif area == 5 and column_1 == 2 and row_3 == 20 and game_board[10] == 0 then return true
	elseif area == 9 and column_1 == 2 and row_2 == 20 and game_board[6] == 0 then return true
	elseif area == 8 and column_4 == 2 and row_3 == 20 and game_board[11] == 0 then return true
	elseif area == 12 and column_4 == 2 and row_2 == 20 and game_board[7] == 0 then return true
	elseif area == 14 and row_4 == 2 and column_3 == 20 and game_board[11] == 0 then return true
	elseif area == 15 and row_4 == 2 and column_2 == 20 and game_board[10] == 0 then return true
	elseif area == 6 then
		if right_diag == 2 and (row_3 == 20 or column_3 == 20) then return true end
		if row_2 == 2 and column_3 == 20 then return true end
		if column_2 == 2 and row_3 == 20 then return true end
	elseif area == 7 then
		if left_diag == 2 and (row_2 == 20 or column_2 == 20) then return true end
		if row_2 == 2 and column_2 == 20 then return true end
		if column_3 == 2 and row_3 == 20 then return true end
	elseif area == 10 then
		if left_diag == 2 and (row_2 == 20 or column_3 == 20) then return true end
		if row_3 == 2 and column_3 == 20 then return true end
		if column_2 == 2 and row_2 == 20 then return true end
	elseif area == 11 then
		if right_diag == 2 and (row_2 == 20 or column_2 == 20) then return true end
		if row_3 == 2 and column_2 == 20 then return true end
		if column_3 == 2 and row_2 == 20 then return true end
	end
	return false
end

-- 4 areas should be in a line
function fill_up_sides(area1, area2, area3, area4)
	if game_board[area1] == 1 and game_board[area4] == 1 then 
		if game_board[area2] == 0 and not enemy_wins_next_move(area2) and not enemy_gets_3_in_a_line_next_move(area2) then 
			navigate_to_menu_option(area2)
			return true
		elseif game_board[area3] == 0 and not enemy_wins_next_move(area3) and not enemy_gets_3_in_a_line_next_move(area3) then 
			navigate_to_menu_option(area3)
			return true
		end
	end
	return false
end

function block_without_bust(area1,area2,area3,area4)
	if game_board[area1] == 0 and fill_without_bust(area1) then 
		navigate_to_menu_option(area1)
		return true
	elseif game_board[area2] == 0 and fill_without_bust(area2) then
		navigate_to_menu_option(area2)
		return true
	elseif game_board[area3] == 0 and fill_without_bust(area3) then
		navigate_to_menu_option(area3)
		return true
	elseif game_board[area4] == 0 and fill_without_bust(area4) then
		navigate_to_menu_option(area4)
		return true
	end
	return false
end

function fill_without_bust(area)
	local no_bust = true
	if area == 2 then
		if (game_board[1] == 1 and game_board[3] == 1)
		or (game_board[3] == 1 and game_board[4] == 1)
		or (game_board[6] == 1 and game_board[10] == 1)
		or (game_board[7] == 1 and game_board[12] == 1)
		or (game_board[3] == 10 and game_board[4] == 1)
		or (game_board[6] == 10 and game_board[10] == 1)
		or (game_board[7] == 10 and game_board[12] == 1)
		then no_bust = false end
	elseif area == 3 then
		if (game_board[1] == 1 and game_board[2] == 1)
		or (game_board[2] == 1 and game_board[4] == 1)
		or (game_board[7] == 1 and game_board[11] == 1)
		or (game_board[6] == 1 and game_board[9] == 1)
		or (game_board[1] == 1 and game_board[2] == 10)
		or (game_board[7] == 10 and game_board[11] == 1)
		or (game_board[6] == 10 and game_board[9] == 1)
		then no_bust = false end
	elseif area == 5 then
		if (game_board[9] == 1 and game_board[13] == 1)
		or (game_board[1] == 1 and game_board[9] == 1)
		or (game_board[6] == 1 and game_board[7] == 1)
		or (game_board[10] == 1 and game_board[15] == 1)
		or (game_board[9] == 10 and game_board[13] == 1)
		or (game_board[6] == 10 and game_board[7] == 1)
		or (game_board[10] == 10 and game_board[15] == 1)
		then no_bust = false end
	elseif area == 9 then
		if (game_board[1] == 1 and game_board[5] == 1)
		or (game_board[5] == 1 and game_board[13] == 1)
		or (game_board[10] == 1 and game_board[11] == 1)
		or (game_board[6] == 1 and game_board[3] == 1)
		or (game_board[5] == 10 and game_board[1] == 1)
		or (game_board[10] == 10 and game_board[11] == 1)
		or (game_board[6] == 10 and game_board[3] == 1)
		then no_bust = false end
	elseif area == 8 then
		if (game_board[4] == 1 and game_board[12] == 1)
		or (game_board[12] == 1 and game_board[16] == 1)
		or (game_board[7] == 1 and game_board[6] == 1)
		or (game_board[11] == 1 and game_board[14] == 1)
		or (game_board[12] == 10 and game_board[16] == 1)
		or (game_board[7] == 10 and game_board[6] == 1)
		or (game_board[11] == 10 and game_board[14] == 1)
		then no_bust = false end
	elseif area == 12 then
		if (game_board[8] == 1 and game_board[16] == 1)
		or (game_board[8] == 1 and game_board[4] == 1)
		or (game_board[11] == 1 and game_board[10] == 1)
		or (game_board[7] == 1 and game_board[2] == 1)
		or (game_board[8] == 10 and game_board[4] == 1)
		or (game_board[11] == 10 and game_board[10] == 1)
		or (game_board[7] == 10 and game_board[2] == 1)
		then no_bust = false end
	elseif area == 14 then
		if (game_board[13] == 1 and game_board[15] == 1)
		or (game_board[15] == 1 and game_board[16] == 1)
		or (game_board[10] == 1 and game_board[6] == 1)
		or (game_board[11] == 1 and game_board[8] == 1)
		or (game_board[15] == 10 and game_board[16] == 1)
		or (game_board[10] == 10 and game_board[6] == 1)
		or (game_board[11] == 10 and game_board[8] == 1)
		then no_bust = false end
	elseif area == 15 then
		if (game_board[16] == 1 and game_board[14] == 1)
		or (game_board[14] == 1 and game_board[13] == 1)
		or (game_board[11] == 1 and game_board[7] == 1)
		or (game_board[10] == 1 and game_board[5] == 1)
		or (game_board[14] == 10 and game_board[13] == 1)
		or (game_board[11] == 10 and game_board[7] == 1)
		or (game_board[10] == 10 and game_board[5] == 1)
		then no_bust = false end
	elseif area == 6 then
		if (game_board[2] == 1 and game_board[10] == 1)
		or (game_board[5] == 1 and game_board[7] == 1)
		or (game_board[1] == 1 and game_board[11] == 1)
		or (game_board[9] == 1 and game_board[3] == 1)
		or (game_board[7] == 1 and game_board[8] == 1)
		or (game_board[10] == 1 and game_board[14] == 1)
		or (game_board[11] == 1 and game_board[16] == 1)
		or (game_board[7] == 10 and game_board[8] == 1)
		or (game_board[10] == 10 and game_board[14] == 1)
		or (game_board[11] == 10 and game_board[16] == 1)
		then no_bust = false end
	elseif area == 11 then
		if (game_board[16] == 1 and game_board[6] == 1)
		or (game_board[14] == 1 and game_board[8] == 1)
		or (game_board[10] == 1 and game_board[12] == 1)
		or (game_board[7] == 1 and game_board[15] == 1)
		or (game_board[9] == 1 and game_board[10] == 1)
		or (game_board[1] == 1 and game_board[6] == 1)
		or (game_board[3] == 1 and game_board[7] == 1)
		or (game_board[10] == 10 and game_board[9] == 1)
		or (game_board[6] == 10 and game_board[1] == 1)
		or (game_board[7] == 10 and game_board[3] == 1)
		then no_bust = false end
	elseif area == 7 then
		if (game_board[2] == 1 and game_board[12] == 1)
		or (game_board[3] == 1 and game_board[11] == 1)
		or (game_board[10] == 1 and game_board[4] == 1)
		or (game_board[6] == 1 and game_board[8] == 1)
		or (game_board[6] == 1 and game_board[5] == 1)
		or (game_board[11] == 1 and game_board[15] == 1)
		or (game_board[10] == 1 and game_board[13] == 1)
		or (game_board[6] == 10 and game_board[5] == 1)
		or (game_board[11] == 10 and game_board[15] == 1)
		or (game_board[10] == 10 and game_board[13] == 1)
		then no_bust = false end
	elseif area == 10 then
		if (game_board[5] == 1 and game_board[15] == 1)
		or (game_board[6] == 1 and game_board[14] == 1)
		or (game_board[7] == 1 and game_board[13] == 1)
		or (game_board[9] == 1 and game_board[11] == 1)
		or (game_board[11] == 1 and game_board[12] == 1)
		or (game_board[7] == 1 and game_board[4] == 1)
		or (game_board[6] == 1 and game_board[2] == 1)
		or (game_board[11] == 10 and game_board[12] == 1)
		or (game_board[7] == 10 and game_board[4] == 1)
		or (game_board[6] == 10 and game_board[2] == 1)
		then no_bust = false end
	end
	if no_bust then navigate_to_menu_option(area) end
	return no_bust
end

function update_game_board(area_selected)
	last_board_update = os.clock()
	if not player_turn then
		game_board[area_selected] = 10
		player_turn = true
		if debugging then notice("Opponent selected Area " .. area_selected) end
		opponent_move_time = last_board_update
		game_started_time = 0
	else 
		game_board[area_selected] = 1
		player_turn = false
		if debugging then notice("Player selected Area " .. area_selected) end
		player_action_started = false
	end
end

function navigate_to_menu_option(option_index, override_delay)
	if debugging then notice("Navigate to " .. option_index) end
	player_action_start_time = os.clock()
	player_action_started = true
	navigation_helper.navigate_to_menu_option(option_index, override_delay)
end

function update_loop()
	local time_now = os.clock()
	if started and navigation_helper.target_menu_option == 0 and not player_action_started and not navigation_helper.resetting then
		if need_to_reset then
			need_to_reset = false
			player_action_started = false 
			navigation_helper.reset_position()
		elseif game_state == 1 then
			if game_started_time > 0 and time_now - game_started_time > 10 then
				game_started_time = 0
				player_turn = true
				do_player_turn()
			elseif game_started_time == 0 and time_now - last_board_update > 10 then
				player_turn = true
				do_player_turn()
			elseif game_started_time == 0 and player_turn and opponent_move_time > 0 and time_now - opponent_move_time > 2 then
				do_player_turn()
			end
		end
	elseif started and navigation_helper.target_menu_option == 0 and player_action_started and not navigation_helper.resetting 
	and time_now - player_action_start_time > 10 then
		if game_state == 1 then 
			player_action_started = false -- for cases where tried to input but no action, set this flag to false so that can do player turn again
			navigation_helper.reset_position()
		elseif game_state == 2 then
			navigate_to_menu_option(1)
		end
	else
		navigation_helper.update(time_now)
	end
end

function poke_thing(npc)
	local p = packets.new('outgoing', 0x1a, {
		['Target'] = npc.id,
		['Target Index'] = npc.index,
	})
	packets.inject(p)
end

function poke_chacharoon()
	current_zone_id = windower.ffxi.get_info().zone
	if npc_ids[current_zone_id] then
		local npc = windower.ffxi.get_mob_by_id(npc_ids[current_zone_id].npc_id)
		if npc and npc.distance <= interact_distance_square then
			log('poke chacharoon')
			npc_index = npc.index
			wait_for_chacharoon_0x034 = true
			poke_thing(npc)
		end
	end
end

function buy_key_routine()
	local p = packets.new('outgoing', 0x5b, {
            ['Target'] =  npc_ids[current_zone_id].npc_id,
            ['Target Index'] = npc_index,
			['Menu ID'] = npc_ids[current_zone_id].menu_id,
			['Zone'] = current_zone_id,
			['Option Index'] = buy_key_fo_option_index,
			['_unknown1'] = 1,
			["Automated Message"] = true
		})
	packets.inject(p)
	buy_key = buy_key - 1
	if buy_key > 0 then
		buy_key_routine:schedule(1)
	else
		notice('Stopping buy key')
		local p = packets.new('outgoing', 0x5b, {
            ['Target'] =  npc_ids[current_zone_id].npc_id,
            ['Target Index'] = npc_index,
			['Menu ID'] = npc_ids[current_zone_id].menu_id,
			['Zone'] = current_zone_id,
			['Option Index'] = 0,
			['_unknown1'] = 0,
		})
		packets.inject(p)
		wait_for_chacharoon_0x034 = false
	end
end

function parse_incoming_text(original, modified, original_mode, modified_mode, blocked)
	if started then
		if original:find("There is already a piece in this location.") ~= nil then
			player_action_started = false
			navigation_helper.reset_position()
		elseif original:find("You will forfeit all mandy earned this game") ~= nil then
			navigation_helper.press_enter()
			need_to_reset = true
		end
	end
end

windower.register_event('incoming text', parse_incoming_text)

windower.register_event('prerender', update_loop)

windower.register_event('zone change', function()
	reset_state()
end)