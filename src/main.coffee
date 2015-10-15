setting = require '../setting'
Bot = require './bot'
Twitter = require './twitter'
Repl = require './repl'

{inspect} = require 'util'
{exec, spawn} = require 'child_process'
log4js = require 'log4js'

#log
log4js.configure 'log4js.json',
  reloadSecs: 60

logger = log4js.getLogger "system"
tracer = log4js.getLogger "trace"

# bot
bot = new Bot logger

emitter = (user, command)->
  new Promise (resolve, reject)->
    bot.emit 'command', user, command, (res)-> resolve res

# repl
repl = new Repl logger, emitter

# twitter
twi = new Twitter logger, emitter

child = spawn 'tail', ['-n', '1', '-f', '~/minecraft4/logs/latest.log']
child.stdout.on 'data', (stdout)->
  line = stdout.toString()
  console.log line
  sp = line[0].split ']: '
  return if sp.length < 2
  mes = sp[1]
  console.log mes
  return if @db.mutedCache.some((u)-> ///#{u}///.test mes)
  if /joined the game/.test mes
    twi.tweet mes
  else if /earned the achievement/.test mes
    twi.tweet mes
  else if /connection/.test mes
    return
  else if /UUID/.test mes
    return
  else if /logged/.test mes
    return
  else  if /<[^>]+> [^#]/.test mes
    return
  twi.tweet mes

# uncaughtException
process.on 'uncaughtException', (err)->
  tracer.trace err.stack
  logger.error err.message