-- World-space scene rendering inspired by SQLCommit/ZoneLines (MIT).
-- Opaque gradients avoid early-pass background rims; shared depth includes actors.
local ffi=require('ffi')
local bit=require('bit')
local C=ffi.C
ffi.cdef[[typedef struct { float x,y,z; uint32_t color; } XLSceneVertex;]]
local vertices=ffi.new('XLSceneVertex[?]',512*32*21)
local M={}
local function check(hr,operation)if hr~=0 then error((operation or 'Scene rendering')..' failed: '..tostring(hr),0) end end
function M.draw(device,entries,view,texture,s,projection,viewport)
    local n=0
    local rx,ry,rz=view._11,view._21,view._31
    local ux,uy,uz=view._12,view._22,view._32
    local rl=math.sqrt(rx*rx+ry*ry+rz*rz);local ul=math.sqrt(ux*ux+uy*uy+uz*uz)
    if rl<.001 or ul<.001 then return end
    rx,ry,rz=rx/rl,ry/rl,rz/rl;ux,uy,uz=ux/ul,uy/ul,uz/ul
    -- ZoneLines-style vertex-colored circles: no translucent texture border.
    local function packed(f)
        local blend=s.coreSize>0 and math.exp(-((f/(s.coreSize+.04))^2))*s.coreStrength or 0
        local rgb={}
        for i=1,3 do rgb[i]=math.floor(math.max(0,math.min(1,
            (s.orbColor[i]+(s.coreColor[i]-s.orbColor[i])*blend)*s.brightness))*255+.5) end
        return 4278190080+rgb[1]*65536+rgb[2]*256+rgb[3]
    end
    local colors={};for ring=0,4 do colors[ring]=packed(ring/4) end
    local function vertex(p,radius,f,angle,color)
        local x,y=math.cos(angle)*radius*f,math.sin(angle)*radius*f
        local v=vertices[n];n=n+1
        v.x=p.x+rx*x+ux*y;v.y=p.y+ry*x+uy*y;v.z=p.z+rz*x+uz*y;v.color=color
    end
    for index,e in ipairs(entries) do
        if index>512 then break end
        local alpha=math.max(0,math.min(1,e.alpha*s.opacity))
        if alpha>.01 then
            -- Early scene alpha cannot reveal later scenery: fade size instead.
            local radius=s.size*math.sqrt(alpha)
            for ring=1,4 do
                local inner,outer=(ring-1)/4,ring/4
                for seg=0,31 do
                    local a,b=seg*math.pi/16,(seg+1)*math.pi/16
                    vertex(e.point,radius,inner,a,colors[ring-1])
                    vertex(e.point,radius,outer,a,colors[ring])
                    vertex(e.point,radius,outer,b,colors[ring])
                    if ring>1 then
                        vertex(e.point,radius,inner,a,colors[ring-1])
                        vertex(e.point,radius,outer,b,colors[ring])
                        vertex(e.point,radius,inner,b,colors[ring-1])
                    end
                end
            end
        end
    end
    if n==0 then return end
    local hr,token=device:CreateStateBlock(C.D3DSBT_ALL);check(hr,'CreateStateBlock')
    if token==nil then error('Could not preserve graphics state') end
    local ok,err=pcall(function()
        local identity=ffi.new('D3DMATRIX');identity._11=1;identity._22=1;identity._33=1;identity._44=1
        check(device:SetTransform(C.D3DTS_WORLD,identity),'SetTransform WORLD')
        check(device:SetTransform(C.D3DTS_VIEW,view),'SetTransform VIEW')
        check(device:SetTransform(C.D3DTS_PROJECTION,projection),'SetTransform PROJECTION')
        -- Preserve the current target viewport; the scene-entry target may differ.
        check(device:SetPixelShader(0),'SetPixelShader');check(device:SetVertexShader(bit.bor(C.D3DFVF_XYZ,C.D3DFVF_DIFFUSE)),'SetVertexShader')
        check(device:SetTexture(0,nil), 'SetTexture')
        for _,pair in ipairs({{C.D3DRS_ZENABLE,1},{C.D3DRS_ZWRITEENABLE,1},{C.D3DRS_ZFUNC,C.D3DCMP_LESSEQUAL},
            {C.D3DRS_ZBIAS,8},{C.D3DRS_LIGHTING,0},{C.D3DRS_FOGENABLE,0},{C.D3DRS_CULLMODE,C.D3DCULL_NONE},
            {C.D3DRS_ALPHABLENDENABLE,0},{C.D3DRS_SRCBLEND,C.D3DBLEND_SRCALPHA},{C.D3DRS_DESTBLEND,C.D3DBLEND_ZERO},{C.D3DRS_BLENDOP,C.D3DBLENDOP_ADD},
            {C.D3DRS_ALPHATESTENABLE,0},{C.D3DRS_ALPHAFUNC,C.D3DCMP_GREATER},{C.D3DRS_ALPHAREF,8},
            {C.D3DRS_STENCILENABLE,0},{C.D3DRS_COLORWRITEENABLE,15},{C.D3DRS_FILLMODE,C.D3DFILL_SOLID}}) do check(device:SetRenderState(pair[1],pair[2]),'SetRenderState '..tonumber(pair[1])) end
        check(device:SetTextureStageState(0,C.D3DTSS_COLOROP,C.D3DTOP_SELECTARG1),'Select vertex color')
        check(device:SetTextureStageState(0,C.D3DTSS_COLORARG1,C.D3DTA_DIFFUSE),'Vertex color source')
        check(device:SetTextureStageState(0,C.D3DTSS_ALPHAOP,C.D3DTOP_SELECTARG1),'Select vertex alpha')
        check(device:SetTextureStageState(0,C.D3DTSS_ALPHAARG1,C.D3DTA_DIFFUSE),'Vertex alpha source')
        check(device:SetTextureStageState(1,C.D3DTSS_COLOROP,C.D3DTOP_DISABLE),'Disable texture stage 1')
        check(device:DrawPrimitiveUP(C.D3DPT_TRIANGLELIST,n/3,vertices,ffi.sizeof('XLSceneVertex')),'DrawPrimitiveUP')
    end)
    local restored=device:ApplyStateBlock(token);device:DeleteStateBlock(token)
    if not ok then error(err) end;check(restored,'ApplyStateBlock')
end
return M
