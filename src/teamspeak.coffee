# Hubot dependencies
Robot   = require '../../hubot/src/robot'
Adapter = require '../../hubot/src/adapter'
{TextMessage, EnterMessage, LeaveMessage} = require '../../hubot/src/message'

# teamspeak library
Teamspeak = require 'node-teamspeak'
util	  = require 'util'
fs	  = require 'fs'

class TeamspeakBot extends Adapter
	send: (envelope, strings...) ->
		console.log "Sending"
		for str in strings
			@message envelope.user, str

	reply: (envelope, strings...) ->
		console.log "Replying"
		for str in strings
			@message envelope.user, str

	message: (client, message) ->
		self = @
		console.log "Firing sendtextmessage"
		self.bot.send "sendtextmessage", {targetmode: 1, target: client.clid, msg: message}
		console.log "Done firing sendtextmessage"

	getUserFromName: (name) ->
		return @robot.brain.userForName(name) if @robot.brain?.userForName?

		return @userForName name

	getUserFromId: (id) ->
		return @robot.brain.userForId(id) if @robot.brain?.userForId?

		return @userForId id

	createUser: (client) ->
		user = @getUserFromName client.client_nickname
		unless user?
			id = client.client_database_id
			user = @getUserFromId id
			user.name = client.client_nickname
			for key, value of client
				user[key] = client[key]
	
		user

	checkCanStart: ->
		if not process.env.HUBOT_TEAMSPEAK_CONFIG
			throw new Error("HUBOT_TEAMSPEAK_CONFIG is not defined; try: export HUBOT_TEAMSPEAK_CONFIG='/path/to/some/config.js'")

	loadConfig: (configLocation) ->
		file = fs.readFileSync configLocation, {encoding: 'UTF-8'}
		@config = JSON.parse(file);

	run: ->
		self = @

		do @checkCanStart
		@loadConfig process.env.HUBOT_TEAMSPEAK_CONFIG

		@robot.name = @config.nick
		bot = new Teamspeak @config.server
		@bot = bot

		do @doLogin

	doLogin: ->
		self = @
		self.bot.send "login", {client_login_name: self.config.username, client_login_password: self.config.password}, (err, resp) ->
			self.bot.send "use", {sid: 1}, ->
				self.bot.send "clientupdate", {client_nickname: self.config.nick}
				do self.doBinds
				self.emit "connected"
	doBinds: ->
		self = @
		self.bot.send "servernotifyregister", {event: "textprivate"}
		self.bot.send "servernotifyregister", {event: "textserver"}
		self.bot.send "servernotifyregister", {event: "channel", id: 0}

		self.bot.send "channellist", {}, (err, response) ->
			for channel in response
				self.bot.send "servernotifyregister", {event: "channel", id: channel.cid}
				self.bot.send "servernotifyregister", {event: "textchannel", id: channel.cid}

		self.bot.on 'connect', (err, response) ->
			console.log response 

		self.bot.on 'error', (err) ->
			console.log err 

		console.log "Binding TextMessage"
		self.bot.on "textmessage", (event) ->
			user = self.getUserFromName event.invokername
			unless user?
				self.bot.send "clientinfo", {clid: event.invokerid}, (err, client) ->
					client.clid = event.invokerid
					console.log client
					user = self.createUser client
					self.buildTextMessage user, event.msg
					return

			self.buildTextMessage user, event.msg
	
	buildTextMessage: (user, message) ->
		@receive new TextMessage user, message

	receive: (message) ->
		@robot.receive message
	
	error: (e) ->
		console.log "There was an error."
		console.log e

exports.use = (robot) ->
  new TeamspeakBot robot
