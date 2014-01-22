# Hubot dependencies
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require 'hubot'

# teamspeak library
Teamspeak  = require 'node-teamspeak'
util	   = require 'util'
fs		 = require 'fs'

class TeamspeakBot extends Adapter
	poke: (name, message = "") ->
		self = @
		self.bot.send "clientfind", {pattern: name}, (err, response) ->
			self.bot.send "clientpoke", {clid: response.clid, msg: message}
	
	megaPoke: (name, count = 100, message="") ->
		self = @
		time = 250
		for i in [0..count] by 1
			setTimeout ->
				self.poke name, message
			, time
			time = time + 250
		
	message: (client, message = "") ->
		self = @
		self.bot.send "sendtextmessage", {targetmode: 1, target: client.clid, msg: message}

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
				do self.messageClients
		  
	messageClients: ->
		self = @
		self.bot.send "clientlist", (err, resp) ->
			for client in resp
				continue if self.config.debug.enabled and client.client_database_id != self.config.debug.user
				self.message client, "Hey there #{client.client_nickname}. Your friendly neighborhood bot is back!"
				self.addUserToBrain client
	
	doBinds: ->
		self = @
		#self.bot.send "servernotifyregister", {event: "server"} # Apparently unnecessary
		self.bot.send "servernotifyregister", {event: "textprivate"}
		self.bot.send "servernotifyregister", {event: "textserver"}
		self.bot.send "servernotifyregister", {event: "channel", id: 0}

		console.log "Fetching Channels"
		self.bot.send "channellist", {}, (err, response) ->
			for channel in response
				self.bot.send "servernotifyregister", {event: "channel", id: channel.cid}
				self.bot.send "servernotifyregister", {event: "textchannel", id: channel.cid}

		self.bot.on 'connect', (err, response) ->
			console.log response 

		self.bot.on 'error', (err) ->
			console.log err 

		console.log "Binding!"

		self.binds.connect self
		self.binds.join self
		self.binds.chat self
	
	binds: 
		connect: (self) ->
			self.bot.on 'cliententerview', (event) ->
				console.log 'Client Connected'

				return if self.config.debug.enabled and event.client_database_id != self.config.debug.user
				self.message event, self.config.welcome.message.format event.client_nickname 
				
				self.addUserToBrain event
			
		join: (self) ->
			self.bot.on "clientmoved", (event) ->
				console.log 'Client Moved Channels'
				console.log event

		chat: (self) ->
			self.bot.on 'textmessage', (event) ->
				console.log 'Client sent the bot a message'
				console.log event
				console.log self.userForName event.invokername

	addUserToBrain: (client) ->
		self = @
		console.log "Adding user to brain"
		console.log self.robot.brain
		self.bot.send "clientinfo", {clid: client.clid}, (err, response) ->
			response['name'] = response.client_nickname
			self.robot.brain.userForId(response.client_database_id, response)
		

exports.use = (robot) ->
  new TeamspeakBot robot

  
String.prototype.format = ->
	args = arguments
	return this.replace /{(\d+)}/g, (match, number) ->
		return if typeof args[number] isnt 'undefined' then args[number] else match
