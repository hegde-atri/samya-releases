-- Pure schema, presentation and command model. No clock, process or host access.
-- Optional action target tables capture IDs at render time; stale targets reject.
local M = {}

local function integer(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

local function text(value)
    return type(value) == "string" and utf8.len(value) ~= nil
end

local function id(value)
    return text(value) and #value > 0
end

local function displayTitle(value)
    if not text(value) then return false end
    return utf8.len(value) <= 200
end

local function booleans(value, fields)
    for _, key in ipairs(fields) do
        if type(value[key]) ~= "boolean" then return false end
    end
    return true
end

local function array(value, limit)
    if type(value) ~= "table" or #value > limit then return false end
    local count = 0
    for key in pairs(value) do
        if not integer(key) or key < 1 or key > #value then return false end
        count = count + 1
    end
    return count == #value
end

local function focusValid(f)
    if type(f) ~= "table" or not id(f.session_id) or not id(f.task_id)
        or not id(f.phase_id) or not displayTitle(f.title)
        or not integer(f.elapsed_seconds)
        or not booleans(f, {"can_pause", "can_resume", "can_end", "can_start_next_phase"}) then
        return false
    end
    if f.state ~= "running" and f.state ~= "paused" and f.state ~= "waiting"
        and f.state ~= "ending" then return false end
    if f.save_state ~= "idle" and f.save_state ~= "saving" and f.save_state ~= "failed" then
        return false
    end
    if f.phase ~= "focus" and f.phase ~= "break" and f.phase ~= "long_break" then
        return false
    end
    if f.mode == "stopwatch" then
        if f.remaining_seconds ~= nil or f.phase ~= "focus" or f.state == "waiting" then
            return false
        end
    elseif f.mode == "pomodoro" then
        if not integer(f.remaining_seconds) then return false end
    else
        return false
    end
    local ready = f.save_state == "idle" and f.state ~= "ending"
    if f.can_pause and (not ready or f.state ~= "running") then return false end
    if f.can_resume and (not ready or f.state ~= "paused") then return false end
    if f.can_start_next_phase and (not ready or f.state ~= "waiting" or f.mode ~= "pomodoro") then
        return false
    end
    -- Failed End may be explicitly retried with retained write identities.
    if f.can_end and f.save_state == "saving" then return false end
    return true
end

local function eventsValid(rows, identities)
    if not array(rows, 16) then return false end
    for _, event in ipairs(rows) do
        if type(event) ~= "table" or not id(event.occurrence_id)
            or not displayTitle(event.title) or not id(event.starts_at) or not id(event.ends_at)
            or not booleans(event, {"imminent", "can_join"}) then return false end
        if identities[event.occurrence_id] then return false end
        identities[event.occurrence_id] = true
    end
    return true
end

-- JSON null values must be decoded as nil before calling this function.
-- Timestamps and IDs remain opaque: no Join calculations or UUID assumptions.
function M.validate(snapshot)
    if type(snapshot) ~= "table" or snapshot.schema_version ~= 1 then
        return false, "Unsupported desktop state schema"
    end
    if type(snapshot.connected) ~= "boolean" or not id(snapshot.observed_at)
        or snapshot.join_lead_seconds ~= 300
        or not integer(snapshot.omitted_current) or not integer(snapshot.omitted_upcoming)
        or type(snapshot.can_start_focus) ~= "boolean"
        or (snapshot.reason ~= nil and not text(snapshot.reason)) then
        return false, "Invalid desktop state fields"
    end
    if snapshot.connected then
        if not id(snapshot.instance_id) or snapshot.reason ~= nil then
            return false, "Invalid connected desktop identity"
        end
    elseif snapshot.instance_id ~= nil or not id(snapshot.reason) then
        return false, "Invalid offline desktop identity"
    end
    local identities = {}
    if not eventsValid(snapshot.current_events, identities)
        or not eventsValid(snapshot.upcoming_events, identities) then
        return false, "Invalid desktop event rows"
    end
    if snapshot.focus ~= nil and not focusValid(snapshot.focus) then
        return false, "Invalid Focus state"
    end
    if snapshot.focus ~= nil and snapshot.can_start_focus then
        return false, "Focus start conflicts with an existing session"
    end
    local block = snapshot.current_block
    if block ~= nil and (type(block) ~= "table" or not id(block.task_id)
        or not displayTitle(block.title) or not integer(block.remaining_seconds)) then
        return false, "Invalid scheduled work"
    end
    local sync = snapshot.sync
    if type(sync) ~= "table" or not booleans(sync, {"paused", "can_sync_now", "can_pause", "can_resume"})
        or (sync.summary ~= nil and not displayTitle(sync.summary)) then
        return false, "Invalid sync state"
    end
    if (sync.can_pause and sync.paused) or (sync.can_resume and not sync.paused) then
        return false, "Conflicting sync capabilities"
    end
    if not snapshot.connected and (snapshot.focus ~= nil or block ~= nil
        or #snapshot.current_events > 0 or #snapshot.upcoming_events > 0
        or snapshot.omitted_current ~= 0 or snapshot.omitted_upcoming ~= 0
        or snapshot.can_start_focus or sync.can_sync_now or sync.can_pause or sync.can_resume) then
        return false, "Offline state contains operational data"
    end
    return true
end

function M.clock(seconds)
    if not integer(seconds) then return "--:--" end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    local rest = seconds % 60
    if hours > 0 then return string.format("%.0f:%02d:%02d", hours, minutes, rest) end
    return string.format("%02d:%02d", minutes, rest)
end

-- width, when supplied, counts Unicode scalar values rather than bytes.
function M.title(raw, show, fallback, width)
    if show == false then return fallback end
    local value = text(raw) and raw or fallback
    if value == nil then return nil end
    if integer(width) and width > 0 and utf8.len(value) > width then
        if width == 1 then return "…" end
        return string.sub(value, 1, utf8.offset(value, width) - 1) .. "…"
    end
    return value
end

local function upcomingMeeting(snapshot)
    for _, event in ipairs(snapshot.upcoming_events or {}) do
        if event.imminent then return event end
    end
    return nil
end

function M.primary(snapshot, settings)
    settings = settings or {}
    if type(snapshot) ~= "table" or snapshot.connected ~= true then
        return {glyph = "plug-off", label = "Samaya offline", state = "offline", meeting = false}
    end
    local imminent = upcomingMeeting(snapshot)
    local f = snapshot.focus
    if f then
        local glyph, label = "target", "Focus"
        if f.phase ~= "focus" then label = f.phase == "long_break" and "Long break" or "Break" end
        if f.state == "paused" then glyph, label = "player-pause", "Paused"
        elseif f.state == "waiting" then
            glyph, label = "hourglass", f.phase == "focus" and "Ready for Focus" or "Ready for break"
        end
        if f.state == "ending" or f.save_state == "saving" then glyph, label = "device-floppy", "Saving" end
        if f.save_state == "failed" then glyph, label = "alert-circle", "Save failed" end
        return {
            glyph = glyph, label = label, state = f.state, meeting = imminent ~= nil,
            clock = M.clock(f.mode == "pomodoro" and f.remaining_seconds or f.elapsed_seconds),
            title = M.title(f.title, settings.show_titles, nil),
        }
    end
    local event = snapshot.current_events[1] or imminent
    if event then
        return {
            glyph = "calendar-event", label = snapshot.current_events[1] and "Meeting" or "Upcoming meeting",
            state = "event", meeting = imminent ~= nil,
            title = M.title(event.title, settings.show_titles, nil),
        }
    end
    local block = snapshot.current_block
    if block then
        return {
            glyph = "clock", label = "Scheduled work", clock = M.clock(block.remaining_seconds),
            state = "block", meeting = false, title = M.title(block.title, settings.show_titles, nil),
        }
    end
    if settings.show_next_event ~= false and snapshot.upcoming_events[1] then
        return {
            glyph = "calendar-event", label = "Next event", state = "next_event", meeting = false,
            title = M.title(snapshot.upcoming_events[1].title, settings.show_titles, nil),
        }
    end
    return {glyph = "circle-dashed", label = "Samaya", state = "idle", meeting = false}
end

local focusActions = {pause = "can_pause", resume = "can_resume", ["end"] = "can_end", next_phase = "can_start_next_phase"}
local syncActions = {sync_now = "can_sync_now", pause_sync = "can_pause", resume_sync = "can_resume"}
local syncCommands = {sync_now = "sync-now", pause_sync = "pause-sync", resume_sync = "resume-sync"}

function M.action(snapshot, kind, target)
    local valid, reason = M.validate(snapshot)
    if not valid then return nil, reason end
    if not snapshot.connected then return nil, "Samaya is offline" end
    if target ~= nil and type(target) ~= "table" then return nil, "Invalid action target" end
    target = target or {}
    if focusActions[kind] then
        local f = snapshot.focus
        if not f or not f[focusActions[kind]] then return nil, "Focus action unavailable" end
        if target.session_id ~= nil and target.session_id ~= f.session_id then
            return nil, "Session changed"
        end
        if kind == "next_phase" then
            if target.phase_id ~= nil and target.phase_id ~= f.phase_id then return nil, "Phase changed" end
            return {"samaya", "focus", "start-next-phase", "--session", f.session_id, "--phase", f.phase_id}
        end
        return {"samaya", "focus", kind, "--session", f.session_id}
    elseif syncActions[kind] then
        if not snapshot.sync[syncActions[kind]] then return nil, "Sync action unavailable" end
        return {"samaya", "desktop", syncCommands[kind]}
    elseif kind == "start" then
        local block = snapshot.current_block
        if not snapshot.can_start_focus or not block then return nil, "No available Focus task" end
        if target.task_id ~= nil and target.task_id ~= block.task_id then return nil, "Scheduled task changed" end
        return {"samaya", "focus", "start", "--", block.task_id}
    elseif kind == "open_task" then
        local taskId = target.task_id or (snapshot.focus and snapshot.focus.task_id)
            or (snapshot.current_block and snapshot.current_block.task_id)
        if taskId == nil or not ((snapshot.focus and snapshot.focus.task_id == taskId)
            or (snapshot.current_block and snapshot.current_block.task_id == taskId)) then
            return nil, "Task changed"
        end
        return {"samaya", "desktop", "open-task", "--", taskId}
    elseif kind == "join" then
        if not id(target.occurrence_id) then return nil, "Meeting target required" end
        for _, rows in ipairs({snapshot.current_events, snapshot.upcoming_events}) do
            for _, event in ipairs(rows) do
                if event.occurrence_id == target.occurrence_id and event.can_join then
                    return {"samaya", "event", "join", "--", event.occurrence_id}
                end
            end
        end
        return nil, "Meeting is no longer joinable"
    end
    return nil, "Unknown desktop action"
end

return M
