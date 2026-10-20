[6:0] ')' expected near 'local'

Error: failed to minify. Make sure the Lua code is valid.
If you think this is a bug in luamin, please report it:
https://github.com/mathiasbynens/luamin/issues/new

Stack trace using luamin@1.0.4 and luaparse@0.2.1:

SyntaxError: [6:0] ')' expected near 'local'
    at raise (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:460:15)
    at expect (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1049:10)
    at parseCallExpression (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1975:11)
    at parsePrefixExpression (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1942:20)
    at parseAssignmentOrCallStatement (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1593:18)
    at parseStatement (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1316:12)
    at parseBlock (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1271:19)
    at parseChunk (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:1248:16)
    at end (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:2094:17)
    at parse (/usr/local/lib/node_modules/luamin/node_modules/luaparse/luaparse.js:2065:31)
