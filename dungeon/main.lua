local wallImg, gunImg, enemyImg, bulletImg, ammoImg
local map = {}
local enemies = {}
local bullets = {}
local pickups = {}
local tileSize = 64
local isEditMode = false
local editBrush = 1
local mapWidth, mapHeight = 50, 50

-- Added gunKick for the vibration effect
local player = { 
    x = 300, y = 300, angle = 0, speed = 150, 
    ammo = 10, muzzleFlash = 0, gunKick = 0 
}

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    wallImg = love.graphics.newImage("wall.png")
    gunImg = love.graphics.newImage("gun.png")
    enemyImg = love.graphics.newImage("enemy.png")
    bulletImg = love.graphics.newImage("bullet.png")
    ammoImg = love.graphics.newImage("ammo.png")
    
    for y = 1, mapHeight do
        map[y] = {}
        for x = 1, mapWidth do
            if x == 1 or x == mapWidth or y == 1 or y == mapHeight then 
                map[y][x] = 1 
            else 
                map[y][x] = 0 
            end
        end
    end
end

function shoot()
    if player.ammo > 0 then
        player.ammo = player.ammo - 1
        player.muzzleFlash = 0.1
        player.gunKick = 0.5 -- Set vibration duration to 0.5 seconds
        
        table.insert(bullets, {
            x = player.x,
            y = player.y,
            angle = player.angle,
            speed = 800,
            life = 0
        })
    end
end

function love.update(dt)
    if player.muzzleFlash > 0 then player.muzzleFlash = player.muzzleFlash - dt end
    
    -- Update gun vibration timer
    if player.gunKick > 0 then player.gunKick = player.gunKick - dt end

    if isEditMode then
        local camX, camY = player.x - love.graphics.getWidth()/2, player.y - love.graphics.getHeight()/2
        local mx, my = love.mouse.getPosition()
        local gx = math.floor((mx + camX)/tileSize)+1
        local gy = math.floor((my + camY)/tileSize)+1
        
        if love.mouse.isDown(1) then
            if map[gy] and map[gy][gx] then
                if editBrush == 1 then map[gy][gx] = 1
                elseif editBrush == 2 then
                    local exists = false
                    for _, e in ipairs(enemies) do if e.gx == gx and e.gy == gy then exists = true end end
                    if not exists then table.insert(enemies, {gx = gx, gy = gy, x = (gx-0.5)*tileSize, y = (gy-0.5)*tileSize}) end
                end
            end
        elseif love.mouse.isDown(2) then
            if map[gy] and map[gy][gx] then
                map[gy][gx] = 0
                for i = #enemies, 1, -1 do
                    if enemies[i].gx == gx and enemies[i].gy == gy then table.remove(enemies, i) end
                end
            end
        end
        -- Edit mode movement
        if love.keyboard.isDown("up") then player.y = player.y - 300 * dt end
        if love.keyboard.isDown("down") then player.y = player.y + 300 * dt end
        if love.keyboard.isDown("left") then player.x = player.x - 300 * dt end
        if love.keyboard.isDown("right") then player.x = player.x + 300 * dt end
    else
        -- Gameplay Movement
        local cosA, sinA = math.cos(player.angle), math.sin(player.angle)
        local nextX, nextY = player.x, player.y
        if love.keyboard.isDown("w") then nextX = player.x + cosA * player.speed * dt; nextY = player.y + sinA * player.speed * dt end
        if love.keyboard.isDown("s") then nextX = player.x - cosA * player.speed * dt; nextY = player.y - sinA * player.speed * dt end
        
        local gx, gy = math.floor(nextX/tileSize)+1, math.floor(nextY/tileSize)+1
        if map[gy] and map[gy][gx] == 0 then player.x, player.y = nextX, nextY end
        if love.keyboard.isDown("a") then player.angle = player.angle - 3 * dt end
        if love.keyboard.isDown("d") then player.angle = player.angle + 3 * dt end

        -- Bullets
        for i = #bullets, 1, -1 do
            local b = bullets[i]
            b.life = b.life + dt
            local steps = 10
            local stepX = (math.cos(b.angle) * b.speed * dt) / steps
            local stepY = (math.sin(b.angle) * b.speed * dt) / steps
            local removed = false

            for s = 1, steps do
                b.x = b.x + stepX
                b.y = b.y + stepY
                local bgx, bgy = math.floor(b.x/tileSize)+1, math.floor(b.y/tileSize)+1
                if map[bgy] and map[bgy][bgx] == 1 then table.remove(bullets, i); removed = true; break end
                for j = #enemies, 1, -1 do
                    local e = enemies[j]
                    if math.sqrt((b.x - e.x)^2 + (b.y - e.y)^2) < 30 then
                        table.insert(pickups, {x = e.x, y = e.y, timer = 0})
                        table.remove(enemies, j); table.remove(bullets, i); removed = true; break
                    end
                end
                if removed then break end
            end
        end

        -- Pickups
        for i = #pickups, 1, -1 do
            local p = pickups[i]
            p.timer = p.timer + dt
            if math.sqrt((player.x - p.x)^2 + (player.y - p.y)^2) < 40 then
                player.ammo = player.ammo + math.random(1, 4)
                table.remove(pickups, i)
            end
        end
    end
end

function love.draw()
    if isEditMode then
        draw2DEditor()
    else
        draw3DView()
        drawMuzzleFlash()
        drawGunHUD()
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("AMMO: " .. player.ammo, 30, 60, 0, 2, 2)
    end
end

function drawMuzzleFlash()
    if player.muzzleFlash > 0 then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        love.graphics.setColor(1, 0.8, 0.2, 0.7)
        love.graphics.circle("fill", sw/2, sh/2 + 30, math.random(40, 60))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", sw/2, sh/2 + 30, math.random(15, 25))
    end
end

function draw3DView()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.1, 0.1, 0.1); love.graphics.rectangle("fill", 0, 0, sw, sh/2)
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.rectangle("fill", 0, sh/2, sw, sh/2)
    
    local zBuffer = {}
    local res, fov = 2, math.pi / 3
    
    for i = 0, sw - 1, res do
        local rayA = (player.angle - fov/2) + (i / sw) * fov
        local rx, ry, dist = player.x, player.y, 0
        while dist < 1200 do
            rx, ry, dist = rx + math.cos(rayA)*5, ry + math.sin(rayA)*5, dist + 5
            local gx, gy = math.floor(rx/tileSize)+1, math.floor(ry/tileSize)+1
            if map[gy] and map[gy][gx] == 1 then
                local corrected = dist * math.cos(rayA - player.angle)
                zBuffer[i] = corrected
                local h = (tileSize * sh) / corrected
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(wallImg, i, (sh-h)/2, 0, res/wallImg:getWidth(), h/wallImg:getHeight())
                break
            end
        end
        if not zBuffer[i] then zBuffer[i] = 2000 end
        for j = 1, res-1 do zBuffer[i+j] = zBuffer[i] end
    end

    local items = {}
    for _, e in ipairs(enemies) do table.insert(items, {x=e.x, y=e.y, img=enemyImg, type="sprite"}) end
    for _, p in ipairs(pickups) do table.insert(items, {x=p.x, y=p.y, img=ammoImg, type="ammo", t=p.timer}) end
    for _, b in ipairs(bullets) do table.insert(items, {x=b.x, y=b.y, type="bullet", life=b.life}) end

    table.sort(items, function(a,b) return (a.x-player.x)^2+(a.y-player.y)^2 > (b.x-player.x)^2+(b.y-player.y)^2 end)

    for _, s in ipairs(items) do
        local dx, dy = s.x - player.x, s.y - player.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local angle = math.atan2(dy, dx) - player.angle
        while angle > math.pi do angle = angle - 2*math.pi end
        while angle < -math.pi do angle = angle + 2*math.pi end

        if math.abs(angle) < fov/2 + 0.2 and dist > 2 then
            local sx = (angle / (fov/2) * 0.5 + 0.5) * sw
            local h = (tileSize * sh) / (dist * math.cos(angle))
            local ix = math.floor(sx)

            if ix >= 0 and ix < sw and dist < zBuffer[ix] then
                if s.type == "bullet" then
                    if s.life < 1.0 then
                        love.graphics.setColor(1, 1, 0)
                        love.graphics.rectangle("fill", sx-2, sh/2-2, 4, 4)
                    end
                elseif s.type == "ammo" then
                    -- AMMO ROTATION: math.cos on the horizontal scale simulates spinning
                    local rotationScale = math.cos(s.t * 4) 
                    local bob = math.sin(s.t * 5) * 20 * (64 / dist)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(s.img, sx, sh/2 + bob, 0, (h / s.img:getHeight()) * rotationScale, h / s.img:getHeight(), s.img:getWidth()/2)
                else
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(s.img, sx, (sh-h)/2, 0, h/s.img:getHeight(), h/s.img:getHeight(), s.img:getWidth()/2)
                end
            end
        end
    end
end

function drawGunHUD()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local offsetX, offsetY = 0, 0
    
    -- GUN SHAKE: Apply random offsets if gunKick is active
    if player.gunKick > 0 then
        offsetX = math.random(-10, 10) * (player.gunKick * 2)
        offsetY = math.random(-10, 10) * (player.gunKick * 2)
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gunImg, (sw*0.7) + offsetX, sh + offsetY, 0, 7, 7, gunImg:getWidth()/2, gunImg:getHeight())
end

function draw2DEditor()
    love.graphics.push()
    love.graphics.translate(love.graphics.getWidth()/2 - player.x, love.graphics.getHeight()/2 - player.y)
    for y=1, mapHeight do
        for x=1, mapWidth do
            if map[y][x] == 1 then 
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.rectangle("line", (x-1)*tileSize, (y-1)*tileSize, tileSize, tileSize) 
            end
        end
    end
    for _, e in ipairs(enemies) do love.graphics.setColor(1,1,1); love.graphics.circle("fill", e.x, e.y, 10) end
    love.graphics.setColor(1,0,0); love.graphics.circle("fill", player.x, player.y, 5)
    love.graphics.pop()
end

function love.mousepressed(x, y, button) if not isEditMode and button == 1 then shoot() end end
function love.keypressed(k) 
    if k == "tab" then isEditMode = not isEditMode end
    if k == "1" then editBrush = 1 end
    if k == "2" then editBrush = 2 end
end
