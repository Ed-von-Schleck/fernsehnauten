Meteor.publish "channels", ->
  return Channels.find({})

Meteor.publish "public_rooms", () ->
  return Rooms.find
    "options.visible": "public"
    active: true
           
Meteor.publish "member_rooms", () ->
  if @userId?
    return Rooms.find
      "options.visible": "members"
      active: true

Meteor.publish "user_rooms", () ->
  if @userId?
    return Rooms.find
      "options.visible": "user"
      owner_id: @userId
      active: true

Meteor.publish "friend_rooms", () ->
  if @userId?
    friends = Meteor.users.findOne({_id: @userId}, {fields: friends: 1}).friends
    friend_ids = (friend.user_id for friend in friends when friend.status is "accepted")
    friend_ids.push @userId
    return Rooms.find
      "options.visible": "friends"
      active: true
      owner_id:
        $in: friend_ids

Meteor.publish "friends", ->
  return if not @userId
  friends = Meteor.users.findOne({_id: @userId}, {fields: friends: 1}).friends
  friend_ids = (friend.user_id for friend in friends)
  selector =
    _id:
      $in: friend_ids

  options =
    fields:
      profile: 1
      username: 1
      email_hash: 1

  fields = ["profile", "username", "email_hash", "status"]
  
  handle = Meteor.users.find(selector, options).observe
    added: (doc, before_index) =>
      doc.status = friend.status for friend in friends when friend.user_id is doc._id
      @set "friends", doc._id, doc
      @flush()
    removed: (doc, at_index) =>
      @unset "friends", doc._id, fields
      @flush()
    changed: (doc, at_index, old_doc) =>
      @unset "friends", old_doc._id, fields
      @set "friends", doc._id, doc
      @flush()

  @onStop =>
    handle.stop()
    Meteor.users.find(selector, options).forEach (doc) =>
      @unset "friends", doc._id, fields
    @flush()
  
Meteor.publish "userData", () ->
  return Meteor.users.find {
      _id: @userId
    }, {
      fields:
        friends: 1
        email_hash: 1
    }

Meteor.publish "ratings", ->
  return Ratings.find()
###
Meteor.publish "active_channel", (channel_id) ->
  @old_keys = []
  @old_ids = []

  publish_channel = =>
    for _id in @old_ids
      @unset "active_channel", _id, @old_keys
    @old_keys = []
    @old_ids = []

    timestamp = +new Date / 1000 | 0

    channel = Programs.find
      channel: channel_id
      start:
        $lt: timestamp + 60 * 60 * 12
        $gt: timestamp - 60 * 60 * 12

    channel.forEach (doc) =>
      @old_keys = (key for key, val of doc) if @old_keys.length isnt 0
      @old_ids.push doc._id
      @set "active_channel", doc._id, doc
    @flush()
  publish_channel()
  Meteor.setTimeout publish_channel, 1000 * 60 * 60

  @onStop =>
    for _id in @old_ids
      @unset "active_channel", _id, @old_keys
      @flush()
###
Meteor.publish "messages", (room_id, limit) ->
  room = Rooms.findOne {
    _id: room_id
  },{
    fields:
      "options.read": 1
      owner_id: 1
      
  }
  return if not room?

  if @userId?
    friends = Meteor.users.findOne({_id: @userId}, {fields: friends: 1}).friends
    friend_ids = (friend.user_id for friend in friends when friend.status is "accepted")
    friend_ids.push @userId
  else
    friend_ids = []

  return if (room.options.read is "user" and not (room.owner_id is @userId)) or (room.options.read is "friends" and not (room.owner_id in friend_ids)) or (room.options.read is "members" and not @userId)

  return Messages.find {
    room_id: room_id
    timestamp:
      $gt: (+new Date / 1000 | 0) - 60 * 60 * 12  # not older than 12 hours
  }, {
    sort:
      timestamp: -1
    limit: limit
  }

###
Meteor.publish "message_count", (room_id) ->
  uuid = Meteor.uuid()
  count = 0
  handle = Messages.find({
    room_id: room_id
    timestamp:
      $gt: (+new Date / 1000 | 0) - 60 * 60 * 12  # not older than 12 hours
  }).observe
    added: (doc, before_id) =>
      count++
      @set "message_count", uuid, count: count
      @flush()
    removed: (doc, at_index) =>
      count--
      @set "message_count", uuid, count: count

  @onStop =>
    handle.stop()
    @unset "message_count", uuid, ["count"]
    @flush()
###
          
###
Meteor.publish "current_programs", ->
  @old_ids = []
  @old_keys = []
  publish_current = () =>
    timestamp = +new Date / 1000 | 0
    current_programs = Programs.find
      start:
        $lte: timestamp
      stop:
        $gt: timestamp
    
    for _id in @old_ids
      @unset "curent_programs", _id, @old_keys
    @old_ids = []
    @old_keys = []
    @min_stop = null
    current_programs.forEach (program) =>
      @set "current_programs", program._id, program
      @old_ids.push program._id
      @old_keys = (key for key of program) if @old_keys.length == 0
      @min_stop = program.stop if not @min_stop? or program.stop < @min_stop
    timeout = @min_stop * 1000 - +new Date
    Meteor.setTimeout publish_current, timeout + 1000 # wait a second longer before re-querying program data
    @flush()
    
  publish_current()
  @onStop =>
    for _id in @old_ids
      @unset "current_programs", _id, @old_keys
      @flush()
###

Meteor.publish "programs", (channel_ids) ->
  timestamp = +new Date / 1000 | 0
  query =
    channel:
      $in: channel_ids
    start:
      $gte: timestamp - 60 * 60 * 6
    stop:
      $lt: timestamp + 60 * 60 * 12

  options =
    fields:
      title: 1
      subtitle: 1
      start: 1
      stop: 1
      "sub-title": 1
      channel: 1
  return Programs.find query, options

Accounts.onCreateUser (options, user) ->
  user.profile = if options.profile then options.profile else {}
  if not user.emails?
    throw new Meteor.Error 403, "no email"
  user.email_hash = CryptoJS.MD5(user.emails[0].address).toString()
  user.friends = []
  return user

Accounts.validateNewUser (user) ->
  if not user.username
    throw new Meteor.Error 403, "no username"
  re_email = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
  if not re_email.test(user.emails[0].address)
    throw new Meteor.Error 403, "email not valid"
  if Meteor.users.findOne(username: user.username)?
    throw new Meteor.Error 403, "username already in use"
  if Meteor.users.findOne(emails: $in: user.emails)?
    throw new Meteor.Error 403, "email already in use"
  return true

_cleanup = ->
  twelve_hours_ago = (+new Date / 1000 | 0) - 60 * 60 * 12  # older than 12 hours
  to_disable = []
  Rooms.find(name: $ne: "Öffentlich").forEach (room) ->
    query =
      room_id: room._id
      active: true

    options =
      sort:
        timestamp: -1
      limit: 1

    message = Messages.findOne query, options
    if message?
      if message.timestamp < twelve_hours_ago
        to_disable.push room._id
      else
        Rooms.update {_id: room._id,}, {$set: disable_next: false}
    else
      if room.disable_next
        to_disable.push room._id
      else
        Rooms.update {_id: room._id,}, {$set: disable_next: true}
      
  Rooms.update {
    _id:
      $in: to_delete
  }, {
    $set:
      active: false
  }
  
Meteor.setInterval _cleanup, 60 * 60 * 1000
