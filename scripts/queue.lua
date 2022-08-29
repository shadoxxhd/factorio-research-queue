local rqtech = require('.rqtech')
local util = require('.util')

-- initialisation
local function new(force, paused)
  local queue = {}
  global.forces[force.index].queue = queue
  global.forces[force.index].queue_paused = paused
  local backup = {}
  global.forces[force.index].frozen = nil -- indicates first research that was frozen due to pausing the queue
  -- global.forces[force.index].last = nil
end

-- move q[i] to [j] and shift intervening items
local function rotate(force, queue, i, j)
  if i == j then return end
  local dir = i < j and 1 or -1
  local tmp = queue[i]
  local k = i
  while k*dir < j*dir do
    queue[k] = queue[k+dir]
    k = k+dir
  end
  queue[j] = tmp
end

local function is_researchable(force, queue, tech)
  return
    not tech.tech.prototype.hidden and
    tech.tech.enabled and
    not rqtech.is_researched(tech)
end

local function is_dependency(force, queue, dependency, tech)
  return is_researchable(force, queue, dependency) and tech.prerequisites[dependency.tech.name] ~= nil
end

local function is_dependent(force, queue, dependent, tech)
  return is_researchable(force, queue, dependent) and is_dependency(force, queue, tech, dependent)
end

-- returns all dependencies
local function tech_dependencies(force, queue, tech)
  return util.iter_filter(
    util.iter_values(tech.prerequisites),
    function(dependency)
      return is_researchable(force, queue, dependency)
    end)
end

-- returns all techs that depend on <tech>
local function tech_dependents(force, queue, tech)
  local deps
  if tech.infinite and tech.level < tech.tech.prototype.max_level then
    deps = util.iter_once(rqtech.new(tech.tech, tech.level + 1))
  else
    deps = rqtech.iter(force)
  end
  return util.iter_filter(
    deps,
    function(depdendent)
      return is_dependent(force, queue, depdendent, tech)
    end)
end

-- where is a tech in queue
local function queue_pos(force, queue, tech)
  for idx, queued_tech in ipairs(queue) do
    if queued_tech.id == tech.id then
      return idx
    end
  end
  return nil
end

-- is tech first item in queue
local function is_head(force, queue, tech, ignore_level)
  if queue[1] == nil then
    return false
  end
  if ignore_level then
    return queue[1].tech.name == tech.tech.name
  else
    return queue[1].id == tech.id
  end
end

local function get_head(force, queue)
  return queue[1]
end

-- queue_pos
local function queue_prev(force, queue, tech)
  for idx, queued_tech in ipairs(queue) do
    if queued_tech.id == tech.id then
      return idx
    end
  end
  return nil
end

local function in_queue(force, queue, tech)
  for _, queued_tech in ipairs(queue) do
    if queued_tech.id == tech.id then
      return true
    end
  end
  return false
end

-- enqueue all necessary techs
local function enqueue(force, queue, tech)
  if not in_queue(force, queue, tech) then
    for dependency in tech_dependencies(force, queue, tech) do
      enqueue(force, queue, dependency)
    end

    table.insert(queue, tech)
  end
end

-- dequeue tech and all dependents
local function dequeue(force, queue, tech)
  if in_queue(force, queue, tech) then
    for dependent in tech_dependents(force, queue, tech) do
      dequeue(force, queue, dependent)
    end

    for idx, queued_tech in ipairs(queue) do
      if queued_tech.id == tech.id then
        table.remove(queue, idx)
        break
      end
    end
  end
end

-- is tech d. of queue[from...to]
local function is_depdendency_of_any(force, queue, tech, from_pos, to_pos)
  for i = from_pos,to_pos do
    if is_dependency(force, queue, tech, queue[i]) then
      return true
    end
  end
  return false
end

-- is tech d. of queue[from...to]
local function is_depdendent_of_any(force, queue, tech, from_pos, to_pos)
  for i = from_pos,to_pos do
    if is_dependent(force, queue, tech, queue[i]) then
      return true
    end
  end
  return false
end

-- search for a tech than could be moved before <tech>
local function try_shift_later(force, queue, tech)
  local tech_pos = queue_pos(force, queue, tech)
  local pivot_pos = tech_pos + 1
  if pivot_pos > #queue then
    return nil
  end
  while is_depdendent_of_any(force, queue, queue[pivot_pos], tech_pos, pivot_pos) do
    pivot_pos = pivot_pos + 1
    if pivot_pos > #queue then
      return nil
    end
  end
  return pivot_pos, tech_pos
end

-- move earliest independent tech in front of <tech>
local function shift_later(force, queue, tech)
  local pivot_pos, tech_pos = try_shift_later(force, queue, tech)
  if pivot_pos ~= nil then
    rotate(force, queue, pivot_pos, tech_pos)
    return true
  end
  return false
end

-- search for latest independent tech that could be moved behind <tech>
local function try_shift_earlier(force, queue, tech, head)
  head = head or 1
  local tech_pos = queue_pos(force, queue, tech)
  local pivot_pos = tech_pos - 1
  if pivot_pos < head then
    return nil
  end
  while is_depdendency_of_any(force, queue, queue[pivot_pos], pivot_pos, tech_pos) do
    pivot_pos = pivot_pos - 1
    if pivot_pos < head then
      return nil
    end
  end
  return pivot_pos, tech_pos
end

-- move latest independent tech behind <tech>
local function shift_earlier(force, queue, tech, head)
  local pivot_pos, tech_pos = try_shift_earlier(force, queue, tech, head)
  if pivot_pos ~= nil then
    rotate(force, queue, pivot_pos, tech_pos)
    return true
  end
  return false
end

-- move to the right as far as possible
local function shift_latest(force, queue, tech)
  while shift_later(force, queue, tech) do end
end

-- move to the left as far as possible
local function shift_earliest(force, queue, tech)
  while shift_earlier(force, queue, tech) do end
end

-- move to the left as far as possible, but keep current
local function shift_before_earliest(force, queue, paused, tech)
  while shift_earlier(force, queue, tech, paused and 1 or 2) do end
end

-- enqueue and move to the right
local function enqueue_tail(force, queue, tech)
  enqueue(force, queue, tech)
  shift_latest(force, queue, tech)
end

-- enqueue and move to the left
local function enqueue_head(force, queue, tech)
  enqueue(force, queue, tech)
  shift_earliest(force, queue, tech)
end

-- enqueue and move to the left, ignoring current research
local function enqueue_before_head(force, queue, paused, tech)
  enqueue(force, queue, tech)
  shift_before_earliest(force, queue, paused, tech)
end

-- queue iterator
local function iter(force, queue)
  return util.iter_list(queue)
end

-- clear all after current research
local function clear(force, force_data)
  if force_data.queue_paused then
    force_data.queue = {}
  else
    local head = force_data.queue[1]
    force_data.queue = {head}
  end
end

local function set_queue(force, target)
  last = force.previous_research
  force.research_queue = target
  force.previous_research = last
end

-- sync with vanilla queue
-- modes:
--  0   mod queue changed from mod UI || overwrite vanilla | wait for vanilla | freeze vanilla
--  1   research finished || pass through queue if unmodified | refill if empty | prevent vanilla queue from advancing (if [1] not in modqueue, back it off)
--  2   research started || check for divergence (started from vanilla UI?) | noop | noop
--  3   changes were made from vanilla || merge changes into mod | noop (wait for empty queue) | noop
--  4   pause toggle || pause: prevent [8:] from advancing ('frozen') | noop | let vanilla advance if paused (?push back current if paused?)
local function update(force, queue, paused, mode)
  if mode == nil then
    mode = 0
  end
  -- remove invalid/researched techs
  local to_dequeue = {}
  for _, tech in ipairs(queue) do
    if not is_researchable(force, queue, tech) then
      table.insert(to_dequeue, tech)
    end
  end
  for _, tech in ipairs(to_dequeue) do
    dequeue(force, queue, tech)
  end
  -- process newly started tech
  if mode==2 and settings.global['rq-sync'].value ~= 'freeze' then
    set_paused(force, false)
    local tech = rqtech.new(force.research_queue[1], "current")
    enqueue_head(force, tech)
  end

  if force.research_queue_enabled then
    -- old incompatability code
    --force.print{'',
    --  '[[color=150,206,130]',
    --  {'mod-name.sonaxaton-research-queue'},
    --  '[/color]] ',
    --  {'sonaxaton-research-queue.vanilla-queue-overwritten-warning'}}
    --force.research_queue_enabled = false
    if settings.global['rq-sync'].value == 'sync' then -- TODO
      -- sync with vanilla queue
      if mode == 0 then -- mod UI
        rq = {}
        for i=1,7 do
          if queue[i]~= nil then break end
          table.insert(rq, queue[i].tech)
        end
        set_queue(force, rq)
      elseif mode == 1 then -- research finished
        if queue[7] ~= nil then
          local rq = force.research_queue
          table.insert(rq, queue[7].tech)
          set_queue(force, rq)
        end
      elseif mode == 2 then -- research started TODO
        if paused then -- was paused - restore queue
          -- put current rq in front of queue - already done by general mode2 handling
            --[[local rq = force.research_queue
            for i=1, #rq do
              local j = 0
              for k=1, i-1 do
                if rq[#rq+1-i].name == rq[#rq+1-k].name then j=j+1 end
              end
              enqueue_head(force, queue, rqtech.new(rq[#rq+1-i], 'current', j))
            end--]]
          local rq = {}
          for i=1,7 do
            if queue[i] == nil then break end
            table.insert(rq, queue[i].tech)
          end
          set_queue(force, rq)
        else -- was not paused TODO
          -- if normal "next in line": noop
          -- if diverged: vanilla UI input; compare queues. final merge waits until UI closed.
          --  should probably be effectively noop???
          if force.research_queue[1].name == queue[1].tech.name then return end
          -- do anything?
        end
      elseif mode == 3 then -- vanilla UI closed TODO
        -- merge vanilla queue changes into mod UI (cancel, add(<7), reorder, replace as cancel or insert)
        -- compare rq with queue[1:7] - only removal: remove from queue; replacement and #queue >=7: add to queue
        -- check difference
        local flag = false
        for i=1, 7 do
          if force.research_queue[i] ~= nil and queue[i] ~= nil then
            if force.research_queue[i].name ~= queue[i].tech.name then
              flag = true
              break
            end
          elseif force.research_queue[i] ~= nil or queue[i] ~= nil then
            flag = true
            break
          else
            break
          end
        end
        if not flag then return end
        -- some change occured
        --check for new techs
        local new = {}
        for i=1,7 do
          local tech = force.research_queue[i]
          if tech == nil then break end
          local present = false
          for j=1,7 do
            if tech.name == queue[j].tech.name then
              present=true
              break
            end
          end
          if not present then
            table.insert(new, tech)
          end
        end
        if #new > 0 then
          -- new technology was added to rq
          for i=1,#new do
            local j = 0
            for k=i+1, #new do
              if new[#new+1-i].name == new[#new+1-k].name then j=j+1 end
            end
            enqueue_head(force, rqtech.new(new[#new+1-i], 'current', j))
          end
        elseif #force.research_queue < 7 and #force.research_queue < #queue then
          -- only deletion
          local removed = {}
          for i=1,7 do
            if queue[i] == nil then break end
            local present = false
            for j=1,#force.research_queue do
              if queue[i].tech.name == force.research_queue[j].name then
                present = true
                break
              end
            end
            if not present then table.insert(removed, queue[i]) end
          end
          for _,tech in ipairs(removed) do
            dequeue(force, queue, tech)
          end
        end
      elseif mode == 4 then -- pause toggle
        if paused then -- freeze
          set_queue(force, {})
        else -- unfreeze
          local rq = {}
          for i=1,7 do
            if queue[i] == nil then break end
            table.insert(rq, queue[i].tech)
          end
          set_queue(force, rq)
        end
      end
    elseif settings.global['rq-sync'].value == 'wait' then
      if #force.research_queue == 0  and not paused and next(queue) ~= nil then
        set_queue(force, {queue[1].tech})
      end
    elseif settings.global['rq-sync'].value == 'freeze' then
      if #queue == 0 or paused then return end
      if mode == 0 then
        local rq = force.research_queue
        rq[1] = queue[1].tech
        set_queue(force, rq)
      elseif mode==1 then
        if queue[1].tech.name ~= force.research_queue[1].name then
          local rq = {queue[1].tech}
          for _,tech in ipairs(force.research_queue) do
            table.insert(rq, tech)
          end
          set_queue(force, rq)
        end
      end
    elseif settings.global['rq-sync'].value == 'move-head' or settings.global['rq-sync'].value == 'move-tail' then
      if mode==2 then return end
      local rq = force.research_queue
      if mode == 3 and #rq > 1 then
        force.print("sufficient items")
        -- move to mod queue
        if settings.global['rq-sync'].value == 'move-head' then
          for i=1, #rq do
            local j = 0
            for k=1, i-1 do
              if rq[#rq+1-i].name == rq[#rq+1-k].name then j=j+1 end
            end
            enqueue_head(force, queue, rqtech.new(rq[#rq+1-i], 'current', j))
          end
        else
          for i=1, #rq do
            local j = 0
            for k=1, i-1 do
              if rq[i].name == rq[k].name then j=j+1 end
            end
            enqueue_tail(force, queue, rqtech.new(rq[i], 'current', j))
          end
        end
      end
      if not paused and next(queue) ~= nil then
        set_queue(force, {queue[1].tech})
      else
        set_queue(force, {})
      end
    end
  else
    -- "classic" queue replacement
    if not paused and next(queue) ~= nil then
      set_queue(force, {queue[1].tech})
    else
      set_queue(force, {})
    end
  end
end

return {
  new = new,
  is_paused = function(force)
    local force_data = global.forces[force.index]
    local paused = force_data.queue_paused
    return paused
  end,
  set_paused = function(force, paused)
    local force_data = global.forces[force.index]
    force_data.queue_paused = paused
  end,
  toggle_paused = function(force, paused)
    local force_data = global.forces[force.index]
    force_data.queue_paused = not force_data.queue_paused
  end,
  is_researchable = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return is_researchable(force, queue, tech)
  end,
  in_queue = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return in_queue(force, queue, tech)
  end,
  is_head = function(force, tech, ignore_level)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return is_head(force, queue, tech, ignore_level)
  end,
  get_head = function(force)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return get_head(force, queue)
  end,
  queue_pos = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return queue_pos(force, queue, tech)
  end,
  enqueue = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return enqueue(force, queue, tech)
  end,
  enqueue_tail = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return enqueue_tail(force, queue, tech)
  end,
  enqueue_head = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    force_data.queue_paused = false
    return enqueue_head(force, queue, tech)
  end,
  enqueue_before_head = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    local paused = force_data.queue_paused
    return enqueue_before_head(force, queue, paused, tech)
  end,
  shift_earlier = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return shift_earlier(force, queue, tech)
  end,
  shift_earliest = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return shift_earliest(force, queue, tech)
  end,
  can_shift_earlier = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return try_shift_earlier(force, queue, tech) ~= nil
  end,
  shift_before_earliest = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    local paused = force_data.queue_paused
    return shift_before_earliest(force, queue, paused, tech)
  end,
  shift_later = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return shift_later(force, queue, tech)
  end,
  shift_latest = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return shift_latest(force, queue, tech)
  end,
  can_shift_later = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return try_shift_later(force, queue, tech) ~= nil
  end,
  dequeue = function(force, tech)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return dequeue(force, queue, tech)
  end,
  clear = function(force)
    local force_data = global.forces[force.index]
    return clear(force, force_data)
  end,
  iter = function(force)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    return iter(force, queue)
  end,
  update = function(force, mode)
    local force_data = global.forces[force.index]
    local queue = force_data.queue
    local paused = force_data.queue_paused
    return update(force, queue, paused, mode)
  end
}
