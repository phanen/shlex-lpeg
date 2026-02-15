local lpeg = require('lpeg')

local P, S, C, Cf, Ct, Cs = lpeg.P, lpeg.S, lpeg.C, lpeg.Cf, lpeg.Ct, lpeg.Cs
local BS = P('\\')
local DQ = P('"')
local SQ = P("'")
local SP = S(' \t\n\r')
local squote = SQ * C((1 - SQ) ^ 0) * SQ
local dq_escaped_dq = BS * DQ / '"' --  \" to "
local dq_escaped_bs = BS * BS / '\\' --  \\ to \
local dquote = DQ * Cs((dq_escaped_dq + dq_escaped_bs + (P(1) - DQ)) ^ 0) * DQ
local unquoted = BS * C(P(1)) + C(P(1) - SP)
local word = squote + dquote + unquoted
local token = Cf(word ^ 1, function(acc, val)
  return acc .. val
end)
local split = Ct(SP ^ 0 * token * (SP ^ 1 * token) ^ 0 * SP ^ 0)

local M = {}

---@param s string
---@return string[]
M.split = function(s)
  return split:match(s)
end

local R = lpeg.R
local cont = R('\128\191') -- continuation byte
local utf8 = C(
  R('\0\127')
    + R('\194\223') * cont
    + R('\224\239') * cont * cont
    + R('\240\244') * cont * cont * cont
)

---@param s string
---@return string
M.quote = function(s)
  if s == '' then return "''" end
  if not s:match('[^%w%%%+,%-%./:=@_]') and utf8:match(s) then return s end
  -- Use single quotes, and put single quotes into double quotes.
  -- E.g., $'b becomes '$"'"'b'
  return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

---@param split_command string[]
---@return string
M.join = function(split_command)
  local quoted_tokens = {}
  for _, token_str in ipairs(split_command) do
    quoted_tokens[#quoted_tokens + 1] = M.quote(token_str)
  end
  return table.concat(quoted_tokens, ' ')
end

return M
