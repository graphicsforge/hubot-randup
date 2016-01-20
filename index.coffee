# Description:
#   Have Hubot remind you to do randups.
#   Forked from https://github.com/hubot-scripts/hubot-standup-alarm
#
# Dependencies:
#   slack-client
#   underscore
#   cron


cronJob = require('cron').CronJob
_ = require('underscore')
Slack = require('slack-client')

slack = new Slack(process.env.HUBOT_SLACK_TOKEN, true, true);
slack.on 'error', (err) ->
  # something fatal and terrible happened out of the gate
  throw err
slack.login()

module.exports = (robot) ->

  # Compares current time to the time of the standup
  # to see if it should be fired.
  standupShouldFire = (standup) ->
    standupTime = standup.time
    utc = standup.utc
    now = new Date
    currentHours = undefined
    currentMinutes = undefined
    if utc
      currentHours = now.getUTCHours() + parseInt(utc, 10)
      currentMinutes = now.getUTCMinutes()
      if currentHours > 23
        currentHours -= 23
    else
      currentHours = now.getHours()
      currentMinutes = now.getMinutes()
    standupHours = standupTime.split(':')[0]
    standupMinutes = standupTime.split(':')[1]
    try
      standupHours = parseInt(standupHours, 10)
      standupMinutes = parseInt(standupMinutes, 10)
    catch _error
      return false
    if standupHours == currentHours and standupMinutes == currentMinutes
      return true
    false

  # Returns all standups.
  getStandups = ->
    robot.brain.get('standups') or []

  # Returns just standups for a given room.
  getStandupsForRoom = (room) ->
    _.where getStandups(), room: room

  # Gets all standups, fires ones that should be.
  checkStandups = ->
    standups = getStandups()
    _.chain(standups).filter(standupShouldFire).pluck('room').each doStandup
    return

  # Fires the standup message.
  doStandup = (room) ->
    channels = (channel for id, channel of slack.channels when channel.is_member)
    for channel in channels when channel.name==room
      # is this how to do things in coffeescript?  it'd better not be!
      members = (slack.getUserByID id for id in channel.members when slack.getUserByID and slack.getUserByID(id).presence=='active' and !slack.getUserByID(id).is_bot)
      lucky_user = _.sample members

      message = '@'+lucky_user.name+': '+_.sample(STANDUP_MESSAGES)
      robot.messageRoom room, message
    return

  # Finds the room for most adaptors
  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  # Stores a standup in the brain.
  saveStandup = (room, time, utc) ->
    standups = getStandups()
    newStandup = 
      time: time
      room: room
      utc: utc
    standups.push newStandup
    updateBrain standups
    return

  # Updates the brain's standup knowledge.
  updateBrain = (standups) ->
    robot.brain.set 'standups', standups
    return

  clearAllStandupsForRoom = (room) ->
    standups = getStandups()
    standupsToKeep = _.reject(standups, room: room)
    updateBrain standupsToKeep
    standups.length - (standupsToKeep.length)

  clearSpecificStandupForRoom = (room, time) ->
    standups = getStandups()
    standupsToKeep = _.reject(standups,
      room: room
      time: time)
    updateBrain standupsToKeep
    standups.length - (standupsToKeep.length)

  'use strict'
  # Constants.
  STANDUP_MESSAGES = [
    'Random slackup!  For more details type `@' +robot.name + ' randup what`',
    'Whatcha up to?  For more details type `@' +robot.name + ' randup what`',
    'What\'s queue\'in?  For more details type `@' +robot.name + ' randup what`'
  ]

  # Check for standups that need to be fired, once a minute
  # Monday to Friday.
  new cronJob('1 * * * * 1-5', checkStandups, null, true)

  robot.respond /delete all randups for (.+)$/i, (msg) ->
    room = msg.match[1]
    standupsCleared = clearAllStandupsForRoom(room)
    msg.send 'Deleted ' + standupsCleared + ' randups for ' + room

  robot.respond /delete all randups$/i, (msg) ->
    standupsCleared = clearAllStandupsForRoom(findRoom(msg))
    msg.send 'Deleted ' + standupsCleared + ' randup' + (if standupsCleared == 1 then '' else 's') + '. No more randups for you.'
    return
  robot.respond /delete ([0-5]?[0-9]:[0-5]?[0-9]) randup/i, (msg) ->
    time = msg.match[1]
    standupsCleared = clearSpecificStandupForRoom(findRoom(msg), time)
    if standupsCleared == 0
      msg.send 'Nice try. You don\'t even have a randup at ' + time
    else
      msg.send 'Deleted your ' + time + ' randup.'
    return
  robot.respond /create randup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, (msg) ->
    time = msg.match[1]
    room = findRoom(msg)
    saveStandup room, time
    msg.send 'Ok, from now on I\'ll remind this room to do a randup every weekday at ' + time
    return
  robot.respond /create randup ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) UTC([+-]([0-9]|1[0-3]))$/i, (msg) ->
    time = msg.match[1]
    utc = msg.match[2]
    room = findRoom(msg)
    saveStandup room, time, utc
    msg.send 'Ok, from now on I\'ll remind this room to do a randup every weekday at ' + time + ' UTC' + utc
    return
  robot.respond /list randups$/i, (msg) ->
    standups = getStandupsForRoom(findRoom(msg))
    if standups.length == 0
      msg.send 'Well this is awkward. You haven\'t got any randups set :-/'
    else
      standupsText = [ 'Here\'s your randups:' ].concat(_.map(standups, (standup) ->
        if standup.utc
          standup.time + ' UTC' + standup.utc
        else
          standup.time
      ))
      msg.send standupsText.join('\n')
    return
  robot.respond /list randups in every room/i, (msg) ->
    standups = getStandups()
    if standups.length == 0
      msg.send 'No, because there aren\'t any.'
    else
      standupsText = [ 'Here\'s the randups for every room:' ].concat(_.map(standups, (standup) ->
        'Room: ' + standup.room + ', Time: ' + standup.time
      ))
      msg.send standupsText.join('\n')
    return
  robot.respond /randup now/i, (msg) ->
    doStandup msg.envelope.room
  robot.respond /randup what/i, (msg) ->
    message = []
    message.push 'I can randomly select someone to give a quick status!'
    message.push 'Not every department is tracked on github, jira, or zendesk... and maybe not everyone has access to all of those.'
    message.push 'A random standup allows anyone to shine, and doesn\'t use up everyone\'s time every single time.'
    message.push ''
    message.push 'type `@'+robot.name+' randup help` for command listing.'
    msg.send message.join('\n')
    return
  robot.respond /randup help/i, (msg) ->
    message = []
    message.push 'I can remind you to do your randups!'
    message.push 'Use me to create a randup, and then I\'ll post in this room every weekday at the time you specify. Here\'s how:'
    message.push ''
    message.push '`@' + robot.name + ' create randup hh:mm` - I\'ll remind you to randup in this room at hh:mm every weekday.'
    message.push '`@' + robot.name + ' create randup hh:mm UTC+2` - I\'ll remind you to randup in this room at hh:mm every weekday.'
    message.push '`@' + robot.name + ' list randups` - See all randups for this room.'
    message.push '`@' + robot.name + ' list randups in every room` - Be nosey and see when other rooms have their randup.'
    message.push '`@' + robot.name + ' delete hh:mm randup` - If you have a randup at hh:mm, I\'ll delete it.'
    message.push '`@' + robot.name + ' delete all randups` - Deletes all randups for this room.'
    message.push '`@' + robot.name + ' randup now` - Manually trigger a randup in this room.'
    msg.send message.join('\n')
    return
  return
