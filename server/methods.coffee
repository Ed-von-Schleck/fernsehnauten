Meteor.methods
  search_user: (input) ->
    exclude_ids = (friend.user_id for friend in Meteor.user().friends when friend.status is "accepted")
    exclude_ids.push(@userId)
    result = Meteor.users.find({
      $and: [{
        $or: [{
          username:
            $regex: ".*#{input}.*"
            $options: "i"
          }, {
          emails:
            $regex: ".*#{input}.*"
            $options: "i"
          }, {
          "profile.realname":
            $regex: ".*#{input}.*"
            $options: "i"

          }]
        }, {
          _id:
            $nin: exclude_ids
        }]
      }, {
        fields:
          username: 1
          "profile.realname": 1
          email_hash: 1
      }, {
        limit: 10
      })
    # HACKY: This is a workaround for a strange bug that occured
    # whenever {{this.username}} was used in the template. So
    # we use {{this.name}} instead. Weird though.
    users = result.fetch()
    user.name = user.username for user in users
    return users

  request_friendship_name: (friend_username, msg="") ->
    #user = Meteor.users.findOne _id: @userId
    friend = Meteor.users.findOne username: friend_username
    Meteor.users.update {
      username: friend_username
    }, {
      $addToSet:
        friends:
          user_id: @userId
          status: "requested"
    }
    Meteor.users.update {
      _id: @userId
    }, {
      $addToSet:
        friends:
          user_id: friend._id
          status: "pending"
    }

  accept_friendship_name: (friend_username) ->
    #TODO: check if all things are really ok
    friend_id = Meteor.users.findOne(username: friend_username)._id
    Meteor.users.update {
      _id: @userId
      "friends.user_id": friend_id
    }, {
      $set:
        "friends.$.status": "accepted"
    }
    Meteor.users.update {
      _id: friend_id
      "friends.user_id": @userId
    }, {
      $set:
        "friends.$.status": "accepted"
    }

  check_user_exists: (username) ->
    return not Meteor.users.findOne(username: username)?

  get_user_info: (username) ->
    if not username?
      #TODO: shouldn't happen, but does ...
      return
    query =
      username: username
    options =
      fields:
        email_hash: 1
        profile: 1
    return Meteor.users.findOne(query, options)
