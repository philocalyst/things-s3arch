#!/usr/bin/env luajit

-- Get script directory to properly locate modules
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*[/\\])") or "./"

-- Set package path with proper semicolon separators between paths
package.path = package.path
    .. ";"
    .. script_dir .. "lua_modules/share/lua/5.1/?.lua"
    .. ";"
    .. script_dir .. "lua_modules/share/lua/5.1/?/init.lua"
    .. ";"
    .. script_dir .. "lua-ljsqlite3/init.lua"

-- Required libraries
local json = require("lunajson")
local sql = require("ljsqlite3")
local fzy = require("fzy")

-- Function to find Things database directory
local function find_things_database_dir()
  local group_containers_path = os.getenv("HOME") .. "/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac/"

  -- Open directory and scan for subdirectories
  local popen = io.popen('ls "' .. group_containers_path .. '"')
  if not popen then
    return nil, "Could not open directory"
  end

  for dir in popen:lines() do
    -- Check if it looks like a Things data directory (Things Data)
    if dir:match("%ThingsData") then
      popen:close()
      return group_containers_path .. dir .. "/Things Database.thingsdatabase/main.sqlite"
    end
  end

  popen:close()
  return nil, "No Things database directory found"
end

-- Get database connection with dynamic path discovery
local function get_db_connection()
  -- First check environment variable
  -- local db_path = os.getenv("THINGS_DATABASE")

  -- If no environment variable, try to discover the path
  if not db_path then
    local path, err = find_things_database_dir()
    if not path then
      error(err or "Failed to locate Things database")
    end
    db_path = path
  end

  local conn, err = sql.open(db_path)
  if not conn then
    error("Failed to connect to database: " .. (err or "unknown error"))
  end
  return conn
end

-- Determine if search should be case-sensitive
local function smart_case(str)
  if not str then return false end
  return str:match("%u") ~= nil
end

-- Fetch tasks from database with error handling
local function fetch_tasks(conn)
  local query = [[
        SELECT
            TMTask.title,
            TMTask.uuid,
            TMTask.notes,
            TMTask.status,
            Project.title AS project_title,
            Area.title AS area_title
        FROM TMTask
        LEFT JOIN TMTask AS Project ON TMTask.project = Project.uuid
        LEFT JOIN TMArea AS Area ON TMTask.area = Area.uuid
        WHERE TMTask.trashed = 0
    ]]

  local stmt, err = conn:prepare(query)
  if not stmt then
    error("Failed to prepare statement: " .. (err or "unknown error"))
  end

  local resultset, nrow = stmt:resultset()
  stmt:close()
  return resultset, nrow
end

-- Sort matches by score (descending) and then by index (ascending)
local function sort_matches(matches)
  if not matches or #matches == 0 then
    return {}
  end

  table.sort(matches, function(a, b)
    -- Sort by score (descending)
    if a[3] ~= b[3] then
      return a[3] > b[3]
    end
    -- If scores are equal, sort by index (ascending)
    return a[1] < b[1]
  end)

  return matches
end

-- Process tasks and filter by search key using fzy directly
local function process_tasks(tasks, search_key, max_results)
  if not tasks or #tasks == 0 or not search_key or search_key == "" then
    return {}
  end

  -- Create a list of titles and notes for searching
  local search_items = {}
  local item_map = {} -- Maps search_items index to task and type (title or note)

  local idx = 1
  for i, task in ipairs(tasks) do
    -- Add title to search items
    if task.title and task.title ~= "" then
      search_items[idx] = task.title
      item_map[idx] = { task = task, type = "title" }
      idx = idx + 1
    end

    -- Add notes to search items
    if task.notes and task.notes ~= "" then
      search_items[idx] = task.notes
      item_map[idx] = { task = task, type = "notes" }
      idx = idx + 1
    end
  end

  -- Determine if search should be case sensitive
  local use_smart_case = os.getenv("SMART_CASE") ~= "0"
  local case_sensitive = use_smart_case and smart_case(search_key) or false

  -- Use fzy.filter to find matches
  local matches = fzy.filter(search_key, search_items, case_sensitive)

  -- Sort matches by score (higher is better)
  table.sort(matches, function(a, b)
    return a[3] > b[3] -- Sort by score (descending)
  end)

  -- Build results table from matches
  local results = {}
  local seen_tasks = {} -- Track which tasks we've already added

  for i = 1, math.min(#matches, max_results) do
    local match = matches[i]
    if not match then break end

    local search_idx = match[1]
    local item_info = item_map[search_idx]

    if item_info and item_info.task then
      local task = item_info.task

      -- Only add a task once (using UUID as unique identifier)
      if not seen_tasks[task.uuid] then
        seen_tasks[task.uuid] = true

        local subtitle = task.project_title or task.area_title or ""
        local arg = task.uuid and "things:///show?id=" .. task.uuid or ""

        table.insert(results, {
          title = task.title or "Untitled Task",
          subtitle = subtitle,
          arg = arg,
          valid = arg ~= "" and true or false,
          -- Optional: include match positions for highlighting
          positions = match[2],
          score = match[3],
          matched_field = item_info.type
        })
      end
    end
  end

  return results
end

-- Main function to perform the search
local function main(search_key)
  if not search_key or search_key == "" then
    return json.encode({ items = {} })
  end

  -- Get maximum results from environment or use default
  local max_results = tonumber(os.getenv("MAX_RESULTS")) or 100

  -- Connect to database
  local conn
  local ok, err = pcall(function()
    conn = get_db_connection()
    return true
  end)

  if not ok then
    return json.encode({
      items = { {
        title = "Error connecting to Things database",
        subtitle = err or "Unknown error",
        valid = false
      } }
    })
  end

  -- Fetch tasks with error handling
  local resultset, nrow
  ok, err = pcall(function()
    resultset, nrow = fetch_tasks(conn)
    return true
  end)

  if not ok then
    conn:close()
    return json.encode({
      items = { {
        title = "Error fetching tasks",
        subtitle = err or "Unknown error",
        valid = false
      } }
    })
  end

  -- Process tasks
  local tasks = {}
  if nrow and nrow > 0 then
    for i = 1, nrow do
      tasks[i] = {
        notes = resultset.notes and resultset.notes[i] or "",
        title = resultset.title and resultset.title[i] or "Untitled",
        uuid = resultset.uuid and resultset.uuid[i] or "",
        project_title = resultset.project_title and resultset.project_title[i] or nil,
        area_title = resultset.area_title and resultset.area_title[i] or nil,
      }
    end
  end

  -- Close database connection
  conn:close()

  -- Process and filter tasks
  local filtered = process_tasks(tasks, search_key, max_results)

  -- Return JSON results
  return json.encode({ items = filtered })
end

-- Handle command-line arguments
local args = { ... }
local search_key = table.concat(args, " ")

-- Execute main function with error handling
local ok, result = pcall(main, search_key)
if not ok then
  print(json.encode({
    items = { {
      title = "Error executing search",
      subtitle = result or "Unknown error",
      valid = false
    } }
  }))
else
  print(result)
end
