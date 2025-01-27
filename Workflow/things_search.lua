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

package.path = package.path .. ";" .. script_dir .. "lua-ljsqlite3/init.lua"

local json = require("json")
local sql = require("ljsqlite3")

local function main(search_key)
	local db_path = os.getenv("HOME")
		.. (
			os.getenv("THINGS_DATABASE")
			or "/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac/ThingsData-QZTVJ/Things Database.thingsdatabase/main.sqlite"
		)

	local max_results = tonumber(os.getenv("MAX_RESULTS")) or 100

	-- Connect to database
	local conn, err = sql.open(db_path)
	if not conn then
		error("Failed to connect to database: " .. (err or "unknown error"))
	end

	-- Prepare LIKE patterns
	local like_pattern = "%" .. search_key .. "%"

	-- Prepare SQL query with parameter placeholders
	local task_query = [[
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
            AND (TMTask.title LIKE ? OR TMTask.notes LIKE ?)
        ORDER BY
            TMTask.type DESC,
            TMTask.status ASC,
            startDate ASC
    ]]

	-- Prepare and execute statement
	local stmt, err = conn:prepare(task_query)
	if not stmt then
		conn:close()
		error("Failed to prepare statement: " .. (err or "unknown error"))
	end

	stmt:bind(like_pattern, like_pattern)
	local resultset, nrow = stmt:resultset()

	-- Process results
	local results = {}
	if resultset and nrow > 0 then
		for i = 1, nrow do
			if i > max_results then
				return json:encode({ items = results })
			end
			local title = resultset.title[i]
			local uuid = resultset.uuid[i]
			local project_title = resultset.project_title[i]
			local area_title = resultset.area_title[i]

			local subtitle = project_title or area_title or ""
			local arg = uuid and "things:///show?id=" .. uuid or ""

			table.insert(results, {
				title = title or "Untitled Task",
				subtitle = subtitle,
				arg = arg,
				valid = arg ~= "" and true or false,
			})
		end
	end

	-- Cleanup resources
	stmt:close()
	conn:close()

	return (json:encode({ items = results }))
end

-- Handle command-line arguments
local arguments = table.concat(arg, " ")
print(main(arguments))
