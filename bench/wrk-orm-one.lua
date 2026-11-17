math.randomseed(os.time())
request = function()
  return wrk.format("GET", "/orm/" .. math.random(1, 1000))
end
