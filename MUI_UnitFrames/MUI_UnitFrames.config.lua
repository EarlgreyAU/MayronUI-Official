-- luacheck: ignore MayronUI self 143 631
local _, namespace = ...;

local _G = _G;
local tonumber, ipairs, MayronUI = _G.tonumber, _G.ipairs, _G.MayronUI;
local tk, db, _, _, obj, L = MayronUI:GetCoreComponents();
local C_UnitFramesModule = namespace.C_UnitFramesModule;

function C_UnitFramesModule:GetConfigTable(data)
    return {
        name = "Unit Frames",
        type = "menu",
        module = "UnitFramesModule",
        children =  {
            {   type = "loop";
                args = {  }, -- get list of unit frames to go here, e.g. { "Player", "Target" }
                func = function(_, name)
                    -- local statusBarsEnabled = data.settings[name].statusBars.enabled;

                    local tbl = {
                        type = "submenu",
                        name = name;
                        dbPath = "profile.unitFrames."..name,

                        OnLoad = function()
                            -- position_TextFields[name] = obj:PopTable();
                        end;

						children = {}
					};

                    return tbl;
                end;
            };
        }
    };
end