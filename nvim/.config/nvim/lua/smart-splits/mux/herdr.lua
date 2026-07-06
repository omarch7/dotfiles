-- Custom smart-splits.nvim multiplexer backend for herdr (https://herdr.dev).
-- Resolved by smart-splits via require('smart-splits.mux.herdr') when
-- `multiplexer_integration = 'herdr'`. Our nvim config's lua/ dir is on
-- 'runtimepath', so this is found without patching the plugin. Modeled on the
-- built-in smart-splits/mux/tmux.lua. herdr direction words match smart-splits
-- (left/right/up/down) 1:1, so no translation table is needed.
--
-- Fail-safe: any non-zero exit / JSON parse failure returns false/nil, which
-- smart-splits treats as "stay in nvim". (mux.move_pane/resize_pane also pcall.)

local types = require("smart-splits.types")
local Direction = types.Direction
local utils = require("smart-splits.utils")

---Run a herdr CLI command; return its decoded `.result` table (or nil) and exit code.
---@param args string[]
---@return table|nil result, integer code
local function herdr_json(args)
  local cmd = vim.list_extend({ "herdr" }, args)
  local text, code = utils.system(cmd)
  if code ~= 0 or not text or #text == 0 then
    return nil, code
  end
  local ok, decoded = pcall(vim.json.decode, text)
  if not ok or type(decoded) ~= "table" then
    return nil, code
  end
  return decoded.result, code
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = "herdr" ---@diagnostic disable-line: assign-type-mismatch

function M.is_in_session()
  local pane = vim.env.HERDR_PANE_ID
  return vim.env.HERDR_ENV == "1" and pane ~= nil and #pane > 0
end

-- Returns the *static* pane id from the environment (no CLI call). This is
-- correct ONLY with at_edge='stop': smart-splits' move_multiplexer_inner()
-- compares this id before/after next_pane() to detect a move, but under 'stop'
-- that return value is never used for a wrap-back -- the real gate is
-- current_pane_at_edge(). If at_edge is ever changed to 'wrap', switch this to
-- read `.result.edges.layout.focused_pane_id` so before/after differs.
function M.current_pane_id()
  return vim.env.HERDR_PANE_ID
end

function M.current_pane_at_edge(direction)
  if not M.is_in_session() then
    return false
  end
  local result = herdr_json({ "pane", "edges", "--current" })
  if not result or type(result.edges) ~= "table" then
    return false
  end
  return result.edges[direction] == true
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end
  local _, code = herdr_json({ "pane", "focus", "--direction", direction, "--current" })
  return code == 0
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end
  local _, code = herdr_json({
    "pane", "resize", "--direction", direction, "--amount", tostring(amount), "--current",
  })
  return code == 0
end

function M.current_pane_is_zoomed()
  local result = herdr_json({ "pane", "edges", "--current" })
  if not result or type(result.edges) ~= "table" or type(result.edges.layout) ~= "table" then
    return false
  end
  return result.edges.layout.zoomed == true
end

function M.split_pane(direction, size)
  -- Not exercised by nav/resize with at_edge='stop'. Best-effort: herdr only
  -- splits right|down, so map left->right and up->down.
  local herdr_dir = (direction == Direction.left or direction == Direction.right) and "right" or "down"
  local args = { "pane", "split", "--current", "--direction", herdr_dir }
  if size then
    vim.list_extend(args, { "--ratio", tostring(size) })
  end
  local _, code = herdr_json(args)
  return code == 0
end

function M.update_mux_layout_details()
  -- No cached layout: edges are queried live on each call. Nothing to do.
end

return M
