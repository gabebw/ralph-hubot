# Description:
#   Save "Hey Future Joe, check out this link" type messages and say them when
#   Joe (e.g.) comes back.
#
# Dependencies:
#   * A robot.brain that saves to persistent storage. I've only tested this with
  #   redis-brain (available by default)
#   * Underscore.js
#
# Configuration:
#   * Ensure your brain's persistent storage is set up (e.g. RedisToGo on Heroku).

_ = require 'underscore'

class FutureMessager
  constructor: (robot) ->
    robot.brain.data.futureMessages ?= {}
    @brain = robot.brain.data.futureMessages

  saveForLater: (msg) ->
    targetUser = msg.match[1].toLowerCase()
    sender = msg.message.user.name
    room = msg.message.user.room
    @brain[room] ?= {}
    @brain[room][targetUser] ?= []

    @brain[room][targetUser].push(@textForLater(msg, sender))
    msg.send "OK #{sender}, I'll tell #{targetUser} that when they get back."

  textForLater: (msg, sender) ->
    timestamp = (new Date()).toLocaleString()
    "[#{timestamp}] From: #{sender} | #{msg.message.text}"

  tellUserAboutMissedMessages: (msg) ->
    newlyEnteredUsername = msg.message.user.name.toLowerCase()
    room = msg.message.user.room

    if @brain[room]?
      # Scan stored matches for newly-entered user
      resultOfScanningForPings = @prefixedWith(newlyEnteredUsername, _.keys(@brain[room]))
      if resultOfScanningForPings.length > 0
        sentNotification = false
        for previouslyPingedUsername in resultOfScanningForPings
          if @brain[room][previouslyPingedUsername].length > 0
            if sentNotification is false
              # Notify them that they have some messages coming up
              msg.send "Hey #{newlyEnteredUsername}, you have some messages:"
              sentNotification = true
          for pastMessage in @brain[room][previouslyPingedUsername]
            msg.send "> #{pastMessage}"
          @brain[room][previouslyPingedUsername] = []

  # Find names in the possibleUsernames that start with the given nickname.
  prefixedWith: (nickname, possibleUsernames) ->
    lowerNickname = nickname.toLowerCase()
    username for username in possibleUsernames when (
      username.toLowerCase().lastIndexOf(lowerNickname, 0) is 0
    )

module.exports = (robot) ->
  # Ensure the brain is loaded.
  robot.brain.on 'loaded', ->
    futureMessager = new FutureMessager(robot)

    # Listen for messages like "Hey future Joe, tell me a joke".
    robot.hear /future ([a-z]+)/i, (msg) ->
      futureMessager.saveForLater(msg)

    # When a user enters, tell them about the messages they missed.
    robot.enter (msg) ->
      futureMessager.tellUserAboutMissedMessages(msg)
