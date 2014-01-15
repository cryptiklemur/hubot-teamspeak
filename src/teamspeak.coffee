# Hubot dependencies
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require 'hubot'

# teamspeak library
Teamspeak = require 'node-teamspeak'

class TeamspeakBot extends Adapter
  run: ->
    self = @

    do @checkCanStart

    options =
      nick:     process.env.HUBOT_TEAMSPEAK_NICK or @robot.name
      server:   process.env.HUBOT_TEAMSPEAK_SERVER
      password: process.env.HUBOT_TEAMSPEAK_PASSWORD

    @robot.name = options.nick
    bot = new Teamspeak options.server
    response = bot.send("login", {client_login_name: options.nick})
    console.log(response);
    
    @bot = bot

exports.use = (robot) ->
  new TeamspeakBot robot
