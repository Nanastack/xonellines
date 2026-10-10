-- Screen-space actor occlusion, independent of terrain depth.
-- Estimated rounded body masks, not pixel-perfect model silhouettes.
local bit=require('bit')
local geom=require('zg_math')
local M={}
local cache,last={},-1
-- Estimated race proportions, not measured model bounds. Mounted values include rider.
local sizes={
 [1]={1.85,.32,2.45,.48},[2]={1.77,.30,2.35,.46},
 [3]={2.10,.34,2.65,.50},[4]={2.00,.32,2.55,.48},
 [5]={1.05,.27,1.95,.40},[6]={1.05,.27,1.95,.40},
 [7]={1.60,.30,2.35,.46},[8]={2.05,.46,2.75,.60},
}
function M.dimensions(race,scale,mounted)
    if not scale or scale<=0 or scale>4 then scale=1 end
    local size=sizes[race] or sizes[1]
    return size[mounted and 3 or 1]*scale,size[mounted and 4 or 2]*scale
end
-- Animation state belongs to each entity, unlike local-player buffs.
function M.isMounted(entities,index,isLocal,localBuff)
    local animation=entities.GetAnimation and entities:GetAnimation(index,0) or nil
    if animation==5 or animation==85 then return true end
    return isLocal and localBuff or false
end
function M.projectActors(player,s,view,projection,vp)
    if not s.occludePlayers and not s.occludeNPCs then return {} end
    local now=os.clock()
    if now-last>0.10 then
        cache={};last=now
        local mm=AshitaCore:GetMemoryManager();local entities=mm:GetEntity()
        local me=mm:GetParty():GetMemberTargetIndex(0)
        local mounted=false
        if s.occludePlayers and mm.GetPlayer then
            local owner=mm:GetPlayer()
            if owner and owner.GetBuffs then
                for _,buff in pairs(owner:GetBuffs() or {}) do
                    if buff==252 then mounted=true;break end
                end
            end
        end
        for i=0,0x8FF do
            local pointer=entities:GetActorPointer(i)
            if pointer and pointer~=0 then
                local flags=entities:GetSpawnFlags(i)
                local pc=bit.band(flags,0x01)~=0 or i==me
                local npc=not pc and bit.band(flags,0x02)~=0 and bit.band(flags,0x10)==0
                if (pc and s.occludePlayers) or (npc and s.occludeNPCs) then
                    local p={x=entities:GetLocalPositionX(i),y=entities:GetLocalPositionZ(i),z=entities:GetLocalPositionY(i)}
                    if geom.length(p,player)<s.range+30 then
                        local scale=entities:GetModelSize(i)
                        if not scale or scale<=0 or scale>4 then scale=1 end
                        local riding=pc and M.isMounted(entities,i,i==me,mounted)
                        local race=pc and entities.GetRace and entities:GetRace(i) or nil
                        local height,width=M.dimensions(race,scale,riding)
                        cache[#cache+1]={point=p,height=height,width=width}
                    end
                end
            end
        end
    end
    local result={}
    for _,actor in ipairs(cache) do
        local feet=geom.project(actor.point,view,projection,vp)
        local top=geom.project({x=actor.point.x,y=actor.point.y-actor.height,z=actor.point.z},view,projection,vp)
        if feet and top then
            local ry=math.max(math.abs(feet.y-top.y)/2,feet.scale*actor.width)
            if ry>1 then result[#result+1]={x=(feet.x+top.x)/2,y=(feet.y+top.y)/2,
                rx=math.max(2,feet.scale*actor.width),ry=ry,depth=(feet.z+top.z)/2,
                cameraDepth=math.min(feet.cameraDepth,top.cameraDepth)-actor.width,
                top=math.min(feet.y,top.y),bottom=math.max(feet.y,top.y)} end
        end
    end
    return result
end
function M.visibility(dot,actors)
    local visibility=1
    for _,actor in ipairs(actors) do
        local behind
        if dot.cameraDepth and actor.cameraDepth then behind=dot.cameraDepth>=actor.cameraDepth
        else behind=dot.z>actor.depth end
        if behind then
            local r
            if actor.top and actor.bottom then
                -- Rounded ends remain inside projected head-to-feet bounds.
                local cap=math.min(actor.rx,(actor.bottom-actor.top)/2)
                local cy=math.max(actor.top+cap,math.min(actor.bottom-cap,dot.y))
                r=math.sqrt(((dot.x-actor.x)/actor.rx)^2+((dot.y-cy)/math.max(.001,math.min(actor.rx,(actor.bottom-actor.top)/2)))^2)
            else
                r=math.sqrt(((dot.x-actor.x)/actor.rx)^2+((dot.y-actor.y)/actor.ry)^2)
            end
            visibility=math.min(visibility,math.max(0,math.min(1,(r-0.85)/0.15)))
        end
    end
    return visibility
end
function M.reset() cache={};last=-1 end
return M
