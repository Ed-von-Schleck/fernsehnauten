Meteor.startup ->  
  Messages.allow
    insert: (user_id, doc) ->
      return false if not user_id?
      return false if user_id isnt doc.user_id
      room = Rooms.findOne {
        _id: doc.room_id
      }, {
        fields:
          owner_id: 1
          "options.write": 1
      }
      return if not room?
      switch room.options.write
        when "members"
          return user_id?
        when "user"
          return room.owner_id is user_id
        when "friends"
          friends = Meteor.users.findOne({_id: user_id}, {fields: friends: 1}).friends
          friend_ids = (friend.user_id for friend in friends when friend.status is "accepted")
          friend_ids.push user_id
          return room.owner_id in friend_ids
        else
          return false

  Meteor.users.allow
    fetch: ["username", "_id"]

  Ratings.allow
    insert: (user_id, doc) ->
      return user_id && doc.user_id == user_id

    update: (user_id, docs) ->
      return _.all docs, (doc) ->
        return doc.user_id == user_id

    remove: (user_id, docs) ->
      return _.all docs, (doc) ->
        return doc.user_id == user_id

  Rooms.allow
    insert: (user_id, doc) ->
      return user_id && doc.owner_id == user_id

    update: (user_id, docs) ->
      return user_id and _.all docs, (doc) ->
        return (doc.owner_id == user_id)

    remove: (user_id, docs) ->
      return false

