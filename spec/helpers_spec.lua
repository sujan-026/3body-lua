-- Busted unit tests for helper functions
local _G = _G

-- Stub minimal Love2D and Suit modules for tests
love = {
  graphics = {
    getWidth = function() return 800 end,
    getHeight = function() return 600 end,
    newImage = function() return {} end
  }
}
_G.love = love
package.loaded['suit'] = {}

dofile('main.lua')

describe('helper functions', function()
  describe('computeRadius', function()
    it('computes radius proportional to cube root of mass', function()
      assert.is_true(math.abs(computeRadius(8) - 5 * 2) < 1e-6)
      assert.is_true(math.abs(computeRadius(27) - 5 * 3) < 1e-6)
    end)
  end)

  describe('calculateKineticEnergy', function()
    it('computes kinetic energy correctly', function()
      local body = { mass = 2, vx = 3, vy = 4 }
      local expected = 0.5 * 2 * (3*3 + 4*4)
      assert.are.equal(expected, calculateKineticEnergy(body))
    end)
  end)

  describe('calculatePotentialEnergy', function()
    it('computes potential energy based on distance', function()
      local body1 = { mass = 5, x = 0, y = 0 }
      local body2 = { mass = 10, x = 0, y = 10 }
      local distance = 10
      local expected = -G * body1.mass * body2.mass / distance
      assert.are.equal(expected, calculatePotentialEnergy(body1, body2))
    end)
  end)
end)
