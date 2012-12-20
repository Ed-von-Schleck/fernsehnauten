Meteor.methods
  add_chat_message: (channel_id, room_id, program_id, program_start, message) ->
    # Can't just be inserted on the client b/c the timestamp could be wrong.
    timestamp = +new Date / 1000 | 0
    return if not @userId
    return Messages.insert
      user_id: @userId
      user_username: Meteor.users.findOne(_id: @userId).username
      timestamp: timestamp
      time_passed: timestamp - program_start
      channel_id: channel_id
      program_id: program_id
      room_id: room_id
      msg: message
