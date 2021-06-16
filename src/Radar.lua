-- Imports CPU utilities
local CPU = require('@wolfe-labs/Kernel:CPU')

-- Classes are required here
local Class = require('@wolfe-labs/Kernel:Class')

-- We also need the Math utilities
local Math = require('@wolfe-labs/Kernel:Math')

-- And the cherry on the cake, the blazing-fast JSON decoder
local JSA = require('@wolfe-labs/Kernel:JsonAnalyzer')

-- List of Core Unit sizes
local CoreSize = require('@wolfe-labs/Kernel:Data/CoreSize')

-- Gets the Core Unit
local coreUnit = CPU.core()

-- Limits maximum pings to X at one time
local maxPings = 1000

-- Enforces Core Unit existence and also gets current size for corrections
if not coreUnit then error('You must have a Core Unit linked to be able to use the radar properly') end
local coreUnitSize = CoreSize.fromCoreUnit(coreUnit)

-- The actual Radar code starts here :)
local Radar = {}

function Radar:new (radarUnit)
  self.unit = radarUnit

  -- Cache stuff about the construct so we don't have to calculate later, not sure why but by default the core unit local coords aren't centered around zero, so we also fix that here
  self.coreLocal = vec3(coreUnit.getElementPositionById(coreUnit.getId())) - (coreUnitSize.center * 2)
  self.radarLocal = vec3(coreUnit.getElementPositionById(radarUnit.getId())) - (coreUnitSize.center * 2)

  -- This variable stores previous scan info per construct ID
  self.pings = {}

  -- Ping count
  self.pingCount = 0

  -- Last scan
  self.lastScan = nil
end

function Radar:scan (maxRange)
  -- This is the scan results
  local scanResults = {}

  -- Default range = 5000
  if not maxRange then maxRange = 5000 end

  -- The position of the scan (radar unit) and of the construct
  local posScan = Math.convertLocalToWorldPosition(coreUnit, self.radarLocal)
  local posShip = vec3(coreUnit.getConstructWorldPos())
  local rawData = self.unit.getData()
  local rawTime = system.getTime()
  local velAngular = vec3(coreUnit.getWorldAngularVelocity())

  -- Does the scan
  local hits = JSA.extractEntities(
    JSA.extractAllKeys(
      rawData,
      true
    ).constructsList
  )

  -- Metadata about current scan
  local currentScan = {
    time = rawTime,
    pos = posScan,
  }

  -- If no previous scan, use current as base
  local lastDistance = nil
  if self.prevScan then
    lastDistance = self.prevScan.pos:dist(currentScan.pos)
  else
    self.prevScan = currentScan
  end
      
  -- Estimates how much we rotated away from the last position
  local drift = velAngular * (currentScan.time - self.prevScan.time)
  local driftAmount = vec3({ 0, 0, 0 }):dist(drift)
  local driftWeight = math.min(1, (1 + driftAmount) ^ 720 - 1)

  system.print('LSD: ' .. lastDistance)

  -- Estimates how far we're from last scan, only do it again if at minimum distance away
  local allowScanning = (lastDistance > 4 or lastDistance == nil) and not (driftAmount and driftAmount > 0.0005)

  -- Processes each of the hits
  for _, hit in pairs(hits) do
    -- Prevents overheating
    CPU.tick(75)

    -- If not a construct, skip
    if hit and hit.constructId and hit.distance <= maxRange then
      -- Caches the construct ID
      local id = string.format('_%d', hit.constructId)

      -- Consider if we should add an extra ping
      if not self.pings[id] then
        self.pingCount = self.pingCount + 1

        -- Prevents memory overflow
        if self.pingCount > maxPings then
          self.pings = {}
          self.pingCount = 0
          break
        end
      end

      -- In case of new radar entry, add it to list
      local ping = self.pings[id] or {
        id = hit.constructId,
        name = hit.name,
        size = hit.size,
        pos = nil,
        hist = {},
        hits = {},
      }

      -- If we're drifting around then don't do anything
      if allowScanning then
        -- This will keep only the last four pings so we can do trilateration properly
        ping.hits[4] = nil
        ping.hits[4] = ping.hits[3]
        ping.hits[3] = ping.hits[2]
        ping.hits[2] = ping.hits[1]
        ping.hits[1] = {
          scan = currentScan,
          dist = hit.distance
        }

        -- Are we ready for trilateration?
        if 4 == #ping.hits then
          local result = Math.trilaterate(
            ping.hits[1].scan.pos, ping.hits[1].dist,
            ping.hits[2].scan.pos, ping.hits[2].dist,
            ping.hits[3].scan.pos, ping.hits[3].dist,
            ping.hits[4].scan.pos, ping.hits[4].dist
          );

          -- Ignores any invalid nan values
          if result and not (Math.isNaN(result.x) or Math.isNaN(result.y) or Math.isNaN(result.z)) then
            -- Moves average up
            ping.hist[4] = ping.hist[3]
            ping.hist[3] = ping.hist[2]
            ping.hist[2] = ping.hist[1]

            -- Saves current position
            ping.hist[1] = { w = 1 - driftWeight, p = result }

            -- Averages over time
            local zero = vec3(0, 0, 0)
            local normalizer = 1 / (ping.hist[1].w
              + (ping.hist[2] and ping.hist[2].w or 0)
              + (ping.hist[3] and ping.hist[3].w or 0)
              + (ping.hist[4] and ping.hist[4].w or 0)
            )
            ping.pos = normalizer * ((ping.hist[1].w * ping.hist[1].p)
              + (ping.hist[2] and (ping.hist[2].w * ping.hist[2].p) or zero)
              + (ping.hist[3] and (ping.hist[3].w * ping.hist[3].p) or zero)
              + (ping.hist[4] and (ping.hist[4].w * ping.hist[4].p) or zero)
            )

            -- if ping.pos then
            --   -- Weighted average of previous point and current point
            --   ping.pos = (1 - driftWeight) * result + driftWeight * ping.pos
            -- else
            --   -- Save current point
            --   ping.pos = result
            -- end
          end
        end
      end

      -- Results processing
      if ping.pos then
        table.insert(scanResults, {
          id = hit.constructId,
          name = hit.name,
          dist = hit.distance,
          size = hit.size,
          pos = ping.pos,
        })
      end

      -- Updates ping info
      self.pings[id] = ping
    end
  end

  -- Updates previous scan
  self.prevScan = currentScan

  -- Done
  return scanResults
end

function Radar:localize (scanResults)
  local vertical = ((coreUnit.g() > 0) and (-1 * vec3(coreUnit.getWorldVertical()))) or vec3(coreUnit.getConstructWorldOrientationUp())
  local forward = vec3(coreUnit.getConstructWorldOrientationForward())
  local right = vec3(coreUnit.getConstructWorldOrientationRight())
  local axis = {
    up = vertical,
    right = right,
    forward = forward,
  }

  -- system.print(string.format('V = %.3f, %.3f, %.3f', vertical.x, vertical.y, vertical.z))
  -- system.print(string.format('F = %.3f, %.3f, %.3f', forward.x, forward.y, forward.z))
  -- system.print(string.format('R = %.3f, %.3f, %.3f', right.x, right.y, right.z))

  for _, result in pairs(scanResults) do
    CPU.tick(200)
    -- scanResults[_].posLocal = result.pos - vec3(coreUnit.getConstructWorldPos())
    scanResults[_].posLocal = Math.convertWorldToLocalPosition(
      coreUnit,
      result.pos,
      axis
    )
  end
end

return Class('Radar', { prototype = Radar }).new