addon.name='xonellines'
addon.author='Zarianna (100% Vibe coded)'
addon.version='0.3.7'
addon.desc='Configurable FFXII-inspired zone boundary orbs.'
require('common')
local settings=require('settings')
local imgui=require('imgui')
local automatic=require('zone_data')
local directions=require('zone_directions')
local ground=require('zone_ground')
local actors=require('zg_actors')
for zone,lines in pairs(automatic) do
    for _,line in ipairs(lines) do
        line.direction=(directions[zone] or {})[line.id]
        local hit=(ground[zone] or {})[line.id]
        if hit then line.groundY=hit.y;line.groundSpans=hit.spans end
    end
end
local function normalizeName(value)
    return (value:gsub('_',' '):gsub('%s+',' '):match('^%s*(.-)%s*$'))
end
local zoneList={}
local zoneNames={}
for id in pairs(automatic) do
    local ok,name=pcall(function() return AshitaCore:GetResourceManager():GetString('zones.names',id) end)
    name=ok and type(name)=='string' and normalizeName(name) or ''
    if name=='' then name='Zone '..id end
    zoneNames[id]=name
    zoneList[#zoneList+1]={id=id,name=name}
end
table.sort(zoneList,function(a,b)return a.name<b.name end)
local search={''}
local selectedZone=nil
local geom=require('zg_math')
local renderer
local function clone(value)
    if type(value)~='table' then return value end
    local result=T{}; for k,v in pairs(value) do result[k]=clone(v) end; return result
end
-- Built-in defaults; retain the established settings profile for existing users.
local legacy={enabled=true,auto=true,spacing=0.65,size=0.30,height=0.35,brightness=1,lines={},zoneOffsets={}}
local defaults=T{enabled=legacy.enabled~=false,auto=legacy.auto~=false,range=30,spacing=legacy.spacing or 0.65,
    size=legacy.size or 0.30,height=legacy.height or 0.35,brightness=legacy.brightness or 1,
    opacity=1,orbColor=T{0.08,0.39,1},coreColor=T{0.85,0.97,1},coreSize=0.12,
    coreStrength=0.65,lines=T{},zoneOffsets=T{},migrated=false,
    horizontal=0,zoneHorizontal=T{},occludePlayers=true,occludeNPCs=true}
local s=settings.load(defaults,'v033')
local opened=false
local openFlag={false}
local preview,firstPoint,lastZone=nil,nil,nil
local dirty=false
local status='Ready'
local fault=false
local lastSave=0
local lastError=''
local function say(message) status=tostring(message); print('[xonellines] '..status) end
local function save() settings.save('v033'); dirty=false; lastSave=os.clock() end
local function migrate()
    if s.migrated then return end
    s.lines=clone(legacy.lines or {})
    s.zoneOffsets=clone(legacy.zoneOffsets or {})
    s.spacing=legacy.spacing or 0.65; s.size=legacy.size or 0.30
    s.height=legacy.height or 0.35; s.brightness=legacy.brightness or 1
    s.migrated=true; save()
end
settings.register('v033','xonellines_v033_settings',function(new)
    if new then s=new end
    preview=nil; firstPoint=nil; dirty=false
end)
local function position()
    local mm=AshitaCore:GetMemoryManager(); local zoning=mm:GetPlayer():GetIsZoning()
    if zoning==true or (type(zoning)=='number' and zoning~=0) then return nil end
    local party=mm:GetParty(); local index=party:GetMemberTargetIndex(0); local zone=party:GetMemberZone(0)
    if index==0 or zone==0 then return nil end
    local entity=mm:GetEntity()
    return {x=entity:GetLocalPositionX(index),y=entity:GetLocalPositionZ(index),z=entity:GetLocalPositionY(index),zone=zone}
end
local function makePreview(p)
    preview={zone=p.zone,height=1.2,name='Config preview',
        a={x=p.x-1.5,y=p.y,z=p.z},b={x=p.x+1.5,y=p.y,z=p.z}}
end
local function setOpen(value)
    opened=value; openFlag[1]=value
    if value then local p=position(); if p then makePreview(p) end
    else preview=nil; if dirty then save() end end
end
local function slider(label,key,minimum,maximum,format)
    local val={s[key]}
    if imgui.SliderFloat(label,val,minimum,maximum,format or '%.2f') then s[key]=val[1]; dirty=true end
end
local function checkbox(label,key)
    local val={s[key]}
    if imgui.Checkbox(label,val) then s[key]=val[1]; dirty=true; fault=false; actors.reset() end
end
local function panel(p)
    if not opened then return end
    imgui.SetNextWindowPos({40,40},ImGuiCond_FirstUseEver)
    imgui.SetNextWindowSize({510,620},ImGuiCond_FirstUseEver)
    local visible=imgui.Begin('xonellines v0.3.7 configuration',openFlag,0)
    local ok,err=pcall(function()
    if visible then
        imgui.Text('Inspired by Final Fantasy XII zone line indicators.')
        if imgui.Button('Move preview to my position') and p then makePreview(p) end
        imgui.Text('Nearby preview updates live while this window is open.')
        checkbox('Show zone markers','enabled')
        slider('Visibility range (yalms)','range',5,100,'%.0f')
        slider('Orb spacing','spacing',0.2,3)
        slider('Orb size','size',0.05,1)
        slider('Vertical offset (Global)','height',-3,3)
        if p then
            local total,aligned=0,0
            for _,line in ipairs(automatic[p.zone] or {}) do total=total+1;if line.groundY then aligned=aligned+1 end end
            imgui.Text(string.format('Ground aligned: %d / %d exits (others retain original height)',aligned,total))
        end
        slider('Horizontal offset (Global)','horizontal',-5,5)
        slider('Opacity','opacity',0,1)
        slider('Brightness','brightness',0.1,2)
        imgui.Separator()
        local orb={s.orbColor[1],s.orbColor[2],s.orbColor[3]}
        if imgui.ColorEdit3('Orb color',orb) then s.orbColor=T{orb[1],orb[2],orb[3]}; dirty=true end
        local core={s.coreColor[1],s.coreColor[2],s.coreColor[3]}
        if imgui.ColorEdit3('Center color',core) then s.coreColor=T{core[1],core[2],core[3]}; dirty=true end
        slider('Center radius','coreSize',0,0.5)
        slider('Center amount','coreStrength',0,1)
        imgui.Separator()
        if imgui.CollapsingHeader('Player / NPC occlusion') then
            checkbox('Player occlusion','occludePlayers')
            checkbox('NPC occlusion','occludeNPCs')
            imgui.TextWrapped('Tests estimated actor silhouettes, including your character. Not pixel-perfect; sizes can differ by model. Walls and terrain are ignored. Both options default to on.')
        end
        if imgui.CollapsingHeader('Per-zone offset tuning') then
            if not selectedZone and p then selectedZone=p.zone end
            imgui.InputText('Search zone name or ID',search,128)
            local childVisible=imgui.BeginChild('xonellines_zone_list',{0,140},0,0)
            local childOk,childErr=pcall(function()
            if childVisible then
                for _,zone in ipairs(zoneList) do
                    local label=zone.name..' ('..zone.id..')'
                    if label:lower():find(normalizeName(search[1]):lower(),1,true) then
                        if imgui.Selectable(label,selectedZone==zone.id) then selectedZone=zone.id end
                    end
                end
            end
            end)
            imgui.EndChild()
            if not childOk then error(childErr,0) end
            if selectedZone then
                local key=tostring(selectedZone)
                imgui.Text('Selected zone: '..(zoneNames[selectedZone] or 'Zone')..' ('..key..')')
                local vertical={s.zoneOffsets[key] or 0}
                local horizontal={s.zoneHorizontal[key] or 0}
                if imgui.SliderFloat('Zone vertical adjustment',vertical,-5,5,'%.2f') then s.zoneOffsets[key]=vertical[1];dirty=true end
                if imgui.SliderFloat('Zone horizontal adjustment',horizontal,-5,5,'%.2f') then s.zoneHorizontal[key]=horizontal[1];dirty=true end
            end
            imgui.TextWrapped('These add to the global offsets. Positive horizontal shifts follow each exit toward the playable side, where a direction is available.')
        end
        imgui.Separator()
        imgui.TextWrapped(status)
        if imgui.Button('Save and close') then setOpen(false) end
    end
    end)
    imgui.End()
    if not ok then error(err,0) end
    if not openFlag[1] and opened then setOpen(false) end
end
local function appearance(p)
    local out={}; for k,v in pairs(s) do out[k]=v end
    out.zoneOffset=s.zoneOffsets[tostring(p.zone)] or 0
    out.zoneHorizontal=s.zoneHorizontal[tostring(p.zone)] or 0
    return out
end
local function drawWorld(p)
    if not p then return end
    if lastZone~=p.zone then
        actors.reset()
        firstPoint=nil
        if opened then makePreview(p) else preview=nil end
        lastZone=p.zone
    end
    if fault then return end
    local lines={}
    if s.enabled then
        if s.auto then for _,line in ipairs(automatic[p.zone] or {}) do lines[#lines+1]=line end end
        for _,line in ipairs(s.lines[tostring(p.zone)] or {}) do lines[#lines+1]=line end
    end
    if opened and preview and preview.zone==p.zone then lines[#lines+1]=preview end
    if #lines==0 then return end
    if not renderer then renderer=require('zg_render') end
    local style=appearance(p)
    local count,detail=renderer.draw(lines,p,style,0)
    status=string.format('%d visible orbs | %s',count,detail or '')
end
ashita.events.register('d3d_present','xonellines_v03_present',function()
    local ok,err=pcall(function()
        migrate()
        local p=position()
        if opened and p and not preview then makePreview(p) end
        panel(p)
        drawWorld(p)
        if dirty and os.clock()-lastSave>1 then save() end
    end)
    if not ok then
        fault=true
        if tostring(err)~=lastError then lastError=tostring(err); say('Error: '..lastError..' | /xl on retries') end
    end
end)
ashita.events.register('command','xonellines_v03_command',function(e)
    local args=e.command:args(); local root=(args[1] or ''):lower()
    if root~='/xl' and root~='/xonellines' then return end
    e.blocked=true
    migrate()
    local cmd=(args[2] or 'config'):lower()
    if cmd=='config' then setOpen(not opened); return end
    if cmd=='clear' then setOpen(false); firstPoint=nil; return end
    if cmd=='on' or cmd=='off' then s.enabled=cmd=='on'; fault=false; save(); return end
    if cmd=='auto' then
        if args[3]~='on' and args[3]~='off' then say('/xl '..cmd..' on|off'); return end
        s[cmd]=args[3]=='on'; fault=false; save(); return
    end
    local limits={range={5,100},spacing={0.2,3},size={0.05,1},height={-3,3},horizontal={-5,5},opacity={0,1},brightness={0.1,2},coresize={0,0.5},corestrength={0,1}}
    if limits[cmd] then
        local val=tonumber(args[3]); local bound=limits[cmd]
        if not val or val~=val or val<bound[1] or val>bound[2] then say('Value outside allowed range.'); return end
        local key=cmd=='coresize' and 'coreSize' or (cmd=='corestrength' and 'coreStrength' or cmd)
        s[key]=val; save(); return
    end
    local p=position(); if not p then say('Waiting for player position.'); return end
    local key=tostring(p.zone)
    if cmd=='start' then firstPoint=p; say('First endpoint recorded.')
    elseif cmd=='end' then
        if not firstPoint or firstPoint.zone~=p.zone then say('Use /xl start in this zone first.'); return end
        local length=geom.length(firstPoint,p)
        if length<0.5 or length>100 then say('Endpoints must be 0.5 to 100 yalms apart.'); return end
        local words={}; for i=3,#args do words[#words+1]=args[i] end
        s.lines[key]=s.lines[key] or T{}
        table.insert(s.lines[key],{a=firstPoint,b=p,name=#words>0 and table.concat(words,' ') or 'Exit'})
        firstPoint=nil; save(); say('Manual marker saved.')
    elseif cmd=='remove' then
        local id=tonumber(args[3]); local lines=s.lines[key] or {}
        if id and id%1==0 and lines[id] then table.remove(lines,id); save() else say('Use /xl list for manual marker IDs.') end
    elseif cmd=='list' then
        say('Zone '..key..': '..#(automatic[p.zone] or {})..' automatic boundaries.')
        for i,line in ipairs(s.lines[key] or {}) do print(i..': '..line.name) end
    elseif cmd=='status' then say('v'..addon.version..' | '..status)
    else say('/xl config | auto on/off | range 30 | on/off | list | start | end Name | remove ID') end
end)
ashita.events.register('unload','xonellines_v03_unload',function() if dirty then save() end; if renderer then renderer.release() end end)
ashita.events.register('load','xonellines_v03_load',function() say('v0.3.7 loaded. /xl config opens live appearance controls.') end)
