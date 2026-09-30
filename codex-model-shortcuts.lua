local M = {}

M.config = {
  codexBundleIDs = { ["com.openai.codex"] = true, ["app.cdxmux.multi"] = true },
  shortcutModifiers = { "cmd", "alt" },
  diagnosticDirectory = os.getenv("HOME") .. "/.hammerspoon/codex-model-shortcuts",
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
    { key = "M", label = "Astra Très élevé", model = "GPT-6 Astra", effort = 3, speed = "standard" },
    { key = "L", label = "Astra Low", model = "GPT-6 Astra", effort = 0, speed = "standard" },
    { key = "K", label = "Sol 6.1 High", model = "GPT-6.1 Sol", effort = 2, speed = "standard" },
    { key = "J", label = "Luna Max", model = "GPT-6 Luna", effort = 4, speed = "standard" },
    { key = "H", label = "Astra Low Ultrarapide", model = "GPT-6 Astra", effort = 0, speed = "ultrafast" },
  },
}

-- Current model catalog, including Sol 6.1; verify the selected model before continuing.
local models = { "GPT-6.1 Sol", "GPT-6 Astra", "GPT-6 Sol", "GPT-6 Luna",
  "GPT-5.6 Sol", "GPT-5.6 Terra", "GPT-5.6 Luna", "GPT-5.5" }
local efforts = {
  { "Minimal", "minimal", "Léger", "léger", "Faible", "Low", "low" },
  { "Moyen", "moyen", "Medium", "medium", "Standard" },
  { "Élevé", "élevé", "High", "high", "Étendu", "Extended" },
  { "Très élevé", "très élevé", "Extra high", "XHigh", "xhigh" },
  { "Maximum", "maximum", "Max", "max" },
  { "Ultra", "ultra" },
}

function M.parseSelection(label)
  if type(label) ~= "string" or label == "" then return nil end
  -- Codex strips GPT- from picker labels depending on its display flag.
  label = label:match("^([^,]+)"):gsub(" ", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
  for index, model in ipairs(models) do
    for _, name in ipairs({ model, (model:gsub("^GPT%-", "")) }) do
      if label:sub(1, #name + 1) == name .. " " then
        local suffix = label:sub(#name + 2)
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
end

local busy = false
local activeWindow
local activeBundleID
local activePreset
local speedReadings = {}
local reasoningReadings = {}
local sentKeys = {}

local function codexIsFrontmost()
  local app = hs.application.frontmostApplication()
  return app and M.config.codexBundleIDs[app:bundleID()] == true
end

local function press(key)
  sentKeys[#sentKeys + 1] = key
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

function M.openPicker()
  if not codexIsFrontmost() then return end
  local app = hs.application.frontmostApplication()
  local window = axAttribute(hs.axuielement.applicationElement(app), "AXFocusedWindow")
  if not window then return end
  sentKeys[#sentKeys + 1] = "ctrl+shift+m"
  hs.eventtap.keyStroke({ "ctrl", "shift" }, "m", M.config.keyStrokeDelay)
  return window, app:bundleID()
end

function M.startPickerTest()
  if M.pickerTestHotkey then
    M.pickerTestHotkey:delete()
  end
  M.pickerTestHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
    afterShortcutModifiersReleased(M.openPicker)
  end)
end

local function focusedElement()
  local app = hs.application.frontmostApplication()
  return axAttribute(hs.axuielement.applicationElement(app), "AXFocusedUIElement")
end

local function writeDiagnostic(report)
  local directory = M.config.diagnosticDirectory
  hs.fs.mkdir(directory)
  local path = directory .. "/diagnostic.json"
  if hs.json.write(report, path, true, true) then return path end
end

local function fail(message)
  busy = false
  -- Keep the actual failing state, before another shortcut replaces the menu.
  local ok, path = pcall(function()
    return writeDiagnostic({version = 3, error = message, requestedPreset = activePreset,
      capturedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"), completed = false, speedReadings = speedReadings,
      reasoningReadings = reasoningReadings, sentKeys = sentKeys,
      failure = M.captureDiagnostic(focusedElement())})
  end)
  local saved = ok and path and "\nRapport diagnostic.json actualisé." or ""
  hs.alert.show("Codex : " .. message .. saved, 12)
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

local speedNames = {
  standard = { "Standard", "Normal" },
  fast = { "Rapide", "Fast" },
  ultrafast = { "Ultrarapide", "Ultra rapide", "Ultrafast" },
}

function M.readSpeed(control)
  local role = axAttribute(control, "AXRole")
  if role ~= "AXMenuItem" and role ~= "AXButton" and role ~= "AXPopUpButton" then return nil end
  for _, attribute in ipairs({ "AXTitle", "AXDescription" }) do
    local label = axAttribute(control, attribute)
    if type(label) == "string" then
      label = label:gsub(" ", " "):gsub("%s+", " "):match("^%s*(.-)%s*$"):lower()
      label = label:gsub("^vitesse%s+", ""):gsub("^speed%s+", "")
      for speed, aliases in pairs(speedNames) do
        for _, alias in ipairs(aliases) do
          alias = alias:lower()
          -- Menu options include descriptive subtext in their accessible name.
          local following = label:sub(#alias + 1, #alias + 1)
          if label:sub(1, #alias) == alias
              and (following == "" or following:match("[%s,:;(]")) then return speed end
        end
      end
    end
  end
  local fast = M.readFast(control)
  if fast ~= nil then return fast and "fast" or "standard" end
end

local function setSpeed(wanted, done)
  runKeySequence({ "down" }, 1, function()
    local control = focusedElement()
    if axAttribute(control, "AXEnabled") == false then fail("contrôle de vitesse indisponible"); return end
    local current = M.readSpeed(control)
    speedReadings[#speedReadings + 1] = {stage = "speed_control", reading = M.captureDiagnostic(control)}
    if not current then fail("vitesse illisible, aucun choix automatique"); return end
    if current == wanted then done(); return end
    local legacy = M.readFast(control)
    if legacy ~= nil then
      if wanted == "ultrafast" then fail("Ultrarapide indisponible sur ce compte/modèle"); return end
      runKeySequence({ { key = "return", delay = M.config.timing.speedChanged } }, 1, function()
        if M.readSpeed(focusedElement()) ~= wanted then fail("vitesse non confirmée"); return end
        done()
      end)
      return
    end
    -- The current picker exposes an explicit Standard / Fast / Ultrafast submenu.
    -- Read each focused label; never assume its order or select an unknown row.
    runKeySequence({ { key = "return", delay = M.config.timing.submenu } }, 1, function()
      local function choose(attempt, retry)
        local control = focusedElement()
        local speed = M.readSpeed(control)
        speedReadings[#speedReadings + 1] = {stage = "speed_option", attempt = attempt,
          reading = M.captureDiagnostic(control), recognizedSpeed = speed}
        if not speed then
          if retry < 2 then
            hs.timer.doAfter(0.1, function()
              runKeySequence({}, 1, function() choose(attempt, retry + 1) end)
            end)
          else fail("option de vitesse illisible, séquence arrêtée") end
          return
        end
        if speed == wanted then
          if axAttribute(control, "AXEnabled") == false then
            fail("vitesse demandée désactivée"); return
          end
          runKeySequence({ { key = "return", delay = M.config.timing.speedChanged } }, 1, function()
            if M.readSpeed(focusedElement()) ~= wanted then fail("vitesse non confirmée"); return end
            done()
          end)
        elseif attempt < 3 then
          runKeySequence({ "down" }, 1, function() choose(attempt + 1, 0) end)
        else
          fail("vitesse demandée indisponible, aucun choix automatique")
        end
      end
      choose(1, 0)
    end)
  end)
end

-- Read the control's rendered children too: the model row can contain separate
-- effort and model labels, instead of the old "Select model" accessibility name.
local function walk(element, visit, depth, seen)
  depth, seen = depth or 0, seen or {}
  if not element or seen[element] or depth > 8 then return end
  seen[element] = true
  visit(element)
  for _, child in ipairs(axAttribute(element, "AXChildren") or {}) do
    walk(child, visit, depth + 1, seen)
  end
end

local function controlTexts(control)
  local texts = {}
  walk(control, function(element)
    for _, key in ipairs({ "AXTitle", "AXDescription", "AXValue", "AXHelp" }) do
      local value = axAttribute(element, key)
      if type(value) == "string" and value ~= "" then texts[#texts + 1] = value end
    end
  end)
  return texts
end

local function modelIn(text)
  for index, model in ipairs(models) do
    for _, name in ipairs({ model, (model:gsub("^GPT%-", "")) }) do
      local start, finish = text:find(name, 1, true)
      if start and (start == 1 or text:sub(start - 1, start - 1):match("[%s,]"))
          and (finish == #text or text:sub(finish + 1, finish + 1):match("[%s,]")) then
        return model, index
      end
    end
  end
end

local function readModel(control)
  for _, text in ipairs(controlTexts(control)) do
    local model, index = modelIn(text)
    if model then return model, index end
  end
end

-- Codex puts the current value in a sibling aria-live status, not inside
-- the "Power" menu item. Read only that local status, never the window.
local function reasoningStatus(control)
  local label = axAttribute(control, "AXTitle") or axAttribute(control, "AXDescription")
  if axAttribute(control, "AXRole") ~= "AXMenuItem"
      or (label ~= "Puissance" and label ~= "Power") then return end
  local parent = axAttribute(control, "AXParent")
  local evidence = {parentRole = axAttribute(parent, "AXRole"), matches = {}}
  if evidence.parentRole ~= "AXGroup" then return nil, evidence end
  local siblings = axAttribute(parent, "AXChildren") or {}
  evidence.childCount = #siblings
  if #siblings > 8 then return nil, evidence end
  local seen, remaining = {}, 40
  local function collect(node, depth)
    if not node or node == control or seen[node] or depth > 4 or remaining == 0 then return end
    seen[node], remaining = true, remaining - 1
    local role = axAttribute(node, "AXRole")
    if role ~= "AXGroup" and role ~= "AXStaticText" then return end
    for _, key in ipairs({"AXValue", "AXTitle", "AXDescription"}) do
      local value = axAttribute(node, key)
      -- Match the source's "model effort, position of total" status exactly.
      if type(value) == "string" and (value:match(",%s*%d+%s+sur%s+%d+")
          or value:match(",%s*%d+%s+of%s+%d+")) then
        local selected = M.parseSelection(value)
        if selected then evidence.matches[#evidence.matches + 1] = selected end
      end
    end
    for _, child in ipairs(axAttribute(node, "AXChildren") or {}) do collect(child, depth + 1) end
  end
  for _, sibling in ipairs(siblings) do collect(sibling, 0) end
  evidence.capped = remaining == 0
  local selected = evidence.matches[1]
  for _, match in ipairs(evidence.matches) do
    if match.model ~= selected.model or match.effort ~= selected.effort then
      evidence.ambiguous = true
      return nil, evidence
    end
  end
  if not evidence.capped then return selected, evidence end
  return nil, evidence
end

local function readSelection(control)
  local texts = controlTexts(control)
  for _, text in ipairs(texts) do
    local selected = M.parseSelection(text)
    if selected then return selected end
  end
  local model = readModel(control)
  if model then
    for _, text in ipairs(texts) do
      local selected = M.parseSelection(model .. " " .. text)
      if selected then return selected end
    end
  end
  return reasoningStatus(control)
end

local function panelRoot(control)
  local current = control
  for _ = 1, 8 do
    if axAttribute(current, "AXRole") == "AXMenu" then return current end
    current = axAttribute(current, "AXParent")
    if not current then break end
  end
  return control -- Never search the whole window or conversation for a guessed state.
end

local function panelSpeed(control)
  local speed, ambiguous
  walk(panelRoot(control), function(element)
    local value = M.readSpeed(element)
    if value then
      if speed and speed ~= value then ambiguous = true end
      speed = value
    end
  end)
  if not ambiguous then return speed end
end

local function setEffort(preset)
  local function readEffort()
    local control = focusedElement()
    local role = axAttribute(control, "AXRole")
    local label = axAttribute(control, "AXTitle")
    local selected = readSelection(control)
    reasoningReadings[#reasoningReadings + 1] = {role = role, label = label,
      model = selected and selected.model, effort = selected and selected.effort}
    if (role ~= "AXSlider" and (role ~= "AXMenuItem" or (label ~= "Puissance" and label ~= "Power")))
        or axAttribute(control, "AXEnabled") == false then
      fail("focus sorti du contrôle de raisonnement, séquence arrêtée"); return
    end
    if not selected or selected.model ~= preset.model then
      fail("raisonnement non lisible dans le panneau, séquence arrêtée"); return
    end
    return selected.effort
  end
  local initial = readEffort()
  if initial == nil then return end
  local function advance(current, remaining)
    if current == preset.effort then
      runKeySequence({ { key = "return", delay = M.config.timing.picker } }, 1, function() busy = false end)
      return
    end
    if remaining == 0 then fail("limite de déplacement du raisonnement atteinte"); return end
    local direction = current < preset.effort and 1 or -1
    local expected = current + direction
    -- A stale live region is not permission to send another arrow.
    local function waitForChange(polls)
      local observed = readEffort()
      if observed == nil then return end
      if observed == expected then advance(observed, remaining - 1)
      elseif observed ~= current then
        fail("niveau de raisonnement inattendu, séquence arrêtée")
      elseif polls < 10 then
        hs.timer.doAfter(0.05, function()
          runKeySequence({}, 1, function() waitForChange(polls + 1) end)
        end)
      else
        fail("mise à jour du raisonnement non confirmée, aucune flèche supplémentaire")
      end
    end
    runKeySequence({ direction == 1 and "right" or "left" }, 1, function() waitForChange(0) end)
  end
  advance(initial, math.abs(preset.effort - initial))
end

-- Focus can lag behind a key event. Wait for each move before sending the
-- next one; Return must never land on the reset-to-default action.
local function focusReasoning(preset, fromSpeed)
  local function move(key, remaining)
    local previous = axAttribute(focusedElement(), "AXTitle")
    local function confirm(polls)
      local control = focusedElement()
      local label = axAttribute(control, "AXTitle")
      if label == previous then
        if polls < 10 then
          hs.timer.doAfter(0.05, function()
            runKeySequence({}, 1, function() confirm(polls + 1) end)
          end)
        else fail("déplacement du focus non confirmé, séquence arrêtée") end
        return
      end
      if axAttribute(control, "AXRole") ~= "AXMenuItem" then
        fail("focus inattendu avant le raisonnement"); return
      end
      if label == "Puissance" or label == "Power" then setEffort(preset)
      elseif fromSpeed and remaining > 0 and (label == "Rétablir la sélection par défaut"
          or label == "Réinitialiser" or label == "Reset to default") then
        move("down", remaining - 1)
      else fail("contrôle inattendu avant le raisonnement") end
    end
    runKeySequence({key}, 1, function() confirm(0) end)
  end
  move(fromSpeed and "down" or "up", fromSpeed and 1 or 0)
end

local function selectPreset(preset)
  if busy or not codexIsFrontmost() then return end
  activePreset, speedReadings, reasoningReadings, sentKeys = preset, {}, {}, {}
  local window, bundleID = M.openPicker()
  if not window then return end
  busy, activeWindow, activeBundleID = true, window, bundleID
  hs.timer.doAfter(M.config.timing.picker, function()
    runKeySequence({}, 1, function()
      local control = focusedElement()
      local role = axAttribute(control, "AXRole")
      local currentModel = readModel(control)
      local opensModelList = false
      for _, attribute in ipairs({"AXTitle", "AXDescription"}) do
        local label = axAttribute(control, attribute)
        if label == "Sélectionner le modèle" or label == "Sélectionner un modèle"
            or label == "Select model" then opensModelList = true end
      end
      -- The current AX label names the action and hides the selected model.
      -- Only open a confirmed model control, never send Return into the composer.
      if (not currentModel and not opensModelList)
          or (role ~= "AXMenuItem" and role ~= "AXButton")
          or axAttribute(control, "AXEnabled") == false then
        fail("modèle courant illisible dans le panneau (" .. tostring(role) .. ")")
        return
      end
      local function finishModel()
        if panelSpeed(focusedElement()) == preset.speed then
          focusReasoning(preset, false)
        else
          setSpeed(preset.speed, function()
            focusReasoning(preset, true)
          end)
        end
      end
      if currentModel == preset.model then finishModel(); return end
      runKeySequence({ { key = "return", delay = M.config.timing.submenu } }, 1, function()
        local selected = focusedElement()
        local _, current = readModel(selected)
        local _, target = modelIn(preset.model)
        if not current or axAttribute(selected, "AXRole") ~= "AXMenuItem" then
          fail("modèle sélectionné illisible dans la liste"); return
        end
        local steps = {}
        for _ = 1, math.abs(target - current) do
          steps[#steps + 1] = target < current and "up" or "down"
        end
        runKeySequence(steps, 1, function()
          local chosen = focusedElement()
          if readModel(chosen) ~= preset.model or axAttribute(chosen, "AXEnabled") == false then
            fail("modèle demandé non confirmé dans la liste"); return
          end
          runKeySequence({ { key = "return", delay = M.config.timing.modelSelected } }, 1, finishModel)
        end)
      end)
    end)
  end)
end

-- Explicit user-triggered, read-only evidence. Never scan the window/conversation.
function M.captureDiagnostic(control)
  local report = { probes = {}, candidates = {} }
  local candidateKeys = {}
  local function probe(name, root, deep, structureOnly)
    local rows, seen, remaining = {}, {}, 60
    local function collect(element, depth)
      if not element or seen[element] or depth > 8 or remaining == 0 then return end
      seen[element], remaining = true, remaining - 1
      local role = axAttribute(element, "AXRole")
      if role == "AXWindow" or role == "AXTextArea" or role == "AXWebArea" then return end
      local row = {depth = depth}
      local fields = structureOnly and {"AXRole", "AXFocused", "AXExpanded"}
        or {"AXRole", "AXSubrole", "AXIdentifier", "AXTitle", "AXDescription",
          "AXValue", "AXHelp", "AXEnabled", "AXSelected", "AXExpanded"}
      for _, key in ipairs(fields) do
        local value = axAttribute(element, key)
        if type(value) == "string" then
          row[key] = value:sub(1, 240)
          local model = modelIn(value)
          if model and not candidateKeys[name .. model] then
            report.candidates[#report.candidates + 1] = {method = name, model = model}
            candidateKeys[name .. model] = true
          end
        elseif type(value) == "boolean" or type(value) == "number" then row[key] = value end
      end
      rows[#rows + 1] = row
      if deep then
        for _, key in ipairs({"AXChildren", "AXVisibleChildren"}) do
          for _, child in ipairs(axAttribute(element, key) or {}) do collect(child, depth + 1) end
        end
        collect(axAttribute(element, "AXTitleUIElement"), depth + 1)
      end
    end
    collect(root, 0)
    report.probes[#report.probes + 1] = {method = name, nodes = rows, capped = remaining == 0}
  end
  local role = axAttribute(control, "AXRole")
  report.focusRole = role
  -- A group can be the picker container or the background after a toggle.
  -- Record topology without collecting arbitrary conversation text.
  if role == "AXGroup" then
    probe("focused_group_structure", control, true, true)
    report.ancestorRoles = {}
    local ancestor = axAttribute(control, "AXParent")
    for _ = 1, 8 do
      local ancestorRole = axAttribute(ancestor, "AXRole")
      if not ancestorRole then break end
      report.ancestorRoles[#report.ancestorRoles + 1] = ancestorRole
      if ancestorRole == "AXWindow" or ancestorRole == "AXWebArea" then break end
      ancestor = axAttribute(ancestor, "AXParent")
    end
    local menu = panelRoot(control)
    if axAttribute(menu, "AXRole") == "AXMenu" then
      probe("menu_children_and_title", menu, true)
    else
      report.error = "focused_group_outside_confirmed_menu"
    end
    return report
  end
  if role ~= "AXMenuItem" and role ~= "AXButton" and role ~= "AXSlider" then
    report.error = "focus_is_not_a_picker_control"
    return report
  end
  probe("focused_attributes", control, false)
  probe("focused_children_and_title", control, true)
  local _, statusEvidence = reasoningStatus(control)
  report.reasoningStatus = statusEvidence
  local menu = panelRoot(control)
  if axAttribute(menu, "AXRole") == "AXMenu" then probe("menu_children_and_title", menu, true) end
  return report
end

function M.diagnose()
  if busy or not codexIsFrontmost() then return end
  local before = M.captureDiagnostic(focusedElement())
  local window, bundleID = M.openPicker()
  if not window then return end
  busy, activeWindow, activeBundleID = true, window, bundleID
  local report = {version = 2, beforeShortcut = before, samples = {}, applied = false,
    note = "Recognized labels are candidates, not proof of selection or successful switching."}
  local function sample(number)
    runKeySequence({}, 1, function()
      report.samples[#report.samples + 1] = M.captureDiagnostic(focusedElement())
      if number < 3 then
        hs.timer.doAfter(0.5, function() sample(number + 1) end)
        return
      end
      local path = writeDiagnostic(report)
      if not path then fail("écriture du diagnostic impossible"); return end
      busy = false
      local matches = {}
      for _, candidate in ipairs(report.samples[#report.samples].candidates) do
        matches[#matches + 1] = candidate.model .. " via " .. candidate.method
      end
      hs.alert.show((#matches > 0 and "Lecture candidate : " .. table.concat(matches, "; ")
        or "Aucun nom de modèle reconnu") .. "\nAucun modèle modifié. Rapport révélé dans le Finder.", 15)
      hs.task.new("/usr/bin/open", nil, {"-R", path}):start()
    end)
  end
  hs.timer.doAfter(M.config.timing.picker, function() sample(1) end)
end

function M.start()
  if M.pickerTestHotkey then M.pickerTestHotkey:delete(); M.pickerTestHotkey = nil end
  for _, hotkey in ipairs(M.hotkeys or {}) do hotkey:delete() end
  M.hotkeys = {}
  table.insert(M.hotkeys, hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "D", function()
    afterShortcutModifiersReleased(M.diagnose)
  end))
  for _, preset in ipairs(M.config.presets) do
    local boundPreset = preset
    table.insert(M.hotkeys, hs.hotkey.bind(M.config.shortcutModifiers, boundPreset.key, function()
      if busy then return end
      afterShortcutModifiersReleased(function() selectPreset(boundPreset) end)
    end))
  end
end

return M
