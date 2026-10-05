-- Procedural texture overlay with optional actor masking; no scene-depth rendering.
local ffi=require('ffi')
local bit=require('bit')
local d3d=require('d3d8')
local geom=require('zg_math')
local candidates=require('zg_candidates')
local actorOcclusion=require('zg_actors')
local imgui=require('imgui')
local glow=require('zg_texture')
local C=ffi.C
local MAX_DOTS=512
local function color(a,r,g,b)
    return bit.bor(bit.lshift(math.floor(math.max(0,math.min(255,a))),24),bit.lshift(r,16),bit.lshift(g,8),b)
end
local M={}
function M.draw(lines,player,s,time)
    local device=d3d.get_device()
    if device==nil then return 0 end
    local hr,view=device:GetTransform(C.D3DTS_VIEW); if hr~=0 then return 0 end
    local hp,projection=device:GetTransform(C.D3DTS_PROJECTION); if hp~=0 then return 0 end
    local hv,vp=device:GetViewport(); if hv~=0 then return 0 end
    local dots=0
    -- Queue depth-off dots with the UI pass instead of immediate device draws.
    -- This avoids relying on the current render target / scene timing at Present.
    local overlay=imgui.GetBackgroundDrawList()
    local actors=actorOcclusion.projectActors(player,s,view,projection,vp)
    local textureId=glow.get(device,s)
    local function overlayDot(p,radius,alpha)
        overlay:AddImage(textureId,{p.x-radius,p.y-radius},{p.x+radius,p.y+radius},
            {0,0},{1,1},color(255*alpha,255,255,255))
    end
    local visible={}
    for _,entry in ipairs(candidates.collect(lines,player,s)) do
        local p=geom.project(entry.point,view,projection,vp)
        if p then
            local radius=math.min(100,s.size*p.scale)
            if p.x+radius>=vp.X and p.x-radius<=vp.X+vp.Width and p.y+radius>=vp.Y and p.y-radius<=vp.Y+vp.Height then
                entry.screen=p; entry.radius=radius; visible[#visible+1]=entry
            end
        end
    end
    local budgetRange=#visible>MAX_DOTS and visible[MAX_DOTS].distance or nil
    for index=1,math.min(MAX_DOTS,#visible) do
        local entry=visible[index]
        local fade=candidates.fade(entry.distance,s.range)
        if budgetRange then
            fade=fade*math.max(0,math.min(1,(budgetRange-entry.distance)/2))
        end
        local proximity=geom.proximity(entry.distance)
        local visibility=actorOcclusion.visibility(entry.screen,actors)
        local p,radius=entry.screen,entry.radius
        overlayDot(p,radius,fade*(1+0.6*proximity)/1.6*visibility)
        dots=dots+1
    end
    return dots,'UI pass: '..dots..' orbs processed'
end
function M.release() glow.release() end
return M
