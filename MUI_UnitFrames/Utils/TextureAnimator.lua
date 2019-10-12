-- luacheck: ignore self 143
local _, _, _, _, obj = _G.MayronUI:GetCoreComponents();

-- Objects -----------------------------

---@class UnitFrameUtils : Package
local Utils = obj:CreatePackage("UnitFrameUtils", "MayronUI");

---@class TextureAnimator : Object
local C_TextureAnimator = Utils:CreateClass("TextureAnimator");

local UnitHealth, UnitHealthMax, unpack = _G.UnitHealth, _G.UnitHealthMax, _G.unpack;

-- Local Functions --------------------
local function GenerateCoords(data)
    local numFrames = data.rows * data.columns;
	local coords = {};

	local widthRatio = data.cellWidth / data.tgaWidth; -- 0.25
	local heightRatio = data.cellHeight / data.tgaHeight; -- 0.0625

	for i = 1, numFrames do
		local rowNum = (math.ceil(i / data.columns)) - 1;
		local colNum = i % data.columns;

		colNum = ((colNum > 0) and colNum or data.columns) - 1;
		coords[i] = {};

		coords[i][1] = 0.00 + (widthRatio * colNum); -- left
		coords[i][2] = widthRatio + (widthRatio * colNum); -- right

		coords[i][3] = 0.00 + (heightRatio * rowNum); -- top
		coords[i][4] = heightRatio + (heightRatio * rowNum); -- bottom
	end

	data.coords = coords;
end

local function AnimateTexture(data, elapsed)
    data.amount = data.amount + elapsed;

    if (data.amount >= data.frameRate) then
        data.index = data.index + 1;
        data.amount = 0;

        if (data.index > #data.coords)then
            data.index = 1;
        end

        if (data.statusBar:IsVisible()) then
            local left, right, top, bottom = unpack(data.coords[data.index]); -- 0 to 1
            data.fill:SetTexCoord(left, right, top, bottom);

            local width = data.statusBar:GetStatusBarTexture():GetWidth();
            data.mask:SetWidth(width);
        end
    end
end

-- C_TextureAnimator --------------------

Utils:DefineParams("StatusBar", "MaskTexture", "Texture");
function C_TextureAnimator:__Construct(data, statusBar, mask, fill)
    data.statusBar = statusBar;
    data.mask = mask;
    data.fill = fill;
end

Utils:DefineParams("number", "number");
function C_TextureAnimator:SetTgaFileSize(data, width, height)
    data.tgaWidth = width;
    data.tgaHeight = height;
end

Utils:DefineParams("number", "number","number", "number");
function C_TextureAnimator:SetGridDimensions(data, rows, columns, cellWidth, cellHeight)
    data.rows = rows;
    data.columns = columns;
    data.cellWidth = cellWidth;
    data.cellHeight = cellHeight;
end

Utils:DefineParams("number");
function C_TextureAnimator:SetFrameRate(data, frameRate)
    data.frameRate = 1 / frameRate;
    data.amount = 0;
    data.index = 1;
end

function C_TextureAnimator:Play(data)
    obj:Assert(data.frameRate, "Framerate not set.");
    GenerateCoords(data);

    data.statusBar:SetScript("OnUpdate", function(self, elapsed)
        AnimateTexture(data, elapsed);
    end);
end

function C_TextureAnimator:Stop(data)
    data.coords = nil;
    data.statusBar:SetScript("OnUpdate", nil);
end