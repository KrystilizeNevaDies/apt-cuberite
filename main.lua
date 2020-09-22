-- main.lua

-- Implements the main plugin entrypoint

-- Called by Cuberite on plugin start to initialize the plugin
function Initialize(Plugin)
	Plugin:SetName("Apt Plugin Manager")
	Plugin:SetVersion(1)
    
    cPluginManager.BindConsoleCommand("apt", HandleCmdApt, "Apt Command Entrypoint");
    
	LOG("Initialised " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())

	return true
end

-- Entrypoint
function HandleCmdApt(Split)

    if not(Split[2]) then
        LOGINFO("Apt-Cuberite version 1.0.0")
        LOGINFO("Run [apt help] for help on usage")
        return
    end
    
    -- remove capitalisation
    for _, Value in pairs(Split) do
        Value = string.lower(Value)
    end
    
    -- set arg2 so it doesnt have to be re-indexed in if's
    local Arg2 = string.lower(Split[2])
    
    
    if Arg2 == "help" then -- Redimentary help menu
        LOGINFO([[
apt:
    help (Displays this menu)
    info (Displays info on plugin)
    install (Installs plugin)
    installall (Installs every single plugin (not recommended for raspberry pi's lol))
    remove (Removes Plugin)
    removeall (Removs all installed plugins)
    list (lists local Plugins)
    list all (lists all plugins)
        ]])
        
        
        
    elseif Arg2 == "info" then -- Gets info from external database
        HandleInfo(Split[3])
        
        
        
    elseif Arg2 == "list" then -- Lists apt plugins
        if Split[3] == "all" then -- Lists all (external) plugins
            HandleExternalList()
        else
            HandleInternalList() -- Lists internal plugins
        end
        
        
        
    elseif Arg2 == "install" then
        HandleInstallCMD(Split) -- Installs a plugin from external database
        
        
        
    elseif Arg2 == "remove" then
        HandleRemoveCMD(Split) -- Removes a plugin from the local apt repository
        
        
    elseif Arg2 == "installall" then
        HandleInstallAllCMD(Split) -- Installs all plugins from external databases
        -- WHY??????
        
        
    elseif Arg2 == "removeall" then
        HandleRemoveAllCMD() -- Installs all plugins from external databases
        -- WHY??????
        
        
        
        
    else
        LOGINFO("Unknown apt subcommand. Do [apt help] to get help") -- Unkown command
    end
    
    return true
end




-- apt installall
function HandleInstallAllCMD() -- run for each plugin
    local Split = {}
    ApiRequest({["PluginList"] = "true"}, "https://cuberite.krystilize.com", function(Response)
        -- parse into table
        local Table = table.load(Response)
        for Key, Value in pairs(Table) do -- log information on each
            ApiRequest({["PluginInfo"] = Key}, "https://cuberite.krystilize.com", function(Response)
                HandleInstallPrepare(Key, Response)
            end)
        end
    end)
end

-- apt install <plugin>
function HandleInstallCMD(Split) -- run for each plugin
    -- ensure pluginname is set
    if Split[3] == nil then
        LOGWARNING("You need to specify a plugin")
        return
    end
    for Key, PluginName in ipairs(Split) do
        if Key > 2.5 then
            ApiRequest({["PluginInfo"] = PluginName}, "https://cuberite.krystilize.com", function(Response)
                HandleInstallPrepare(PluginName, Response)
            end)
        end
    end
end

function HandleInstallPrepare(PluginName, Response)
    
    Info = table.load(Response)
    local LocalInfo = {}
    
    for Key, Value in pairs(Info) do
        LocalInfo[Key] = Value
    end
    
    if LocalInfo == nil then
        LOGWARNING("Plugin: " .. PluginName .. " not found.")
        return
    end
    -- Save plugin info to Apt/Info
    cFile:CreateFolderRecursive("Plugins/Apt/Info/" .. PluginName .. "/")
    local file = io.open("Plugins/Apt/Info/" .. PluginName .. "/info.lua", "w+")
    file:write(table.save(LocalInfo))
    file:close()
    
    DownloadToFile("Plugins/" .. LocalInfo.PluginDirectory .. ".zip", LocalInfo.DownloadDirectory, function()
        HandleInstall(PluginName, LocalInfo)
    end)
    -- os.execute([[curl "]] .. Table.DownloadDirectory .. [[" --output ]] .. "Plugins/" .. Table.PluginDirectory .. ".zip")
end

function HandleInstall(PluginName, Info) -- Install plugin
    
    local Table = Info
    
    -- Extract using 7zip
    
    
    --TODO: support old win versions:
    --[[
    E.G.
    path=whatever && powershell -command "Expand-Archive -Force '%path/my_zip_file.zip' '%path'"
    ]]
    
    LOGINFO("Extracting...")
    os.execute([[mkdir "Plugins/]] .. Table.PluginDirectory .. [["]])
    os.execute([[tar -xf "]] .. "Plugins/" .. Table.PluginDirectory .. [[.zip" -C "]] .. "Plugins/" .. Table.PluginDirectory .. [["]])
    
    -- Update settings.ini
    LOGINFO("Loading...")
    local IniFile = cIniFile()
    if (IniFile:ReadFile("settings.ini")) then
        IniFile:SetValue("Plugins", Table.PluginDirectory, 1, true)
        IniFile:WriteFile("settings.ini")
    end    
    
    -- Finalise and load plugin
    cPluginManager:Get():RefreshPluginList()
    cPluginManager:Get():LoadPlugin(Table.PluginDirectory)
    LOGINFO("Installed!")
    cPluginManager:Get():RefreshPluginList()
end

-- apt removeall
function HandleRemoveAllCMD() -- run for each plugin
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        HandleRemove(Value)
    end
end

-- apt remove <plugin>
function HandleRemoveCMD(Split)
    -- ensure pluginname is set
    if Split[3] == nil then
        LOGWARNING("You need to specify a plugin")
        return
    end
    for Key, PluginName in pairs(Split) do
        if Key > 2.5 then
            HandleRemove(PluginName)
        end
    end
end

function HandleRemove(PluginName) -- remove plugin
    -- read plugin info
    local file, err = io.open([[Plugins/Apt/Info/]] .. PluginName .. [[/info.lua]], "r")
    if file == nil then
        LOGWARNING("Plugin: " .. PluginName .. " not found. \r\n" .. err)
        return
    end
    local Table = table.load(file:read("*all"))
    file:close()
    
    
    -- match loaded plugin for unload
    local RealPluginName = ""
    cPluginManager:Get():RefreshPluginList() -- ensure update
    cPluginManager:Get():ForEachPlugin(function(Plugin)
        if Plugin:GetFolderName() == Table.PluginDirectory then
            LOGINFO(Plugin:GetName() .. " Detected as " .. PluginName)
            RealPluginName = Plugin:GetName()
            cPluginManager:Get():UnloadPlugin(Plugin:GetFolderName())
        end
    end)
    
    -- Update settings.ini file
    local IniFile = cIniFile()
    if (IniFile:ReadFile("settings.ini")) then
        IniFile:DeleteValue("Plugins", Table.PluginDirectory)
        IniFile:WriteFile("settings.ini")
    end
    
    -- remove all files
    cRoot:Get():GetDefaultWorld():ScheduleTask(2, function() -- 2 tick delay to ensure plugin is unloaded
        cFile:DeleteFile("Plugins/" .. Table.PluginDirectory .. ".zip")
        cFile:DeleteFile("Plugins/Apt/Info/" .. Table.PluginDirectory .. "/info.lua")
        cFile:DeleteFolderContents("Plugins/Apt/Info/" .. PluginName .. "/")
        cFile:DeleteFolder("Plugins/Apt/Info/" .. PluginName .. "/")
        cFile:DeleteFolderContents("Plugins/" .. Table.PluginDirectory)
        cFile:DeleteFolder("Plugins/" .. Table.PluginDirectory)
        LOGINFO(RealPluginName .. " removed.")
        cPluginManager:Get():RefreshPluginList()
    end)
end

function HandleExternalList()
    ApiRequest({["PluginList"] = "true"}, "https://cuberite.krystilize.com", function(Response)
        -- parse into table
        local Table = table.load(Response)
        for Key, Value in pairs(Table) do -- log information on each
            LOGINFO(Key .. " aka. " .. Value.PluginDirectory)
            LOG("Version: " .. Value.Version .. " | " .. Value.ShortDescription .. "\r\n")
        end
    end)
end

function HandleInternalList()
    -- read all folders in "Apt/Info/"
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        local file = io.open("Plugins/Apt/Info/" .. Value .. "/info.lua", "r")
        Table[Value] = table.load(file:read("*all")) -- parse table
        file:close()
    end
    for Key, Value in pairs(Table) do -- for each parsed table
        -- log into parsed table
        LOGINFO(Value.PluginDirectory)
        LOG("Version: " .. Value.Version .. " | " .. Value.ShortDescription .. "\r\n")
    end
end

function HandleInfo(PluginName)
    -- ensure pluginname is set
    if PluginName == nil then
        LOGWARNING("You need to specify a plugin")
        return
    end
    ApiRequest({["PluginInfo"] = PluginName}, "https://cuberite.krystilize.com", function(Response)
        local Table = table.load(Response)
        
        -- ensure plugin exists
        if Table == nil then
            LOGWARNING("Plugin: " .. PluginName .. " not found.")
            return
        end
        
        -- print plugin info
        LOGINFO("--- Plugin Info ---")
        LOGINFO(Table.Description)
        LOGINFO("Current Version: " .. Table.Version)
    end)
end