-- luacheck: ignore MayronUI self 143 631
local Lib = _G.LibStub:NewLibrary("LibMayronDB", 2.2);
local obj = _G.LibStub:GetLibrary("LibMayronObjects");

if (not Lib or not obj) then return; end

local Framework = obj:CreatePackage("LibMayronDB");
local Database = Framework:CreateClass("Database");
local Observer = Framework:CreateClass("Observer");
local Helper = Framework:CreateClass("Helper");

Observer.Static:AddFriendClass("Helper");

local select, tonumber, strsplit = select, tonumber, _G.strsplit;

local OnAddOnLoadedListener = _G.CreateFrame("Frame");
OnAddOnLoadedListener:RegisterEvent("ADDON_LOADED");
OnAddOnLoadedListener.RegisteredDatabases = obj:PopWrapper();

OnAddOnLoadedListener:SetScript("OnEvent", function(self, _, addOnName)
    local database = OnAddOnLoadedListener.RegisteredDatabases[addOnName];

    if (database) then
        database:Start();
    end
end);

local function GetNextPath(path, key)
    if (path ~= nil) then
        if (tonumber(key)) then
            return string.format("%s[%s]", path, key);
        else
            return string.format("%s.%s", path, key);
        end
    else
        if (tonumber(key)) then
            key = string.format("[%s]", key);
        end

        return key;
    end
end

local function Equals(value1, value2, shallowEquals)
    local type1 = type(value1);

    if (type(value2) == type1) then

        if (type1 == "table") then

            if (tostring(value1) == tostring(value2)) then
                return true;
            elseif (shallowEquals) then
                return false;
            else
                for id, value in pairs(value1) do
                    if (not Equals(value, value2[id])) then
                        return false;
                    end
                end
            end

            return true;
        elseif (type1 == "function") then
            return tostring(value1) == tostring(value2);
        else
            return value1 == value2;
        end
    end

    return false;
end

local function IsObserver(value)
    return (type(value) == "table" and value.IsObjectType and value:IsObjectType("Observer"));
end

local function GetDatabasePathInfo(db, rootTableOrPath, pathOrValue, value)
    local rootTable, path;

    if (type(rootTableOrPath) == "table") then
        rootTable = rootTableOrPath;
        path = pathOrValue;
    else
        local rootTableType, realPath = rootTableOrPath:match("([^.]+).(.*)");
        rootTableType = rootTableType:gsub("%s", ""):lower();

        path = realPath;
        value = pathOrValue;

        if (rootTableType == "global") then
            rootTable = db.global;
        elseif (rootTableType == "profile") then
            rootTable = db.profile;
        end
    end

    return rootTable, path, value;
end

------------------------
-- Database API
------------------------
--[[
Creates the database but does not initialize it until after "ADDON_LOADED" event (unless manualStartUp is set to true).

@param (string) addOnName: The name of the addon to listen out for. If supplied it will start the database
    automatically after the ADDON_LOADED event has fired (when the saved variable becomes accessible).
@param (string) savedVariableName: The name of the saved variable to hold the database (defined in the toc file).
@param (optional | boolean) manualStartUp: Set to true if you do not want the library to automatically start
    the database when the saved variable becomes accessible.

@return (Database): The database object.
]]
function Lib:CreateDatabase(addOnName, savedVariableName, manualStartUp)
    local database = Database(addOnName, savedVariableName);

    if (not manualStartUp) then
        if (_G[savedVariableName]) then
            -- already loaded
            database:Start();
        else
            -- register to start when ready
            OnAddOnLoadedListener.RegisteredDatabases[addOnName] = database;
        end
    end

    return database;
end

--[[
Do NOT call this manually! Should only be called by Lib:CreateDatabase(...)
]]
Framework:DefineParams("string", "string");
function Database:__Construct(data, addOnName, savedVariableName)
    data.addOnName = addOnName;
    data.svName = savedVariableName;
    data.callbacks = obj:PopWrapper();
    data.helper = Helper(self, data);

    -- holds all database defaults to check first before searching database
    data.defaults = obj:PopWrapper();
    data.defaults.global = obj:PopWrapper();
    data.defaults.profile = obj:PopWrapper();
end

--[[
Hooks a callback function onto the "StartUp" event to be called when the database starts up
(i.e. when the saved variable becomes accessible). By default, this function is called by the library
with 2 arguments: the database and the addOn name passed to Lib:CreateDatabase(...).

@param (function) callback: The start up callback function
]]
Framework:DefineParams("function");
function Database:OnStartUp(data, callback)
    local startUpCallbacks = data.callbacks["OnStartUp"] or obj:PopWrapper();
    data.callbacks["OnStartUp"] = startUpCallbacks;

    table.insert(startUpCallbacks, callback);
end

--[[
Hooks a callback function onto the "ProfileChanged" event to be called when the database changes profile
(i.e. only changed by the user using db:SetProfile() or db:RemoveProfile(currentProfile)).

@param (function) callback: The profile changing callback function
]]
Framework:DefineParams("function");
function Database:OnProfileChange(data, callback)
    local profileChangedCallback = data.callbacks["OnProfileChange"] or obj:PopWrapper();
    data.callbacks["OnProfileChange"] = profileChangedCallback;

    table.insert(profileChangedCallback, callback);
end

--[[
Starts the database. Should only be used when the saved variable is accessible (after the ADDON_LOADED event has fired).
This is called automatically by the library when the saved variable becomes accessible unless manualStartUp was
set to true during the call to Lib:CreateDatabase(...).
]]
function Database:Start(data)
    if (data.loaded) then
        -- previously started and loaded
        return;
    end

    OnAddOnLoadedListener.RegisteredDatabases[data.addOnName] = nil;

    -- create Saved Variable if it has never been created before
    _G[data.svName] = _G[data.svName] or obj:PopWrapper();
    data.sv = _G[data.svName];
    data.svName = nil; -- no longer needed once it is loaded

    -- create root profiles table if it does not exist
    data.sv.profiles = data.sv.profiles or obj:PopWrapper();

    -- create root global table if it does not exist
    data.sv.global = data.sv.global or obj:PopWrapper();

    -- create profileKeys table if it does not exist
    data.sv.profileKeys = data.sv.profileKeys or obj:PopWrapper();

    -- create appended table if it does not exist
    data.sv.appended = data.sv.appended or obj:PopWrapper();

    -- create Default profile if it does not exist
    data.sv.profiles.Default = data.sv.profiles.Default or obj:PopWrapper();

    -- create Profile and Global accessible observers:

    self.profile = Observer(false, data);
    self.global = Observer(true, data);

    data.loaded = true;

    if (data.callbacks["OnStartUp"]) then
        for _, callback in ipairs(data.callbacks["OnStartUp"]) do
            callback(self, data.addOnName);
        end
    end

    data.callbacks["OnStartUp"] = nil;
end

--[[
Returns true if the database has been successfully started and loaded.

@return (boolean): indicates if the database is loaded.
]]
Framework:DefineReturns("boolean");
function Database:IsLoaded(data)
    return data.loaded == true;
end

--[[
Adds a value to the database defaults table relative to the path: defaults.<path> = <value>

@param (string): a database path string, such as "myTable.mySubTable[2]"
@param (any): a value to assign to the database defaults table using the path
]]
Framework:DefineParams("string", "?any");
function Database:AddToDefaults(data, path, value)
    self:SetPathValue(data.defaults, path, value);
end

--[[
Adds a value to a table relative to a path: rootTable.<path> = <value>

@param (table or string) rootTableOrPath: The initial root table to search from OR a string that starts with
    "global" or "profile" so that the rootTable can be calculated.
@param (optional any) pathOrValue: a table path string (also called a path address) such as "myTable.mySubTable[2]"
    OR if rootTable is a string representing the path then this is the value argument.
    If it is the path then this is converted to a sequence of tables which are added to the
    database if they do not already exist (myTable will be created if not found).
@param (optional any): a value to assign to the table relative to the provided path string (is nil if the path argument is the value)
]]
Framework:DefineParams("table|string");
function Database:SetPathValue(data, rootTableOrPath, pathOrValue, value)
    local rootTable, path, realValue = GetDatabasePathInfo(self, rootTableOrPath, pathOrValue, value);

    if (rootTable.GetObjectType and rootTable:GetObjectType() == "Observer") then
        rootTable = rootTable:ToSavedVariable();
    end

    local lastTable, lastKey = data.helper:GetLastTableKeyPairs(rootTable, path);

    assert(type(lastTable) == "table" and (type(lastKey) == "string" or type(lastKey) == "number"),
        "Database:SetPathValue failed to set value");

    lastTable[lastKey] = realValue;
end

--[[
Searches a path address (table path string) and returns the located value if found.

@param (table or string) rootTableOrPath: The root table to begin searching through using the path address.
    OR a string that starts with "global" or "profile" so that the rootTable can be calculated.
@param (string) path: The path of the value to search for. Example: "myTable.mySubTable[2]"
    OR if rootTableOrPath is a string representing the path then this is nil.
@return (any): The value found at the location specified by the path address.
Might return nil if the path address is invalid, or no value is located at the address.

Example: value = db:ParsePathValue(db.profile, "mySettings[" .. moduleName .. "][5]");
]]
Framework:DefineParams("table|string", "?string");
function Database:ParsePathValue(_, rootTableOrPath, pathOrNil)
    local rootTable, path = GetDatabasePathInfo(self, rootTableOrPath, pathOrNil);

    for _, key in obj:IterateArgs(strsplit(".", path)) do

        if (rootTable == nil or type(rootTable) ~= "table") then
            break;
        end

        if (tonumber(key)) then
            key = tonumber(key);
            rootTable = rootTable[key];
        else
            local indexes;

            if (key:find("%b[]")) then
                indexes = {};
                for index in key:gmatch("(%b[])") do
                    index = index:match("%[(.+)%]");
                    table.insert(indexes, index);
                end
            end

            key = strsplit("[", key);

            if (#key > 0) then
                rootTable = rootTable[key];
            end

            if (indexes and type(rootTable) == "table") then
                for _, indexKey in ipairs(indexes) do
                    indexKey = tonumber(indexKey) or indexKey;
                    rootTable = rootTable[indexKey];

                    if (rootTable == nil or type(rootTable) ~= "table") then
                        break;
                    end
                end
            end
        end
    end

    return rootTable;
end

--[[
Sets the addon profile for the currently logged in character.
Creates a new profile if the named profile does not exist.

@param (string) name: The name of the profile to assign to the character.
]]
Framework:DefineParams("string");
function Database:SetProfile(data, profileName)
    local profile = data.sv.profiles[profileName] or obj:PopWrapper();
    data.sv.profiles[profileName] = profile;

    local profileKey = data.helper:GetCurrentProfileKey();
    local oldProfileName = data.sv.profileKeys[profileKey] or "Default";

    data.sv.profileKeys[profileKey] = profileName;

    if (data.callbacks["OnProfileChange"]) then
        for _, callback in ipairs(data.callbacks["OnProfileChange"]) do
            callback(self, profileName, oldProfileName);
        end
    end
end

--[[
@return (string): The current profile associated with the currently logged in character.
]]
Framework:DefineReturns("string");
function Database:GetCurrentProfile(data)
    local profileKey = data.helper:GetCurrentProfileKey();
    return data.sv.profileKeys[profileKey] or "Default";
end

--[[
@return (table): A table containing string profile names for all profiles associated with the addon.
--]]
function Database:GetProfiles(data)
    local profiles = obj:PopWrapper();

    for profileName, _ in pairs(data.sv.profiles) do
        table.insert(profiles, profileName);
    end

    return profiles;
end

--[[
Usable in a for loop to loop through all profiles associated with the AddOn.
Each loop returns values: id, profileName, profile

    - (int) id: current loop iteration
    - (string) profileName: the name of the profile
    - (table) profile: the profile data
]]
function Database:IterateProfiles(data)
    local id = 0;
    local profileNames = obj:PopWrapper();

    for name, _ in pairs(data.sv.profiles) do
        table.insert(profileNames, name);
    end

    return function()
        id = id + 1;

        if (id <= #profileNames) then
            return id, profileNames[id], data.sv.profiles[profileNames[id]];
        end
    end
end

--[[
@return (int): The number of profiles associated with the database.
]]
Framework:DefineReturns("number");
function Database:GetNumProfiles(data)
    local n = 0;

    for _ in pairs(data.sv.profiles) do
        n = n + 1;
    end

    return n;
end

--[[
Helper function to reset a profile.

@param (string) name: The name of the profile to reset.
]]
Framework:DefineParams("string");
function Database:ResetProfile(_, profileName)
    self:RemoveProfile(profileName);
    self:SetProfile(profileName);
end

--[[
Moves the profile to the bin. The profile cannot be accessed from the bin.
Use db:RestoreProfile(profileName) to restore the profile.

@param (string) profileName: The name of the profile to move to the bin.
@return (boolean): Returns true if the profile was changed due to removing the current profile
]]
Framework:DefineParams("string");
Framework:DefineReturns("boolean");
function Database:RemoveProfile(data, profileName)
     if (data.sv.profiles[profileName]) then

        data.bin = data.bin or {};
        data.bin[profileName] = data.sv.profiles[profileName];
        data.sv.profiles[profileName] = nil;

        if (self:GetCurrentProfile() == profileName) then
            self:SetProfile("Default");
            return true;
        end
    end

    return false;
end

--[[
Profiles will remain in the bin until a reload of the UI occurs.
If the bin contains a profile, this function can restore it.

@param (string) name: The name of the profile located inside the bin.
]]
Framework:DefineParams("string");
Framework:DefineReturns("boolean");
function Database:RestoreProfile(data, profileName)
    if (data.bin) then
        local profile = data.bin[profileName];

        if (profile) then
            profileName = data.helper:GetNewProfileName(profileName, data.sv.profiles);
            data.sv.profiles[profileName] = profile;
            data.bin[profileName] = nil;

            return true;
        end
    end

    return false;
end

--[[
Gets all profiles that can be restored from the bin
@return (table): An index table containing the names of all profiles in the bin
]]
Framework:DefineReturns("table");
function Database:GetProfilesInBin(data)
    local profilesInBin = {};

    if (data.bin) then
        for profileName, _ in pairs(data.bin) do
            table.insert(profilesInBin, profileName);
        end
    end

    return profilesInBin;
end

--[[
Renames an existing profile to a new profile name. If the new name already exists, it appends a number
to avoid clashing: 'example (2)'.

@param (string) oldProfileName: The old profile name.
@param (string) newProfileName: The new profile name.
]]
Framework:DefineParams("string", "string");
function Database:RenameProfile(data, oldProfileName, newProfileName)
    newProfileName = data.helper:GetNewProfileName(newProfileName, data.sv.profiles);
    local profile = data.sv.profiles[oldProfileName];

    data.sv.profiles[oldProfileName] = nil;
    data.sv.profiles[newProfileName] = profile;

    local currentProfileKey = data.helper:GetCurrentProfileKey();

    for profileKey, profileName in pairs(data.sv.profileKeys) do
        if (profileName == oldProfileName) then
            data.sv.profileKeys[profileKey] = newProfileName;

            if (profileKey == currentProfileKey) then
                if (data.callbacks["OnProfileChange"]) then
                    for _, value in ipairs(data.callbacks["OnProfileChange"]) do
                        local callback = value[1];
                        callback(newProfileName, select(2, _G.unpack(value)));
                    end
                end
            end
        end
    end
end

--[[
Adds a new value to the saved variable table only once. Registers the added value with a registration key.

@param (Observer) rootTable: The root database table (observer) to append the value to relative to the path address provided.
@param (string) path: The path address to specify where the value should be appended to.
@param (any) value: The value to be added.
@return (boolean): Returns whether the value was successfully added.
]]
Framework:DefineParams("Observer", "string", "any");
Framework:DefineReturns("boolean");
function Database:AppendOnce(data, rootTable, path, value)
    local tableType = data.helper:GetDatabaseRootTableName(rootTable);

    local appendTable = data.sv.appended[tableType] or obj:PopWrapper();
    data.sv.appended[tableType] = appendTable;

    if (appendTable[path]) then
        -- already previously appended, cannot append again
        return false;
    end

    self:SetPathValue(rootTable, path, value);
    appendTable[path] = true;

    return true;
end

-------------------------
-- Observer Class:
-------------------------

--[[
Do NOT call this manually! Should only be called by the library to create a new
observer that controls a database table.
]]
Framework:DefineParams("boolean", "table");
function Observer:__Construct(data, isGlobal, previousData)
    data.isGlobal = isGlobal;
    data.helper = previousData.helper;
    data.sv = previousData.sv;
    data.defaults = previousData.defaults;
    data.internalTree = obj:PopWrapper();
    data.database = data.helper:GetDatabase();
end

--[[
When a new value is being added to the database, use the child observer's table if
switched to using a parent observer. Also, add to the saved variable table if not a function.
]]
Observer.Static:OnIndexChanging(function(_, data, key, value)
    data.helper:HandlePathValueChange(data, key, value);
    return true; -- prevent indexing
end);

--[[
Pick from Observer's saved variable table, else parent table if not found, else defaults table.
]]
Observer.Static:OnIndexed(function(self, data, key, realValue)
    if (realValue ~= nil) then
        return realValue; -- it is an observer object value
    end

    local foundValue;
    local svTable = self:ToSavedVariable();

    if (svTable) then
        -- convert saved variable table into an Observer
        foundValue = data.helper:GetNextValue(data, svTable, key);
    end

    -- check parent if still not found
    if (foundValue == nil) then
        if (data.parent) then
            local parentSvTable = data.parent:ToSavedVariable();

            if (parentSvTable ~= nil) then
                local parentData = data:GetFriendData(data.parent);

                data.helper:SetUsingChild(data.isGlobal, data.path, data.parent);
                -- it is possible to not have a svTable (might be dependent on defaults table)
                foundValue = data.helper:GetNextValue(parentData, parentSvTable, key);
            end
        end
    end

    -- check own defaults table if still not found
    if (foundValue == nil) then
        local defaults = self:GetDefaults();

        if (defaults) then
            foundValue = data.helper:GetNextValue(data, defaults, key);
        end
    end

    if (foundValue == nil and data.parent) then
        -- check parent's defaults table before own defaults table
        local defaults = data.parent:GetDefaults();

        if (defaults ~= nil) then
            local parentData = data:GetFriendData(data.parent);
            foundValue = data.helper:GetNextValue(parentData, defaults, key);
        end
    end

    return foundValue;
end);

--[[
Used to achieve database inheritance. If an observer cannot find a value, it uses the value found in the
parent table. Useful if many separate tables in the saved variables table should use the same set of
changable values when the defaults table is not a suitable solution.

@param (optional | Observer) parentObserver: Which observer should be used as the parent.
    If this is nil, the parent is removed.
Example: db.profile.aFrame:SetParent(db.global.frameTemplate)
]]
Framework:DefineParams("?Observer");
function Observer:SetParent(data, parentObserver)
    data.parent = parentObserver;
end

--[[
@return (Observer): Returns the current Observer's parent.
]]
Framework:DefineReturns("?Observer");
function Observer:GetParent(data)
    return data.parent;
end

--[[
@return (boolean): Returns true if the current Observer has a parent.
]]
Framework:DefineReturns("boolean");
function Observer:HasParent(data)
    return data.parent ~= nil;
end

do
    local function Merge(mergeTable, tbl)
        for key, value in pairs(tbl) do
            if (mergeTable[key] == nil) then
                -- only add to mergeTable if value does not already exist
                if (type(value) == "table") then
                    mergeTable[key] = obj:PopWrapper();
                    Merge(mergeTable[key], value);

                else
                    mergeTable[key] = value;
                end
            end
        end
    end

    local trackerMT = {};

    local function SaveChanges(self)
        local totalChanges = 0;
        local tracker = self.__tracker;

        for dbPath, value in pairs(tracker.changes) do
            if (value == "nil") then
                value = nil;
            end

           tracker.database:SetPathValue(dbPath, value);
           totalChanges = totalChanges + 1;
        end

        obj:PushWrapper(tracker.changes);
        return totalChanges;
    end

    local function CreateTracker(key, tbl, database, previousTracker)
        local proxyTracker = obj:PopWrapper();
        local tracker = obj:PopWrapper();

        proxyTracker.__tracker = tracker;

        if (previousTracker) then
            tracker.dbPath = string.format("%s.%s", previousTracker.dbPath, key);
            tracker.changes = previousTracker.changes;
        else
            tracker.dbPath = key;
            tracker.changes = obj:PopWrapper();
        end

        tracker.database = database;
        tracker.data = tbl;
        proxyTracker.SaveChanges = SaveChanges;

        return setmetatable(proxyTracker, trackerMT);
    end

    trackerMT.__index = function(self, key)
        local tracker = self.__tracker;
        local nextValue = tracker.data[key];

        if (type(nextValue) == "table") then
            return CreateTracker(key, nextValue, tracker.database, tracker);
        else
            return nextValue;
        end
    end

    trackerMT.__newindex = function(self, key, value)
        local tracker = self.__tracker;
        local dbPath = string.format("%s.%s", tracker.dbPath, key);
        local currentValue = tracker.data[key];

        if (currentValue ~= nil and value == nil) then
            tracker.changes[dbPath] = "nil";

        elseif (not Equals(currentValue, value)) then
            tracker.changes[dbPath] = value;
        end
    end

    --[[
    Creates an immutable table containing all values from the underlining saved variables table,
    parent table, and defaults table. Changing this table will not affect the saved variables table!

    @return (table): a table containing all merged values
    ]]
    Framework:DefineReturns("table");
    function Observer:ToTable(data)
        local merged = obj:PopWrapper();
        local svTable = self:ToSavedVariable();
        local defaults = self:GetDefaults();

        if (svTable) then
            Merge(merged, svTable);
        end

        if (defaults) then
            Merge(merged, defaults);
        end

        if (data.parent) then
            local parentTable = data.parent:ToSavedVariable();

            if (parentTable) then
                Merge(merged, parentTable);
            end
        end

        return CreateTracker(data.path, merged, data.database);
    end
end

--[[
Gets the underlining saved variables table. Default or parent values will not be included in this!

@return (table): the underlining saved variables table.
]]
function Observer:ToSavedVariable(data)
    local rootTable;

    if (data.isGlobal) then
        rootTable = data.sv.global;
    else
        local currentProfile = data.database:GetCurrentProfile();
        rootTable = data.sv.profiles[currentProfile];
    end

    if (data.path) then
        rootTable = data.database:ParsePathValue(rootTable, data.path);
    end

    return rootTable;
end

--[[
Gets the underlining saved variables table. Default or parent values will not be included in this!

@return (table): the underlining saved variables table.
]]
function Observer:GetDefaults(data)
    local rootTable;

    if (data.isGlobal) then
        rootTable = data.defaults.global;
    else
        rootTable = data.defaults.profile;
    end

    if (data.path) then
        return data.database:ParsePathValue(rootTable, data.path);
    end

    return rootTable;
end

--[[
Usable in a for loop. Uses the merged table to iterate through key and value pairs of the default and
saved variable table paired together using the Observer path address.

Example:
    for key, value in db.profile.aModule:Iterate() do
        print(string.format("%s : %s", key, value))
    end
]]
function Observer:Iterate()
    local merged = self:ToTable();
    return next, merged, nil;
end

--[[
@return (boolean): Whether the merged table is empty.
]]
Framework:DefineReturns("boolean");
function Observer:IsEmpty()
    return self:GetLength() == 0;
end

--[[
A helper function to print all contents of a table pointed to by the selected Observer.

@param (optional | int) depth: The depth of tables to print before only printing table references.

Example: db.profile.aModule:Print()
]]
Framework:DefineParams("?number");
function Observer:Print(data, depth)
    local merged = self:ToTable();
    local tablePath = data.helper:GetDatabaseRootTableName(self);
    local path = (data.usingChild and data.usingChild.path) or data.path;

    if (path ~= nil) then
        tablePath = string.format("%s.%s", tablePath, path);
    end

    print(" ");
    print(string.format("db.%s = {", tablePath));
    data.helper:PrintTable(merged, depth, 4);
    print("};");
    print(" ");
end

--[[
@return (int): The length of the merged table (Observer:ToTable()).
]]
Framework:DefineReturns("number");
function Observer:GetLength()
    local length = 0;

    for _, _ in self:Iterate() do
        length = length + 1;
    end

    return length;
end

--[[
Helper function to return the path address of the observer.
@return (string): The path address
]]
Framework:DefineReturns("?string");
function Observer:GetPathAddress(data)
    return data.path;
end
-------------------------------------------------
-- Helper Class (only for Library developers)
-------------------------------------------------
Framework:DefineParams("Database", "table");
function Helper:__Construct(data, database, databaseData)
    data.database = database;
    data.dbData = databaseData;
end

Framework:DefineReturns("Database");
function Helper:GetDatabase(data)
    return data.database;
end

do
    local function GetNextTable(tbl, key, parsing)
        local previous = tbl;

        if (tbl[key] == nil) then
            if (parsing) then return nil; end
            tbl[key] = obj:PopWrapper();
        end

        return previous, tbl[key];
    end

    local function IsEmpty(tbl)
        if (tbl == nil) then
            return true;
        end

        for _, value in pairs(tbl) do
            if (type(value) ~= "table" or not IsEmpty(value)) then
                return false;
            end
        end

        return true;
    end

    Framework:DefineParams("table", "string", "?boolean", "?boolean");
    function Helper:GetLastTableKeyPairs(_, rootTable, path, cleaning)
        local nextTable = rootTable;
        local lastTable, lastKey;

        for _, key in obj:IterateArgs(strsplit(".", path)) do
            if (tonumber(key)) then
                key = tonumber(key);
                lastKey = key;
                lastTable, nextTable = GetNextTable(nextTable, key);

                if (cleaning and IsEmpty(nextTable)) then
                    if (type(lastTable) == "table") then
                        lastTable[lastKey] = nil;
                    end
                    return nil;
                end

            elseif (key ~= "db") then
                local indexes;

                if (key:find("%b[]")) then
                    indexes = obj:PopWrapper();

                    for index in key:gmatch("(%b[])") do
                        index = index:match("%[(.+)%]");
                        table.insert(indexes, index);
                    end
                end

                key = strsplit("[", key);

                if (#key > 0) then
                    lastKey = key;
                    lastTable, nextTable = GetNextTable(nextTable, key);

                    if (cleaning and IsEmpty(nextTable)) then
                        if (type(lastTable) == "table") then
                            lastTable[lastKey] = nil;
                        end
                        return nil;
                    end
                end

                if (indexes) then
                    for _, indexKey in ipairs(indexes) do
                        indexKey = tonumber(indexKey) or indexKey;
                        lastKey = indexKey;
                        lastTable, nextTable = GetNextTable(nextTable, indexKey);

                        if (cleaning and IsEmpty(nextTable)) then
                            if (type(lastTable) == "table") then
                                lastTable[lastKey] = nil;
                            end

                            return nil;
                        end
                    end

                    obj:PushWrapper(indexes);
                end
            end
        end

        return lastTable, lastKey;
    end
end

Framework:DefineParams("string", "table");
Framework:DefineReturns("string");
function Helper:GetNewProfileName(_, oldProfileName, profilesTable)
    local newProfileName = oldProfileName;
    local n = 2;

    while (profilesTable[newProfileName]) do
        -- if it exists in table, we need a new name to avoid name clashes
        newProfileName = string.format("%s (%i)", oldProfileName, n);
        n = n + 1;
    end

    return newProfileName;
end

Framework:DefineReturns("string");
function Helper:GetCurrentProfileKey()
    local playerName = _G.UnitName("player");
    local realm = _G.GetRealmName():gsub("%s+", "");

    return string.join("-", playerName, realm);
end

Framework:DefineParams("table", "table", "any") -- should be string or number
function Helper:GetNextValue(data, previousObserverData, tbl, key)
    --tbl could be sv or defaults table
    local nextValue = tbl[key];

    if (type(nextValue) ~= "table") then
        return nextValue;
    end

    local nextObserver = nextValue;

    if (not IsObserver(nextObserver)) then
        nextObserver = previousObserverData.internalTree[key];

        if (not nextObserver) then
            nextObserver = Observer(previousObserverData.isGlobal, previousObserverData);
        end

        previousObserverData.internalTree[key] = nextObserver;
    end

    -- get next observer data and set next path (needs to be updated if from internalTree)
    local nextPath = GetNextPath(previousObserverData.path, key);
    local nextObserverData = data:GetFriendData(nextObserver);
    nextObserverData.path = nextPath;

    -- get next child path in use
    if (previousObserverData.usingChild) then
        local nextChildPath = GetNextPath(previousObserverData.usingChild.path, key);
        self:SetUsingChild(previousObserverData.usingChild.isGlobal, nextChildPath, nextObserver);
    else
        obj:PushWrapper(nextObserverData.usingChild);
        nextObserverData.usingChild = nil;
    end

    return nextObserver;
end

Framework:DefineParams("table", "?number");
function Helper:PrintTable(_, tbl, depth, n)
    n = n or 0;
    depth = depth or 4;

    if (depth == 0) then
        return
    end

    if (n == 0) then
        print(" ");
    end

    for key, value in pairs(tbl) do
        if (key and type(key) == "number" or type(key) == "string") then
            key = string.format("[\"%s\"]", key);

            if (type(value) == "table") then
                print(string.rep(' ', n)..key.." = {");
                self:PrintTable(value, depth - 1, n + 4);
                print(string.rep(' ', n).."},");
            else
                if (type(value) == "string") then
                    value = string.format("\"%s\"", value);
                else
                    value = tostring(value);
                end

                print(string.rep(' ', n)..key.." = "..value..",");
            end
        end
    end

    if (n == 0) then
        print(" ");
    end
end

Framework:DefineParams("Observer");
Framework:DefineReturns("string");
function Helper:GetDatabaseRootTableName(data, observer)
    local observerData = data:GetFriendData(observer);

    if (observerData.isGlobal) then
        return "global";
    end

    local currentProfile = data.database:GetCurrentProfile();

    if (currentProfile:find("%s+")) then
        -- has spaces
        return string.format("profile['%s']", currentProfile);
    else
        return string.format("profile.%s", currentProfile);
    end
end

Framework:DefineParams("table", "any", "?any");
function Helper:HandlePathValueChange(data, observerData, key, value)
    local path;
    local defaultRootTable;
    local svRootTable;
    local isGlobal;

    if (observerData.usingChild) then
        path = observerData.usingChild.path;
        isGlobal = observerData.usingChild.isGlobal;
    else
        path = observerData.path;
        isGlobal = observerData.isGlobal;
    end

    if (isGlobal) then
        defaultRootTable = data.dbData.defaults.global;
        svRootTable = data.dbData.sv.global;
    else
        defaultRootTable = data.dbData.defaults.profile;
        svRootTable = data.database.profile:ToSavedVariable();
    end

    local indexingPath = GetNextPath(path, key);
    local defaultValue = data.database:ParsePathValue(defaultRootTable, indexingPath);

    if (not Equals(defaultValue, value)) then
        -- different from default value so add it
        data.database:SetPathValue(svRootTable, indexingPath, value);
    else
        -- same as default value so remove it from saved variables table
        data.database:SetPathValue(svRootTable, indexingPath, nil);
        self:GetLastTableKeyPairs(svRootTable, indexingPath, true, true); -- clean
    end
end

Framework:DefineParams("boolean", "string", "Observer");
function Helper:SetUsingChild(data, isGlobal, path, parentObserver)
    local parentObserverData = data:GetFriendData(parentObserver);
    local usingChild = parentObserverData.usingChild or obj:PopWrapper();

    usingChild.isGlobal = isGlobal;
    usingChild.path = path;

    parentObserverData.usingChild = usingChild;
end