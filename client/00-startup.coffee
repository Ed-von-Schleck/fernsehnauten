#ActiveChannel = new Meteor.Collection "active_channel"
Friends = new Meteor.Collection "friends"
#MessageCount = new Meteor.Collection "message_count"
#CurrentPrograms = new Meteor.Collection "current_programs"

Meteor.subscribe "channels"
Meteor.subscribe "current_programs"
Meteor.subscribe "ratings"
Meteor.subscribe "userData"


Meteor.autosubscribe ->
  Meteor.subscribe "message_count", Session.get "active_room_id"

Session.set "dirty_friends_number", 0

Meteor.subscribe "public_rooms"

Meteor.subscribe "member_rooms"
Meteor.subscribe "user_rooms"
Meteor.autosubscribe ->
  Meteor.subscribe "friend_rooms", Session.get "dirty_friends_number"
###
Meteor.autosubscribe ->
  active_channel_id = Session.get "active_channel_id"
  Meteor.subscribe "rooms", Session.get "dirty_friends_number"
###
###
Meteor.autosubscribe ->
  active_channel_id = Session.get "active_channel_id"
  if active_channel_id
    Meteor.subscribe "active_channel", active_channel_id
  #else
  #  Meteor.subscribe "messages", "main"
###
Meteor.autosubscribe ->
  active_room_id = Session.get "active_room_id"
  if active_room_id
    limit = Session.get "chat_message_limit"
    Meteor.subscribe "messages", active_room_id, limit, Session.get "dirty_friends_number"

Meteor.autosubscribe ->
  return if not Meteor.user()
  dirty_friends_number = Session.keys.dirty_friends_number
  dirty_friends_number++
  Session.set "dirty_friends_number", dirty_friends_number
  Meteor.subscribe "friends", Meteor.user().friends

#Session.set "active_channel_id", null
if not Session.get "main_view_state"  # "main", "user"
  Session.set "main_view_state", "main"
if not Session.get "user_view_state"  # "profile", "friends", "settings"
  Session.set "user_view_state", "profile"
Session.set "user_search_input_value", null
Session.set "user_search_result", null
if not Session.get "user_friends_view_state"
  Session.set "user_friends_view_state", "all_friends"
if not Session.get "log_in_status"
  Session.set "log_in_status", "not_logged_in"
if not Session.get "login_form_state"
  Session.set "login_form_state", "log_in"
Session.set "login_error", null
###
if not Session.get "user_menu_status"
  Session.set "user_menu_status", "hide"
###
Session.set "can_create_user", false
Session.set "username_ok", false
Session.set "email_ok", false
Session.set "password_ok", false
Session.set "username_feedback", ""
Session.set "email_feedback", ""
Session.set "password_feedback", ""

getScrollBarWidth = () ->
  div = $('<div style="width:50px;height:50px;overflow:hidden;position:absolute;top:-200px;left:-200px;"><div style="height:100px;"></div></div>')
  $('body').append(div)
  w1 = $('div', div).innerWidth()
  div.css('overflow-y', 'auto')
  w2 = $('div', div).innerWidth()
  $(div).remove()
  return (w1 - w2)

###
_set_now = ->
  Session.set "now", +new Date / 1000 | 0
_set_now()

Meteor.setInterval _set_now, 2000
###

pad = (n) ->
  if n < 10 then "0#{n}" else n.toString()

Meteor.startup ->
  window.scrollbar_width = getScrollBarWidth()
  header_height = $("#header").outerHeight()
  fixed_header_height = $("#fixed_header").outerHeight()
  $body = $("body")
  $window = $(window)

  position_element = (element_str) ->
    $element = $(element_str)
    if $element.length is 0
      return
    scroll_top = $window.scrollTop()
    top = Math.max header_height - scroll_top , fixed_header_height
    if header_height - scroll_top  > fixed_header_height
      if $element.css("position") isnt "absolute"
        $element.css
          position: "absolute"
          top: 0
          height: $window.height() - top
      else
        $element.css
          height: $window.height() - top
    else
      if $element.css("position") isnt "fixed"
        $element.css
          position: "fixed"
          top: fixed_header_height
          height: $window.height() - top

  window.position_element = position_element
  
  $window.scroll ->
    position_element "#channel_bar"

  $window.resize ->
    position_element "#channel_bar"
  
  position_element "channel_bar"

  Meteor.autorun ->
    #return if not Programs?
    #return if not Rooms?
    active_channel_id = Session.get "active_channel_id"
    if active_channel_id?
      now = +new Date / 1000 | 0
      Session.set "active_program", Programs.findOne
        channel: active_channel_id
        start:
          $lte: now
        stop:
          $gt: now
      room = Rooms.findOne(channel_id: active_channel_id, name: "Öffentlich")
      Session.set "active_room", room
      Session.set "active_room_id", room?._id
    else
      Session.set "active_program", null

  Meteor.autorun ->
    now = +new Date /1000 | 0
    active_channel_id = Session.get "active_channel_id"
    return if not active_channel_id?
    refresh_active_program = ->
      return if not Programs?
      now = +new Date /1000 | 0
      new_active_program = Programs.findOne
        channel: active_channel_id
        start:
          $lte: now
        stop:
          $gt: now
      return if not new_active_program?
      Session.set "active_program", new_active_program
      console.log "refreshing active program to", new_active_program
    current_active_program = Session.get "active_program"
    if current_active_program?
      refresh_timeout = (current_active_program.stop - now) * 1000
    else
      refresh_timeout = 1000
    if window.refresh_active_program_timeout_id?
      window.clearTimeout window.refresh_active_program_timeout_id
    window.refresh_active_program_timeout_id = window.setTimeout refresh_active_program, refresh_timeout
    console.log "Will refresh active program in", refresh_timeout, "ms"
      
  Meteor.autorun ->
    # Change "active_room" Session variable whenever "active_room_id" var changes
    active_room_id = Session.get "active_room_id"
    active_room = Session.keys.active_room
    return if active_room?._id is active_room_id
    Session.set "active_room", Rooms.findOne(_id: active_room_id)

  Meteor.autorun ->
    # Reset chat message limit on room change.
    if Session.get "active_room_id"
      Session.set "chat_message_limit", 20

  Meteor.autorun ->
    # Reset friend search results (TODO: find better way)
    return if not Session.equals "main_view_state", "user"
    return if not Session.equals "user_view_state", "friends"
    return if Session.equals "user_friends_view_state", "search_friends"
    Session.set "user_search_input_value", null
    Session.set "user_search_result", null

   
  window._program_subscription_interval_id = null
  Meteor.autorun ->
    if Channels?
      _subscribe_programs = ->
        Meteor.subscribe "programs", Channels.find({}, {fields: _id: 1}).map (channel) -> channel._id
      _subscribe_programs()
    if window._program_subscription_interval_id?
      window.clearInterval window._program_subscription_interval_id
    window._program_subscription_interval_id = window.setInterval _subscribe_programs, 1000 * 60 * 60
