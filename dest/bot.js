(function() {
  var Bot, DB, EventEmitter, exec, express, inspect, setting, util,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  setting = require('../setting');

  util = require('./util');

  DB = require('./db');

  EventEmitter = require('events').EventEmitter;

  exec = require('child_process').exec;

  inspect = require('util').inspect;

  express = require('express');

  module.exports = Bot = (function(superClass) {
    extend(Bot, superClass);

    function Bot(logger) {
      var app, server;
      this.logger = logger;
      app = express();
      app.get('/', function(req, res) {
        return res.send('matcha mura');
      });
      server = app.listen(setting.PORT, (function(_this) {
        return function() {
          return _this.logger.info("server listening at " + (server.address().port) + " port");
        };
      })(this));
      this.db = new DB;
      this.pexec = (function(_this) {
        return function(cmd) {
          return new Promise(function(resolve, reject) {
            return exec(cmd, function(err, stdout, stderr) {
              if (stderr) {
                _this.logger.trace(stderr.toString());
              }
              if (!err) {
                return resolve(stdout.toString());
              } else {
                return reject(err);
              }
            });
          });
        };
      })(this);
      this.on('command', (function(_this) {
        return function(user, cmd, respond) {
          var args, command, list, num, report;
          args = cmd.split(/[\s　]+/);
          command = args[0];
          args.splice(0, 1);
          switch (command) {
            case 'restart':
              return _this.pexec("ps -ef | egrep '[S]CREEN.+minecraft' | awk '{print $2};'").then(function(out) {
                var pid;
                if (out.length > 0) {
                  pid = parseInt(out);
                  console.log(pid);
                  return _this.pexec("kill -9 " + pid).then(function() {
                    return respond("server was alive... kill process. please try again.");
                  });
                } else {
                  return _this.pexec("/etc/init.d/minecraft start").then(function() {
                    return respond("server was down... server has started!");
                  });
                }
              })["catch"](function(err) {
                _this.logger.error(err.message);
                return respond("error.");
              });
            case 'list':
              return _this.pexec("/etc/init.d/minecraft command list").then(function(out) {
                var line, message, num, players, sp;
                line = out.split(/\r*\n/);
                line.splice(0, 2);
                num = 0;
                if (line.length > 0) {
                  sp = line[0].split(']: ');
                  if (sp.length === 2) {
                    players = sp[1].split(', ');
                    players = players.filter(function(p) {
                      return _this.db.mutedCache.every(function(u) {
                        return u !== p;
                      });
                    });
                    num = players.length;
                  }
                }
                message = "There are " + num + " players!";
                message += " (" + (players.join(', ')) + ")";
                return respond(message);
              })["catch"](function(err) {
                _this.logger.error(err.message);
                return respond("error.");
              });
            case 'mute':
              list = _this.db.mutedCache.join(', ');
              return respond("muted: " + list);
            case 'addmute':
              if (args.length === 0) {
                return respond("usage: addmute (user1) [user2] ...");
              }
              return Promise.all(args.map(function(user) {
                return _this.db.addMute(user);
              })).then(function(res) {
                return respond("ok.");
              })["catch"](function(err) {
                _this.logger.error(err.message);
                return respond("error.");
              });
            case 'removemute':
              if (args.length === 0) {
                return respond("usage: removemute (user1) [user2] ...");
              }
              return Promise.all(args.map(function(user) {
                return _this.db.removeMute(user);
              })).then(function(res) {
                return respond("ok.");
              })["catch"](function(err) {
                _this.logger.error(err.message);
                return respond("error.");
              });
            case 'report':
              if (args.length === 0) {
                return _this.db.find().then(function(res) {
                  var doc, i, len, str;
                  str = "";
                  for (i = 0, len = res.length; i < len; i++) {
                    doc = res[i];
                    str += "[" + doc.num + "] " + doc.message + "\n";
                  }
                  return respond(str);
                })["catch"](function(err) {
                  _this.logger.error(err.message);
                  return respond("err");
                });
              } else {
                report = args.join(' ');
                return _this.db.register(user, report).then(function(res) {
                  return respond("ok.");
                })["catch"](function(err) {
                  _this.logger.error(err.message);
                  return respond("error.");
                });
              }
              break;
            case 'delete':
              if (args.length !== 1) {
                return respond("usage: delete (report number)");
              }
              num = parseInt(arg[0]);
              return _this.db.remove(num).then(function(res) {
                return respond("ok.");
              })["catch"](function(err) {
                _this.logger.error(err.message);
                return respond("error.");
              });
            default:
              return respond("unknown command: " + command);
          }
        };
      })(this));
    }

    return Bot;

  })(EventEmitter);

}).call(this);