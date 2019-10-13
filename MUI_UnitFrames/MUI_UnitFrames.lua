local addOnName, namespace = ...;

-- luacheck: ignore self 143
local _G, MayronUI = _G, _G.MayronUI;
local tk, _, _, _, obj = MayronUI:GetCoreComponents();
local oUF = namespace.oUF or _G.oUF

-- Create Database ---------------------
local db = _G.LibStub:GetLibrary("LibMayronDB"):CreateDatabase(addOnName, "MUI_UnitFramesDb");
MayronUI:AddModuleComponent("UnitFramesModule", "Database", db);

-- Objects -----------------------------

---@type Engine
local Engine = obj:Import("MayronUI.Engine");

---@class UnitFramesModule : BaseModule
local C_UnitFramesModule = MayronUI:RegisterModule("UnitFrames", "Unit Frames");
namespace.C_UnitFramesModule = C_UnitFramesModule;

namespace.styles = obj:PopTable();

-- Load Database Defaults --------------

db:AddToDefaults("profile", {
    __templateUnitFrame = {
        enabled = true;
    };
    frames = { -- to iterate over
        Player = {
			position = {"BOTTOMLEFT", "MUI_ActionBarPanel", "TOPLEFT", 24, 5 }
        };
        Target = {
			position = {"BOTTOMRIGHT", "MUI_ActionBarPanel", "TOPRIGHT", -24, 5 }
        };
    }
});

-- Local Functions -------------

function C_UnitFramesModule:CreateUnitFrames(data)
	data.frames = obj:PopTable();

	for unitName, settings in pairs(data.settings.frames) do
		local C_UnitFrame = Engine:Get(unitName.."UnitFrame");
		local unitFrame = C_UnitFrame(unitName, settings);
		data.frames[unitName:lower()] = unitFrame;

		-- this will trigger the Style callback for that unit
		unitFrame:SetEnabled(true);
	end
end

function C_UnitFramesModule:OnEnable(data)
	-- this is called after CreateUnitFrame so data.frames will be filled
	oUF:RegisterStyle("MayronUI", function(frame, unitName)
		if (not unitName) then
			return;
		end

		local unitFrame = data.frames[unitName];
		unitFrame:ApplyStyle(frame);

		return frame;
	end);

	oUF:SetActiveStyle("MayronUI");
	self:CreateUnitFrames();
end

-- C_UnitFramesModule -----------------------
function C_UnitFramesModule:OnInitialize(data)

	for name, _ in db.profile.frames:Iterate() do
		local sv = db.profile.frames[name];
		sv:SetParent(db.profile.__templateField);
	end

	data.options = {
        onExecuteAll = {
            ignore = {
                "enabled";
            };
        };

        groups = {
            {
                patterns = { "frames%.[^.]+%.[^.]+" }; -- (i.e. "fields.Player.<setting>")

                onPre = function(value, keysList)
                    -- keysList:PopFront();
                    -- local unitName = keysList:PopFront();
                    -- local unitFrame = data.frames[unitName];
                    -- local settingName = keysList:GetFront();

                    -- this is where we create a TimerField if it is enabled
                    -- if (obj:IsBoolean(unitFrame)) then
                    --     if (not (field or (settingName == "enabled" and value))) then
                    --         -- if not trying to enable a field because it is disabled, then do not continue
                    --         return nil;
                    --     end

                    --     -- create field (it is enabled)
                    --     field = C_TimerField(fieldName, data.settings);
                    --     data.fields[fieldName] = field; -- replace "true" with real object
                    -- end

                    -- return field, fieldName;
                end;

                value = {
                    enabled = function(value, _, unitFrame)
                        -- unitFrame:SetEnabled(value);
                    end;
                };
            };
        };
    };

    self:RegisterUpdateFunctions(db.profile, {});
	self:SetEnabled(true);
end

-- Colors: ----------------

oUF.colors.disconnected = {
	0.1, 0.1, 0.1
}

oUF.colors.reaction = {
	[1] = { 0.87, 0.37, 0.37 }, -- Hated
	[2] = { 0.87, 0.37, 0.37 }, -- Hostile
	[3] = { 0.87, 0.37, 0.37 }, -- Unfriendly
	[4] = { 0.85, 0.77, 0.36 }, -- Neutral
	[5] = { 0.29, 0.67, 0.30 }, -- Friendly
	[6] = { 0.29, 0.67, 0.30 }, -- Honored
	[7] = { 0.29, 0.67, 0.30 }, -- Revered
	[8] = { 0.29, 0.67, 0.30 }, -- Exalted
}

oUF.colors.power = {
	["MANA"]              = {0.31, 0.45, 0.63},
	["RAGE"]              = {0.69, 0.31, 0.31},
	["ENERGY"]            = {0.65, 0.63, 0.35},
	["FOCUS"]             = {0.71, 0.43, 0.27},
	["AMMOSLOT"]          = {0.80, 0.60, 0.00},
}