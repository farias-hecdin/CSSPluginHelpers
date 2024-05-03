local M = {}
local vim = vim

M.setup = function(options) end

-- INFO: File operations

--- Search for the file "*.css" in the current directory and parent directories.
M.find_file = function(fname, dir, attempt, limit)
  if not attempt or attempt > limit then
    return
  end

  dir = dir or ""
  local handle = io.popen("ls -1 " .. dir)
  if not handle then
    return false
  end

  for file in handle:lines() do
    if file == fname then
      handle:close()
      if attempt == 1 then
        return dir .. fname
      end
      return dir .. "/" .. fname
    end
  end
  handle:close()

  dir = dir .. "../"

  return M.find_file(fname, dir, attempt + 1, limit)
end

--- Get the content of the current line
M.get_current_line_content = function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]

  return line, line_content
end

--- Open a file and return its contents
M.open_file = function(fpath)
  local file = io.open(fpath, "r")
  if not file then
    return
  end

  local contents = {}
  for line in file:lines() do
    table.insert(contents, line)
  end

  file:close()
  return contents
end

M.extract_from_file = function (content, pattern)
  local captured_data = {}

  for _, line in ipairs(content) do
    for data in string.gmatch(line, pattern) do
      table.insert(captured_data, data)
    end
  end
  return captured_data
end


-- INFO: CSS operations

M.get_css_attribute = function(fpath, properties)
  local content = M.open_file(fpath)
  local captured_data = M.extract_from_file(content, "[-_%w]+%:[^;]+")

  local key_value_pairs = {}
  for _, data in ipairs(captured_data) do
    local key, value = M.extract_key_value(data)
    if key:match(properties) then
      key_value_pairs[key] = value
    end
  end

  return key_value_pairs
end

M.extract_key_value = function(data)
  local key = data:match("[-_%w]*[^:]+")
  local value = data:match("%:([^;]+)")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  return key, value
end

return M
