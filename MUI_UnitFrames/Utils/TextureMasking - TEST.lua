-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

local TextureAnimator = engine:Get("TextureAnimator");

local frame = CreateFrame("Frame", "TestArea_Frame", UIParent);
frame:SetSize(277, 63);
frame:SetPoint("CENTER");

local health = frame:CreateTexture(nil, "ARTWORK");
health:SetAllPoints(true);
health:SetTexture("interface\\addons\\TestArea\\Animated_StatusBar.tga");

local colour = RAID_CLASS_COLORS[(select(2, UnitClass("player")))];
health:SetVertexColor(colour.r, colour.g, colour.b);

local border = frame:CreateTexture(nil, "OVERLAY");
border:SetAllPoints(true);
border:SetTexture("interface\\addons\\TestArea\\UnitFrame_Overlay.tga");

local animator = TextureAnimator(frame, health);
animator:SetTgaFileSize(1024, 1024);
animator:SetGridDimensions(15, 4, 256, 64);
animator:SetFrameRate(24);
animator:SetTextureMask("interface\\addons\\TestArea\\UnitFrame_Mask.tga");

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");

events:SetScript("OnEvent", function(self, _, addonName)
	if (addonName == "TestArea") then

		-- do stuff
		-- MayronTestSV = MayronTestSV or {};
		-- MayronTestSV.results = CreateSequenceAnimator(1024, 1024, 256, 64, 15, 4);
        -- MayronTestSV.texCoords = texCoords;
        animator:Play();

    end
end);

-- function SmoothBar(statusBar,value)
-- 	local limit = 30/GetFramerate()
-- 	local old = statusBar:GetValue()
-- 	local new = old + math.min((value-old)/6, math.max(value-old, limit))
-- 	if new ~= new then
-- 		new = value
-- 	end
-- 	if old == value or abs(new - value) < 0 then
-- 		statusBar:SetValue(value)
-- 	else
-- 		statusBar:SetValue(new)
-- 	end
-- end