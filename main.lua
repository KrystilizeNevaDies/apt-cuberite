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

    if os.name() == "Linux" then
        LOGINFO("Detected linux, installing unzip...")
        LOGINFO("You may need to enter your user's password")
        os.execute("sudo apt install unzip")
    end

    cPluginManager.BindConsoleCommand("apt", HandleCmdApt, "Apt Command Entrypoint")
    cPluginManager.BindCommand("/apt", "apt", HandleCmdApt, " ~ standard apt entrypoint. Use apt help for more info")

    LOG("Initialised " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())

    return true
end

-- Entrypoint
function HandleCmdApt(Split, Player)
    if not (Split[2]) then
        if Player then
            Player:SendMessageInfo("Apt-Cuberite version 1.0.0")
            Player:SendMessageInfo("Run [apt help] for help on usage")
        end
        LOGINFO("Apt-Cuberite version 1.0.0")
        LOGINFO("Run [apt help] for help on usage")
        return true
    end

    -- remove capitalisation
    for _, Value in pairs(Split) do
        Value = string.lower(Value)
    end

    -- set arg2 so it doesnt have to be re-indexed in if's
    local Arg2 = string.lower(Split[2])

    if Arg2 == "help" then -- Redimentary help menu
        local help =
            [[
    apt:
    help (Displays this menu)
    info (Displays info on plugin)
    install (Installs plugin)
    installall (Installs every single plugin (not recommended for raspberry pi's lol))
    remove (Removes Plugin)
    removeall (Removs all installed plugins)
    list (lists local Plugins)
    list all (lists all plugins)
    ]]

        if Player then
            Player:SendMessageInfo(help)
        end
        LOGINFO(help)
    elseif Arg2 == "info" then -- Gets info from external database
        HandleInfo(Split[3], Player)
    elseif Arg2 == "list" then -- Lists apt plugins
        if Split[3] == "all" then -- Lists all (external) plugins
            HandleExternalList(Player)
        else
            HandleInternalList(Player) -- Lists internal plugins
        end
    elseif Arg2 == "install" then
        HandleInstallCMD(Split, Player) -- Installs a plugin from external database
    elseif Arg2 == "remove" then
        HandleRemoveCMD(Split, Player) -- Removes a plugin from the local apt repository
    elseif Arg2 == "installall" then
        -- WHY??????
        HandleInstallAllCMD(Player) -- Installs all plugins from external databases
    elseif Arg2 == "removeall" then
        -- Actually, pretty useful
        HandleRemoveAllCMD(Player) -- Removes all apt plugins
    else
        if Player then
            Player:SendMessageInfo("Unknown apt subcommand. Do [apt help] to get help")
        end
        LOGINFO("Unknown apt subcommand. Do [apt help] to get help") -- Unkown command
    end

    return true
end

-- apt installall
function HandleInstallAllCMD(Player) -- run for each plugin
    local Split = {}
    ApiRequest(
        {["PluginList"] = "true"},
        "https://cuberite.krystilize.com",
        function(Response)
            -- parse into table
            local Table = table.load(Response)
            for Key, Value in pairs(Table) do -- log information on each
                ApiRequest(
                    {["PluginInfo"] = Key},
                    "https://cuberite.krystilize.com",
                    function(Response)
                        HandleInstallPrepare(Key, Response, Player)
                    end
                )
            end
        end
    )
end

-- apt install <plugin>
function HandleInstallCMD(Split, Player) -- run for each plugin
    -- ensure pluginname is set
    if Split[3] == nil then
        if Player then
            Player:SendMessageInfo("You need to specify a plugin")
        end
        LOGWARNING("You need to specify a plugin")
        return
    end
    for Key, PluginName in ipairs(Split) do
        if Key > 2.5 then
            ApiRequest(
                {["PluginInfo"] = PluginName},
                "https://cuberite.krystilize.com",
                function(Response)
                    HandleInstallPrepare(PluginName, Response, Player)
                end
            )
        end
    end
end

function HandleInstallPrepare(PluginName, Response, Player)
    Info = table.load(Response)
    local LocalInfo = {}

    if Info == nil then
        if Player then
            Player:SendMessageInfo("Plugin: " .. PluginName .. " not found.")
        end
        LOGWARNING("Plugin: " .. PluginName .. " not found.")
        return
    end

    for Key, Value in pairs(Info) do
        LocalInfo[Key] = Value
    end

    -- Save plugin info to Apt/Info
    cFile:CreateFolderRecursive("Plugins/Apt/Info/" .. PluginName .. "/")
    local file = io.open("Plugins/Apt/Info/" .. PluginName .. "/info.lua", "w+")
    file:write(table.save(LocalInfo))
    file:close()

  local IsFirstDownload = true

    -- Download file
    DownloadToFile("Plugins/" .. LocalInfo.PluginDirectory .. ".zip", LocalInfo.DownloadDirectory,function(Success)
          if Success and IsFirstDownload then
            IsFirstDownload = false
            local Query = string.find(LocalInfo.DownloadDirectory, "/zip/")
            HandleInstall(PluginName, LocalInfo, Query, Player)
          end
      end)
    -- os.execute([[curl "]] .. Table.DownloadDirectory .. [[" --output ]] .. "Plugins/" .. Table.PluginDirectory .. ".zip")
end

function HandleInstall(PluginName, Info, IsGithub, Player) -- Install plugin
    local Table = Info
    --TODO: support old win versions:
    --[[
  E.G.
  path=whatever && powershell -command "Expand-Archive -Force '%path/my_zip_file.zip' '%path'"
  ]]
    -- Check if plugin folder is occupied
    if cFile:IsFolder("Plugins/" .. Table.PluginDirectory) then
        if Player then
            Player:SendMessageWarning("Folder is occupied, is this plugin already installed?")
        end
        LOGWARNING("Folder is occupied, is this plugin already installed?")
        return
    end

    if Player then
        Player:SendMessageInfo("Extracting...")
    end
    LOGINFO("Extracting...")
    if os.name() == "Windows" then
        local MakeDir = os.capture([[mkdir "Plugins/]] .. Table.PluginDirectory .. [["]])
        local Extract =
            os.capture(
            [[tar -xf "]] ..
                "Plugins/" .. Table.PluginDirectory .. [[.zip" -C "]] .. "Plugins/" .. Table.PluginDirectory .. [["]]
        )
        if Player and #MakeDir > 1 and #Extract > 1 then
            Player:SendMessageInfo(MakeDir)
            Player:SendMessageInfo(Extract)
            LOGINFO(MakeDir)
            LOGINFO(Extract)
        end
    elseif os.name() == "Linux" then
        local MakeDir = os.capture([[mkdir "Plugins/]] .. Table.PluginDirectory .. [["]])
        local Extract =
            os.capture([[unzip -o -q "]] .. "Plugins/" .. Table.PluginDirectory .. [[.zip" -d "]] .. "Plugins/" .. Table.PluginDirectory .. [["]])
        if Player and #MakeDir > 1 or #Extract > 1 then
            Player:SendMessageInfo(MakeDir)
            Player:SendMessageInfo(Extract)
            LOGINFO(MakeDir)
            LOGINFO(Extract)
        end
    end

    -- Fix file structure
    local Dir = Table.PluginDirectory
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/" .. Dir)) do -- -master folder
      if os.name() == "Windows" then
          os.execute([[move "Plugins/]] .. Dir .. "/" .. Value .. [[/*" "Plugins/]] .. Dir .. "/")
      else
          os.capture([[mv -v -f "Plugins/]] .. Dir .. "/" .. Value .. [["/* "Plugins/]] .. Dir .. '/"')
          os.capture([[rm -r -f "Plugins/]] .. Dir .. "/" .. Value .. [["]])
      end
    end

    -- Update settings.ini
    if Player then
        Player:SendMessageInfo("Loading...")
    end
    LOGINFO("Loading...")
    local IniFile = cIniFile()
    if (IniFile:ReadFile("settings.ini")) then
        IniFile:SetValue("Plugins", Table.PluginDirectory, 1, true)
        IniFile:WriteFile("settings.ini")
    end

    -- Finalise and load plugin
    cPluginManager:Get():RefreshPluginList()
    cPluginManager:Get():LoadPlugin(Table.PluginDirectory)
    if Player then
        Player:SendMessageSuccess("Installed " .. Table.PluginDirectory .. "!")
    end
    LOGINFO("Installed " .. Table.PluginDirectory .. "!")
    cPluginManager:Get():RefreshPluginList()
end

-- apt removeall
function HandleRemoveAllCMD(Player) -- run for each plugin
    local Table = {}
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/Apt/Info/")) do -- for each folder in apt/info
        HandleRemove(Value, Player)
    end
end

-- apt remove <plugin>
function HandleRemoveCMD(Split, Player)
    -- ensure pluginname is set
    if Split[3] == nil then
        if Player then
            Player:SendMessageInfo("You need to specify a plugin")
        end
        LOGWARNING("You need to specify a plugin")
        return
    end
    for Key, PluginName in pairs(Split) do
        if Key > 2.5 then
            HandleRemove(PluginName, Player)
        end
    end
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
