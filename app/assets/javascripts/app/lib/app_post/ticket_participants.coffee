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

# Offers the ticket participants as a condition, e.g. for overviews.
do ->
  defaults = App.UiElement.ApplicationSelector.defaults

  App.UiElement.ApplicationSelector.defaults = (attribute = {}, params = {}) ->
    result = defaults.call(@, attribute, params)

    if result[2]['ticket.mention_user_ids']
      result[2]['ticket.participant_user_ids'] =
        name: 'participant_user_ids'
        display: __('Participants')
        tag: 'autocompletion_ajax'
        relation: 'User'
        null: false
        translate: true
        operator: [__('is'), __('is not')]

    result
