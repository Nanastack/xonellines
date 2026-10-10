local geom=require('zg_math')
local M={}
local function inOpening(line,t,margin)
    if not line.groundSpans then return true end
    for _,span in ipairs(line.groundSpans) do
        if t>=span[1]+margin and t<=span[2]-margin then return true end
    end
    return false
end
-- Sample the original fixed grid, only inside its intersection with the range
-- sphere. Long boundaries retain their spacing; walking does not slide the dots.
function M.collect(lines,player,s)
    local result={}
    for li,line in ipairs(lines) do
        local override=(s.exitOverrides or {})[line.id] or {}
        if override.enabled~=false then
        local groundY=override.alternative and line.altGroundY or line.groundY
        local vertical=(s.zoneOffset or 0)+(override.vertical or 0)
        local lift=(line.height or 0.35)+(s.height-0.35)+vertical
        local direction=line.direction
        local shift=(s.horizontal or 0)+(s.zoneHorizontal or 0)+(override.horizontal or 0)+(direction and 1.15 or 0)
        local ox=direction and direction.x*shift or 0
        local oz=direction and direction.z*shift or 0
        local a={x=line.a.x+ox,y=groundY and (groundY-s.height-vertical) or (line.a.y-lift),z=line.a.z+oz}
        local b={x=line.b.x+ox,y=groundY and (groundY-s.height-vertical) or (line.b.y-lift),z=line.b.z+oz}
        local length=geom.length(a,b)
        if length>0.001 then
            local dx,dy,dz=(b.x-a.x)/length,(b.y-a.y)/length,(b.z-a.z)/length
            local px,py,pz=player.x-a.x,player.y-a.y,player.z-a.z
            local along=px*dx+py*dy+pz*dz
            local perpendicular=math.max(0,px*px+py*py+pz*pz-along*along)
            local remaining=s.range*s.range-perpendicular
            if remaining>0 then
                local reach=math.sqrt(remaining)
                local steps=math.max(1,math.ceil(length/s.spacing))
                local interval=length/steps
                local first=math.max(0,math.ceil((along-reach)/interval))
                local last=math.min(steps,math.floor((along+reach)/interval))
                for i=first,last do
                    local p={x=a.x+dx*i*interval,y=a.y+dy*i*interval,z=a.z+dz*i*interval}
                    local distance=geom.length(p,player)
                    if distance<s.range and inOpening(line,i/steps,(s.size or 0)/length) then
                        result[#result+1]={point=p,distance=distance,line=li,index=i}
                    end
                end
            end
        end
        end
    end
    table.sort(result,function(a,b)
        if a.distance~=b.distance then return a.distance<b.distance end
        if a.line~=b.line then return a.line<b.line end
        return a.index<b.index
    end)
    return result
end
function M.fade(distance,range)
    local t=math.max(0,math.min(1,(range-distance)/math.min(8,range)))
    return t*t*(3-2*t)
end
return M
