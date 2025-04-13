--[[
	samsweeper V.0.1.0

	Credit @sambouza on github ok? Fork it if you want
	still very much a WIP + spaghetti code so probably don't

	Planned Features:
		-> Custom Mods / Gamemodes
		-> Custom Boards
		-> Custom difficulties / selector
]]

-- Initialization
math.randomseed(os.time())

-- CONSTANTS
local FORMAT = {
	RESET = "\027[0m",
	BOLD = "\027[1m",

	RED = "\027[31m",
	RED_BG = "\027[41m",
	ORANGE = "\027[38;5;208m",
	ORANGE_BG = "\027[48;5;208m",
	YELLOW = "\027[33m",
	YELLOW_BG = "\027[43m",
	GREEN = "\027[32m",
	GREEN_BG = "\027[42m",
	BLUE = "\027[34m",
	BLUE_BG = "\027[44m",
	PURPLE = "\027[35m",
	PURPLE_BG = "\027[45m",
	CYAN = "\027[36m",
	CYAN_BG = "\027[46m",
	BLACK = "\027[30m",
	BLACK_BG = "\027[40m",
	WHITE = "\027[37m",
	WHITE_BG = "\027[47m",
	GREY = "\027[90m",
	GREY_BG = "\027[100m",
}
local CHAR = {
	FLAG = { SYM = "!", CLR = FORMAT.YELLOW },
	MINE = { SYM = "X", CLR = FORMAT.RED },
	EMPTY = { SYM = ".", CLR = FORMAT.WHITE },
	HIDDEN = { SYM = "#", CLR = FORMAT.GREY },
}
local NUM = {
	[1] = { CLR = FORMAT.BLUE },
	[2] = { CLR = FORMAT.GREEN },
	[3] = { CLR = FORMAT.RED },
	[4] = { CLR = FORMAT.PURPLE },
	[5] = { CLR = FORMAT.ORANGE },
	[6] = { CLR = FORMAT.CYAN },
	[7] = { CLR = FORMAT.BLACK },
	[8] = { CLR = FORMAT.GREY },
}
local HEADER_BG_COLORS = {
	FORMAT.BLUE_BG,
	FORMAT.GREEN_BG,
	FORMAT.PURPLE_BG,
	FORMAT.ORANGE_BG,
	FORMAT.CYAN_BG,
	FORMAT.YELLOW_BG,
	FORMAT.GREY_BG,
	FORMAT.RED_BG,
	-- Add more FORMAT._BG colors here if needed for more cycles
}
local GAME_MESSAGES = {
	WIN = {
		"Well done!",
	},
	LOSE = {
		"One small misstep, and it's already too late. You inevitably lift off your foot and meet your demise.",
		"Tripped on a mine, didn't you?",
		"Carelessness will not get you anywhere. What if you were in a real situation?",
		"You're not a good minesweeper. You're a bad minesweeper.",
		"What a shame.",
		"Would you look at that! You just killed the baby in your arms. The afterlife court will be in touch.",
		"What's wrong with you!? You just killed another baby. The supreme afterlife court will be in touch. Baby killer.",
	},
}

-- Variables
local width, height = 10, 10
local minePercentage = 0.25

-- Generic functions
local function numberize(str)
	local result = 0
	for i = 1, #str do
		local char = string.lower(string.sub(str, i, i))
		local value = string.byte(char) - string.byte("a") + 1
		result = result * 26 + value
	end
	return result
end
local function alphabetize(num)
	if num < 1 then
		return ""
	end
	local result = ""
	while num > 0 do
		local remainder = (num - 1) % 26
		result = string.char(string.byte("a") + remainder) .. result
		num = math.floor((num - 1) / 26)
	end
	return result
end
local function formatHeader(columnIndex)
	local charCode = (columnIndex - 1) % 26
	local char = string.char(string.byte("a") + charCode)
	local cycleIndex = math.floor((columnIndex - 1) / 26)
	local bgColor = "" -- no bg color for the first cycle
	if cycleIndex > 0 then
		local colorListIndex = (cycleIndex - 1) % #HEADER_BG_COLORS + 1
		bgColor = HEADER_BG_COLORS[colorListIndex] or ""
	end
	return bgColor .. char .. FORMAT.RESET
end
local function parseInput(input)
	if not input or #input < 2 then
		return nil, nil, nil
	end

	local flag = nil
	local coordStr = input
	if #input >= 4 and input:sub(2, 2) == " " and input:sub(1, 1):match("%a") then
		flag = input:sub(1, 1)
		coordStr = input:sub(3)
	end

	local colLetters, rowDigits = coordStr:match("^([a-zA-Z]+)([0-9]+)$")
	if not colLetters or not rowDigits then
		return nil, nil, nil
	end

	local x = numberize(colLetters)
	local y = tonumber(rowDigits)
	if not x or x <= 0 or not y or y <= 0 then
		return nil, nil, nil
	end

	return x, y, flag
end
local function msWrite(char)
	if type(char) == "number" and NUM[char] then -- number
		io.write(NUM[char].CLR .. char .. FORMAT.RESET)
	elseif type(char) == "table" and char.SYM and char.CLR then -- symbol
		io.write(FORMAT.BOLD .. char.CLR .. char.SYM .. FORMAT.RESET)
	else -- fallback
		io.write(char)
	end
end

-- Board functions
local function isBoardComplete(board)
	local width = #board
	local height = #board[1]

	for y = 1, height do
		for x = 1, width do
			if board[x][y].mine and not board[x][y].flagged then
				return false
			end
		end
	end
	return true
end
local function newBoard(width, height, mineConcentration)
	local board = { mines = 0 }

	-- x and y represent coordinates, so for loops are reversed
	-- and the origin starts at the top left
	for x = 1, width do
		board[x] = {}
		for y = 1, height do
			board[x][y] = {
				mine = math.random() < mineConcentration,
				revealed = false,
				flagged = false,
				adjacentMines = 0,
			}
			board.mines = board.mines + (board[x][y].mine and 1 or 0)
		end
	end

	-- Precalculate adjacent mines: Iterate rows (y) then columns (x)
	for y = 1, height do
		for x = 1, width do
			local adjacentMines = 0

			-- Adjacent cells
			for dy = -1, 1 do
				for dx = -1, 1 do
					local nx = x + dx
					local ny = y + dy
					if nx > 0 and nx <= width and ny > 0 and ny <= height then
						adjacentMines = adjacentMines + (board[nx][ny].mine and 1 or 0)
					end
				end
			end

			board[x][y].adjacentMines = adjacentMines
		end
	end

	-- Methods
	function board:RecursiveReveal(x, y)
		if
			x <= 0
			or x > width
			or y <= 0
			or y > height
			or self[x][y].revealed
			or self[x][y].flagged
			or self[x][y].mine
		then
			return self
		end

		self[x][y].revealed = true
		if self[x][y].adjacentMines == 0 then
			for dx = -1, 1 do
				for dy = -1, 1 do
					local nx, ny = x + dx, y + dy
					if (dx ~= 0 or dy ~= 0) and (nx > 0 and nx <= width and ny > 0 and ny <= height) then
						self:RecursiveReveal(nx, ny)
					end
				end
			end
		end

		return self
	end

	function board:RevealAll()
		for y = 1, height do
			for x = 1, width do
				self[x][y].revealed = true
			end
		end

		return self
	end

	function board:Regenerate()
		self.mines = 0 -- Reset mine count

		for x = 1, width do
			for y = 1, height do
				self[x][y] = {
					mine = math.random() < mineConcentration,
					revealed = false,
					flagged = false,
					adjacentMines = 0,
				}
				self.mines = self.mines + (self[x][y].mine and 1 or 0)
			end
		end

		for y = 1, height do
			for x = 1, width do
				local adjacentMines = 0
				for dy = -1, 1 do
					for dx = -1, 1 do
						if dx ~= 0 or dy ~= 0 then
							local nx = x + dx
							local ny = y + dy
							if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
								if self[nx][ny].mine then
									adjacentMines = adjacentMines + 1
								end
							end
						end
					end
				end
				self[x][y].adjacentMines = adjacentMines
			end
		end

		return self
	end

	function board:Print(withTitle)
		local maxDigits = math.floor(math.log10(height)) + 1
		local marginSize = maxDigits + 1 -- Add 1 for the space after the number
		local rowFormat = "%" .. maxDigits .. "d "

		if withTitle then
			-- Count flagged cells
			local flaggedCount = 0
			for y = 1, height do
				for x = 1, width do
					if self[x][y].flagged then
						flaggedCount = flaggedCount + 1
					end
				end
			end

			-- Define header parts
			-- title
			local titleHeader = "sambouza sweeper"
			-- flagged/mines
			local flaggedStr = CHAR.FLAG.CLR .. flaggedCount .. FORMAT.RESET
			local totalMinesStr = FORMAT.BOLD .. FORMAT.RED .. self.mines .. FORMAT.RESET
			local flaggedToMinesStr = flaggedStr .. " / " .. totalMinesStr
			local flaggedToMinesLen = #tostring(flaggedCount) + 3 + #tostring(self.mines)
			local seperatorStr = string.rep(" ", math.max(1, (2 * width - 1) - #titleHeader - flaggedToMinesLen))

			-- Print header
			io.write(string.rep(" ", marginSize))
			io.write(FORMAT.BOLD .. FORMAT.YELLOW .. titleHeader .. FORMAT.RESET)
			io.write(seperatorStr)
			io.write(flaggedToMinesStr)
			io.write("\n")
		end

		-- Print column headers
		io.write(string.rep(" ", marginSize))
		for x = 1, width do
			io.write(formatHeader(x) .. " ")
		end
		io.write("\n")

		for y = 1, height do
			-- row headers
			io.write(string.format(rowFormat, y))

			-- row contents
			for x = 1, width do
				local cell = self[x][y]
				if cell.flagged then
					msWrite(CHAR.FLAG)
				elseif cell.revealed then
					if cell.mine then
						msWrite(CHAR.MINE)
					else
						msWrite(cell.adjacentMines == 0 and CHAR.EMPTY or cell.adjacentMines)
					end
				else
					msWrite(CHAR.HIDDEN)
				end
				io.write(" ")
			end
			io.write("\n")
		end

		return self
	end

	return board
end

-- Initialize board
local board = newBoard(width, height, minePercentage)
local isFirstClick = true -- Add this flag

-- Game loop
while true do
	-- Draw board
	os.execute("cls")
	board:Print(true)

	-- Handle input
	local x, y, flag
	while not x or not y do
		io.write("> ")
		x, y, flag = parseInput(io.read())
		if not x or not y or not (x > 0 and x <= width and y > 0 and y <= height) then
			x, y = nil, nil
			io.write(FORMAT.RED .. "Invalid input" .. FORMAT.RESET .. "\n\n")
		elseif board[x][y].revealed then
			x, y = nil, nil
			io.write(FORMAT.YELLOW .. "Already revealed" .. FORMAT.RESET .. "\n\n")
		end
	end
	io.write("\n")

	-- Handle action
	if flag == "f" then
		-- Toggle flag only if not revealed
		if not board[x][y].revealed then
			board[x][y].flagged = not board[x][y].flagged
		end
	else
		-- Reveal action
		if isFirstClick then
			while board[x][y].mine do
				board:Regenerate()
			end
			isFirstClick = false
		end

		if board[x][y].mine then
			-- Losing condition
			board:RevealAll():Print()
			print(GAME_MESSAGES.LOSE[math.random(#GAME_MESSAGES.LOSE)])
			break
		else
			board:RecursiveReveal(x, y)
		end
	end

	-- Winning condition
	if isBoardComplete(board) then
		board:Print()
		print(GAME_MESSAGES.WIN[math.random(#GAME_MESSAGES.WIN)])
		break
	end
end
