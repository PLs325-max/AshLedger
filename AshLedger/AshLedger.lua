-- Ash Ledger 1.0 (beta): standalone Soul Ash, crates and character raid locks.
local addonName=...
local db,current,window,body,status,totalText,minimapButton
local rows,offset,elapsed={},0,0
local refreshing=false
local renderDirty=true
local nextRaidExpiry
local bagsPending=false
local rateFrame
local rateSession={gain=0,last={}}
local updateRate,toggleRate
local refresh,scan,applyFonts
local fontWidgets,styledButtons={},{}
local FONTS={{name="Friz Quadrata",path="Fonts\\FRIZQT__.TTF"},{name="Arial Narrow",path="Fonts\\ARIALN.TTF"},{name="Morpheus",path="Fonts\\MORPHEUS.TTF"},{name="Skurri",path="Fonts\\SKURRI.TTF"}}
local function fontSize() return math.max(8,math.min(18,tonumber(db and db.fontSize) or 11)) end
local function rowHeight() return math.max(25,fontSize()+14) end
local CRATE=95010
local RAID_COLUMNS = {
    {key="naxx10",name="Naxxramas",size=10,title="Naxx 10"},
    {key="naxx25",name="Naxxramas",size=25,title="Naxx 25"},
    {key="os10",name="The Obsidian Sanctum",size=10,title="OS 10"},
    {key="os25",name="The Obsidian Sanctum",size=25,title="OS 25"},
    {key="eoe10",name="The Eye of Eternity",size=10,title="EoE 10"},
    {key="eoe25",name="The Eye of Eternity",size=25,title="EoE 25"},
    {key="ulduar10",name="Ulduar",size=10,title="Uld 10"},
    {key="ulduar25",name="Ulduar",size=25,title="Uld 25"},
    {key="icc10",name="Icecrown Citadel",size=10,title="ICC 10"},
    {key="icc25",name="Icecrown Citadel",size=25,title="ICC 25"},
    {key="icc10h",name="Icecrown Citadel",size=10,title="ICC 10H",heroic=true},
    {key="icc25h",name="Icecrown Citadel",size=25,title="ICC 25H",heroic=true},
}
local function raidName(name)
    return (name or ""):lower():gsub("^the%s+", ""):gsub("[^%a]", "")
end
local function requestLocks()
    if RequestRaidInfo then RequestRaidInfo() end
end
local function updateLocks()
    if not db or not current or not GetNumSavedInstances or not GetSavedInstanceInfo then return end
    local locks = {}
    for i=1,GetNumSavedInstances() do
        local name,id,reset,difficulty,locked,extended,_,isRaid,size,difficultyName = GetSavedInstanceInfo(i)
        if (locked or extended) and isRaid ~= false then
            if size ~= 10 and size ~= 25 then
                if difficulty==1 or difficulty==3 then size=10
                elseif difficulty==2 or difficulty==4 then size=25 end
            end
            for _,col in ipairs(RAID_COLUMNS) do
                local heroic=difficulty==3 or difficulty==4 or (type(difficultyName)=="string" and difficultyName:lower():find("heroic",1,true)~=nil)
                if raidName(name)==raidName(col.name) and size==col.size and (not col.key:match("^icc") or (col.heroic or false)==heroic) then
                    local record={id=id,resetAt=reset and reset>0 and (time()+reset) or nil,extended=extended or false}
                    local old=locks[col.key]
                    if not old or (record.resetAt or math.huge)>(old.resetAt or math.huge) then locks[col.key]=record end
                end
            end
        end
    end
    local e=db.characters[current]; e.locks=locks; e.locksUpdated=time()
end
local function lockState(entry,key)
    if not entry.locksUpdated then return 3 end
    local lock=entry.locks and entry.locks[key]
    if not lock then return 0 end
    if lock.resetAt and lock.resetAt<=time() then return 2 end
    return 1
end
local function lockText(entry,key)
    local state=lockState(entry,key)
    if state==3 then return "|cff999999--|r" end
    if state==0 then return "|cff44ff33Ready|r" end
    if state==2 then return "|cffaaaaaaRecheck|r" end
    return "|cffff4444Locked|r"
end

local function say(s) DEFAULT_CHAT_FRAME:AddMessage("|cffb66affAshLedger:|r "..s) end
local function crateCount(e) return (e.bags or 0)+(e.bank or 0) end
local function crateValue() return db.bonus and 800000 or 400000 end
local function available(e) return (e.ash or 0)+(e.savedAsh or 0)+crateCount(e)*crateValue() end
local function getSort() return (db.view=="raids" and db.raidSort or db.ashSort) or {key="name",ascending=true} end
local function setSort(key)
 local old=getSort();local sort={key=key,ascending=old.key==key and not old.ascending or (old.key~=key and (key=="name" or key:match("^raid:")) and true or false)};if db.view=="raids" then db.raidSort=sort else db.ashSort=sort end;offset=0;refresh()
end
local function value(e,key)
 if key:match("^raid:") then return lockState(e,key:sub(6)) end
 if key=="name" then return e.name:lower() elseif key=="level" then return e.level elseif key=="ash" then return e.ash elseif key=="savedAsh" then return e.savedAsh elseif key=="resetCost" then return e.raidResetCost elseif key=="crates" then return crateCount(e) else return available(e) end
end
local function clean(s)
    return (tostring(s or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function number(s)
    s = clean(s):gsub(",", ""):match("^%s*(%d+)%s*$")
    return s and tonumber(s)
end
local function fmt(n)
    if n == nil then return "--" end
    local s = tostring(math.floor(n))
    repeat local k; s,k = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
local function resetSummary()
 local nextReset,unknown,expired
 for _,e in pairs(db.characters) do if e.realm==GetRealmName() then
  for _,col in ipairs(RAID_COLUMNS) do local lock=e.locks and e.locks[col.key]
   if lock then
    if lock.resetAt and lock.resetAt>time() then nextReset=math.min(nextReset or lock.resetAt,lock.resetAt)
    elseif lock.resetAt then expired=true else unknown=true end
   end
  end
 end end
 if nextReset then local seconds=math.max(0,nextReset-time());return string.format("Raids reset: %dd %02d:%02d:%02d",math.floor(seconds/86400),math.floor(seconds%86400/3600),math.floor(seconds%3600/60),math.floor(seconds%60)) end
 return unknown and "Raids reset: unknown" or expired and "Reset passed - refresh" or "Raids reset: no saved timer"
end
local function texts(frame, out, depth)
    if not frame or depth > 12 or (frame.IsVisible and not frame:IsVisible()) then return end
    local regions = {frame:GetRegions()}
    for _,r in ipairs(regions) do
        if r:GetObjectType() == "FontString" then
            local t = clean(r:GetText())
            if t ~= "" then out[#out+1] = {text=t, name=r:GetName(), parent=frame} end
        end
    end
    for _,child in ipairs({frame:GetChildren()}) do texts(child,out,depth+1) end
end
local function within(frame,ancestor)
 local depth=0
 while frame and depth<50 do if frame==ancestor then return true end;frame=frame.GetParent and frame:GetParent();depth=depth+1 end
 return false
end
local function ownFrame(frame)
 local depth=0
 while frame and depth<50 do
  local name=frame.GetName and frame:GetName();local lower=name and name:lower() or ""
  if lower:find("ashledger",1,true) or lower:find("altoholic",1,true) or lower:find("datastore",1,true) then return true end
  frame=frame.GetParent and frame:GetParent();depth=depth+1
 end
 return false
end
-- Cache only frames exposing currency/reset labels. Discovery is bounded;
-- never synchronously traverse the complete UI from a recurring timer.
local currencyFrames,currencySet,resetFrames,resetSet={},{},{},{}
local discovery={active=true,cursor=nil,idle=0,enumerator=nil}
local function directTexts(frame,out)
 if not frame or ownFrame(frame) or (frame.IsVisible and not frame:IsVisible()) then return end
 if frame.GetRegions then for i,region in ipairs({frame:GetRegions()}) do
  if i>40 then break end
  if region.GetText then local text=clean(region:GetText());if text~="" then out[#out+1]={text=text,name=region.GetName and region:GetName(),parent=frame} end end
 end end
 if frame.GetText then local text=clean(frame:GetText());if text~="" then out[#out+1]={text=text,name=frame.GetName and frame:GetName(),parent=frame} end end
end
local function nearbyTexts(frame,out)
 directTexts(frame,out)
 if frame and frame.GetChildren and (not frame.IsVisible or frame:IsVisible()) then
  for i,child in ipairs({frame:GetChildren()}) do if i>40 then break end;directTexts(child,out) end
 end
end
local function requestDiscovery()
 if not discovery.active then discovery.active=true;discovery.cursor=nil end
 discovery.idle=0
end
local function discoverStep(delta)
 discovery.idle=discovery.idle+delta
 if not EnumerateFrames then return end
 if discovery.enumerator~=EnumerateFrames then discovery.enumerator=EnumerateFrames;discovery.active=true;discovery.cursor=nil end
 if InCombatLockdown and InCombatLockdown() then return end
 if not discovery.active then return end
 -- Maximum 24 frames or 0.25ms per render tick, independent of UI size.
 local started=debugprofilestop and debugprofilestop()
 for i=1,24 do
  if i>1 and started and debugprofilestop()-started>=.25 then break end
  local frame=EnumerateFrames(discovery.cursor)
  discovery.cursor=frame
  if not frame then discovery.active=false;discovery.idle=0;return end
  if not ownFrame(frame) and (not frame.IsVisible or frame:IsVisible()) then
   local entries={};directTexts(frame,entries)
   for _,entry in ipairs(entries) do
    local lower=entry.text:lower();local key=lower:gsub("[^%a]","")
    if (lower:find("soul%s*ashe?s?%f[%A]") or lower:find("saved%s+ash")) and not currencySet[frame] and #currencyFrames<128 then currencySet[frame]=true;currencyFrames[#currencyFrames+1]=frame end
    if (key:find("clearids",1,true) or key:find("raidresetcost",1,true)) and not resetSet[frame] and #resetFrames<32 then resetSet[frame]=true;resetFrames[#resetFrames+1]=frame end
   end
  end
 end
end
local function ashRoots()
 local roots,seen={},{}
 local function add(frame)
  if frame and not seen[frame] and frame.GetRegions and not ownFrame(frame) and (not frame.IsVisible or frame:IsVisible()) then seen[frame]=true;roots[#roots+1]=frame end
 end
 for _,name in ipairs({"ProjectEbonholdPlayerRunFrame","PlayerTalentFrame","ProjectEbonholdSkillTreeFrame","ProjectEbonholdTalentFrame","EbonholdSkillTreeFrame"}) do add(_G[name]) end
 for _,frame in ipairs(currencyFrames) do add(frame) end
 return roots
end
-- Session observations are independent of persisted character snapshots.
local function observeRate(run,saved)
 local values={run=run,saved=saved}
 for key,value in pairs(values) do
  if value~=nil then
   if not rateSession.started then rateSession.started=GetTime() end
   if rateSession.last[key]~=nil then rateSession.gain=rateSession.gain+value-rateSession.last[key] end
   rateSession.last[key]=value
  end
 end
end
local function resetRate()
 rateSession.gain=0;rateSession.started=GetTime()
 if updateRate then updateRate() end
end
local function rateText()
 if not rateSession.started then return "Ash/h: --" end
 local seconds=GetTime()-rateSession.started
 local value=seconds>0 and rateSession.gain*3600/seconds or 0
 return "Ash/h: "..fmt(value<0 and math.ceil(value) or math.floor(value))
end
updateRate=function()
 local text=rateText()
 if window and window:IsShown() and window.rateText then window.rateText:SetText(text) end
 if rateFrame and rateFrame:IsShown() then rateFrame.value:SetText(text) end
end
local function balanceNumber(text)
 text=clean(text):gsub(",",""):gsub("\194\160"," "):gsub("\226\128\175"," ")
 repeat local changed;text,changed=text:gsub("(%d)%s+(%d)","%1%2");if changed==0 then break end until false
 local value=text:match("^%s*(%d+)%s*$") or text:match(":%s*(%d+)%s*$")
 if value then return tonumber(value) end
 local amount,suffix=text:match("([%d]+%.?[%d]*)%s*([kKmMbB])%s*$")
 if amount then local factor=({k=1000,m=1000000,b=1000000000})[suffix:lower()];return math.floor(tonumber(amount)*factor+.5) end
 return nil
end
local function readAsh()
 if db.source then
  local field=_G[db.source]
  if field and field.GetText and (not field.IsVisible or field:IsVisible()) then
   local n=balanceNumber(field:GetText())
   if n then return n,"Reading selected available-ash field." end
  end
  return nil,"Selected field unavailable; /ashle source auto to reset."
 end
 local entries={};local run=_G.ProjectEbonholdPlayerRunFrame
 if run and run:IsVisible() then texts(run,entries,0) end
 local candidates,best={},0
 local function add(n,rank)
  if n==nil then return end
  if rank>best then candidates={};best=rank end
  if rank==best then candidates[n]=true end
 end
 for _,entry in ipairs(entries) do
  local lower=entry.text:lower();local fieldName=(entry.name or ""):lower()
  local bad=lower:find("spent",1,true) and not lower:find("unspent",1,true)
  for _,word in ipairs({"cost","crate","used","required","earned","lifetime","refund","reset"}) do if lower:find(word,1,true) then bad=true end end
  for _,word in ipairs({"cost","used","earned","lifetime","refund","reset"}) do if fieldName:find(word,1,true) then bad=true end end
  if fieldName:find("spent",1,true) and not fieldName:find("unspent",1,true) then bad=true end
  local namedAsh=fieldName:find("soulash",1,true) or fieldName:find("soul_ash",1,true)
  local labelledAsh=lower:find("%f[%a]ashe?s?%f[%A]") or lower:find("soulash",1,true)
  if not bad and (labelledAsh or namedAsh) then
   local rank=(lower:find("available",1,true) or lower:find("unspent",1,true) or lower:find("balance",1,true)) and 120 or labelledAsh and 100 or 80
   local n=balanceNumber(entry.text)
   if not n and labelledAsh and not entry.text:find("/",1,true) then n=tonumber(clean(entry.text):gsub(",",""):match("(%d+)%s*$")) end
   if n then add(n,rank) else
    local values={}
    for _,other in ipairs(entries) do if other.parent==entry.parent then local v=balanceNumber(other.text);if v then values[v]=true end end end
    local value,count=nil,0;for v in pairs(values) do value=v;count=count+1 end
    if count==1 then add(value,rank) end
   end
  end
 end
 local value,count=nil,0;for n in pairs(candidates) do value=n;count=count+1 end
 if count==1 then return value,"Available ash updated from visible run/skill-tree panel." end
 if count>1 then return nil,"Available ash ambiguous; /ashle debug or /ashle source FIELD." end
 -- Preserve unique-number fallback only for the original run panel.
 local root=_G.ProjectEbonholdPlayerRunFrame
 if root and root:IsVisible() then
  local original={};texts(root,original,0);local nums={}
  for _,entry in ipairs(original) do local n=number(entry.text);if n then nums[n]=true end end
  value,count=nil,0;for n in pairs(nums) do value=n;count=count+1 end
  if count==1 then return value,"Ash updated from unique run-panel value." end
 end
 return nil,"Open the skill tree or Ebonhold ash panel to read available ash."
end
local function readSavedAsh()
 if db.savedSource then
  local field=_G[db.savedSource]
  if field and field.GetText and (not field.IsVisible or field:IsVisible()) then local n=balanceNumber(field:GetText());if n then return n,"Saved ash updated from selected field." end end
  return nil,"Saved-ash field unavailable."
 end
 local entries={};for _,root in ipairs(ashRoots()) do directTexts(root,entries) end
 local candidates,best={},0
 local function add(n,rank)
  if n==nil then return end
  if rank>best then candidates={};best=rank end
  if rank==best then candidates[n]=true end
 end
 for _,entry in ipairs(entries) do if not ownFrame(entry.parent) and not within(entry.parent,_G.ProjectEbonholdPlayerRunFrame) then
  local lower=entry.text:lower();local named=(entry.name or ""):lower()
  local label=lower:match("^%s*soul%s*ashe?s?%f[%A]") or lower:match("^%s*saved%s+ashe?s?%f[%A]") or lower:match("^%s*available%s+soul%s*ashe?s?%f[%A]") or lower:match("^%s*unspent%s+soul%s*ashe?s?%f[%A]")
  local bad=false
  for _,word in ipairs({"cost","required","earned","lifetime","refund","reset","used","crate"}) do if lower:find(word,1,true) or named:find(word,1,true) then bad=true end end
  if (lower:find("spent",1,true) and not lower:find("unspent",1,true)) or (named:find("spent",1,true) and not named:find("unspent",1,true)) then bad=true end
  if label and not bad then
   local rank=(lower:find("saved",1,true) or lower:find("available",1,true) or lower:find("unspent",1,true)) and 120 or 100
   local n=balanceNumber(entry.text)
   if not n and not entry.text:find("/",1,true) then n=tonumber(clean(entry.text):gsub(",",""):match("(%d+)%s*$")) end
   if n then add(n,rank) else
    local values={};for _,other in ipairs(entries) do if other.parent==entry.parent then local v=number(other.text) or (other.text:match("^%s*[%d%.]+%s*[kKmMbB]%s*$") and balanceNumber(other.text));if v then values[v]=true end end end
    local value,count=nil,0;for v in pairs(values) do value=v;count=count+1 end
    if count==1 then add(value,rank) end
   end
  end
 end end
 local value,count=nil,0;for n in pairs(candidates) do value=n;count=count+1 end
 if count==1 then return value,"Saved ash updated from skill tree." end
 return nil,count>1 and "Saved ash ambiguous; /ashle debug lists visible fields." or "Open skill tree to update Saved Ash."
end
local function resetEntries()
 local entries,seen={},{}
 local function add(frame)
  if not frame or seen[frame] then return end;seen[frame]=true;nearbyTexts(frame,entries)
 end
 for _,root in ipairs({_G.FriendsFrame or false,_G.RaidFrame or false,_G.RaidFrameNotInRaid or false}) do if root then add(root) end end
 for _,frame in ipairs(resetFrames) do add(frame) end
 return entries
end
local function readRaidResetCost()
 local entries=resetEntries();local candidates,best={},0
 local function add(value,rank)
  if value==nil then return end
  if rank>best then candidates={};best=rank end
  if rank==best then candidates[value]=true end
 end
 local function amount(text)
  local normalized=clean(text):gsub("\194\160"," "):gsub("\226\128\175"," ")
  local token=normalized:match("(%d[%d,%s%.]*[kKmMbB]?)")
  return token and balanceNumber(token)
 end
 for _,entry in ipairs(entries) do
  local key=entry.text:lower():gsub("[^%a]","")
  if key:find("clearids",1,true) or key:find("raidresetcost",1,true) or key:find("resetraids",1,true) then
   local inline=amount(entry.text)
   if inline then add(inline,4) else
    local parent=entry.parent
    for depth=1,3 do
     if not parent or ownFrame(parent) then break end
     local nearby={};nearbyTexts(parent,nearby)
     for _,other in ipairs(nearby) do if other.text~=entry.text then
      local lower=other.text:lower()
      local explanation=lower:find("next",1,true) or lower:find("increas",1,true) or lower:find("each",1,true) or lower:find("cooldown",1,true) or lower:find("removes",1,true)
      if not explanation then
       if lower:find("cost",1,true) or lower:find("ash",1,true) then add(amount(other.text),3)
       else add(balanceNumber(other.text),2) end
      end
     end end
     parent=parent.GetParent and parent:GetParent()
    end
   end
  end
 end
 local value,count=nil,0;for n in pairs(candidates) do value=n;count=count+1 end
 if count==1 then return value end
end
local function saveGeometry()
    if not window or not db then return end
    local p,_,rp,x,y = window:GetPoint()
    db.window = {point=p,relativePoint=rp,x=x,y=y,width=window:GetWidth(),height=window:GetHeight()}
end
local function label(parent,text,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY")
    local delta=(size or 12)-11
    f:SetFont(FONTS[db.fontIndex or 1].path,fontSize()+delta)
    fontWidgets[#fontWidgets+1]={widget=f,delta=delta}
    f:SetTextColor(unpack(color or {0.92,0.90,0.96}))
    f:SetText(text); f:SetJustifyH("LEFT")
    return f
end
local borderFrames={}
local function sizeBorder(frame)
 local scale=frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
 local resolution=GetCVar and GetCVar("gxResolution")
 local screenHeight=(resolution and tonumber(resolution:match("%d+x(%d+)"))) or (GetScreenHeight and GetScreenHeight()) or 768
 local thickness=2*768/(math.max(1,screenHeight)*math.max(.01,scale))
 if frame.ashBorderThickness==thickness then return end
 frame.ashBorderThickness=thickness
 local edges=frame.ashBorders
 edges[1]:SetHeight(thickness);edges[2]:SetHeight(thickness)
 edges[3]:SetWidth(thickness);edges[4]:SetWidth(thickness)
end
local function paint(f,r,g,b)
 -- WHITE8X8 is a solid fill, not a nine-slice edge atlas. Draw each edge
 -- explicitly so fractional dimensions/UI scales cannot drop a slice.
 f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
 f:SetBackdropColor(r,g,b,0.98)
 if not f.ashBorders then
  f.ashBorders={}
  for i=1,4 do
   local edge=f:CreateTexture(nil,"OVERLAY");edge:SetTexture("Interface\\Buttons\\WHITE8X8")
   f.ashBorders[i]=edge
  end
  local e=f.ashBorders
  e[1]:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);e[1]:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
  e[2]:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0);e[2]:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
  e[3]:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);e[3]:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0)
  e[4]:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0);e[4]:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
  local native=f.SetBackdropBorderColor
  f.SetBackdropBorderColor=function(self,red,green,blue,alpha)
   if native then native(self,red,green,blue,alpha) end
   for _,edge in ipairs(self.ashBorders) do edge:SetVertexColor(red,green,blue,alpha or 1) end
  end
  borderFrames[#borderFrames+1]=f
 end
 sizeBorder(f);f:SetBackdropBorderColor(.48,.25,.64,1)
end
local function button(parent,text,w,click)
    local b=CreateFrame("Button",nil,parent); b:SetSize(w,math.max(22,fontSize()+11));styledButtons[#styledButtons+1]=b;b.baseWidth=w; paint(b,0.17,0.08,0.23)
    local t=label(b,text,11); t:SetPoint("CENTER"); b.text=t
    b:SetScript("OnClick",click)
    b:SetScript("OnEnter",function(self) self:SetBackdropColor(0.30,0.13,0.40,1) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropColor(0.17,0.08,0.23,1) end)
    return b
end
local function headerButton(parent,title,key)
    local b=button(parent,title,80,function() setSort(key) end)
    b.title=title; b.key=key;b.isHeader=true
    return b
end
local function positionHeader(h,x,fraction,width)
    h:ClearAllPoints(); h:SetPoint("LEFT",window.header,"LEFT",width*x,0)
    h:SetWidth(width*fraction-2)
    local sort=getSort()
    h.text:SetText(h.title..(sort.key==h.key and (sort.ascending and " ^" or " v") or ""))
end

local function measure(text)
 window.measure:SetText(clean(text))
 if window.measure.GetStringWidth then return window.measure:GetStringWidth() end
 return #clean(text)*fontSize()*.60
end
local function fitButtons()
 for _,frame in ipairs(borderFrames) do sizeBorder(frame) end
 for _,b in ipairs(styledButtons) do
  b:SetHeight(math.max(22,fontSize()+12))
  if not b.isHeader then b:SetWidth(math.max(b.baseWidth or 22,measure(b.text:GetText() or "")+18)) end
 end
end
local function columnLayout(list)
 local headers=db.view=="raids" and window.raidHeaders or window.headers
 local sizes,total={},0
 for j,h in ipairs(headers) do sizes[j]=measure(h.title.." v")+18 end
 sizes[1]=math.max(sizes[1],140)
 for _,item in ipairs(list) do
  local e=item.entry
  local values
  if db.view=="raids" then
   values={e.name,tostring(e.level or "--")}
   for j,col in ipairs(RAID_COLUMNS) do values[j+2]=lockText(e,col.key) end
   values[#RAID_COLUMNS+3]=fmt(e.raidResetCost)
  else values={e.name,tostring(e.level or "--"),fmt(e.ash),fmt(crateCount(e)).."+?",fmt(available(e)).."*",fmt(e.raidResetCost)} end
  for j,text in ipairs(values) do sizes[j]=math.max(sizes[j],measure(text)+18) end
 end
 for _,size in ipairs(sizes) do total=total+size end
 local minWidth=math.ceil(math.max(1080,total+20))
 window:SetMaxResize(math.max(1500,minWidth),850);window:SetMinResize(minWidth,260)
 if window:GetWidth()<minWidth then window:SetWidth(minWidth) end
 local width=window:GetWidth()-20
 local extra=math.max(0,width-total);local positions,fractions={},{};local left=0
 for j,size in ipairs(sizes) do
  local share=j==1 and .40 or .60/(#sizes-1)
  local actual=size+extra*share
  positions[j]=left/width;fractions[j]=actual/width;left=left+actual
 end
 return positions,fractions
end
refresh=function()
 if not window or refreshing then return end
 if not window:IsShown() then renderDirty=true;return end
 renderDirty=false;refreshing=true;nextRaidExpiry=nil
 for _,entry in pairs(db.characters) do if entry.realm==GetRealmName() then
  for _,col in ipairs(RAID_COLUMNS) do local lock=entry.locks and entry.locks[col.key]
   if lock and lock.resetAt and lock.resetAt>time() then nextRaidExpiry=math.min(nextRaidExpiry or lock.resetAt,lock.resetAt) end
  end
 end end
 window.bonusButton.text:SetText(db.bonus and "Crate: 800k (+100%)" or "Crate: 400k")
 fitButtons()
 local barHeight=math.max(28,fontSize()+14);window.titleBar:SetHeight(barHeight)
 local toolbarTop=barHeight+9;window.ashesTab:ClearAllPoints();window.ashesTab:SetPoint("TOPLEFT",10,-toolbarTop)
 local headerTop=toolbarTop+math.max(22,fontSize()+12)+7
 local headerHeight=math.max(22,fontSize()+10)
 window.header:SetHeight(headerHeight);window.header:ClearAllPoints();window.header:SetPoint("TOPLEFT",10,-headerTop);window.header:SetPoint("TOPRIGHT",-10,-headerTop)
 body:ClearAllPoints();body:SetPoint("TOPLEFT",10,-headerTop-headerHeight-3);body:SetPoint("BOTTOMRIGHT",-10,65)
 local list={};local ash,saved,crates,partial=0,0,0,false
 for key,e in pairs(db.characters) do if e.realm==GetRealmName() then
  list[#list+1]={key=key,entry=e};ash=ash+(e.ash or 0);saved=saved+(e.savedAsh or 0);crates=crates+crateCount(e)
  if e.ash==nil or e.savedAsh==nil or not e.bankUpdated then partial=true end
 end end
 local sort=getSort()
 table.sort(list,function(a,b)
  local x,y=value(a.entry,sort.key),value(b.entry,sort.key)
  if x==nil and y~=nil then return false elseif y==nil and x~=nil then return true end
  if x~=y then if sort.ascending then return x<y else return x>y end end
  return a.key<b.key
 end)
 local positions,widths=columnLayout(list)
 local capacity=math.max(1,math.floor(body:GetHeight()/rowHeight()));offset=math.max(0,math.min(offset,math.max(0,#list-capacity)))
 local w=body:GetWidth()
 for i=1,math.max(#rows,capacity) do
  local r=rows[i]
  if not r then
   r=CreateFrame("Frame",nil,body);r:SetHeight(rowHeight()-1);r.fields={}
   for j=1,3+#RAID_COLUMNS do r.fields[j]=label(r,"",11) end
   r:EnableMouse(true);r:SetScript("OnEnter",function(self)
    local e=self.entry;if not e then return end
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(e.name,0.75,0.43,1)
    GameTooltip:AddLine("Ash checked: "..(e.ashUpdated and date("%d %b %H:%M",e.ashUpdated) or "Never"),1,1,1)
    GameTooltip:AddLine("Saved Ash: "..fmt(e.savedAsh).." | checked: "..(e.savedAshUpdated and date("%d %b %H:%M",e.savedAshUpdated) or "Open skill tree"),1,1,1)
    GameTooltip:AddLine("Bank checked: "..(e.bankUpdated and date("%d %b %H:%M",e.bankUpdated) or "Visit bank"),1,1,1)
    GameTooltip:AddLine("Raid reset cost: "..fmt(e.raidResetCost).." ash | "..(e.raidResetCostUpdated and date("%d %b %H:%M",e.raidResetCostUpdated) or "Open raid panel / Clear IDs"),1,1,1)
    GameTooltip:AddLine("Offline values are saved snapshots; * means partial total.",1,1,1);GameTooltip:Show()
   end);r:SetScript("OnLeave",function() GameTooltip:Hide() end);rows[i]=r
  end
  local item=list[i+offset]
  if i<=capacity and item then
   local e=item.entry;r.entry=e;r:ClearAllPoints();r:SetPoint("TOPLEFT",body,"TOPLEFT",0,-(i-1)*rowHeight());r:SetWidth(w);r:SetHeight(rowHeight()-1)
   if item.key==current then paint(r,.23,.095,.32);r:SetBackdropBorderColor(.74,.43,1,1) else paint(r,i%2==0 and .10 or .075,.055,.12) end
   local text={e.name,e.level or "--",fmt(e.ash),fmt(crateCount(e))..(e.bankUpdated and "" or "+?"),fmt(available(e))..((e.ash==nil or e.savedAsh==nil or not e.bankUpdated) and "*" or ""),fmt(e.raidResetCost)}
   if db.view=="raids" then
    text={e.name,e.level or "--"}
    for j,col in ipairs(RAID_COLUMNS) do text[j+2]=lockText(e,col.key) end
    text[#RAID_COLUMNS+3]=fmt(e.raidResetCost)
   end
   for j,f in ipairs(r.fields) do
    if text[j] then f:Show()
    f:ClearAllPoints();f:SetPoint("LEFT",r,"LEFT",w*positions[j]+(j==1 and 6 or 0),0)
    f:SetWidth(w*widths[j]-(j==1 and 10 or 2));f:SetJustifyH(j==1 and "LEFT" or "CENTER");f:SetText(text[j])
    else f:Hide() end
   end;r:Show()
  else r:Hide() end
 end
 for _,h in ipairs(window.headers) do h:Hide() end
 for _,h in ipairs(window.raidHeaders) do h:Hide() end
 local headers=db.view=="raids" and window.raidHeaders or window.headers
 for j,h in ipairs(headers) do positionHeader(h,positions[j],widths[j],window.header:GetWidth());h:Show() end
 window.resetTimer:SetText(resetSummary());updateRate()
 for _,tab in ipairs({window.ashesTab,window.raidsTab}) do local active=tab.view==db.view;tab:SetBackdropBorderColor(active and .85 or .48,active and .57 or .25,active and 1 or .64,1) end
 local totalAvailable=ash+saved+crates*crateValue()
 totalText:SetText("Ash: |cffbb77ff"..fmt(ash).."|r  Saved Ash: |cffbb77ff"..fmt(saved).."|r  Crates: |cff44ff33"..fmt(crates).."|r  Available: |cffbb77ff"..fmt(totalAvailable).."|r  Inf Nodes: |cff44ff33"..fmt(math.floor(totalAvailable/100000000)).."|r"..(partial and "*" or ""))
 status:SetText(db.view=="raids" and "Ready = last check free | -- = unchecked | Recheck = saved timer expired; log in to confirm." or db.message or "Open Ebonhold's ash panel to update. Bank counts require a bank visit.")
 refreshing=false
end
local function displaySignature(e)
 return table.concat({tostring(e.ash),tostring(e.savedAsh),tostring(e.bags),tostring(e.bank),tostring(e.bankUpdated~=nil),tostring(e.level),tostring(e.raidResetCost),tostring(db.message)},"|")
end
scan=function(bank,force)
 if not db then return end
 local e=db.characters[current];local before=displaySignature(e)
 e.level=UnitLevel("player");e.bags=GetItemCount(CRATE,false) or 0;e.cratesUpdated=time()
 if bank then e.bank=math.max(0,(GetItemCount(CRATE,true) or 0)-e.bags);e.bankUpdated=time() end
 local resetCost=readRaidResetCost();if resetCost~=nil then e.raidResetCost=resetCost;e.raidResetCostUpdated=time() end
 local n,message=readAsh();local saved,savedMessage=readSavedAsh();db.message=message.." | "..savedMessage
 observeRate(n,saved);updateRate()
 if saved~=nil then e.savedAsh=saved;e.savedAshUpdated=time() end
 if n~=nil then e.ash=n;e.ashUpdated=time();e.source="Visible ash/skill-tree panel" end
 if force or renderDirty or before~=displaySignature(e) or (window:IsShown() and nextRaidExpiry and time()>=nextRaidExpiry) then refresh() end
 if window:IsShown() then window.resetTimer:SetText(resetSummary()) end
end

applyFonts=function()
 local font=FONTS[db.fontIndex or 1]
 for _,record in ipairs(fontWidgets) do record.widget:SetFont(font.path,math.max(7,fontSize()+record.delta)) end
 for _,b in ipairs(styledButtons) do b:SetHeight(math.max(22,fontSize()+11)) end
 if window.settings then
  window.settings.fontText:SetText("Font: "..font.name)
  window.settings.sizeText:SetText("Font size: "..fontSize())
 end
 if window.header then window.header:SetHeight(math.max(22,fontSize()+10)) end
 refresh()
end
local function buildRate()
 rateFrame=CreateFrame("Frame","AshLedgerRateFrame",UIParent)
 rateFrame:SetSize(430,100);rateFrame:SetFrameStrata("DIALOG");rateFrame:EnableMouse(true);rateFrame:SetMovable(true);rateFrame:SetClampedToScreen(true)
 local g=db.rateWindow or {};rateFrame:SetPoint(g.point or "CENTER",UIParent,g.relativePoint or "CENTER",g.x or 0,g.y or 0);paint(rateFrame,.09,.045,.13)
 rateFrame:RegisterForDrag("LeftButton")
 rateFrame:SetScript("OnDragStart",function(self) self:StartMoving() end)
 rateFrame:SetScript("OnDragStop",function(self)
  self:StopMovingOrSizing();local point,_,relativePoint,x,y=self:GetPoint();db.rateWindow={point=point,relativePoint=relativePoint,x=x,y=y}
 end)
 local title=label(rateFrame,"Current character - net session rate",10,{.75,.43,1});title:SetPoint("TOPLEFT",12,-10)
 rateFrame.value=label(rateFrame,"",17,{1,.83,.25});rateFrame.value:SetPoint("CENTER",rateFrame,"CENTER",0,-9)
 local close=button(rateFrame,"X",24,function() toggleRate(false) end);close:SetPoint("TOPRIGHT",-5,-5)
 rateFrame:SetScript("OnShow",function() updateRate() end)
 if not db.ratePopout then rateFrame:Hide() end
end
toggleRate=function(show)
 if show==nil then show=not db.ratePopout end
 db.ratePopout=show and true or false
 if db.ratePopout then rateFrame:Show();updateRate() else rateFrame:Hide() end
 if window.settings and window.settings.rateToggle then window.settings.rateToggle.text:SetText(db.ratePopout and "Hide Ash/h pop-out" or "Show Ash/h pop-out") end
end
local function buildSettings()
 local panel=CreateFrame("Frame",nil,window);window.settings=panel
 panel:SetSize(540,410);panel:SetPoint("CENTER",window,"CENTER",0,0);panel:SetFrameStrata("DIALOG");panel:SetFrameLevel(window:GetFrameLevel()+20);panel:EnableMouse(true);paint(panel,.09,.045,.13)
 local heading=label(panel,"Ash Ledger Settings",13,{.75,.43,1});heading:SetPoint("TOPLEFT",14,-12)
 local close=button(panel,"X",26,function() panel:Hide() end);close:SetPoint("TOPRIGHT",-8,-8)
 panel.fontText=label(panel,"",12);panel.fontText:SetPoint("TOPLEFT",14,-48)
 for i,font in ipairs(FONTS) do
  local index=i
  local choice=button(panel,font.name,190,function() db.fontIndex=index;applyFonts() end)
  choice:SetPoint("TOPLEFT",14+((i-1)%2)*208,-78-math.floor((i-1)/2)*38)
  panel["font"..i]=choice
 end
 panel.sizeText=label(panel,"",12);panel.sizeText:SetPoint("TOPLEFT",14,-160)
 panel.smaller=button(panel,"-",38,function() db.fontSize=math.max(8,fontSize()-1);applyFonts() end);panel.smaller:SetPoint("TOPLEFT",230,-157)
 panel.larger=button(panel,"+",38,function() db.fontSize=math.min(18,fontSize()+1);applyFonts() end);panel.larger:SetPoint("LEFT",panel.smaller,"RIGHT",12,0)
 local note=label(panel,"Size 8-18. Changes apply immediately and are saved.",10);note:SetPoint("TOPLEFT",14,-205)
 panel.rateToggle=button(panel,db.ratePopout and "Hide Ash/h pop-out" or "Show Ash/h pop-out",220,function() toggleRate() end);panel.rateToggle:SetPoint("TOPLEFT",14,-242)
 panel.rateReset=button(panel,"Reset rate",135,resetRate);panel.rateReset:SetPoint("TOPLEFT",330,-242)
 local rateNote=label(panel,"Net run + saved ash this session. Spending lowers the rate.",10);rateNote:SetPoint("TOPLEFT",14,-292);rateNote:SetWidth(510);rateNote:SetHeight(48)
 panel.defaults=button(panel,"Default fonts",160,function() db.fontIndex=1;db.fontSize=11;applyFonts() end);panel.defaults:SetPoint("BOTTOMLEFT",14,18)
 local done=button(panel,"Done",85,function() panel:Hide() end);done:SetPoint("BOTTOMRIGHT",-14,18)
 panel:Hide()
 panel.fontText:SetText("Font: "..FONTS[db.fontIndex].name);panel.sizeText:SetText("Font size: "..fontSize())
end
local function build()
 window=CreateFrame("Frame","AshLedgerMainFrame",UIParent);window:SetFrameStrata("DIALOG");window:EnableMouse(true);window:SetMovable(true);window:SetResizable(true);window:SetMinResize(1080,260);window:SetMaxResize(1500,850);window:SetClampedToScreen(true)
 local g=db.window or {};window:SetSize(math.max(1080,g.width or 1180),g.height or 350);window:SetPoint(g.point or "CENTER",UIParent,g.relativePoint or "CENTER",g.x or 0,g.y or 0);paint(window,.065,.045,.085)
 local bar=CreateFrame("Frame",nil,window);window.titleBar=bar;bar:SetPoint("TOPLEFT",1,-1);bar:SetPoint("TOPRIGHT",-1,-1);bar:SetHeight(28);paint(bar,.16,.075,.22);bar:EnableMouse(true);bar:RegisterForDrag("LeftButton")
 bar:SetScript("OnDragStart",function() window:StartMoving() end);bar:SetScript("OnDragStop",function() window:StopMovingOrSizing();saveGeometry() end)
 local title=label(bar,"Ash Ledger. Ver 1.0 (beta) - By Éuthanize",13,{.75,.43,1});title:SetPoint("LEFT",9,0)
 local close=button(bar,"X",22,function() window:Hide() end);close:SetPoint("RIGHT",-3,0)
 window.resetTimer=label(bar,"",11,{1,.86,.43});window.resetTimer:SetPoint("RIGHT",close,"LEFT",-12,0)
 window.ashesTab=button(window,"Soul Ash",90,function() db.view="ashes";offset=0;refresh() end);window.ashesTab.view="ashes";window.ashesTab:SetPoint("TOPLEFT",10,-37)
 window.raidsTab=button(window,"Raid Locks",100,function() db.view="raids";offset=0;requestLocks();refresh() end);window.raidsTab.view="raids";window.raidsTab:SetPoint("LEFT",window.ashesTab,"RIGHT",6,0)
 local update=button(window,"Refresh",72,function() requestDiscovery();requestLocks();scan(window.bankOpen,true) end);update:SetPoint("LEFT",window.raidsTab,"RIGHT",6,0)
 window.bonusButton=button(window,"",156,function() db.bonus=not db.bonus;refresh() end);window.bonusButton:SetPoint("LEFT",update,"RIGHT",6,0)
 window.settingsButton=button(window,"Settings",86,function() if window.settings:IsShown() then window.settings:Hide() else window.settings:Show() end end);window.settingsButton:SetPoint("LEFT",window.bonusButton,"RIGHT",6,0)
 window.rateText=label(window,"",11,{1,.83,.25});window.rateText:SetPoint("LEFT",window.settingsButton,"RIGHT",14,0)
 window.measure=label(window,"",11);window.measure:Hide()
 local header=CreateFrame("Frame",nil,window);header:SetPoint("TOPLEFT",10,-67);header:SetPoint("TOPRIGHT",-10,-67);header:SetHeight(22);paint(header,.17,.075,.24);window.header=header
 window.headers={headerButton(header,"Character","name"),headerButton(header,"Level","level"),headerButton(header,"Soul Ash","ash"),headerButton(header,"Crates","crates"),headerButton(header,"Total Available","total"),headerButton(header,"Reset Cost","resetCost")}
 window.raidHeaders={headerButton(header,"Character","name"),headerButton(header,"Level","level")}
 for _,col in ipairs(RAID_COLUMNS) do window.raidHeaders[#window.raidHeaders+1]=headerButton(header,col.title,"raid:"..col.key) end
 window.raidHeaders[#window.raidHeaders+1]=headerButton(header,"Reset Cost","resetCost")
 body=CreateFrame("Frame",nil,window);body:SetPoint("TOPLEFT",10,-92);body:SetPoint("BOTTOMRIGHT",-10,65);body:EnableMouseWheel(true);body:SetScript("OnMouseWheel",function(_,delta) offset=offset-delta*3;refresh() end)
 totalText=label(window,"",11);totalText:SetPoint("BOTTOMLEFT",10,40);totalText:SetPoint("RIGHT",window,"RIGHT",-10,0)
 status=label(window,"",10,{.68,.60,.74});status:SetPoint("BOTTOMLEFT",10,15);status:SetPoint("RIGHT",window,"RIGHT",-20,0);status:SetHeight(22)
 local grip=CreateFrame("Button",nil,window);grip:SetSize(20,20);grip:SetPoint("BOTTOMRIGHT",-1,1);grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
 grip:SetScript("OnMouseDown",function(_,b) if b=="LeftButton" then window:StartSizing("BOTTOMRIGHT") end end);grip:SetScript("OnMouseUp",function() window:StopMovingOrSizing();saveGeometry();refresh() end)
 window:SetScript("OnSizeChanged",function() refresh() end);window:SetScript("OnHide",saveGeometry);window:SetScript("OnShow",function() requestDiscovery();scan(window.bankOpen,true) end)
 buildRate();buildSettings();updateRate()
 tinsert(UISpecialFrames,"AshLedgerMainFrame");window:Hide();refresh()
end
local function buildMinimap()
    if not Minimap then return end
    minimapButton=CreateFrame("Button","AshLedgerMinimapButton",Minimap)
    minimapButton:SetSize(28,28); minimapButton:SetFrameStrata("MEDIUM"); minimapButton:SetFrameLevel(Minimap:GetFrameLevel()+5)
    minimapButton:SetNormalTexture("Interface\\AddOns\\AshLedger\\Textures\\Minimap.tga")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:RegisterForClicks("LeftButtonUp"); minimapButton:RegisterForDrag("LeftButton")
    local function place()
        local angle=math.rad(db.minimapAngle or 225)
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*(Minimap:GetWidth()/2+8),math.sin(angle)*(Minimap:GetHeight()/2+8))
    end
    place()
    minimapButton:SetScript("OnDragStart",function(self)
        self:SetScript("OnUpdate",function()
            local x,y=GetCursorPosition(); local cx,cy=Minimap:GetCenter(); local scale=Minimap:GetEffectiveScale()
            local dx,dy=x/scale-cx,y/scale-cy
            if dx~=0 or dy~=0 then db.minimapAngle=math.deg(math.atan2(dy,dx)); place() end
        end)
    end)
    minimapButton:SetScript("OnDragStop",function(self)
        self:SetScript("OnUpdate",nil); self.draggedUntil=GetTime()+0.2; place()
    end)
    minimapButton:SetScript("OnClick",function(self)
        if self.draggedUntil and GetTime()<self.draggedUntil then return end
        if window:IsShown() then window:Hide() else window:Show() end
    end)
    minimapButton:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT"); GameTooltip:AddLine("AshLedger",0.75,0.45,1)
        GameTooltip:AddLine("Click to open or close. Drag around the minimap.",1,1,1); GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
    if db.minimapHidden then minimapButton:Hide() end
end

local perf={}
local function profile(name,fn,...)
 if not debugprofilestop then return fn(...) end
 local started=debugprofilestop();local result=fn(...);local ms=debugprofilestop()-started
 local record=perf[name] or {count=0,total=0,max=0};perf[name]=record
 record.count=record.count+1;record.total=record.total+ms;record.max=math.max(record.max,ms)
 return result
end
local rawScan,rawRefresh=scan,refresh
scan=function(...) return profile("Source reads",rawScan,...) end
refresh=function(...) return profile("Window updates",rawRefresh,...) end
local events=CreateFrame("Frame");events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,arg)
 if event=="ADDON_LOADED" then
  if arg~=addonName then return end
  AshLedgerDB=AshLedgerDB or {};db=AshLedgerDB;db.characters=db.characters or {};db.version=9;db.fontIndex=tonumber(db.fontIndex) or 1;if not FONTS[db.fontIndex] then db.fontIndex=1 end;db.fontSize=fontSize();db.view=db.view=="raids" and "raids" or "ashes"
  current=GetRealmName().."\031"..UnitName("player");local e=db.characters[current] or {};db.characters[current]=e;e.name=UnitName("player");e.realm=GetRealmName();e.level=UnitLevel("player")
  build();buildMinimap()
  for _,name in ipairs({"PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","UPDATE_INSTANCE_INFO","PLAYER_ENTERING_WORLD","BAG_UPDATE","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED","PLAYER_LEVEL_UP","PLAYER_LOGOUT"}) do events:RegisterEvent(name) end
 elseif not db then return
 elseif event=="PLAYER_REGEN_ENABLED" then scan(window.bankOpen)
 elseif event=="UPDATE_INSTANCE_INFO" then updateLocks();refresh()
 elseif event=="PLAYER_ENTERING_WORLD" then requestDiscovery();requestLocks();scan(window.bankOpen)
 elseif event=="BANKFRAME_OPENED" then window.bankOpen=true;scan(true)
 elseif event=="BANKFRAME_CLOSED" then window.bankOpen=false;scan(false)
 elseif event=="PLAYER_LEVEL_UP" then db.characters[current].level=tonumber(arg) or UnitLevel("player");refresh()
 elseif event=="PLAYER_LOGOUT" then scan(window.bankOpen);saveGeometry()
 elseif event=="BAG_UPDATE" or event=="PLAYERBANKSLOTS_CHANGED" then bagsPending=true
 elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then refresh()
 end
end)
events:SetScript("OnUpdate",function(_,delta)
 if not db then return end
 local wasDiscovering=discovery.active
 discoverStep(delta)
 elapsed=elapsed+delta
 local inCombat=InCombatLockdown and InCombatLockdown()
 if wasDiscovering and not discovery.active then scan(window.bankOpen) end
 if bagsPending and elapsed>=.25 and not inCombat then
  bagsPending=false
  local e=db.characters[current];local bags=GetItemCount(CRATE,false) or 0
  local bank=window.bankOpen and math.max(0,(GetItemCount(CRATE,true) or 0)-bags) or e.bank
  local changed=e.bags~=bags or e.bank~=bank
  e.bags=bags;e.bank=bank;e.cratesUpdated=time()
  if window.bankOpen then e.bankUpdated=time() end
  if changed then refresh() end
 end
 if elapsed>=1 then
  elapsed=0
  if window:IsShown() or (rateFrame and rateFrame:IsShown()) then updateRate() end
  if window:IsShown() and not inCombat then
   if nextRaidExpiry and time()>=nextRaidExpiry then refresh() end
   window.resetTimer:SetText(resetSummary())
  end
 end
end)

SLASH_ASHLEDGER1="/ashledger";SLASH_ASHLEDGER2="/ashes";SLASH_ASHLEDGER3="/ashle"
SlashCmdList.ASHLEDGER=function(msg)
 if not db then return end
 local cmd,arg=msg:match("^(%S*)%s*(.-)%s*$");cmd=cmd:lower()
 if cmd=="" then if window:IsShown() then window:Hide() else window:Show() end
 elseif cmd=="rate" then
  if arg=="reset" then resetRate();say("Ash/hour session reset.") else toggleRate() end
 elseif cmd=="perf" then
  if arg=="reset" then perf={};say("Performance counters reset.")
  elseif not debugprofilestop then say("Client profiling API unavailable.")
  else for _,name in ipairs({"Source reads","Window updates"}) do local record=perf[name];if record then say(string.format("%s: %d calls, average %.3f ms, max %.3f ms",name,record.count,record.total/record.count,record.max)) end end end
 elseif cmd=="resetdebug" then requestDiscovery();local entries=resetEntries();if #entries==0 then say("Open the game raid panel with Clear IDs visible, then /ashle resetdebug.") end;for _,entry in ipairs(entries) do say((entry.name or "<unnamed>").." = "..entry.text) end
 elseif cmd=="settings" then window:Show();window.settings:Show()
 elseif cmd=="raids" then db.view="raids";offset=0;requestLocks();window:Show();refresh()
 elseif cmd=="ashes" then db.view="ashes";offset=0;window:Show();refresh()
 elseif cmd=="refresh" then requestDiscovery();requestLocks();scan(window.bankOpen,true)
 elseif cmd=="bonus" then db.bonus=not db.bonus;refresh()
 elseif cmd=="set" then local n=number(arg);if n then local e=db.characters[current];e.ash=n;rateSession.last.run=n;e.ashUpdated=time();e.source="Manual";refresh() else say("Usage: /ashle set NUMBER") end
 elseif cmd=="savedsource" then if arg=="auto" then db.savedSource=nil elseif _G[arg] and _G[arg].GetText then db.savedSource=arg else say("Specify a named saved-ash field or auto.");return end;scan(window.bankOpen)
 elseif cmd=="source" then if arg=="auto" then db.source=nil elseif _G[arg] and _G[arg].GetText then db.source=arg else say("Specify a named text field from /ashle debug.");return end;scan(window.bankOpen)
 elseif cmd=="debug" then local out={};for _,root in ipairs(ashRoots()) do texts(root,out,0) end;for _,e in ipairs(out) do say((e.name or "<unnamed>").." = "..e.text) end
 elseif cmd=="resetpos" then window:ClearAllPoints();window:SetPoint("CENTER",UIParent,"CENTER",0,0);window:SetSize(1180,350);saveGeometry();window:Show()
 elseif cmd=="minimap" then db.minimapHidden=not db.minimapHidden;if minimapButton then if db.minimapHidden then minimapButton:Hide() else minimapButton:Show() end end
 else say("Ash/crate ledger only. Commands: refresh, bonus, set NUMBER, source FIELD, source auto, debug, minimap, resetpos. Farming is now /rh.") end
end
