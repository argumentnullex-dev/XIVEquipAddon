-- Pawn.lua — XIVEquip Pawn comparer (strict scoring; SV-first; API-probed fallback)
local addonName, XIVEquip = ...
local Comparers = XIVEquip and XIVEquip.Comparers
if not Comparers then return end

local Log = XIVEquip.Log or { Debug=function(...) print("|cff66ccffXIVEquip|r", ...) end,
                               Info =function(...) print("|cff66ccffXIVEquip|r", ...) end,
                               Warn =function(...) print("|cff66ccffXIVEquip|r [warn]", ...) end }
local L = (XIVEquip and XIVEquip.L) or {}
local AddonPrefix = L.AddonPrefix or "XIVEquip: "

-- ---------- Pawn API wiring ----------
local IsLoaded  = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
local LoadAddOn = (C_AddOns and C_AddOns.LoadAddOn)    or _G.LoadAddOn
local api = {}

local function ensurePawnLoaded()
  if IsLoaded and IsLoaded("Pawn") then return true end
  if LoadAddOn then pcall(LoadAddOn, "Pawn") end
  return true
end

local function probeAPI()
  api = {
    GetAllInfo   = _G.PawnGetAllScaleInfo,       -- array of recs (preferred)
    GetAllScales = _G.PawnGetAllScales,          -- map tag -> rec/string (fallback)
    GetName      = _G.PawnGetScaleLocalizedName, -- tag -> display name
    IsVisible    = _G.PawnIsScaleVisible,        -- tag -> boolean
    GetItemData  = _G.PawnGetItemData,           -- link -> itemTable
    ItemValue    = _G.PawnGetItemValue,          -- (itemTable, scaleNameDisplay)
    SingleValue  = _G.PawnGetSingleValue,        -- (itemTable, scaleNameDisplay)
    SingleFor    = _G.PawnGetSingleValueForItem, -- (link, scaleNameDisplay)
  }
  Log.Debug("Pawn API: AllInfo=",type(api.GetAllInfo)," AllScales=",type(api.GetAllScales),
            " GetName=",type(api.GetName)," ItemValue=",type(api.ItemValue),
            " SingleValue=",type(api.SingleValue)," SingleFor=",type(api.SingleFor),
            " GetItemData=",type(api.GetItemData))
end

-- ---------- utils ----------
local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
local function norm(s) return trim(s):lower() end
local function dequote(s) s = tostring(s or "") return (s:gsub('^"(.*)"$', "%1")) end

local function echo(cmd, arg)
  cmd = tostring(cmd or "")
  arg = tostring(arg or "")
  if arg ~= "" then
    print(("|cff66ccffXIVEquip|r [/xivepawn %s %s]"):format(cmd, arg))
  else
    print(("|cff66ccffXIVEquip|r [/xivepawn %s]"):format(cmd))
  end
end


-- helper: build an index of active scales reported by Pawn API
local function API_ActiveIndex()
  ensurePawnLoaded()
  probeAPI()
  local act = {}
  if type(api.GetAllInfo) == "function" then
    for _, rec in ipairs(api.GetAllInfo() or {}) do
      if rec then
        local rawTag = rec.Tag or rec.Key
        local active = rec.Active or rec.Visible or isTagVisible(rawTag)
        if active then
          local name = norm(rec.LocalizedName or rec.PrettyName or rawTag)
          if name ~= "" then act[name] = true end
          local tag = norm(rawTag)
          if tag ~= "" then act[tag] = true end
        end
      end
    end
  elseif type(api.GetAllScales) == "function" then
    for k, v in pairs(api.GetAllScales() or {}) do
      local rec = type(v)=="table" and v or nil
      local tag = dequote(type(k)=="string" and k or (type(v)=="string" and v) or "")
      local active = rec and (rec.Active or rec.Visible or isTagVisible(tag))
      if active then
        local name = norm((rec.LocalizedName or rec.PrettyName or
                          (type(api.GetName)=="function" and api.GetName(tag)) or tag))
        if name ~= "" then act[name] = true end
        local tagl = norm(tag)
        if tagl ~= "" then act[tagl] = true end
      end
    end
  end
  return act
end

local function playerSpec()
  local idx = GetSpecialization()
  local specName = idx and select(2, GetSpecializationInfo(idx)) or ""
  return idx, specName
end

local function isTagVisible(tag)
  tag = tostring(tag or "")
  if type(api.IsVisible)=="function" then
    local ok,vis = pcall(api.IsVisible, tag); if ok then return vis == true end
  end
  local PO = _G.PawnOptions
  if type(PO)=="table" and type(PO.Scales)=="table" then
    for _, s in ipairs(PO.Scales) do
      if s.Key == tag and s.Visible == true then return true end
    end
  end
  return false
end

-- collect SavedVariable scales; mark active if SV says so OR API says so
function SV_Scales(onlyActive)
  if onlyActive == nil then onlyActive = true end
  ensurePawnLoaded()
  probeAPI()
  local activeIdx = API_ActiveIndex()
  local out = {}

  local function push(s)
    if type(s) ~= "table" then return end
    local name   = s.Name or s.LocalizedName or s.PrettyName
    local tag    = s.Key or s.Tag
    local values = (type(s.Values) == "table") and s.Values or nil

    local svActive  = (s.Active == "Y") or (s.Active == true)
    local svVisible = (s.Visible == true)
    local byName    = name and activeIdx[(name or ""):lower()]
    local byTag     = tag and tag ~= "" and activeIdx[(tag or ""):lower()]
    local visible   = svVisible or isTagVisible(tag)
    local active    = svActive or byName or byTag or visible

    if (not onlyActive) or active then
      table.insert(out, {
        name    = name,
        tag     = tag,
        values  = values,
        active  = active,
        visible = visible,
        _raw    = s,
      })
    end
  end

  local function add(container)
    if type(container) ~= "table" then return end
    for _, s in pairs(container) do push(s) end
  end

  add(PawnOptions and PawnOptions.Scales)
  if PawnOptions and PawnOptions.PerCharacterOptions then
    for _, perChar in pairs(PawnOptions.PerCharacterOptions) do
      if perChar and type(perChar.Scales) == "table" then add(perChar.Scales) end
    end
  end
  add(PawnCommon and PawnCommon.Scales)

  return out
end

-- Provider/API scales: include only those visible to this character
local function API_Scales()
  local out = {}

  local function push(tag, name, values)
    tag  = tostring(tag or "")
    name = tostring(name or "")
    if (tag ~= "" or name ~= "") and isTagVisible(tag) then
      table.insert(out, {
        tag    = tag,
        name   = name,
        values = type(values) == "table" and values or nil,
        active = true,
      })
    end
  end

  if type(api.GetAllInfo) == "function" then
    for _, rec in ipairs(api.GetAllInfo() or {}) do
      if type(rec) == "table" then
        push(
          dequote(rec.Tag or rec.Key or ""),
          rec.LocalizedName or rec.PrettyName or rec.Tag,
          rec.Values
        )
      end
    end
  elseif type(api.GetAllScales) == "function" then
    for k, v in pairs(api.GetAllScales() or {}) do
      local tag = dequote(type(k)=="string" and k or (type(v)=="string" and v) or "")
      local name = (type(v)=="table" and (v.LocalizedName or v.PrettyName))
                or (type(api.GetName)=="function" and api.GetName(tag))
                or tag
      local values = type(v) == "table" and v.Values or nil
      push(tag, name, values)
    end
  end

  return out
end


local function specTokens(specName)
  local n = norm(specName); local t={n}
  if n:find("retribution",1,true) then t[#t+1]="ret" end
  if n:find("protection",1,true)  then t[#t+1]="prot" end
  if n:find("restoration",1,true) then t[#t+1]="resto" end
  if n:find("discipline",1,true)  then t[#t+1]="disc" end
  if n:find("demonology",1,true)  then t[#t+1]="demo" end
  if n:find("destruction",1,true) then t[#t+1]="destro" end
  if n:find("subtlety",1,true)    then t[#t+1]="sub" end
  return t
end

-- pick any cached item for probing
local function sampleItem()
  if type(api.GetItemData) ~= "function" then return nil end
  for _,slot in ipairs({1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}) do
    local link = GetInventoryItemLink("player", slot)
    if link then local ok,it = pcall(api.GetItemData, link); if ok and type(it)=="table" then return it, link end end
  end
  for bag=0, NUM_BAG_SLOTS do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    for s=1,n do
      local link = C_Container.GetContainerItemLink(bag, s)
      if link then local ok,it = pcall(api.GetItemData, link); if ok and type(it)=="table" then return it, link end end
    end
  end
  return nil
end

-- true if Pawn returns a numeric for (itemTable, scaleDisplayName)
local function scoresOnThisBuild(itemTable, scaleName)
  if not itemTable or not scaleName or scaleName=="" then return false end
  if type(api.ItemValue)=="function" then
    local ok,v = pcall(api.ItemValue, itemTable, scaleName)
    Log.Debug("score-probe ItemValue(",scaleName,"):", ok and v or ("err:"..tostring(v)))
    if ok and type(v)=="number" then return true end
  end
  if type(api.SingleValue)=="function" then
    local ok,v = pcall(api.SingleValue, itemTable, scaleName)
    Log.Debug("score-probe SingleValue(",scaleName,"):", ok and v or ("err:"..tostring(v)))
    if ok and type(v)=="number" then return true end
  end
  return false
end

-- ---------- resolver (SV-first, API-probe fallback) ----------
local Active = { name=nil, tag=nil, reason=nil }

local function resolveScaleStrict()
  Active.name, Active.tag, Active.reason = nil, nil, nil
  if not ensurePawnLoaded() then return nil, "not_loaded" end
  probeAPI()

  local specIdx, specName = playerSpec()
  if not specIdx or specName=="" then return nil, "no_spec" end
  local tokens    = specTokens(specName)
  local itemTable = sampleItem()

  -- 1) Per-spec override -> match against SV first (must have values), else against API (but must score).
  local S  = _G.XIVEquip_Settings or {}
  local ov = S.PawnScaleBySpec and S.PawnScaleBySpec[specIdx]
  if type(ov)=="string" and ov~="" then
    -- SV exact
    for _,r in ipairs(SV_Scales(true)) do
      if r.values and (r.name==ov or r.tag==ov) and (r.visible or (r.tag and isTagVisible(r.tag))) then
        if not itemTable or scoresOnThisBuild(itemTable, r.name) then
          Active.name, Active.tag, Active.reason = r.name, r.tag, "override(SV)"
          XIVEquip._PawnActiveName, XIVEquip._PawnActiveTag, XIVEquip._PawnActiveReason = Active.name, Active.tag, Active.reason
          Log.Debug("resolve: override SV => NAME=", r.name, " TAG=", r.tag or "—")
          return Active.name, Active.reason
        end
      end
    end
    -- API exact
    for _,r in ipairs(API_Scales()) do
      if (r.name==ov or r.tag==ov) and r.active then
        if not itemTable or scoresOnThisBuild(itemTable, r.name) then
          Active.name, Active.tag, Active.reason = r.name, r.tag, "override(API)"
          XIVEquip._PawnActiveName, XIVEquip._PawnActiveTag, XIVEquip._PawnActiveReason = Active.name, Active.tag, Active.reason
          Log.Debug("resolve: override API => NAME=", r.name, " TAG=", r.tag or "—")
          return Active.name, Active.reason
        end
      end
    end
    Log.Warn("resolve: override not usable; continuing with spec match.")
  end

  -- 2) Prefer **visible** SV scales with weights matching spec tokens (your personal scales)
  do
    local candidates={}
    for _,r in ipairs(SV_Scales(true)) do
      if r.values and r.visible then
        local ln = norm(r.name or "")
        for _,t in ipairs(tokens) do
          if ln:find(t,1,true) then candidates[#candidates+1]=r; break end
        end
      end
    end
    table.sort(candidates, function(a,b) return norm(a.name)<norm(b.name) end)
    for _,r in ipairs(candidates) do
      if not itemTable or scoresOnThisBuild(itemTable, r.name) then
        Active.name, Active.tag, Active.reason = r.name, r.tag, "sv_with_values"
        XIVEquip._PawnActiveName, XIVEquip._PawnActiveTag, XIVEquip._PawnActiveReason = Active.name, Active.tag, Active.reason
        Log.Debug("resolve: SV picked => NAME=", r.name, " TAG=", r.tag or "—")
        return Active.name, Active.reason
      end
    end
  end

  -- 3) Fall back to **visible** provider/API scales that match spec tokens, but only if they score.
  do
    local candidates={}
    for _,r in ipairs(API_Scales()) do
      if r.active then
        local ln, lt = norm(r.name or ""), norm(r.tag or "")
        for _,t in ipairs(tokens) do
          if ln:find(t,1,true) or lt:find(t,1,true) then
            -- prefer MrRobot, then Wowhead, then Other by simple heuristic
            local pr = r.tag:find("MrRobot",1,true) and 1 or (r.tag:find("Wowhead",1,true) and 2 or 3)
            candidates[#candidates+1] = {rec=r, pr=pr}
            break
          end
        end
      end
    end
    table.sort(candidates, function(a,b) if a.pr~=b.pr then return a.pr<b.pr end return norm(a.rec.name)<norm(b.rec.name) end)
    for _,c in ipairs(candidates) do
      local r = c.rec
      if not itemTable or scoresOnThisBuild(itemTable, r.name) then
        Active.name, Active.tag, Active.reason = r.name, r.tag, "api_active"
        XIVEquip._PawnActiveName, XIVEquip._PawnActiveTag, XIVEquip._PawnActiveReason = Active.name, Active.tag, Active.reason
        Log.Debug("resolve: API picked => NAME=", r.name, " TAG=", r.tag or "—")
        return Active.name, Active.reason
      end
    end
  end

  return nil, "no_scoreable_active"
end

-- ---------- comparer ----------
Comparers:RegisterComparer("Pawn", {
  Label = "Pawn",

  IsAvailable = function()
    local ok = ensurePawnLoaded()
    probeAPI()
    ok = ok and (api.GetAllInfo or api.GetAllScales) and (api.ItemValue or api.SingleValue or api.SingleFor)
    Log.Debug("Pawn IsAvailable:", ok and "true" or "false")
    return ok and true or false
  end,

  -- Strict: only run if we found a usable Pawn scale that scores.
  PrePass = function()
    local name, reason = resolveScaleStrict()
    if not name then
      Log.Warn("Pawn PrePass: no usable scale (", reason, ")")
      if _G.XIVEquip_Settings and _G.XIVEquip_Settings.Messages and _G.XIVEquip_Settings.Messages.Login ~= false then
        print(AddonPrefix .. "Pawn active scale not usable ("..tostring(reason)..").")
      end
      return false
    end
    Log.Debug(("Pawn PrePass using: %s (tag=%s) via %s"):format(Active.name or "?", Active.tag or "—", reason or "?"))
    return true
  end,

  -- Score via Pawn using display NAME. Accept 0. Never fall back to ilvl.
  ScoreItem = function(location)
    if not Active.name then return nil end
    if C_Item and C_Item.IsItemDataCached and not C_Item.IsItemDataCached(location) then
      if C_Item.RequestLoadItemData then C_Item.RequestLoadItemData(location) end
      XIVEquip._needsItemRetry = true
      return nil
    end
    local link = C_Item and C_Item.GetItemLink and C_Item.GetItemLink(location)
    if not link then return nil end

    if type(api.GetItemData)=="function" then
      local okIt, it = pcall(api.GetItemData, link)
      if okIt and type(it)=="table" then
        if type(api.ItemValue)=="function" then
          local ok,v = pcall(api.ItemValue, it, Active.name)
          Log.Debug("Pawn ScoreItem(ItemValue):", ok and v or ("err:"..tostring(v)), "name=", Active.name)
          if ok and type(v)=="number" then return v end
        end
        if type(api.SingleValue)=="function" then
          local ok,v = pcall(api.SingleValue, it, Active.name)
          Log.Debug("Pawn ScoreItem(SingleValue):", ok and v or ("err:"..tostring(v)), "name=", Active.name)
          if ok and type(v)=="number" then return v end
        end
      end
    end
    if type(api.SingleFor)=="function" then
      local ok,v = pcall(api.SingleFor, link, Active.name)
      Log.Debug("Pawn ScoreItem(SingleForItem):", ok and v or ("err:"..tostring(v)), "name=", Active.name)
      if ok and type(v)=="number" then return v end
    end
    return nil
  end,
})

-- ---------- /xivepawn debug ----------
SLASH_XIVEPAWN1 = "/xivepawn"
SlashCmdList["XIVEPAWN"] = function(msg)
  local sub = msg:match("^(%S+)") or ""
  ensurePawnLoaded()
  probeAPI()

  -- /xivepawn scales
  if sub == "scales" then
    echo("scales", "")
    if ensurePawnLoaded() then
      probeAPI()
      local printed = 0
      if type(api.GetAllInfo) == "function" then
        for _, rec in pairs(api.GetAllInfo() or {}) do
          if type(rec) == "table" then
            local tag  = dequote(rec.Tag or rec.Key or "")
            local name = rec.LocalizedName or rec.PrettyName or rec.Tag
            print(("|cff66ccffXIVEquip|r TAG=%s NAME=%s Active=%s")
              :format(tag ~= "" and tag or "—", name or "—", isTagVisible(tag) and "Y" or "N"))
            printed = printed + 1
          end
        end
      elseif type(api.GetAllScales) == "function" then
        for k, v in pairs(api.GetAllScales() or {}) do
          local tag = dequote(type(k)=="string" and k or (type(v)=="string" and v) or "")
          local name = (type(v)=="table" and (v.LocalizedName or v.PrettyName))
                    or (type(api.GetName)=="function" and api.GetName(tag))
                    or tag
          print(("|cff66ccffXIVEquip|r TAG=%s NAME=%s Active=%s")
            :format(tag ~= "" and tag or "—", name or "—", isTagVisible(tag) and "Y" or "N"))
          printed = printed + 1
        end
      end
      if printed == 0 then
        print("|cff66ccffXIVEquip|r Pawn API not available.")
      end
    else
      print("|cff66ccffXIVEquip|r Pawn API not available.")
    end
    return
  end

  -- /xivepawn sv
  if sub == "sv" then
    echo("sv", "")
    ensurePawnLoaded()
    probeAPI()
    local rows = SV_Scales(false)

    -- merge in visible provider scales that lack an SV table
    local seen = {}
    for _, r in ipairs(rows) do
      local t = (r.tag or ""):lower()
      local n = (r.name or ""):lower()
      if t ~= "" then seen[t] = true end
      if n ~= "" then seen[n] = true end
    end
    for _, r in ipairs(API_Scales()) do
      local t = (r.tag or ""):lower()
      local n = (r.name or ""):lower()
      if not seen[t] and not seen[n] then
        rows[#rows+1] = {
          name         = r.name,
          tag          = r.tag,
          values       = r.values,
          active       = r.active,
          visible      = true,
          providerOnly = true,
        }
      end
    end

    for _, r in ipairs(rows) do
      print(("|cff66ccffXIVEquip|r SV: NAME=%s TAG=%s Active=%s Visible=%s Values=%s ProviderOnly=%s ProviderValues=%s")
        :format(r.name or "—", r.tag or "—",
                r.active and "Y" or "N",
                r.visible and "Y" or "N",
                r.values and "Y" or "N",
                r.providerOnly and "Y" or "N",
                (r.providerOnly and r.values) and "Y" or "N"))
    end
    return
  end

  -- /xivepawn weights <name/tag>
  if sub:sub(1,7) == "weights" then
    local q = (msg:sub(8) or ""):match("^%s*(.-)%s*$")
    echo("weights", q)
    if q == "" then
      print("|cff66ccffXIVEquip|r Usage: /xivepawn weights <name|tag>")
      return
    end
    local ql = q:lower()

    ensurePawnLoaded()
    probeAPI()

    local function dump(r)
      if r and r.values then
        print(("|cff66ccffXIVEquip|r Weights for [%s] (tag=%s):")
          :format(r.name or "—", r.tag or "—"))
        for stat, val in pairs(r.values) do
          print("   ", stat, "=", val)
        end
        return true
      end
    end

    local svActive  = SV_Scales(true)
    local apiActive = API_Scales()

    -- 1) exact match (active SV scales)
    for _, r in ipairs(svActive) do
      local n = (r.name or ""):lower()
      local t = (r.tag or ""):lower()
      if (n == ql or (t ~= "" and t == ql)) and dump(r) then return end
    end

    -- 2) substring match (active SV scales)
    for _, r in ipairs(svActive) do
      local n = (r.name or ""):lower()
      local t = (r.tag or ""):lower()
      if (n:find(ql, 1, true) or (t ~= "" and t:find(ql, 1, true))) and dump(r) then return end
    end

    -- 3) exact match (active provider scales via API)
    for _, r in ipairs(apiActive) do
      local n = (r.name or ""):lower()
      local t = (r.tag or ""):lower()
      if n == ql or (t ~= "" and t == ql) then
        for _, sv in ipairs(svActive) do
          local sn = (sv.name or ""):lower()
          local st = (sv.tag or ""):lower()
          if sn == n or (st ~= "" and st == t) then
            if dump(sv) then return end
          end
        end
        if dump(r) then return end
        print(("|cff66ccffXIVEquip|r '%s' is an active provider scale with no SV table; " ..
               "XIVEquip scores it via Pawn API at runtime.")
          :format(r.name or r.tag or q))
        return
      end
    end

    -- 4) substring match (active provider scales via API)
    for _, r in ipairs(apiActive) do
      local n = (r.name or ""):lower()
      local t = (r.tag or ""):lower()
      if n:find(ql, 1, true) or (t ~= "" and t:find(ql, 1, true)) then
        for _, sv in ipairs(svActive) do
          local sn = (sv.name or ""):lower()
          local st = (sv.tag or ""):lower()
          if sn == n or (st ~= "" and st == t) then
            if dump(sv) then return end
          end
        end
        if dump(r) then return end
        print(("|cff66ccffXIVEquip|r '%s' is an active provider scale with no SV table; " ..
               "XIVEquip scores it via Pawn API at runtime.")
          :format(r.name or r.tag or q))
        return
      end
    end
    print("|cff66ccffXIVEquip|r No scale matched:", q)
    return
  end

  -- /xivepawn score <scale> [itemLink]
  if sub == "score" then
    local rest = msg:sub(6) or ""
    local scale, link = rest:match("^%s*(%S+)%s*(.*)")
    scale = trim(scale)
    link = trim(link)
    echo("score", scale .. (link ~= "" and (" " .. link) or ""))
    if scale == "" then
      print("|cff66ccffXIVEquip|r Usage: /xivepawn score <scale> [itemLink]")
      return
    end
    ensurePawnLoaded()
    probeAPI()
    local itemTable, itemLink
    if link ~= "" then
      itemLink = link
      if type(api.GetItemData) == "function" then
        local ok,it = pcall(api.GetItemData, link)
        if ok and type(it) == "table" then itemTable = it end
      end
    else
      itemTable, itemLink = sampleItem()
    end
    if not itemTable and not itemLink then
      print("|cff66ccffXIVEquip|r No item available to score.")
      return
    end
    local score
    if itemTable and type(api.ItemValue) == "function" then
      local ok,v = pcall(api.ItemValue, itemTable, scale)
      if ok and type(v) == "number" then score = v end
    end
    if not score and itemLink and type(api.SingleFor) == "function" then
      local ok,v = pcall(api.SingleFor, itemLink, scale)
      if ok and type(v) == "number" then score = v end
    end
    if score then
      print(("|cff66ccffXIVEquip|r Score[%s] = %s"):format(scale, score))
    else
      print(("|cff66ccffXIVEquip|r Unable to score scale '%s'."):format(scale))
    end
    return
  end

  -- default help
  print("|cff66ccffXIVEquip|r Usage: /xivepawn <scales | sv | weights <name> | score <scale>>")
end
