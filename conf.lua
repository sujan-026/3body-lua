function love.conf(t)
    t.window.title = "Orbital Simulation - Year: 2025"  -- Set a descriptive window title
    t.window.width = 1280                              -- Default width: increased from 800
    t.window.height = 720                              -- Default height: increased from 600
    t.window.resizable = true                          -- Enable window resizing
    t.window.minwidth = 1024                           -- Increased minimum width
    t.window.minheight = 700                           -- Increased minimum height
    t.window.vsync = true                              -- Enable vertical sync
    t.window.display = 1                               -- Use primary display
    
    -- Set app identity information
    t.identity = "OrbitSimulation"                     -- Used for save directory
    
    -- Set other LÖVE configurations
    t.modules.audio = true
    t.modules.joystick = false                         -- Disable joystick module if not needed
    t.modules.physics = false                          -- Disable physics module (we use custom physics)
    t.modules.video = false                            -- Disable video module if not needed
end