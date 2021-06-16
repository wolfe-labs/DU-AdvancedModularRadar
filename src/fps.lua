local screens = library.getLinksByClass('ScreenUnit')
local storage = library.getLinksByClass('DataBankUnit')

test = 0

function DrawRadar ()
  for _, screen in pairs(screens) do
    screen.setHTML('<div style="font-family:sans-serif;font-size:10vh;position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);">Test: ' .. test .. '</div>')
  end
  test = 0
end

unit:onEvent('tick', function ()
  DrawRadar()
end)
unit.setTimer('refresh', 1.000)

system:onEvent('update', function ()
  test = test + 1
end)