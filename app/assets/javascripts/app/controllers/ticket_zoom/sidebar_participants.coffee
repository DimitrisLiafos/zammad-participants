class SidebarParticipants extends App.Controller
  sidebarItem: =>
    return if !@ticket.participants_enabled

    @item = {
      name:            'participants'
      badgeIcon:       'team'
      sidebarHead:     __('Participants')
      sidebarCallback: @showParticipants
      sidebarActions:  []
    }

    # The server decides in the end; this only hides the action from those who can never use it.
    if @ticket.currentView() is 'agent' && @ticket.editable()
      @item.sidebarActions.push(
        title:    __('Add participant')
        name:     'participant-add'
        callback: @addParticipant
      )

    @item

  showParticipants: (el) =>
    @elSidebar = el
    @fetch()

  reload: =>
    return if !@elSidebar

    @fetch()

  url: =>
    "#{@apiPath}/tickets/#{@ticket.id}/participants"

  fetch: =>
    @ajax(
      id:      "ticket-participants-#{@ticket.id}"
      type:    'GET'
      url:     @url()
      success: (data) => @renderList(data)
      error:   (xhr, status) =>
        return if status is 'abort'

        @elSidebar.html(App.i18n.translateInline('Loading failed.'))
    )

  renderList: (data) =>
    list = $(App.view('ticket_zoom/sidebar_participants')(
      participants:  data.participants
      currentUserId: App.User.current()?.id
    ))

    list.on('click', '.js-remove', (e) =>
      e.preventDefault()
      @removeParticipant($(e.currentTarget).data('id'), $(e.currentTarget).data('self'))
    )

    @elSidebar.html(list)

  addParticipant: =>
    new ParticipantAdd(
      container: @elSidebar.closest('.content')
      url:       @url()
      callback:  @fetch
    )

  removeParticipant: (id, self) =>
    message = if self
      __('Do you want to leave this ticket? You will no longer receive its updates and lose your access to it.')
    else
      __('Do you want to remove this participant? They will lose their access to the ticket.')

    new App.ControllerConfirm(
      message:     message
      buttonClass: 'btn--danger'
      container:   @elSidebar.closest('.content')
      callback:    =>
        @ajax(
          id:      "ticket-participants-remove-#{id}"
          type:    'DELETE'
          url:     "#{@url()}/#{id}"
          success: =>
            # Having left, the ticket is gone for this user.
            return @navigate('#') if self

            @fetch()
          error: (xhr) => @notifyError(xhr)
        )
    )

  notifyError: (xhr) ->
    App.Event.trigger('notify', {
      type:    'error'
      msg:     xhr.responseJSON?.error_human || xhr.responseJSON?.error || __('The request could not be processed.')
      timeout: 6000
    })

class ParticipantAdd extends App.ControllerModal
  buttonClose:  true
  buttonCancel: true
  buttonSubmit: __('Add')
  head:         __('Add participant')

  content: ->
    @controller = new App.ControllerForm(
      model:
        configure_attributes: [
          { name: 'user_id', display: __('Customer'), tag: 'user_autocompletion', null: false, placeholder: __('Enter Person or Organization/Company'), minLengt: 2, disableCreateObject: true },
        ]
      autofocus: true
    )
    @controller.form

  onSubmit: (e) =>
    params = @formParam(e.target)
    return if !params.user_id

    @formDisable(e)
    @ajax(
      id:          'ticket-participants-add'
      type:        'POST'
      url:         @url
      data:        JSON.stringify(user_id: params.user_id)
      processData: true
      success:     =>
        @close()
        @callback()
      error: (xhr) =>
        @formEnable(e)
        @showAlert(xhr.responseJSON?.error_human || xhr.responseJSON?.error || __('The request could not be processed.'))
    )

App.Config.set('350-Participants', SidebarParticipants, 'TicketZoomSidebar')
