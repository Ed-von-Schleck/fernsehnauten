Template.fixed_login_button.events
  "click .set_on_click": _set_on_click
###
Template.absolute_login_button.events
  "click .set_on_click": _set_on_click
###
Template.fixed_user_status_button.events
  "click .set_on_click": _set_on_click
  "click .toggle_on_click": _toggle_on_click
###
Template.absolute_user_status_button.events
  "click .set_on_click": _set_on_click
  "click .toggle_on_click": _toggle_on_click
###
Template.login_form.events
  "click .set_on_click": _set_on_click

  "click #login_button": (event) ->
    username_or_email = $("#username_or_email_input").val()
    password = $("#password_input").val()
    Meteor.loginWithPassword username_or_email, password, (error) ->
      if error?
        switch error.reason
          when "Must pass username, email, or id in request.user" then Session.set "login_error", "Geben Sie Ihren Benutzernamen oder Emailadresse ein"
          when "User not found" then Session.set "login_error", "Benutzer wurde nicht gefunden. Bitte überprüfen Sie Ihre Eingabe."
          when "Incorrect password" then Session.set "login_error", "Das Passwort ist nicht korrekt. Bitte überprüfen Sie Ihre Eingabe."
          else Session.set "login_error", error.reason
      else
        Session.set "log_in_status", "logged_in"
      
  "click #create_user_button": (event) ->
    username = $("#username_input").val()
    email = $("#email_input").val()
    password = $("#password_input").val()
    try
      Accounts.createUser {username: username, email: email, password: password}, (error) ->
        if error?
          switch error.reason
            when "no email" then Session.set "login_error", "Bitte geben Sie Ihre Emailadresse ein."
            when "Need to set a username or email" then Session.set "login_error", "Bitte geben Sie einen Benutzernamen und Ihre Emailadresse ein."
            when "no username" then Session.set "login_error", "Bitte geben Sie einen Benutzernamen ein."
            when "email not valid" then Session.set "login_error", "Ihre Emailadresse ist nicht korrekt. Bitte überprüfen Sie Ihre Eingabe."
            when "username already in use" then Session.set "login_error", "Der Benutzername ist schon vergeben. Bitte wählen Sie einen anderen Benutzeernamen"
            when "email already in use" then Session.set "login_error", "Die Emailadresse ist schon in Benutzung. Bitte überprüfen Sie Ihre Eingabe."
            else Session.set "login_error", error.reason
        else
          Session.set "log_in_status", "logged_in"
    catch error
      switch error.message
        when "Must set options.password" then Session.set "login_error", "Bitte geben Sie ein Passwort ein"
        else error.message

  "keyup input": (event) ->
    return if not Session.equals "login_form_state", "create_user"
    switch event.target.id
      when "username_input"
        username = event.target.value
        Meteor.call "check_user_exists", username, (error, ok) ->
          console.log error, ok
          #console.log username, ok
          if username is event.target.value # check that is didn't change
            if not ok
              Session.set "username_feedback", "Benutzername schon vergeben"
              Session.set "username_ok", false
              Session.set "can_create_user", Session.get("username_ok") and Session.get("email_ok") and Session.get("password_ok")
        if username.length < 5
          Session.set "username_ok", false
          Session.set "username_feedback", "Benutzername zu kurz"
        else
          Session.set "username_feedback", ""
          Session.set "username_ok", true

      when "email_input"
        re_email = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
        email = event.target.value
        if not re_email.test(email)
          Session.set "email_feedback", "Emailadresse ist nicht korrekt"
          Session.set "email_ok", false
        else
          Session.set "email_feedback", ""
          Session.set "email_ok", true

      when "password_input"
        password = event.target.value
        if password.length < 6
          Session.set "password_feedback", "Password zu kurz (mindestens 6 Zeichen)"
          Session.set "password_ok", false
        else
          Session.set "password_feedback", ""
          Session.set "password_ok", true

Meteor.autorun ->
  Session.set "can_create_user", Session.get("username_ok") and Session.get("email_ok") and Session.get("password_ok")

Template.preserve = ["#email_input"]

Template.user_menu.events
  "click #logout_button": (event) ->
    Meteor.logout()
    Session.set "log_in_status", "not_logged_in"
    Session.set "login_form_state", "log_in"
    Session.set "can_create_user", false
    Session.set "username_ok", false
    Session.set "email_ok", false
    Session.set "password_ok", false
    Session.set "username_feedback", ""
    Session.set "email_feedback", ""
    Session.set "password_feedback", ""
    Session.set "main_view_state", "main"

  "click #show_user_friends": (event) ->
    Session.set "main_view_state", "user"
    Session.set "user_view_state", "friends"

  "click #show_user_profile": (event) ->
    Session.set "main_view_state", "user"
    Session.set "user_view_state", "profile"

  "click #show_user_settings": (event) ->
    Session.set "main_view_state", "user"
    Session.set "user_view_state", "settings"
