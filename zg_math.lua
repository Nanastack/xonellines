-- Coordinates in this module are renderer coordinates: x, vertical y, horizontal z.
local M = {}
function M.proximity(distance)
    local t=math.max(0,math.min(1,(15-distance)/12))
    return t*t*(3-2*t)
end
local function transform(x,y,z,w,m)
    return x*m._11+y*m._21+z*m._31+w*m._41,
           x*m._12+y*m._22+z*m._32+w*m._42,
           x*m._13+y*m._23+z*m._33+w*m._43,
           x*m._14+y*m._24+z*m._34+w*m._44
end
function M.project(p,view,projection,vp)
    local x,y,z,w = transform(p.x,p.y,p.z,1,view)
    x,y,z,w = transform(x,y,z,w,projection)
    if w <= 0.01 then return nil end
    local depth = z/w
    if depth < 0 or depth > 1 then return nil end
    return {x=vp.X+(x/w+1)*vp.Width/2, y=vp.Y+(1-y/w)*vp.Height/2,
        z=vp.MinZ+depth*(vp.MaxZ-vp.MinZ), rhw=1/w,
        scale=math.abs(projection._22)*vp.Height/(2*w)}
end
function M.length(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
function M.points(a,b,spacing,height)
    local steps = math.max(1,math.min(160,math.ceil(M.length(a,b)/spacing)))
    local result = {}
    for i=0,steps do
        local t=i/steps
        result[#result+1]={x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t-height,z=a.z+(b.z-a.z)*t}
    end
    return result
end
function M.distance(p,a,b)
    local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z
    local d=dx*dx+dy*dy+dz*dz
    local t=d>0 and math.max(0,math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy+(p.z-a.z)*dz)/d)) or 0
    return M.length(p,{x=a.x+t*dx,y=a.y+t*dy,z=a.z+t*dz})
end
return M
