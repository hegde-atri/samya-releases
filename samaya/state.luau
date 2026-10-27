-- This service is the only owner of the watcher and operational subprocesses.
-- Noctalia owns its update timer, subscriptions and the stream's process group.
local model = require("./model.luau")
local disposed = false
local active = false
local last_valid = noctalia.nowMs()
local restart_at = 0
local retry_seconds = 5
local generation = 0
local chunks = nil
local frame_bytes = 0
local busy = nil
local view = { health = "unavailable", reason = "Connecting to Samaya", launch_available = false }

local labels = {
    pause = "Pause Focus", resume = "Resume Focus", ["end"] = "End Focus",
    next_phase = "Start next phase", start = "Start Focus", open_task = "Open task",
    join = "Join meeting", sync_now = "Sync now", pause_sync = "Pause sync",
    resume_sync = "Resume sync", open = "Open Samaya", compose = "Add a task",
}

local function publish()
    if not disposed then noctalia.state.set("view", view) end
end

local function unavailable(reason, health)
    view.health = health or "unavailable"
    view.reason = reason
    publish()
end

local function accept_frame(raw)
    local ok, snapshot = pcall(noctalia.json.decode, raw)
    if not ok then
        unavailable("Invalid Samaya status data")
        return
    end
    local valid, reason = model.validate(snapshot)
    if not valid then
        unavailable(reason or "Unsupported Samaya status data")
        return
    end
    last_valid = noctalia.nowMs()
    retry_seconds = 5
    -- Even an offline schema-v1 frame proves this is a compatible GUI build.
    view.launch_available = true
    view.snapshot = snapshot
    view.health = snapshot.connected and "live" or "offline"
    view.reason = snapshot.reason
    publish()
end

local function on_line(line)
    if disposed or not active then return end
    if line == "B" then
        chunks = {}
        frame_bytes = 0
    elseif string.sub(line, 1, 1) == "C" and chunks then
        local part = string.sub(line, 2)
        frame_bytes = frame_bytes + #part
        if frame_bytes > 262144 then
            chunks = nil
            unavailable("Samaya status exceeds the 256 KiB limit")
        else
            table.insert(chunks, part)
        end
    elseif line == "E" and chunks then
        local raw = table.concat(chunks)
        chunks = nil
        accept_frame(raw)
    elseif line == "!exit" then
        active = false
        chunks = nil
        view.launch_available = false
        restart_at = noctalia.nowMs() + retry_seconds * 1000
        retry_seconds = math.min(30, retry_seconds * 2)
        unavailable("Samaya helper exited. Check PATH and use a GUI build of Samaya 1.12.0 or later.")
    elseif line == "!oversized" then
        chunks = nil
        unavailable("Samaya status exceeds the 256 KiB limit")
    else
        chunks = nil
        unavailable("Invalid Samaya stream framing")
    end
end

local function start_helper()
    local executable_exists = noctalia.commandExists("samaya")
    -- A headless or old binary may exist on PATH but cannot launch this UI.
    -- Wait for a valid frame from this helper before advertising Open/Compose.
    view.launch_available = false
    if not executable_exists then
        restart_at = noctalia.nowMs() + 30000
        unavailable("Samaya is missing from Noctalia's PATH. Install its GUI build, then reload the plugin.")
        return
    end
    -- Only the trusted installation path is quoted. The invoked script always
    -- runs the same watch command; all operational actions use direct argv.
    local path = noctalia.pluginDir() .. "/watch.sh"
    local quoted = "'" .. string.gsub(path, "'", "'\\''") .. "'"
    generation = generation + 1
    local owner = generation
    active = true
    last_valid = noctalia.nowMs()
    if not noctalia.runStream("exec sh " .. quoted, function(line)
        if owner == generation then on_line(line) end
    end) then
        active = false
        restart_at = noctalia.nowMs() + 30000
        unavailable("Could not start the Samaya status helper")
    end
end

local function outcome(request, status, reason)
    if disposed then return end
    noctalia.state.set("action", {
        status = status, label = labels[request.kind], reason = reason,
        target = request.target, token = request.token,
    })
end

local function handle_request(request)
    if disposed or type(request) ~= "table" or not labels[request.kind] then return end
    if request.kind == "open" or request.kind == "compose" then
        if not view.launch_available then
            if busy then
                outcome(busy, "pending", "Samaya's GUI is unavailable. The original operation is still in progress.")
            else
                outcome(request, "failed", "Samaya's GUI interface is unavailable. Check PATH and install a GUI build of Samaya 1.12.0 or later.")
            end
            return
        end
        local argv = request.kind == "compose" and { "samaya", "compose" } or { "samaya" }
        if noctalia.runAsync(argv) then
            if not busy then
                outcome(request, "ok", request.kind == "compose" and "Opening the composer" or "Opening Samaya")
            end
        else
            if busy then
                outcome(busy, "pending", "Could not launch Samaya. The original operation is still in progress.")
            else
                outcome(request, "failed", "Could not launch Samaya")
            end
        end
        return
    end
    if busy then return end
    if view.health ~= "live" then
        outcome(request, "rejected", "Samaya is unavailable. Open Samaya to recover.")
        return
    end
    local argv, reason = model.action(view.snapshot, request.kind, request.target)
    if not argv then
        outcome(request, "rejected", reason)
        return
    end
    busy = request
    outcome(request, "pending")
    local accepted = noctalia.runAsync(argv, function(result)
        if disposed or busy ~= request then return end
        busy = nil
        local ok, reply = pcall(noctalia.json.decode, result.stdout or "")
        if ok and type(reply) == "table" and not result.stdoutTruncated and not result.timedOut then
            if reply.result == "ok" then
                outcome(request, "ok")
                return
            elseif reply.result == "rejected" and type(reply.reason) == "string" then
                outcome(request, "rejected", reply.reason)
                return
            elseif reply.result == "failed" and type(reply.message) == "string" then
                outcome(request, "failed", reply.message)
                return
            elseif reply.result == "unknown" then
                outcome(request, "unknown", "The reply was lost or timed out. Samaya may still finish; open it to check.")
                return
            end
        end
        outcome(request, "unknown", "No usable reply arrived. Samaya may still finish; open it to check.")
    end, 15000)
    if not accepted then
        busy = nil
        outcome(request, "failed", "Could not launch the Samaya command")
    end
end

noctalia.state.set("action", {})
noctalia.state.watch("request", handle_request)
publish()
start_helper()
noctalia.setUpdateInterval(1000)

function update()
    if disposed then return end
    local now = noctalia.nowMs()
    if active and view.health ~= "stale" and now - last_valid >= 15000 then
        unavailable("Samaya's status helper stopped responding. Open Samaya or reload the plugin.", "stale")
    elseif not active and now >= restart_at then
        start_helper()
    end
end

function onConfigChanged()
    -- Presentation settings do not require restarting a healthy watch process.
end

function onExit()
    disposed = true
    active = false
    chunks = nil
    -- The host unregisters state watches and the timer, discards callbacks, and
    -- terminates the entire stream process group (including samaya and awk).
end
