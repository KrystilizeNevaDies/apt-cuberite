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
    remove (Removes Plugin)
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
        
        
        
    else
        LOGINFO("Unknown apt subcommand. Do [apt help] to get help") -- Unkown command
    end
    
    return true
end

-- apt install <plugin>
function HandleInstallCMD(Split) -- run for each plugin
    for Key, PluginName in pairs(Split) do
        if Key > 2.5 then
            HandleInstall(PluginName)
        end
    end
end

function HandleInstall(PluginName) -- Install plugin
    -- Request data and parse into table
    local Header = "PluginInfo: " .. PluginName
    local Response = ApiRequest(Header, "https://cuberite.krystilize.com")
    local Table = table.load(Response)
    if Table == nil then
        LOGWARNING("Plugin: " .. PluginName .. " not found.")
        return
    end
    
    -- Download using curl
    LOGINFO("Downloading...")
    os.execute([[curl "]] .. Table.DownloadDirectory .. [[" --output ]] .. "Plugins/" .. Table.PluginDirectory .. ".zip")
    
    -- Extract using 7zip
    LOGINFO("Extracting...")
    if not(string.match(os.capture("Plugins\\Apt\\7zip\\win\\7za.exe e Plugins/" .. Table.PluginDirectory .. ".zip -y -oPlugins/" .. Table.PluginDirectory), "Everything is")) then
        LOGWARNING("Extract error detected")
        return
    end
    
    -- Update settings.ini
    LOGINFO("Loading...")
    local IniFile = cIniFile()
    if (IniFile:ReadFile("settings.ini")) then
        IniFile:SetValue("Plugins", Table.PluginDirectory, 1, true)
        IniFile:WriteFile("settings.ini")
    end
    
    -- Save plugin info to Apt/Info
    cFile:CreateFolderRecursive("Plugins/Apt/Info/" .. PluginName .. "/")
    local file = io.open("Plugins/Apt/Info/" .. PluginName .. "/info.lua", "w+")
    file:write(table.save(Table))
    file:close()
    
    
    -- Finalise and load plugin
    cPluginManager:Get():RefreshPluginList()
    cPluginManager:Get():LoadPlugin(Table.PluginDirectory)
    LOGINFO("Installed!")
    cPluginManager:Get():RefreshPluginList()
end

-- apt remove <plugin>
function HandleRemoveCMD(Split)
    for Key, PluginName in pairs(Split) do
        if Key > 2.5 then
            HandleRemove(PluginName)
        end
    end
end

function HandleRemove(PluginName) -- remove plugin
    -- read plugin info
    local file = io.open("Plugins/Apt/Info/" .. PluginName .. "/info.lua", "r")
    if file == nil then
        LOGWARNING("Plugin: " .. PluginName .. " not found.")
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
    
    -- ensure plugin was found (again)
    if RealPluginName == "" then
        LOGWARNING("Plugin: " .. string.lower(PluginName) .. " not found.")
        return
    end
    
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
    -- request from external database
    local Header = "PluginList: true"
    local Response = ApiRequest(Header, "https://cuberite.krystilize.com")
    -- parse into table
    local Table = table.load(Response)
    for Key, Value in pairs(Table) do -- log information on each
        LOGINFO(Key .. " aka. " .. Value.PluginDirectory)
        LOG("Version: " .. Value.Version .. " | Download: " .. Value.DownloadDirectory .. "\r\n")
    end
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
        LOG("Version: " .. Value.Version .. " | Download: " .. Value.DownloadDirectory .. "\r\n")
    end
end

function HandleInfo(PluginName)
    -- get data from external database
    local Header = "PluginInfo: " .. PluginName
    local Response = ApiRequest(Header, "https://cuberite.krystilize.com")
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
end