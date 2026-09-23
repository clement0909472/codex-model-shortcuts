-- Run with: lua test-picker.lua. Uses mocks only, never controls an application.
local function element(attributes)
  return { attributeValue = function(_, key) return attributes[key] end }
end
local bundle, clicks, alerts, timers = "com.openai.codex", {}, {}, {}
local modifiers, binding = {}, nil
local bounds = { x = 0, y = 0, w = 1500, h = 1000 }
local buttonAttributes = {
  AXRole = "AXButton", AXTitle = "GPT-6 Astra Léger",
  AXFrame = { x = 1000, y = 800, w = 200, h = 40 },
}
local button = element(buttonAttributes)
local windowAttributes = { AXFrame = bounds, AXChildren = { button } }
local root = element({ AXFocusedWindow = element(windowAttributes) })
hs = {
  application = { frontmostApplication = function()
    return { bundleID = function() return bundle end }
  end },
  axuielement = { applicationElement = function() return root end },
  eventtap = {
    checkKeyboardModifiers = function() return modifiers end,
    leftClick = function(point) table.insert(clicks, point) end,
  },
  timer = { doAfter = function(_, callback) table.insert(timers, callback) end },
  alert = { show = function(message) table.insert(alerts, message) end },
  hotkey = { bind = function(mods, key, callback)
    assert(mods[1] == "cmd" and mods[2] == "alt" and key == "M")
    binding = callback
    return { delete = function() end }
  end },
}
local shortcuts = dofile("codex-model-shortcuts.lua")
shortcuts.startPickerTest()
modifiers = { alt = true }
binding()
assert(#clicks == 0 and #timers == 1, "Wait for Option release")
modifiers = {}
timers[1]()
assert(#clicks == 1 and clicks[1].x == 1100 and clicks[1].y == 820)
-- A moved window on a monitor with negative coordinates uses its new frame.
bounds.x = -2000
buttonAttributes.AXFrame.x = -1000
shortcuts.openPicker()
assert(#clicks == 2 and clicks[2].x == -900)
bundle = "other.app"
shortcuts.openPicker()
assert(#clicks == 2, "Do not click outside Codex")
bundle = "com.openai.codex"
windowAttributes.AXChildren = { button, element(buttonAttributes) }
shortcuts.openPicker()
assert(#clicks == 2 and #alerts == 1, "Do not guess between buttons")
windowAttributes.AXChildren = { element({ AXRole = "AXStaticText", AXTitle = "GPT-6 Astra" }) }
shortcuts.openPicker()
assert(#clicks == 2 and #alerts == 2, "Do not click conversation text")
windowAttributes.AXChildren = { button }
buttonAttributes.AXFrame.x = 9000
shortcuts.openPicker()
assert(#clicks == 2 and #alerts == 3, "Do not click off-window elements")
print("Picker checks passed (mock accessibility, no UI interaction)")

-- Minimal deltas, including the Ultra -> Luna -> Medium fallback.
local function plan(label, key, modelDelta, effortDelta)
  local selected = assert(shortcuts.parseSelection(label), label)
  for _, preset in ipairs(shortcuts.config.presets) do
    if preset.key == key then
      local actualModel, actualEffort = shortcuts.plan(selected, preset)
      assert(actualModel == modelDelta and actualEffort == effortDelta, label .. ' -> ' .. key)
      return
    end
  end
  error('Missing preset: ' .. key)
end
plan('GPT-6 Luna Maximum', 'M', -2, -2)
plan('GPT-6 Astra Élevé', 'K', 1, 0)
plan('GPT-6 Sol Ultra', 'J', 1, 3)
plan('GPT-6 Luna Maximum', 'L', -2, -4)
plan('GPT-6 Astra Élevé', 'L', 0, -2)
plan('GPT-6 Luna Léger', 'J', 0, 4)
plan('GPT-6 Astra Très élevé', 'M', 0, -1)
plan('GPT-6 Astra Low', 'H', 0, 0)
assert(not shortcuts.parseSelection('GPT-6 Astra Inconnu'))
assert(not shortcuts.parseSelection('Sélectionner l’effort'))
print('Minimal model/effort sequence checks passed')

assert(shortcuts.readFast(element({ AXRole = 'AXSwitch', AXValue = 1 })) == true)
assert(shortcuts.readFast(element({ AXRole = 'AXButton', AXTitle = 'Speed', AXValue = 0 })) == false)
assert(shortcuts.readFast(element({ AXRole = 'AXButton', AXTitle = 'Speed' })) == nil)
assert(shortcuts.readFast(element({ AXRole = 'AXButton', AXTitle = 'Reset', AXValue = 0 })) == nil)

-- Regression from the user's alert: AXSelected=false even with Fast active.
assert(shortcuts.readFast(element({ AXRole = 'AXMenuItem',
  AXTitle = 'Activer le mode standard', AXValue = '', AXSelected = false })) == true)
assert(shortcuts.readFast(element({ AXRole = 'AXMenuItem',
  AXTitle = 'Activer le mode rapide', AXValue = '', AXSelected = true })) == false)
assert(shortcuts.readFast(element({ AXRole = 'AXMenuItem',
  AXTitle = 'Speed', AXSelected = false })) == nil)

-- Simulate the keyboard contract supplied by the user, including sticky effort.
local names = { 'GPT-6 Astra', 'GPT-6 Sol', 'GPT-6 Luna' }
local levels = { 'Léger', 'Moyen', 'Élevé', 'Très élevé', 'Maximum', 'Ultra' }
local currentModel, currentEffort, fast, phase, position, menuIndex, toggleCount, arrowCount
local submenuOpens, modelArrows, keyCount = 0, 0, 0
local bindings = {}
local speed = {}
local rootAttributes = { AXFocusedWindow = element(windowAttributes) }
root = element(rootAttributes)
bounds.x, buttonAttributes.AXFrame.x = 0, 1000
windowAttributes.AXChildren = { button }
local function update()
  buttonAttributes.AXTitle = names[currentModel] .. ' ' .. levels[currentEffort + 1]
  speed = { AXRole = 'AXMenuItem',
    AXTitle = fast and 'Activer le mode standard' or 'Activer le mode rapide',
    AXValue = '', AXSelected = false }
  rootAttributes.AXFocusedUIElement = position == 1 and element(speed) or nil
end
hs.hotkey.bind = function(mods, key, callback)
  assert(mods[1] == 'cmd' and mods[2] == 'alt')
  bindings[key] = callback
  return { delete = function() end }
end
hs.eventtap.leftClick = function()
  assert(phase == 'closed')
  phase, position = 'panel', -1
end
hs.eventtap.keyStroke = function(_, key)
  keyCount = keyCount + 1
  if phase == 'list' then
    if key == 'up' or key == 'down' then modelArrows = modelArrows + 1 end
    if key == 'up' then menuIndex = menuIndex - 1 end
    if key == 'down' then menuIndex = menuIndex + 1 end
    if key == 'return' then
      currentModel = menuIndex
      if currentModel == 3 and currentEffort == 5 then currentEffort = 1 end
      phase, position = 'panel', 0
    end
  elseif phase == 'panel' then
    if key == 'down' then position = position + 1 end
    if key == 'return' and position == 0 then
      submenuOpens = submenuOpens + 1
      phase, menuIndex = 'list', currentModel
    elseif key == 'return' and position == 1 then
      fast, toggleCount = not fast, toggleCount + 1
    elseif key == 'return' and position == 3 then
      phase = 'closed'
    elseif key == 'left' or key == 'right' then
      assert(position == 3, 'Reasoning arrows must target the slider')
      arrowCount = arrowCount + 1
      currentEffort = math.max(0, math.min(currentModel == 3 and 4 or 5,
        currentEffort + (key == 'left' and -1 or 1)))
    end
  else
    error('No keyboard action is allowed after reasoning is confirmed: ' .. key)
  end
  update()
end
local composer = element({ AXRole = 'AXTextArea', AXFocused = true,
  AXFrame = { x = 100, y = 500, w = 600, h = 100 } })
local focusWrites = 0
composer.setAttributeValue = function() focusWrites = focusWrites + 1 end
windowAttributes.AXChildren = { button, composer }
hs.application.get = function() return hs.application.frontmostApplication() end
shortcuts.start()
local cases = 0
for model = 1, 3 do
  for effort = 0, (model == 3 and 4 or 5) do
    for _, initiallyFast in ipairs({ false, true }) do
      for _, preset in ipairs(shortcuts.config.presets) do
        currentModel, currentEffort, fast = model, effort, initiallyFast
        phase, position, toggleCount, arrowCount = 'closed', -1, 0, 0
        timers, alerts = {}, {}
        submenuOpens, modelArrows, keyCount = 0, 0, 0
        update()
        bindings[preset.key]()
        local count = 0
        while #timers > 0 do
          table.remove(timers, 1)()
          count = count + 1
          assert(count < 100, 'Timer loop')
        end
        assert(names[currentModel] == preset.model and currentEffort == preset.effort)
        assert(fast == preset.fast and phase == 'closed')
        assert(toggleCount == (initiallyFast == preset.fast and 0 or 1))
        local retained = preset.model == 'GPT-6 Luna' and effort == 5 and 1 or effort
        assert(arrowCount == math.abs(preset.effort - retained), 'Use minimal arrows')
        assert(#alerts == 0, 'Successful selection must finish silently')
        local changesModel = names[model] ~= preset.model
        assert(submenuOpens == (changesModel and 1 or 0), 'Skip model list when already selected')
        assert(modelArrows == math.abs(currentModel - model), 'Use minimal model arrows')
        assert(keyCount == 5 + arrowCount + toggleCount
          + (changesModel and 2 + modelArrows or 0), 'No redundant keys')
        cases = cases + 1
      end
    end
  end
end
-- Unknown speed state must stop, without blindly toggling it.
currentModel, currentEffort, fast = 1, 0, false
phase, position, toggleCount, arrowCount = 'closed', -1, 0, 0
alerts, timers = {}, {}
update()
local normalReadFast = shortcuts.readFast
shortcuts.readFast = function() return nil end
bindings.H()
while #timers > 0 do table.remove(timers, 1)() end
assert(toggleCount == 0 and phase == 'panel' and position == 1)
assert(alerts[#alerts]:find('Fast illisible', 1, true))
shortcuts.readFast = normalReadFast
print(cases .. ' preset transitions passed (mock UI only)')
-- A queued shortcut must not type into another application after focus changes.
currentModel, currentEffort, fast = 1, 0, false
phase, position, toggleCount, arrowCount = 'closed', -1, 0, 0
timers = {}
update()
bindings.M()
bindings.M() -- ignored while the first selection is running
bundle = 'other.app'
while #timers > 0 do table.remove(timers, 1)() end
assert(currentModel == 1 and currentEffort == 0 and position == -1)
bundle = 'com.openai.codex'
print('Focus-change cancellation and overlapping shortcut checks passed')

assert(focusWrites == 0, "Preset completion must not refocus the composer or move its caret")
