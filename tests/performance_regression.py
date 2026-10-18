"""Run with Python + lupa (Lua 5.1); no game files or saved variables are changed."""
from pathlib import Path
import math
import subprocess
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
OLD = subprocess.check_output(
    ["git", "show", "backup/pre-performance-2026-10-17:zPie.lua"], cwd=ROOT, text=True
)
NEW = (ROOT / "zPie.lua").read_text()

MOCK = r'''
calls={}; scale=1; mx=0; my=0; now=0; shift=false; alt=true; ctrl=true; mouse=true
function frame()
 local f={shown=true,scripts={}}
 setmetatable(f,{__index=function(t,k)
  if k=='CreateTexture' or k=='CreateFontString' then return function() calls.created=(calls.created or 0)+1; return frame() end end
  if string.find(k,'^[A-Z]') then return function(self,...) calls[k]=(calls[k] or 0)+1 end end
 end})
 function f:Hide() self.shown=false end
 function f:Show() self.shown=true end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:SetPoint(...) self.point={...}; calls.points=(calls.points or 0)+1 end
 function f:SetTexCoord(...) self.coords={...}; calls.coords=(calls.coords or 0)+1 end
 function f:GetEffectiveScale() return scale end
 function f:SetTexture(v) self.texture=v; calls.textures=(calls.textures or 0)+1 end
 return f
end
UIParent=frame()
function CreateFrame() return frame() end
function setglobal(k,v) _G[k]=v end
function GetTime() return now end
function GetCursorPosition() return mx,my end
function GetScreenWidth() return 1000 end
function GetScreenHeight() return 800 end
function IsShiftKeyDown() return shift end
function IsAltKeyDown() return alt end
function IsControlKeyDown() return ctrl end
function IsMouseButtonDown() return mouse end
function IsSkillActive() return false end
function GetContainerItemLink() return 'item:1' end
function UseContainerItem() used=(used or 0)+1 end
math.atan2=function(y,x) calls.atan=(calls.atan or 0)+1; return math.atan2_original(y,x) end
'''

def section(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]

def setup(source):
    lua = LuaRuntime()
    lua.execute('math.atan2_original=math.atan2')
    lua.execute(MOCK)
    lua.execute(source[:source.index('function zPie:MigrateLegacyBindings')])
    lua.execute(section(source, 'local function SetRotatedTexCoords', 'function zPie:ShowSelectionTooltip').replace('local function SetRotatedTexCoords', 'function SetRotatedTexCoords', 1))
    lua.execute(section(source, 'function zPie:UseItem(', 'function zPie:TargetRaidMarker'))
    lua.execute(section(source, 'function zPie:OpenRing(', 'function zPie:IsItemAvailable'))
    lua.execute(section(source, 'function zPie:CloseRing()', 'zPie:RegisterEvent("PLAYER_LOGIN")'))
    lua.execute(r'''
zPie.selectionTooltip=false
zPie:InitButtons(1,0)
zPie.rings={}
for r=1,12 do
 zPie.rings[r]={}
 for i=1,8 do
  local b=frame(); b.hl=frame(); b.activeTex=frame(); b.arrow=frame(); b.border=frame()
  b.icon=frame(); b.cd=frame(); b.count=frame(); b.equippedOutline={}
  zPie.rings[r][i]=b
 end
end
function zPie:GetRingBinding() return binding end
function zPie:GetBindingKeyCode() return nil end
function zPie:GetIcon() return 'icon' end
function zPie:SetIconTexture() end
function zPie:IsItemEquipped() return false end
function zPie:GetActionData() return '',0,0,0 end
function zPie:IsEquippableItemLink() return false end
function zPie:ShowSelectionTooltip() end
function zPie:ExecuteAction(item) self:UseItem(item,'BAG',0,1) end
zPieDB={arrowBehavior='SMOOTH',arrowStyle='Interface\\Minimap\\MinimapArrow'}
for i=1,12 do zPieDB[i]={radius=75,anchor='MOUSE',items={{name='Potion'}},tapBehavior='FIRST'} end
function tick() zPie.updateDriver.scripts.OnUpdate() end
''')
    return lua


old, new = setup(OLD), setup(NEW)
for filename in ('zPie.lua', 'options.lua'):
    new.execute('assert(loadstring(...))', (ROOT / filename).read_text())
assert section(OLD, 'function zPie:MigrateLegacyBindings', 'local function SetRotatedTexCoords') == section(NEW, 'function zPie:MigrateLegacyBindings', 'local function SetRotatedTexCoords')
assert section(OLD, 'function zPie:TargetRaidMarker', 'function zPie:OpenRing') == section(NEW, 'function zPie:TargetRaidMarker', 'function zPie:OpenRing')
old_created, new_created = old.globals().calls.created, new.globals().calls.created
styles = list(new.globals().zPie.arrowOffsets.keys())
for style in styles:
    for radius, scale, anchor in [(75, 1, 'MOUSE'), (130, .64, 'CENTER'), (40, 1.5, 'MOUSE')]:
        for lua in (old, new):
            lua.globals().style = style
            lua.globals().radius, lua.globals().scale, lua.globals().anchor = radius, scale, anchor
            lua.execute("zPieDB.arrowStyle=style; zPieDB[1].radius=radius; zPieDB[1].anchor=anchor; mx=317; my=429; zPie:OpenRing(1)")
        for deg in range(1, 361):
            radians = math.radians(deg)
            for lua in (old, new):
                g = lua.globals()
                g.mx = (g.zPie.centerX + 100 * math.cos(radians)) * scale
                g.my = (g.zPie.centerY + 100 * math.sin(radians)) * scale
                lua.execute('tick()')
            assert old.globals().zPie.activeDegree == new.globals().zPie.activeDegree == deg
            a = old.globals().zPie.compassFrame.arrows[deg]
            b = new.globals().zPie.compassFrame.arrow
            assert a.texture == b.texture and a.shown == b.shown
            for key in ('point', 'coords'):
                av, bv = getattr(a, key), getattr(b, key)
                for i in ([4, 5] if key == 'point' else range(1, 9)):
                    assert abs(av[i] - bv[i]) < 1e-12, (style, deg, key, i)
            assert old.globals().zPie.hoveredSlice == new.globals().zPie.hoveredSlice

# Old and new must select the same slices at rounding boundaries and in every mode.
for mode in ('SMOOTH', 'SNAP', 'NONE'):
    for lua in (old, new):
        lua.globals().mode = mode
        lua.execute("zPieDB.arrowBehavior=mode; zPieDB.arrowStyle=mode=='NONE' and 'NONE' or style; zPieDB[1].items={{name='A'},{name='B'},{name='C'}}; zPie:OpenRing(1)")
    for degrees in (-179.51, -.51, -.5, -.49, 0, .49, .5, .51, 179.5, 359.5):
        for lua in (old, new):
            g=lua.globals()
            g.mx=(g.zPie.centerX+100*math.cos(math.radians(degrees)))*g.scale
            g.my=(g.zPie.centerY+100*math.sin(math.radians(degrees)))*g.scale
            lua.execute('tick()')
        assert old.globals().zPie.hoveredSlice == new.globals().zPie.hoveredSlice
        assert old.globals().zPie.activeDegree == new.globals().zPie.activeDegree
    for lua in (old,new):
        lua.execute('mx=zPie.centerX*scale; my=zPie.centerY*scale; tick(); assert(zPie.hoveredSlice==nil and zPie.activeDegree==nil)')

new.execute(r'''
zPie:HideAll(); assert(not zPie.updateDriver.shown)
-- Stock bag fallback queues AFTER HideAll in CloseRing; releasing Shift executes once.
zPieDB[1].items={{name='Potion'}}; shift=true; used=0
zPie:OpenRing(1); assert(zPie.updateDriver.shown)
zPie:CloseRing(); assert(zPie.pendingItem and zPie.updateDriver.shown)
tick(); assert(used==0 and zPie.updateDriver.shown)
shift=false; tick(); assert(used==1 and not zPie.pendingItem and not zPie.updateDriver.shown)
tick(); assert(used==1)
-- Pending work also survives opening/switching rings and closing an empty ring.
shift=true; zPie:UseItem({name='Potion'},'BAG',0,1)
zPie:OpenRing(1); zPie:OpenRing(2); assert(zPie.currentRing==2 and zPie.updateDriver.shown)
zPie:HideAll(); zPieDB[3].items={}; zPie:OpenRing(3)
assert(zPie.currentRing==nil and zPie.pendingItem and zPie.updateDriver.shown)
shift=false; tick(); assert(used==2 and not zPie.updateDriver.shown)
-- Modifier and mouse release all use the same CloseRing ordering.
for _,key in ipairs({'ALT-X','CTRL-X','SHIFT-X','BUTTON4'}) do
 binding=key; alt=true; ctrl=true; shift=true; mouse=true
 zPie:OpenRing(1); now=now+1
 alt=false; ctrl=false; shift=false; mouse=false
 tick(); assert(zPie.currentRing==nil and not zPie.updateDriver.shown)
end
binding=nil; zPieDB.arrowBehavior='SMOOTH'; zPieDB.arrowStyle=style
zPie:OpenRing(1); mx=(zPie.centerX+100)*scale; my=zPie.centerY*scale
calls={}; tick(); tick()
assert(calls.atan==2 and calls.points==1 and calls.coords==1)
''')

new.execute("zPie:HideAll(); for i=1,12 do zPieDB[i].items={{name='Potion'}} end")
for binding in ET.parse(ROOT / 'Bindings.xml').getroot():
    for state in ('down', 'up'):
        new.globals().keystate = state
        new.execute(binding.text)
        assert new.globals().zPie.updateDriver.shown == (state == 'down')

# The extended KEY_DOWN/KEY_UP handlers themselves are unchanged by this patch.
assert OLD[OLD.index('    elseif event == "KEY_DOWN"'): ] == NEW[NEW.index('    elseif event == "KEY_DOWN"'): ]
new.execute('''
binding=nil; shift=true; zPie:UseItem({name='Potion'},'BAG',0,1)
zPie:OpenRing(11); shift=false; tick()
assert(zPie.pendingItem==nil and zPie.currentRing==11 and zPie.updateDriver.shown)
now=now+1; zPie:CloseRing(); assert(not zPie.updateDriver.shown)
''')

for lua in (old,new):
    lua.execute("zPie:HideAll(); calls={}; zPieDB[1].items={{name='A'},{name='B'},{name='C'}}; zPieDB.arrowBehavior='SMOOTH'; zPieDB.arrowStyle=style; zPie:OpenRing(1)")
print('PASS: 4 styles x 3 geometry/scale cases x 360 directions; rounding boundaries; SMOOTH/SNAP/NONE; deadzone; lifecycle and pending-item regression checks.')
print('Init texture/font objects (old/new): %s/%s (359 fewer compass textures)' % (old_created,new_created))
print('Compass preparation calls per SMOOTH open (old/new): points %s/%s, rotations %s/%s, textures %s/%s' % (
    old.globals().calls.points or 0,new.globals().calls.points or 0,
    old.globals().calls.coords or 0,new.globals().calls.coords or 0,
    old.globals().calls.textures or 0,new.globals().calls.textures or 0))
