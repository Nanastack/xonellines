-- Screen-space actor occlusion, independent of terrain depth.
-- Estimated upright ellipses, not pixel-perfect model silhouettes.
local bit=require('bit')
local geom=require('zg_math')
local M={}
local cache,last={},-1
function M.projectActors(player,s,view,projection,vp)
    if not s.occludePlayers and not s.occludeNPCs then return {} end
    local now=os.clock()
    if now-last>0.10 then
        cache={};last=now
        local mm=AshitaCore:GetMemoryManager();local entities=mm:GetEntity()
        local me=mm:GetParty():GetMemberTargetIndex(0)
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
                        cache[#cache+1]={point=p,height=1.7*scale,width=0.32*scale}
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
                rx=math.max(2,feet.scale*actor.width),ry=ry,depth=(feet.z+top.z)/2} end
        end
    end
    return result
end
function M.visibility(dot,actors)
    local visibility=1
    for _,actor in ipairs(actors) do
        if dot.z>actor.depth+0.00001 then
            local r=math.sqrt(((dot.x-actor.x)/actor.rx)^2+((dot.y-actor.y)/actor.ry)^2)
            visibility=math.min(visibility,math.max(0,math.min(1,(r-0.85)/0.15)))
        end
    end
    return visibility
end
function M.reset() cache={};last=-1 end
return M
