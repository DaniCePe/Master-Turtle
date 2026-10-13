version = 20261013.2000
-- Last edited: see version YYYYMMDD.HHMM
function clear()
	term.clear()
	term.setCursorPos(1, 1)
end

function main()
	clear()
	print("Make sure there is empty space above")
	print("Place gravel into slots 1-15 (slot 16 = fuel)")
	print()
	print("Press Enter when ready")
	read()
	local data = {}
	for slot = 1, 15 do -- slots 1-15; 16 is the fuel slot
		if turtle.getItemCount(slot) > 0 then
			turtle.select(slot)
			data = turtle.getItemDetail(slot)
			if string.find(data.name, "gravel") ~= nil then
				while turtle.placeUp() do
					turtle.digUp()
				end
			end
		end
	end
	for slot = 1, 15 do -- consolidate into slot 1; slot 16 (fuel) untouched
		turtle.select(slot)
		turtle.transferTo(1)
	end
end

main()
