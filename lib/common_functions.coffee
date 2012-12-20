DEFAULT_AVATAR = "https://raw.github.com/Ed-von-Schleck/fernsehnauten-data/master/fernsehnauten_logo_draft_crop_square_001.png"

if Meteor.isClient
  _active_if = (varname, other) ->
    return " active " if Session.equals varname, other

  _set_on_click = (event) ->
    $element = $(event.currentTarget)
    Session.set $element.attr("data-varname"), $element.attr("data-value")

  _toggle_on_click = (event) ->
    $element = $(event.currentTarget)
    varname = $element.attr "data-varname"
    value = $element.attr "data-value"
    other = $element.attr "data-other"
    switch Session.get "varname"
      when value then Session.set varname, other
      when other then Session.set varname, value

  _ratings = (program, filter_by="_id") ->
    return if not program?
    if filter_by is "_id"
      likes = Ratings.find(program_id: program._id, like: true).count()
      dont_likes = Ratings.find(program_id: program._id, like: false).count()
    else if filter_by is "title"
      likes = Ratings.find(program_title: program.title[0][0], like: true).count()
      dont_likes = Ratings.find(program_title: program.title[0][0], like: false).count()

    ratings_count = likes + dont_likes
    return new Handlebars.SafeString Template.ratings ratings:
      likes: likes
      dont_likes: dont_likes
      likes_percent: (likes / ratings_count) * 100
      dont_likes_percent: (dont_likes / ratings_count) * 100
      count: ratings_count

  _friends_of_status = (status) ->
    return if not Meteor.user()
    #HACKY: This strange username bug ... revisit some time, see if it is still buggy
    friends = Friends.find(status: status).fetch()
    friend.name = friend.username for friend in friends
    return friends

  _userwidget = (username) ->
    return if not username
    gravatar_url_name = "#{username}_gravatar_url"
    profile_name = "#{username}_profile"
    friend = Friends.findOne(username: username)
    if Meteor.userId() and friend?
      is_friend = true
      friend_status = friend.status
      Session.set gravatar_url_name, "http://www.gravatar.com/avatar/#{friend.email_hash}?s=64&d=#{encodeURI DEFAULT_AVATAR}"
      Session.set profile_name, friend.profile
    else
      is_friend = false
      friend_status = null
      Meteor.call "get_user_info", username, (error, result) ->
        if not error?
          if not Session.keys[gravatar_url_name]?
            Session.set gravatar_url_name, "http://www.gravatar.com/avatar/#{result.email_hash}?s=64&d=#{encodeURI DEFAULT_AVATAR}"
          if not Session.keys[profile_name]?
            Session.set profile_name, result.profile
          _delete_info = ->
            delete Session.keys[gravatar_url_name]
            delete Session.keys[profile_name]
          Meteor.setTimeout _delete_info, 1000 * 60

    return new Handlebars.SafeString Template.userwidget
      name: username
      is_friend: is_friend
      friend_status: friend_status
      gravatar_session_var: gravatar_url_name
      profile_session_var: profile_name

  _editable = (target, on_enter) ->
    $target = $(target)
    inner_width = $target.innerWidth()
    text = $.trim $target.text()
    html = target.innerHTML
    $input = $("<input style=\"width: #{inner_width}px;\" type=\"text\" value=\"#{text}\">")
    $target.empty()
    $target.append $input
    $input.focus()
    $input.keydown (event) ->
      switch event.which
        when 27
          $(event.target).parent().html html
        when 13
          input_value = $.trim event.target.value
          return if not input_value
          $(event.target).parent().html html
          on_enter input_value
        else
          $span = $("<span style=\"visibility: hidden; position: absolute;\">#{event.target.value}W</span>")
          $(document.body).append $span
          width = $span.width()
          $span.remove()
          $(event.target).width width

    $input.blur (event) ->
      $(event.target).parent().html html

  _small_profile = (username, profile) ->
    return new Handlebars.SafeString Template.small_profile name: username, profile: profile

  _human_delta = (delta) ->
    if delta < 60
      return "gerade eben"
    if delta < 120
      return "vor einer Minute"
    if delta < 60 * 60
      return "vor #{delta / 60 | 0} Minuten"
    if delta < 60 * 120
      return "vor einer Stunde"
    if delta < 60 * 60 * 24
      return "vor #{delta / 3600 | 0} Stunden"
    if delta < 60 * 60 * 48
      return "gestern"
    if delta < 60 * 60 * 24 * 30
      return "vor #{delta / (3600 * 24) | 0} Tagen"
    return "vor #{delta / (3600 * 24 * 30) | 0} Monaten"
