local model = require("./model.luau")

local alive = true
local view = noctalia.state.get("view")

local function settings()
  return {
    show_titles = noctalia.getConfig("show_titles") ~= false,
    label_width = noctalia.getConfig("label_width") or 160,
    show_next_event = noctalia.getConfig("show_next_event") ~= false,
  }
end

local function render()
  if not alive then return end
  local options = settings()
  local health = view and view.health or "unavailable"
  local snapshot = view and view.snapshot
  local primary = snapshot and model.primary(snapshot, options) or {
    glyph = "plug-off", label = "Samaya", meeting = false,
  }
  local live = health == "live"
  local color = live and "on_surface" or "on_surface_variant"
  local vertical = barWidget.isVertical()
  local content = {
    ui.glyph({ name = primary.glyph, size = 15, color = live and "primary" or color }),
  }

  if primary.clock then
    if vertical then
      -- A side bar is only one glyph wide. Stack the published clock's parts
      -- along the bar rather than clipping a horizontal clock to its thickness.
      for part in string.gmatch(primary.clock, "[^:]+") do
        table.insert(content, ui.label({
          text = part, fontFamily = "monospace", fontSize = 10,
          width = 22, textAlign = "center", color = color,
        }))
      end
    else
      table.insert(content, ui.label({
        text = primary.clock, fontFamily = "monospace", width = 70,
        textAlign = "center", color = color,
      }))
    end
  end

  if not vertical then
    local text = primary.title or primary.label
    if not live and not primary.clock then
      text = health == "offline" and "Samaya offline" or "Samaya unavailable"
    end
    table.insert(content, ui.label({
      text = text, maxWidth = options.label_width, maxLines = 1, color = color,
    }))
  end
  if primary.meeting then
    table.insert(content, ui.glyph({ name = "calendar-event", size = 13, color = color }))
  end
  if not live and primary.clock then
    table.insert(content, ui.glyph({ name = "alert-circle", size = 12, color = color }))
  end

  local tooltip = { "Samaya", primary.label }
  if primary.clock then table.insert(tooltip, primary.clock) end
  if primary.title then table.insert(tooltip, primary.title) end
  if primary.meeting then table.insert(tooltip, "Meeting soon") end
  if not live then
    table.insert(tooltip, health == "stale" and "Updates stopped; clock frozen" or "Disconnected; controls unavailable")
  end
  barWidget.setTooltip(table.concat(tooltip, " · "))
  local layout = vertical and ui.column or ui.row
  barWidget.render(layout({ gap = vertical and 2 or 5, align = "center" }, content))
end

function onClick()
  noctalia.togglePanel("hegdeatri/samaya:details")
end

-- Noctalia 5.3 exposes context menus only inside panels. Keep the full set
-- of actions in the attached panel, and leave middle click to host settings.
function onRightClick()
  noctalia.togglePanel("hegdeatri/samaya:details")
end

function onExit()
  alive = false
end

noctalia.state.watch("view", function(value)
  if not alive then return end
  view = value
  render()
end)
render()
