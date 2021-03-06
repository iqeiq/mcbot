setting = require '../setting'
util = require './util'
DB = require './db'
dm = require './deathmessages'

{EventEmitter} = require 'events'
{exec} = require 'child_process'
{inspect} = require 'util'


express = require 'express'

module.exports = class Bot extends EventEmitter
  constructor: (@logger)->
    # server
    app = express()
    app.get '/', (req, res)-> res.send 'matcha mura'
    server = app.listen setting.PORT, =>
      @logger.info "server listening at #{server.address().port} port"
    
    # DB
    @db = new DB

    @emitter = []

    @morningcall = []

    @alarmstart()

    mclogfile = setting.MCLOG

    watcher = require('fs').watch mclogfile, (event)=>
      if event is 'rename'
        @logger.info "logfile rotated. try restart."
        return process.exit 1
      return unless event is 'change'
      prevlog = ""
      exec "tail -n 1 #{mclogfile}", (err, stdout, stderr)=>
        @logger.error err if err
        @logger.trace stderr.toString() if stderr
        return if err or stderr
        line = stdout.toString().split /\r*\n/
        return if line.length is 0
        sp = line[0].split /]:\s*/
        return if sp.length < 2
        t = sp[0].split(/\s+/)[0]
        return if sp[1].length is 0
        mes = "#{t} #{sp[1]}"
        return if mes is prevlog
        prevlog = mes
        
        if /<[^>]+>\s*#/.test mes
          res = /<([^>]+)>\s*#\s*(.+)/.exec mes
          @emit 'command', res[1], res[2], (res)=>
            for line in res.split /\r*\n/
              @pexec "/etc/init.d/minecraft command say '#{line}'"
                .catch (err)=>
                  logger.error err if err
          return

        return if @db.mutedCache.some((u)-> ///#{u}///.test mes)

        flag = false
        unless /<[^>]+>/.test mes
          if /the game/.test mes
            flag = true
          else if /earned the achievement/.test mes
            flag = true
          else if dm.some((v)-> v.test mes)
            flag = true
        @say mes if flag

    @on 'command', (user, cmd, respond)=>
      args = cmd.split /[\s　]+/
      command = args[0]
      args.splice 0, 1

      switch command
        when 'restart'
          @pexec "ps -ef | egrep '[S]CREEN.+minecraft' | awk '{print $2};'"
            .then (out)=>
              if out.length > 0
                if user isnt 'mokha_trogy'
                  respond "server was alive... Permission denied."
                  return
                pid = parseInt out[0]
                console.log pid
                @pexec "kill -9 #{pid}"
                  .then ->
                    respond "server was alive... kill process. please try again."
              else
                @pexec "/etc/init.d/minecraft start"
                  .then ->
                    respond "server was down... server has started!"
            .catch (err)=>
              @logger.error err.message
              respond "error."
        when 'list'
          @pexec "/etc/init.d/minecraft command list"
            .then (out)=>
              line = out.split /\r*\n/
              line.splice 0, 2
              num = 0
              if line.length > 0
                sp = line[0].split /]:\s*/
                if sp.length is 2
                  if sp[1].length > 0
                    players = sp[1].split ', '
                    players = players.filter (p)=> 
                      @db.mutedCache.every (u)-> u isnt p
                    num = players.length
              else
                @logger.debug "failed to getting player list."
                @emit 'command', user, cmd, respond
                return
              message = "There are #{num} players!"
              message += " (#{players.join ', '})" if num isnt 0
              respond message 
            .catch (err)=>
              @logger.error err.message
              respond "error."
        when 'time'
          @pexec "/etc/init.d/minecraft command time query daytime"
            .then (out)=>
              line = out.split /\r*\n/
              line.splice 0, 1
              return if line.length is 0
              sp = line[0].split /Time\s*is\s*/
              return unless sp.length is 2
              return if sp[1].length is 0
              daytime = parseInt sp[1]
              time = daytime % 24000
              day = Math.floor daytime / 24000
              hour = (Math.floor(time / 1000) + 6) % 24
              minute = Math.floor (time % 1000) * 60 / 1000.0
              message = "Day #{day}  #{hour}:#{util.zeroFill(minute,2)}"
              respond message 
            .catch (err)=>
              @logger.error err.message
              respond "error."
        when 'alarm'
          @morningcall.push user
          respond "ok."
        when 'mute'
          list = @db.mutedCache.join ', '
          respond "muted: #{list}"
        when 'addmute'
          if args.length is 0
            #return respond "usage: addmute (user1) [user2] ..."
            args.push user
          Promise.all args.map((user)=> @db.addMute user)
            .then (res)-> respond "ok."
            .catch (err)=>
              @logger.error err.message
              respond "error."
        when 'removemute'
          if args.length is 0
            #return respond "usage: removemute (user1) [user2] ..."
            args.push user
          Promise.all args.map((user)=> @db.removeMute user)
            .then (res)-> respond "ok."
            .catch (err)=>
              @logger.error err.message
              respond "error."
        when 'report'
          if args.length is 0
            @db.find()
              .then (res)->
                str = ""
                for doc in res
                  str += "\n[#{doc.num}] #{doc.message}"
                respond str
              .catch (err)=>
                @logger.error err.message
                respond "error."
          else
            report = args.join ' '
            @db.register user, report
              .then (res)-> respond "ok."
              .catch (err)=>
                @logger.error err.message
                respond "error."
        when 'report_no'
          if args.length isnt 1
            return respond "usage: report_no (number)  (( report => report_no in Twitter ))"
          else
            num = parseInt args[0]
            @db.findOne {num: num}
              .then (doc)->
                if doc?
                  respond "\n[#{doc.num}] #{doc.message}"
                else
                  respond "Not Found."
              .catch (err)=>
                @logger.error err.message
                respond "error."
        when 'delete'
          unless args.length is 1
            return respond "usage: delete (report number)"
          num = parseInt args[0]
          @db.remove num
            .then (res)-> respond "ok."
            .catch (err)=>
              @logger.error err.message
              respond "error."
        else
          respond "unknown command: #{command}"

  say: (text)->
    console.log "say: " + text
    Promise.all @emitter.map((saye)=> saye text)
      .catch =>
        @logger.error err.message

  addEmitter: (cb)->
    @emitter.push cb

  pexec: (cmd)->
    new Promise (resolve, reject)=>
      exec cmd, (err, stdout, stderr)=>
        @logger.trace stderr.toString() if stderr
        unless err
          resolve stdout.toString()
        else
          reject err

  alarmstart: (cnt = 0)->
    if cnt > 3
      @logger.error "failed to starting alarm cycle."
      return
    @pexec "/etc/init.d/minecraft command time query daytime"
    .then (out)=>
      line = out.split /\r*\n/
      line.splice 0, 1
      if line.length is 0
        @alarmstart cnt + 1 
        return
      sp = line[0].split /Time\s*is\s*/
      unless sp.length is 2
        @alarmstart cnt + 1 
        return 
      if sp[1].length is 0
        @alarmstart cnt + 1 
        return
      daytime = parseInt sp[1]
      time = daytime % 24000
      ms = (24000 - time) * 50
      setTimeout =>
        @morningTimer()
      , ms
    .catch (err)=>
      @logger.error err.message


  morningTimer: ->
    for user in @morningcall
      @say "@#{user} asadayo- #{new Date().getTime()}"
    @morningcall = []
    setTimeout =>
      @morningTimer()
    , 1200000