# Search Things, Powerfully (Alfred Workflow)

Search Things as if you were there, except in Alfred.

![ishare-1738002952-arc](https://github.com/user-attachments/assets/f7261237-bbee-4e31-bbd4-61ccc44f8bfa)
![ishare-1738002920-arc](https://github.com/user-attachments/assets/3db47d3c-91ed-413e-8905-ebd8de9b44e2)


## Usage

Find Todos using match search, via the keyword "ths" (User-changeable).
Select a todo and get brought to its location in the things app.

## Dependencies

- luaJIT (Ensure this is installed on your system)
- luarocks
- Libraries
    - https://luarocks.org/modules/tomasguisasola/luasql-sqlite3
    - https://luarocks.org/modules/jiyinyiyong/json-lua

## Finding Things Database Path

- Ensure that you have "Show hidden files on" in Finder
- Then, enter Library -> Group Containers -> (WEIRD NUMBER STRING)com.culturedcode.Thingsmac -> ThingsData(MORE NUMBERS) -> (something)database(something) -> RIGHT CLICK ON IT -> "Show package contents"
- Then you need to select main.sqlite - Basic solution: While selected, go to the Edit menu -> copy as pathname
  Yay!!!!
