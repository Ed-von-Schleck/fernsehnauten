Template.channels.helpers
  data: ->
    return Channels.find({}, {sort: {position: 1}, reactive: false})

  currentProgramm: (channel_id) ->
    CurrentPrograms.findOne channel: channel_id

  ratings: (channel_id) ->
    program = CurrentPrograms.findOne channel: channel_id
    return _ratings program

  similar_ratings: (channel_id) ->
    program = CurrentPrograms.findOne channel: channel_id
    return _ratings program, filter_by="title"

Template.channels.destroyed = ->
  window.channel_bar_scroll_top = $(window).scrollTop()

Template.channels.events
  "click .set_on_click": _set_on_click

