
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    widgets.lua
--  brief:   the widget manager, a call-in router
--  author:  Dave Rodgers
--
--  modified by jK, quantum, Bluestone
--
--  Copyright (C) 2007,2008,2009.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- stable release?
local isStable = false
local CONFIG_VERSION = 4 -- increment to force a blank config/order on users

function includeZIPFirst(filename, envTable)
  if (string.find(filename, '.h.lua', 1, true)) then
    filename = 'Headers/' .. filename
  end
  return VFS.Include(LUAUI_DIRNAME .. filename, envTable, VFS.ZIP_FIRST)
end


include("keysym.h.lua")
include("utils.lua")
includeZIPFirst("system.lua")
includeZIPFirst("cache.lua")
include("callins.lua")
include("savetable.lua")

local ORDER_FILENAME     = LUAUI_DIRNAME .. 'Config/' .. Game.modShortName:upper() .. '_order.lua'
local CONFIG_FILENAME    = LUAUI_DIRNAME .. 'Config/' .. Game.modShortName:upper() .. '_data.lua'
local VERSION_FILENAME     = LUAUI_DIRNAME .. 'Config/' .. Game.modShortName:upper() .. '_version.lua'
local WIDGET_DIRNAME     = LUAUI_DIRNAME .. 'Widgets/'

local HANDLER_BASENAME = "barwidgets.lua"
local SELECTOR_BASENAME = 'selector.lua'


local SAFEWRAP = 1
-- 0: disabled
-- 1: enabled, but can be overriden by widget.GetInfo().unsafe
-- 2: always enabled

local SAFEDRAW = false  -- requires SAFEWRAP to work
local glPopAttrib  = gl.PopAttrib
local glPushAttrib = gl.PushAttrib
local pairs = pairs
local ipairs = ipairs

-- read local widgets config?
local localWidgetsFirst = true
local localWidgets = true

if VFS.FileExists(CONFIG_FILENAME) then
  local configData = VFS.Include(CONFIG_FILENAME)
  if configData then
    if configData["Local Widgets Config"] then
      localWidgetsFirst = configData["Local Widgets Config"].localWidgetsFirst
      localWidgets = configData["Local Widgets Config"].localWidgets
    end
  end
end

local VFSMODE
VFSMODE = localWidgetsFirst and VFS.RAW_FIRST
VFSMODE = VFSMODE or localWidgets and VFS.ZIP_FIRST
VFSMODE = VFSMODE or VFS.ZIP

--------------------------------------------------------------------------------

-- install bindings for TweakMode and the Widget Selector

Spring.SendCommands({
  "unbindkeyset  Any+f11",
  "unbindkeyset Ctrl+f11",
  "bind    f11  luaui selector",
  "bind  C+f11  luaui tweakgui",
  "echo LuaUI: bound F11 to the widget selector",
  "echo LuaUI: bound CTRL+F11 to tweak mode"
})


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  the widgetHandler object
--

widgetHandler = {

  widgets = {},

  configData = {},
  orderList = {},

  knownWidgets = {},
  knownCount = 0,
  knownChanged = true, -- we must set to true *whenever* we see a widget change state; it is the widget selectors responsibility to set back to false once it has processed the event
  
  allowUserWidgets = true,

  commands = {},
  customCommands = {},
  inCommandsChanged = false,

  actionHandler = includeZIPFirst("actions.lua"),

  WG = {}, -- shared table for widgets

  globals = {}, -- global vars/funcs

  mouseOwner = nil,
  ownedButton = 0,

  tweakMode = false,
}


-- these call-ins are set to 'nil' if not used
-- they are setup in UpdateCallIns()
local flexCallIns = {
  'GameOver',
  'GameFrame',
  'TeamDied',
  'TeamChanged',
  'PlayerAdded',
  'PlayerChanged',
  "PlayerRemoved",
  'ShockFront',
  'WorldTooltip',
  'MapDrawCmd',
  'GameSetup',
  'DefaultCommand',
  'UnitCreated',
  'UnitFinished',
  'UnitFromFactory',
  'UnitDestroyed',
  'UnitExperience',
  'UnitTaken',
  'UnitGiven',
  'UnitIdle',
  'UnitCommand',
  'UnitCmdDone',
  'UnitDamaged',
  'UnitEnteredRadar',
  'UnitEnteredLos',
  'UnitLeftRadar',
  'UnitLeftLos',
  'UnitEnteredWater',
  'UnitEnteredAir',
  'UnitLeftWater',
  'UnitLeftAir',
  'UnitSeismicPing',
  'UnitLoaded',
  'UnitUnloaded',
  'UnitCloaked',
  'UnitDecloaked',
  'UnitMoveFailed',
  'RecvLuaMsg',
  'StockpileChanged',
  'DrawGenesis',
  'DrawWorld',
  'DrawWorldPreUnit',
  'DrawWorldShadow',
  'DrawWorldReflection',
  'DrawWorldRefraction',
  'DrawScreenEffects',
  'DrawInMiniMap',
  'SelectionChanged',
  'AddTransmitLine',
  'AddConsoleMessage',
  'VoiceCommand',  
  'FeatureCreated', 
  'FeatureDestroyed', 
}
local flexCallInMap = {}
for _,ci in ipairs(flexCallIns) do
  flexCallInMap[ci] = true
end

local callInLists = {
  'GamePreload',
  'GameStart',
  'Shutdown',
  'Update',
  -- 'TextCommand', -- deprecated, use widgetHandler:AddAction 
  'CommandNotify',
  'AddConsoleLine',
  'ViewResize',
  'DrawScreen',
  'TextInput',
  'KeyPress',
  'KeyRelease',
  'MousePress',
  'MouseWheel',
  'IsAbove',
  'GetTooltip',
  'GroupChanged',
  'CommandsChanged',
  'TweakMousePress',
  'TweakMouseWheel',
  'TweakIsAbove',
  'TweakGetTooltip',
  'GameProgress',
  'UnsyncedHeightMapUpdate',
-- these use mouseOwner instead of lists
--  'MouseMove',
--  'MouseRelease',
--  'TweakKeyPress',
--  'TweakKeyRelease',
--  'TweakMouseMove',
--  'TweakMouseRelease',

-- uses the DrawScreenList
--  'TweakDrawScreen',
}

-- append the flex call-ins
for _,uci in ipairs(flexCallIns) do
  table.insert(callInLists, uci)
end


-- initialize the call-in lists
do
  for _,listname in ipairs(callInLists) do
    widgetHandler[listname..'List'] = {}
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  array-table reverse iterator
--
--  all callin handlers use this so that widget can
--  RemoveWidget() themselves (during iteration over
--  a callin list) without causing a miscount
--
--  c.f. Array{Insert,Remove}
--
local function r_ipairs(tbl)
  local function r_iter(tbl, key)
    if (key <= 1) then
      return nil
    end

    -- next idx, next val
    return (key - 1), tbl[key - 1]
  end

  return r_iter, tbl, (1 + #tbl)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widgetHandler:LoadOrderList()
  local chunk, err = loadfile(ORDER_FILENAME)
    if (chunk == nil) or (err) then
        if err then
            Spring.Log(HANDLER_BASENAME, LOG.INFO, err)
        end
        return {}
    elseif (chunk() == nil) then
        Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Luaui order config file was blank')
        return {}
    end 
    
    local tmp = {}
    setfenv(chunk, tmp)
    self.orderList = chunk()
    if (not self.orderList) then
        self.orderList = {} -- safety
    end
end


function widgetHandler:SaveOrderList()
  -- update the current order
  for i,w in ipairs(self.widgets) do 
    self.orderList[w.whInfo.name] = i
  end
  table.save(self.orderList, ORDER_FILENAME,
             '-- Widget Order List  (0 disables a widget)')
end


--------------------------------------------------------------------------------

function widgetHandler:LoadConfigData()
  local chunk, err = loadfile(CONFIG_FILENAME)
  if (chunk == nil) or (err) then
    if err then
      Spring.Log(HANDLER_BASENAME, LOG.INFO, err)
    end
    return {}
  elseif (chunk() == nil) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Luaui data config file was blank')
    return {}
  end  
  local tmp = {}
  setfenv(chunk, tmp)
  self.configData = chunk()
  
  -- safety
  if (not self.orderList) then
    self.orderList = {} 
  end
  if (not self.configData) then
    self.configData = {} 
  end
end


function widgetHandler:SaveConfigData()
  for _,w in r_ipairs(self.widgets) do
    if (w.GetConfigData) then
      local ok, err = pcall(function() 
        self.configData[w.whInfo.name] = w:GetConfigData()
      end)
      if not ok then Spring.Log(HANDLER_BASENAME, LOG.ERROR, "Failed to GetConfigData from: " .. w.whInfo.name.." ("..err..")") end 
    end
  end
  table.save(self.configData, CONFIG_FILENAME, '-- Widget Custom Data')
end


function widgetHandler:SendConfigData()
  self:LoadConfigData()
  for _,w in r_ipairs(self.widgets) do
    local data = self.configData[w.whInfo.name]
    if (w.SetConfigData and data) then
      w:SetConfigData(data)
    end
  end
end

--------------------------------------------------------------------------------

function widgetHandler:CheckConfigVersion()
  local chunk, err = loadfile(VERSION_FILENAME)
  local tmp = {}
  if (chunk == nil) or (err) then
    if err then
        Spring.Log(HANDLER_BASENAME, LOG.INFO, err)
        versionData = nil
    end
  elseif (chunk() == nil) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Luaui version file was blank')
    versionData = nil
  else
    setfenv(chunk, tmp)
    versionData = chunk()  
  end 

  local prevVersion = versionData and versionData.version or nil
  if prevVersion~=CONFIG_VERSION then
    Spring.Echo("LuaUI: Applying new config version " .. CONFIG_VERSION .. " (previous was " .. (prevVersion or 'nil') .. ")")
    self.configData = {}
    self.orderData = {}
  end
  Spring.Echo("LuaUI: Config version is " .. CONFIG_VERSION)  
  table.save({version=CONFIG_VERSION}, VERSION_FILENAME, '-- BAR luaui config version')
end

--------------------------------------------------------------------------------

function widgetHandler:Initialize()
  if Game.modVersion:find("stable",1,true) then
    isStable = true
  end

  self:LoadOrderList()
  self:LoadConfigData()
  self:CheckConfigVersion()
  self:SaveOrderList()
  self:SaveConfigData()
  
  if self.configData.allowUserWidgets~=nil then
    self.allowUserWidgets = self.configData.allowUserWidgets 
  end
  
  --local autoModWidgets = Spring.GetConfigInt('LuaAutoModWidgets', 1)
  --self.autoModWidgets = (autoModWidgets ~= 0)
  if self.allowUserWidgets then
    Spring.Echo("LuaUI: Allowing User Widgets")
  else
    Spring.Echo("LuaUI: Disallowing User Widgets")
  end

  -- create the "LuaUI/Config" directory
  Spring.CreateDir(LUAUI_DIRNAME .. 'Config')

  local unsortedWidgets = {}

  -- stuff the raw widgets into unsortedWidgets
  if self.allowUserWidgets then
    local widgetFiles = VFS.DirList(WIDGET_DIRNAME, "*.lua", VFS.RAW_ONLY)
    for k,wf in ipairs(widgetFiles) do
      local widget = self:LoadWidget(wf, VFS.RAW_ONLY)
      if (widget) then
        table.insert(unsortedWidgets, widget)
      end
    end
  end
  
  -- stuff the zip widgets into unsortedWidgets
  local widgetFiles = VFS.DirList(WIDGET_DIRNAME, "*.lua", VFS.ZIP_ONLY)
  for k,wf in ipairs(widgetFiles) do
    local widget = self:LoadWidget(wf, VFS.ZIP_ONLY)
    if (widget) then
      table.insert(unsortedWidgets, widget)
    end
  end
  
  -- sort the widgets
  table.sort(unsortedWidgets, function(w1, w2)
    local a1 = w1.whInfo.api
    local a2 = w2.whInfo.api
    if (a1 ~= a2) then
        return (a1 == true)
    end
    
    local l1 = w1.whInfo.layer
    local l2 = w2.whInfo.layer
    if (l1 ~= l2) then
      return (l1 < l2)
    end
    
    local n1 = w1.whInfo.name
    local n2 = w2.whInfo.name
    local o1 = self.orderList[n1]
    local o2 = self.orderList[n2]
    if (o1 ~= o2) then
      return (o1 < o2)
    else
      return (n1 < n2)
    end
  end)

  -- add the widgets  
  for _,w in ipairs(unsortedWidgets) do
    local name = w.whInfo.name
    local basename = w.whInfo.basename
    local source = self.knownWidgets[name].fromZip and "mod: " or "user:"
    local api = w.whInfo.api and " API" or ""
    Spring.Echo(string.format("Loading%s widget from %s  %-18s  <%s> ...", api, source, name, basename))

    widgetHandler:InsertWidget(w)
  end

end


function widgetHandler:LoadWidget(filename, _VFSMODE)
  _VFSMODE = _VFSMODE or VFSMODE
  local basename = Basename(filename)
  local text = VFS.LoadFile(filename, _VFSMODE)

  if (text == nil) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Failed to load: ' .. basename .. '  (missing file: ' .. filename ..')')
    return nil
  end
  local chunk, err = loadstring(text, filename)
  if (chunk == nil) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Failed to load: ' .. basename .. '  (' .. err .. ')')
    return nil
  end

  local widget = widgetHandler:NewWidget()
  setfenv(chunk, widget)
  local success, err = pcall(chunk)
  if (not success) then
    Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
    return nil
  end
  if (err == false) then
    return nil -- widget asked for a silent death
  end

  -- raw access to widgetHandler
  if (widget.GetInfo and widget:GetInfo().handler) then
    widget.widgetHandler = self
  end

  self:FinalizeWidget(widget, filename, basename)
  local name = widget.whInfo.name
  if (basename == SELECTOR_BASENAME) then
    self.orderList[name] = 1  --  always enabled
  end

  err = self:ValidateWidget(widget)
  if (err) then
    Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
    return nil
  end

  local knownInfo = self.knownWidgets[name]
  if (knownInfo) then
    if (knownInfo.active) then
      Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Failed to load: ' .. basename .. '  (duplicate name)')
      return nil
    end
  else
    -- create a knownInfo table
    knownInfo = {}
    knownInfo.desc     = widget.whInfo.desc
    knownInfo.author   = widget.whInfo.author
    knownInfo.basename = widget.whInfo.basename
    knownInfo.filename = widget.whInfo.filename
    knownInfo.alwaysStart = widget.whInfo.alwaysStart
    knownInfo.fromZip  = true
    if (_VFSMODE ~= VFS.ZIP) then
      if (_VFSMODE == VFS.RAW_FIRST) then
        knownInfo.fromZip = not VFS.FileExists(filename,VFS.RAW_ONLY)
      else
        knownInfo.fromZip = VFS.FileExists(filename,VFS.ZIP_ONLY)
      end
    end
    self.knownWidgets[name] = knownInfo
    self.knownCount = self.knownCount + 1
    self.knownChanged = true
  end
  knownInfo.active = true

  if (widget.GetInfo == nil) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Failed to load: ' .. basename .. '  (no GetInfo() call)')
    return nil
  end

  -- Get widget information
  local info  = widget:GetInfo()

  -- Enabling
  local order = self.orderList[name]
  if order then
    if order <= 0 then
       order = nil
    end
  else
    if info.enabled and (knownInfo.fromZip or self.allowUserWidgets) then
        order = 12345
    end
  end

  if order then
    self.orderList[name] = order
  else
    self.orderList[name] = 0
    self.knownWidgets[name].active = false
    return nil
  end

  -- load the config data
  local config = self.configData[name]
  if (widget.SetConfigData and config) then
    widget:SetConfigData(config)
  end

  return widget
end


function widgetHandler:NewWidget()
  local widget = {}
  if (true) then
    -- copy the system calls into the widget table
    for k,v in pairs(System) do
      widget[k] = v
    end
  else
    -- use metatable redirection
    setmetatable(widget, {
      __index = System,
      __metatable = true,
    })
  end
  widget.WG = self.WG    -- the shared table
  widget.widget = widget -- easy self referencing

  -- wrapped calls (closures)
  widget.widgetHandler = {}
  local wh = widget.widgetHandler
  local self = self
  widget.include  = function (f) return include(f, widget) end
  wh.ForceLayout  = function (_) self:ForceLayout() end
  wh.RaiseWidget  = function (_) self:RaiseWidget(widget) end
  wh.LowerWidget  = function (_) self:LowerWidget(widget) end
  wh.RemoveWidget = function (_) self:RemoveWidget(widget) end
  wh.GetCommands  = function (_) return self.commands end
  wh.InTweakMode  = function (_) return self.tweakMode end
  wh.GetViewSizes = function (_) return self:GetViewSizes() end
  wh.GetHourTimer = function (_) return self:GetHourTimer() end
  wh.IsMouseOwner = function (_) return (self.mouseOwner == widget) end
  wh.DisownMouse  = function (_)
    if (self.mouseOwner == widget) then
      self.mouseOwner = nil
    end
  end

  wh.isStable = function (_) return self:isStable() end

  wh.UpdateCallIn = function (_, name)
    self:UpdateWidgetCallIn(name, widget)
  end
  wh.RemoveCallIn = function (_, name)
    self:RemoveWidgetCallIn(name, widget)
  end

  wh.AddAction    = function (_, cmd, func, data, types)
    return self.actionHandler:AddAction(widget, cmd, func, data, types)
  end
  wh.RemoveAction = function (_, cmd, types)
    return self.actionHandler:RemoveAction(widget, cmd, types)
  end

  wh.AddLayoutCommand = function (_, cmd)
    if (self.inCommandsChanged) then
      table.insert(self.customCommands, cmd)
    else
      Spring.Log(HANDLER_BASENAME, LOG.ERROR, "AddLayoutCommand() can only be used in CommandsChanged()")
    end
  end

  wh.RegisterGlobal = function(_, name, value)
    return self:RegisterGlobal(widget, name, value)
  end
  wh.DeregisterGlobal = function(_, name)
    return self:DeregisterGlobal(widget, name)
  end
  wh.SetGlobal = function(_, name, value)
    return self:SetGlobal(widget, name, value)
  end

  wh.ConfigLayoutHandler = function(_, d) self:ConfigLayoutHandler(d) end

  ----
  widget.ProcessConsoleBuffer = function(_,_, num)	-- FIXME: probably not the least hacky way to make ProcessConsoleBuffer accessible to widgets
    return MessageProcessor:ProcessConsoleBuffer(num)
  end
  ----
  
  return widget
end


function widgetHandler:FinalizeWidget(widget, filename, basename)
  local wi

  if (widget.GetInfo == nil) then
    wi = {}
    wi.filename = filename
    wi.basename = basename
    wi.name  = basename
    wi.layer = 0
  else
    local info = widget:GetInfo()
    wi = info
    wi.filename = filename
    wi.basename = basename
    wi.name     = wi.name    or basename
    wi.layer    = wi.layer   or 0
    wi.desc     = wi.desc    or ""
    wi.author   = wi.author  or ""
    wi.license  = wi.license or ""
    wi.enabled  = wi.enabled or false
    wi.api      = wi.api or false
  end

  widget.whInfo = {}  --  a proxy table
  local mt = {
    __index = wi,
    __newindex = function() error("whInfo tables are read-only") end,
    __metatable = "protected"
  }
  setmetatable(widget.whInfo, mt)
end


function widgetHandler:ValidateWidget(widget)
  if (widget.GetTooltip and not widget.IsAbove) then
    return "Widget has GetTooltip() but not IsAbove()"
  end
  if (widget.TweakGetTooltip and not widget.TweakIsAbove) then
    return "Widget has TweakGetTooltip() but not TweakIsAbove()"
  end
  return nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function HandleError(widget, funcName, status, ...)
  if (status) then
    return ...
  end

  if (funcName ~= 'Shutdown') then
    widgetHandler:RemoveWidget(widget)
  else
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Error in Shutdown()')
  end
  local name = widget.whInfo.name
  local error_message = select(1,...)
  Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Error in ' .. funcName ..'(): ' .. tostring(error_message))
  Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Removed widget: ' .. name)
  widgetHandler.knownChanged = true
  return nil
end

local function SafeWrapFuncNoGL(func, funcName)
  return function(w, ...)
    return HandleError(w, funcName, pcall(func, w, ...))
  end
end

local function SafeWrapFuncGL(func, funcName)
  return function(w, ...)

    glPushAttrib(GL.ALL_ATTRIB_BITS)
    local r = { pcall(func, w, ...) }
    glPopAttrib()

    if (r[1]) then
      table.remove(r, 1)
      return unpack(r)
    else
      if (funcName ~= 'Shutdown') then
        widgetHandler:RemoveWidget(w)
      else
        Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Error in Shutdown()')
      end
      local name = w.whInfo.name
      Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Error in ' .. funcName ..'(): ' .. tostring(r[2]))
      Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'Removed widget: ' .. name)
      widgetHandler.knownChanged = true
      return nil
    end
  end
end


local function SafeWrapFunc(func, funcName)
  if (not SAFEDRAW) then
    return SafeWrapFuncNoGL(func, funcName)
  else
    if (string.sub(funcName, 1, 4) ~= 'Draw') then
      return SafeWrapFuncNoGL(func, funcName)
    else
      return SafeWrapFuncGL(func, funcName)
    end
  end
end


local function SafeWrapWidget(widget)
  if (SAFEWRAP <= 0) then
    return
  elseif (SAFEWRAP == 1) then
    if (widget.GetInfo and widget.GetInfo().unsafe) then
      Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'LuaUI: loaded unsafe widget: ' .. widget.whInfo.name)
      return
    end
  end

  for _,ciName in ipairs(callInLists) do
    if (widget[ciName]) then
      widget[ciName] = SafeWrapFunc(widget[ciName], ciName)
    end
    if (widget.Initialize) then
      widget.Initialize = SafeWrapFunc(widget.Initialize, 'Initialize')
    end
  end
end


--------------------------------------------------------------------------------

local function ArrayInsert(t, w)
  local layer = w.whInfo.layer
  local index = 1

  for i,v in ipairs(t) do
    if (v == w) then
      return -- already in the table
    end

    -- insert-sort the widget based on its layer
    -- note: reversed value ordering, highest to lowest
    -- iteration over the callin lists is also reversed
    if (layer < v.whInfo.layer) then
      index = i + 1
    end
  end

  table.insert(t, index, w)
end


local function ArrayRemove(t, w)
  for k,v in ipairs(t) do
    if (v == w) then
      table.remove(t, k)
      -- break
    end
  end
end


function widgetHandler:InsertWidget(widget)
  if (widget == nil) then
    return
  end

  SafeWrapWidget(widget)

  ArrayInsert(self.widgets, widget)
  for _,listname in ipairs(callInLists) do
    local func = widget[listname]
    if (type(func) == 'function') then
      ArrayInsert(self[listname..'List'], widget)
    end
  end
  self:UpdateCallIns()

  if (widget.Initialize) then
    widget:Initialize()
  end
end


function widgetHandler:RemoveWidget(widget)
  if (widget == nil) then
    return
  end

  local name = widget.whInfo.name
  if (widget.GetConfigData) then
    local ok, err = pcall(function() 
      self.configData[name] = widget:GetConfigData()
    end)
    if not ok then Spring.Log(HANDLER_BASENAME, LOG.ERROR, "Failed to GetConfigData: " .. name.." ("..err..")") end 
  end
  self.knownWidgets[name].active = false
  if (widget.Shutdown) then
    widget:Shutdown()
  end
  ArrayRemove(self.widgets, widget)
  self:RemoveWidgetGlobals(widget)
  self.actionHandler:RemoveWidgetActions(widget)
  for _,listname in ipairs(callInLists) do
    ArrayRemove(self[listname..'List'], widget)
  end
  self:UpdateCallIns()
  widgetHandler.knownChanged = true
end


--------------------------------------------------------------------------------

function widgetHandler:UpdateCallIn(name)
  local listName = name .. 'List'
  if ((name == 'Update')     or
      (name == 'DrawScreen')) then
    return
  end

  if ((#self[listName] > 0) or
      (not flexCallInMap[name]) or
      ((name == 'GotChatMsg')     and actionHandler.HaveChatAction()) or
      ((name == 'RecvFromSynced') and actionHandler.HaveSyncAction())) then
    -- always assign these call-ins
    local selffunc = self[name]
    _G[name] = function(...)
      return selffunc(self, ...)
    end
  else
    _G[name] = nil
  end
  Script.UpdateCallIn(name)
end


function widgetHandler:UpdateWidgetCallIn(name, w)
  local listName = name .. 'List'
  local ciList = self[listName]
  if (ciList) then
    local func = w[name]
    if (type(func) == 'function') then
      ArrayInsert(ciList, w)
    else
      ArrayRemove(ciList, w)
    end
    self:UpdateCallIn(name)
  else
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'UpdateWidgetCallIn: bad name: ' .. name)
  end
end


function widgetHandler:RemoveWidgetCallIn(name, w)
  local listName = name .. 'List'
  local ciList = self[listName]
  if (ciList) then
    ArrayRemove(ciList, w)
    self:UpdateCallIn(name)
  else
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, 'RemoveWidgetCallIn: bad name: ' .. name)
  end
end


function widgetHandler:UpdateCallIns()
  for _,name in ipairs(callInLists) do
    self:UpdateCallIn(name)
  end
end


--------------------------------------------------------------------------------

function widgetHandler:EnableWidget(name)
  local ki = self.knownWidgets[name]
  if (not ki) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, "EnableWidget(), could not find widget: " .. tostring(name))
    return false
  end
  if (not ki.active) then
    Spring.Echo('Loading:  '..ki.filename)
    local order = widgetHandler.orderList[name]
    if (not order or (order <= 0)) then
      self.orderList[name] = 1
    end
    local w = self:LoadWidget(ki.filename)
    if (not w) then return false end
    self:InsertWidget(w)
    self:SaveOrderList()
  end
  widgetHandler.knownChanged = true
  return true
end


function widgetHandler:DisableWidget(name)
  local ki = self.knownWidgets[name]
  if (not ki) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, "DisableWidget(), could not find widget: " .. tostring(name))
    return false
  end
  if (ki.active) then
    local w = self:FindWidget(name)
    if (not w) then return false end
    Spring.Echo('Removed:  '..ki.filename)
    self:RemoveWidget(w)     -- deactivate
    self.orderList[name] = 0 -- disable
    self:SaveOrderList()	
    self:SaveConfigData()
  end
  return true
end


function widgetHandler:ToggleWidget(name)
  local ki = self.knownWidgets[name]
  if (not ki) then
    Spring.Log(HANDLER_BASENAME, LOG.ERROR, "ToggleWidget(), could not find widget: " .. tostring(name))
    return
  end
  if (ki.active) then
    return self:DisableWidget(name)
  elseif (self.orderList[name] <= 0) then
    return self:EnableWidget(name)
  else
    -- the widget is not active, but enabled; disable it
    self.orderList[name] = 0
    self:SaveOrderList()
    self:SaveConfigData()
  end
  widgetHandler.knownChanged = true
  return true
end


--------------------------------------------------------------------------------

local function FindWidgetIndex(t, w)
  for k,v in ipairs(t) do
    if (v == w) then
      return k
    end
  end
  return nil
end




function widgetHandler:RaiseWidget(widget)
  if (widget == nil) then
    return
  end

  local function FindLowestIndex(t, i, layer)
    local n = #t
    for x = (i + 1), n, 1 do
      if (t[x].whInfo.layer < layer) then
        return (x - 1)
      end
    end
    return n
  end

  local function Raise(callinList, gadget)
    local widgetIdx = FindWidgetIndex(callinList, widget)
    if (widgetIdx == nil) then
      return
    end

    -- starting from gIdx and counting up, find the index
    -- of the first gadget whose layer is lower** than g's
    -- and move g to right before (lowestIdx - 1) it
    -- ** lists are in reverse layer order, lowest at back
    local lowestIdx = FindLowestIndex(callinList, widgetIdx, widget.whInfo.layer)

    if (lowestIdx > widgetIdx) then
      -- insert first since lowestIdx is larger
      table.insert(callinList, lowestIdx, widget)
      table.remove(callinList, widgetIdx)
    end
  end

  Raise(self.widgets, widget)

  for _,listname in ipairs(callInLists) do
    if (widget[listname] ~= nil) then
      Raise(self[listname .. 'List'], widget)
    end
  end
end


function widgetHandler:LowerWidget(widget)
  if (widget == nil) then
    return
  end

  local function FindHighestIndex(t, i, layer)
    for x = (i - 1), 1, -1 do
      if (t[x].whInfo.layer > layer) then
        return (x + 1)
      end
    end
    return 1
  end

  local function Lower(callinList, gadget)
    local widgetIdx = FindWidgetIndex(callinList, widget)
    if (widgetIdx == nil) then
      return
    end

    -- starting from wIdx and counting down, find the index
    -- of the first widget whose layer is higher** than g's
    -- and move g to right after (highestIdx + 1) it
    -- ** lists are in reverse layer order, highest at front
    local highestIdx = FindHighestIndex(callinList, widgetIdx, widget.whInfo.layer)

    if (highestIdx < widgetIdx) then
      -- remove first since highestIdx is smaller
      table.remove(callinList, widgetIdx)
      table.insert(callinList, highestIdx, widget)
    end
  end

  Lower(self.widgets, widget)

  for _,listname in ipairs(callInLists) do
    if (widget[listname] ~= nil) then
      Lower(self[listname .. 'List'], widget)
    end
  end
end


function widgetHandler:FindWidget(name)
  if (type(name) ~= 'string') then
    return nil
  end
  for k,v in ipairs(self.widgets) do 
    if (name == v.whInfo.name) then
      return v,k
    end
  end
  return nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Global var/func management
--

function widgetHandler:RegisterGlobal(owner, name, value)
  if ((name == nil)        or
      (_G[name])           or
      (self.globals[name]) or
      (CallInsMap[name])) then
    return false
  end
  _G[name] = value
  self.globals[name] = owner
  return true
end


function widgetHandler:DeregisterGlobal(owner, name)
  if ((name == nil) or (self.globals[name] and (self.globals[name] ~= owner))) then
    return false
  end
  _G[name] = nil
  self.globals[name] = nil
  return true
end


function widgetHandler:SetGlobal(owner, name, value)
  if ((name == nil) or (self.globals[name] ~= owner)) then
    return false
  end
  _G[name] = value
  return true
end


function widgetHandler:RemoveWidgetGlobals(owner)
  local count = 0
  for name, o in pairs(self.globals) do
    if (o == owner) then
      _G[name] = nil
      self.globals[name] = nil
      count = count + 1
    end
  end
  return count
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Helper facilities
--

local hourTimer = 0


function widgetHandler:GetHourTimer()
  return hourTimer
end

function widgetHandler:GetViewSizes()
  --FIXME remove
  return gl.GetViewSizes()
end

function widgetHandler:ForceLayout()
  forceLayout = true  --  in main.lua
end


function widgetHandler:ConfigLayoutHandler(data)
  ConfigLayoutHandler(data)
end

function widgetHandler:isStable()
  return isStable
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  The call-in distribution routines
--

function widgetHandler:Shutdown()
  -- record if we will allow user widgets on next load
  if self.__allowUserWidgets~=nil then 
      self.allowUserWidgets = self.__allowUserWidgets
  end
  self.configData.allowUserWidgets = self.allowUserWidgets
  
  -- save config
  if self.__blankOutConfig then
    table.save({["allowUserWidgets"]=self.allowUserWidgets}, CONFIG_FILENAME, '-- Widget Custom Data (reset)')  
    table.save({}, ORDER_FILENAME, '-- Widget Order List (reset)')  
  else
    self:SaveConfigData()
    self:SaveOrderList()
  end
  
  for _,w in r_ipairs(self.ShutdownList) do
    w:Shutdown()
  end
  return
end

function widgetHandler:Update()
  local deltaTime = Spring.GetLastUpdateSeconds()
  -- update the hour timer
  hourTimer = (hourTimer + deltaTime)%3600
  for _,w in r_ipairs(self.UpdateList) do
    w:Update(deltaTime)
  end
  return
end


function widgetHandler:ConfigureLayout(command)
  if (command == 'tweakgui') then
    self.tweakMode = true
    Spring.Echo("LuaUI TweakMode: ON")
    return true
  elseif (command == 'reconf') then
    self:SendConfigData()
    return true
  elseif (command == 'selector') then
    for _,w in r_ipairs(self.widgets) do
      if (w.whInfo.basename == SELECTOR_BASENAME) then
        return true  -- there can only be one
      end
    end
    local sw = self:LoadWidget(LUAUI_DIRNAME .. SELECTOR_BASENAME, VFS.RAW_FIRST)
    self:InsertWidget(sw)
    self:RaiseWidget(sw)
    return true
  elseif (string.find(command, 'togglewidget') == 1) then
    self:ToggleWidget(string.sub(command, 14))
    return true
  elseif (string.find(command, 'enablewidget') == 1) then
    self:EnableWidget(string.sub(command, 14))
    return true
  elseif (string.find(command, 'disablewidget') == 1) then
    self:DisableWidget(string.sub(command, 15))
    return true
  end

  if (self.actionHandler:TextAction(command)) then
    return true
  end

  return false
end


function widgetHandler:CommandNotify(id, params, options)
  for _,w in r_ipairs(self.CommandNotifyList) do
    if (w:CommandNotify(id, params, options)) then
      return true
    end
  end
  return false
end

function widgetHandler:AddConsoleLine(msg, priority)
  if msg:find("<<IGNOREME>>") then return end --TODO: Remove this
  for _,w in r_ipairs(self.AddConsoleLineList) do
    w:AddConsoleLine(msg, priority)
  end
  return
end



function widgetHandler:GroupChanged(groupID)
  for _,w in r_ipairs(self.GroupChangedList) do
    w:GroupChanged(groupID)
  end
  return
end


function widgetHandler:CommandsChanged()
  self.inCommandsChanged = true
  self.customCommands = {}
  for _,w in r_ipairs(self.CommandsChangedList) do
    w:CommandsChanged()
  end
  self.inCommandsChanged = false
  return
end


--------------------------------------------------------------------------------
--
--  Drawing call-ins
--


function widgetHandler:ViewResize(viewGeometry)
  local vsx = viewGeometry.viewSizeX
  local vsy = viewGeometry.viewSizeY

  for _,w in r_ipairs(self.ViewResizeList) do
    w:ViewResize(vsx, vsy, viewGeometry)
  end
  return
end

function widgetHandler:DrawScreen()
  if (Spring.IsGUIHidden()) then
    return
  end

  if (self.tweakMode) then
    gl.Color(0, 0, 0, 0.5)
    local sx, sy, px, py = Spring.GetViewGeometry()
    gl.Shape(GL.QUADS, {
      {v = { px,  py }}, {v = { px+sx, py }}, {v = { px+sx, py+sy }}, {v = { px, py+sy }}
    })
    gl.Color(1, 1, 1)
  end
  for _,w in r_ipairs(self.DrawScreenList) do
    w:DrawScreen()
    if (self.tweakMode and w.TweakDrawScreen) then
      w:TweakDrawScreen()
    end
  end
  return
end


function widgetHandler:DrawGenesis()
  for _,w in r_ipairs(self.DrawGenesisList) do
    w:DrawGenesis()
  end
  return
end


function widgetHandler:DrawWorld()
  for _,w in r_ipairs(self.DrawWorldList) do
    w:DrawWorld()
  end
  return
end


function widgetHandler:DrawWorldPreUnit()
  for _,w in r_ipairs(self.DrawWorldPreUnitList) do
    w:DrawWorldPreUnit()
  end
  return
end


function widgetHandler:DrawWorldShadow()
  for _,w in r_ipairs(self.DrawWorldShadowList) do
    w:DrawWorldShadow()
  end
  return
end


function widgetHandler:DrawWorldReflection()
  for _,w in r_ipairs(self.DrawWorldReflectionList) do
    w:DrawWorldReflection()
  end
  return
end


function widgetHandler:DrawWorldRefraction()
  for _,w in r_ipairs(self.DrawWorldRefractionList) do
    w:DrawWorldRefraction()
  end
  return
end


function widgetHandler:DrawScreenEffects(vsx, vsy)
  for _,w in r_ipairs(self.DrawScreenEffectsList) do
    w:DrawScreenEffects(vsx, vsy)
  end
  return
end


function widgetHandler:DrawInMiniMap(xSize, ySize)
  for _,w in r_ipairs(self.DrawInMiniMapList) do
    w:DrawInMiniMap(xSize, ySize)
  end
  return
end


--------------------------------------------------------------------------------
--
--  Keyboard call-ins
--

function widgetHandler:TextInput(utf8, ...)
  for _,w in r_ipairs(self.TextInputList) do
    if (w:TextInput(utf8, ...)) then
      return true
    end
  end
  return false
end

function widgetHandler:KeyPress(key, mods, isRepeat, label, unicode)
  if (self.tweakMode) then
    local mo = self.mouseOwner
    if (mo and mo.TweakKeyPress) then
      mo:TweakKeyPress(key, mods, isRepeat, label, unicode)
    end
    return true
  end

  if (self.actionHandler:KeyAction(true, key, mods, isRepeat)) then
    return true
  end

  for _,w in r_ipairs(self.KeyPressList) do
    if (w:KeyPress(key, mods, isRepeat, label, unicode)) then
      return true
    end
  end
  return false
end


function widgetHandler:KeyRelease(key, mods, label, unicode)
  if (self.tweakMode) then
    local mo = self.mouseOwner
    if (mo and mo.TweakKeyRelease) then
      mo:TweakKeyRelease(key, mods, label, unicode)
    elseif (key == KEYSYMS.ESCAPE) then
      Spring.Echo("LuaUI TweakMode: OFF")
      self.tweakMode = false
    end
    return true
  end

  if (self.actionHandler:KeyAction(false, key, mods, false)) then
    return true
  end

  for _,w in r_ipairs(self.KeyReleaseList) do
    if (w:KeyRelease(key, mods, label, unicode)) then
      return true
    end
  end
  return false
end


--------------------------------------------------------------------------------
--
--  Mouse call-ins
--

do
  local lastDrawFrame = 0
  local lastx,lasty = 0,0
  local lastWidget

  local spGetDrawFrame = Spring.GetDrawFrame

  -- local helper (not a real call-in)
  function widgetHandler:WidgetAt(x, y)
    local drawframe = spGetDrawFrame()
    if (lastDrawFrame == drawframe)and(lastx == x)and(lasty == y) then
      return lastWidget
    end

    lastDrawFrame = drawframe
    lastx = x
    lasty = y
 
    if (not self.tweakMode) then
      for _,w in r_ipairs(self.IsAboveList) do
        if (w:IsAbove(x, y)) then
          lastWidget = w
          return w
        end
      end
    else
      for _,w in r_ipairs(self.TweakIsAboveList) do
        if (w:TweakIsAbove(x, y)) then
          lastWidget = w
          return w
        end
      end
    end
    lastWidget = nil
    return nil
  end
end


function widgetHandler:MousePress(x, y, button)
  local mo = self.mouseOwner
  if (not self.tweakMode) then
    if (mo) then
      mo:MousePress(x, y, button)
      return true  --  already have an active press
    end
    for _,w in r_ipairs(self.MousePressList) do
      if (w:MousePress(x, y, button)) then
        self.mouseOwner = w
        return true
      end
    end
    return false
  else
    if (mo) then
      mo:TweakMousePress(x, y, button)
      return true  --  already have an active press
    end
    for _,w in r_ipairs(self.TweakMousePressList) do
      if (w:TweakMousePress(x, y, button)) then
        self.mouseOwner = w
        return true
      end
    end
    return true  --  always grab the mouse
  end
end


function widgetHandler:MouseMove(x, y, dx, dy, button)
  local mo = self.mouseOwner
  if (not self.tweakMode) then
    if (mo and mo.MouseMove) then
      return mo:MouseMove(x, y, dx, dy, button)
    end
  else
    if (mo and mo.TweakMouseMove) then
      mo:TweakMouseMove(x, y, dx, dy, button)
    end
    return true
  end
end


function widgetHandler:MouseRelease(x, y, button)
  local mo = self.mouseOwner
  local mx, my, lmb, mmb, rmb = Spring.GetMouseState()
  if (not (lmb or mmb or rmb)) then
    self.mouseOwner = nil
  end

  if (not self.tweakMode) then
    if (mo and mo.MouseRelease) then
      return mo:MouseRelease(x, y, button)
    end
    return false
  else
    if (mo and mo.TweakMouseRelease) then
      mo:TweakMouseRelease(x, y, button)
    end
    return false
  end
end


function widgetHandler:MouseWheel(up, value)
  if (not self.tweakMode) then
    for _,w in r_ipairs(self.MouseWheelList) do
      if (w:MouseWheel(up, value)) then
        return true
      end
    end
    return false
  else
    for _,w in r_ipairs(self.TweakMouseWheelList) do
      if (w:TweakMouseWheel(up, value)) then
        return true
      end
    end
    return false -- FIXME: always grab in tweakmode?
  end
end


function widgetHandler:IsAbove(x, y)
  if (self.tweakMode) then
    return true
  end
  return (widgetHandler:WidgetAt(x, y) ~= nil)
end


function widgetHandler:GetTooltip(x, y)
  if (not self.tweakMode) then
    for _,w in r_ipairs(self.GetTooltipList) do
      if (w:IsAbove(x, y)) then
        local tip = w:GetTooltip(x, y)
        if ((type(tip) == 'string') and (#tip > 0)) then
          return tip
        end
      end
    end
    return ""
  else
    for _,w in r_ipairs(self.TweakGetTooltipList) do
      if (w:TweakIsAbove(x, y)) then
        local tip = w:TweakGetTooltip(x, y) or ''
        if ((type(tip) == 'string') and (#tip > 0)) then
          return tip
        end
      end
    end
    return "Tweak Mode  --  hit ESCAPE to cancel"
  end
end


--------------------------------------------------------------------------------
--
--  Game call-ins
--

function widgetHandler:GamePreload()
  for _,w in r_ipairs(self.GamePreloadList) do
    w:GamePreload()
  end
  return
end


function widgetHandler:GameStart()
  for _,w in r_ipairs(self.GameStartList) do
    w:GameStart()
  end
  return
end


function widgetHandler:GameOver(winningAllyTeams)
  for _,w in r_ipairs(self.GameOverList) do
    w:GameOver(winningAllyTeams)
  end
  return
end


function widgetHandler:TeamDied(teamID)
  for _,w in r_ipairs(self.TeamDiedList) do
    w:TeamDied(teamID)
  end
  return
end


function widgetHandler:TeamChanged(teamID)
  for _,w in r_ipairs(self.TeamChangedList) do
    w:TeamChanged(teamID)
  end
  return
end


function widgetHandler:PlayerAdded(playerID, reason)
  --ListMutedPlayers()
  for _,w in r_ipairs(self.PlayerAddedList) do
    w:PlayerAdded(playerID, reason)
  end
  return
end


function widgetHandler:PlayerChanged(playerID)
  for _,w in r_ipairs(self.PlayerChangedList) do
    w:PlayerChanged(playerID)
  end
  return
end


function widgetHandler:PlayerRemoved(playerID, reason)
  for _,w in r_ipairs(self.PlayerRemovedList) do
    w:PlayerRemoved(playerID, reason)
  end
  return
end


function widgetHandler:GameFrame(frameNum)
  for _,w in r_ipairs(self.GameFrameList) do
    w:GameFrame(frameNum)
  end
  return
end


function widgetHandler:ShockFront(power, dx, dy, dz)
  for _,w in r_ipairs(self.ShockFrontList) do
    w:ShockFront(power, dx, dy, dz)
  end
  return
end


function widgetHandler:WorldTooltip(ttType, ...)
  for _,w in r_ipairs(self.WorldTooltipList) do
    local tt = w:WorldTooltip(ttType, ...)
    if ((type(tt) == 'string') and (#tt > 0)) then
      return tt
    end
  end
  return
end


function widgetHandler:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
  local retval = false
  for _,w in r_ipairs(self.MapDrawCmdList) do
    local takeEvent = w:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
    if (takeEvent) then
      retval = true
    end
  end
  return retval
end


function widgetHandler:GameSetup(state, ready, playerStates)
  for _,w in r_ipairs(self.GameSetupList) do
    local success, newReady = w:GameSetup(state, ready, playerStates)
    if (success) then
      return true, newReady
    end
  end
  return false
end


function widgetHandler:DefaultCommand(...)
  for _,w in r_ipairs(self.DefaultCommandList) do
    local result = w:DefaultCommand(...)
    if (type(result) == 'number') then
      return result
    end
  end
  return nil  --  not a number, use the default engine command
end


--------------------------------------------------------------------------------
--
--  Unit call-ins
--

function widgetHandler:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  for _,w in r_ipairs(self.UnitCreatedList) do
    w:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  end
  return
end


function widgetHandler:UnitFinished(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitFinishedList) do
    w:UnitFinished(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitFromFactory(unitID, unitDefID, unitTeam,
                                       factID, factDefID, userOrders)
  for _,w in r_ipairs(self.UnitFromFactoryList) do
    w:UnitFromFactory(unitID, unitDefID, unitTeam,
                      factID, factDefID, userOrders)
  end
  return
end


function widgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitDestroyedList) do
    w:UnitDestroyed(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitExperience(unitID,     unitDefID,     unitTeam,
                                      experience, oldExperience)
  for _,w in r_ipairs(self.UnitExperienceList) do
    w:UnitExperience(unitID,     unitDefID,     unitTeam,
                    experience, oldExperience)
  end
  return
end


function widgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  for _,w in r_ipairs(self.UnitTakenList) do
    w:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  end
  return
end


function widgetHandler:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  for _,w in r_ipairs(self.UnitGivenList) do
    w:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  end
  return
end


function widgetHandler:UnitIdle(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitIdleList) do
    w:UnitIdle(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitCommand(unitID, unitDefID, unitTeam,
                                   cmdId, cmdOpts, cmdParams, cmdTag)
  for _,w in r_ipairs(self.UnitCommandList) do
    w:UnitCommand(unitID, unitDefID, unitTeam,
                  cmdId, cmdOpts, cmdParams, cmdTag)
  end
  return
end


function widgetHandler:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts)
  for _,w in r_ipairs(self.UnitCmdDoneList) do
    w:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts)
  end
  return
end


function widgetHandler:UnitDamaged(unitID, unitDefID, unitTeam,
                                   damage, paralyzer)
  for _,w in r_ipairs(self.UnitDamagedList) do
    w:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  end
  return
end


function widgetHandler:UnitEnteredRadar(unitID, unitTeam)
  for _,w in r_ipairs(self.UnitEnteredRadarList) do
    w:UnitEnteredRadar(unitID, unitTeam)
  end
  return
end


function widgetHandler:UnitEnteredLos(unitID, unitTeam)
  for _,w in r_ipairs(self.UnitEnteredLosList) do
    w:UnitEnteredLos(unitID, unitTeam)
  end
  return
end


function widgetHandler:UnitLeftRadar(unitID, unitTeam)
  for _,w in r_ipairs(self.UnitLeftRadarList) do
    w:UnitLeftRadar(unitID, unitTeam)
  end
  return
end


function widgetHandler:UnitLeftLos(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitLeftLosList) do
    w:UnitLeftLos(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitEnteredWater(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitEnteredWaterList) do
    w:UnitEnteredWater(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitEnteredAir(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitEnteredAirList) do
    w:UnitEnteredAir(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitLeftWater(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitLeftWaterList) do
    w:UnitLeftWater(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitLeftAir(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitLeftAirList) do
    w:UnitLeftAir(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitSeismicPing(x, y, z, strength)
  for _,w in r_ipairs(self.UnitSeismicPingList) do
    w:UnitSeismicPing(x, y, z, strength)
  end
  return
end


function widgetHandler:UnitLoaded(unitID, unitDefID, unitTeam,
                                  transportID, transportTeam)
  for _,w in r_ipairs(self.UnitLoadedList) do
    w:UnitLoaded(unitID, unitDefID, unitTeam,
                 transportID, transportTeam)
  end
  return
end


function widgetHandler:UnitUnloaded(unitID, unitDefID, unitTeam,
                                    transportID, transportTeam)
  for _,w in r_ipairs(self.UnitUnloadedList) do
    w:UnitUnloaded(unitID, unitDefID, unitTeam,
                   transportID, transportTeam)
  end
  return
end


function widgetHandler:UnitCloaked(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitCloakedList) do
    w:UnitCloaked(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitDecloaked(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitDecloakedList) do
    w:UnitDecloaked(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:UnitMoveFailed(unitID, unitDefID, unitTeam)
  for _,w in r_ipairs(self.UnitMoveFailedList) do
    w:UnitMoveFailed(unitID, unitDefID, unitTeam)
  end
  return
end


function widgetHandler:RecvLuaMsg(msg, playerID)
  local retval = false
  for _,w in r_ipairs(self.RecvLuaMsgList) do
    if (w:RecvLuaMsg(msg, playerID)) then
      retval = true
    end
  end
  return retval  --  FIXME  --  another actionHandler type?
end


function widgetHandler:StockpileChanged(unitID, unitDefID, unitTeam,
                                        weaponNum, oldCount, newCount)
  for _,w in r_ipairs(self.StockpileChangedList) do
    w:StockpileChanged(unitID, unitDefID, unitTeam,
                       weaponNum, oldCount, newCount)
  end
  return
end


function widgetHandler:GameProgress(frame)
  for _,w in r_ipairs(self.GameProgressList) do
    w:GameProgress(frame)
  end
  return
end


function widgetHandler:UnsyncedHeightMapUpdate(x1,z1,x2,z2)
  for _,w in r_ipairs(self.UnsyncedHeightMapUpdateList) do
    w:UnsyncedHeightMapUpdate(x1,z1,x2,z2)
  end
  return
end
-------------------------------------------------------------------------------- 
 
--  Feature call-ins 
-- 
 
function widgetHandler:FeatureCreated(featureID, allyTeam) 
 for _,w in r_ipairs(self.FeatureCreatedList) do 
   w:FeatureCreated(featureID, allyTeam) 
  end 
  return 
end 


function widgetHandler:FeatureDestroyed(featureID, allyTeam) 
  for _,w in r_ipairs(self.FeatureDestroyedList) do 
    w:FeatureDestroyed(featureID, allyTeam) 
  end 
 return 
end 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

widgetHandler:Initialize()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
