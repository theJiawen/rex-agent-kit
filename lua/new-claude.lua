-- New Claude: a new tab with Claude Code started, in the session you're looking at, so Cmd+1…9 switches between your
-- agents. It starts in opts.dir, or else where the pane you pressed the key in is. With no session shown, it uses the
-- session labeled opts.session (made when missing). The command is typed into a login shell, so your aliases and PATH
-- apply, and the shell stays when Claude exits.
--
--   require("agent-kit.new-claude"){ key = "cmd+shift+c" }
--   require("agent-kit.new-claude"){ key = "cmd+shift+c", dir = "~/code/my-project", session = "work" }

local SHELL = "com.superlogical.terminal.shell"
local TERMINAL = "com.superlogical.terminal"

local function expand(path)
  if path and path:sub(1, 1) == "~" then return os.getenv("HOME") .. path:sub(2) end
  return path
end

-- Where the pane the key was pressed in is: what its shell last reported, else where its program runs.
local function here(ctx)
  if ctx.block_id == nil then return nil end
  local r = rex.block.call(TERMINAL, "pwd", {})
  if r and r.pwd then
    return (r.pwd:gsub("^file://[^/]*", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
  end
  r = rex.block.call(TERMINAL, "process", {})
  if r and r.foreground and r.foreground.cwd then return r.foreground.cwd end
end

return function(opts)
  opts = opts or {}
  local name = opts.name or "new_claude"
  rex.action{
    name        = name,
    title       = opts.title or "New Claude",
    description = "A new tab in this session with Claude started",
    keywords    = "claude agent new tab",
    run         = function(ctx, args)
      local cwd = expand(opts.dir) or here(ctx) or os.getenv("HOME")
      local layout = rex.layout.block{ flavor = SHELL, options = { cwd = cwd, initial_input = (opts.command or "claude") .. "\n" } }
      local label = opts.label or "claude"
      local session = ctx.session_id
      if session == nil then
        local list = rex.call("session.list") or {}
        for _, s in ipairs(list.sessions or {}) do
          if s.label == (opts.session or "claude") then session = s.session_id end
        end
      end
      local window, err
      if session == nil then
        local s
        s, err = rex.call("session.create", { label = opts.session or "claude", initial_windows = { { layout = layout, window_label = label } } })
        if err == nil then session = s.session_id end
      else
        local w
        w, err = rex.call("session.new_window", { session_id = session, window_label = label, layout = layout })
        if err == nil then window = w.window_id end
      end
      if err ~= nil then error(err, 0) end
      rex.client.queue("session.select", { session_id = session, window_id = window })
      return { session_id = session, window_id = window }
    end,
  }
  if opts.key then rex.bind(opts.key, name) end
end
