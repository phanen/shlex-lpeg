[shlex](https://docs.python.org/3/library/shlex.html) in [lpeg](http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html)

## Todo
* comment string
* stream parsing

## Install
```sh
luarocks install --local shlex-lpeg
# luarocks install shlex-lpeg
```

## Test
```sh
lx --lua-version 5.1 test --impure -- -m '?.lua'
```

## Related
* https://github.com/python/cpython/blob/220c0a8156ad5d33a85fda3cc2b80a3e3d424195/Lib/shlex.py
* https://github.com/ruby/shellwords
* https://github.com/mattn/go-shellwords
