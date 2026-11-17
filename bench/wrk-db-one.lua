-- A different random row (1..1000) on every request.
math.randomseed(os.time())
request = function()
  return wrk.format("GET", "/db/" .. math.random(1, 1000))
end
