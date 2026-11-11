# Offers the ticket participants as a recipient of email notifications in triggers and schedulers.
do ->
  recipientVariables = App.UiElement.ApplicationAction.recpientVariables

  App.UiElement.ApplicationAction.recpientVariables = ->
    variables = recipientVariables.call(@)
    variables['ticket_participants'] = __('Participants')
    variables
