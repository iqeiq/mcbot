(function() {
  var Bot, Repl, Twitter, bot, child, emitter, exec, inspect, log4js, logger, ref, repl, setting, spawn, tracer, twi;

  setting = require('../setting');

  Bot = require('./bot');

  Twitter = require('./twitter');

  Repl = require('./repl');

  inspect = require('util').inspect;

  ref = require('child_process'), exec = ref.exec, spawn = ref.spawn;

  log4js = require('log4js');

  log4js.configure('log4js.json', {
    reloadSecs: 60
  });

  logger = log4js.getLogger("system");

  tracer = log4js.getLogger("trace");

  bot = new Bot(logger);

  emitter = function(user, command) {
    return new Promise(function(resolve, reject) {
      return bot.emit('command', user, command, function(res) {
        return resolve(res);
      });
    });
  };

  repl = new Repl(logger, emitter);

  twi = new Twitter(logger, emitter);

  child = spawn('tail', ['-n', '1', '-f', '~/minecraft4/logs/latest.log']);

  child.stdout.on('data', function(stdout) {
    var line, mes, sp;
    line = stdout.toString();
    console.log(line);
    sp = line[0].split(']: ');
    if (sp.length < 2) {
      return;
    }
    mes = sp[1];
    console.log(mes);
    if (this.db.mutedCache.some(function(u) {
      return RegExp("" + u).test(mes);
    })) {
      return;
    }
    if (/joined the game/.test(mes)) {
      twi.tweet(mes);
    } else if (/earned the achievement/.test(mes)) {
      twi.tweet(mes);
    } else if (/connection/.test(mes)) {
      return;
    } else if (/UUID/.test(mes)) {
      return;
    } else if (/logged/.test(mes)) {
      return;
    } else if (/<[^>]+> [^#]/.test(mes)) {
      return;
    }
    return twi.tweet(mes);
  });

  process.on('uncaughtException', function(err) {
    tracer.trace(err.stack);
    return logger.error(err.message);
  });

}).call(this);