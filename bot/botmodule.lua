BOT = {}

local now = os.time()
math.randomseed(now)

function BOT.msg_valid(msg)
  -- Dont process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if msg.service then
    print('\27[36mNot valid: service\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  return true
end

-- Apply plugin.pre_process function
function BOT.pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
function BOT.is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function BOT.match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches is enought.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if BOT.is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- Save the content of _config to config.lua
function BOT.save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesnt exists, create it.
function BOT.load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesnt exists
  if not f then
    print ("Created new config file: data/config.lua")
    BOT.create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function BOT.create_config( )
  -- A simple config with basic plugins and ourserves as priviled user
  config = {
    enabled_plugins = {
      "9gag",
      "eur",
      "echo",
      "btc",
      "get",
      "giphy",
      "google",
      "gps",
      "help",
      "images",
      "img_google",
      "location",
      "media",
      "plugins",
      "channels",
      "set",
      "stats",
      "time",
      "version",
      "weather",
      "xkcd",
      "youtube" },
    sudo_users = {94746365},
    disabled_channels = {}
  }
  serialize_to_file(config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Enable plugins in config.json
function BOT.load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end

-- Call and postpone execution for cron plugins
function BOT.cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 5 mins
  postpone (cron_plugins, false, 5*60.0)
end

-- Go over enabled plugins patterns.
function BOT.match_plugins(msg)
  for name, plugin in pairs(plugins) do
    BOT.match_plugin(plugin, name, msg)
  end
end

function BOT.start()
  started = true
  postpone (cron_plugins, false, 60*5.0)
  -- See plugins/ping.lua as an example for cron

  _config = BOT.load_config()

  -- load plugins
  plugins = {}
  BOT.load_plugins()
end

-- This function is called when tg receive a msg
function BOT.on_msg_receive (msg)
  
  if not started then
    return
  end

  local receiver = get_receiver(msg)

  -- vardump(msg)
  if BOT.msg_valid(msg) then
    msg = BOT.pre_process_msg(msg)
    if msg then
      BOT.match_plugins(msg)
      mark_read(receiver, ok_cb, false)
    end
  end
end

return BOT
