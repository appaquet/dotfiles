local function is_floating_win(win)
	return vim.api.nvim_win_get_config(win).relative ~= ""
end

--- Close all windows but the current and floating windows
function WinCloseOthers()
	local windows = vim.api.nvim_list_wins()
	local current_win = vim.api.nvim_get_current_win()

	for _, win in ipairs(windows) do
		if win ~= current_win and not is_floating_win(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
end

--- Get the left/right split window
-- @param dest string: the destination window (left or right)
local function get_side_win(dest)
	local current_win = vim.api.nvim_get_current_win()
	local current_win_pos = vim.api.nvim_win_get_position(current_win)

	local windows = vim.api.nvim_list_wins()
	for _, win in ipairs(windows) do
		if win ~= current_win then
			local win_pos = vim.api.nvim_win_get_position(win)

			if not is_floating_win(win) and win_pos[1] == current_win_pos[1] then
				if dest == "right" and win_pos[2] > current_win_pos[2] then
					return win
				elseif dest == "left" and win_pos[2] < current_win_pos[2] then
					return win
				end
			end
		end
	end

	return nil
end

--- Send the current buffer to the right split window and navigate back the left window
local function pop_buf_right()
	local current_buf = vim.api.nvim_get_current_buf()
	local current_win = vim.api.nvim_get_current_win()

	-- Get or create the right split window
	local win_id_right = get_side_win("right")
	if not win_id_right then
		vim.cmd("vsplit")
		win_id_right = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_win_set_buf(win_id_right, current_buf)
	vim.api.nvim_set_current_win(current_win)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "nx", false)
	vim.api.nvim_set_current_win(win_id_right)
end

local function swap_left_right_win()
	local cur_win = vim.api.nvim_get_current_win()
	local left_win = get_side_win("left")
	local right_win = get_side_win("right")

	if right_win ~= nil then
		-- We have a right window, so swap the current window with it
		local cur_buf = vim.api.nvim_get_current_buf()
		local right_buf = vim.api.nvim_win_get_buf(right_win)
		vim.api.nvim_win_set_buf(cur_win, right_buf)
		vim.api.nvim_win_set_buf(right_win, cur_buf)
		vim.api.nvim_set_current_win(right_win)
	elseif left_win ~= nil then
		-- We have a left window, so swap the current window with it
		local cur_buf = vim.api.nvim_get_current_buf()
		local left_buf = vim.api.nvim_win_get_buf(left_win)
		vim.api.nvim_win_set_buf(cur_win, left_buf)
		vim.api.nvim_win_set_buf(left_win, cur_buf)
		vim.api.nvim_set_current_win(left_win)
	end
end

local function win_width_incr()
	local cur_win = vim.api.nvim_get_current_win()
	local cur_width = vim.api.nvim_win_get_width(cur_win)
	vim.api.nvim_win_set_width(cur_win, cur_width + 20)
end

local function win_width_decr()
	local cur_win = vim.api.nvim_get_current_win()
	local cur_width = vim.api.nvim_win_get_width(cur_win)
	vim.api.nvim_win_set_width(cur_win, cur_width - 20)
end

local function win_width_80pc()
	local cur_win = vim.api.nvim_get_current_win()
	local new_width = math.floor(vim.o.columns * 0.8)
	vim.api.nvim_win_set_width(cur_win, new_width)
end

vim.keymap.set("n", "<C-w>pl", pop_buf_right, { silent = true, desc = "Pop buffer to right window" })
vim.keymap.set("n", "<C-w>w", swap_left_right_win, { silent = true, desc = "Swap left and right window buffers" })
vim.keymap.set("n", "<C-w>]", win_width_incr, { silent = true, desc = "Increase window width" })
vim.keymap.set("n", "<C-w>[", win_width_decr, { silent = true, desc = "Decrease window width" })
vim.keymap.set("n", "<C-w>z", win_width_80pc, { silent = true, desc = "Increase window width to 80%" })
