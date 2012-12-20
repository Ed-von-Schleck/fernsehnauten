Handlebars.registerHelper "formatDate", (timestamp) ->
  date = new Date(timestamp * 1000)
  return date.toLocaleString()

Handlebars.registerHelper "formatTime", (timestamp) ->
  date = new Date(timestamp * 1000)
  return "#{date.getHours()}:#{pad date.getMinutes()}"

Handlebars.registerHelper "session_get", (varname) ->
  return Session.get varname

Handlebars.registerHelper "session_equals", (varname, other) ->
  return Session.equals varname, other

Handlebars.registerHelper "session_gt", (varname, other) ->
  return Session.get(varname) > other

Handlebars.registerHelper "session_lt", (varname, other) ->
  return Session.get(varname) < other

Handlebars.registerHelper "session_inc", (varname, value) ->
  old_value = Session.get varname
  Session.set varname old_value + parseInt value

Handlebars.registerHelper "is_true", (value) ->
  return value is true

Handlebars.registerHelper "is_false", (value) ->
  return value is false

Handlebars.registerHelper "is_undefined", (value) ->
  return value is undefined

Handlebars.registerHelper "is_null", (value) ->
  return value is null

Handlebars.registerHelper "all", (args..., fn) ->
  for arg in args
    if not arg
      return false
  return true
Handlebars.registerHelper "username", (_id) ->
  Meteor.users.findOne(_id: _id)?.username

Handlebars.registerHelper "channel_display_name", (channel_id) ->
  Channels.findOne(_id: channel_id)?["display-name"][0][0]

Handlebars.registerHelper "log", (args...) ->
  console.log args

Handlebars.registerHelper "stringify", (obj) ->
  return JSON.stringify obj

Handlebars.registerHelper "gravatar", (hash, size=80) ->
  return "http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=#{encodeURI DEFAULT_AVATAR}"

Handlebars.registerHelper "in_session_get", (thing, varname) ->
  return thing in Session.get varname

Handlebars.registerHelper "is_friend_status", (friend_id, status) ->
  return if not Meteor.user()
  return if not Meteor.userLoaded()
  for friend in Meteor.user().friends
    if friend.user_id is friend_id and friend.status is status
      return true
  return false

Handlebars.registerHelper "bug_user_to_log_in", (message) ->
  return new Handlebars.SafeString Template.bug_user_to_log_in message: message

Handlebars.registerHelper "eq", (value, other) ->
  return value == other

Handlebars.registerHelper "is_one", (value) ->
  return value is 1

Handlebars.registerHelper "is_zero", (value) ->
  return value is 0
