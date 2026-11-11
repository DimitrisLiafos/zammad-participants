# Offers the ticket participants as a recipient of email notifications in triggers and schedulers.
do ->
  recipientVariables = App.UiElement.ApplicationAction.recpientVariables

  App.UiElement.ApplicationAction.recpientVariables = ->
    variables = recipientVariables.call(@)
    variables['ticket_participants'] = __('Participants')
    variables

# Participants may edit (reply to) a ticket like its customer.
do ->
  editableByCustomer = App.Ticket::editableByCustomer

  App.Ticket::editableByCustomer = (user) ->
    return true if editableByCustomer.call(@, user)
    return false if @currentView() != 'customer'

    _.contains(@participant_user_ids, user.id)
