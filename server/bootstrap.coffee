Meteor.startup ->
  Channels.find().forEach (channel) ->
    if not Rooms.findOne(channel_id: channel._id, name: "Öffentlich")?
      Rooms.insert
        channel_id: channel._id
        name: "Öffentlich"
        owner_id: null
        owner_name: "allen"
        active: true
        options:
          visible: "public"
          read: "public"
          write: "members"
