-- Procedural glow texture: four ImGui vertices per orb, not thousands of circle vertices.
local ffi=require('ffi')
local bit=require('bit')
local C=ffi.C
local M={}
local texture,key
local SIZE=128
function M.release()
    if texture then texture:Release();texture=nil end
    key=nil
end
function M.get(device,s)
    local values={s.coreSize,s.coreStrength,s.brightness,s.opacity}
    for _,c in ipairs(s.orbColor) do values[#values+1]=c end
    for _,c in ipairs(s.coreColor) do values[#values+1]=c end
    local wanted=table.concat(values,':')
    if texture and key==wanted then return tonumber(ffi.cast('uintptr_t',texture)) end
    local hr,new=device:CreateTexture(SIZE,SIZE,1,0,C.D3DFMT_A8R8G8B8,C.D3DPOOL_MANAGED)
    if hr~=0 or new==nil then error('Glow texture creation failed: '..tostring(hr)) end
    local lockHr,lock=new:LockRect(0,nil,0)
    if lockHr~=0 or lock==nil then new:Release();error('Glow texture lock failed: '..tostring(lockHr)) end
    local ok,err=pcall(function()
        local ramp={}
        for i=0,256 do
            local f=i/256
            local a,r,g,b=0,0,0,0
            for layer=32,1,-1 do
                local fraction=layer/32
                if fraction>=f and f<1 then
                    local blend=s.coreSize>0 and math.exp(-((fraction/(s.coreSize+0.04))^2))*s.coreStrength or 0
                    local alpha=math.min(1,(2+34*(1-fraction)^2)*s.brightness*1.6*s.opacity*1.2/255)
                    r=(s.orbColor[1]+(s.coreColor[1]-s.orbColor[1])*blend)*alpha+r*(1-alpha)
                    g=(s.orbColor[2]+(s.coreColor[2]-s.orbColor[2])*blend)*alpha+g*(1-alpha)
                    b=(s.orbColor[3]+(s.coreColor[3]-s.orbColor[3])*blend)*alpha+b*(1-alpha)
                    a=alpha+a*(1-alpha)
                end
            end
            if a>0 then r=r/a;g=g/a;b=b/a end
            local packed=bit.bor(bit.lshift(math.floor(a*255),24),bit.lshift(math.floor(r*255),16),bit.lshift(math.floor(g*255),8),math.floor(b*255))
            -- bit.bor returns signed int32. Convert to a positive uint32 value
            -- before FFI storage: x86 floating-to-unsigned conversion can otherwise
            -- discard texels whose alpha sets the sign bit (the bright centers).
            ramp[i]=packed<0 and packed+4294967296 or packed
        end
        local bytes=ffi.cast('uint8_t*',lock.pBits)
        for y=0,SIZE-1 do
            local row=ffi.cast('uint32_t*',bytes+y*lock.Pitch)
            for x=0,SIZE-1 do
                local dx,dy=(x+0.5-SIZE/2)/(SIZE/2-1),(y+0.5-SIZE/2)/(SIZE/2-1)
                row[x]=ramp[math.min(256,math.floor(math.sqrt(dx*dx+dy*dy)*256))]
            end
        end
    end)
    local unlockHr=new:UnlockRect(0)
    if not ok or unlockHr~=0 then new:Release();error(err or ('Glow texture unlock failed: '..unlockHr)) end
    M.release();texture=new;key=wanted
    return tonumber(ffi.cast('uintptr_t',texture))
end
return M
