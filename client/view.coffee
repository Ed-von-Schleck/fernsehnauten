Template.program_info.program = ->
  Session.get "active_program"

Template.channel.messages = (current) ->
  program = Session.get "active_program"
  return if not program?
  if current is "true"
    query =
      program_id: program._id
  else
    query =
      program_id:
        $ne: program._id
  options =
    sort:
      timestamp: 1
  return Messages.find query, options

Template.channel.userwidget = _userwidget

Template.message.userwidget = _userwidget

Template.message.preserve
  "div.message": (node) ->
    return node.id

Template.message.events
  "mouseenter .message": (event, template) ->
    #timestamp = parseInt event.target.getAttribute "data-timestamp"
    timestamp = template.data.message.timestamp
    program = Session.get "active_program"
    return if timestamp < program.start
    #time_passed = parseInt event.target.getAttribute "data-time-passed"
    time_passed = template.data.message.time_passed
    length = program.stop - program.start
    percent = (time_passed / length) * 100
    $marker = $("#message_marker")
    $marker.css
      left: "#{percent}%"
      display: "block"

  "mouseleave .message": (event) ->
    $marker = $("#message_marker")
    $marker.css
      display: "none"

Template.message.created = ->
  timestamp = @data.message.timestamp
  @_update_human_delta = (message_delta_node) =>
    now = +new Date / 1000 | 0
    delta = now - timestamp
    message_delta_node.innerHTML = "(#{_human_delta(delta)})"
    return delta

Template.message.rendered = ->
  _update = =>
    delta = this._update_human_delta @find ".message_delta"
    if delta < 3600
      next_update = (60 - (delta % 60)) * 1000
    else
      next_update = (3600 - (delta % 3600)) * 1000
    @_timeout_id = window.setTimeout _update, next_update
  _update()

Template.message.destroyed = ->
  window.clearTimeout @_timeout_id
  

Template.channel.message = (message) ->
  return new Handlebars.SafeString Template.message message: message

Template.channel.are_there_current_messages = ->
  program = Session.get "active_program"
  return if not program?
  return Messages.findOne(program_id: program._id)?
###
Template.channel.messages_count = ->
  return MessageCount.findOne()?.count
###
###
Template.channel.allowed = (what) ->
  room = Session.get "active_room"
  return if not room?
  switch room.options[what]
    when "public"
      return true
    when "members"
      return Meteor.userId()
    when "friends"
      return if not Meteor.userLoaded()
      return (room.owner_id is Meteor.userId()) or (room.owner_id in (friend.user_id for friend in Meteor.user().friends when friend.status is "accepted"))
    when "user"
      return room.owner_id is Meteor.userId()
    else
      return false
###

Template.channel.room_option_owner = (option_varname, option_value)->
  return new Handlebars.SafeString Template.room_option_owner option_value: option_value, option_varname: option_varname

Template.channel.room_option_visitor = (option_varname, option_value)->
  return new Handlebars.SafeString Template.room_option_visitor option_value: option_value, option_varname: option_varname

Template.channel.message_count_status = ->
  count = Messages.find().count()
  chat_message_limit = Session.get "chat_message_limit"
  if count >= chat_message_limit
    return new Handlebars.SafeString "Zeige maximal #{chat_message_limit} Chatnachrichten. <a>Mehr zeigen … </a>"
  else
    switch count
      when 0
        return "Keine Chatnachricht in den letzten zwölf Stunden"
      when undefined
        return "Keine Chatnachricht in den letzten zwölf Stunden"
      when 1
        return "Zeige einzige Chatnachricht in den letzten zwölf Stunden."
      else
        return "Zeige alle #{count} Nachrichten der letzten zwölf Stunden."
      

Template.channel.rendered = ->
  active_room = Session.get "active_room"
  return if not active_room?
  $buttons = $(@findAll "#room_selector button")
  $buttons.removeClass "active editable"
  $active_button = $buttons.filter "[data-value=\"#{active_room._id}\"]"
  $active_button.addClass "active"
  if Meteor.userId() is active_room.owner_id
    $active_button.addClass "editable"

Template.room_option_owner.events
  "change select": (event) ->
    value = event.target.value
    varname =  event.target.getAttribute "data-varname"
    options = Session.get("active_room").options
    options[varname] = value
    Rooms.update {
      _id: Session.get "active_room_id"
    }, {
      $set:
        options: options
    }

Template.channel.rooms = ->
  return Rooms.find channel_id: Session.get "active_channel_id"

Template.channel.check_friends_allowed = ->
  return false if not Meteor.userId()
  active_room_id = Session.get "active_room_id"
  return if not active_room_id?
  room = Session.get "active_room"
  return if not room?
  return true if room.owner_id is Meteor.userId()
  friend = Friends.findOne(_id: room.owner_id, status: "accepted")
  return friend?

Template.channel_bar.channels = ->
  return Channels.find({}, {sort: position: 1})

Template.channel_bar.channel_count_square_percent = ->
  return 65 / Math.sqrt Channels.find().count()

Template.channel_bar.rendered = ->
  $channel_bar = $("#channel_bar")
  channel_bar_width = 256 #HACKY
  $channel_bar.width channel_bar_width + window.scrollbar_width
  window.position_element "#channel_bar"
  $channel_bar.scrollTop window.channel_bar_scroll_top + $("#fixed_header").outerHeight()

  $channel_bar_items = $(@findAll ".channel_bar_item")
  $channel_bar_items.removeClass "active"
  active_channel_id = Session.get "active_channel_id"
  $channel_bar_items.filter("[data-value=\"#{active_channel_id}\"]").addClass "active"

###
Template.channel_bar.currentProgramm = (channel_id) ->
  now = +new Date /1000 | 0
  return Programs.findOne
    channel: channel_id
    start:
      $lte: now
    stop:
      $gt: now
###

Template.channel.events
  "click .set_on_click": _set_on_click

  "keyup #chat_input": (event) ->
    return if event.which isnt 13
    if event.which is 27
      event.target.value = ""
      return
    return if event.target.value.length < 2
    message = $.trim event.target.value
    return if not message
    return if not Meteor.user()
    channel_id = Session.get "active_channel_id"
    return if not channel_id
    program = Session.get "active_program"
    return if not program?
    room_id = Session.get "active_room_id"
    Meteor.call "add_chat_message", channel_id, room_id, program._id, program.start, message, (error, _id) ->
      $(window).scrollTop $(document).height()# - $(window).height()
    event.target.value = ""

    ###
    timestamp = +new Date / 1000 | 0
    Messages.insert {
      user_id: Meteor.userId()
      user_username: Meteor.user().username
      timestamp: timestamp
      time_passed: timestamp - program.start
      channel_id: channel_id
      program_id: program._id
      room_id: room_id
      msg: message
    }, (error, _id) ->
    ###

  "click #add_room_button": (event) ->
    return if not Meteor.user()
    room_name = "Raum von #{Meteor.user().username}"
    _id = Rooms.insert
      channel_id: Session.get "active_channel_id"
      owner_id: Meteor.userId()
      owner_name: Meteor.user().username
      name: room_name
      active: true
      options:
        read: "friends"
        visible: "user"
        write: "friends"
    Session.set "active_room_id", _id
    return

  "click .editable": (event) ->
    return if not Meteor.user()
    _editable event.target, (new_room_name) ->
      Rooms.update {
        _id: Session.get "active_room_id"
      }, {
        $set:
          name: new_room_name
      }

  "click #close_room": (event) ->
    Rooms.update {
      _id: Session.get "active_room_id"
    }, {
      $set:
        active: false
    }
    active_channel_id = Session.get "active_channel_id"
    room = Rooms.findOne(channel_id: active_channel_id, name: "Öffentlich")
    Session.set "active_room_id", room?._id
    Session.set "active_room", room

  "click #older_messages a": (event) ->
    limit = Session.get "chat_message_limit"
    Session.set "chat_message_limit", limit + 10

Template.channel_bar.events
  "click .set_on_click": _set_on_click
  "scroll": (event) ->
    window.channel_bar_scroll_top = $(event.target).scrollTop()
  
Template.timeline.preserve ["#progress_box"]

Template.timeline.progress = ->
  program = Session.get "active_program"
  if program?
    length = program.stop - program.start
    progress =
      length: length
      human_length: "#{length / 3600 | 0}:#{pad length % 3600 / 60 | 0}"
      start: program.start
    return progress

Template.timeline.rendered = ->
  this.draw_progress_bar()

Template.timeline.created = ->
  window.timeline_update_next = 1000
  _draw_progress_bar = () ->
    progress_bar = document.getElementById "timeline_progress_bar"
    progress_box = document.getElementById "progress_box"
    if progress_bar? and progress_box?
      program = Session.get "active_program"
      if program?
        now = +new Date / 1000 | 0
        delta = now - program.start
        length = program.stop - program.start
        human_passed = "#{delta / 3600 | 0}:#{pad delta % 3600 / 60 | 0}"
        human_length = "#{length / 3600 | 0}:#{pad length % 3600 / 60 | 0}"
        percent = (delta / length) * 100
        progress_bar.style.width = "#{percent}%"
        progress_box.innerHTML = "#{human_passed}/#{human_length}"
        timeline_bar = document.getElementById "timeline_bar"
        if timeline_bar?
          width = timeline_bar.offsetWidth
          window.timeline_update_next = (length / width) * 1000
        else
          window.timeline_update_next = 1000

  _update_progress_bar = () ->
    _draw_progress_bar()
    _draw_next = () ->
      window.requestAnimationFrame _update_progress_bar
    @timeout_id = window.setTimeout _draw_next, window.timeline_update_next

  _update_progress_bar()
  @draw_progress_bar = _draw_progress_bar

Template.timeline.destroyed = ->
  window.clearTimeout this.timeout_id

Template.program_info.events
  "click button.rating": (event, template) ->
    program = Session.get "active_program"
    if not Meteor.userId()
      return #TODO: handle not logged in users
    existing_rating = Ratings.findOne
      user_id: Meteor.userId()
      program_id: program._id
    like = event.target.value == "like"
    if not existing_rating?
      Ratings.insert
        user_id: Meteor.userId()
        like: like
        program_id: program._id
        program_title: program.title[0][0]
    else
      Ratings.update {
        _id: existing_rating._id
      }, {
        $set:
          like: if existing_rating.like isnt like then like else null
      }
    $(event.target).addClass "active"

Template.program_info.ratings = ->
  _ratings Session.get "active_program"

Template.program_info.similar_ratings = ->
  _ratings Session.get("active_program"), filter_by="title"

Template.program_info.rendered = ->
  # We trust the program_info to be re-rendered every time the ratings change.
  # OK, so here is a really strange bug: @data points to the Window object,
  # not to the template data. WTF. 
  return if not Meteor.user()
  program = Session.get "active_program"
  return if not program?
  user_rating = Ratings.findOne user_id: Meteor.userId(), program_id: program._id
  return if not user_rating?
  like_button = $(@find "#like_button")
  dont_like_button = $(@find "#dont_like_button")
  switch user_rating.like
    when true
      like_button.addClass "active"
      dont_like_button.removeClass "active"
    when false
      dont_like_button.addClass "active"
      like_button.removeClass "active"
    else
      like_button.removeClass "active"
      dont_like_button.removeClass "active"
  return

Template.user_view.active_if = _active_if

Template.user_view.events
  "click button.set_on_click": _set_on_click

Template.user_profile.profile_image = ->
  return if not Meteor.user()
  #TODO: don't user Gravatar
  url = Gravatar.imageUrl Meteor.user().emails[0].address,
    size: 130
    default: encodeURI "https://raw.github.com/Ed-von-Schleck/fernsehnauten-data/master/fernsehnauten_logo_draft_crop_square_001.png"
  return url

Template.user_profile.profile_entry = (key, keyname, human_keyname, placeholder) ->
  return new Handlebars.SafeString Template.profile_entry
    key: key
    keyname: keyname
    human_keyname: human_keyname
    placeholder: placeholder

Template.user_profile.events
  "click .editable": (event) ->
    key = event.target.getAttribute "data-key"
    _editable event.target, (result) ->
      profile = Meteor.user().profile
      profile[key] = result
      Meteor.users.update {
        _id: Meteor.userId()
      }, {
        $set:
          profile: profile
      }

Template.user_search_results.suggestions = ->
  return []

Template.user_search_results.is_friend = (name) ->
  return Friends.findOne(username: name)?

Template.user_search_results.search_results = ->
  return Session.get "user_search_result"

Template.user_search_results.events
  "click .set_on_click": _set_on_click

Template.user_friends.active_if = _active_if

Template.user_friends.events
  "focus #search_users_input, keyup #search_users_input": (event) ->
    return if not Meteor.user()
    input = event.target.value
    if not input or input.length == 0
      Session.set "user_search_result", null
    else
      Meteor.call "search_user", input, (error, result) ->
        if error
          console.log "error:", error
          return
        Session.set "user_search_result", result
    Session.set "user_search_input_value", input

  "click .set_on_click": _set_on_click

  "click .request_friendship_name": (event) ->
    Meteor.call "request_friendship_name", event.target.value

Template.friend_requests.requests = ->
  return _friends_of_status "requested"

Template.friend_requests.events
  "click .accept_friendship_name": (event) ->
    Meteor.call "accept_friendship_name", event.target.value

Template.all_friends.friends = ->
  return _friends_of_status "accepted"
  
Template.all_friends.small_profile = (username, profile) ->
  _small_profile username, profile

Template.pending_requests.small_profile = (username, profile) ->
  _small_profile username, profile

Template.friend_requests.small_profile = (username, profile) ->
  _small_profile username, profile

Template.pending_requests.requests = ->
  return _friends_of_status "pending"

Template.bug_user_to_log_in.events
  "click .set_on_click": _set_on_click

Template.userwidget.small_profile_from_session = (username, profile) ->
  _small_profile username, Session.get profile

Template.userwidget.events
  "mouseenter .userwidget": (event) ->
    $target = $(event.target)
    offset = $target.offset()
    left = offset.left + $target.outerWidth()
    $target.children(".userwidget_popup").offset
      left: left
      top: offset.top

  "click .accept_friendship_name": (event) ->
    Meteor.call "accept_friendship_name", event.target.value

  "click .request_friendship_name": (event) ->
    Meteor.call "request_friendship_name", event.target.value

###
Template.ratings.rendered = ->
  positive_ratings = @find ".positive_ratings"
  negative_ratings = @find ".negative_ratings"
  positive_ratings.style.width = "#{@data.ratings.likes_percent}%"
  negative_ratings.style.width = "#{@data.ratings.dont_likes_percent}%"
###
