-- Offline keyboard contract from the September 30 screenshots and shipped picker.
local function element(a)
  return {attributeValue=function(_, k) return a[k] end}
end
local names = {'Par défaut', 'GPT-6.1 Sol', 'GPT-6 Astra', 'GPT-6 Sol', 'GPT-6 Luna', 'GPT-5.6 Sol', 'GPT-5.6 Terra', 'GPT-5.6 Luna', 'GPT-5.5'}
local levels = {'Minimal', 'Moyen', 'Élevé', 'Très élevé', 'Maximum', 'Ultra'}
local speeds = {'standard', 'fast', 'ultrafast'}
local speedLabels = {'Standard', 'Rapide', 'Ultrarapide'}
local window = element({})
local bundle, phase, model, effort, speed, pos, index, stripped, broken
local timers, alerts, bindings, opens = {}, {}, {}, 0
local keys = {}
local noPanelSpeed = false
local focusLag = 0
local pendingFocus
local droppedFocusKeys = 0
local actionOnly = false
local missingModelList = false
local speedDescriptions = false
local unreadableSpeed = false
local speedNotReady = 0
local siblingReasoning = false
local ambiguousReasoning = false
local staleReads, lagPerArrow, previousEffort, arrowJump = 0, 0, 0, 1
local function label(s) return stripped and s:gsub('^GPT%-', '') or s end
local panel
local function panelControl(position)
  local displayedEffort = effort
  if position==3 and staleReads>0 then displayedEffort=previousEffort; staleReads=staleReads-1 end
  local base = {AXRole='AXMenuItem', AXParent=panel}
  if position == 0 then
    -- The actual selected row has children, not the old generic label.
    base.AXDescription=actionOnly and 'Sélectionner le modèle' or 'menu item'
    if not actionOnly then
      base.AXChildren={element({AXRole='AXStaticText',AXValue=levels[effort+1]}),element({AXRole='AXStaticText',AXValue=label(names[model])})}
    end
  elseif position == 1 then
    if model == 3 then
      local i = speed == 'standard' and 1 or speed == 'fast' and 2 or 3
      base.AXTitle='Vitesse '..speedLabels[i]
    else
      base.AXTitle=speed=='standard' and 'Activer le mode rapide' or 'Activer le mode standard'
      base.AXSelected=false
    end
  elseif position == 3 then
    base.AXTitle='Puissance'
    if not siblingReasoning then base.AXHelp=label(names[model])..' '..levels[displayedEffort+1]..', 1 sur 6.' end
  else base.AXTitle='Réinitialiser' end
  local item=element(base)
  if position==3 and siblingReasoning then
    local status=element({AXRole='AXGroup',AXChildren={element({AXRole='AXStaticText',
      AXValue=label(names[model])..' '..levels[displayedEffort+1]..', '..(displayedEffort+1)..' sur 6.'})}})
    local other=ambiguousReasoning and element({AXRole='AXStaticText',AXValue='GPT-6 Astra Minimal, 1 sur 6.'})
      or element({AXRole='AXStaticText',AXValue='Utilisez les flèches gauche et droite'})
    base.AXParent=element({AXRole='AXGroup',AXParent=panel,AXChildren={status,other,item}})
  end
  return item
end
panel={attributeValue=function(_, key)
  if key=='AXRole' then return 'AXMenu' end
  if key=='AXChildren' then return noPanelSpeed and {panelControl(0),panelControl(3)} or {panelControl(0),panelControl(1),panelControl(2),panelControl(3)} end
end}
local function focused()
  if broken then return element({AXRole='AXTextArea', AXValue='draft'}) end
  if phase == 'models' then return element({AXRole='AXMenuItem',AXTitle=missingModelList and '' or label(names[index])}) end
  if phase == 'speeds' then
    if unreadableSpeed or speedNotReady > 0 then
      speedNotReady=math.max(0,speedNotReady-1)
      return element({AXRole='AXMenuItem',AXTitle='menu item'})
    end
    local descriptions={'Vitesse par défaut', '1,5 × la vitesse, utilisation accrue', 'The fastest available responses'}
    return element({AXRole='AXMenuItem',AXTitle=speedLabels[index]..(speedDescriptions and (' '..descriptions[index]) or '')})
  end
  if phase == 'panel' then
    if pendingFocus then
      pendingFocus.reads=pendingFocus.reads-1
      if pendingFocus.reads<=0 then pos=pendingFocus.position;pendingFocus=nil end
    end
    return panelControl(pos)
  end
end
local root={attributeValue=function(_, k)
  if k=='AXFocusedWindow' then return window end
  if k=='AXFocusedUIElement' then return focused() end
end}
hs={
  application={frontmostApplication=function() return {bundleID=function() return bundle end} end},
  axuielement={applicationElement=function() return root end},
  alert={show=function(s) alerts[#alerts+1]=s end},
  timer={doAfter=function(_, f) timers[#timers+1]=f end},
  hotkey={bind=function(_, k, f) bindings[k]=f;return {delete=function() end} end},
  eventtap={checkKeyboardModifiers=function() return {} end,
    leftClick=function() error('Picker must never require a mouse click') end,
    keyStroke=function(mods, key)
      if #mods>0 then
        assert(mods[1]=='ctrl' and mods[2]=='shift' and key=='m')
        assert(phase=='closed'); phase='panel';pos=0;opens=opens+1;keys[#keys+1]='open';return
      end
      keys[#keys+1]=key
      if broken then error('No keys after failed opening') end
      assert(key~='home', 'Never reset the current keyboard selection')
      if phase=='models' then
        if key=='up' then index=index-1
        elseif key=='down' then index=index+1
        elseif key=='return' then
          assert(index>1);model=index;phase='panel';pos=0
          if model~=3 and speed=='ultrafast' then speed='standard' end
          if model==5 and effort==5 then effort=1 end
        else error(key) end
      elseif phase=='speeds' then
        if key=='down' then index=index+1
        elseif key=='return' then speed=speeds[index];phase='panel';pos=1
        else error(key) end
      elseif phase=='panel' then
        if key=='up' or key=='down' then
          local nextPos=(pos+(key=='up' and -1 or 1))%4
          if focusLag>0 and (pos==1 or pos==2) then
            if pendingFocus then droppedFocusKeys=droppedFocusKeys+1
            else pendingFocus={position=nextPos,reads=focusLag} end
          else pos=nextPos end
        elseif key=='return' and pos==0 then phase='models';index=model
        elseif key=='return' and pos==1 then
          if model==3 then phase='speeds';index=1
          else speed=speed=='standard' and 'fast' or 'standard' end
        elseif key=='return' and pos==3 then phase='closed'
        elseif (key=='left' or key=='right') and pos==3 then
          previousEffort=effort;staleReads=lagPerArrow
          effort=math.max(0, math.min(model==5 and 4 or 5,effort+(key=='left' and -arrowJump or arrowJump)))
        else error('Unexpected panel action '..key..' at '..pos) end
      else error('No keyboard actions after completion') end
    end},
}
local source = debug.getinfo(1, 'S').source:sub(2)
local directory = source:match('^(.*[/\\])') or './'
local m=dofile(os.getenv('CODEX_SHORTCUTS_FILE') or (directory..'codex-model-shortcuts.lua'))
m.start()
local function drain()
 local n=0
 while #timers>0 do table.remove(timers,1)();n=n+1;assert(n<120) end
end
local cases=0
for _,only in ipairs({false,true}) do
 actionOnly=only
for _,short in ipairs({false,true}) do
 for startModel=2,#names do
  for startEffort=0,(startModel==5 and 4 or 5) do
   for startSpeed=1,(startModel==3 and 3 or 2) do
    for _,p in ipairs(m.config.presets) do
      stripped=short;model=startModel;effort=startEffort;speed=speeds[startSpeed]
      phase='closed';bundle='com.openai.codex';timers={};alerts={};keys={}
      bindings[p.key]();drain()
      assert(names[model]==p.model and effort==p.effort and speed==p.speed)
      assert(phase=='closed' and #alerts==0)
      cases=cases+1
    end
   end
  end
 end
end
end
actionOnly=false
assert(opens==cases)
for _, alias in ipairs({'Minimal', 'Léger', 'Faible', 'Low'}) do
  assert(m.parseSelection('GPT-6 Astra '..alias).effort==0)
end
assert(m.parseSelection('6.1 Sol Élevé, 3 sur 6.').effort==2)
-- Failed open must not send Return into the composer.
broken=true;phase='closed';bindings.K();drain();assert(#alerts==1)
broken=false;phase='closed';bindings.K();bundle='other';drain();assert(phase=='panel' and pos==0)
-- A subsequent attempt works, and a concurrent shortcut is ignored.
bundle='com.openai.codex';phase='closed';alerts={}
local before=opens;bindings.L();bindings.M();drain();assert(opens==before+1 and #alerts==0)
-- Exact minimal same-model sequence: same Astra, same Standard speed.
model=3;effort=3;speed='standard';phase='closed';keys={};alerts={}
bindings.L();drain()
assert(table.concat(keys, ',')=='open,up,left,left,left,return')
-- Astra speed always opens at Standard, even when currently Ultrafast.
model=3;effort=0;speed='ultrafast';phase='closed';keys={}
bindings.L();drain()
assert(table.concat(keys, ',')=='open,down,return,return,down,down,return')
-- Selecting Ultrafast takes two Down presses, not a delta from current speed.
model=3;effort=0;speed='fast';phase='closed';keys={}
bindings.H();drain()
assert(table.concat(keys, ',')=='open,down,return,down,down,return,down,down,return')
-- A two-speed model toggles once and never enters a speed submenu.
model=2;effort=2;speed='fast';phase='closed';keys={}
bindings.K();drain()
assert(table.concat(keys, ',')=='open,down,return,down,down,return')
-- No visible panel speed means inspecting the speed row, not assuming Standard.
model=3;effort=0;speed='standard';phase='closed';keys={};noPanelSpeed=true
bindings.L();drain();noPanelSpeed=false
assert(table.concat(keys, ',')=='open,down,down,down,return')
print(cases..' keyboard transitions passed: Minimal, compact labels, Astra dropdown, other-model toggle, failed open, focus cancellation, no clicks')
-- Diagnostic probes cover alternate AX sources, but never read a composer/window.
local title = element({AXRole='AXStaticText',AXValue='GPT-6 Astra'})
local visible = element({AXRole='AXStaticText',AXValue='Minimal'})
local attributes={AXRole='AXMenuItem', AXDescription='menu item', AXVisibleChildren={visible}, AXTitleUIElement=title}
local item=element(attributes)
local menuAttributes={AXRole='AXMenu',AXChildren={item,element({AXRole='AXTextArea',AXValue='DO NOT CAPTURE'})}}
local diagnosticMenu=element(menuAttributes)
attributes.AXParent=diagnosticMenu
attributes.AXChildren={item} -- cycle: traversal must terminate.
local report=m.captureDiagnostic(item)
assert(#report.probes==3 and #report.candidates==2)
assert(report.candidates[1].method=='focused_children_and_title' and report.candidates[1].model=='GPT-6 Astra')
for _,probe in ipairs(report.probes) do
  for _,node in ipairs(probe.nodes) do assert(node.AXValue~='DO NOT CAPTURE') end
end
report=m.captureDiagnostic(element({AXRole='AXTextArea',AXValue='DO NOT CAPTURE'}))
assert(report.error=='focus_is_not_a_picker_control' and #report.probes==0)
print('Diagnostic checks passed: alternate sources, cycle bound, no composer/window capture, candidates are not applied selections')

-- The actual submitted report had AXGroup in all samples: do not discard it.
local group = element({AXRole='AXGroup', AXValue='PRIVATE BACKGROUND',
  AXParent=diagnosticMenu, AXChildren={item}})
report=m.captureDiagnostic(group)
assert(report.focusRole=='AXGroup' and not report.error and #report.probes==2)
assert(report.candidates[1].model=='GPT-6 Astra')
for _,node in ipairs(report.probes[1].nodes) do
  assert(node.AXTitle==nil and node.AXValue==nil and node.AXDescription==nil)
end
report=m.captureDiagnostic(element({AXRole='AXGroup',AXChildren={title},
  AXParent=element({AXRole='AXWindow'})}))
assert(report.error=='focused_group_outside_confirmed_menu')
assert(#report.probes==1 and #report.candidates==0 and report.ancestorRoles[1]=='AXWindow')
print('Observed AXGroup regression passed: topology retained, text restricted to confirmed menus')

local savedReport
hs.fs={mkdir=function() return true end}
hs.json={write=function(value) savedReport=value; return true end}
hs.task={new=function(program, _, args)
  assert(program=='/usr/bin/open' and args[1]=='-R')
  return {start=function() end}
end}
model=3;effort=0;speed='standard';phase='closed';keys={};alerts={}
bindings.D();drain()
assert(savedReport.version==2 and savedReport.beforeShortcut and #savedReport.samples==3)
assert(savedReport.applied==false and table.concat(keys, ',')=='open')
assert(model==3 and effort==0 and speed=='standard')
print('Diagnostic orchestration passed: baseline plus three samples, no selection keys')

-- Regression from the user-supplied diagnostic: action label, no model children.
actionOnly=true;model=3;effort=3;speed='standard';phase='closed';keys={};alerts={}
bindings.L();drain()
assert(table.concat(keys, ',')=='open,return,return,up,left,left,left,return')
assert(#alerts==0 and model==3 and effort==0)
-- The selected row is the starting point, even below the target in the list.
model=5;effort=2;speed='standard';phase='closed';keys={};alerts={}
bindings.K();drain()
assert(table.concat(keys, ',')=='open,return,up,up,up,return,up,return')
assert(#alerts==0 and model==2)
-- If opening the list yields no readable model, do not navigate or select blindly.
missingModelList=true;phase='closed';keys={};alerts={}
bindings.K();drain()
assert(table.concat(keys, ',')=='open,return' and #alerts==1)
print('Action-only model label passed: relative selection, same model, unreadable-list stop')

-- Installed Codex source uses these accessible slider labels for medium/high.
assert(m.parseSelection('GPT-6 Astra Standard, 2 sur 6.').effort==1)
assert(m.parseSelection('GPT-6.1 Sol Étendu, 3 sur 6.').effort==2)
assert(m.parseSelection('GPT-6.1 Sol Extended, 3 of 6.').effort==2)

-- Plausible native accessible names: title plus the rendered subtitle.
-- These are source-derived cases, not a claim that the native UI was exercised.
missingModelList=false;actionOnly=true;speedDescriptions=true
model=3;effort=2;speed='ultrafast';phase='closed';keys={};alerts={}
bindings.M();drain()
assert(model==3 and effort==3 and speed=='standard' and #alerts==0)
assert(table.concat(keys, ',')=='open,return,return,down,return,return,down,down,right,return')
assert(m.readSpeed(element({AXRole='AXMenuItem',AXTitle='Fastest available'}))==nil)
assert(m.readSpeed(element({AXRole='AXMenuItem',AXTitle='  Standard\nVitesse par défaut'}))=='standard')
assert(m.readSpeed(element({AXRole='AXMenuItem',AXTitle='Ultrarapide, The fastest available responses'}))=='ultrafast')
-- Opening delay: retry reading, never advance from an unreadable option.
model=3;effort=2;speed='ultrafast';phase='closed';keys={};alerts={};speedNotReady=2
bindings.M();drain()
assert(speed=='standard' and effort==3 and #alerts==0)
-- Persistent read failure captures actual evidence and leaves speed unchanged.
model=3;effort=2;speed='ultrafast';phase='closed';keys={};alerts={};unreadableSpeed=true
bindings.M();drain()
assert(speed=='ultrafast' and effort==2 and #alerts==1)
assert(table.concat(keys, ',')=='open,return,return,down,return')
assert(savedReport.version==3 and savedReport.requestedPreset.key=='M')
assert(savedReport.error=='option de vitesse illisible, séquence arrêtée')
assert(#savedReport.speedReadings==4 and savedReport.completed==false)
print('Speed regression passed: title/subtitle, exact M scenario, delayed read, failure evidence without blind arrows')

-- Real failure shape: Puissance has no value/help; the shipped source puts
-- the current model/effort in a sibling live status. Exercise that layout.
unreadableSpeed=false;siblingReasoning=true;speedDescriptions=true;actionOnly=true
model=3;effort=2;speed='ultrafast';phase='closed';keys={};alerts={}
bindings.M();drain()
assert(model==3 and effort==3 and speed=='standard' and #alerts==0)
assert(table.concat(keys, ',')=='open,return,return,down,return,return,down,down,right,return')
model=3;effort=3;speed='standard';phase='closed';keys={};alerts={}
bindings.L();drain()
assert(effort==0 and #alerts==0)
-- Contradictory status values are not permission to guess or send arrows.
ambiguousReasoning=true;model=3;effort=2;phase='closed';keys={};alerts={}
bindings.M();drain()
assert(effort==2 and #alerts==1)
assert(savedReport.failure.reasoningStatus.ambiguous==true)
assert(not table.concat(keys, ','):find('right',1,true))
-- A surrounding window or a form field must never provide the selection.
local power=element({AXRole='AXMenuItem',AXTitle='Puissance',AXParent=element({AXRole='AXWindow'})})
assert(m.captureDiagnostic(power).reasoningStatus.parentRole=='AXWindow')
print('Reasoning sibling status passed: exact M scenario, relative L movement, ambiguous-state stop, window exclusion')

-- Asynchronous AX status must not turn one intended arrow into several.
ambiguousReasoning=false;siblingReasoning=true;actionOnly=true;lagPerArrow=4
model=3;effort=2;speed='standard';phase='closed';keys={};alerts={};staleReads=0
bindings.M();drain()
assert(effort==3 and phase=='closed' and #alerts==0)
local function count(key) local n=0;for _,k in ipairs(keys) do if k==key then n=n+1 end end;return n end
assert(count('right')==1)
-- Multiple steps still work, with a stale status after every individual step.
model=3;effort=3;phase='closed';keys={};alerts={};staleReads=0
bindings.L();drain()
assert(effort==0 and phase=='closed' and #alerts==0 and count('left')==3)
-- A status that never catches up results in exactly one arrow, not an Ultra overshoot.
lagPerArrow=1000;model=3;effort=2;phase='closed';keys={};alerts={};staleReads=0
bindings.M();drain()
assert(effort==3 and phase=='panel' and #alerts==1 and count('right')==1)
assert(savedReport.error=='mise à jour du raisonnement non confirmée, aucune flèche supplémentaire')
assert(#savedReport.reasoningReadings==12)
assert(savedReport.sentKeys[#savedReport.sentKeys]=='right')
-- An unexpected jump is not corrected with additional arrows or Return.
lagPerArrow=0;arrowJump=2;model=3;effort=2;phase='closed';keys={};alerts={};staleReads=0
bindings.M();drain()
assert(effort==4 and phase=='panel' and #alerts==1 and count('right')==1)
assert(savedReport.error=='niveau de raisonnement inattendu, séquence arrêtée')
print('Stale reasoning status regression passed: one arrow per confirmation, fixed movement budget, no overshoot retries')

-- Native rapid-use failure: one of the two Down events was lost, ending on Reset.
-- Simulate delayed focus that drops additional keys until the first move settles.
arrowJump=1;lagPerArrow=0;focusLag=4;staleReads=0;pendingFocus=nil;droppedFocusKeys=0
noPanelSpeed=true;model=3;effort=2;speed='standard';phase='closed';keys={};alerts={}
bindings.K();drain()
assert(model==2 and effort==2 and phase=='closed' and #alerts==0)
assert(droppedFocusKeys==0)
assert(table.concat(keys, ',')=='open,return,up,return,down,down,down,return')
-- No progress: stay on Speed, stop, and never send Return to Reset.
focusLag=1000;pendingFocus=nil;phase='closed';keys={};alerts={}
bindings.K();drain()
assert(phase=='panel' and pos==1 and #alerts==1)
assert(savedReport.error=='déplacement du focus non confirmé, séquence arrêtée')
assert(savedReport.sentKeys[#savedReport.sentKeys]=='down')
-- Keep the shortcut lock while Enter is closing the picker.
focusLag=0;pendingFocus=nil;phase='closed';keys={};alerts={};noPanelSpeed=false
local priorOpens=opens
bindings.K()
while phase~='closed' do table.remove(timers,1)() end
bindings.M();drain()
assert(opens==priorOpens+1 and model==2 and #alerts==0)
print('Rapid navigation regression passed: no lost Down keys, Reset never activated, close-animation lock')
