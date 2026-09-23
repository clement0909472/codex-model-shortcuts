local M = {}

M.config = {
  codexBundleIDs = { ["com.openai.codex"] = true, ["app.cdxmux.multi"] = true },
  shortcutModifiers = { "cmd", "alt" },
  keyStrokeDelay = 18000,
  -- Keep animation waits at menu boundaries; plain navigation stays quick.
  timing = {
    modifiersReleasedPoll = 0.01,
    picker = 0.20,
    submenu = 0.16,
    modelSelected = 0.08,
    speedChanged = 0.06,
    move = 0.02,
  },
  presets = {
    { key = "M", label = "Astra High", model = "GPT-6 Astra", effort = 2, fast = false },
    { key = "L", label = "Astra Low", model = "GPT-6 Astra", effort = 0, fast = false },
    { key = "K", label = "Sol High", model = "GPT-6 Sol", effort = 2, fast = false },
    { key = "J", label = "Luna Max", model = "GPT-6 Luna", effort = 4, fast = false },
    { key = "H", label = "Astra Low Fast", model = "GPT-6 Astra", effort = 0, fast = true },
  },
}

-- Menu order confirmed by the user's September 2026 screenshot.
local models = { "GPT-6 Astra", "GPT-6 Sol", "GPT-6 Luna",
  "GPT-5.6 Sol", "GPT-5.6 Terra", "GPT-5.6 Luna", "GPT-5.5" }
local efforts = {
  { "Léger", "léger", "Low", "low" },
  { "Moyen", "moyen", "Medium", "medium" },
  { "Élevé", "élevé", "High", "high" },
  { "Très élevé", "très élevé", "Extra high", "XHigh", "xhigh" },
  { "Maximum", "maximum", "Max", "max" },
  { "Ultra", "ultra" },
}

function M.parseSelection(label)
  if type(label) ~= "string" then return nil end
  for index, model in ipairs(models) do
    if label:sub(1, #model) == model then
      local suffix = label:sub(#model + 1):match("^%s*(.-)%s*$")
      for level, aliases in ipairs(efforts) do
        for _, alias in ipairs(aliases) do
          if suffix == alias then
            return { model = model, index = index, effort = level - 1 }
          end
        end
      end
    end
  end
end

function M.plan(current, preset)
  local target
  for index, model in ipairs(models) do
    if preset.model == model then target = index end
  end
  assert(target and current.index and current.effort, "Unknown model/effort")
  local effort = current.effort
  -- User-observed fallback when Luna cannot retain Ultra.
  if preset.model == "GPT-6 Luna" and effort == 5 then effort = 1 end
  return target - current.index, preset.effort - effort
end

local busy = false
local activeWindow
local activeBundleID

local function codexIsFrontmost()
  local app = hs.application.frontmostApplication()
  return app and M.config.codexBundleIDs[app:bundleID()] == true
end

local function press(key)
  hs.eventtap.keyStroke({}, key, M.config.keyStrokeDelay)
end

local function afterShortcutModifiersReleased(callback)
  local modifiers = hs.eventtap.checkKeyboardModifiers()
  if modifiers.cmd or modifiers.shift or modifiers.alt or modifiers.ctrl then
    hs.timer.doAfter(M.config.timing.modifiersReleasedPoll, function()
      afterShortcutModifiersReleased(callback)
    end)
    return
  end
  callback()
end

local function runKeySequence(steps, index, done)
  if not codexIsFrontmost() then busy = false; return end
  local app = hs.application.frontmostApplication()
  if app:bundleID() ~= activeBundleID then busy = false; return end
  local root = hs.axuielement.applicationElement(app)
  if root:attributeValue("AXFocusedWindow") ~= activeWindow then
    busy = false
    return
  end
  if index > #steps then
    done()
    return
  end

  local step = steps[index]
  press(type(step) == "table" and step.key or step)
  local delay = type(step) == "table" and step.delay or M.config.timing.move
  hs.timer.doAfter(delay, function()
    runKeySequence(steps, index + 1, done)
  end)
end

local function axAttribute(element, attribute)
  local ok, value = pcall(function()
    return element:attributeValue(attribute)
  end)
  if ok then
    return value
  end
  return nil
end

-- Only target a unique model control in the focused window.
local function collectModelButtons(element, candidates, visited, depth)
  if not element or visited[element] or depth > 30 then
    return
  end
  visited[element] = true
  local role = axAttribute(element, "AXRole")
  if role == "AXButton" or role == "AXPopUpButton" or role == "AXMenuButton" then
    for _, attribute in ipairs({ "AXTitle", "AXDescription", "AXValue" }) do
      local label = axAttribute(element, attribute)
      if type(label) == "string" and (label:match("^GPT%-")
          or label == "Sélectionner l’effort" or label == "Sélectionner l'effort"
          or label == "Select effort") then
        table.insert(candidates, element)
        break
      end
    end
  end
  for _, child in ipairs(axAttribute(element, "AXChildren") or {}) do
    collectModelButtons(child, candidates, visited, depth + 1)
  end
end

local function modelButton()
  if not codexIsFrontmost() then
    return
  end
  local app = hs.application.frontmostApplication()
  local root = hs.axuielement.applicationElement(app)
  local window = axAttribute(root, "AXFocusedWindow")
  local candidates = {}
  collectModelButtons(window, candidates, {}, 0)
  if #candidates ~= 1 then
    hs.alert.show("Codex : bouton modèle introuvable ou ambigu (" .. #candidates .. ")")
    return
  end
  local frame = axAttribute(candidates[1], "AXFrame")
  local bounds = axAttribute(window, "AXFrame")
  if not frame or not bounds or frame.w <= 0 or frame.h <= 0
      or frame.x < bounds.x or frame.y < bounds.y
      or frame.x + frame.w > bounds.x + bounds.w
      or frame.y + frame.h > bounds.y + bounds.h then
    hs.alert.show("Codex : position du bouton modèle indisponible")
    return
  end
  return candidates[1], window, frame, app:bundleID()
end

local function clickFrame(frame)
  hs.eventtap.leftClick({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
end

function M.openPicker()
  local button, window, frame = modelButton()
  if not button then return end
  -- Resolve the frame on every invocation, including after moving displays.
  clickFrame(frame)
  return button, window
end

local function readSelection(button)
  for _, attribute in ipairs({ "AXTitle", "AXDescription", "AXValue" }) do
    local selected = M.parseSelection(axAttribute(button, attribute))
    if selected then return selected end
  end
end

function M.startPickerTest()
  if M.pickerTestHotkey then
    M.pickerTestHotkey:delete()
  end
  M.pickerTestHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
    afterShortcutModifiersReleased(M.openPicker)
  end)
end

local function appendMoves(steps, delta, negative, positive)
  for _ = 1, math.abs(delta) do
    table.insert(steps, delta < 0 and negative or positive)
  end
end

local function fail(message)
  busy = false
  hs.alert.show("Codex : " .. message, 12)
end

local function focusedElement()
  local app = hs.application.frontmostApplication()
  return axAttribute(hs.axuielement.applicationElement(app), "AXFocusedUIElement")
end

function M.readFast(control)
  local role = axAttribute(control, "AXRole")
  -- The menu label names the action, not the current speed. AXSelected is
  -- menu selection state and stays false even when Fast is active.
  if role == "AXMenuItem" or role == "AXButton" then
    for _, attribute in ipairs({ "AXTitle", "AXDescription" }) do
      local label = axAttribute(control, attribute)
      if type(label) == "string" then
        label = label:lower():match("^%s*(.-)%s*$")
        if label == "activer le mode standard" or label == "enable standard mode" then return true end
        if label == "activer le mode rapide" or label == "enable fast mode" then return false end
      end
    end
  end
  if role == "AXMenuItem" then return nil end
  local text = ""
  for _, attribute in ipairs({ "AXTitle", "AXDescription", "AXHelp" }) do
    local value = axAttribute(control, attribute)
    if type(value) == "string" then text = text .. " " .. value:lower() end
  end
  if role ~= "AXCheckBox" and role ~= "AXSwitch"
      and not text:find("fast", 1, true) and not text:find("rapide", 1, true)
      and not text:find("speed", 1, true) and not text:find("vitesse", 1, true) then
    return nil
  end
  for _, attribute in ipairs({ "AXValue", "AXSelected" }) do
    local value = axAttribute(control, attribute)
    if value == true or value == 1 or value == "1" then return true end
    if value == false or value == 0 or value == "0" then return false end
  end
  return nil
end

local function fastDetails(control)
  local role = axAttribute(control, "AXRole")
  -- Only describe controls, never dump a focused composer or conversation.
  if role ~= "AXButton" and role ~= "AXCheckBox" and role ~= "AXSwitch"
      and role ~= "AXPopUpButton" and role ~= "AXMenuItem" then
    return "focus=" .. tostring(role)
  end
  local details = { role }
  for _, attribute in ipairs({ "AXTitle", "AXDescription", "AXValue", "AXSelected" }) do
    local value = axAttribute(control, attribute)
    table.insert(details, attribute .. "=" .. tostring(value):sub(1, 100))
  end
  return table.concat(details, " | ")
end

local function setSpeed(wanted, done)
  runKeySequence({ "down" }, 1, function()
    local control = focusedElement()
    local enabled = M.readFast(control)
    if enabled == nil then
      fail("état Fast illisible AVANT Entrée\n" .. fastDetails(control))
      return
    end
    if enabled == wanted then done(); return end
    runKeySequence({ { key = "return", delay = M.config.timing.speedChanged } }, 1, function()
      local after = focusedElement()
      if M.readFast(after) ~= wanted then
        fail("bascule Fast non confirmée APRÈS Entrée (attendu=" .. tostring(wanted)
          .. ")\n" .. fastDetails(after))
        return
      end
      done()
    end)
  end)
end

local function selectPreset(preset)
  if busy or not codexIsFrontmost() then return end
  local button, window, frame, bundleID = modelButton()
  if not button then return end
  local current = readSelection(button)
  if not current then
    fail("modèle/effort actuel illisible, aucun changement")
    return
  end
  local modelDelta, effortDelta = M.plan(current, preset)
  busy, activeWindow, activeBundleID = true, window, bundleID
  clickFrame(frame)
  local steps = { "down" }
  if modelDelta ~= 0 then
    table.insert(steps, { key = "return", delay = M.config.timing.submenu })
    appendMoves(steps, modelDelta, "up", "down")
    table.insert(steps, { key = "return", delay = M.config.timing.modelSelected })
  end
  hs.timer.doAfter(M.config.timing.picker, function()
    runKeySequence(steps, 1, function()
      -- Speed is handled before reasoning, using the current control state.
      setSpeed(preset.fast, function()
        local reasoning = { "down", "down" }
        appendMoves(reasoning, effortDelta, "left", "right")
        runKeySequence(reasoning, 1, function()
          -- Codex closes the picker and restores input focus on Return.
          -- No subsequent key, click, notification, or timer.
          press("return")
          busy = false
        end)
      end)
    end)
  end)
end

function M.start()
  if M.pickerTestHotkey then M.pickerTestHotkey:delete(); M.pickerTestHotkey = nil end
  for _, hotkey in ipairs(M.hotkeys or {}) do hotkey:delete() end
  M.hotkeys = {}
  for _, preset in ipairs(M.config.presets) do
    local boundPreset = preset
    table.insert(M.hotkeys, hs.hotkey.bind(M.config.shortcutModifiers, boundPreset.key, function()
      afterShortcutModifiersReleased(function() selectPreset(boundPreset) end)
    end))
  end
end

return M
