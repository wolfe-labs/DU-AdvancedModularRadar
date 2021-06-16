if radar_1 then
  local trace = traceback or (debug and debug.traceback) or function (a, b) return a or b end
  local range = 5000

  if not AMORAD then
    local Radar = require('@wolfe-labs/AMORAD:Radar')
    AMORAD = Radar(radar_1)
  end
  
  if not coroutineRadar or 'dead' == coroutine.status(coroutineRadar) then
    coroutineRadar = coroutine.create(function ()
      -- system.print('Working...')
      local results = AMORAD:scan(range)
      -- system.print('Adding local coordinates...')
      AMORAD:localize(results)
      -- system.print('Found ' .. #results .. ' results!')
      local RadarUI = require('@wolfe-labs/AMORAD:UI/Simple2D')
      radarScreen.setHTML(RadarUI(results, range))
    end)
  end

  -- Error handling
  status, message = coroutine.resume(coroutineRadar)
  if false == status then
    error(string.format('Coroutine error: %s\n:%s ', message, trace(coroutineRadar)))
  end
end