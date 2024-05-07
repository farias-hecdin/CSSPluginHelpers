local M = {}
local vim = vim

M.setup = function(options) end

--- INFO: Visual Mode (Thanks to: https://github.com/antonk52/markdowny.nvim)

-- to get the line at the given line number
local get_line = function(line_num)
  return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
end

-- to get the position of the given mark
local get_mark = function(mark)
  local position = vim.api.nvim_buf_get_mark(0, mark)
  return { position[1], position[2] + 1 }
end

-- to get the first byte of the character at the given position
local get_first_byte = function(pos)
  local byte = string.byte(get_line(pos[1]):sub(pos[2], pos[2]))
  if not byte then
    return pos
  end

  while byte >= 0x80 and byte < 0xc0 do
    pos[2] = pos[2] - 1
    byte = string.byte(get_line(pos[1]):sub(pos[2], pos[2]))
  end
  return pos
end

-- to get the last byte of the character at the given position
local get_last_byte = function(pos)
  if not pos then
    return nil
  end

  local byte = string.byte(get_line(pos[1]):sub(pos[2], pos[2]))
  if not byte then
    return pos
  end

  if byte >= 0xf0 then
    pos[2] = pos[2] + 3
  elseif byte >= 0xe0 then
    pos[2] = pos[2] + 2
  elseif byte >= 0xc0 then
    pos[2] = pos[2] + 1
  end
  return pos
end

-- to get the text between the given selection
local get_text = function(selection)
  local first_pos, last_pos = selection.first_pos, selection.last_pos
  last_pos[2] = math.min(last_pos[2], #get_line(last_pos[1]))
  return vim.api.nvim_buf_get_text(0, first_pos[1] - 1, first_pos[2] - 1, last_pos[1] - 1, last_pos[2], {})
end

--- Capture the currently selected text
M.capture_visual_selection = function()
  local s = get_first_byte(get_mark('<'))
  local e = get_last_byte(get_mark('>'))

  if s == nil or e == nil then
    return
  end
  if vim.fn.visualmode() == 'V' then
    e[2] = #get_line(e[1])
  end

  local selection = {first_pos = s, last_pos = e}
  local text = get_text(selection)

  return selection, text
end

--- Change the text at the given selection
M.change_text = function(selection, text)
  if not selection then
    return
  end
  local first_pos, last_pos = selection.first_pos, selection.last_pos
  vim.api.nvim_buf_set_text(0, first_pos[1] - 1, first_pos[2] - 1, last_pos[1] - 1, last_pos[2], text)
end

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

local extract_key_value = function(data)
  local key = data:match("[-_%w]*[^:]+")
  local value = data:match("%:([^;]+)")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  return key, value
end

M.get_css_attribute = function(fpath, properties)
  local content = M.open_file(fpath)
  local captured_data = M.extract_from_file(content, "[-_%w]+%:[^;]+")

  local key_value_pairs = {}
  for _, data in ipairs(captured_data) do
    local key, value = extract_key_value(data)
    if key:match(properties) then
      key_value_pairs[key] = value
    end
  end

  return key_value_pairs
end

-- INFO: Buffer operations

--- Get the content of the current line
M.get_current_line_content = function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]

  return line, line_content
end

-- Thanks to: https://github.com/jsongerber/nvim-px-to-rem
M.show_virtual_text = function(virtual_text, current_line, namespace, style)
  local extmark = vim.api.nvim_buf_get_extmark_by_id(0, namespace, namespace, {})
  if extmark ~= nil then
    vim.api.nvim_buf_del_extmark(0, namespace, namespace)
  end
  -- Create extmark if virtual text is present
  if #virtual_text > 0 then
    vim.api.nvim_buf_set_extmark(0, tonumber(namespace), (current_line - 1), 0,
      {
        virt_text = { {table.concat(virtual_text, " "), style or "Comment"} },
        id = namespace,
        priority = 100,
      }
    )
  end
end

return M
