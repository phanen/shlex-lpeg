local shlex = require('shlex-lpeg')

local function build_data(raw_data)
  local split_line = function(line)
    if line:match('^%s*$') then return end
    local parts = {}
    for part in line:gmatch('([^|]*)|') do
      parts[#parts + 1] = part
    end
    if #parts == 0 then return end
    return { parts[1], { unpack(parts, 2) } }
  end
  local lines = {}
  for line in raw_data:gmatch('[^\n]*\n') do
    local parts = split_line(line)
    if parts then lines[#lines + 1] = parts end
  end
  return lines
end

-- Corrected posix_data_raw to match Python's r"""...""" behavior exactly
local posix_data_raw = [[
x|x|
foo bar|foo|bar|
 foo bar|foo|bar|
 foo bar |foo|bar|
foo   bar    bla     fasel|foo|bar|bla|fasel|
x y  z              xxxx|x|y|z|xxxx|
\x bar|x|bar|
\ x bar| x|bar|
\ bar| bar|
foo \x bar|foo|x|bar|
foo \ x bar|foo| x|bar|
foo \ bar|foo| bar|
foo "bar" bla|foo|bar|bla|
"foo" "bar" "bla"|foo|bar|bla|
"foo" bar "bla"|foo|bar|bla|
"foo" bar bla|foo|bar|bla|
foo 'bar' bla|foo|bar|bla|
'foo' 'bar' 'bla'|foo|bar|bla|
'foo' bar 'bla'|foo|bar|bla|
'foo' bar bla|foo|bar|bla|
blurb foo"bar"bar"fasel" baz|blurb|foobarbarfasel|baz|
blurb foo'bar'bar'fasel' baz|blurb|foobarbarfasel|baz|
""||
''||
foo "" bar|foo||bar|
foo '' bar|foo||bar|
foo "" "" "" bar|foo||||bar|
foo '' '' '' bar|foo||||bar|
\"|"|
"\""|"|
"foo\ bar"|foo\ bar|
"foo\\ bar"|foo\ bar|
"foo\\ bar\""|foo\ bar"|
"foo\\" bar\"|foo\|bar"|
"foo\\ bar\" dfadf"|foo\ bar" dfadf|
"foo\\\ bar\" dfadf"|foo\\ bar" dfadf|
"foo\\\x bar\" dfadf"|foo\\x bar" dfadf|
"foo\x bar\" dfadf"|foo\x bar" dfadf|
\'|'|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
"foo\\\x bar\" df'a\ 'df"|foo\\x bar" df'a\ 'df|
\"foo|"foo|
\"foo\x|"foox|
"foo\x"|foo\x|
"foo\ "|foo\ |
foo\ xx|foo xx|
foo\ x\x|foo xx|
foo\ x\x\"|foo xx"|
"foo\ x\x"|foo\ x\x|
"foo\ x\x\\"|foo\ x\x\|
"foo\ x\x\\""foobar"|foo\ x\x\foobar|
"foo\ x\x\\"\'"foobar"|foo\ x\x\'foobar|
"foo\ x\x\\"\'"fo'obar"|foo\ x\x\'fo'obar|
"foo\ x\x\\"\'"fo'obar" 'don'\''t'|foo\ x\x\'fo'obar|don't|
"foo\ x\x\\"\'"fo'obar" 'don'\''t' \\|foo\ x\x\'fo'obar|don't|\|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
foo\ bar|foo bar|
foo#bar\nbaz|foo|baz|
:-) ;-)|:-)|;-)|
áéíóú|áéíóú|
]]

describe('shlex-lpeg', function()
  local posix_test_data = build_data(posix_data_raw)

  describe('split (POSIX mode)', function()
    for _, test_case in ipairs(posix_test_data) do
      local input_str = test_case[1]
      local expected = test_case[2]
      it('should correctly split: ' .. input_str, function()
        if input_str == [[foo#bar\nbaz]] then
          -- https://github.com/python/cpython/issues/51860
          pending('wrong test case')
        end
        local result = shlex.split(input_str)
        assert.same(expected, result)
      end)
    end
  end)

  describe('quote', function()
    it('should return empty quotes for empty string', function()
      assert.equal("''", shlex.quote(''))
    end)

    it('should error on non-string input', function()
      assert.has_error(function()
        shlex.quote(123)
      end)
      assert.has_error(function()
        shlex.quote({})
      end)
      assert.has_error(function()
        shlex.quote()
      end)
    end)

    it('should not quote safe ASCII strings', function()
      assert.equal('abcDEF123_@%+-=:,./', shlex.quote('abcDEF123_@%+-=:,./'))
    end)

    it('should quote strings with spaces', function()
      assert.equal("'hello world'", shlex.quote('hello world'))
    end)

    it('should quote strings with special characters', function()
      assert.equal("'$(`~'", shlex.quote('$(`~'))
      assert.equal("''\"'\"'foo'", shlex.quote("'foo"))
    end)

    it('should handle strings with embedded single quotes', function()
      assert.equal("'test'\"'\"'s'", shlex.quote("test's"))
      assert.equal("'a'\"'\"'b'\"'\"'c'", shlex.quote("a'b'c"))
    end)

    it('should quote unicode strings', function()
      assert.equal(
        "'哈基米南北绿豆 ちみーをなめると'",
        shlex.quote('哈基米南北绿豆 ちみーをなめると')
      )
      -- not sure why
      if _VERSION == 'Lua 5.1' and not jit then
        assert.equal('\xe9\xe0\xdf', shlex.quote('\xe9\xe0\xdf'))
      else
        assert.equal("'\xe9\xe0\xdf'", shlex.quote('\xe9\xe0\xdf'))
      end
    end)
  end)

  describe('join', function()
    it('should join simple tokens', function()
      assert.equal('a b c', shlex.join({ 'a', 'b', 'c' }))
    end)

    it('should join tokens with spaces, quoting them', function()
      assert.equal("a 'b c' d", shlex.join({ 'a', 'b c', 'd' }))
    end)

    it('should handle tokens with embedded single quotes', function()
      assert.equal("a 'b'\"'\"'c' d", shlex.join({ 'a', "b'c", 'd' }))
    end)

    it('should handle empty tokens', function()
      assert.equal("a '' b", shlex.join({ 'a', '', 'b' }))
    end)

    it('should handle only empty tokens', function()
      assert.equal("''", shlex.join({ '' }))
      assert.equal("'' ''", shlex.join({ '', '' }))
    end)

    it('should handle tokens with special characters', function()
      assert.equal("a '$(`~' b", shlex.join({ 'a', '$(`~', 'b' }))
    end)

    it('should perform a roundtrip (split then join)', function()
      local test_str =
        'command "arg with \\"escaped quote\\" and \\\\ backslash" \'arg with \\\'single quote\\\' and \\\\ backslash\' foo\\ bar\\ baz'
      local tokens = shlex.split(test_str)
      local joined_str = shlex.join(tokens)
      local resplit_tokens = shlex.split(joined_str)
      assert.same(tokens, resplit_tokens)
    end)

    it('should perform a roundtrip with complex nested quoting', function()
      local filename = 'somefile; rm -rf ~'
      local command_quoted = shlex.quote(filename)
      local remote_command_str = ('ssh home %s'):format(command_quoted)

      local remote_command_split = shlex.split(remote_command_str)
      assert.same({ 'ssh', 'home', 'somefile; rm -rf ~' }, remote_command_split)

      local roundtrip_remote_command_str = shlex.join(remote_command_split)
      local roundtrip_remote_command_split = shlex.split(roundtrip_remote_command_str)
      assert.same(remote_command_split, roundtrip_remote_command_split)
    end)

    it('should handle roundtrip with multi-quoted', function()
      local s_filename = 'somefile; rm -rf ~'
      local q_filename = shlex.quote(s_filename)
      local s_command = 'ls -l ' .. q_filename
      local q_command = shlex.quote(s_command)
      local s_remote_command = 'ssh home ' .. q_command

      local split_remote_command = shlex.split(s_remote_command)
      assert.same({ 'ssh', 'home', "ls -l 'somefile; rm -rf ~'" }, split_remote_command)

      local resplit_command = shlex.split(split_remote_command[3])
      assert.same({ 'ls', '-l', 'somefile; rm -rf ~' }, resplit_command)

      local joined_resplit_command = shlex.join(resplit_command)
      local final_split_from_join = shlex.split(joined_resplit_command)
      assert.same(resplit_command, final_split_from_join)
    end)
  end)
end)
