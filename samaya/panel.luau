local model = require("./model.luau")

local alive = true
local opened = false
local request_number = 0
local view = noctalia.state.get("view")
local action = noctalia.state.get("action")

local function settings()
  return {
    show_titles = noctalia.getConfig("show_titles") ~= false,
    label_width = noctalia.getConfig("label_width") or 160,
    show_next_event = noctalia.getConfig("show_next_event") ~= false,
  }
end

local function request(kind, target)
  if not alive then return end
  request_number = request_number + 1
  noctalia.state.set("request", {
    kind = kind, target = target,
    token = tostring(noctalia.nowMs()) .. ":" .. tostring(request_number),
  })
end

local function button(text, glyph, kind, target, enabled, variant, key)
  return ui.button({
    key = key or kind, text = text, glyph = glyph, controlSize = "sm",
    variant = variant or "outline", enabled = enabled,
    onClick = function() request(kind, target) end,
  })
end

local function label(text, props)
  local value = props or {}
  value.text = text
  return ui.label(value)
end

local function heading(text)
  return label(text, { fontWeight = "semibold", fontSize = 13 })
end

local function time_of_day(value)
  -- Samaya exports local observation times. This extracts their published
  -- display component; it does not compute eligibility or a meeting countdown.
  return string.match(value, "T(%d%d:%d%d)")
    or string.match(value, " (%d%d:%d%d)") or ""
end

local function event_row(event, options, enabled, prefix)
  local title = model.title(event.title, options.show_titles, "Calendar event")
  local times = time_of_day(event.starts_at) .. " – " .. time_of_day(event.ends_at)
  local body = {
    ui.column({ gap = 3, flexGrow = 1 }, {
      label(title, { maxWidth = 280, maxLines = 1 }),
      label(times, { color = "on_surface_variant", fontSize = 12 }),
    }),
  }
  if event.can_join then
    table.insert(body, button("Join", "video", "join", {
      occurrence_id = event.occurrence_id,
    }, enabled, "primary", prefix .. ":join:" .. event.occurrence_id))
  end
  return ui.row({
    key = prefix .. ":" .. event.occurrence_id,
    gap = 10, align = "center", paddingV = 7,
  }, body)
end

local function render()
  if not alive or not opened then return end
  local options = settings()
  local snapshot = view and view.snapshot
  local live = view and view.health == "live" and snapshot ~= nil
  local launch = view and view.launch_available == true
  local pending = action and action.status == "pending"
  local enabled = live and not pending
  local health = view and view.health or "unavailable"
  local status_text = ({ live = "Connected", offline = "Offline", stale = "Updates stopped", unavailable = "Unavailable" })[health]
    or "Unavailable"
  local rows = {
    ui.row({ align = "center", justify = "space_between" }, {
      label("Samaya", { fontSize = 20, fontWeight = "semibold" }),
      label(status_text, { color = live and "primary" or "on_surface_variant", fontSize = 12 }),
    }),
    ui.row({ gap = 8 }, {
      button("Add a task", "plus", "compose", nil, launch, "primary"),
      button("Open Samaya", "external-link", "open", nil, launch),
    }),
  }

  if not live then
    local description = health == "stale"
      and "The last clock is frozen. Focus, Join and sync controls are unavailable until updates resume."
      or "Open Samaya to reconnect. Focus, Join and sync controls require the running desktop app."
    -- Service health explanations are fixed diagnostics, not task/event titles.
    -- Keep PATH/build troubleshooting available even when titles are concealed.
    if view and view.reason then
      description = view.reason .. "\n" .. description
    end
    table.insert(rows, label(description, { maxWidth = 372, maxLines = 5, color = "on_surface_variant", fontSize = 12 }))
  end

  if action and action.status then
    local messages = {
      pending = "Working…", ok = "Done", rejected = "Action rejected",
      failed = "Action failed", unknown = "Result unknown; the operation may still complete",
    }
    local message = messages[action.status] or "Action unavailable"
    if options.show_titles and action.label then message = action.label .. ": " .. message end
    if options.show_titles and action.reason then message = message .. "\n" .. action.reason end
    if action.status == "failed" or action.status == "unknown" then
      message = message .. "\nOpen Samaya to check and recover."
    end
    table.insert(rows, label(message, {
      key = "action-feedback", maxWidth = 372, maxLines = 5,
      color = action.status == "ok" and "primary" or "on_surface_variant", fontSize = 12,
    }))
  end

  local contents = {}
  if snapshot and snapshot.focus then
    local focus = snapshot.focus
    local target = { session_id = focus.session_id, phase_id = focus.phase_id, task_id = focus.task_id }
    local primary = model.primary(snapshot, options)
    local phase_names = { focus = "Focus", ["break"] = "Break", long_break = "Long break" }
    local clock = focus.mode == "pomodoro" and focus.remaining_seconds or focus.elapsed_seconds
    local details = {
      ui.row({ justify = "space_between", align = "center" }, {
        heading(primary.label),
        label(model.clock(clock or 0), { fontFamily = "monospace", fontSize = 24, color = live and "primary" or "on_surface_variant" }),
      }),
      label(model.title(focus.title, options.show_titles, "Focus task"), { maxWidth = 342, maxLines = 2 }),
      label(focus.mode == "pomodoro" and (phase_names[focus.phase] or "Pomodoro") or "Elapsed time", {
        color = "on_surface_variant", fontSize = 12,
      }),
    }
    if focus.save_state == "failed" then
      table.insert(details, label("The save failed. Your session is retained; retry the save or open Samaya.", {
        maxWidth = 342, maxLines = 3, color = "on_surface_variant", fontSize = 12,
      }))
    elseif focus.save_state == "saving" or focus.state == "ending" then
      table.insert(details, label("Saving your session…", { color = "on_surface_variant", fontSize = 12 }))
    end
    local controls = {}
    if focus.can_pause then table.insert(controls, button("Pause", "player-pause", "pause", target, enabled)) end
    if focus.can_resume then table.insert(controls, button("Resume", "player-play", "resume", target, enabled, "primary")) end
    if focus.can_start_next_phase then
      table.insert(controls, button("Start next phase", "player-play", "next_phase", target, enabled, "primary"))
    end
    if focus.can_end then
      table.insert(controls, button(focus.save_state == "failed" and "Retry save" or "End", "square", "end", target, enabled))
    end
    if #controls > 0 then table.insert(details, ui.row({ gap = 8 }, controls)) end
    table.insert(details, button("Open task", "external-link", "open_task", target, enabled, "ghost"))
    table.insert(contents, ui.column({ key = "focus", gap = 8, padding = 12, fill = "surface_variant", radius = 12 }, details))
  end

  if snapshot and snapshot.current_block then
    local block = snapshot.current_block
    local target = { task_id = block.task_id }
    local controls = { button("Open task", "external-link", "open_task", target, enabled, "ghost", "block-open") }
    if snapshot.can_start_focus then
      table.insert(controls, button("Start Focus", "player-play", "start", target, enabled, "primary"))
    end
    table.insert(contents, ui.column({ key = "block", gap = 7 }, {
      heading("Scheduled work"),
      label(model.title(block.title, options.show_titles, "Scheduled task"), { maxWidth = 364, maxLines = 1 }),
      label(model.clock(block.remaining_seconds) .. " scheduled time left", { color = "on_surface_variant", fontSize = 12 }),
      ui.row({ gap = 8 }, controls),
    }))
  end

  if snapshot then
    if #snapshot.current_events > 0 then
      table.insert(contents, heading("Current events"))
      for _, event in ipairs(snapshot.current_events) do
        table.insert(contents, event_row(event, options, enabled, "current"))
      end
    end
    if #snapshot.upcoming_events > 0 then
      table.insert(contents, heading("Later today"))
      for _, event in ipairs(snapshot.upcoming_events) do
        table.insert(contents, event_row(event, options, enabled, "upcoming"))
      end
    end
    local omitted = snapshot.omitted_current + snapshot.omitted_upcoming
    if omitted > 0 then
      table.insert(contents, button(tostring(omitted) .. " more events · Open Samaya", "external-link", "open", nil, launch, "ghost", "overflow"))
    end
    if not snapshot.focus and not snapshot.current_block and #snapshot.current_events == 0 and #snapshot.upcoming_events == 0 then
      table.insert(contents, label("No Focus session or meetings to show.", { maxWidth = 364, color = "on_surface_variant" }))
    end
    table.insert(contents, ui.separator({ spacing = 4 }))
    local sync = snapshot.sync
    table.insert(contents, heading("Calendar sync"))
    local sync_summary = options.show_titles and sync.summary or nil
    table.insert(contents, label(sync_summary or (sync.paused and "Paused" or "Automatic sync"), {
      maxWidth = 364, maxLines = 2, color = "on_surface_variant", fontSize = 12,
    }))
    local sync_controls = {}
    if sync.can_sync_now then table.insert(sync_controls, button("Sync now", "refresh", "sync_now", nil, enabled)) end
    if sync.can_pause then table.insert(sync_controls, button("Pause sync", "player-pause", "pause_sync", nil, enabled)) end
    if sync.can_resume then table.insert(sync_controls, button("Resume sync", "player-play", "resume_sync", nil, enabled)) end
    if #sync_controls > 0 then table.insert(contents, ui.row({ gap = 8 }, sync_controls)) end
  end

  table.insert(rows, ui.scroll({ key = "details", gap = 12, flexGrow = 1 }, contents))
  panel.render(ui.column({ gap = 12, padding = 4, flexGrow = 1, fill = "surface/1.0" }, rows))
end

function onOpen()
  view = noctalia.state.get("view")
  action = noctalia.state.get("action")
  opened = true
  render()
end

function onClose()
  opened = false
end

function onExit()
  alive = false
  opened = false
end

noctalia.state.watch("view", function(value)
  if not alive then return end
  view = value
  render()
end)
noctalia.state.watch("action", function(value)
  if not alive then return end
  action = value
  render()
end)
