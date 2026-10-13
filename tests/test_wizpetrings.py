from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
mock = r'''
frames, bindingOverrides, combat = {}, {}, false
local methods = {}
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:SetAttribute(k,v) assert(not combat, 'protected write during combat'); self.attrs[k] = v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:GetFrameRef(k) return self.refs[k] end
function methods:Show() local changed=not self.shown; self.shown=true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed=self.shown; self.shown=false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetText(v)
 assert(v==nil or type(v)=='string' or type(v)=='number', "bad argument #1 to 'SetText'")
 self.text=v
end
function methods:GetText() return self.text or '' end
function methods:GetFontString()
 if rawget(self,'font') then return self.font end
 assert(self.template and self.template:find('UIPanelButtonTemplate',1,true), 'Button font must come from a client template')
 self.font=rawget(self,'font') or self:CreateFontString(); return self.font
end
function methods:SetFontString(fs) assert(type(fs)=='table'); self.font=fs end
function methods:GetThumbTexture() self.thumb=rawget(self,'thumb') or self:CreateTexture(); return self.thumb end
function methods:SetValue(v) self.value=v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:GetEffectiveScale() return 1 end
function methods:GetMousePosition() return mx,my end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetScale(v) self.scale=v end
function methods:EnableMouse(v) self.mouse=v end
function methods:EnableKeyboard(v) self.keyboard=v end
function methods:SetTexture(v) self.texture=v end
function methods:SetDesaturated(v) self.desaturated=v end
function methods:SetAlpha(v) self.alpha=v end
local mt = { __index=function(_,k)
 if methods[k] then return methods[k] end
 if k:match('^Set') or k:match('^Get') or k:match('^Enable') or k:match('^Register') or k:match('^Clear') or k:match('^Start') or k:match('^Stop') then return function() end end
end }
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({scripts={},events={},attrs={},refs={},shown=true,name=name,template=template},mt)
 frames[#frames+1]=f; if name then _G[name]=f end; return f
end
function methods:CreateTexture() return CreateFrame('Texture') end
function methods:CreateFontString() return CreateFrame('FontString') end
UIParent=CreateFrame('Frame','UIParent'); UIParent.width,UIParent.height=1920,1080
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg) lastMessage=msg end}
SlashCmdList, UISpecialFrames = {}, {}
function InCombatLockdown() return combat end
function UnitClass() return 'Hunter','HUNTER' end
function GetBindingKey() return nil end
function GetBindingAction() return '' end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetTime() return 10 end
mx,my=0.5,0.5
function GetCursorPosition() return mx*1920,my*1080 end
function SecureHandlerSetFrameRef(f,k,v) f.refs[k]=v end
function SecureHandlerWrapScript(f,script,control,pre,post)
 assert(type(pre)=='string', 'Invalid pre-handler body')
 assert(post==nil or type(post)=='string', 'Invalid post-handler body')
 assert(loadstring(pre))
 if post then assert(loadstring(post)) end
 f.wrapped={control=control,pre=pre,post=post}
end
function ClearOverrideBindings(f) bindingOverrides[f.name]=nil end
function SetOverrideBindingClick(f,priority,key,name,button) bindingOverrides[f.name]={key=key,target=name} end
Enum={SpellBookSpellBank={Player=0},SpellBookItemType={FutureSpell=4}}
names={[2641]='Dismiss Pet',[982]='Revive Pet',[883]='Call Bear',[6991]='Feed Pet',[10000]='Future Spell'}
C_Spell={GetSpellName=function(id) return names[id] end,GetSpellTexture=function(id) return 'icon'..id end,
 GetOverrideSpell=function(id) return id end,GetBaseSpell=function(id) return id end}
local book={{spellID=2641,name='Dismiss Pet'},{spellID=982,name='Revive Pet'},
 {spellID=883,name='Call Bear'},{spellID=6991,name='Feed Pet'}, {spellID=10000,name='Future Spell',itemType=4}}
C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,
 GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=5} end,
 GetSpellBookItemInfo=function(slot) return book[slot] end,IsSpellKnown=function(id) return names[id]~=nil end}
local petBar={[1]='PET_ACTION_ATTACK',[2]='PET_ACTION_FOLLOW',[3]='PET_ACTION_MOVE_TO',
 [7]='PET_MODE_ASSIST',[8]='PET_MODE_AGGRESSIVE',[9]='PET_MODE_DEFENSIVE',[10]='PET_MODE_PASSIVE'}
function GetPetActionInfo(slot) return petBar[slot], 'pet-texture', false, slot==10 end
Settings={
 RegisterCanvasLayoutCategory=function(panel,title)
   registeredPanel=panel; registeredTitle=title
   return {GetID=function() return 42 end}
 end,
 RegisterAddOnCategory=function(category) registeredCategory=category end,
 OpenToCategory=function(id) openedCategory=id; registeredPanel:Show() end,
}
'''

def runtime(in_combat=False, preset_id=None, player_class='HUNTER'):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(mock)
    if player_class != 'HUNTER':
        lua.execute(f"function UnitClass() return '{player_class}', '{player_class}' end; PetRingsDB={{petCommandRingKey='R',petCareRingKey='SHIFT-R'}}")
        lua.execute("function GetBindingAction(key) return key=='R' and 'ACTIONBUTTON4' or '' end")
    lua.execute('A={}; combat=' + ('true' if in_combat else 'false'))
    if preset_id:
        lua.execute("PetRingsDB={petCommandRingKey='F9',visualTheme='obsidian',installedVariant='previous'}")
    load = lua.eval('function(source,name) local f,e=loadstring(source,name); assert(f,e); return f end')
    for file in ['Core.lua', 'Preset.lua', 'Themes.lua', 'Actions.lua', 'Rings.lua', 'Options.lua']:
        source = (root / file).read_text()
        if file == 'Preset.lua' and preset_id:
            source = f"local _, A = ...; A.variantID='{preset_id}'; A.defaultTheme='{preset_id}'"
        load(source, file)('WizPetRings', lua.globals().A)
    lua.execute(r'''
    for _,frame in ipairs(frames) do
      if frame.events.PLAYER_LOGIN then eventFrame=frame; break end
    end
    eventFrame.scripts.OnEvent(eventFrame,'PLAYER_LOGIN')
    ''')
    return lua

lua = runtime()
lua.execute(r'''
assert(#A.rings==2)
SlashCmdList.PETRINGS('version'); assert(lastMessage:find('1.0.0',1,true))
assert(WizPetRings==A and SLASH_PETRINGS1=='/wizpetrings' and SLASH_PETRINGS2=='/petrings')
assert(A.state.petCommandRing.known[7]=='Move To')
assert(A.state.petCareRing.known[3]=='Call Bear')
local spellNames=A.Spellbook(); assert(spellNames['Future Spell']==nil)
A.db.petCommandRingKey='CTRL-P'; A.db.petCareRingKey='SHIFT-P'; A.Apply()
assert(bindingOverrides.PetRingsCommandButton.key=='CTRL-P')
assert(bindingOverrides.PetRingsCareButton.key=='SHIFT-P')
local function press(ring,dx,dy)
 self=ring.driver; control=ring.driver.wrapped.control
 local snippet=assert(loadstring(ring.driver.wrapped.pre))
 mx,my=0.5,0.5; down=true
 ring.driver.scripts.PreClick(ring.driver,'LeftButton',true); snippet()
 assert(ring.layer:IsShown() and self.attrs.type==nil)
 mx,my=0.5+dx/1920,0.5+dy/1080; down=false; snippet()
 assert(not ring.layer:IsShown())
end
for ri,ring in ipairs(A.rings) do
 for i=1,ring.n do
  local dx,dy=A.Offset(i,60,ring.n)
  press(ring,dx,dy)
  local attrs=ring.driver.attrs
  assert(attrs.type==attrs['kind'..i])
  local value=attrs['value'..i]
  if attrs.type=='pet' then assert(attrs.action==value)
  elseif attrs.type=='spell' then assert(attrs.spell==value)
  elseif attrs.type=='macro' then assert(attrs.macrotext==value) end
 end
 press(ring,0,0); assert(ring.driver.attrs.type==nil)
end
assert(A.rings[1].driver.attrs.kind4=='pet' and A.rings[1].driver.attrs.value4==9)
assert(A.rings[1].driver.attrs.kind6=='pet' and A.rings[1].driver.attrs.value6==8)
assert(A.rings[1].driver.attrs.kind7=='pet' and A.rings[1].driver.attrs.value7==3)
assert(A.rings[2].driver.attrs.kind3=='spell' and A.rings[2].driver.attrs.value3==883)
-- Settings, persisted layout changes, capture and deferred protected writes.
A.ShowOptions(); assert(openedCategory==nil and registeredPanel==A.settingsPanel)
assert(A.options:IsShown() and #A.options.groups[1].directions==7)
assert(registeredTitle=='WizPetRings' and #A.options.groups[2].directions==4)
assert(PetRingsOptions==A.options and #UISpecialFrames==1)
for _,b in ipairs(A.themeButtons) do
 assert(b.template=='BackdropTemplate' and type(b.text)=='string')
 assert(rawget(b,'font')) -- custom caption is wired before SetText
end
assert(A.options.groups[1].page:IsShown() and not A.options.groups[2].page:IsShown())
local careNav=A.options.groups[2].nav; careNav.scripts.OnClick(careNav)
assert(not A.options.groups[1].page:IsShown() and A.options.groups[2].page:IsShown())
assert(A.db.optionsPage==2 and A.options.groups[2].marker:IsShown())
local cmdNav=A.options.groups[1].nav; cmdNav.scripts.OnClick(cmdNav)
local b=A.options.groups[1].directions[1]; b.scripts.OnClick(b)
assert(A.state.petCommandRing.order[1]=='follow')
local key=A.options.groups[1].key; key.scripts.OnClick(key)
assert(key.keyboard); key.scripts.OnKeyDown(key,'F6')
assert(A.db.petCommandRingKey=='F6' and not key.keyboard)
key.scripts.OnClick(key); key.scripts.OnKeyDown(key,'ESCAPE')
assert(A.db.petCommandRingKey==nil)
key.scripts.OnClick(key); careNav.scripts.OnClick(careNav)
assert(A.capture==nil and not key.keyboard)
A.options.callID:SetText('883'); A.options.callID.scripts.OnEnterPressed()
assert(A.db.petCareCallSpellID==883)
-- Classic is the only appearance, with no remaining theme selector.
local before=A.rings[1].driver.attrs.value4
combat=true
A.ApplyTheme()
assert(A.Theme().name=='Classic' and A.options.styleButtons==nil and A.SetTheme==nil)
assert(A.rings[1].driver.attrs.value4==before and A.rings[1].driver.attrs.kind4=='pet')
combat=false
assert(A.options.parchmentTextures[1]:IsShown())
assert(A.options.parchmentTextures[1].texture:find('Desaturated.png',1,true))
A.options:Hide(); A.ShowOptions()
assert(A.options.groups[2].page:IsShown()) -- remember the selected ring
A.options.callID:SetText('-5'); A.options.callID.scripts.OnEnterPressed()
assert(A.db.petCareCallSpellID==883)
combat=true; A.db.petCommandRingScale=1.5; A.Apply(); assert(A.pending)
combat=false; eventFrame.scripts.OnEvent(eventFrame,'PLAYER_REGEN_ENABLED')
assert(not A.pending and A.rings[1].layer.scale==1.5)
-- A direct slot click cancels a pending key release, preventing a second action.
local ring=A.rings[2]
press(ring,0,60)
ring.driver.attrs.ringX,ring.driver.attrs.ringY=0.5,0.5
self=ring.slots[3]; control=self.wrapped.control
assert(self.wrapped.post==nil and #self.wrapped.pre>0)
assert(loadstring(self.wrapped.pre))()
assert(ring.driver.attrs.ringX==nil)
''')
print('PASS: standalone boot, all slots, Move To, direct stances/summon, key bindings, settings, cancellation and combat deferral')

lua = runtime(in_combat=True)
lua.execute(r'''
assert(#A.rings==0 and A.pending)
combat=false; eventFrame.scripts.OnEvent(eventFrame,'PLAYER_REGEN_ENABLED')
assert(#A.rings==2 and not A.pending)
''')
print('PASS: combat reload defers protected frame creation until combat ends')

for player_class in ['WARRIOR', 'MAGE', 'WARLOCK']:
    alt = runtime(player_class=player_class)
    alt.execute(r'''
    assert(not A.hunter and #A.rings==0)
    A.CreateRings(); A.Apply(); A.RegisterSettings(); A.ShowOptions()
    assert(#A.rings==0 and A.options==nil and A.category==nil)
    assert(PetRingsCommandButton==nil and PetRingsCareButton==nil)
    assert(next(bindingOverrides)==nil and GetBindingAction('R')=='ACTIONBUTTON4')
    assert(PetRingsDB.petCommandRingKey=='R') -- inactive saved values stay untouched
    eventFrame.scripts.OnEvent(eventFrame,'PLAYER_REGEN_ENABLED')
    eventFrame.scripts.OnEvent(eventFrame,'SPELLS_CHANGED')
    assert(next(bindingOverrides)==nil)
    ''')
print('PASS: non-Hunters never create rings, register settings or override keys; Warrior R binding stays unchanged')

for theme in ['obsidian','moonwell','arcane','ironclad','wildwood','classic']:
    preset = runtime(preset_id=theme)
    assert preset.globals().A.db.visualTheme == 'classic'
    assert preset.globals().A.db.petCommandRingKey == 'F9'
assert not list((root / 'Media').glob('Theme*'))
print('PASS: obsolete themes migrate to Classic without resetting keys; unused artwork removed')

for line in (root / 'WizPetRings_Camelot.toc').read_text().splitlines():
    if line and not line.startswith('#'): assert (root / line).is_file(), line
assert (root / 'WizPetRings.toc').read_bytes() == (root / 'WizPetRings_Camelot.toc').read_bytes()
print('PASS: Forever TOCs and addon files verified')
