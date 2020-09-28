function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function ApiRequest(Headers, URL, CallBack)
  local ParsedURL = ReplaceString(URL, "https://cuberite.krystilize.com", "http://31.220.51.169")
  -- Start the URL download:
  local isSuccess, msg = cUrlClient:Get(ParsedURL, function(FileData)

      CallBack(Base64Decode(FileData))

    end,
    Headers)

  if not(isSuccess) then
    LOG("Cannot start an URL download: " .. (msg or ""))
    return true
  end

  return true
end


function DownloadToFile(FileName, URL, Callback)  -- Console command handler
  -- Read the params from the command:
  local DownloadURL = ReplaceString(URL, "https://cuberite.krystilize.com", "http://31.220.51.169")
  DownloadURL = DownloadURL:gsub("https://github.com/", "https://codeload.github.com/")

  local DownloadedQuery = false
  
  local SaveFile = function(FileData, Error)
      if FileData and FileData ~= "404: Not Found" and not(DownloadedQuery) then
        if FileData then
          DownloadedQuery = true
          local File = io.open(FileName, "w+")
          File:write(FileData)
          File:close()
          Callback(true)
        else
          SendWarning(Error)
        end
      end
  end
  
  if string.find(DownloadURL, "codeload.github.com") then
      if os.name() == "Windows" then -- For some reason cUrlClient doesnt work correctly for windows downloading zips
          os.execute([[cd Plugins\Apt\Libs\ && powershell -command 'curl -o "]] .. FileName .. [[" "]] .. DownloadURL .. "/zip/master" .. [["']])
          os.execute([[cd Plugins\Apt\Libs\ && powershell -command 'curl -o "]] .. FileName .. [[" "]] .. DownloadURL .. "/zip/master" .. [["']])
      else
          cUrlClient:Get(DownloadURL .. "/zip/master", SaveFile)
          cUrlClient:Get(DownloadURL .. "/zip/alpha", SaveFile)
      end
  else
    cUrlClient:Get(DownloadURL, SaveFile)
  end
  return true
end


--[[
   Save Table to File
   Load Table from File
   v 1.0
   
   Lua 5.2 compatible
   
   Only Saves Tables, Numbers and Strings
   Insides Table References are saved
   Does not save Userdata, Metatables, Functions and indices of these
   ----------------------------------------------------
   table.save( table , filename )
   
   on failure: returns an error msg
   
   ----------------------------------------------------
   table.load( filename or stringtable )
   
   Loads a table that has been saved via the table.save function
   
   on success: returns a previously saved table
   on failure: returns as second argument an error msg
   ----------------------------------------------------
   
   Licensed under the same terms as Lua itself.
]]--
do
  -- declare local variables
  --// exportstring( string )
  --// returns a "Lua" portable version of the string
  local function exportstring( s )
    return string.format("%q", s)
  end

  --// The Save Function

  -- Modified to return a string instead of saving a file

  function table.save(tbl)
    local charS,charE = "   ","\n"
    local Output = ""
    if err then return err end

    -- initiate variables for save procedure
    local tables,lookup = { tbl },{ [tbl] = 1 }
    Output = Output .. ( "return {"..charE )

    for idx,t in ipairs( tables ) do
      Output = Output .. ( "-- Table: {"..idx.."}"..charE )
      Output = Output .. ( "{"..charE )
      local thandled = {}

      for i,v in ipairs( t ) do
        thandled[i] = true
        local stype = type( v )
        -- only handle value
        if stype == "table" then
          if not lookup[v] then
            table.insert( tables, v )
            lookup[v] = #tables
          end
          Output = Output .. ( charS.."{"..lookup[v].."},"..charE )
        elseif stype == "string" then
          Output = Output .. (  charS..exportstring( v )..","..charE )
        elseif stype == "number" then
          Output = Output .. (  charS..tostring( v )..","..charE )
        end
      end

      for i,v in pairs( t ) do
        -- escape handled values
        if (not thandled[i]) then

          local str = ""
          local stype = type( i )
          -- handle index
          if stype == "table" then
            if not lookup[i] then
              table.insert( tables,i )
              lookup[i] = #tables
            end
            str = charS.."[{"..lookup[i].."}]="
          elseif stype == "string" then
            str = charS.."["..exportstring( i ).."]="
          elseif stype == "number" then
            str = charS.."["..tostring( i ).."]="
          end

          if str ~= "" then
            stype = type( v )
            -- handle value
            if stype == "table" then
              if not lookup[v] then
                table.insert( tables,v )
                lookup[v] = #tables
              end
              Output = Output .. ( str.."{"..lookup[v].."},"..charE )
            elseif stype == "string" then
              Output = Output .. ( str..exportstring( v )..","..charE )
            elseif stype == "number" then
              Output = Output .. ( str..tostring( v )..","..charE )
            end
          end
        end
      end
      Output = Output .. ( "},"..charE )
    end
    Output = Output .. ( "}" )
    return Output
  end

  --// The Load Function
  function table.load( str )
    local ftables,err = loadstring( str )
    if err then return _,err end
    local tables = ftables()
    for idx = 1,#tables do
      local tolinki = {}
      for i,v in pairs( tables[idx] ) do
        if type( v ) == "table" then
          tables[idx][i] = tables[v[1]]
        end
        if type( i ) == "table" and tables[i[1]] then
          table.insert( tolinki,{ i,tables[i[1]] } )
        end
      end
      -- link indices
      for _,v in ipairs( tolinki ) do
        tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
      end
    end
    return tables[1]
  end
-- close do
end


