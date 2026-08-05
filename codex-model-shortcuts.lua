local M = {}

M.config = {
  codexBundleID = "com.openai.codex",
  shortcutModifiers = { "cmd", "shift" },
  pickerModifiers = { "ctrl", "shift" },
  pickerKey = "m",
  timing = {
    modifiersReleasedPoll = 0.005,
    trigger = 0.03,
    picker = 0.02,
    move = 0.02,
    layer = 0.02,
    final = 0.02,
    focus = 0.03,
  },
  presets = {
    {
      key = "K",
      label = "Luna High",
      steps = {
        "down", "right", "down", "down", "return",
        "left", "down", "right", "down", "down", "return",
        "escape",
      },
    },
    {
      key = "L",
      label = "Sol High",
      steps = {
        "down", "right", "return",
        "left", "down", "right", "down", "down", "return",
        "escape",
      },
    },
    {
      key = "M",
      label = "Terra High",
      steps = {
        "down", "right", "down", "return",
        "left", "down", "right", "down", "down", "return",
        "escape",
      },
    },
  },
}

local busy = false

local function codexIsFrontmost()
  local app = hs.application.frontmostApplication()
  return app and app:bundleID() == M.config.codexBundleID
end

local function press(key)
  hs.eventtap.keyStroke({}, key, 10000)
end

local function afterShortcutModifiersReleased(callback)
  local modifiers = hs.eventtap.checkKeyboardModifiers()
  if modifiers.cmd or modifiers.shift then
    hs.timer.doAfter(M.config.timing.modifiersReleasedPoll, function()
      afterShortcutModifiersReleased(callback)
    end)
    return
  end
  callback()
end

local function stepDelay(key)
  if key == "right" or key == "left" then
    return M.config.timing.layer
  end
  if key == "return" or key == "escape" then
    return M.config.timing.final
  end
  return M.config.timing.move
end

local function runKeySequence(steps, index, done)
  if index > #steps then
    done()
    return
  end

  local key = steps[index]
  press(key)
  hs.timer.doAfter(stepDelay(key), function()
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

local function collectComposerCandidates(element, candidates, visited, depth)
  if not element or visited[element] or depth > 30 then
    return
  end
  visited[element] = true

  local role = axAttribute(element, "AXRole")
  local frame = axAttribute(element, "AXFrame")
  if (role == "AXTextArea" or role == "AXTextField")
      and frame and frame.w and frame.h and frame.w > 220 and frame.h > 24 then
    table.insert(candidates, element)
  end

  local children = axAttribute(element, "AXChildren")
  if type(children) == "table" then
    for _, child in ipairs(children) do
      collectComposerCandidates(child, candidates, visited, depth + 1)
    end
  end
end

local function composerScore(element)
  local score = 0
  local role = axAttribute(element, "AXRole")
  local frame = axAttribute(element, "AXFrame")

  if role == "AXTextArea" then
    score = score + 100000
  end
  if frame then
    score = score + (frame.y or 0) + ((frame.w or 0) / 100)
  end

  for _, attribute in ipairs({ "AXDescription", "AXIdentifier", "AXPlaceholderValue", "AXTitle" }) do
    local value = axAttribute(element, attribute)
    if type(value) == "string" then
      local text = string.lower(value)
      if string.find(text, "message", 1, true)
          or string.find(text, "composer", 1, true)
          or string.find(text, "prompt", 1, true) then
        score = score + 200000
      end
    end
  end

  return score
end

local function refocusCodexComposer()
  if not codexIsFrontmost() then
    return
  end

  local app = hs.application.get(M.config.codexBundleID)
  if not app then
    return
  end

  local root = hs.axuielement.applicationElement(app)
  local candidates = {}
  collectComposerCandidates(root, candidates, {}, 0)
  table.sort(candidates, function(a, b)
    return composerScore(a) > composerScore(b)
  end)

  local composer = candidates[1]
  if not composer then
    hs.alert.show("Codex: composer not found")
    return
  end

  local focused = pcall(function()
    composer:setAttributeValue("AXFocused", true)
  end)
  if focused and axAttribute(composer, "AXFocused") == true then
    return
  end

  local frame = axAttribute(composer, "AXFrame")
  if frame then
    hs.eventtap.leftClick({
      x = frame.x + math.min(40, frame.w / 2),
      y = frame.y + (frame.h / 2),
    })
  end
end

local function selectPreset(preset)
  if busy or not codexIsFrontmost() then
    return
  end
  busy = true

  hs.timer.doAfter(M.config.timing.trigger, function()
    hs.eventtap.keyStroke(M.config.pickerModifiers, M.config.pickerKey, 50000)
    hs.timer.doAfter(M.config.timing.picker, function()
      runKeySequence(preset.steps, 1, function()
        busy = false
        hs.timer.doAfter(M.config.timing.focus, refocusCodexComposer)
        hs.alert.show("Codex: " .. preset.label)
      end)
    end)
  end)
end

function M.start()
  for _, preset in ipairs(M.config.presets) do
    local boundPreset = preset
    hs.hotkey.bind(M.config.shortcutModifiers, boundPreset.key, function()
      afterShortcutModifiersReleased(function()
        selectPreset(boundPreset)
      end)
    end)
  end
end

return M
