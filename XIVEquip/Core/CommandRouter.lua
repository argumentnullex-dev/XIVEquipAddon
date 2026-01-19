-- Core/Command.lua
local addon, XIVEquip = ...
XIVEquip              = XIVEquip or {}
XIVEquip.Commands     = XIVEquip.Commands or {}

local C               = XIVEquip.Commands
local L               = XIVEquip.L or {}
local PREFIX          = L.AddonPrefix or "XIVEquip: "
-- Settings: Core addon plumbing: settings.
local function Settings() return XIVEquip.Settings end

-- utils
-- [XIVEquip-AUTO] trim: Helper for Core module.
local function trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end
-- split1: Core addon plumbing: split 1.
local function split1(s)
  local a, b = tostring(s or ""):match("^(%S+)%s*(.*)$")
  return a and string.lower(a) or "", (b or ""):match("^%s*(.-)%s*$")
end
-- onoff_to_bool: Core addon plumbing: onoff to bool.
local function onoff_to_bool(tok)
  tok = string.lower(tostring(tok or ""))
  if tok == "on" or tok == "1" or tok == "true" then return true end
  if tok == "off" or tok == "0" or tok == "false" then return false end
  return nil
end

-- help registry
local helplines = {}
-- C.Help: Core addon plumbing: help.
function C.Help(line) helplines[#helplines + 1] = line end

C.Help(" /xive score <link> [scale] – score with active comparer; if [scale] is given, try Pawn scale")

-- print_help: Core addon plumbing: print help.
local function print_help()
  print(PREFIX .. "Commands:")
  print("  /xive                            – show this help")
  print("  /xivequip                        – equip recommended gear")
  print("  /xive use <comparer>             – set comparer by label (Pawn, ilvl)")
  print("  /xive debug on|off|toggle        – toggle debug logging")
  print("  /xive debug slot <id|clear>      – filter debug to one slot (clear = all)")
  print("  /xive startup msg on|off         – toggle login/startup message")
  print("  /xive gear msg on|off            – toggle equip/change messages")
  print("  /xive gear preview on|off        – toggle hover preview on ERG button")
  print("  /xive auto spec on|off           – auto-equip on spec change")
  print("  /xive auto sets on|off           – auto-save set on equip")
  print("  /xive score <link> [scale]       – score; [scale] uses Pawn if available")
  for _, line in ipairs(helplines) do print("  " .. line) end
end

-- command framework (hardened)
local namespaces = {} -- first token -> function(rest)
-- [XIVEquip-AUTO] ROUTES table holds command -> handler mappings; leaf handlers are functions(rest).
local ROUTES     = {} -- nested tables -> function(rest)

-- command framework (hardened)
-- [XIVEquip-AUTO] ROUTES table holds command -> handler mappings; leaf handlers are functions(rest).
local namespaces = {} -- first token -> function(rest)
local ROUTES     = {} -- nested tables -> function(rest)

-- C.RegisterNamespace: Core addon plumbing: register namespace.
function C.RegisterNamespace(ns, fn)
  namespaces[string.lower(tostring(ns or ""))] = fn
end

-- toPath: Core addon plumbing: to path.
local function toPath(cmd)
  if type(cmd) == "string" then return { cmd } end
  if type(cmd) == "table" then return cmd end
  error("RegisterRoot expects string or table path")
end

-- NEW: promote leaf functions to table nodes when needed
local function ensureTableSlot(t, key)
  local v = t[key]
  if type(v) == "function" then
    -- keep the existing handler as the default for this node
    v = { [""] = v }
    t[key] = v
  elseif type(v) ~= "table" then
    v = {}
    t[key] = v
  end
  return v
end

-- NEW: robust register that supports both leaf + subcommands
local function register(path, fn)
  local p = toPath(path)
  local node = ROUTES
  for i = 1, (#p - 1) do
    local key = string.lower(tostring(p[i] or ""))
    if key ~= "" then
      node = ensureTableSlot(node, key)
    end
  end
  local leaf = string.lower(tostring(p[#p] or ""))
  if leaf == "" then return end
  local existing = node[leaf]
  if type(existing) == "table" then
    -- already has subcommands; store this as the default handler
    existing[""] = fn
  else
    node[leaf] = fn
  end
end

-- C.RegisterRoot: Core addon plumbing: register root.
function C.RegisterRoot(cmdOrPath, fn) register(cmdOrPath, fn) end

-- NEW: dispatcher that honors default handlers on table nodes ([""])
local function dispatch(msg)
  local tokens = {}
  for w in string.gmatch(tostring(msg or ""), "%S+") do tokens[#tokens + 1] = w end
  if #tokens == 0 then
    print_help(); return
  end

  -- 1) namespace
  local head = string.lower(tokens[1])
  if namespaces[head] then
    local rest = table.concat(tokens, " ", 2)
    return namespaces[head](rest)
  end

  -- 2) deepest route with default-handlers ("")
  local node, fn, ix = ROUTES, nil, 0
  local candidateFn, candidateIx = nil, 0
  for i = 1, #tokens do
    local k = string.lower(tokens[i])
    local nxt = node[k]
    if type(nxt) == "function" then
      fn, ix = nxt, i; break
    elseif type(nxt) == "table" then
      node = nxt
      if type(node[""]) == "function" then
        candidateFn, candidateIx = node[""], i
      end
    else
      break
    end
  end
  if not fn and candidateFn then
    fn, ix = candidateFn, candidateIx
  end
  if not fn then
    -- also allow a single-token default at top level
    local one = ROUTES[head]
    if type(one) == "function" then fn, ix = one, 1 end
  end
  if not fn then
    print(PREFIX .. "Unknown command. Try /xive"); return
  end

  local rest = table.concat(tokens, " ", ix + 1)
  return fn(rest)
end

-- slash bindings
SLASH_XIVE1 = "/xive"
-- SlashCmdList["XIVE"]: Core addon plumbing: slash cmd list xive.
SlashCmdList["XIVE"] = function(msg) dispatch(trim(msg)) end

-- handlers

-- /xive use <comparer>
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot("use", function(rest)
  local want = trim(rest)
  if want == "" then
    print(PREFIX .. "Usage: /xive use <comparer label> (e.g., Pawn, ilvl)"); return
  end
  local M = XIVEquip.Comparers
  if not (M and M.All) then
    print(PREFIX .. "Comparers core not loaded."); return
  end
  local target
  for _, def in pairs(M:All()) do
    if string.lower(def.Label or "") == string.lower(want) then
      target = def; break
    end
  end
  if not target then
    print(PREFIX .. "No comparer labeled '" .. want .. "'."); return
  end
  local S = Settings(); if S and S.SetComparerName then S:SetComparerName(target.Label) end
  print(PREFIX .. "Comparer set to: " .. target.Label)
end)

-- /xive debug on|off|toggle
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot("debug", function(rest)
  local S = Settings()
  if not (S and S.SetDebugEnabled and S.GetDebugEnabled) then
    print(PREFIX .. "Settings not available."); return
  end
  local sub = string.lower((rest or ""):match("^(%S*)") or "")
  if sub == "on" then
    S:SetDebugEnabled(true)
  elseif sub == "off" then
    S:SetDebugEnabled(false)
  else
    S:SetDebugEnabled(not S:GetDebugEnabled())
  end
  print(PREFIX .. "Debug: " .. (S:GetDebugEnabled() and "ON" or "OFF"))
end)

-- /xive debug slot <number|clear>
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot({ "debug", "slot" }, function(rest)
  local S = Settings(); if not (S and S.SetDebugSlot) then
    print(PREFIX .. "Settings not available."); return
  end
  local r = trim(rest)
  if r == "" or r == "clear" or r == "off" then
    S:SetDebugSlot(nil); print(PREFIX .. "Debug slot filter cleared."); return
  end
  local n = tonumber(r); if n then
    S:SetDebugSlot(n); print(PREFIX .. ("Debug slot set to %d."):format(n))
  else
    print(PREFIX .. "Usage: /xive debug slot <number|clear>")
  end
end)

-- /xive startup msg on|off
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot("startup", function(rest)
  local S = Settings(); if not (S and S.SetMessage) then
    print(PREFIX .. "Settings not available."); return
  end
  local tok, rest2 = split1(rest); if tok ~= "msg" then
    print(PREFIX .. "Usage: /xive startup msg on|off"); return
  end
  local onoff = onoff_to_bool(select(1, split1(rest2))); if onoff == nil then
    print(PREFIX .. "Usage: /xive startup msg on|off"); return
  end
  S:SetMessage("Login", onoff); print(PREFIX .. "Startup message: " .. (onoff and "ON" or "OFF"))
end)

-- /xive gear msg on|off   and   /xive gear preview on|off
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot("gear", function(rest)
  local S = Settings(); if not (S and S.SetMessage) then
    print(PREFIX .. "Settings not available."); return
  end
  local sub, rest2 = split1(rest); local onoff = onoff_to_bool(select(1, split1(rest2)))
  if sub == "msg" then
    if onoff == nil then
      print(PREFIX .. "Usage: /xive gear msg on|off"); return
    end
    S:SetMessage("Equip", onoff); print(PREFIX .. "Equip/change messages: " .. (onoff and "ON" or "OFF"))
  elseif sub == "preview" then
    if onoff == nil then
      print(PREFIX .. "Usage: /xive gear preview on|off"); return
    end
    S:SetMessage("Preview", onoff); print(PREFIX .. "Hover preview: " .. (onoff and "ON" or "OFF"))
  else
    print(PREFIX .. "Usage: /xive gear msg on|off  |  /xive gear preview on|off")
  end
end)

-- /xive auto spec|sets on|off
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot("auto", function(rest)
  local S = Settings(); if not (S and S.SetAutomation) then
    print(PREFIX .. "Settings not available."); return
  end
  local what, rest2 = split1(rest); local onoff = onoff_to_bool(select(1, split1(rest2)))
  if (what ~= "spec" and what ~= "sets") or onoff == nil then
    print(PREFIX .. "Usage: /xive auto spec on|off  |  /xive auto sets on|off"); return
  end
  S:SetAutomation(what == "spec" and "AutoSpec" or "AutoSets", onoff)
  print(PREFIX .. "Auto " .. what .. ": " .. (onoff and "ON" or "OFF"))
end)

-- /xive score <link> [scale]
-- [XIVEquip-AUTO] Callback: Callback used by CommandRouter.lua to respond to a timer/event/script hook.
C.RegisterRoot("score", function(rest)
  local s = tostring(rest or "")
  local link, tail = nil, ""
  -- Try to locate a full item link (optionally prefixed with a color code) like:
  -- |cff....|Hitem:...|h[Name]|h|r  or  |Hitem:...|h[Name]|h
  local hpos = s:find("|Hitem:")
  if hpos then
    -- If there's a color code immediately before the |Hitem:, include it
    local pre = s:sub(1, hpos - 1)
    local cstart = pre:match("()|c%x%x%x%x%x%x%x%x")
    local startpos = cstart or hpos
    -- Prefer the full terminator |h|r
    local endpos = s:find("|h|r", hpos, true)
    if endpos then
      link = s:sub(startpos, endpos + 3) -- include |h|r
      tail = s:sub(endpos + 4)
    else
      -- Fallback: find the next |h
      local endpos2 = s:find("|h", hpos, true)
      if endpos2 then
        link = s:sub(startpos, endpos2 + 1)
        tail = s:sub(endpos2 + 2)
      end
    end
  else
    -- No explicit item link markers found; treat first token as the link
    local a, b = s:match("^(%S+)%s*(.*)$")
    link, tail = a, b or ""
  end
  link = link and trim(link) or nil
  tail = trim(tail or "")
  if not link or link == "" then
    print(PREFIX .. "Usage: /xive score <itemLink> [scaleName]"); return
  end
  local scaleQuery = tail

  -- If a scale is given and Pawn is available, try it first
  if scaleQuery ~= "" and XIVEquip.Pawn and type(XIVEquip.Pawn.ScoreItemLinkWithScale) == "function" then
    local v, _, entry = XIVEquip.Pawn.ScoreItemLinkWithScale(link, scaleQuery)
    if v then
      print(("%sScore: %.2f  (Pawn: %s)"):format(PREFIX, v, (entry and (entry.name or entry.key)) or scaleQuery)); return
    else
      print(PREFIX .. "Pawn scale not found: " .. scaleQuery .. " — falling back to active comparer.")
    end
  end

  -- Otherwise: Pawn auto / active comparer / ilvl fallback
  if XIVEquip.Pawn and type(XIVEquip.Pawn.ScoreItemLink) == "function" then
    local v, src = XIVEquip.Pawn.ScoreItemLink(link); if v then
      print(PREFIX .. ("Score: %.2f (%s)"):format(v, src or "Pawn")); return
    end
  elseif type(XIVEquip.PawnScoreLinkAuto) == "function" then
    local v, src = XIVEquip.PawnScoreLinkAuto(link); if v then
      print(PREFIX .. ("Score: %.2f (%s)"):format(v, src or "Pawn")); return
    end
  end

  if GetDetailedItemLevelInfo then
    local ok, ilvl = pcall(GetDetailedItemLevelInfo, link)
    print(PREFIX .. ("Score (ilvl): %s"):format(ok and ilvl or "?"))
  else
    print(PREFIX .. "No scorer available.")
  end
end)

-- /xivequip
SLASH_XIVEQUIP1 = "/xivequip"
-- SlashCmdList["XIVEQUIP"]: Core addon plumbing: slash cmd list xivequip.
SlashCmdList["XIVEQUIP"] = function()
  if XIVEquip and XIVEquip.Gear and XIVEquip.Gear.EquipBest then
    XIVEquip.Gear:EquipBest()
  else
    print(PREFIX .. "Equip routine not available.")
  end
end
