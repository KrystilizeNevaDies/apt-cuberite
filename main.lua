-- main.lua

-- Implements the main plugin entrypoint

-- Called by Cuberite on plugin start to initialize the plugin
function Initialize(Plugin)
    Plugin:SetName("Apt Plugin Manager")
    Plugin:SetVersion(1)

    local BinaryFormat = package.cpath:match("%p[\\|/]?%p(%a+)")
    if BinaryFormat == "dll" then
        function os.name()
            return "Windows"
        end
    elseif BinaryFormat == "so" then
        function os.name()
            return "Linux"
        end
    elseif BinaryFormat == "dylib" then
        function os.name()
            return "MacOS"
        end
    end


    cPluginManager.BindConsoleCommand("apt", HandleCmdApt, "Apt Command Entrypoint")
    cPluginManager.BindCommand("/apt", "apt", HandleCmdApt, " ~ standard apt entrypoint. Use apt help for more info")

    LOG("Initialised " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())

    return true
end






-- Send info to console and player is exists
function SendInfo(String, Player)
  if Player then
      Player:SendMessageInfo(String)
  end
  LOGINFO(String)
end





-- Send warning to console and player if exists
function SendWarning(String, Player)
  if Player then
      Player:SendMessageWarning(String)
  end
  LOGWARNING(String)
end





-- Entrypoint for apt command
function HandleCmdApt(Split, Player)
    -- check if arguments exist
    if not (Split[2]) then
        SendInfo("Apt-Cuberite version 1.0.0", Player)
        SendInfo("Run [apt help] for help on usage", Player)
        return true
    end





    -- remove capitalisation because thats cringe
    for _, Value in pairs(Split) do
        Value = string.lower(Value)
    end





    -- set arg2 so it doesnt have to be re-indexed in if checks
    local Arg2 = string.lower(Split[2])





    -- Rudimentary help menu
    if Arg2 == "help" then
        local Help =
            [[
apt:
  help (Displays this menu)
  info (Displays info on plugin)
  update (Updates plugin)
  updateall (Updates all installed plugins)
  install (Installs plugin)
  installall (Installs every single plugin (not recommended for raspberry pi's lol))
  remove (Removes Plugin)
  removeall (Removs all installed plugins)
  list (lists local Plugins)
  list all (lists all plugins)
            ]]
        SendInfo(Help, Player)
        
        
        
        
        
    elseif Arg2 == "info" then -- Gets info from external database
        HandleInfo(Split[3], Player)
        
        
        
        
        
    elseif Arg2 == "list" then -- Lists apt plugins
        if Split[3] == "all" then -- Lists all (external) plugins
            HandleExternalList(Player)
        else
            HandleInternalList(Player) -- Lists internal plugins
        end
        
        
        
        
        
    elseif Arg2 == "update" then
        ForArguments(Split, HandleUpdateCMD, Player) -- Updates a plugin from external database
        
        
        
        
        
    elseif Arg2 == "updateall" then
        HandleUpdateAllCMD(Player) -- Updates all plugins from external database
        
        
        
        
        
    elseif Arg2 == "install" then
        ForArguments(Split, HandleInstallCMD, Player) -- Installs a plugin from external database
        
        
        
        
        
    elseif Arg2 == "installall" then
        -- WHY??????
        HandleInstallAllCMD(Player) -- Installs all plugins from external databases
        
        
        
        
        
    elseif Arg2 == "remove" then
        ForArguments(Split, HandleRemoveCMD, Player) -- Removes a plugin from the local apt repository
        
        
        
        
        
    elseif Arg2 == "removeall" then
        -- Actually, pretty useful
        HandleRemoveAllCMD(Player) -- Removes all apt plugins
        
        
        
        
        
    else
        SendInfo("Unknown apt subcommand. Do [apt help] to get help", Player) -- Unkown command
    end





    -- Either way, return true so users dont panic
    return true
end





-- Utility function used to run multiple functions.
-- uses every value of Split which has a key larger then 2
function ForArguments(Split, Callback, Player)
  for Key, Value in ipairs(Split) do
      if Key > 2.5 then
          Callback(Value, Player)
      end
  end
end


-- apt removeall
function HandleRemoveAllCMD(Player) -- run for each plugin
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        HandleRemove(Value, Player)
    end
end

-- apt remove <plugin>
function HandleRemoveCMD(PluginName, Player)
    -- ensure pluginname is set
    if PluginName == nil then
        if Player then
            Player:SendMessageInfo("You need to specify a plugin")
        end
        LOGWARNING("You need to specify a plugin")
        return
    end
    HandleRemove(PluginName, Player)
end

function HandleRemove(PluginName, Player) -- remove plugin
    -- read plugin info
    local file, err = io.open([[Plugins/Apt/Info/]] .. PluginName .. [[/info.lua]], "r")
    if file == nil then
        if Player then
            Player:SendMessageInfo("Plugin: " .. PluginName .. " not found.")
        end
        LOGWARNING("Plugin: " .. PluginName .. " not found.")
        return
    end
    local Table = table.load(file:read("*all"))
    file:close()

    -- match loaded plugin for unload
    local RealPluginName = ""
    cPluginManager:Get():RefreshPluginList() -- ensure update
    cPluginManager:Get():ForEachPlugin(
        function(Plugin)
            if Plugin:GetFolderName() == Table.PluginDirectory then
                LOGINFO(Plugin:GetName() .. " Detected as " .. PluginName)
                RealPluginName = Plugin:GetName()
                cPluginManager:Get():UnloadPlugin(Plugin:GetFolderName())
            end
        end
    )

    -- Update settings.ini file
    local IniFile = cIniFile()
    if (IniFile:ReadFile("settings.ini")) then
        IniFile:DeleteValue("Plugins", Table.PluginDirectory)
        IniFile:WriteFile("settings.ini")
    end

    -- remove all files
    cRoot:Get():GetDefaultWorld():ScheduleTask(
        2,
        function()
            -- 2 tick delay to ensure plugin is unloaded
            cFile:DeleteFile("Plugins/" .. Table.PluginDirectory .. ".zip")
            cFile:DeleteFile("Plugins/Apt/Info/" .. Table.PluginDirectory .. "/info.lua")
            cFile:DeleteFolderContents("Plugins/Apt/Info/" .. PluginName .. "/")
            cFile:DeleteFolder("Plugins/Apt/Info/" .. PluginName .. "/")
            cFile:DeleteFolderContents("Plugins/" .. Table.PluginDirectory)
            cFile:DeleteFolder("Plugins/" .. Table.PluginDirectory)

            if Player then
                Player:SendMessageSuccess(RealPluginName .. " removed.")
            end
            LOGINFO(RealPluginName .. " removed.")
            cPluginManager:Get():RefreshPluginList()
        end
    )
end

-- apt update <plugin>
function HandleUpdateCMD(PluginName, Player)
    -- ensure pluginname is set
    if PluginName == nil then
        if Player then
            Player:SendMessageInfo("You need to specify a plugin")
        end
        LOGWARNING("You need to specify a plugin")
        return
    end
    -- Get installed plugins
        -- read all folders in "Apt/Info/"
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        local file = io.open("Plugins/Apt/Info/" .. Value .. "/info.lua", "r")
        Table[Value] = table.load(file:read("*all")) -- parse table
        file:close()
    end
    
    -- check if exist and then processs update
    if Table[PluginName] then
        HandleRemove(PluginName, Player)
        HandleInstallCMD(PluginName, Player)
    else
        if Player then
            Player:SendMessageInfo("Plugins not installed. Install with: /apt install " .. PluginName)
        end
        LOGINFO("Plugins not installed. Install with: apt install " .. PluginName)
    end
end

function HandleUpdateAllCMD(Player) -- run for each plugin
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        HandleUpdateCMD(Value, Player)
    end
end

-- Get list external database
function HandleExternalList(Player)
    ApiRequest(
        {["PluginList"] = "true"},
        "https://cuberite.krystilize.com",
        function(Response)
            -- parse into table
            local Table = table.load(Response)
            for Key, Value in pairs(Table) do -- log information on each
                if Player then
                    Player:SendMessageInfo(Key .. " aka. " .. Value.PluginDirectory)
                    Player:SendMessageInfo("Version: " .. Value.Version .. " | " .. Value.ShortDescription .. "\r\n")
                end
                LOGINFO(Key .. " aka. " .. Value.PluginDirectory)
                LOG("Version: " .. Value.Version .. " | " .. Value.ShortDescription .. "\r\n")
            end
        end
    )
end

function HandleInternalList(Player)
    -- read all folders in "Apt/Info/"
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        local file = io.open("Plugins/Apt/Info/" .. Value .. "/info.lua", "r")
        Table[Value] = table.load(file:read("*all")) -- parse table
        file:close()
    end
    for Key, Value in pairs(Table) do -- for each parsed table
        -- log into parsed table

        if Player then
            Player:SendMessageInfo(Key .. " aka. " .. Value.PluginDirectory)
            Player:SendMessageInfo("Version: " .. Value.Version .. " | " .. Value.ShortDescription .. "\r\n")
        end

        LOGINFO(Key .. " aka. " .. Value.PluginDirectory)
        LOG("Version: " .. Value.Version .. " | " .. Value.ShortDescription .. "\r\n")
    end
end

function HandleInfo(PluginName, Player)
    -- ensure pluginname is set
    if PluginName == nil then
        LOGWARNING("You need to specify a plugin")
        return
    end
    ApiRequest(
        {["PluginInfo"] = PluginName},
        "https://cuberite.krystilize.com",
        function(Response)
            local Table = table.load(Response)

            -- ensure plugin exists
            if Table == nil then
                if Player then
                    Player:SendMessageInfo("Plugin: " .. PluginName .. " not found.")
                end
                LOGWARNING("Plugin: " .. PluginName .. " not found.")
                return
            end

            -- print plugin info
            if Player then
                Player:SendMessageInfo("--- Plugin Info ---")
                Player:SendMessageInfo(Table.Description)
                Player:SendMessageInfo("Current Version: " .. Table.Version)
            end
            LOGINFO("--- Plugin Info ---")
            LOGINFO(Table.Description)
            LOGINFO("Current Version: " .. Table.Version)
        end
    )
end
