Template.overview.events
  "click .set_on_click": _set_on_click
  
Template.overview.channels = ->
  return Channels.find()

Template.overview.programs_by_channel = (channel_id) ->
  now = +new Date / 1000 | 0
  an_hour_ago = now - 3600
  programs = Programs.find(channel: channel_id).fetch()
  for program in programs
    program.display_width = (program.stop - program.start) / 10
    program.display_position = (program.start - now) / 10
  return programs

