-- Comparers/Pawn/Commands.lua
local addon, XIVEquip = ...
XIVEquip = XIVEquip or {}
local Cmd = XIVEquip.Commands

local function pawn_help()
  print("  /xive pawn                – list Pawn subcommands")
  print("  /xive pawn scales [all]   – list active (or all) scales")
  print("  /xive pawn weights [name] – show weights (active or by name)")
  print("  /xive pawn score <link> [scale <name>] – score with Pawn (optionally with a specific scale)")
end

Cmd.RegisterNamespace("pawn", function(rest)
  local sub, tail = rest:match("^(%S+)%s*(.*)$")
  sub = (sub or ""):lower()

  if sub == "" or sub == "help" then
    pawn_help(); return

    -- Pawn: List Scale Names and Details
  elseif sub == "scales" then
    local all = (tail and tail:lower():find("all")) ~= nil
    local list = all and (XIVEquip.PawnGetAllScales and XIVEquip.PawnGetAllScales() or {})
        or (XIVEquip.PawnGetActiveScales and XIVEquip.PawnGetActiveScales() or {})
    if #list == 0 then
      print("  (none)")
      return
    end
    for _, r in ipairs(list) do -- Core/Commands.lua
      XIVEquip          = XIVEquip or {}
      XIVEquip.Commands = XIVEquip.Commands or {}

      local Settings    = XIVEquip.Settings     -- must load Core/Settings.lua BEFORE this file
      local C           = XIVEquip.Commands
      local L           = XIVEquip.L or {}
      local PREFIX      = L.AddonPrefix or "XIVEquip: "

      -- utils
      local function trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end
      local function split1(s)
        local a, b = s:match("^(%S+)%s*(.*)$"); return a and a:lower() or "", (b or ""):match("^%s*(.-)%s*$")
      end
      local function onoff_to_bool(tok)
        if tok == "on" or tok == "1" or tok == "true" then
          return true
        elseif tok == "off" or tok == "0" or tok == "false" then
          return false
        end
        return nil
      end

      -- registries
      local namespaces, root, helplines = {}, {}, {}
      function C.RegisterNamespace(ns, fn) namespaces[ns:lower()] = fn end

      function C.RegisterRoot(cmd, fn) root[cmd:lower()] = fn end

      function C.Help(line) helplines[#helplines + 1] = line end

      -- Core contributes one generic comparer tip; modules add their own
      C.Help(" /xive <comparer> score <link> – quick score with a specific comparer (e.g., pawn, ilvl)")

      -- help
      local function print_help()
        print(PREFIX .. "Commands:")
        print("  /xive                         – show this help")
        print("  /xivequip                     – equip recommended gear")
        print("  /xive use <comparer>          – set comparer by label (Pawn, ilvl)")
        print("  /xive debug on|off            – toggle debug logging")
        print("  /xive debug slot <id|name|off>– filter debug to one slot (off = all)")
        print("  /xive startup msg on|off      – toggle login/startup message")
        print("  /xive gear msg on|off         – toggle equip/change messages")
        print("  /xive gear preview on|off     – toggle hover preview on ERG button")
        print("  /xive auto spec on|off        – auto-equip on spec change")
        print("  /xive auto sets on|off        – auto-save set on equip")
        print("  /xive score <link>            – score with ACTIVE comparer")
        print("  /xive <comparer> score <link> – score with specific comparer")
        for _, line in ipairs(helplines) do print("  " .. line) end
      end

      -- /xive use <comparer>
      C.RegisterRoot("use", function(rest)
        local want = trim(rest or "")
        if want == "" then
          print(PREFIX .. "Usage: /xive use <comparer label> (e.g., Pawn, ilvl)"); return
        end
        local M = XIVEquip.Comparers
        if not M then
          print(PREFIX .. "Comparers core not loaded."); return
        end
        local target
        for _, def in pairs(M:All()) do
          if (def.Label or ""):lower() == want:lower() then
            target = def; break
          end
        end
        if not target then
          print(PREFIX .. "No comparer labeled '" .. want .. "'."); return
        end
        Settings:SetComparerLabel(target.Label)
        print(PREFIX .. "Comparer set to: " .. target.Label)
      end)

      -- /xive debug on|off   and   /xive debug slot <x>
      C.RegisterRoot("debug", function(rest)
        local sub, tail = split1(rest)
        if sub == "slot" then
          local arg = trim(tail)
          if arg == "" then
            print(PREFIX .. "Usage: /xive debug slot <id|name|off>"); return
          end
          if arg:lower() == "off" then
            Settings:SetDebugSlot(nil)
            print(PREFIX .. "Debug slot filter: OFF (all slots)")
            return
          end
          -- store as-is; your logging code can accept string names or numeric ids
          local num = tonumber(arg)
          Settings:SetDebugSlot(num or arg)
          print(PREFIX .. "Debug slot filter:", num or arg)
          return
        end
        local val = onoff_to_bool(sub)
        if val == nil then
          print(PREFIX .. "Usage: /xive debug on|off  |  /xive debug slot <id|name|off>"); return
        end
        Settings:SetDebugEnabled(val)
        print(PREFIX .. "Debug logging: " .. (val and "ON" or "OFF"))
      end)

      -- /xive startup msg on|off
      C.RegisterRoot("startup", function(rest)
        local tok, rest2 = split1(rest)
        if tok ~= "msg" then
          print(PREFIX .. "Usage: /xive startup msg on|off"); return
        end
        local onoff = onoff_to_bool(split1(rest2))
        if onoff == nil then
          print(PREFIX .. "Usage: /xive startup msg on|off"); return
        end
        Settings:SetMessage("Login", onoff)
        print(PREFIX .. "Startup message: " .. (onoff and "ON" or "OFF"))
      end)

      -- /xive gear msg on|off   and   /xive gear preview on|off
      C.RegisterRoot("gear", function(rest)
        local sub, rest2 = split1(rest)
        local onoff = onoff_to_bool(split1(rest2))
        if sub == "msg" then
          if onoff == nil then
            print(PREFIX .. "Usage: /xive gear msg on|off"); return
          end
          Settings:SetMessage("Equip", onoff)
          print(PREFIX .. "Equip/change messages: " .. (onoff and "ON" or "OFF"))
        elseif sub == "preview" then
          if onoff == nil then
            print(PREFIX .. "Usage: /xive gear preview on|off"); return
          end
          Settings:SetMessage("Preview", onoff)
          print(PREFIX .. "Hover preview: " .. (onoff and "ON" or "OFF"))
        else
          print(PREFIX .. "Usage: /xive gear msg on|off  |  /xive gear preview on|off")
        end
      end)

      -- /xive auto spec|sets on|off
      C.RegisterRoot("auto", function(rest)
        local what, rest2 = split1(rest)
        local onoff = onoff_to_bool(split1(rest2))
        if (what ~= "spec" and what ~= "sets") or onoff == nil then
          print(PREFIX .. "Usage: /xive auto spec on|off  |  /xive auto sets on|off"); return
        end
        Settings:SetAutomation(what == "spec" and "AutoSpec" or "AutoSets", onoff)
        print(PREFIX .. "Auto " .. what .. ": " .. (onoff and "ON" or "OFF"))
      end)

      -- /xive score <link>
      C.RegisterRoot("score", function(rest)
        local link = rest and (rest:match("(|c%x+|Hitem:[^|]+|h[^|]*|h|r)") or rest:match("(|Hitem:[^|]+|h[^|]*|h)"))
        if not link then
          print(PREFIX .. "Usage: /xive score <itemLink>"); return
        end
        if XIVEquip.PawnScoreLinkAuto then
          local v, src = XIVEquip.PawnScoreLinkAuto(link)
          if v then
            print(PREFIX .. (" Score: %.2f (%s)"):format(v, src or "?")); return
          end
        end
        if GetDetailedItemLevelInfo then
          local ok, ilvl = pcall(GetDetailedItemLevelInfo, link)
          print(PREFIX .. (" Score (ilvl): %s"):format(ok and ilvl or "?"))
        else
          print(PREFIX .. "No scorer available.")
        end
      end)

      -- namespace dispatch + SLASH handlers (unchanged)
      SLASH_XIVE1 = "/xive"
      SlashCmdList["XIVE"] = function(msg)
        msg = trim(msg or "")
        if msg == "" then return print_help() end
        local head, rest = split1(msg)
        if namespaces[head] then
          namespaces[head](rest); return
        end
        local fn = root[head]; if fn then
          fn(rest); return
        end
        print(PREFIX .. "Unknown command. Try /xive")
      end

      SLASH_XIVEQUIP1 = "/xivequip"
      SlashCmdList["XIVEQUIP"] = function()
        if XIVEquip and XIVEquip.Gear and XIVEquip.Gear.EquipRecommended then
          XIVEquip.Gear:EquipRecommended()
        else
          print(PREFIX .. "Equip routine not available.")
        end
      end

      print(string.format("  %-35s  %-8s  key=%s  %s",
        tostring(r.name), r.type or "?", tostring(r.key or "?"), r.active and "[ACTIVE]" or ""))
    end
    return

    -- Pawn: Show Scale Weights
  elseif sub == "weights" then
    local q = tail and tail:match("scale%s+(.+)$") or tail
    local entry = nil
    if q and XIVEquip.PawnGetAllScales then
      for _, r in ipairs(XIVEquip.PawnGetAllScales()) do
        if (r.name and r.name:lower() == q:lower()) or (r.key and r.key:lower() == q:lower()) then
          entry = r; break
        end
      end
    end
    if not entry and XIVEquip.PawnBestActiveScale then entry = XIVEquip.PawnBestActiveScale() end
    if not entry then
      print("  No Pawn scale found."); return
    end
    local vals = XIVEquip.GetPawnScaleValues and select(1, XIVEquip.GetPawnScaleValues(entry)) or entry.values
    print("  Weights for:", entry.name or entry.key or "?")
    if type(vals) ~= "table" then
      print("   (no table available)"); return
    end
    local ks = {}; for k in pairs(vals) do ks[#ks + 1] = k end; table.sort(ks)
    for _, k in ipairs(ks) do print("   ", k, "=", tostring(vals[k])) end
    return

    -- Comparer: Score an item by link with Pawn
  elseif sub == "score" then
    local link = tail:match("(|c%x+|Hitem:[^|]+|h[^|]*|h|r)") or tail:match("(|Hitem:[^|]+|h[^|]*|h)")
    if not link then
      print("  Usage: /xive pawn score <link> [scale <name>]"); return
    end
    if XIVEquip.PawnScoreLinkAuto then
      local v, src = XIVEquip.PawnScoreLinkAuto(link)
      print(string.format("  Score: %.2f (%s)", tonumber(v) or 0, src or "pawn"))
    else
      print("  Pawn scoring not available.")
    end
    return
  end

  pawn_help()
end)

-- Contribute Pawn-specific lines to the global /xive help
Cmd.Help(" /xive pawn                    – Pawn module commands")
Cmd.Help(" /xive pawn scales [all]       – list Pawn scales (active or all)")
Cmd.Help(" /xive pawn weights [name]     – show weights (active or by name)")
Cmd.Help(" /xive pawn score <link> [scale <name>] – score with Pawn (optionally with a specific scale)")
