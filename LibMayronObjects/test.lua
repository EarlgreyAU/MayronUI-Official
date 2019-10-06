local function PopTable(...)
	local wrapper = {};
	local arg;
	local length = select("#", ...);

	-- fill wrapper
	for index = 1, length do
		arg = (select(index, ...));

		if (arg ~= nil) then
			wrapper[index] = arg;
		end
	end

	local lastNonNil = 0;
	-- last index value of wrapper cannot be nil (length bug in Lua)
	for currentIndex, _ in pairs(wrapper) do
		if (currentIndex - 1 > lastNonNil) then
			for i = lastNonNil + 1, currentIndex - 1 do
				wrapper[i] = "nil";
			end
		end

		lastNonNil = currentIndex;
	end

	for i, value in ipairs(wrapper) do
		if (value == "nil") then
			wrapper[i] = nil;
		end
	end

	return wrapper;
end

local tbl = PopTable("a", nil, "b")

print(#tbl);

