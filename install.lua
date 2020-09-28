-- This plugin gets all plugins and runs the installation for each
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
function HandleInstallCMD(PluginName, Player) -- run for each plugin
    -- ensure pluginname is set
    if PluginName == nil then
        SendWarning("You need to specify a plugin")
        return
    end
    
    ApiRequest(
        {["PluginInfo"] = PluginName},
        "https://cuberite.krystilize.com",
        function(Response)
            HandleInstallPrepare(PluginName, Response, Player)
        end
    )
end

function HandleInstallPrepare(PluginName, Response, Player)
    Info = table.load(Response)
    local LocalInfo = {}

    if Info == nil then
        SendWarning("Plugin: " .. PluginName .. " not found.")
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
        SendWarning("Folder is occupied, is this plugin already installed?")
        return
    end





    
    -- Extract
    do
        local InputFile = io.open("Plugins/" .. Table.PluginDirectory .. ".zip", "rb")
        local LP = "Plugins/Apt/Libs/" -- Lib Path
        if os.name() == "Linux" then
            os.capture(LP .. "unzip" .. [[ "Plugins/]] .. Table.PluginDirectory .. [[.zip" -d "Plugins/]] .. Table.PluginDirectory .. [["]])
        
        
        
        
        elseif os.name() == "Windows" then
            local MakeDir = os.capture([[mkdir "Plugins/]] .. Table.PluginDirectory .. [["]])
           local Extract = os.capture([[Plugins/Apt/ZipLib/pkunzip.exe Plugins/]] .. Table.PluginDirectory .. [[.zip]])
        if #MakeDir > 1 or #Extract > 1 then
            SendInfo(MakeDir)
            SendInfo(Extract)
        end
        
        
        
        
        elseif os.name() == "MacOS" then
            
        end
        InputFile:close()
    end




    -- Fix file structure
    local Dir = Table.PluginDirectory
    for Key, Value in pairs(cFile:GetFolderContents("Plugins/" .. Dir)) do -- -master folder
      if os.name() == "Windows" then
          os.capture([[move "Plugins/]] .. Dir .. "/" .. Value .. [[/*" "Plugins/]] .. Dir .. "/")
      else
          os.capture([[mv -v -f "Plugins/]] .. Dir .. "/" .. Value .. [["/* "Plugins/]] .. Dir .. '/"')
          os.capture([[rm -r -f "Plugins/]] .. Dir .. "/" .. Value .. [["]])
      end
    end

    -- Update settings.ini
    local IniFile = cIniFile()
    if (IniFile:ReadFile("settings.ini")) then
        IniFile:SetValue("Plugins", Table.PluginDirectory, 1, true)
        IniFile:WriteFile("settings.ini")
    end

    -- Finalise and load plugin
    cPluginManager:Get():RefreshPluginList()
    cPluginManager:Get():LoadPlugin(Table.PluginDirectory)
    SendInfo("Installed " .. Table.PluginDirectory .. "!")
end