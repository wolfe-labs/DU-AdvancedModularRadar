-- Imports CPU utilities
local CPU = require('@wolfe-labs/Kernel:CPU')

-- List of Core Unit sizes
local CoreSize = require('@wolfe-labs/Kernel:Data/CoreSize')

-- Current Core Unit
-- local coreUnit = CPU.core()
--getWorldVertical()

local function renderUI (scanResults, maxDistance)
  local header = '<style type="text/css">#radar { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 100vh; height: 100vh; border-radius: 100vh; overflow:hidden; background: #121; } #dots { position: relative; width: 100%; height: 100%; } #dots div { position: absolute; width: 1em; height: 1em; border-radius: 1em; font-size: 1vh; transform: translate(-50%, -50%); }</style>'
  local dots = {}

  for _, result in pairs(scanResults) do
    local x = 50 + 50 * (result.posLocal.x / maxDistance)
    local y = 50 - 50 * (result.posLocal.y / maxDistance)

    local color = 'rgb(80,230,230)'
    local layer = 5
    if 'S' == result.size then
      color = 'rgb(230,230,80)'
      layer = 4
    elseif 'M' == result.size then
      color = 'rgb(250,180,80)'
      layer = 3
    elseif 'L' == result.size then
      color = 'rgb(120,120,120)'
      layer = 2
    elseif 'XL' == result.size then
      color = 'purple'
      layer = 1
    end
    
    local size = math.min(100, math.max(1, 100 * CoreSize[result.size].diagonal / maxDistance))
    table.insert(dots, string.format('<div style="top:%.2f%%;left:%.2f%%;font-size:%.2fvh;background:%s;z-index:%d;"></div>', y, x, size, color, layer))
    -- system.print(string.format('x: %.2f%%, y:%.2f%%, size: %.2f%%: %s', x, y, size, result.name))
  end
  return string.format('%s<div id="radar"><div id="dots">%s</div></div>', header, table.concat(dots, ''))
end

return renderUI