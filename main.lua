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
    local Arg2 = string.lower(Split[2])
    if Arg2 == "help" then
        LOGINFO([[
apt:
    help (Displays this menu)*
    info (Displays info on plugin)+
    install (Installs plugin)+
    remove (Removes Plugin)-
    
* implemented
+ in progress
- planned
        ]])
    elseif Arg2 == "info" then
        HandleInfo(Split[3])
    elseif Arg2 == "list" then
        HandleList()
    elseif Arg2 == "install" then
        HandleInstall(Split[3])
    elseif Arg2 == "remove" then
        HandleRemove(Split[3])
    else
        LOGINFO("Unknown apt subcommand. Do [apt help] to get help")
    end
    
    return true
end

-- apt install <plugin>
function HandleInstall(PluginName)
    local Header = "PluginInfo: " .. PluginName
    local Response = ApiRequest(Header, "https://cuberite.krystilize.com")
    local Table = table.load(Response)
    LOGINFO("Downloading...")
    os.execute([[curl "]] .. Table.DownloadDirectory .. [[" --output ]] .. "Plugins/" .. Table.PluginDirectory .. ".zip")
    LOGINFO("Extracting...")
    os.execute("Plugins\\Apt\\7zip\\win\\7za.exe e Plugins/" .. Table.PluginDirectory .. ".zip -y -oPlugins/" .. Table.PluginDirectory)
    LOGINFO("Loading...")
    cRoot:Get():GetDefaultWorld():ScheduleTask(20, function()
        cPluginManager:Get():LoadPlugin(Table.PluginDirectory)
        LOGINFO("Installed!")
    end)
end

-- apt remove <plugin>
function HandleRemove(PluginName)
    local Header = "PluginInfo: " .. PluginName
    local Response = ApiRequest(Header, "https://cuberite.krystilize.com")
    local Table = table.load(Response)
    
    cPluginManager:Get():ForEachPlugin(function(Plugin)
        if Plugin:GetFolderName() == Table.PluginDirectory then
        LOGINFO(Plugin:GetName() .. " Detected as " .. PluginName)
            cPluginManager:Get():UnloadPlugin(Plugin:GetName())
        end
    end)
    
    cFile:DeleteFolderContents("Plugins/" .. Table.PluginDirectory)
end

function HandleList()
    local Response = ApiRequest("List: true", "https://cuberite.krystilize.com")
    LOGINFO("Response: \r\n" .. Response)
end

function HandleInfo(PluginName)
    local Header = "PluginInfo: " .. PluginName
    local Response = ApiRequest(Header, "https://cuberite.krystilize.com")
    local Table = table.load(Response)
    LOGINFO("--- Plugin Info ---")
    LOGINFO(Table.Description)
    LOGINFO("Current Version: " .. Table.Version)
end

-- Api Request
