
@R = {}

{ div, span, a, p, ol, ul, li, strong, em, img,
  form, label, input, textarea, button,
  h1, h2, h3, h4, h5, h6 } = React.DOM

R.component = (name, data) ->
  data.displayName = "R.#{name}"
  cl = React.createClass(data)
  R[name] = React.createFactory(cl)
  R[name]._class = cl

R.component "UploadList", {
  render: ->
    console.log @state.uploads
    uploads = @render_uploads()
    div className: "upload_list", uploads...

  render_uploads: ->
    for upload in @state.uploads
      R.Upload upload: upload

}

R.component "Upload", {
  render: ->
    console.log @state

    div className: "upload_row", @state.upload.filename
}

class Upload
  upload_template: S.lazy_template @, "file_upload"
  constructor: (@data, @manager) ->
    @el = $ @upload_template @data
    @el.data "upload", @
    @el.data "upload_id", @data.id

    @progress_bar = @el.find ".upload_progress"
    @progress_bar_inner = @progress_bar.find ".upload_progress_inner"

  upload_params: => @_upload_params ||= {}

  set_upload_params: (obj) =>
    return unless obj
    params = @upload_params()

    for k,v of obj
      params[k] = v

    params

  set_save_url: (@save_url) =>

  start_upload: (action) ->
    throw "missing file" unless @data.file

    @el.addClass "uploading"

    form_data = new FormData()
    for key, val of @upload_params()
      form_data.append key, val

    form_data.append "file", @data.file

    xhr = new XMLHttpRequest
    xhr.upload.addEventListener "progress", (e) =>
      if e.lengthComputable
        @progress? e.loaded, e.total

    xhr.upload.addEventListener "error", (e) =>
      S.event "upload", "xhr error", @kind

    xhr.upload.addEventListener "abort", (e) =>
      S.event "upload", "xhr abort", @kind

    xhr.addEventListener "load", (e) =>
      @el.removeClass "uploading"

      if xhr.status != 200 && xhr.status != 204
        return @set_error "server failed to accept upload"

      try
        res = $.parseJSON(xhr.responseText)
        if res.errors
          return @set_error "#{res.errors.join ", "}"

      if @save_url
        $.post @save_url, S.with_csrf(), (res) =>
          if res.errors
            return @set_error "#{res.errors.join ", "}"

          @save_upload res
      else
        @save_upload res

    xhr.open "POST", action
    xhr.send form_data

  progress: (loaded, total) =>
    p = loaded/total * 100
    @progress_bar_inner.css "width", "#{p}%"

  save_upload: (res) =>
    @el.addClass("has_success")
      .trigger "s:upload_complete", [@]

  set_error: (msg) =>
    @el.addClass("has_error").find(".upload_error").text msg

class UploaderManager
  constructor: (@button_el, @view, @opts) ->
    input = null
    @upload_list = @view.el.find ".file_upload_list"

    @button_el.on "click", (e) =>
      e.preventDefault()

      input.remove() if input
      input = $("<input type='file' multiple />").hide().insertAfter(@button_el)
      if accept = @button_el.data "accept"
        input.attr "accept", accept

      max_size = @button_el.data "max_size"
      input.on "change", =>
        for file in input[0].files
          if max_size? and file.size > max_size
            alert "#{file.name} is greater than max size of #{_.str.formatBytes max_size}"
            continue

          @prepare_and_start_upload file

      input.insertAfter @button_el
      input.click()

  prepare_and_start_upload: (file, callback) ->
    prepare_url = @button_el.data "url"
    data = S.with_csrf {
      "upload[filename]": file.name
      "upload[size]": file.size
    }

    $.post prepare_url, data, (res) =>
      if res.errors
        return alert res.errors.join ", "

      upload = new Upload {
        filename: file.name
        size: file.size
        type: file.type
        file: file
        id: res.id
        position: @next_upload_position()
      }


      upload.set_upload_params res.post_params
      upload.set_save_url res.save_url


      @upload_list.append upload.el
      upload.start_upload res.url
      callback? upload, file

  next_upload_position: ->
    @upload_list.find(".file_upload").length

  add_existing: (upload) ->
    upload = new Upload upload
    @upload_list.append upload.el

  reset_upload_positions: =>
    for input, i in @upload_list.find(".position_input")
      $(input).val i

class S.EditSubmission
  constructor: (el, @opts) ->
    @el = $ el
    form = @el.find("form")
    form.remote_submit (res) =>
      if res.errors
        form.set_form_errors res.errors
        return

      if res.url
        window.location = res.url

    @setup_uploads()
    @setup_upload2()

    @setup_tags()
    S.redactor @el.find "textarea"

    @el.dispatch "click", {
      move_down_btn: (btn) =>
        upload = btn.closest ".file_upload"
        upload.swap_with upload.next ".file_upload"
        @upload_manager.reset_upload_positions()

      move_up_btn: (btn) =>
        upload = btn.closest ".file_upload"
        upload.swap_with upload.prev ".file_upload"
        @upload_manager.reset_upload_positions()

      delete_btn: (btn) =>
        if confirm "Are you sure you want to remove this file?"
          btn.closest(".file_upload").remove()
          @upload_manager.reset_upload_positions()
    }

  setup_upload2: =>
    container = @el.find ".uploader2"
    console.log "rendering uploader2", @opts.uploads
    React.render (R.UploadList { uploads: @opts.uploads || [] }), container[0]

  setup_uploads: =>
    @upload_manager = new UploaderManager @el.find(".new_upload_btn"), @
    if @opts.uploads
      for upload in @opts.uploads
        @upload_manager.add_existing upload

  setup_tags: ->
    slug_input = @el.find ".tags_input"

    slug_input.tagit {
      availableTags: @opts.suggested_tags
      autocomplete: { delay: 0, minLength: 2 }
      allowSpaces: true
    }


