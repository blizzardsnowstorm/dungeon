local map = {}
local enemies = {}
local bullets = {}
local pickups = {}
local trophy = nil 
local doors = {} 
local tileSize = 64
local isEditMode = false
local editBrush = 1 -- 1: Wall, 2: Enemy, 3: Trophy, 4: Door
local mapWidth, mapHeight = 50, 50
local detectionRange = 400

-- Game State
local hasWon = false
local winTimer = 0

-- UI Feedback
local messageText = ""
local messageTimer = 0

local player = { 
    x = 300, y = 300, angle = 0, speed = 150, 
    ammo = 10, muzzleFlash = 0, gunKick = 0,
    hp = 100 
}

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Assets
    wallImg = love.graphics.newImage("wall.png")
    gunImg = love.graphics.newImage("gun.png")
    enemyImg = love.graphics.newImage("enemy.png")
    enemy2Img = love.graphics.newImage("enemy2.png")
    bulletImg = love.graphics.newImage("bullet.png")
    ammoImg = love.graphics.newImage("ammo.png")
    enemyFireImg = love.graphics.newImage("enemyfire.png")
    enemyFire1Img = love.graphics.newImage("enemyfire1.png")
    trophyImg = love.graphics.newImage("trophy.png")
    winImg = love.graphics.newImage("win.png")
    doorImg = love.graphics.newImage("door.png") 
    
    resetMap()
end

function resetMap()
    hasWon = false
    winTimer = 0
    player.hp = 100
    player.ammo = 10
    player.x = 300
    player.y = 300
    player.angle = 0
    enemies = {}
    bullets = {}
    pickups = {}
    doors = {}
    trophy = nil 
    for y = 1, mapHeight do
        map[y] = {}
        for x = 1, mapWidth do
            map[y][x] = (x == 1 or x == mapWidth or y == 1 or y == mapHeight) and 1 or 0
        end
    end
end

function saveLevel()
    local data = "return {\n"
    -- Added playerAngle here
    data = data .. string.format("  playerX = %d, playerY = %d, playerAngle = %.2f,\n", player.x, player.y, player.angle)
    
    if trophy then
        data = data .. string.format("  trophy = {gx = %d, gy = %d},\n", trophy.gx, trophy.gy)
    end
    data = data .. "  map = {\n"
    for y = 1, #map do
        data = data .. "    {" .. table.concat(map[y], ", ") .. "},\n"
    end
    data = data .. "  },\n"
    data = data .. "  enemies = {\n"
    for _, e in ipairs(enemies) do
        data = data .. string.format("    {gx = %d, gy = %d, x = %d, y = %d, type = %d},\n", e.gx, e.gy, e.x, e.y, e.type)
    end
    data = data .. "  }\n}"

    local success, message = love.filesystem.write("level1.lua", data)
    if success then
        messageText = "LEVEL SAVED"
        messageTimer = 3
    else
        messageText = "SAVE FAILED: " .. message
        messageTimer = 3
    end
end

function loadLevel()
    if love.filesystem.getInfo("level1.lua") then
        local chunk = love.filesystem.load("level1.lua")
        local data = chunk()
        player.x = data.playerX or 300
        player.y = data.playerY or 300
        -- Load the angle, defaulting to 0 if it's an old save file
        player.angle = data.playerAngle or 0
        
        map = data.map
        
        doors = {}
        for y = 1, #map do
            for x = 1, #map[y] do
                if map[y][x] == 4 then
                    table.insert(doors, {gx = x, gy = y, offset = 0, state = "closed", timer = 0})
                end
            end
        end

        if data.trophy then
            trophy = {
                gx = data.trophy.gx, gy = data.trophy.gy,
                x = (data.trophy.gx-0.5)*tileSize, y = (data.trophy.gy-0.5)*tileSize,
                timer = 0
            }
        end
        
        enemies = {}
        if data.enemies then
            for _, e in ipairs(data.enemies) do
                table.insert(enemies, {
                    gx = e.gx, gy = e.gy, x = e.x, y = e.y, type = e.type,
                    angle = math.random() * math.pi * 2, shootTimer = 0, moveTimer = 0
                })
            end
        end
        messageText = "LEVEL LOADED"
        messageTimer = 2
    end
end

function getDoor(gx, gy)
    for _, d in ipairs(doors) do
        if d.gx == gx and d.gy == gy then return d end
    end
    return nil
end

function spawnBullet(posX, posY, angle, isEnemy, projImg)
    table.insert(bullets, {
        x = posX, y = posY, angle = angle, speed = 800,
        life = 0, isEnemy = isEnemy, img = projImg or bulletImg
    })
end

function shoot()
    if player.ammo > 0 and player.hp > 0 and not hasWon then
        player.ammo = player.ammo - 1
        player.muzzleFlash = 0.1
        player.gunKick = 0.5
        
        local forwardDist = 10
        local sideDist = 5 
        
        local spawnX = player.x + math.cos(player.angle) * forwardDist - math.sin(player.angle) * sideDist
        local spawnY = player.y + math.sin(player.angle) * forwardDist + math.cos(player.angle) * sideDist
        
        spawnBullet(spawnX, spawnY, player.angle, false, bulletImg)
    end
end

function canSeePlayer(e)
    local dx, dy = player.x - e.x, player.y - e.y
    local dist = math.sqrt(dx*dx + dy*dy)
    local angle = math.atan2(dy, dx)
    for d = 0, dist, 10 do
        local rx = e.x + math.cos(angle) * d
        local ry = e.y + math.sin(angle) * d
        local gx, gy = math.floor(rx/tileSize)+1, math.floor(ry/tileSize)+1
        if map[gy] and map[gy][gx] == 1 then return false end
    end
    return true
end

function love.update(dt)
    if hasWon then
        winTimer = winTimer + dt
        if winTimer >= 3 then resetMap() end
        return 
    end

    if messageTimer > 0 then messageTimer = messageTimer - dt end
    if player.hp <= 0 then return end 

    if player.muzzleFlash > 0 then player.muzzleFlash = player.muzzleFlash - dt end
    if player.gunKick > 0 then player.gunKick = player.gunKick - dt end

    for _, d in ipairs(doors) do
        if d.state == "opening" then
            d.offset = d.offset + 128 * dt
            if d.offset >= 64 then d.offset = 64; d.state = "open"; d.timer = 3 end
        elseif d.state == "open" then
            d.timer = d.timer - dt
            if d.timer <= 0 then d.state = "closing" end
        elseif d.state == "closing" then
            d.offset = d.offset - 128 * dt
            if d.offset <= 0 then d.offset = 0; d.state = "closed" end
        end
    end

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
                    if not exists then 
                        table.insert(enemies, {
                            gx = gx, gy = gy, x = (gx-0.5)*tileSize, y = (gy-0.5)*tileSize,
                            angle = math.random() * math.pi * 2, shootTimer = 0, moveTimer = 0, type = math.random(1, 2)
                        }) 
                    end
                elseif editBrush == 3 then
                    trophy = { gx = gx, gy = gy, x = (gx-0.5)*tileSize, y = (gy-0.5)*tileSize, timer = 0 }
                elseif editBrush == 4 then
                    if not getDoor(gx, gy) then
                        map[gy][gx] = 4
                        table.insert(doors, {gx = gx, gy = gy, offset = 0, state = "closed", timer = 0})
                    end
                end
            end
        elseif love.mouse.isDown(2) then
            if map[gy] and map[gy][gx] then
                map[gy][gx] = 0
                for i = #doors, 1, -1 do if doors[i].gx == gx and doors[i].gy == gy then table.remove(doors, i) end end
                for i = #enemies, 1, -1 do if enemies[i].gx == gx and enemies[i].gy == gy then table.remove(enemies, i) end end
                if trophy and trophy.gx == gx and trophy.gy == gy then trophy = nil end
            end
        end

        if love.keyboard.isDown("up") then player.y = player.y - 300 * dt end
        if love.keyboard.isDown("down") then player.y = player.y + 300 * dt end
        if love.keyboard.isDown("left") then player.x = player.x - 300 * dt end
        if love.keyboard.isDown("right") then player.x = player.x + 300 * dt end
    else
        local cosA, sinA = math.cos(player.angle), math.sin(player.angle)
        local nextX, nextY = player.x, player.y
        if love.keyboard.isDown("w") then nextX = player.x + cosA * player.speed * dt; nextY = player.y + sinA * player.speed * dt end
        if love.keyboard.isDown("s") then nextX = player.x - cosA * player.speed * dt; nextY = player.y - sinA * player.speed * dt end
        
        local pgx, pgy = math.floor(nextX/tileSize)+1, math.floor(nextY/tileSize)+1
        local canMove = true
        if map[pgy] and map[pgy][pgx] == 1 then canMove = false end
        if map[pgy] and map[pgy][pgx] == 4 then
            local d = getDoor(pgx, pgy)
            if d and d.offset < 40 then canMove = false end
        end
        if canMove then player.x, player.y = nextX, nextY end
        
        if love.keyboard.isDown("a") then player.angle = player.angle - 3 * dt end
        if love.keyboard.isDown("d") then player.angle = player.angle + 3 * dt end

        if trophy then
            trophy.timer = (trophy.timer or 0) + dt
            local distToTrophy = math.sqrt((player.x - trophy.x)^2 + (player.y - trophy.y)^2)
            if distToTrophy < 40 then hasWon = true end
        end

        for _, e in ipairs(enemies) do
            local dx, dy = player.x - e.x, player.y - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < detectionRange and canSeePlayer(e) then
                e.shootTimer = e.shootTimer - dt
                if e.shootTimer <= 0 then
                    spawnBullet(e.x, e.y, math.atan2(dy, dx), true, (e.type == 2) and enemyFire1Img or enemyFireImg)
                    e.shootTimer = 2.0 
                end
            else
                e.moveTimer = e.moveTimer - dt
                if e.moveTimer <= 0 then e.angle = math.random() * math.pi * 2; e.moveTimer = math.random(2, 5) end
                local nx, ny = e.x + math.cos(e.angle)*60*dt, e.y + math.sin(e.angle)*60*dt
                local egx, egy = math.floor(nx/tileSize)+1, math.floor(ny/tileSize)+1
                if map[egy] and map[egy][egx] == 0 then e.x, e.y = nx, ny else e.angle = e.angle + math.pi end
            end
        end

        for i = #bullets, 1, -1 do
            local b = bullets[i]
            b.life = b.life + dt
            local steps, removed = 10, false
            local sx, sy = (math.cos(b.angle)*b.speed*dt)/10, (math.sin(b.angle)*b.speed*dt)/10
            for s = 1, steps do
                b.x, b.y = b.x + sx, b.y + sy
                local bgx, bgy = math.floor(b.x/tileSize)+1, math.floor(b.y/tileSize)+1
                local hit = false
                if map[bgy] and map[bgy][bgx] == 1 then hit = true end
                if map[bgy] and map[bgy][bgx] == 4 then
                    local d = getDoor(bgx, bgy)
                    if d and d.offset < 10 then hit = true end
                end
                if hit then table.remove(bullets, i); removed = true; break end
                if not b.isEnemy then
                    for j = #enemies, 1, -1 do
                        if math.sqrt((b.x - enemies[j].x)^2 + (b.y - enemies[j].y)^2) < 30 then
                            table.insert(pickups, {x = enemies[j].x, y = enemies[j].y, timer = 0})
                            table.remove(enemies, j); table.remove(bullets, i); removed = true; break
                        end
                    end
                else
                    if math.sqrt((b.x - player.x)^2 + (b.y - player.y)^2) < 20 then
                        player.hp = math.max(0, player.hp - 10)
                        table.remove(bullets, i); removed = true; break
                    end
                end
                if removed then break end
            end
        end

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

function draw3DView()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.1, 0.1, 0.1); love.graphics.rectangle("fill", 0, 0, sw, sh/2)
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.rectangle("fill", 0, sh/2, sw, sh/2)
    
    local zBuffer, res, fov = {}, 2, math.pi / 3
    for i = 0, sw - 1, res do
        local rayA = (player.angle - fov/2) + (i / sw) * fov
        local rx, ry, dist = player.x, player.y, 0
        local cosA, sinA = math.cos(rayA), math.sin(rayA)
        while dist < 1200 do
            rx, ry, dist = rx + cosA*5, ry + sinA*5, dist + 5
            local gx, gy = math.floor(rx/tileSize)+1, math.floor(ry/tileSize)+1
            if map[gy] and map[gy][gx] > 0 then
                local hitWall = false
                local texture = wallImg
                if map[gy][gx] == 1 then hitWall = true
                elseif map[gy][gx] == 4 then
                    local d = getDoor(gx, gy)
                    if d then
                        local hitX, hitY = rx % tileSize, ry % tileSize
                        local checkPos = (hitX > 1 and hitX < 63) and hitX or hitY
                        if checkPos > d.offset then texture = doorImg; hitWall = true end
                    end
                end
                if hitWall then
                    local corrected = dist * math.cos(rayA - player.angle)
                    zBuffer[i] = corrected
                    local h = (tileSize * sh) / corrected
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(texture, i, (sh-h)/2, 0, res/texture:getWidth(), h/texture:getHeight())
                    break
                end
            end
        end
        if not zBuffer[i] then zBuffer[i] = 2000 end
        for j = 1, res-1 do zBuffer[i+j] = zBuffer[i] end
    end

    local items = {}
    if trophy then table.insert(items, {x=trophy.x, y=trophy.y, img=trophyImg, type="trophy", t=trophy.timer}) end
    for _, e in ipairs(enemies) do table.insert(items, {x=e.x, y=e.y, img=(e.type == 2) and enemy2Img or enemyImg, type="sprite"}) end
    for _, p in ipairs(pickups) do table.insert(items, {x=p.x, y=p.y, img=ammoImg, type="ammo", t=p.timer}) end
    for _, b in ipairs(bullets) do table.insert(items, {x=b.x, y=b.y, type="bullet", life=b.life, img=b.img}) end
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
                love.graphics.setColor(1, 1, 1)
                if s.type == "trophy" or s.type == "ammo" then
                    local rot = math.cos(s.t * 4) 
                    local bob = math.sin(s.t * 5) * 20 * (64 / dist)
                    love.graphics.draw(s.img, sx, sh/2 + bob, 0, (h / s.img:getHeight()) * rot, h / s.img:getHeight(), s.img:getWidth()/2, s.img:getHeight()/2)
                elseif s.type == "bullet" then
                    local bSize = h * 0.1
                    love.graphics.draw(s.img, sx, sh/2, 0, bSize/s.img:getWidth(), bSize/s.img:getHeight(), s.img:getWidth()/2, s.img:getHeight()/2)
                else
                    love.graphics.draw(s.img, sx, (sh-h)/2, 0, h/s.img:getHeight(), h/s.img:getHeight(), s.img:getWidth()/2)
                end
            end
        end
    end
end

function love.draw()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    if isEditMode then
        love.graphics.push(); love.graphics.translate(sw/2 - player.x, sh/2 - player.y)
        for y=1, mapHeight do 
            for x=1, mapWidth do 
                if map[y][x] == 1 then love.graphics.setColor(0.5, 0.5, 0.5); love.graphics.rectangle("line", (x-1)*64, (y-1)*64, 64, 64) 
                elseif map[y][x] == 4 then love.graphics.setColor(0, 0.5, 1); love.graphics.rectangle("line", (x-1)*64, (y-1)*64, 64, 64) end 
            end 
        end
        if trophy then love.graphics.setColor(1, 1, 0); love.graphics.rectangle("fill", trophy.x-10, trophy.y-10, 20, 20) end
        for _, e in ipairs(enemies) do love.graphics.setColor(e.type == 2 and {0,1,0} or {1,1,1}); love.graphics.circle("fill", e.x, e.y, 10) end
        love.graphics.setColor(1,0,0); love.graphics.circle("fill", player.x, player.y, 5); love.graphics.pop()
    else
        draw3DView()
        
        if player.muzzleFlash > 0 then
            love.graphics.setColor(1, 0.8, 0.2, 0.7)
            local flashX = sw * 0.70
            local flashY = sh * 0.80
            love.graphics.circle("fill", flashX, flashY, math.random(30, 50))
        end

        local ox, oy = 0, 0
        if player.gunKick > 0 then ox = math.random(-10, 10) * (player.gunKick * 2); oy = math.random(-10, 10) * (player.gunKick * 2) end
        love.graphics.setColor(1, 1, 1)
        if player.hp > 0 then love.graphics.draw(gunImg, (sw*0.7) + ox, sh + oy, 0, 7, 7, gunImg:getWidth()/2, gunImg:getHeight()) end
        
        love.graphics.setColor(1, 1, 0); love.graphics.print("AMMO: " .. player.ammo, 30, 60, 0, 2, 2)
        love.graphics.setColor(0.5, 0, 0); love.graphics.rectangle("fill", 30, sh-40, 200, 20)
        love.graphics.setColor(0, 1, 0); love.graphics.rectangle("fill", 30, sh-40, 200*(player.hp/100), 20)
        
        -- DOOR UI PROMPT
        local tx = math.floor((player.x + math.cos(player.angle) * 100) / tileSize) + 1
        local ty = math.floor((player.y + math.sin(player.angle) * 100) / tileSize) + 1
        if map[ty] and map[ty][tx] == 4 then
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("PRESS SPACE TO OPEN", 0, sh*0.6, sw, "center")
        end

        -- FIXED GAME OVER CENTERING
        if player.hp <= 0 then 
            love.graphics.setColor(1, 0, 0)
            -- Use sw/2 for the limit because scale is 2
            love.graphics.printf("GAME OVER", 0, sh/2-50, sw/2, "center", 0, 2, 2) 
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("PRESS R TO RESTART", 0, sh/2+10, sw/1.5, "center", 0, 1.5, 1.5) 
        end
    end

    if hasWon then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(winImg, 0, 0, 0, sw/winImg:getWidth(), sh/winImg:getHeight())
    end

    if messageTimer > 0 then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print(messageText, 20, 20, 0, 1.2, 1.2)
    end
end

function love.mousepressed(x, y, button) if not isEditMode and button == 1 then shoot() end end

function love.keypressed(k) 
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl and k == "s" then saveLevel() elseif ctrl and k == "l" then loadLevel() end
    if k == "tab" then isEditMode = not isEditMode end
    if k == "1" then editBrush = 1 end
    if k == "2" then editBrush = 2 end
    if k == "3" then editBrush = 3 end
    if k == "4" then editBrush = 4 end
    if k == "r" then resetMap() end
    
    if k == "space" and not isEditMode then
        local tx = math.floor((player.x + math.cos(player.angle) * 100) / tileSize) + 1
        local ty = math.floor((player.y + math.sin(player.angle) * 100) / tileSize) + 1
        if map[ty] and map[ty][tx] == 4 then
            local d = getDoor(tx, ty)
            if d and (d.state == "closed" or d.state == "closing") then 
                d.state = "opening" 
            end
        end
    end
end
