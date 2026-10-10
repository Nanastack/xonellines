-- Shared glow texture and actor masks for overlay and terrain-depth rendering.
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
local sceneRenderer
local M={}
-- Capture at the known world-scene entry point, before later UI transforms.
function M.captureCamera()
    local device=d3d.get_device()
    if device==nil then return nil end
    local a,view=device:GetTransform(C.D3DTS_VIEW)
    local b,projection=device:GetTransform(C.D3DTS_PROJECTION)
    local c,vp=device:GetViewport()
    if a~=0 or b~=0 or c~=0 then return nil end
    local function matrix(source)
        local out=ffi.new('D3DMATRIX')
        for i=1,4 do for j=1,4 do local k='_'..i..j;out[k]=source[k] end end
        return out
    end
    local viewport=ffi.new('D3DVIEWPORT8')
    for _,k in ipairs({'X','Y','Width','Height','MinZ','MaxZ'})do viewport[k]=vp[k] end
    return {view=matrix(view),projection=matrix(projection),viewport=viewport}
end
function M.draw(lines,player,s,time)
    local device=d3d.get_device()
    if device==nil then return 0 end
    local camera=s.scene and s.camera or M.captureCamera()
    if not camera then return 0,'Camera unavailable' end
    local view,projection,vp=camera.view,camera.projection,camera.viewport
    if s.scene then
        local hr,current=device:GetViewport()
        if hr~=0 then error('GetViewport failed: '..tostring(hr)) end
        vp=current
    end
    local dots=0
    -- Queue depth-off dots with the UI pass instead of immediate device draws.
    -- This avoids relying on the current render target / scene timing at Present.
    local overlay=not s.scene and imgui.GetBackgroundDrawList() or nil
    local actors=actorOcclusion.projectActors(player,s,view,projection,vp)
    local sceneEntries={}
    local textureId=not s.scene and glow.get(device,s) or nil
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
        local alpha=fade*(1+0.6*proximity)/1.6*visibility
        if s.scene then sceneEntries[#sceneEntries+1]={point=entry.point,alpha=alpha}
        else overlayDot(p,radius,alpha) end
        dots=dots+1
    end
    if s.scene then
        sceneRenderer=sceneRenderer or require('zg_scene')
        sceneRenderer.draw(device,sceneEntries,view,textureId,s,projection,vp)
        return dots,string.format('Early terrain draw: %d candidates, viewport %dx%d',dots,vp.Width,vp.Height)
    end
    return dots,'Soft glow overlay'
end
function M.release() glow.release() end
return M
