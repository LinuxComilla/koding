kd                  = require 'kd'
$                   = require 'jquery'
KDModalView         = kd.ModalView
KDTabView           = kd.TabView
IDETabHandleView    = require './idetabhandleview'
ApplicationTabView  = require 'app/commonviews/applicationview/applicationtabview'


module.exports = class IDEApplicationTabView extends ApplicationTabView

  constructor: (options = {}, data) ->

    options.sortable        ?= no
    options.droppable       ?= yes
    options.tabHandleClass   = IDETabHandleView

    super options, data


  handleClicked: (event, handle) ->

    {pane} = handle.getOptions()

    if $(event.target).hasClass 'close-tab'
      @emit 'PaneRemovedByUserAction', pane

    super event, handle


  removePane_: KDTabView::removePane

  removePane: (pane, shouldDetach, quiet = no) ->

    return  unless pane

    {aceView} = pane.getOptions()

    if quiet or not aceView or not aceView.ace.isContentChanged()
      return @removePane_ pane, shouldDetach

    @askForSave pane, aceView


  askForSave: (pane, aceView) ->

    { ace } = aceView
    file    = ace.getData()

    content = "Your changes will be lost if you don't save them. "

    { frontApp } = kd.singletons.appManager

    if frontApp.hasSession()
      participants = frontApp.getWatchingMeParticipantsList()

      if participants.length

        more = ""
        if participants.length > 3
          more = " and <strong>#{participants.length - 3}</strong> others"

        content += """
          Also #{(participants.slice(0,3).map (p) -> '<strong>@'+p+'</strong>').join(', ')}
          #{more} may have some changes here.
        """

    modal = new KDModalView
      width         : 620
      cssClass      : "modal-with-text"
      title         : "Do you want to save your changes?"
      content       : "<p>#{content}</p>"
      overlay       : yes
      buttons       :
        "SaveClose" :
          cssClass  : "solid green medium"
          title     : "Save and Close"
          callback  : =>
            if file.path.indexOf("localfile:") is 0
              file.once "fs.saveAs.finished", => @removePane_ pane
              @willClose = yes
              ace.requestSaveAs()
              modal.destroy()
            else
              ace.requestSave()
              file.once "fs.save.finished", => @removePane_ pane
              modal.destroy()
        "DontSave"  :
          cssClass  : "solid red medium"
          title     : "Don't Save"
          callback  : =>
            @closePaneAndModal pane, modal
        "Cancel"    :
          cssClass  : "solid light-gray medium"
          title     : "Cancel"
          callback  : =>
            modal.destroy()

  closePaneAndModal: (pane, modal) ->
    @removePane_ pane
    modal.destroy()
