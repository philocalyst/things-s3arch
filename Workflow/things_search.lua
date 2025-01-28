#!/usr/bin/env luajit

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*[/\\])") or "./"

package.path = package.path
	.. ";"
	.. script_dir
	.. "lua_modules/share/lua/5.1/?.lua"
	.. ";"
	.. script_dir
	.. "lua_modules/share/lua/5.1/?/init.lua"
	.. ";"
	.. script_dir
	.. "lua-ljsqlite3/init.lua"

local json = require("json")
local sql = require("ljsqlite3")
local fzy = require("fzy")

local function get_db_connection()
	local db_path = os.getenv("HOME")
		.. (
			os.getenv("THINGS_DATABASE")
			or "/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac/ThingsData-QZTVJ/Things Database.thingsdatabase/main.sqlite"
		)

	local conn, err = sql.open(db_path)
	if not conn then
		error("Failed to connect to database: " .. (err or "unknown error"))
	end
	return conn
end

local function smart_case(str)
	for char in str:gmatch(".") do
		if char:match("%u") then
			return true
		end
	end
	return false
end

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

local function sort_matches(matches)
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

local function process_tasks(tasks, search_key, max_results)
	local titles = {}
	for i, task in ipairs(tasks) do
		titles[i] = task.title
		titles[i + #tasks] = task.notes
	end

	local case_sensitive = os.getenv("SMART_CASE") or smart_case(search_key)
	local matches = fzy.filter(search_key, titles, case_sensitive)
	matches = sort_matches(matches)
	local results = {}

	for i = 1, math.min(#matches, max_results) do
		local idx = matches[i]
		local task
		local fd_indx = idx[1]
		if fd_indx > #tasks then
			task = tasks[fd_indx - #tasks]
		else
			task = tasks[fd_indx]
		end
		local subtitle = task.project_title or task.area_title or ""
		local arg = task.uuid and "things:///show?id=" .. task.uuid or ""

		table.insert(results, {
			title = task.title or "Untitled Task",
			subtitle = subtitle,
			arg = arg,
			valid = arg ~= "" and true or false,
		})
	end

	return results
end

local function main(search_key)
	local max_results = tonumber(os.getenv("MAX_RESULTS")) or 100
	local conn = get_db_connection()
	local ok, resultset, nrow = pcall(fetch_tasks, conn)

	if not ok then
		conn:close()
		error(resultset)
	end

	local tasks = {}
	if nrow > 0 then
		for i = 1, nrow do
			tasks[i] = {
				notes = resultset.notes[i],
				title = resultset.title[i],
				uuid = resultset.uuid[i],
				project_title = resultset.project_title[i],
				area_title = resultset.area_title[i],
			}
		end
	end

	conn:close()
	local filtered = process_tasks(tasks, search_key, max_results)
	return json:encode({ items = filtered })
end

-- Handle command-line arguments
local args = { ... }
local search_key = table.concat(args, " ")

local ok, result = pcall(main, search_key)
if not ok then
	print("Error", result)
else
	print(result)
end
