-- Initialize SUIT UI library
suit = require('suit')

-- Control panel variables
G = 1  -- Gravitational constant (scaled for simulation)
sliderG = {value = G * 100, min = 0, max = 200}  -- Initial G value * 100 for slider
controlPanelVisible = true
draggedBody = nil

function computeRadius(mass)
    return 5 * mass^(1/3)
end

-- Calculate gravitational potential energy between two bodies
function calculatePotentialEnergy(body1, body2)
    local dx = body1.x - body2.x
    local dy = body1.y - body2.y
    local distance = math.sqrt(dx*dx + dy*dy)
    return -G * body1.mass * body2.mass / distance
end

-- Calculate kinetic energy of a body
function calculateKineticEnergy(body)
    local velocity_squared = body.vx * body.vx + body.vy * body.vy
    return 0.5 * body.mass * velocity_squared
end

-- Calculate total energy of the system
function calculateSystemEnergy()
    local kineticEnergy = 0
    local potentialEnergy = 0
    
    for _, body in ipairs(bodies) do
        kineticEnergy = kineticEnergy + calculateKineticEnergy(body)
    end
    
    for i = 1, #bodies do
        for j = i + 1, #bodies do
            potentialEnergy = potentialEnergy + calculatePotentialEnergy(bodies[i], bodies[j])
        end
    end
    
    return kineticEnergy + potentialEnergy
end

-- Calculate center of mass of the system
function calculateCenterOfMass()
    local totalMass = 0
    local centerX, centerY = 0, 0
    
    for _, body in ipairs(bodies) do
        totalMass = totalMass + body.mass
        centerX = centerX + body.x * body.mass
        centerY = centerY + body.y * body.mass
    end
    
    if totalMass > 0 then
        centerX = centerX / totalMass
        centerY = centerY / totalMass
    end
    
    return centerX, centerY
end

-- Calculate total angular momentum of the system
function calculateAngularMomentum()
    local centerX, centerY = calculateCenterOfMass()
    local angularMomentum = 0
    
    for _, body in ipairs(bodies) do
        local rx = body.x - centerX
        local ry = body.y - centerY
        local crossProduct = rx * body.vy * body.mass - ry * body.vx * body.mass
        angularMomentum = angularMomentum + crossProduct
    end
    
    return angularMomentum
end

-- Check if the system is near a previous state (for periodicity detection)
function checkForPeriodicity()
    local threshold = 10 -- Adjust based on your simulation scale
    local minDistance = math.huge
    local minTimeGap = 100 -- Only check against states that are at least this far apart
    
    for i = 1, #orbitHistory - minTimeGap do
        local oldState = orbitHistory[i]
        -- Only proceed if the old state has the same number of bodies as the current state.
        if #oldState == #bodies then
            local totalDistance = 0
            for j, body in ipairs(bodies) do
                local dx = body.x - oldState[j].x
                local dy = body.y - oldState[j].y
                totalDistance = totalDistance + math.sqrt(dx*dx + dy*dy)
            end
            
            minDistance = math.min(minDistance, totalDistance)
            
            if totalDistance < threshold and not periodicityDetected then
                periodicityDetected = true
                periodicityTimer = 3 -- Show the alert for 3 seconds
                return true
            end
        end
    end
    
    return false
end

-- Create a deep copy of the bodies for the shadow system
function createShadowSystem()
    local shadowBodies = {}
    for _, body in ipairs(bodies) do
        local shadowBody = {}
        for k, v in pairs(body) do
            shadowBody[k] = v
        end
        shadowBody.x = shadowBody.x + (math.random() - 0.5) * 0.01
        shadowBody.y = shadowBody.y + (math.random() - 0.5) * 0.01
        table.insert(shadowBodies, shadowBody)
    end
    return shadowBodies
end

-- Calculate the divergence between main and shadow systems
function calculateShadowDivergence()
    local totalDivergence = 0
    for i, body in ipairs(bodies) do
        local shadowBody = shadowBodies[i]
        local dx = body.x - shadowBody.x
        local dy = body.y - shadowBody.y
        totalDivergence = totalDivergence + math.sqrt(dx*dx + dy*dy)
    end
    return totalDivergence
end

-- Update the shadow system
function updateShadowSystem(dt)
    for i, b in ipairs(shadowBodies) do
        b.ax, b.ay = 0, 0
        for j, o in ipairs(shadowBodies) do
            if i ~= j then
                local dx = o.x - b.x
                local dy = o.y - b.y
                local dist2 = dx * dx + dy * dy
                local dist = math.sqrt(dist2)
                local accel = G * o.mass / dist2
                b.ax = b.ax + accel * dx / dist
                b.ay = b.ay + accel * dy / dist
            end
        end
    end

    for _, b in ipairs(shadowBodies) do
        b.vx = b.vx + b.ax * dt
        b.vy = b.vy + b.ay * dt
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
    end
end

-- love.load: initialization
function love.load()
    windowWidth = love.graphics.getWidth()
    windowHeight = love.graphics.getHeight()
    
    local cx = windowWidth / 2
    local cy = windowHeight / 2

    simulationTime = 0
    simulationYearLength = 5  -- Default year length in seconds
    startYear = 2025
    
    timeScale = 10
    constTimeScale = 10
    timeDirection = 1
    G = 1
    pausedMsg = ""
    hoveredBody = nil
    
    initialEnergy = 0
    currentEnergy = 0
    initialAngularMomentum = 0
    currentAngularMomentum = 0
    initialCOMx, initialCOMy = 0, 0
    energyDrift = 0
    angularMomentumDrift = 0
    comDrift = 0
    
    shadowBodies = {}
    shadowDivergence = 0
    maxDivergence = 0
    showShadowSystem = false
    chaosLevel = 0
    
    orbitHistory = {}
    historyInterval = 10
    frameCount = 0
    periodicityDetected = false
    periodicityTimer = 0
    
    stabilityIndex = 0
    showAnalytics = true
    collisionEffects = {}
    
    sunImage = love.graphics.newImage("sun.png")
    earthImage = love.graphics.newImage("earth.png")
    jupiterImage = love.graphics.newImage("jupiter_juno.png")
    
    presets = {
        {
            name = "Default",
            bodies = {
                { name = "Star",    mass = 1000, x = cx,       y = cy,      vx = 0,    vy = 0,    image = sunImage },
                { name = "Planet",  mass = 1,    x = cx + 100, y = cy,      vx = 0,    vy = 1.5,  image = earthImage },
                { name = "Planet2", mass = 500,  x = cx + 200, y = cy,      vx = 0,    vy = 1.5,  image = jupiterImage },
            }
        },
        {
            name = "Figure 8",
            bodies = {
                { name = "Alpha",   mass = 100, x = cx - 100, y = cy,      vx = 0.347,  vy = 0.533, image = sunImage },
                { name = "Beta",    mass = 100, x = cx,       y = cy,      vx = -0.694, vy = -1.066, image = earthImage },
                { name = "Gamma",   mass = 100, x = cx + 100, y = cy,      vx = 0.347,  vy = 0.533,  image = jupiterImage },
            }
        },
        {
            name = "Solar System",
            bodies = {
                { name = "Sun",     mass = 1000, x = cx,       y = cy,      vx = 0,     vy = 0,     image = sunImage },
                { name = "Earth",   mass = 1,    x = cx + 150, y = cy,      vx = 0,     vy = 2.0,   image = earthImage },
                { name = "Jupiter", mass = 317,  x = cx + 350, y = cy,      vx = 0,     vy = 0.9,   image = jupiterImage },
            }
        },
        {
            name = "Broucke-Henon",
            bodies = {
                { name = "Alpha",   mass = 100, x = cx - 100, y = cy,      vx = 0,      vy = 0.4645, image = sunImage },
                { name = "Beta",    mass = 100, x = cx,       y = cy,      vx = -0.4083, vy = -0.2323, image = earthImage },
                { name = "Gamma",   mass = 100, x = cx + 100, y = cy,      vx = 0.4083,  vy = -0.2323, image = jupiterImage },
            }
        },
        {
            name = "Binary Stars",
            bodies = {
                { name = "Star1",   mass = 800,  x = cx - 80,  y = cy,      vx = 0,     vy = 1.0,   image = sunImage },
                { name = "Star2",   mass = 800,  x = cx + 80,  y = cy,      vx = 0,     vy = -1.0,  image = sunImage },
                { name = "Planet",  mass = 2,    x = cx,       y = cy + 200, vx = 2.0,   vy = 0,     image = earthImage },
            }
        },
        {
            name = "Harmony",
            bodies = {
                { name = "Sun",     mass = 1000, x = cx,        y = cy,      vx = 0,    vy = 0,    image = sunImage },
                { name = "Planet1", mass = 1,    x = cx + 150,  y = cy,      vx = 0,    vy = 2.58, image = earthImage },
                { name = "Planet2", mass = 1,    x = cx + 250,  y = cy,      vx = 0,    vy = 2.00, image = earthImage },
                { name = "Planet3", mass = 1,    x = cx + 350,  y = cy,      vx = 0,    vy = 1.69, image = earthImage },
            }
        }
    }

    currentPreset = 2
    loadPreset(currentPreset)
    updateButtonPositions()
end

-- love.update: simulation update (preset reinitialization removed)
function love.update(dt)
    updateControlPanel(dt)
    updateHoveredBody()
    local effective_dt = dt * timeScale
    
    if timeScale ~= 0 then
        simulationTime = simulationTime + effective_dt
    end
    
    if periodicityTimer > 0 then
        periodicityTimer = periodicityTimer - dt
        if periodicityTimer <= 0 then
            periodicityDetected = false
        end
    end
    
    if timeScale == 0 then return end

    for i, b in ipairs(bodies) do
        b.ax, b.ay = 0, 0
        for j, o in ipairs(bodies) do
            if i ~= j then
                local dx = o.x - b.x
                local dy = o.y - b.y
                local dist2 = dx * dx + dy * dy
                local dist = math.sqrt(dist2)
                local accel = G * o.mass / dist2
                b.ax = b.ax + accel * dx / dist
                b.ay = b.ay + accel * dy / dist
            end
        end
    end

    for _, b in ipairs(bodies) do
        b.vx = b.vx + b.ax * effective_dt
        b.vy = b.vy + b.ay * effective_dt
        b.x  = b.x + b.vx * effective_dt
        b.y  = b.y + b.vy * effective_dt
    end

    updateShadowSystem(effective_dt)
    shadowDivergence = calculateShadowDivergence()
    maxDivergence = math.max(maxDivergence, shadowDivergence)
    chaosLevel = math.min(1.0, math.log(1 + shadowDivergence) / 5)
    
    frameCount = frameCount + 1
    if frameCount % historyInterval == 0 then
        local currentState = {}
        for _, body in ipairs(bodies) do
            table.insert(currentState, { x = body.x, y = body.y, vx = body.vx, vy = body.vy })
        end
        table.insert(orbitHistory, currentState)
        if #orbitHistory > 1000 then
            table.remove(orbitHistory, 1)
        end
        if #orbitHistory > 50 then
            checkForPeriodicity()
        end
    end
    
    currentEnergy = calculateSystemEnergy()
    energyDrift = (currentEnergy - initialEnergy) / math.abs(initialEnergy) * 100
    currentAngularMomentum = calculateAngularMomentum()
    if initialAngularMomentum ~= 0 then
        angularMomentumDrift = (currentAngularMomentum - initialAngularMomentum) / math.abs(initialAngularMomentum) * 100
    else
        angularMomentumDrift = 0
    end
    
    local comX, comY = calculateCenterOfMass()
    comDrift = math.sqrt((comX - initialCOMx)^2 + (comY - initialCOMy)^2)
    
    stabilityIndex = math.max(0, 1 - (
        math.abs(energyDrift) * 0.01 +
        math.abs(angularMomentumDrift) * 0.01 +
        comDrift * 0.1 +
        chaosLevel * 0.5
    ))
    
    handleCollisions()
    
    for i = #collisionEffects, 1, -1 do
        local effect = collisionEffects[i]
        effect.currentTime = effect.currentTime + dt
        for _, particle in ipairs(effect.particles) do
            particle.currentTime = particle.currentTime + dt
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            local progress = particle.currentTime / particle.lifetime
            particle.color[4] = 1 - progress
        end
        if effect.currentTime >= effect.lifetime then
            table.remove(collisionEffects, i)
        end
    end
end

-- Update on-screen buttons
function updateButtonPositions()
    buttons = {
        { label = "<<",     x = 10,  y = 50, w = 50, h = 30, action = function() 
                timeDirection = -1 
                timeScale = -constTimeScale 
                pausedMsg = ""
            end },
        { label = "Pause",  x = 70,  y = 50, w = 50, h = 30, action = function() 
                timeScale = 0 
                pausedMsg = "Paused"
            end },
        { label = ">>",     x = 130, y = 50, w = 50, h = 30, action = function() 
                timeDirection = 1 
                timeScale = constTimeScale 
                pausedMsg = ""
            end },
        { label = "Analytics",  x = 190, y = 50, w = 70, h = 30, action = function() 
                showAnalytics = not showAnalytics
            end },
        { label = "Shadow",  x = 270, y = 50, w = 70, h = 30, action = function() 
                showShadowSystem = not showShadowSystem
            end }
    }
    
    local buttonX = 10
    local buttonY = windowHeight - 40
    for i, preset in ipairs(presets) do
        table.insert(buttons, { 
            label = preset.name, 
            x = buttonX, 
            y = buttonY, 
            w = 80, 
            h = 30, 
            action = function() 
                loadPreset(i)
                timeDirection = 1 
                timeScale = constTimeScale 
                pausedMsg = ""
            end 
        })
        buttonX = buttonX + 90
    end
end

-- love.resize: update window dimensions and adjust positions
function love.resize(w, h)
    windowWidth = w
    windowHeight = h
    
    local cx = windowWidth / 2
    local cy = windowHeight / 2
    
    updateButtonPositions()
    
    for i, preset in ipairs(presets) do
        for j, body in ipairs(preset.bodies) do
            if j == 1 or body.name:find("Sun") or body.name:find("Star") then
                preset.bodies[j].x = cx
                preset.bodies[j].y = cy
            else
                local relX = preset.bodies[j].x - preset.bodies[1].x
                local relY = preset.bodies[j].y - preset.bodies[1].y
                preset.bodies[j].x = cx + relX
                preset.bodies[j].y = cy + relY
            end
        end
    end
    
    if #bodies > 0 then
        local primaryBody
        for _, body in ipairs(bodies) do
            if body.name:find("Sun") or body.name:find("Star") then
                primaryBody = body
                break
            end
        end
        if not primaryBody then
            primaryBody = bodies[1]
        end
        local moveX = cx - primaryBody.x
        local moveY = cy - primaryBody.y
        for _, body in ipairs(bodies) do
            body.x = body.x + moveX
            body.y = body.y + moveY
        end
    end
end

-- Load a specific preset configuration
function loadPreset(presetIndex)
    currentPreset = presetIndex
    bodies = {}
    collisionEffects = {}
    orbitHistory = {}
    
    for _, body in ipairs(presets[presetIndex].bodies) do
        local newBody = {}
        for k, v in pairs(body) do
            newBody[k] = v
        end
        table.insert(bodies, newBody)
    end
    
    for i, body in ipairs(bodies) do
        body.radius = computeRadius(body.mass)
    end
    
    shadowBodies = createShadowSystem()
    shadowDivergence = 0
    maxDivergence = 0
    
    initialEnergy = calculateSystemEnergy()
    currentEnergy = initialEnergy
    initialAngularMomentum = calculateAngularMomentum()
    currentAngularMomentum = initialAngularMomentum
    initialCOMx, initialCOMy = calculateCenterOfMass()
    energyDrift = 0
    angularMomentumDrift = 0
    comDrift = 0
    
    periodicityDetected = false
    periodicityTimer = 0
    frameCount = 0
end

-- Update hovered body based on mouse position
function updateHoveredBody()
    local mx, my = love.mouse.getPosition()
    hoveredBody = nil
    for _, b in ipairs(bodies) do
        if ((mx - b.x)^2 + (my - b.y)^2) < (b.radius * b.radius) then
            hoveredBody = b
            break
        end
    end
end

-- Create collision effect
function createCollisionEffect(x, y, mass, vx, vy)
    local particleCount = math.min(100, math.floor(mass / 10) + 20)
    local effect = {
        x = x,
        y = y,
        particles = {},
        lifetime = 2.0,
        currentTime = 0
    }
    
    for i = 1, particleCount do
        local angle = math.random() * math.pi * 2
        local speed = math.random() * 30 + 20
        local particleVx = math.cos(angle) * speed + vx * 0.5
        local particleVy = math.sin(angle) * speed + vy * 0.5
        local size = math.random() * 4 + 2
        local lifetime = math.random() * 2
        table.insert(effect.particles, {
            x = 0,
            y = 0,
            vx = particleVx,
            vy = particleVy,
            size = size,
            lifetime = lifetime,
            currentTime = 0,
            color = {1, math.random(0.5, 1), 0, 1}
        })
    end
    
    table.insert(collisionEffects, effect)
    return effect
end

-- Apply gravitational disturbance to nearby bodies
function applySupernovaEffect(x, y, explosionEnergy, sourceBody)
    local disturbanceRadius = explosionEnergy * 5
    for _, body in ipairs(bodies) do
        if body ~= sourceBody then
            local dx = body.x - x
            local dy = body.y - y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < disturbanceRadius then
                local forceMagnitude = (explosionEnergy / 10) * (1 - dist/disturbanceRadius)
                local angle = math.atan2(dy, dx)
                body.vx = body.vx + math.cos(angle) * forceMagnitude / body.mass
                body.vy = body.vy + math.sin(angle) * forceMagnitude / body.mass
            end
        end
    end
end

-- Handle collisions between bodies and merge them
function handleCollisions()
    for i = #bodies, 1, -1 do
        for j = i - 1, 1, -1 do
            local dx = bodies[i].x - bodies[j].x
            local dy = bodies[i].y - bodies[j].y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < (bodies[i].radius + bodies[j].radius) then
                local collisionX = (bodies[i].x * bodies[i].mass + bodies[j].x * bodies[j].mass) / (bodies[i].mass + bodies[j].mass)
                local collisionY = (bodies[i].y * bodies[i].mass + bodies[j].y * bodies[j].mass) / (bodies[i].mass + bodies[j].mass)
                local totalMass = bodies[i].mass + bodies[j].mass
                local combinedVx = (bodies[i].vx * bodies[i].mass + bodies[j].vx * bodies[j].mass) / totalMass
                local combinedVy = (bodies[i].vy * bodies[i].mass + bodies[j].vy * bodies[j].mass) / totalMass
                createCollisionEffect(collisionX, collisionY, totalMass, combinedVx, combinedVy)
                local relVx = bodies[i].vx - bodies[j].vx
                local relVy = bodies[i].vy - bodies[j].vy
                local relV = math.sqrt(relVx*relVx + relVy*relVy)
                local explosionEnergy = 0.5 * bodies[i].mass * bodies[j].mass * relV * relV / (bodies[i].mass + bodies[j].mass)
                applySupernovaEffect(collisionX, collisionY, explosionEnergy, nil)
                local m1 = bodies[i].mass
                local m2 = bodies[j].mass
                local newMass = m1 + m2
                local newX = (bodies[i].x * m1 + bodies[j].x * m2) / newMass
                local newY = (bodies[i].y * m1 + bodies[j].y * m2) / newMass
                local newVx = (bodies[i].vx * m1 + bodies[j].vx * m2) / newMass
                local newVy = (bodies[i].vy * m1 + bodies[j].vy * m2) / newMass
                local largerIndex = (m1 >= m2) and i or j
                local newImage = bodies[largerIndex].image
                local newName = bodies[largerIndex].name
                local newBody = {
                    name = newName,
                    mass = newMass,
                    x = newX,
                    y = newY,
                    vx = newVx,
                    vy = newVy,
                    image = newImage,
                    radius = computeRadius(newMass)
                }
                table.remove(bodies, i)
                table.remove(bodies, j)
                table.insert(bodies, newBody)
                if #shadowBodies > 0 then
                    local shadowNewBody = {
                        name = newName,
                        mass = newMass,
                        x = newX + (math.random() - 0.5) * 0.01,
                        y = newY + (math.random() - 0.5) * 0.01,
                        vx = newVx,
                        vy = newVy,
                        radius = computeRadius(newMass)
                    }
                    table.remove(shadowBodies, i)
                    table.remove(shadowBodies, j)
                    table.insert(shadowBodies, shadowNewBody)
                end
                initialEnergy = calculateSystemEnergy()
                currentEnergy = initialEnergy
                initialAngularMomentum = calculateAngularMomentum()
                currentAngularMomentum = initialAngularMomentum
                initialCOMx, initialCOMy = calculateCenterOfMass()
                orbitHistory = {}
                frameCount = 0
                periodicityDetected = false
                periodicityTimer = 0
                return
            end
        end
    end
end

-- Handle drag and drop of planets
function startDraggingBody(x, y)
    for _, body in ipairs(bodies) do
        local dx = x - body.x
        local dy = y - body.y
        if dx*dx + dy*dy <= body.radius*body.radius then
            draggedBody = body
            dragStartX = x
            dragStartY = y
            dragOriginalX = body.x
            dragOriginalY = body.y
            return true
        end
    end
    return false
end

function updateDraggedBody(x, y)
    if draggedBody then
        draggedBody.x = x
        draggedBody.y = y
        return true
    end
    return false
end

function stopDraggingBody(x, y)
    if draggedBody then
        if timeScale ~= 0 then
            local dragTime = 0.2
            draggedBody.vx = (draggedBody.x - dragOriginalX) / dragTime
            draggedBody.vy = (draggedBody.y - dragOriginalY) / dragTime
        end
        draggedBody = nil
        return true
    end
    return false
end

function addNewPlanet(x, y)
    addingPlanet = false
    local newPlanet = {
        name = "Planet" .. (#bodies + 1),
        mass = 10,
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        image = earthImage,
        radius = computeRadius(10)
    }
    table.insert(bodies, newPlanet)
    if #shadowBodies > 0 then
        local shadowPlanet = {
            name = newPlanet.name,
            mass = newPlanet.mass,
            x = x + (math.random() - 0.5) * 0.01,
            y = y + (math.random() - 0.5) * 0.01,
            vx = 0,
            vy = 0,
            radius = newPlanet.radius
        }
        table.insert(shadowBodies, shadowPlanet)
    end
    initialEnergy = calculateSystemEnergy()
    currentEnergy = initialEnergy
    initialAngularMomentum = calculateAngularMomentum()
    currentAngularMomentum = initialAngularMomentum
    initialCOMx, initialCOMy = calculateCenterOfMass()
    timeScale = constTimeScale
    pausedMsg = ""
end

-- Draw a body (scaled image or circle)
function drawBody(body)
    if body.image then
        local scale = (2 * body.radius) / body.image:getWidth()
        love.graphics.draw(body.image, body.x, body.y, 0, scale, scale, body.image:getWidth()/2, body.image:getHeight()/2)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", body.x, body.y, body.radius)
    end
end

-- Draw a collision effect
function drawCollisionEffect(effect)
    for _, particle in ipairs(effect.particles) do
        love.graphics.setColor(particle.color)
        love.graphics.circle("fill", effect.x + particle.x, effect.y + particle.y, particle.size * (1 - particle.currentTime/particle.lifetime))
    end
end

-- Draw the analytics panel
function drawAnalyticsPanel()
    if not showAnalytics then return end
    
    local panelX = 10
    local panelY = 100
    local panelWidth = 220
    local panelHeight = 230
    local textY = panelY + 10
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Physics Analysis", panelX + 10, textY)
    textY = textY + 20
    
    local energyColor = {1, 1, 1}
    if math.abs(energyDrift) > 1.0 then
        energyColor = {1, 0.3, 0.3}
    end
    love.graphics.setColor(energyColor)
    love.graphics.print(string.format("Energy: %.2f (%.2f%%)", currentEnergy, energyDrift), panelX + 10, textY)
    textY = textY + 20
    
    local amColor = {1, 1, 1}
    if math.abs(angularMomentumDrift) > 1.0 then
        amColor = {1, 0.3, 0.3}
    end
    love.graphics.setColor(amColor)
    love.graphics.print(string.format("Ang. Momentum: %.2f (%.2f%%)", currentAngularMomentum, angularMomentumDrift), panelX + 10, textY)
    textY = textY + 20
    
    local comColor = {1, 1, 1}
    if comDrift > 5.0 then
        comColor = {1, 0.3, 0.3}
    end
    love.graphics.setColor(comColor)
    love.graphics.print(string.format("COM Drift: %.2f", comDrift), panelX + 10, textY)
    textY = textY + 30
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Chaos Level:", panelX + 10, textY)
    textY = textY + 20
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", panelX + 10, textY, 200, 20)
    local chaosFillWidth = 200 * chaosLevel
    local r = chaosLevel
    local g = 1 - chaosLevel
    love.graphics.setColor(r, g, 0.1)
    love.graphics.rectangle("fill", panelX + 10, textY, chaosFillWidth, 20)
    textY = textY + 30
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Stability Index: %.2f", stabilityIndex), panelX + 10, textY)
    textY = textY + 30
    
    if periodicityDetected then
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.print("Periodic Orbit Detected!", panelX + 10, textY)
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Orbit Type: " .. (stabilityIndex > 0.8 and "Stable" or "Chaotic"), panelX + 10, textY)
    end
end

-- Update control panel with a Reset Simulation button and aligned toggle button
function updateControlPanel(dt)
    local panelX = windowWidth - 250
    local toggleY = 10
    local contentY = 50
    local sliderWidth = 200
    local currentYearLength = simulationYearLength or 5

    if suit.Button(controlPanelVisible and "Hide Panel" or "Show Panel", {id = "togglePanel"}, panelX, toggleY, 120, 30).hit then
        controlPanelVisible = not controlPanelVisible
    end

    if controlPanelVisible then
        suit.Label("Control Panel", {align = "left"}, panelX, contentY, 200, 20)
        suit.Label("Gravity (G): " .. string.format("%.2f", sliderG.value/100), {align = "left"}, panelX, contentY + 30, 200, 20)
        
        if suit.Slider(sliderG, panelX, contentY + 50, sliderWidth, 20, {id = "gravitySlider"}).changed then
            G = sliderG.value / 100
        end

        suit.Label("Year Length (seconds): " .. string.format("%.1f", currentYearLength), {align = "left"}, panelX, contentY + 80, 200, 20)
        local yearSlider = {value = currentYearLength * 10, min = 5, max = 100}
        if suit.Slider(yearSlider, panelX, contentY + 100, sliderWidth, 20, {id = "yearSlider"}).changed then
            simulationYearLength = yearSlider.value / 10
        end

        if suit.Button("Reset Year to 2025", {id = "resetYearButton"}, panelX, contentY + 130, 150, 30).hit then
            simulationTime = 0
        end

        if suit.Button("Add Planet", {id = "addButton"}, panelX, contentY + 170, 120, 30).hit then
            timeScale = 0
            pausedMsg = "Click to place new planet"
            addingPlanet = true
        end

        if timeScale == 0 then
            if suit.Button("Step Forward", {id = "stepButton"}, panelX, contentY + 210, 120, 30).hit then
                local savedTimeScale = constTimeScale
                timeScale = constTimeScale
                love.update(0.016)
                timeScale = 0
                pausedMsg = "Paused"
            end
        end

        if suit.Button("Reset Simulation", {id = "resetSimButton"}, panelX, contentY + 250, 150, 30).hit then
            love.load()
        end
    end
end

function love.draw()
    local yearsPassed = math.floor(simulationTime / simulationYearLength)
    local currentYear = startYear + yearsPassed

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Time Scale: " .. timeScale, 10, 10)
    love.graphics.print(pausedMsg, 10, 30)
    love.graphics.print("Current: " .. presets[currentPreset].name, 200, 10)
    love.graphics.print("Year: " .. currentYear, 400, 10)

    for _, btn in ipairs(buttons) do
        if (btn.label == presets[currentPreset].name) or 
           (btn.label == "Analytics" and showAnalytics) or
           (btn.label == "Shadow" and showShadowSystem) then
            love.graphics.setColor(0.4, 0.4, 0.7)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(1, 1, 1)
        local textWidth = love.graphics.getFont():getWidth(btn.label)
        local textHeight = love.graphics.getFont():getHeight(btn.label)
        love.graphics.print(btn.label, btn.x + (btn.w - textWidth) / 2, btn.y + (btn.h - textHeight) / 2)
    end

    if showShadowSystem and #shadowBodies > 0 then
        love.graphics.setColor(0.5, 0.5, 1, 0.3)
        for _, body in ipairs(shadowBodies) do
            love.graphics.circle("fill", body.x, body.y, body.radius)
        end
    end

    for _, b in ipairs(bodies) do
        love.graphics.setColor(1, 1, 1)
        drawBody(b)
    end
    
    for _, effect in ipairs(collisionEffects) do
        drawCollisionEffect(effect)
    end
    
    drawAnalyticsPanel()

    if hoveredBody then
        local speed = math.sqrt(hoveredBody.vx^2 + hoveredBody.vy^2)
        local details = "Name: " .. hoveredBody.name ..
                        "\nMass: " .. hoveredBody.mass ..
                        "\nSpeed: " .. string.format("%.2f", speed)
        local bx, by = windowWidth - 160, 90
        local boxW, boxH = 150, 50
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", bx, by, boxW, boxH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(details, bx + 5, by + 5)
    end
    
    if periodicityDetected then
        local notifX = windowWidth / 2 - 100
        local notifY = 50
        love.graphics.setColor(0.2, 0.6, 0.2, 0.8)
        love.graphics.rectangle("fill", notifX, notifY, 200, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Periodic Orbit Detected!", notifX + 20, notifY + 5)
    end

    suit:draw()

    if addingPlanet then
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(0.5, 1, 0.5, 0.7)
        love.graphics.circle("line", mx, my, 10)
        love.graphics.line(mx - 15, my, mx + 15, my)
        love.graphics.line(mx, my - 15, mx, my + 15)
    end
end

function love.keypressed(key)
    if suit:keypressed(key) then
        return
    end

    if key:match("%d") then
        if key == "0" then
            timeScale = 0
            pausedMsg = "Paused"
        else
            timeScale = constTimeScale * tonumber(key) * timeDirection
            pausedMsg = ""
        end
    elseif key == "a" then
        showAnalytics = not showAnalytics
    elseif key == "s" then
        showShadowSystem = not showShadowSystem
    elseif key == "r" then
        loadPreset(currentPreset)
    end
end

function love.textinput(t)
    suit:textinput(t)
end

function love.mousepressed(x, y, button)
    if suit.mousepressed and suit:mousepressed(x, y, button) then
        return
    end
    if button == 1 then
        for _, btn in ipairs(buttons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                btn.action()
                return
            end
        end

        if addingPlanet then
            addNewPlanet(x, y)
            return
        end

        startDraggingBody(x, y)
    end
end

function love.mousemoved(x, y, dx, dy)
    if suit.mousemoved and suit:mousemoved(x, y, dx, dy) then return end
    updateDraggedBody(x, y)
end

function love.mousereleased(x, y, button)
    if suit.mousereleased and suit:mousereleased(x, y, button) then return end
    if button == 1 then
        stopDraggingBody(x, y)
    end
end
