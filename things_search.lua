#!/usr/bin/env luajit

-- Get the directory of the current script
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*[/\\])") or "./"

-- Add package paths
package.path = package.path
	.. ";"
	.. script_dir
	.. "lua_modules/share/lua/5.1/?.lua;"
	.. script_dir
	.. "lua_modules/share/lua/5.1/?/init.lua"

package.cpath = package.cpath
	.. ";"
	.. script_dir
	.. "lua_modules/lib/lua/5.1/luasql/sqlite3.so;"
	.. script_dir
	.. "lua_modules/lib/lua/5.1/?/init.so"

local json = require("json")
local luasql = require("luasql.sqlite3")

local function main(search_key)
	local db_path = os.getenv("HOME") .. os.getenv("THINGS_DATABASE")

	-- Create environment and connect to database
	local env = assert(luasql.sqlite3())
	local conn, err = env:connect(db_path)
	if not conn then
		error("Failed to connect to database: " .. (err or "unknown error"))
	end

	-- Escape search key and prepare LIKE patterns
	local escaped_search = conn:escape(search_key)
	local like_pattern = "%" .. escaped_search .. "%"

	-- Construct SQL query with interpolated patterns
	local task_query = string.format(
		[[
        SELECT
            TMTask.title,
            TMTask.uuid,
            TMTask.notes,
            TMTask.status,
            COALESCE(TMTask.startDate, 0) AS startDate,
            Project.title AS project_title,
            Area.title AS area_title
        FROM TMTask
        LEFT JOIN TMTask AS Project ON TMTask.project = Project.uuid
        LEFT JOIN TMArea AS Area ON TMTask.area = Area.uuid
        WHERE TMTask.trashed = 0
            AND (TMTask.title LIKE '%s' OR TMTask.notes LIKE '%s')
        ORDER BY
            TMTask.type DESC,
            TMTask.status ASC,
            startDate ASC
    ]],
		like_pattern,
		like_pattern
	)

	-- Execute query and handle potential errors
	local cur, err = conn:execute(task_query)
	if not cur then
		conn:close()
		env:close()
		error("Failed to execute query: " .. (err or "unknown error"))
	end

	-- Process query results
	local results = {}
	local row = cur:fetch({}, "a") -- 'a' for associative (named) indices
	while row do
		local subtitle = row.project_title or row.area_title or ""
		local arg = row.uuid and "things:///show?id=" .. row.uuid or ""

		table.insert(results, {
			title = row.title or "Untitled Task",
			subtitle = subtitle,
			arg = arg,
			valid = arg ~= "" and true or false,
		})
		row = cur:fetch(row, "a") -- Reuse the table for next row
	end

	-- Cleanup resources
	cur:close()
	conn:close()
	env:close()

	print(json:encode({ items = results }))
end

-- Handle command-line arguments
local arguments = table.concat(arg, " ")
main(arguments)
