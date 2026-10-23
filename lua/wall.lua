-- Agent Wall: every tab of the session you're looking at tiled into one grid tab, to see all your agents working at
-- once. Run it again to put each back in its own tab, named as before. The work is bin/rex-wall, beside this folder.
--
--   require("agent-kit.wall"){ key = "cmd+shift+a" }

-- Rex names a module by its path (no "@" in front, unlike plain Lua).
local dir = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(/.*)/[^/]*$")
local WALL = dir and dir .. "/../bin/rex-wall" or os.getenv("HOME") .. "/.local/bin/rex-wall"

return function(opts)
  opts = opts or {}
  local name = opts.name or "agent_wall"
  rex.action{
    name        = name,
    title       = opts.title or "Agent Wall",
    description = "Tile every tab of this session into one grid, or put them back in their own tabs",
    keywords    = "wall grid tile agents claude all tabs",
    run         = function(ctx, args)
      if ctx.session_id == nil then error("Agent Wall: open a session first", 0) end
      local r, err = rex.exec({ opts.bin or WALL, "-s", ctx.session_id }, { timeout = 60 })
      if r == nil then error(err, 0) end
      if not r.ok then error(r.stderr ~= "" and r.stderr or r.stdout, 0) end
      return { message = r.stdout }
    end,
  }
  if opts.key then rex.bind(opts.key, name) end
end
