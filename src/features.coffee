Header =
  init: ->
    headerEl = $.el 'div',
      id: 'header'
      innerHTML: """
        <div id=header-bar class=dialog>
          <span class='menu-button brackets-wrap'><a href=javascript:;><i></i></a></span>
          <span id=shortcuts class=brackets-wrap></span>
          <span id=board-list>
            <span id=custom-board-list></span>
            <span id=full-board-list hidden></span>
          </span>
          <div id=toggle-header-bar title="Toggle the header auto-hiding."></div>
        </div>
        <div id=notifications></div>
      """.replace />\s+</g, '><' # get rid of spaces between elements

    @bar    = $ '#header-bar', headerEl
    @toggle = $ '#toggle-header-bar', @bar

    @menu = new UI.Menu 'header'
    $.on $('.menu-button', @bar), 'click', @menuToggle
    $.on @toggle, 'mousedown', @toggleBarVisibility
    $.on window, 'load hashchange', Header.hashScroll
    $.on d, 'CreateNotification', @createNotification

    headerToggler = $.el 'label',
      innerHTML: '<input type=checkbox name="Header auto-hide"> Auto-hide header'
    barPositionToggler = $.el 'label',
      innerHTML: '<input type=checkbox name="Bottom header"> Bottom header'
    catalogToggler = $.el 'label',
      innerHTML: '<input type=checkbox name="Header catalog links"> Use catalog board links'
    topBoardToggler = $.el 'label',
      innerHTML: '<input type=checkbox name="Top Board List"> Top original board list'
    botBoardToggler = $.el 'label',
      innerHTML: '<input type=checkbox name="Bottom Board List"> Bottom original board list'
    customNavToggler = $.el 'label',
      innerHTML: '<input type=checkbox name="Custom Board Navigation"> Custom board navigation'
    editCustomNav = $.el 'a',
      textContent: 'Edit custom board navigation'
      href: 'javascript:;'

    @headerToggler      = headerToggler.firstElementChild
    @barPositionToggler = barPositionToggler.firstElementChild
    @catalogToggler     = catalogToggler.firstElementChild
    @topBoardToggler    = topBoardToggler.firstElementChild
    @botBoardToggler    = botBoardToggler.firstElementChild
    @customNavToggler   = customNavToggler.firstElementChild

    $.on @headerToggler,      'change', @toggleBarVisibility
    $.on @barPositionToggler, 'change', @toggleBarPosition
    $.on @catalogToggler,     'change', @toggleCatalogLinks
    $.on @topBoardToggler,    'change', @toggleOriginalBoardList
    $.on @botBoardToggler,    'change', @toggleOriginalBoardList
    $.on @customNavToggler,   'change', @toggleCustomNav
    $.on editCustomNav,       'click',  @editCustomNav

    @setBarVisibility Conf['Header auto-hide']
    @setBarPosition   Conf['Bottom header']
    @setTopBoardList  Conf['Top Board List']
    @setBotBoardList  Conf['Bottom Board List']

    $.sync 'Header auto-hide',  @setBarVisibility
    $.sync 'Bottom header',     @setBarPosition
    $.sync 'Top Board List',    @setTopBoardList
    $.sync 'Bottom Board List', @setBotBoardList

    $.event 'AddMenuEntry',
      type: 'header'
      el: $.el 'span', textContent: 'Header'
      order: 105
      subEntries: [
        {el: headerToggler}
        {el: barPositionToggler}
        {el: catalogToggler}
        {el: topBoardToggler}
        {el: botBoardToggler}
        {el: customNavToggler}
        {el: editCustomNav}
      ]

    $.asap (-> d.body), ->
      return unless Main.isThisPageLegit()
      # Wait for #boardNavMobile instead of #boardNavDesktop,
      # it might be incomplete otherwise.
      $.asap (-> $.id('boardNavMobile') or d.readyState is 'complete'), Header.setBoardList
      $.prepend d.body, headerEl

    $.ready ->
      if a = $ "a[href*='/#{g.BOARD}/']", $.id 'boardNavDesktopFoot'
        a.className = 'current'

      Header.setCatalogLinks Conf['Header catalog links']
      $.sync 'Header catalog links', Header.setCatalogLinks

  setBoardList: ->
    nav = $.id 'boardNavDesktop'
    if a = $ "a[href*='/#{g.BOARD}/']", nav
      a.className = 'current'
    fullBoardList = $ '#full-board-list', Header.bar
    fullBoardList.innerHTML = nav.innerHTML
    $.rm $ '#navtopright', fullBoardList
    btn = $.el 'span',
      className: 'hide-board-list-button brackets-wrap'
      innerHTML: '<a href=javascript:;> - </a>'
    $.on btn, 'click', Header.toggleBoardList
    $.add fullBoardList, btn

    Header.setCustomNav      Conf['Custom Board Navigation']
    Header.generateBoardList Conf['boardnav']

    $.sync 'Custom Board Navigation', Header.setCustomNav
    $.sync 'boardnav',                Header.generateBoardList

  generateBoardList: (text) ->
    list = $ '#custom-board-list', Header.bar
    $.rmAll list
    return unless text
    as = $$('#full-board-list a', Header.bar)[0...-2] # ignore the Settings and Home links
    nodes = text.match(/[\w@]+(-(all|title|replace|full|index|catalog|text:"[^"]+"))*|[^\w@]+/g).map (t) ->
      if /^[^\w@]/.test t
        return $.tn t
      if /^toggle-all/.test t
        a = $.el 'a',
          className: 'show-board-list-button'
          textContent: (t.match(/-text:"(.+)"/) || [null, '+'])[1]
          href: 'javascript:;'
        $.on a, 'click', Header.toggleBoardList
        return a
      board = if /^current/.test t
        g.BOARD.ID
      else
        t.match(/^[^-]+/)[0]
      for a in as
        if a.textContent is board
          a = a.cloneNode true
          if /-title/.test t
            a.textContent = a.title
          else if /-replace/.test t
            if $.hasClass a, 'current'
              a.textContent = a.title
          else if /-full/.test t
            a.textContent = "/#{board}/ - #{a.title}"
          else if /-(index|catalog|text)/.test t
            if m = t.match /-(index|catalog)/
              a.setAttribute 'data-only', m[1]
              a.href = "//boards.4chan.org/#{board}/"
              a.href += 'catalog' if m[1] is 'catalog'
            if m = t.match /-text:"(.+)"/
              a.textContent = m[1]
          else if board is '@'
            $.addClass a, 'navSmall'
          return a
      $.tn t
    $.add list, nodes

  toggleBoardList: ->
    {bar}  = Header
    custom = $ '#custom-board-list', bar
    full   = $ '#full-board-list',   bar
    showBoardList = !full.hidden
    custom.hidden = !showBoardList
    full.hidden   =  showBoardList

  setBarVisibility: (hide) ->
    Header.headerToggler.checked = hide
    $.event 'CloseMenu'
    (if hide then $.addClass else $.rmClass) Header.bar, 'autohide'
  toggleBarVisibility: (e) ->
    return if e.type is 'mousedown' and e.button isnt 0 # not LMB
    hide = if @nodeName is 'INPUT'
      @checked
    else
      !$.hasClass Header.bar, 'autohide'
    Conf['Header auto-hide'] = hide
    $.set 'Header auto-hide', hide
    Header.setBarVisibility hide
    message = if hide
      'The header bar will automatically hide itself.'
    else
      'The header bar will remain visible.'
    new Notification 'info', message, 2

  setBarPosition: (bottom) ->
    Header.barPositionToggler.checked = bottom
    $.event 'CloseMenu'
    if bottom
      $.addClass doc, 'bottom-header'
      $.rmClass  doc, 'top-header'
      Header.bar.parentNode.className = 'bottom'
    else
      $.addClass doc, 'top-header'
      $.rmClass  doc, 'bottom-header'
      Header.bar.parentNode.className = 'top'
  toggleBarPosition: ->
    $.cb.checked.call @
    Header.setBarPosition @checked

  setCatalogLinks: (useCatalog) ->
    Header.catalogToggler.checked = useCatalog
    as = $$ [
      '#board-list a[href*="boards.4chan.org"]'
      '#boardNavDesktop a[href*="boards.4chan.org"]'
      '#boardNavDesktopFoot a[href*="boards.4chan.org"]'
    ].join ', '
    path = if useCatalog then 'catalog' else ''
    for a in as
      continue if a.dataset.only
      a.pathname = "/#{a.pathname.split('/')[1]}/#{path}"
    return
  toggleCatalogLinks: ->
    $.cb.checked.call @
    Header.setCatalogLinks @checked

  setTopBoardList: (show) ->
    Header.topBoardToggler.checked = show
    if show
      $.addClass doc, 'show-original-top-board-list'
    else
      $.rmClass  doc, 'show-original-top-board-list'
  setBotBoardList: (show) ->
    Header.botBoardToggler.checked = show
    if show
      $.addClass doc, 'show-original-bot-board-list'
    else
      $.rmClass  doc, 'show-original-bot-board-list'
  toggleOriginalBoardList: ->
    $.cb.checked.call @
    (if @name is 'Top Board List' then Header.setTopBoardList else Header.setBotBoardList) @checked

  setCustomNav: (show) ->
    Header.customNavToggler.checked = show
    cust = $ '#custom-board-list', Header.bar
    full = $ '#full-board-list',   Header.bar
    btn  = $ '.hide-board-list-button', full
    [cust.hidden, full.hidden, btn.hidden] = if show
      [false, true, false]
    else
      [true, false, true]
  toggleCustomNav: ->
    $.cb.checked.call @
    Header.setCustomNav @checked

  editCustomNav: ->
    Settings.open 'Rice'
    settings = $.id 'fourchanx-settings'
    $('input[name=boardnav]', settings).focus()

  hashScroll: ->
    return unless post = $.id @location.hash[1..]
    return if (Get.postFromRoot post).isHidden
    Header.scrollToPost post
  scrollToPost: (post) ->
    {top} = post.getBoundingClientRect()
    unless Conf['Bottom header']
      headRect = Header.toggle.getBoundingClientRect()
      top += - headRect.top - headRect.height
    <% if (type === 'crx') { %>d.body<% } else { %>doc<% } %>.scrollTop += top

  addShortcut: (el) ->
    shortcut = $.el 'span',
      className: 'shortcut'
    $.add shortcut, el
    $.prepend $('#shortcuts', Header.bar), shortcut

  menuToggle: (e) ->
    Header.menu.toggle e, @, g

  createNotification: (e) ->
    {type, content, lifetime, cb} = e.detail
    notif = new Notification type, content, lifetime
    cb notif if cb

class Notification
  constructor: (type, content, @timeout) ->
    @add   = add.bind @
    @close = close.bind @

    @el = $.el 'div',
      innerHTML: '<a href=javascript:; class=close title=Close>×</a><div class=message></div>'
    @el.style.opacity = 0
    @setType type
    $.on @el.firstElementChild, 'click', @close
    if typeof content is 'string'
      content = $.tn content
    $.add @el.lastElementChild, content

    $.ready @add

  setType: (type) ->
    @el.className = "notification #{type}"

  add = ->
    if d.hidden
      $.on d, 'visibilitychange', @add
      return
    $.off d, 'visibilitychange', @add
    $.add $.id('notifications'), @el
    @el.clientHeight # force reflow
    @el.style.opacity = 1
    setTimeout @close, @timeout * $.SECOND if @timeout

  close = ->
    $.rm @el

Settings =
  init: ->
    # 4chan X settings link
    link = $.el 'a',
      className:   'settings-link'
      textContent: '<%= meta.name %> Settings'
      href:        'javascript:;'
    $.on link, 'click', Settings.open
    $.event 'AddMenuEntry',
      type: 'header'
      el: link
      order: 111

    # 4chan settings link
    link = $.el 'a',
      className:   'fourchan-settings-link'
      textContent: '4chan Settings'
      href:        'javascript:;'
    $.on link, 'click', -> $.id('settingsWindowLink').click()
    $.event 'AddMenuEntry',
      type: 'header'
      el: link
      order: 110
      open: -> Conf['Enable 4chan\'s Extension']

    $.get 'previousversion', null, (item) ->
      if previous = item['previousversion']
        return if previous is g.VERSION
        <% if (type === 'crx') { %>
        # XXX tmp conversion: move some settings from sync to local
        Settings['3.2.1-update'] previous
        <% } %>
        changelog = '<%= meta.repo %>blob/<%= meta.mainBranch %>/CHANGELOG.md'
        el = $.el 'span',
          innerHTML: "<%= meta.name %> has been updated to <a href='#{changelog}' target=_blank>version #{g.VERSION}</a>."
        new Notification 'info', el, 30
      else
        $.on d, '4chanXInitFinished', Settings.open
      $.set
        lastupdate: Date.now()
        previousversion: g.VERSION

    Settings.addSection 'Main',     Settings.main
    Settings.addSection 'Filter',   Settings.filter
    Settings.addSection 'Sauce',    Settings.sauce
    Settings.addSection 'Rice',     Settings.rice
    Settings.addSection 'Keybinds', Settings.keybinds
    $.on d, 'AddSettingsSection',   Settings.addSection
    $.on d, 'OpenSettings',         (e) -> Settings.open e.detail

    return if Conf['Enable 4chan\'s Extension']
    settings = JSON.parse(localStorage.getItem '4chan-settings') or {}
    return if settings.disableAll
    settings.disableAll = true
    localStorage.setItem '4chan-settings', JSON.stringify settings

  open: (openSection) ->
    $.off d, '4chanXInitFinished', Settings.open
    return if Settings.dialog
    $.event 'CloseMenu'

    html = """
      <div id=fourchanx-settings class=dialog>
        <nav>
          <div class=sections-list></div>
          <div class=credits>
            <a href='<%= meta.page %>' target=_blank><%= meta.name %></a> |
            <a href='<%= meta.repo %>blob/<%= meta.mainBranch %>/CHANGELOG.md' target=_blank>#{g.VERSION}</a> |
            <a href='<%= meta.repo %>blob/<%= meta.mainBranch %>/CONTRIBUTING.md#reporting-bugs-and-suggestions' target=_blank>Issues</a> |
            <a href=javascript:; class=close title=Close>×</a>
          </div>
        </nav>
        <hr>
        <div class=section-container><section></section></div>
      </div>
    """

    Settings.dialog = overlay = $.el 'div',
      id: 'overlay'
      innerHTML: html

    links = []
    for section in Settings.sections
      link = $.el 'a',
        className: "tab-#{section.hyphenatedTitle}"
        textContent: section.title
        href: 'javascript:;'
      $.on link, 'click', Settings.openSection.bind section
      links.push link, $.tn ' | '
      sectionToOpen = link if section.title is openSection
    links.pop()
    $.add $('.sections-list', overlay), links
    (if sectionToOpen then sectionToOpen else links[0]).click()

    $.on $('.close', overlay), 'click', Settings.close
    $.on overlay,              'click', Settings.close
    $.on overlay.firstElementChild, 'click', (e) -> e.stopPropagation()

    d.body.style.width = "#{d.body.clientWidth}px"
    $.addClass d.body, 'unscroll'
    $.add d.body, overlay
  close: ->
    return unless Settings.dialog
    d.body.style.removeProperty 'width'
    $.rmClass d.body, 'unscroll'
    $.rm Settings.dialog
    delete Settings.dialog

  sections: []
  addSection: (title, open) ->
    if typeof title isnt 'string'
      {title, open} = title.detail
    hyphenatedTitle = title.toLowerCase().replace /\s+/g, '-'
    Settings.sections.push {title, hyphenatedTitle, open}
  openSection: ->
    if selected = $ '.tab-selected', Settings.dialog
      $.rmClass selected, 'tab-selected'
    $.addClass $(".tab-#{@hyphenatedTitle}", Settings.dialog), 'tab-selected'
    section = $ 'section', Settings.dialog
    $.rmAll section
    section.className = "section-#{@hyphenatedTitle}"
    @open section, g
    section.scrollTop = 0

  main: (section) ->
    section.innerHTML = """
      <div class=imp-exp>
        <button class=export>Export Settings</button>
        <button class=import>Import Settings</button>
        <input type=file style='visibility:hidden'>
      </div>
      <p class=imp-exp-result></p>
    """
    $.on $('.export', section), 'click',  Settings.export
    $.on $('.import', section), 'click',  Settings.import
    $.on $('input',   section), 'change', Settings.onImport

    items  = {}
    inputs = {}
    for key, obj of Config.main
      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"
      for key, arr of obj
        description = arr[1]
        div = $.el 'div',
          innerHTML: "<label><input type=checkbox name=\"#{key}\">#{key}</label><span class=description>: #{description}</span>"
        input = $ 'input', div
        $.on input, 'change', $.cb.checked
        items[key]  = Conf[key]
        inputs[key] = input
        $.add fs, div
      $.add section, fs

    $.get items, (items) ->
      for key, val of items
        inputs[key].checked = val
      return

    div = $.el 'div',
      innerHTML: "<button></button><span class=description>: Clear manually-hidden threads and posts on all boards. Refresh the page to apply."
    button = $ 'button', div
    hiddenNum = 0
    $.get 'hiddenThreads', boards: {}, (item) ->
      for ID, board of item.hiddenThreads.boards
        for ID, thread of board
          hiddenNum++
      button.textContent = "Hidden: #{hiddenNum}"
    $.get 'hiddenPosts', boards: {}, (item) ->
      for ID, board of item.hiddenPosts.boards
        for ID, thread of board
          for ID, post of thread
            hiddenNum++
      button.textContent = "Hidden: #{hiddenNum}"
    $.on button, 'click', ->
      @textContent = 'Hidden: 0'
      $.get 'hiddenThreads', boards: {}, (item) ->
        for boardID of item.hiddenThreads.boards
          localStorage.removeItem "4chan-hide-t-#{boardID}"
        $.delete ['hiddenThreads', 'hiddenPosts']
    $.after $('input[name="Stubs"]', section).parentNode.parentNode, div
  export: (now, data) ->
    unless typeof now is 'number'
      now  = Date.now()
      data =
        version: g.VERSION
        date: now
      Conf['WatchedThreads'] = {}
      for db in DataBoards
        Conf[db] = boards: {}
      # Make sure to export the most recent data.
      $.get Conf, (Conf) ->
        data.Conf = Conf
        Settings.export now, data
      return
    a = $.el 'a',
      className: 'warning'
      textContent: 'Save me!'
      download: "<%= meta.name %> v#{g.VERSION}-#{now}.json"
      href: "data:application/json;base64,#{btoa unescape encodeURIComponent JSON.stringify data, null, 2}"
      target: '_blank'
    <% if (type === 'userscript') { %>
    # XXX Firefox won't let us download automatically.
    p = $ '.imp-exp-result', Settings.dialog
    $.rmAll p
    $.add p, a
    <% } else { %>
    a.click()
    <% } %>
  import: ->
    @nextElementSibling.click()
  onImport: ->
    return unless file = @files[0]
    output = @parentNode.nextElementSibling
    unless confirm 'Your current settings will be entirely overwritten, are you sure?'
      output.textContent = 'Import aborted.'
      return
    reader = new FileReader()
    reader.onload = (e) ->
      try
        data = JSON.parse e.target.result
        Settings.loadSettings data
        if confirm 'Import successful. Refresh now?'
          window.location.reload()
      catch err
        output.textContent = 'Import failed due to an error.'
        c.error err.stack
    reader.readAsText file
  loadSettings: (data) ->
    version = data.version.split '.'
    if version[0] is '2'
      data = Settings.convertSettings data,
        # General confs
        'Disable 4chan\'s extension': ''
        'Catalog Links': ''
        'Reply Navigation': ''
        'Show Stubs': 'Stubs'
        'Image Auto-Gif': 'Auto-GIF'
        'Expand From Current': ''
        'Unread Favicon': 'Unread Tab Icon'
        'Post in Title': 'Thread Excerpt'
        'Auto Hide QR': ''
        'Open Reply in New Tab': ''
        'Remember QR size': ''
        'Quote Inline': 'Quote Inlining'
        'Quote Preview': 'Quote Previewing'
        'Indicate OP quote': 'Mark OP Quotes'
        'Indicate Cross-thread Quotes': 'Mark Cross-thread Quotes'
        # filter
        'uniqueid': 'uniqueID'
        'mod': 'capcode'
        'country': 'flag'
        'md5': 'MD5'
        # keybinds
        'openEmptyQR': 'Open empty QR'
        'openQR': 'Open QR'
        'openOptions': 'Open settings'
        'close': 'Close'
        'spoiler': 'Spoiler tags'
        'code': 'Code tags'
        'submit': 'Submit QR'
        'watch': 'Watch'
        'update': 'Update'
        'unreadCountTo0': ''
        'expandAllImages': 'Expand images'
        'expandImage': 'Expand image'
        'zero': 'Front page'
        'nextPage': 'Next page'
        'previousPage': 'Previous page'
        'nextThread': 'Next thread'
        'previousThread': 'Previous thread'
        'expandThread': 'Expand thread'
        'openThreadTab': 'Open thread'
        'openThread': 'Open thread tab'
        'nextReply': 'Next reply'
        'previousReply': 'Previous reply'
        'hide': 'Hide'
        # updater
        'Scrolling': 'Auto Scroll'
        'Verbose': ''
      data.Conf.sauces = data.Conf.sauces.replace /\$\d/g, (c) ->
        switch c
          when '$1'
            '%TURL'
          when '$2'
            '%URL'
          when '$3'
            '%MD5'
          when '$4'
            '%board'
          else
            c
      for key, val of Config.hotkeys
        continue unless key of data.Conf
        data.Conf[key] = data.Conf[key].replace(/ctrl|alt|meta/g, (s) -> "#{s[0].toUpperCase()}#{s[1..]}").replace /(^|.+\+)[A-Z]$/g, (s) ->
          "Shift+#{s[0...-1]}#{s[-1..].toLowerCase()}"
      data.Conf.WatchedThreads = data.WatchedThreads
    $.set data.Conf
  convertSettings: (data, map) ->
    for prevKey, newKey of map
      data.Conf[newKey] = data.Conf[prevKey] if newKey
      delete data.Conf[prevKey]
    data
  <% if (type === 'crx') { %>
  '3.2.1-update': (previous) ->
    return unless /^3\.[10]\.|^3\.2\.0$/.test previous
    items = {}
    for key in $.localKeys
      items[key] = null
    chrome.storage.sync.get items, (items) ->
      chrome.storage.sync.remove $.localKeys
      for key, val of items
        delete items[key] if val is null
      chrome.storage.local.set items
  <% } %>

  filter: (section) ->
    section.innerHTML = """
      <select name=filter>
        <option value=guide>Guide</option>
        <option value=name>Name</option>
        <option value=uniqueID>Unique ID</option>
        <option value=tripcode>Tripcode</option>
        <option value=capcode>Capcode</option>
        <option value=email>E-mail</option>
        <option value=subject>Subject</option>
        <option value=comment>Comment</option>
        <option value=flag>Flag</option>
        <option value=filename>Filename</option>
        <option value=dimensions>Image dimensions</option>
        <option value=filesize>Filesize</option>
        <option value=MD5>Image MD5</option>
      </select>
      <div></div>
    """
    select = $ 'select', section
    $.on select, 'change', Settings.selectFilter
    Settings.selectFilter.call select
  selectFilter: ->
    div = @nextElementSibling
    if (name = @value) isnt 'guide'
      $.rmAll div
      ta = $.el 'textarea',
        name: name
        className: 'field'
        spellcheck: false
      $.get name, Conf[name], (item) ->
        ta.value = item[name]
      $.on ta, 'change', $.cb.value
      $.add div, ta
      return
    div.innerHTML = """
      <div class=warning #{if Conf['Filter'] then 'hidden' else ''}><code>Filter</code> is disabled.</div>
      <p>
        Use <a href=https://developer.mozilla.org/en/JavaScript/Guide/Regular_Expressions>regular expressions</a>, one per line.<br>
        Lines starting with a <code>#</code> will be ignored.<br>
        For example, <code>/weeaboo/i</code> will filter posts containing the string `<code>weeaboo</code>`, case-insensitive.<br>
        MD5 filtering uses exact string matching, not regular expressions.
      </p>
      <ul>You can use these settings with each regular expression, separate them with semicolons:
        <li>
          Per boards, separate them with commas. It is global if not specified.<br>
          For example: <code>boards:a,jp;</code>.
        </li>
        <li>
          Filter OPs only along with their threads (`only`), replies only (`no`), or both (`yes`, this is default).<br>
          For example: <code>op:only;</code>, <code>op:no;</code> or <code>op:yes;</code>.
        </li>
        <li>
          Overrule the `Show Stubs` setting if specified: create a stub (`yes`) or not (`no`).<br>
          For example: <code>stub:yes;</code> or <code>stub:no;</code>.
        </li>
        <li>
          Highlight instead of hiding. You can specify a class name to use with a userstyle.<br>
          For example: <code>highlight;</code> or <code>highlight:wallpaper;</code>.
        </li>
        <li>
          Highlighted OPs will have their threads put on top of board pages by default.<br>
          For example: <code>top:yes;</code> or <code>top:no;</code>.
        </li>
      </ul>
    """

  sauce: (section) ->
    section.innerHTML = """
      <div class=warning #{if Conf['Sauce'] then 'hidden' else ''}><code>Sauce</code> is disabled.</div>
      <div>Lines starting with a <code>#</code> will be ignored.</div>
      <div>You can specify a display text by appending <code>;text:[text]</code> to the URL.</div>
      <ul>These parameters will be replaced by their corresponding values:
        <li><code>%TURL</code>: Thumbnail URL.</li>
        <li><code>%URL</code>: Full image URL.</li>
        <li><code>%MD5</code>: MD5 hash.</li>
        <li><code>%board</code>: Current board.</li>
      </ul>
      <textarea name=sauces class=field spellcheck=false></textarea>
    """
    sauce = $ 'textarea', section
    $.get 'sauces', Conf['sauces'], (item) ->
      sauce.value = item['sauces']
    $.on sauce, 'change', $.cb.value

  rice: (section) ->
    section.innerHTML = """
      <fieldset>
        <legend>Custom Board Navigation <span class=warning #{if Conf['Custom Board Navigation'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=boardnav class=field spellcheck=false></div>
        <div>In the following, <code>board</code> can translate to a board ID (<code>a</code>, <code>b</code>, etc...), the current board (<code>current</code>), or the Status/Twitter link (<code>status</code>, <code>@</code>).</div>
        <div>Board link: <code>board</code></div>
        <div>Title link: <code>board-title</code></div>
        <div>Board link (Replace with title when on that board): <code>board-replace</code></div>
        <div>Full text link: <code>board-full</code></div>
        <div>Custom text link: <code>board-text:"VIP Board"</code></div>
        <div>Index-only link: <code>board-index</code></div>
        <div>Catalog-only link: <code>board-catalog</code></div>
        <div>Combinations are possible: <code>board-index-text:"VIP Index"</code></div>
        <div>Full board list toggle: <code>toggle-all</code></div>
      </fieldset>

      <fieldset>
        <legend>Time Formatting <span class=warning #{if Conf['Time Formatting'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=time class=field spellcheck=false>: <span class=time-preview></span></div>
        <div>Supported <a href=//en.wikipedia.org/wiki/Date_%28Unix%29#Formatting>format specifiers</a>:</div>
        <div>Day: <code>%a</code>, <code>%A</code>, <code>%d</code>, <code>%e</code></div>
        <div>Month: <code>%m</code>, <code>%b</code>, <code>%B</code></div>
        <div>Year: <code>%y</code></div>
        <div>Hour: <code>%k</code>, <code>%H</code>, <code>%l</code>, <code>%I</code>, <code>%p</code>, <code>%P</code></div>
        <div>Minute: <code>%M</code></div>
        <div>Second: <code>%S</code></div>
      </fieldset>

      <fieldset>
        <legend>Quote Backlinks formatting <span class=warning #{if Conf['Quote Backlinks'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=backlink class=field spellcheck=false>: <span class=backlink-preview></span></div>
      </fieldset>

      <fieldset>
        <legend>File Info Formatting <span class=warning #{if Conf['File Info Formatting'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=fileInfo class=field spellcheck=false>: <span class='fileText file-info-preview'></span></div>
        <div>Link: <code>%l</code> (truncated), <code>%L</code> (untruncated), <code>%T</code> (Unix timestamp)</div>
        <div>Original file name: <code>%n</code> (truncated), <code>%N</code> (untruncated), <code>%t</code> (Unix timestamp)</div>
        <div>Spoiler indicator: <code>%p</code></div>
        <div>Size: <code>%B</code> (Bytes), <code>%K</code> (KB), <code>%M</code> (MB), <code>%s</code> (4chan default)</div>
        <div>Resolution: <code>%r</code> (Displays 'PDF' for PDF files)</div>
      </fieldset>

      <fieldset>
        <legend>Unread Tab Icon <span class=warning #{if Conf['Unread Tab Icon'] then 'hidden' else ''}>is disabled.</span></legend>
        <select name=favicon>
          <option value=ferongr>ferongr</option>
          <option value=xat->xat-</option>
          <option value=Mayhem>Mayhem</option>
          <option value=Original>Original</option>
        </select>
        <span class=favicon-preview></span>
      </fieldset>

      <fieldset>
        <legend>
          <label><input type=checkbox name='Custom CSS' #{if Conf['Custom CSS'] then 'checked' else ''}> Custom CSS</label>
        </legend>
        <button id=apply-css>Apply CSS</button>
        <textarea name=usercss class=field spellcheck=false #{if Conf['Custom CSS'] then '' else 'disabled'}></textarea>
      </fieldset>
    """
    items = {}
    inputs = {}
    for name in ['boardnav', 'time', 'backlink', 'fileInfo', 'favicon', 'usercss']
      input = $ "[name=#{name}]", section
      items[name]  = Conf[name]
      inputs[name] = input
      event = if name in ['favicon', 'usercss']
        'change'
      else
        'input'
      $.on input, event, $.cb.value
    $.get items, (items) ->
      for key, val of items
        input = inputs[key]
        input.value = val
        unless key in ['usercss']
          $.on input, event, Settings[key]
          Settings[key].call input
      return
    $.on $('input[name="Custom CSS"]', section), 'change', Settings.togglecss
    $.on $.id('apply-css'), 'click', Settings.usercss
  boardnav: ->
    Header.generateBoardList @value
  time: ->
    funk = Time.createFunc @value
    @nextElementSibling.textContent = funk Time, new Date()
  backlink: ->
    @nextElementSibling.textContent = Conf['backlink'].replace /%id/, '123456789'
  fileInfo: ->
    data =
      isReply: true
      file:
        URL: '//images.4chan.org/g/src/1334437723720.jpg'
        name: 'd9bb2efc98dd0df141a94399ff5880b7.jpg'
        size: '276 KB'
        sizeInBytes: 276 * 1024
        dimensions: '1280x720'
        isImage: true
        isSpoiler: true
    funk = FileInfo.createFunc @value
    @nextElementSibling.innerHTML = funk FileInfo, data
  favicon: ->
    Favicon.switch()
    Unread.update() if g.VIEW is 'thread' and Conf['Unread Tab Icon']
    @nextElementSibling.innerHTML = """
      <img src=#{Favicon.default}>
      <img src=#{Favicon.unreadSFW}>
      <img src=#{Favicon.unreadNSFW}>
      <img src=#{Favicon.unreadDead}>
      """
  togglecss: ->
    if $('textarea[name=usercss]', $.x 'ancestor::fieldset[1]', @).disabled = !@checked
      CustomCSS.rmStyle()
    else
      CustomCSS.addStyle()
    $.cb.checked.call @
  usercss: ->
    CustomCSS.update()

  keybinds: (section) ->
    section.innerHTML = """
      <div class=warning #{if Conf['Keybinds'] then 'hidden' else ''}><code>Keybinds</code> are disabled.</div>
      <div>Allowed keys: <kbd>a-z</kbd>, <kbd>0-9</kbd>, <kbd>Ctrl</kbd>, <kbd>Shift</kbd>, <kbd>Alt</kbd>, <kbd>Meta</kbd>, <kbd>Enter</kbd>, <kbd>Esc</kbd>, <kbd>Up</kbd>, <kbd>Down</kbd>, <kbd>Right</kbd>, <kbd>Left</kbd>.</div>
      <div>Press <kbd>Backspace</kbd> to disable a keybind.</div>
      <table><tbody>
        <tr><th>Actions</th><th>Keybinds</th></tr>
      </tbody></table>
    """
    tbody  = $ 'tbody', section
    items  = {}
    inputs = {}
    for key, arr of Config.hotkeys
      tr = $.el 'tr',
        innerHTML: "<td>#{arr[1]}</td><td><input class=field></td>"
      input = $ 'input', tr
      input.name = key
      input.spellcheck = false
      items[key]  = Conf[key]
      inputs[key] = input
      $.on input, 'keydown', Settings.keybind
      $.add tbody, tr
    $.get items, (items) ->
      for key, val of items
        inputs[key].value = val
      return
  keybind: (e) ->
    return if e.keyCode is 9 # tab
    e.preventDefault()
    e.stopPropagation()
    return unless (key = Keybinds.keyCode e)?
    @value = key
    $.cb.value.call @

PSAHiding =
  init: ->
    return if !Conf['Announcement Hiding']

    $.addClass doc, 'hide-announcement'

    entry =
      type: 'header'
      el: $.el 'a',
        textContent: 'Show announcement'
        className: 'show-announcement'
        href: 'javascript:;'
      order: 50
      open: ->
        if $.id('globalMessage')?.hidden
          return true
        false
    $.event 'AddMenuEntry', entry

    $.on entry.el, 'click', PSAHiding.toggle
    $.on d, '4chanXInitFinished', @setup
  setup: ->
    $.off d, '4chanXInitFinished', PSAHiding.setup

    unless psa = $.id 'globalMessage'
      $.rmClass doc, 'hide-announcement'
      return

    PSAHiding.btn = btn = $.el 'a',
      innerHTML: '<span>[&nbsp;-&nbsp;]</span>'
      title: 'Hide announcement.'
      className: 'hide-announcement'
      href: 'javascript:;'
    $.on btn, 'click', PSAHiding.toggle

    $.get 'hiddenPSAs', [], (item) ->
      PSAHiding.sync item['hiddenPSAs']
      $.before psa, btn
      $.rmClass doc, 'hide-announcement'

    $.sync 'hiddenPSAs', PSAHiding.sync
  toggle: (e) ->
    hide = $.hasClass @, 'hide-announcement'
    text = PSAHiding.trim $.id 'globalMessage'
    $.get 'hiddenPSAs', [], ({hiddenPSAs}) ->
      if hide
        hiddenPSAs.push text
        hiddenPSAs = hiddenPSAs[-5..]
      else
        $.event 'CloseMenu'
        i = hiddenPSAs.indexOf text
        hiddenPSAs.splice i, 1
      PSAHiding.sync hiddenPSAs
      $.set 'hiddenPSAs', hiddenPSAs
  sync: (hiddenPSAs) ->
    psa = $.id 'globalMessage'
    psa.hidden = PSAHiding.btn.hidden = if PSAHiding.trim(psa) in hiddenPSAs
      true
    else
      false
    if hr = $.x 'following-sibling::hr', psa
      hr.hidden = psa.hidden
  trim: (psa) ->
    psa.textContent.replace(/\W+/g, '').toLowerCase()

Fourchan =
  init: ->
    return if g.VIEW is 'catalog'

    board = g.BOARD.ID
    if board is 'g'
      $.globalEval """
        window.addEventListener('prettyprint', function(e) {
          var pre = e.detail;
          pre.innerHTML = prettyPrintOne(pre.innerHTML);
        }, false);
      """
      Post::callbacks.push
        name: 'Parse /g/ code'
        cb:   @code
    if board is 'sci'
      # https://github.com/MayhemYDG/4chan-x/issues/645#issuecomment-13704562
      $.globalEval """
        window.addEventListener('jsmath', function(e) {
          if (jsMath.loaded) {
            // process one post
            jsMath.ProcessBeforeShowing(e.detail);
          } else {
            // load jsMath and process whole document
            jsMath.Autoload.Script.Push('ProcessBeforeShowing', [null]);
            jsMath.Autoload.LoadJsMath();
          }
        }, false);
      """
      Post::callbacks.push
        name: 'Parse /sci/ math'
        cb:   @math
  code: ->
    return if @isClone
    for pre in $$ '.prettyprint', @nodes.comment
      $.event 'prettyprint', pre, window
    return
  math: ->
    return if @isClone or !$ '.math', @nodes.comment
    $.event 'jsmath', @nodes.post, window
  parseThread: (threadID, offset, limit) ->
    # Fix /sci/
    # Fix /g/
    $.event '4chanParsingDone',
      threadId: threadID
      offset: offset
      limit: limit

CustomCSS =
  init: ->
    return if !Conf['Custom CSS']
    @addStyle()
  addStyle: ->
    @style = $.addStyle Conf['usercss']
  rmStyle: ->
    if @style
      $.rm @style
      delete @style
  update: ->
    unless @style
      @addStyle()
    @style.textContent = Conf['usercss']

Filter =
  filters: {}
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Filter']

    for key of Config.filter
      @filters[key] = []
      for filter in Conf[key].split '\n'
        continue if filter[0] is '#'

        unless regexp = filter.match /\/(.+)\/(\w*)/
          continue

        # Don't mix up filter flags with the regular expression.
        filter = filter.replace regexp[0], ''

        # Do not add this filter to the list if it's not a global one
        # and it's not specifically applicable to the current board.
        # Defaults to global.
        boards = filter.match(/boards:([^;]+)/)?[1].toLowerCase() or 'global'
        if boards isnt 'global' and not (g.BOARD.ID in boards.split ',')
          continue

        if key in ['uniqueID', 'MD5']
          # MD5 filter will use strings instead of regular expressions.
          regexp = regexp[1]
        else
          try
            # Please, don't write silly regular expressions.
            regexp = RegExp regexp[1], regexp[2]
          catch err
            # I warned you, bro.
            new Notification 'warning', err.message, 60
            continue

        # Filter OPs along with their threads, replies only, or both.
        # Defaults to both.
        op = filter.match(/[^t]op:(yes|no|only)/)?[1] or 'yes'

        # Overrule the `Show Stubs` setting.
        # Defaults to stub showing.
        stub = switch filter.match(/stub:(yes|no)/)?[1]
          when 'yes'
            true
          when 'no'
            false
          else
            Conf['Stubs']

        # Highlight the post, or hide it.
        # If not specified, the highlight class will be filter-highlight.
        # Defaults to post hiding.
        if hl = /highlight/.test filter
          hl  = filter.match(/highlight:(\w+)/)?[1] or 'filter-highlight'
          # Put highlighted OP's thread on top of the board page or not.
          # Defaults to on top.
          top = filter.match(/top:(yes|no)/)?[1] or 'yes'
          top = top is 'yes' # Turn it into a boolean

        @filters[key].push @createFilter regexp, op, stub, hl, top

      # Only execute filter types that contain valid filters.
      unless @filters[key].length
        delete @filters[key]

    return unless Object.keys(@filters).length
    Post::callbacks.push
      name: 'Filter'
      cb:   @node

  createFilter: (regexp, op, stub, hl, top) ->
    test =
      if typeof regexp is 'string'
        # MD5 checking
        (value) -> regexp is value
      else
        (value) -> regexp.test value
    settings =
      hide:  !hl
      stub:  stub
      class: hl
      top:   top
    (value, isReply) ->
      if isReply and op is 'only' or !isReply and op is 'no'
        return false
      unless test value
        return false
      settings

  node: ->
    return if @isClone
    for key of Filter.filters
      value = Filter[key] @
      # Continue if there's nothing to filter (no tripcode for example).
      continue if value is false

      for filter in Filter.filters[key]
        unless result = filter value, @isReply
          continue

        # Hide
        if result.hide
          if @isReply
            PostHiding.hide @, result.stub
          else if g.VIEW is 'index'
            ThreadHiding.hide @thread, result.stub
          else
            continue
          return

        # Highlight
        $.addClass @nodes.root, result.class
        if !@isReply and result.top and g.VIEW is 'index'
          # Put the highlighted OPs' thread on top of the board page...
          thisThread = @nodes.root.parentNode
          # ...before the first non highlighted thread.
          if firstThread = $ 'div[class="postContainer opContainer"]'
            unless firstThread is @nodes.root
              $.before firstThread.parentNode, [thisThread, thisThread.nextElementSibling]

  name: (post) ->
    if 'name' of post.info
      return post.info.name
    false
  uniqueID: (post) ->
    if 'uniqueID' of post.info
      return post.info.uniqueID
    false
  tripcode: (post) ->
    if 'tripcode' of post.info
      return post.info.tripcode
    false
  capcode: (post) ->
    if 'capcode' of post.info
      return post.info.capcode
    false
  email: (post) ->
    if 'email' of post.info
      return post.info.email
    false
  subject: (post) ->
    if 'subject' of post.info
      return post.info.subject or false
    false
  comment: (post) ->
    if 'comment' of post.info
      return post.info.comment
    false
  flag: (post) ->
    if 'flag' of post.info
      return post.info.flag
    false
  filename: (post) ->
    if post.file
      return post.file.name
    false
  dimensions: (post) ->
    if post.file and post.file.isImage
      return post.file.dimensions
    false
  filesize: (post) ->
    if post.file
      return post.file.size
    false
  MD5: (post) ->
    if post.file
      return post.file.MD5
    false

  menu:
    init: ->
      return if g.VIEW is 'catalog' or !Conf['Menu'] or !Conf['Filter']

      div = $.el 'div',
        textContent: 'Filter'

      entry =
        type: 'post'
        el: div
        order: 50
        open: (post) ->
          Filter.menu.post = post
          true
        subEntries: []

      for type in [
        ['Name',             'name']
        ['Unique ID',        'uniqueID']
        ['Tripcode',         'tripcode']
        ['Capcode',          'capcode']
        ['E-mail',           'email']
        ['Subject',          'subject']
        ['Comment',          'comment']
        ['Flag',             'flag']
        ['Filename',         'filename']
        ['Image dimensions', 'dimensions']
        ['Filesize',         'filesize']
        ['Image MD5',        'MD5']
      ]
        # Add a sub entry for each filter type.
        entry.subEntries.push Filter.menu.createSubEntry type[0], type[1]

      $.event 'AddMenuEntry', entry

    createSubEntry: (text, type) ->
      el = $.el 'a',
        href: 'javascript:;'
        textContent: text
      el.setAttribute 'data-type', type
      $.on el, 'click', Filter.menu.makeFilter

      return {
        el: el
        open: (post) ->
          value = Filter[type] post
          value isnt false
      }

    makeFilter: ->
      {type} = @dataset
      # Convert value -> regexp, unless type is MD5
      value = Filter[type] Filter.menu.post
      re = if type in ['uniqueID', 'MD5'] then value else value.replace ///
        /
        | \\
        | \^
        | \$
        | \n
        | \.
        | \(
        | \)
        | \{
        | \}
        | \[
        | \]
        | \?
        | \*
        | \+
        | \|
        ///g, (c) ->
          if c is '\n'
            '\\n'
          else if c is '\\'
            '\\\\'
          else
            "\\#{c}"

      re = if type in ['uniqueID', 'MD5']
        "/#{re}/"
      else
        "/^#{re}$/"

      # Add a new line before the regexp unless the text is empty.
      $.get type, Conf[type], (item) ->
        save = item[type]
        save =
          if save
            "#{save}\n#{re}"
          else
            re
        $.set type, save

        # Open the settings and display & focus the relevant filter textarea.
        Settings.open 'Filter'
        section = $ '.section-container'
        select = $ 'select[name=filter]', section
        select.value = type
        Settings.selectFilter.call select
        ta = $ 'textarea', section
        tl = ta.textLength
        ta.setSelectionRange tl, tl
        ta.focus()

ThreadHiding =
  init: ->
    return if g.VIEW isnt 'index' or !Conf['Thread Hiding'] and !Conf['Thread Hiding Link']

    @db = new DataBoard 'hiddenThreads'
    @syncCatalog()
    Thread::callbacks.push
      name: 'Thread Hiding'
      cb:   @node

  node: ->
    if data = ThreadHiding.db.get {boardID: @board.ID, threadID: @ID}
      ThreadHiding.hide @, data.makeStub
    return unless Conf['Thread Hiding']
    $.prepend @OP.nodes.root, ThreadHiding.makeButton @, 'hide'

  syncCatalog: ->
    # Sync hidden threads from the catalog into the index.
    hiddenThreads = ThreadHiding.db.get
      boardID: g.BOARD.ID
      defaultValue: {}
    # XXX tmp fix
    try
      hiddenThreadsOnCatalog = JSON.parse(localStorage.getItem "4chan-hide-t-#{g.BOARD}") or {}
    catch e
      localStorage.setItem "4chan-hide-t-#{g.BOARD}", JSON.stringify {}
      return ThreadHiding.syncCatalog()

    # Add threads that were hidden in the catalog.
    for threadID of hiddenThreadsOnCatalog
      unless threadID of hiddenThreads
        hiddenThreads[threadID] = {}

    # Remove threads that were un-hidden in the catalog.
    for threadID of hiddenThreads
      unless threadID of hiddenThreadsOnCatalog
        delete hiddenThreads[threadID]

    if (ThreadHiding.db.data.lastChecked or 0) > Date.now() - $.MINUTE
      # Was cleaned just now.
      ThreadHiding.cleanCatalog hiddenThreadsOnCatalog

    unless Object.keys(hiddenThreads).length
      ThreadHiding.db.delete boardID: g.BOARD.ID
      return
    ThreadHiding.db.set
      boardID: g.BOARD.ID
      val: hiddenThreads

  cleanCatalog: (hiddenThreadsOnCatalog) ->
    # We need to clean hidden threads on the catalog ourselves,
    # otherwise if we don't visit the catalog regularly
    # it will pollute the localStorage and our data.
    $.cache "//api.4chan.org/#{g.BOARD}/threads.json", ->
      return unless @status is 200
      threads = {}
      for page in JSON.parse @response
        for thread in page.threads
          if thread.no of hiddenThreadsOnCatalog
            threads[thread.no] = hiddenThreadsOnCatalog[thread.no]
      if Object.keys(threads).length
        localStorage.setItem "4chan-hide-t-#{g.BOARD}", JSON.stringify threads
      else
        localStorage.removeItem "4chan-hide-t-#{g.BOARD}"

  menu:
    init: ->
      return if g.VIEW isnt 'index' or !Conf['Menu'] or !Conf['Thread Hiding Link']

      div = $.el 'div',
        className: 'hide-thread-link'
        textContent: 'Hide thread'

      apply = $.el 'a',
        textContent: 'Apply'
        href: 'javascript:;'
      $.on apply, 'click', ThreadHiding.menu.hide

      makeStub = $.el 'label',
        innerHTML: "<input type=checkbox checked=#{Conf['Stubs']}> Make stub"

      $.event 'AddMenuEntry',
        type: 'post'
        el: div
        order: 20
        open: ({thread, isReply}) ->
          if isReply or thread.isHidden
            return false
          ThreadHiding.menu.thread = thread
          true
        subEntries: [el: apply; el: makeStub]
    hide: ->
      makeStub = $('input', @parentNode).checked
      {thread} = ThreadHiding.menu
      ThreadHiding.hide thread, makeStub
      ThreadHiding.saveHiddenState thread, makeStub
      $.event 'CloseMenu'

  makeButton: (thread, type) ->
    a = $.el 'a',
      className: "#{type}-thread-button"
      innerHTML: "<span>[&nbsp;#{if type is 'hide' then '-' else '+'}&nbsp;]</span>"
      href:      'javascript:;'
    a.setAttribute 'data-fullid', thread.fullID
    $.on a, 'click', ThreadHiding.toggle
    a

  saveHiddenState: (thread, makeStub) ->
    hiddenThreadsOnCatalog = JSON.parse(localStorage.getItem "4chan-hide-t-#{g.BOARD}") or {}
    if thread.isHidden
      ThreadHiding.db.set
        boardID:  thread.board.ID
        threadID: thread.ID
        val: {makeStub}
      hiddenThreadsOnCatalog[thread] = true
    else
      ThreadHiding.db.delete
        boardID:  thread.board.ID
        threadID: thread.ID
      delete hiddenThreadsOnCatalog[thread]
    localStorage.setItem "4chan-hide-t-#{g.BOARD}", JSON.stringify hiddenThreadsOnCatalog

  toggle: (thread) ->
    unless thread instanceof Thread
      thread = g.threads[@dataset.fullid]
    if thread.isHidden
      ThreadHiding.show thread
    else
      ThreadHiding.hide thread
    ThreadHiding.saveHiddenState thread

  hide: (thread, makeStub=Conf['Stubs']) ->
    return if thread.isHidden
    {OP} = thread
    threadRoot = OP.nodes.root.parentNode
    threadRoot.hidden = thread.isHidden = true

    unless makeStub
      threadRoot.nextElementSibling.hidden = true # <hr>
      return

    numReplies = 0
    if span = $ '.summary', threadRoot
      numReplies = +span.textContent.match /\d+/
    numReplies += $$('.opContainer ~ .replyContainer', threadRoot).length
    numReplies  = if numReplies is 1 then '1 reply' else "#{numReplies} replies"
    opInfo =
      if Conf['Anonymize']
        'Anonymous'
      else
        $('.nameBlock', OP.nodes.info).textContent

    a = ThreadHiding.makeButton thread, 'show'
    $.add a, $.tn " #{opInfo} (#{numReplies})"
    thread.stub = $.el 'div',
      className: 'stub'
    $.add thread.stub, a
    if Conf['Menu']
      $.add thread.stub, [$.tn(' '), Menu.makeButton OP]
    $.before threadRoot, thread.stub

  show: (thread) ->
    if thread.stub
      $.rm thread.stub
      delete thread.stub
    threadRoot = thread.OP.nodes.root.parentNode
    threadRoot.nextElementSibling.hidden =
      threadRoot.hidden = thread.isHidden = false

PostHiding =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Reply Hiding'] and !Conf['Reply Hiding Link']

    @db = new DataBoard 'hiddenPosts'
    Post::callbacks.push
      name: 'Reply Hiding'
      cb:   @node

  node: ->
    return if !@isReply or @isClone
    if data = PostHiding.db.get {boardID: @board.ID, threadID: @thread.ID, postID: @ID}
      if data.thisPost
        PostHiding.hide @, data.makeStub, data.hideRecursively
      else
        Recursive.apply PostHiding.hide, @, data.makeStub, true
        Recursive.add PostHiding.hide, @, data.makeStub, true
    return unless Conf['Reply Hiding']
    $.replace $('.sideArrows', @nodes.root), PostHiding.makeButton @, 'hide'

  menu:
    init: ->
      return if g.VIEW is 'catalog' or !Conf['Menu'] or !Conf['Reply Hiding Link']

      # Hide
      div = $.el 'div',
        className: 'hide-reply-link'
        textContent: 'Hide reply'

      apply = $.el 'a',
        textContent: 'Apply'
        href: 'javascript:;'
      $.on apply, 'click', PostHiding.menu.hide

      thisPost = $.el 'label',
        innerHTML: '<input type=checkbox name=thisPost checked> This post'
      replies  = $.el 'label',
        innerHTML: "<input type=checkbox name=replies  checked=#{Conf['Recursive Hiding']}> Hide replies"
      makeStub = $.el 'label',
        innerHTML: "<input type=checkbox name=makeStub checked=#{Conf['Stubs']}> Make stub"

      $.event 'AddMenuEntry',
        type: 'post'
        el: div
        order: 20
        open: (post) ->
          if !post.isReply or post.isClone or post.isHidden
            return false
          PostHiding.menu.post = post
          true
        subEntries: [{el: apply}, {el: thisPost}, {el: replies}, {el: makeStub}]

      # Show
      div = $.el 'div',
        className: 'show-reply-link'
        textContent: 'Show reply'

      apply = $.el 'a',
        textContent: 'Apply'
        href: 'javascript:;'
      $.on apply, 'click', PostHiding.menu.show

      thisPost = $.el 'label',
        innerHTML: '<input type=checkbox name=thisPost> This post'
      replies  = $.el 'label',
        innerHTML: "<input type=checkbox name=replies> Show replies"

      $.event 'AddMenuEntry',
        type: 'post'
        el: div
        order: 20
        open: (post) ->
          if !post.isReply or post.isClone or !post.isHidden
            return false
          unless data = PostHiding.db.get {boardID: post.board.ID, threadID: post.thread.ID, postID: post.ID}
            return false
          PostHiding.menu.post = post
          thisPost.firstChild.checked = post.isHidden
          replies.firstChild.checked  = if data?.hideRecursively? then data.hideRecursively else Conf['Recursive Hiding']
          true
        subEntries: [{el: apply}, {el: thisPost}, {el: replies}]
    hide: ->
      parent   = @parentNode
      thisPost = $('input[name=thisPost]', parent).checked
      replies  = $('input[name=replies]',  parent).checked
      makeStub = $('input[name=makeStub]', parent).checked
      {post}   = PostHiding.menu
      if thisPost
        PostHiding.hide post, makeStub, replies
      else if replies
        Recursive.apply PostHiding.hide, post, makeStub, true
        Recursive.add PostHiding.hide, post, makeStub, true
      else
        return
      PostHiding.saveHiddenState post, true, thisPost, makeStub, replies
      $.event 'CloseMenu'
    show: ->
      parent   = @parentNode
      thisPost = $('input[name=thisPost]', parent).checked
      replies  = $('input[name=replies]',  parent).checked
      {post}   = PostHiding.menu
      if thisPost
        PostHiding.show post, replies
      else if replies
        Recursive.apply PostHiding.show, post, true
        Recursive.rm PostHiding.hide, post, true
      else
        return
      if data = PostHiding.db.get {boardID: post.board.ID, threadID: post.thread.ID, postID: post.ID}
        PostHiding.saveHiddenState post, !(thisPost and replies), !thisPost, data.makeStub, !replies
      $.event 'CloseMenu'

  makeButton: (post, type) ->
    a = $.el 'a',
      className: "#{type}-reply-button"
      innerHTML: "<span>[&nbsp;#{if type is 'hide' then '-' else '+'}&nbsp;]</span>"
      href:      'javascript:;'
    $.on a, 'click', PostHiding.toggle
    a

  saveHiddenState: (post, isHiding, thisPost, makeStub, hideRecursively) ->
    data =
      boardID:  post.board.ID
      threadID: post.thread.ID
      postID:   post.ID
    if isHiding
      data.val =
        thisPost: thisPost isnt false # undefined -> true
        makeStub: makeStub
        hideRecursively: hideRecursively
      PostHiding.db.set data
    else
      PostHiding.db.delete data

  toggle: ->
    post = Get.postFromNode @
    if post.isHidden
      PostHiding.show post
    else
      PostHiding.hide post
    PostHiding.saveHiddenState post, post.isHidden

  hide: (post, makeStub=Conf['Stubs'], hideRecursively=Conf['Recursive Hiding']) ->
    return if post.isHidden
    post.isHidden = true

    if hideRecursively
      Recursive.apply PostHiding.hide, post, makeStub, true
      Recursive.add PostHiding.hide, post, makeStub, true

    for quotelink in Get.allQuotelinksLinkingTo post
      $.addClass quotelink, 'filtered'

    unless makeStub
      post.nodes.root.hidden = true
      return

    a = PostHiding.makeButton post, 'show'
    postInfo =
      if Conf['Anonymize']
        'Anonymous'
      else
        $('.nameBlock', post.nodes.info).textContent
    $.add a, $.tn " #{postInfo}"
    post.nodes.stub = $.el 'div',
      className: 'stub'
    $.add post.nodes.stub, a
    if Conf['Menu']
      $.add post.nodes.stub, [$.tn(' '), Menu.makeButton post]
    $.prepend post.nodes.root, post.nodes.stub

  show: (post, showRecursively=Conf['Recursive Hiding']) ->
    if post.nodes.stub
      $.rm post.nodes.stub
      delete post.nodes.stub
    else
      post.nodes.root.hidden = false
    post.isHidden = false
    if showRecursively
      Recursive.apply PostHiding.show, post, true
      Recursive.rm PostHiding.hide, post
    for quotelink in Get.allQuotelinksLinkingTo post
      $.rmClass quotelink, 'filtered'
    return

Recursive =
  recursives: {}
  init: ->
    return if g.VIEW is 'catalog'

    Post::callbacks.push
      name: 'Recursive'
      cb:   @node

  node: ->
    return if @isClone
    for quote in @quotes
      if obj = Recursive.recursives[quote]
        for recursive, i in obj.recursives
          recursive @, obj.args[i]...
    return

  add: (recursive, post, args...) ->
    obj = Recursive.recursives[post.fullID] or=
      recursives: []
      args: []
    obj.recursives.push recursive
    obj.args.push args

  rm: (recursive, post) ->
    return unless obj = Recursive.recursives[post.fullID]
    for rec, i in obj.recursives
      if rec is recursive
        obj.recursives.splice i, 1
        obj.args.splice i, 1
    return

  apply: (recursive, post, args...) ->
    {fullID} = post
    for ID, post of g.posts
      if fullID in post.quotes
        recursive post, args...
    return

QuoteStrikeThrough =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Reply Hiding'] and !Conf['Reply Hiding Link'] and !Conf['Filter']

    Post::callbacks.push
      name: 'Strike-through Quotes'
      cb:   @node

  node: ->
    return if @isClone
    for quotelink in @nodes.quotelinks
      {boardID, postID} = Get.postDataFromLink quotelink
      if g.posts["#{boardID}.#{postID}"]?.isHidden
        $.addClass quotelink, 'filtered'
    return

Menu =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Menu']

    @menu = new UI.Menu 'post'
    Post::callbacks.push
      name: 'Menu'
      cb:   @node

  node: ->
    button = Menu.makeButton @
    if @isClone
      $.replace $('.menu-button', @nodes.info), button
      return
    $.add @nodes.info, [$.tn('\u00A0'), button]

  makeButton: do ->
    a = null
    (post) ->
      a or= $.el 'a',
        className: 'menu-button'
        innerHTML: '[<i></i>]'
        href:      'javascript:;'
      clone = a.cloneNode true
      clone.setAttribute 'data-postid', post.fullID
      clone.setAttribute 'data-clone', true if post.isClone
      $.on clone, 'click', Menu.toggle
      clone

  toggle: (e) ->
    post =
      if @dataset.clone
        Get.postFromNode @
      else
        g.posts[@dataset.postid]
    Menu.menu.toggle e, @, post

ReportLink =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Menu'] or !Conf['Report Link']

    a = $.el 'a',
      className: 'report-link'
      href: 'javascript:;'
      textContent: 'Report this post'
    $.on a, 'click', ReportLink.report
    $.event 'AddMenuEntry',
      type: 'post'
      el: a
      order: 10
      open: (post) ->
        ReportLink.post = post
        !post.isDead
  report: ->
    {post} = ReportLink
    url = "//sys.4chan.org/#{post.board}/imgboard.php?mode=report&no=#{post}"
    id  = Date.now()
    set = "toolbar=0,scrollbars=0,location=0,status=1,menubar=0,resizable=1,width=685,height=200"
    window.open url, id, set

DeleteLink =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Menu'] or !Conf['Delete Link']

    div = $.el 'div',
      className: 'delete-link'
      textContent: 'Delete'
    postEl = $.el 'a',
      className: 'delete-post'
      href: 'javascript:;'
    fileEl = $.el 'a',
      className: 'delete-file'
      href: 'javascript:;'

    postEntry =
      el: postEl
      open: ->
        postEl.textContent = 'Post'
        $.on postEl, 'click', DeleteLink.delete
        true
    fileEntry =
      el: fileEl
      open: ({file}) ->
        return false if !file or file.isDead
        fileEl.textContent = 'File'
        $.on fileEl, 'click', DeleteLink.delete
        true

    $.event 'AddMenuEntry',
      type: 'post'
      el: div
      order: 40
      open: (post) ->
        return false if post.isDead
        DeleteLink.post = post
        node = div.firstChild
        node.textContent = 'Delete'
        DeleteLink.cooldown.start post, node
        true
      subEntries: [postEntry, fileEntry]

  delete: ->
    {post} = DeleteLink
    return if DeleteLink.cooldown.counting is post

    $.off @, 'click', DeleteLink.delete
    @textContent = "Deleting #{@textContent}..."

    pwd =
      if m = d.cookie.match /4chan_pass=([^;]+)/
        decodeURIComponent m[1]
      else
        $.id('delPassword').value

    fileOnly = $.hasClass @, 'delete-file'

    form =
      mode: 'usrdel'
      onlyimgdel: fileOnly
      pwd: pwd
    form[post.ID] = 'delete'

    link = @
    $.ajax $.id('delform').action.replace("/#{g.BOARD}/", "/#{post.board}/"),
      onload:  -> DeleteLink.load  link, post, fileOnly, @response
      onerror: -> DeleteLink.error link
    ,
      cred: true
      form: $.formData form
  load: (link, post, fileOnly, html) ->
    tmpDoc = d.implementation.createHTMLDocument ''
    tmpDoc.documentElement.innerHTML = html
    if tmpDoc.title is '4chan - Banned' # Ban/warn check
      s = 'Banned!'
    else if msg = tmpDoc.getElementById 'errmsg' # error!
      s = msg.textContent
      $.on link, 'click', DeleteLink.delete
    else
      if tmpDoc.title is 'Updating index...'
        # We're 100% sure.
        (post.origin or post).kill fileOnly
      s = 'Deleted'
    link.textContent = s
  error: (link) ->
    link.textContent = 'Connection error, please retry.'
    $.on link, 'click', DeleteLink.delete

  cooldown:
    start: (post, node) ->
      unless QR.db?.get {boardID: post.board.ID, threadID: post.thread.ID, postID: post.ID}
        # Only start counting on our posts.
        delete DeleteLink.cooldown.counting
        return
      DeleteLink.cooldown.counting = post
      length = if post.board.ID is 'q'
        600
      else
        30
      seconds = Math.ceil (length * $.SECOND - (Date.now() - post.info.date)) / $.SECOND
      DeleteLink.cooldown.count post, seconds, length, node
    count: (post, seconds, length, node) ->
      return if DeleteLink.cooldown.counting isnt post
      unless 0 <= seconds <= length
        if DeleteLink.cooldown.counting is post
          node.textContent = 'Delete'
          delete DeleteLink.cooldown.counting
        return
      setTimeout DeleteLink.cooldown.count, 1000, post, seconds - 1, length, node
      node.textContent = "Delete (#{seconds})"

DownloadLink =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Menu'] or !Conf['Download Link']

    a = $.el 'a',
      className: 'download-link'
      textContent: 'Download file'
    $.event 'AddMenuEntry',
      type: 'post'
      el: a
      order: 70
      open: ({file}) ->
        return false unless file
        a.href     = file.URL
        a.download = file.name
        true

ArchiveLink =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Menu'] or !Conf['Archive Link']

    div = $.el 'div',
      textContent: 'Archive'

    entry =
      type: 'post'
      el: div
      order: 90
      open: ({ID, thread, board}) ->
        redirect = Redirect.to {postID: ID, threadID: thread.ID, boardID: board.ID}
        redirect isnt "//boards.4chan.org/#{board}/"
      subEntries: []

    for type in [
      ['Post',      'post']
      ['Name',      'name']
      ['Tripcode',  'tripcode']
      ['E-mail',    'email']
      ['Subject',   'subject']
      ['Filename',  'filename']
      ['Image MD5', 'MD5']
    ]
      # Add a sub entry for each type.
      entry.subEntries.push @createSubEntry type[0], type[1]

    $.event 'AddMenuEntry', entry

  createSubEntry: (text, type) ->
    el = $.el 'a',
      textContent: text
      target: '_blank'

    open = if type is 'post'
      ({ID, thread, board}) ->
        el.href = Redirect.to {postID: ID, threadID: thread.ID, boardID: board.ID}
        true
    else
      (post) ->
        value = Filter[type] post
        # We want to parse the exact same stuff as the filter does already.
        return false unless value
        el.href = Redirect.to
          boardID:  post.board.ID
          type:     type
          value:    value
          isSearch: true
        true

    return {
      el: el
      open: open
    }

Keybinds =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Keybinds']

    init = ->
      $.off d, '4chanXInitFinished', init
      $.on d, 'keydown',  Keybinds.keydown
      for node in $$ '[accesskey]'
        node.removeAttribute 'accesskey'
      return
    $.on d, '4chanXInitFinished', init

  keydown: (e) ->
    return unless key = Keybinds.keyCode e
    {target} = e
    if target.nodeName in ['INPUT', 'TEXTAREA']
      return unless /(Esc|Alt|Ctrl|Meta)/.test key

    threadRoot = Nav.getThread()
    if op = $ '.op', threadRoot
      thread = Get.postFromNode(op).thread
    switch key
      # QR & Options
      when Conf['Toggle board list']
        if Conf['Custom Board Navigation']
          Header.toggleBoardList()
      when Conf['Open empty QR']
        Keybinds.qr threadRoot
      when Conf['Open QR']
        Keybinds.qr threadRoot, true
      when Conf['Open settings']
        Settings.open()
      when Conf['Close']
        if Settings.dialog
          Settings.close()
        else if (notifications = $$ '.notification').length
          for notification in notifications
            $('.close', notification).click()
        else if QR.nodes
          QR.close()
      when Conf['Spoiler tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'spoiler', target
      when Conf['Code tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'code', target
      when Conf['Eqn tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'eqn', target
      when Conf['Math tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'math', target
      when Conf['Submit QR']
        QR.submit() if QR.nodes and !QR.status()
      # Thread related
      when Conf['Watch']
        ThreadWatcher.toggle thread
      when Conf['Update']
        ThreadUpdater.update()
      # Images
      when Conf['Expand image']
        Keybinds.img threadRoot
      when Conf['Expand images']
        Keybinds.img threadRoot, true
      # Board Navigation
      when Conf['Front page']
        window.location = "/#{g.BOARD}/0#delform"
      when Conf['Open front page']
        $.open "/#{g.BOARD}/#delform"
      when Conf['Next page']
        if form = $ '.next form'
          window.location = form.action
      when Conf['Previous page']
        if form = $ '.prev form'
          window.location = form.action
      # Thread Navigation
      when Conf['Next thread']
        return if g.VIEW is 'thread'
        Nav.scroll +1
      when Conf['Previous thread']
        return if g.VIEW is 'thread'
        Nav.scroll -1
      when Conf['Expand thread']
        ExpandThread.toggle thread
      when Conf['Open thread']
        Keybinds.open thread
      when Conf['Open thread tab']
        Keybinds.open thread, true
      # Reply Navigation
      when Conf['Next reply']
        Keybinds.hl +1, threadRoot
      when Conf['Previous reply']
        Keybinds.hl -1, threadRoot
      when Conf['Hide']
        ThreadHiding.toggle thread if g.VIEW is 'index'
      else
        return
    e.preventDefault()
    e.stopPropagation()

  keyCode: (e) ->
    key = switch kc = e.keyCode
      when 8 # return
        ''
      when 13
        'Enter'
      when 27
        'Esc'
      when 37
        'Left'
      when 38
        'Up'
      when 39
        'Right'
      when 40
        'Down'
      else
        if 48 <= kc <= 57 or 65 <= kc <= 90 # 0-9, A-Z
          String.fromCharCode(kc).toLowerCase()
        else
          null
    if key
      if e.altKey   then key = 'Alt+'   + key
      if e.ctrlKey  then key = 'Ctrl+'  + key
      if e.metaKey  then key = 'Meta+'  + key
      if e.shiftKey then key = 'Shift+' + key
    key

  qr: (thread, quote) ->
    return unless Conf['Quick Reply'] and QR.postingIsEnabled
    QR.open()
    if quote
      QR.quote.call $ 'input', $('.post.highlight', thread) or thread
    QR.nodes.com.focus()

  tags: (tag, ta) ->
    value    = ta.value
    selStart = ta.selectionStart
    selEnd   = ta.selectionEnd

    ta.value =
      value[...selStart] +
      "[#{tag}]" + value[selStart...selEnd] + "[/#{tag}]" +
      value[selEnd..]

    # Move the caret to the end of the selection.
    range = "[#{tag}]".length + selEnd
    ta.setSelectionRange range, range

    # Fire the 'input' event
    $.event 'input', null, ta

  img: (thread, all) ->
    if all
      ImageExpand.cb.toggleAll()
    else
      post = Get.postFromNode $('.post.highlight', thread) or $ '.op', thread
      ImageExpand.toggle post

  open: (thread, tab) ->
    return if g.VIEW isnt 'index'
    url = "/#{thread.board}/res/#{thread}"
    if tab
      $.open url
    else
      location.href = url

  hl: (delta, thread) ->
    if Conf['Bottom header']
      topMargin = 0
    else
      headRect  = Header.toggle.getBoundingClientRect()
      topMargin = headRect.top + headRect.height
    if postEl = $ '.reply.highlight', thread
      $.rmClass postEl, 'highlight'
      rect = postEl.getBoundingClientRect()
      if rect.bottom >= topMargin and rect.top <= doc.clientHeight # We're at least partially visible
        root = postEl.parentNode
        next = $.x 'child::div[contains(@class,"post reply")]',
          if delta is +1 then root.nextElementSibling else root.previousElementSibling
        unless next
          @focus postEl
          return
        return unless g.VIEW is 'thread' or $.x('ancestor::div[parent::div[@class="board"]]', next) is thread
        rect = next.getBoundingClientRect()
        if rect.top < 0 or rect.bottom > doc.clientHeight
          if delta is -1
            window.scrollBy 0, rect.top - topMargin
          else
            next.scrollIntoView false
        @focus next
        return

    replies = $$ '.reply', thread
    replies.reverse() if delta is -1
    for reply in replies
      rect = reply.getBoundingClientRect()
      if delta is +1 and rect.top >= topMargin or delta is -1 and rect.bottom <= doc.clientHeight
        @focus reply
        return

  focus: (post) ->
    $.addClass post, 'highlight'

Nav =
  init: ->
    switch g.VIEW
      when 'index'
        return unless Conf['Index Navigation']
      when 'thread'
        return unless Conf['Reply Navigation']
      else # catalog
        return

    span = $.el 'span',
      id: 'navlinks'
    prev = $.el 'a',
      textContent: '▲'
      href: 'javascript:;'
    next = $.el 'a',
      textContent: '▼'
      href: 'javascript:;'

    $.on prev, 'click', @prev
    $.on next, 'click', @next

    $.add span, [prev, $.tn(' '), next]
    append = ->
      $.off d, '4chanXInitFinished', append
      $.add d.body, span
    $.on d, '4chanXInitFinished', append

  prev: ->
    if g.VIEW is 'thread'
      window.scrollTo 0, 0
    else
      Nav.scroll -1

  next: ->
    if g.VIEW is 'thread'
      window.scrollTo 0, d.body.scrollHeight
    else
      Nav.scroll +1

  getThread: (full) ->
    if Conf['Bottom header']
      topMargin = 0
    else
      headRect  = Header.toggle.getBoundingClientRect()
      topMargin = headRect.top + headRect.height
    threads = $$ '.thread:not([hidden])'
    for thread, i in threads
      rect = thread.getBoundingClientRect()
      if rect.bottom > topMargin # not scrolled past
        return if full then [threads, thread, i, rect, topMargin] else thread
    return $ '.board'

  scroll: (delta) ->
    [threads, thread, i, rect, topMargin] = Nav.getThread true
    top = rect.top - topMargin

    # unless we're not at the beginning of the current thread
    # (and thus wanting to move to beginning)
    # or we're above the first thread and don't want to skip it
    unless (delta is -1 and Math.ceil(top) < 0) or (delta is +1 and top > 1)
      i += delta

    top = threads[i]?.getBoundingClientRect().top - topMargin
    window.scrollBy 0, top

Redirect =
  image: (boardID, filename) ->
    # Do not use g.BOARD, the image url can originate from a cross-quote.
    switch boardID
      when 'a', 'gd', 'jp', 'm', 'q', 'tg', 'vg', 'vp', 'vr', 'wsg'
        "//archive.foolz.us/#{boardID}/full_image/#{filename}"
      when 'u'
        "//nsfw.foolz.us/#{boardID}/full_image/#{filename}"
      when 'po'
        "//archive.thedarkcave.org/#{boardID}/full_image/#{filename}"
      when 'hr', 'tv'
        "http://archive.4plebs.org/#{boardID}/full_image/#{filename}"
      when 'ck', 'fa', 'lit', 's4s'
        "//fuuka.warosu.org/#{boardID}/full_image/#{filename}"
      when 'cgl', 'g', 'mu', 'w'
        "//rbt.asia/#{boardID}/full_image/#{filename}"
      when 'an', 'k', 'toy', 'x'
        "http://archive.heinessen.com/#{boardID}/full_image/#{filename}"
      when 'c'
        "//archive.nyafuu.org/#{boardID}/full_image/#{filename}"
  post: (boardID, postID) ->
    # XXX foolz had HSTS set for 120 days, which broke XHR+CORS+Redirection when on HTTP.
    # Remove necessary HTTPS procotol in September 2013.
    switch boardID
      when 'a', 'co', 'gd', 'jp', 'm', 'q', 'sp', 'tg', 'tv', 'v', 'vg', 'vp', 'vr', 'wsg'
        "https://archive.foolz.us/_/api/chan/post/?board=#{boardID}&num=#{postID}"
      when 'u'
        "https://nsfw.foolz.us/_/api/chan/post/?board=#{boardID}&num=#{postID}"
      when 'c', 'int', 'out', 'po'
        "//archive.thedarkcave.org/_/api/chan/post/?board=#{boardID}&num=#{postID}"
      when 'hr', 'x'
        "http://archive.4plebs.org/_/api/chan/post/?board=#{boardID}&num=#{postID}"
    # for fuuka-based archives:
    # https://github.com/eksopl/fuuka/issues/27
  to: (data) ->
    {boardID} = data
    switch boardID
      when 'a', 'co', 'gd', 'jp', 'm', 'q', 'sp', 'tg', 'tv', 'v', 'vg', 'vp', 'vr', 'wsg'
        Redirect.path '//archive.foolz.us', 'foolfuuka', data
      when 'u'
        Redirect.path '//nsfw.foolz.us', 'foolfuuka', data
      when 'int', 'out', 'po'
        Redirect.path '//archive.thedarkcave.org', 'foolfuuka', data
      when 'hr'
        Redirect.path 'http://archive.4plebs.org', 'foolfuuka', data
      when 'ck', 'fa', 'lit', 's4s'
        Redirect.path '//fuuka.warosu.org', 'fuuka', data
      when 'diy', 'g', 'sci'
        Redirect.path '//archive.installgentoo.net', 'fuuka', data
      when 'cgl', 'mu', 'w'
        Redirect.path '//rbt.asia', 'fuuka', data
      when 'an', 'fit', 'k', 'mlp', 'r9k', 'toy', 'x'
        Redirect.path 'http://archive.heinessen.com', 'fuuka', data
      when 'c'
        Redirect.path '//archive.nyafuu.org', 'fuuka', data
      else
        if data.threadID then "//boards.4chan.org/#{boardID}/" else ''
  path: (base, archiver, data) ->
    if data.isSearch
      {boardID, type, value} = data
      type = if type is 'name'
        'username'
      else if type is 'MD5'
        'image'
      else
        type
      value = encodeURIComponent value
      return if archiver is 'foolfuuka'
        "#{base}/#{boardID}/search/#{type}/#{value}"
      else if type is 'image'
        "#{base}/#{boardID}/?task=search2&search_media_hash=#{value}"
      else
        "#{base}/#{boardID}/?task=search2&search_#{type}=#{value}"

    {boardID, threadID, postID} = data
    # keep the number only if the location.hash was sent f.e.
    path = if threadID
      "#{boardID}/thread/#{threadID}"
    else
      "#{boardID}/post/#{postID}"
    if archiver is 'foolfuuka'
      path += '/'
    if threadID and postID
      path += if archiver is 'foolfuuka'
        "##{postID}"
      else
        "#p#{postID}"
    "#{base}/#{path}"

Build =
  spoilerRange: {}
  shortFilename: (filename, isReply) ->
    # FILENAME SHORTENING SCIENCE:
    # OPs have a +10 characters threshold.
    # The file extension is not taken into account.
    threshold = if isReply then 30 else 40
    if filename.length - 4 > threshold
      "#{filename[...threshold - 5]}(...).#{filename[-3..]}"
    else
      filename
  postFromObject: (data, boardID) ->
    o =
      # id
      postID:   data.no
      threadID: data.resto or data.no
      boardID:  boardID
      # info
      name:     data.name
      capcode:  data.capcode
      tripcode: data.trip
      uniqueID: data.id
      email:    if data.email then encodeURI data.email.replace /&quot;/g, '"' else ''
      subject:  data.sub
      flagCode: data.country
      flagName: data.country_name
      date:     data.now
      dateUTC:  data.time
      comment:  data.com
      # thread status
      isSticky: !!data.sticky
      isClosed: !!data.closed
      # file
    if data.ext or data.filedeleted
      o.file =
        name:      data.filename + data.ext
        timestamp: "#{data.tim}#{data.ext}"
        url:       "//images.4chan.org/#{boardID}/src/#{data.tim}#{data.ext}"
        height:    data.h
        width:     data.w
        MD5:       data.md5
        size:      data.fsize
        turl:      "//thumbs.4chan.org/#{boardID}/thumb/#{data.tim}s.jpg"
        theight:   data.tn_h
        twidth:    data.tn_w
        isSpoiler: !!data.spoiler
        isDeleted: !!data.filedeleted
    Build.post o
  post: (o, isArchived) ->
    {
      postID, threadID, boardID
      name, capcode, tripcode, uniqueID, email, subject, flagCode, flagName, date, dateUTC
      isSticky, isClosed
      comment
      file
    } = o
    isOP = postID is threadID

    staticPath = '//static.4chan.org'

    if email
      emailStart = '<a href="mailto:' + email + '" class="useremail">'
      emailEnd   = '</a>'
    else
      emailStart = ''
      emailEnd   = ''

    subject = "<span class=subject>#{subject or ''}</span>"

    userID =
      if !capcode and uniqueID
        " <span class='posteruid id_#{uniqueID}'>(ID: " +
          "<span class=hand title='Highlight posts by this ID'>#{uniqueID}</span>)</span> "
      else
        ''

    switch capcode
      when 'admin', 'admin_highlight'
        capcodeClass = " capcodeAdmin"
        capcodeStart = " <strong class='capcode hand id_admin'" +
          "title='Highlight posts by the Administrator'>## Admin</strong>"
        capcode      = " <img src='#{staticPath}/image/adminicon.gif' " +
          "alt='This user is the 4chan Administrator.' " +
          "title='This user is the 4chan Administrator.' class=identityIcon>"
      when 'mod'
        capcodeClass = " capcodeMod"
        capcodeStart = " <strong class='capcode hand id_mod' " +
          "title='Highlight posts by Moderators'>## Mod</strong>"
        capcode      = " <img src='#{staticPath}/image/modicon.gif' " +
          "alt='This user is a 4chan Moderator.' " +
          "title='This user is a 4chan Moderator.' class=identityIcon>"
      when 'developer'
        capcodeClass = " capcodeDeveloper"
        capcodeStart = " <strong class='capcode hand id_developer' " +
          "title='Highlight posts by Developers'>## Developer</strong>"
        capcode      = " <img src='#{staticPath}/image/developericon.gif' " +
          "alt='This user is a 4chan Developer.' " +
          "title='This user is a 4chan Developer.' class=identityIcon>"
      else
        capcodeClass = ''
        capcodeStart = ''
        capcode      = ''

    flag =
      if flagCode
        " <img src='#{staticPath}/image/country/#{if boardID is 'pol' then 'troll/' else ''}" +
        flagCode.toLowerCase() + ".gif' alt=#{flagCode} title='#{flagName}' class=countryFlag>"
      else
        ''

    if file?.isDeleted
      fileHTML =
        if isOP
          "<div id=f#{postID} class=file><div class=fileInfo></div><span class=fileThumb>" +
              "<img src='#{staticPath}/image/filedeleted.gif' alt='File deleted.' class='fileDeleted retina'>" +
          "</span></div>"
        else
          "<div id=f#{postID} class=file><span class=fileThumb>" +
            "<img src='#{staticPath}/image/filedeleted-res.gif' alt='File deleted.' class='fileDeletedRes retina'>" +
          "</span></div>"
    else if file
      ext = file.name[-3..]
      if !file.twidth and !file.theight and ext is 'gif' # wtf ?
        file.twidth  = file.width
        file.theight = file.height

      fileSize = $.bytesToString file.size

      fileThumb = file.turl
      if file.isSpoiler
        fileSize = "Spoiler Image, #{fileSize}"
        unless isArchived
          fileThumb = '//static.4chan.org/image/spoiler'
          if spoilerRange = Build.spoilerRange[boardID]
            # Randomize the spoiler image.
            fileThumb += "-#{boardID}" + Math.floor 1 + spoilerRange * Math.random()
          fileThumb += '.png'
          file.twidth = file.theight = 100

      if boardID.ID isnt 'f'
        imgSrc = "<a class='fileThumb#{if file.isSpoiler then ' imgspoiler' else ''}' href='#{file.url}' target=_blank>" +
          "<img src='#{fileThumb}' alt='#{fileSize}' data-md5=#{file.MD5} style='height: #{file.theight}px; width: #{file.twidth}px;'></a>"

      # Ha ha, filenames!
      # html -> text, translate WebKit's %22s into "s
      a = $.el 'a', innerHTML: file.name
      filename = a.textContent.replace /%22/g, '"'

      # shorten filename, get html
      a.textContent = Build.shortFilename filename
      shortFilename = a.innerHTML

      # get html
      a.textContent = filename
      filename      = a.innerHTML.replace /'/g, '&apos;'

      fileDims = if ext is 'pdf' then 'PDF' else "#{file.width}x#{file.height}"
      fileInfo = "<span class=fileText id=fT#{postID}#{if file.isSpoiler then " title='#{filename}'" else ''}>File: <a href='#{file.url}' target=_blank>#{file.timestamp}</a>" +
        "-(#{fileSize}, #{fileDims}#{
          if file.isSpoiler
            ''
          else
            ", <span title='#{filename}'>#{shortFilename}</span>"
        }" + ")</span>"

      fileHTML = "<div id=f#{postID} class=file><div class=fileInfo>#{fileInfo}</div>#{imgSrc}</div>"
    else
      fileHTML = ''

    tripcode =
      if tripcode
        " <span class=postertrip>#{tripcode}</span>"
      else
        ''

    sticky =
      if isSticky
        ' <img src=//static.4chan.org/image/sticky.gif alt=Sticky title=Sticky class=stickyIcon>'
      else
        ''
    closed =
      if isClosed
        ' <img src=//static.4chan.org/image/closed.gif alt=Closed title=Closed class=closedIcon>'
      else
        ''

    container = $.el 'div',
      id: "pc#{postID}"
      className: "postContainer #{if isOP then 'op' else 'reply'}Container"
      innerHTML: \
      (if isOP then '' else "<div class=sideArrows id=sa#{postID}>&gt;&gt;</div>") +
      "<div id=p#{postID} class='post #{if isOP then 'op' else 'reply'}#{
        if capcode is 'admin_highlight'
          ' highlightPost'
        else
          ''
        }'>" +

        "<div class='postInfoM mobile' id=pim#{postID}>" +
          "<span class='nameBlock#{capcodeClass}'>" +
              "<span class=name>#{name or ''}</span>" + tripcode +
            capcodeStart + capcode + userID + flag + sticky + closed +
            "<br>#{subject}" +
          "</span><span class='dateTime postNum' data-utc=#{dateUTC}>#{date}" +
            "<a href=#{"/#{boardID}/res/#{threadID}#p#{postID}"}>No.</a>" +
            "<a href='#{
              if g.VIEW is 'thread' and g.THREADID is +threadID
                "javascript:quote(#{postID})"
              else
                "/#{boardID}/res/#{threadID}#q#{postID}"
              }'>#{postID}</a>" +
          '</span>' +
        '</div>' +

        (if isOP then fileHTML else '') +

        "<div class='postInfo desktop' id=pi#{postID}>" +
          "<input type=checkbox name=#{postID} value=delete> " +
          "#{subject} " +
          "<span class='nameBlock#{capcodeClass}'>" +
            emailStart +
              "<span class=name>#{name or ''}</span>" + tripcode +
            capcodeStart + emailEnd + capcode + userID + flag + sticky + closed +
          ' </span> ' +
          "<span class=dateTime data-utc=#{dateUTC}>#{date}</span> " +
          "<span class='postNum desktop'>" +
            "<a href=#{"/#{boardID}/res/#{threadID}#p#{postID}"} title='Highlight this post'>No.</a>" +
            "<a href='#{
              if g.VIEW is 'thread' and g.THREADID is +threadID
                "javascript:quote(#{postID})"
              else
                "/#{boardID}/res/#{threadID}#q#{postID}"
              }' title='Quote this post'>#{postID}</a>" +
          '</span>' +
        '</div>' +

        (if isOP then '' else fileHTML) +

        "<blockquote class=postMessage id=m#{postID}>#{comment or ''}</blockquote> " +

      '</div>'

    for quote in $$ '.quotelink', container
      href = quote.getAttribute 'href'
      continue if href[0] is '/' # Cross-board quote, or board link
      quote.href = "/#{boardID}/res/#{href}" # Fix pathnames

    container

Get =
  threadExcerpt: (thread) ->
    {OP} = thread
    excerpt = OP.info.subject?.trim() or
      OP.info.comment.replace(/\n+/g, ' // ') or
      Conf['Anonymize'] and 'Anonymous' or
      $('.nameBlock', OP.nodes.info).textContent.trim()
    if excerpt.length > 70
      excerpt = "#{excerpt[...67]}..."
    "/#{thread.board}/ - #{excerpt}"
  postFromRoot: (root) ->
    link    = $ 'a[title="Highlight this post"]', root
    boardID = link.pathname.split('/')[1]
    postID  = link.hash[2..]
    index   = root.dataset.clone
    post    = g.posts["#{boardID}.#{postID}"]
    if index then post.clones[index] else post
  postFromNode: (root) ->
    Get.postFromRoot $.x 'ancestor::div[contains(@class,"postContainer")][1]', root
  contextFromLink: (quotelink) ->
    Get.postFromRoot $.x 'ancestor::div[parent::div[@class="thread"]][1]', quotelink
  postDataFromLink: (link) ->
    if link.hostname is 'boards.4chan.org'
      path     = link.pathname.split '/'
      boardID  = path[1]
      threadID = path[3]
      postID   = link.hash[2..]
    else # resurrected quote
      boardID  = link.dataset.boardid
      threadID = link.dataset.threadid or 0
      postID   = link.dataset.postid
    return {
      boardID:  boardID
      threadID: +threadID
      postID:   +postID
    }
  allQuotelinksLinkingTo: (post) ->
    # Get quotelinks & backlinks linking to the given post.
    quotelinks = []
    # First:
    #   In every posts,
    #   if it did quote this post,
    #   get all their backlinks.
    for ID, quoterPost of g.posts
      if post.fullID in quoterPost.quotes
        for quoterPost in [quoterPost].concat quoterPost.clones
          quotelinks.push.apply quotelinks, quoterPost.nodes.quotelinks
    # Second:
    #   If we have quote backlinks:
    #   in all posts this post quoted
    #   and their clones,
    #   get all of their backlinks.
    if Conf['Quote Backlinks']
      for quote in post.quotes
        continue unless quotedPost = g.posts[quote]
        for quotedPost in [quotedPost].concat quotedPost.clones
          quotelinks.push.apply quotelinks, [quotedPost.nodes.backlinks...]
    # Third:
    #   Filter out irrelevant quotelinks.
    quotelinks.filter (quotelink) ->
      {boardID, postID} = Get.postDataFromLink quotelink
      boardID is post.board.ID and postID is post.ID
  postClone: (boardID, threadID, postID, root, context) ->
    if post = g.posts["#{boardID}.#{postID}"]
      Get.insert post, root, context
      return

    root.textContent = "Loading post No.#{postID}..."
    if threadID
      $.cache "//api.4chan.org/#{boardID}/res/#{threadID}.json", ->
        Get.fetchedPost @, boardID, threadID, postID, root, context
    else if url = Redirect.post boardID, postID
      $.cache url, ->
        Get.archivedPost @, boardID, postID, root, context
  insert: (post, root, context) ->
    # Stop here if the container has been removed while loading.
    return unless root.parentNode
    clone = post.addClone context
    Main.callbackNodes Post, [clone]

    # Get rid of the side arrows.
    {nodes} = clone
    $.rmAll nodes.root
    $.add nodes.root, nodes.post

    $.rmAll root
    $.add root, nodes.root
  fetchedPost: (req, boardID, threadID, postID, root, context) ->
    # In case of multiple callbacks for the same request,
    # don't parse the same original post more than once.
    if post = g.posts["#{boardID}.#{postID}"]
      Get.insert post, root, context
      return

    {status} = req
    if status not in [200, 304]
      # The thread can die by the time we check a quote.
      if url = Redirect.post boardID, postID
        $.cache url, ->
          Get.archivedPost @, boardID, postID, root, context
      else
        $.addClass root, 'warning'
        root.textContent =
          if status is 404
            "Thread No.#{threadID} 404'd."
          else
            "Error #{req.statusText} (#{req.status})."
      return

    posts = JSON.parse(req.response).posts
    Build.spoilerRange[boardID] = posts[0].custom_spoiler
    for post in posts
      break if post.no is postID # we found it!
      if post.no > postID
        # The post can be deleted by the time we check a quote.
        if url = Redirect.post boardID, postID
          $.cache url, ->
            Get.archivedPost @, boardID, postID, root, context
        else
          $.addClass root, 'warning'
          root.textContent = "Post No.#{postID} was not found."
        return

    board = g.boards[boardID] or
      new Board boardID
    thread = g.threads["#{boardID}.#{threadID}"] or
      new Thread threadID, board
    post = new Post Build.postFromObject(post, boardID), thread, board
    Main.callbackNodes Post, [post]
    Get.insert post, root, context
  archivedPost: (req, boardID, postID, root, context) ->
    # In case of multiple callbacks for the same request,
    # don't parse the same original post more than once.
    if post = g.posts["#{boardID}.#{postID}"]
      Get.insert post, root, context
      return

    data = JSON.parse req.response
    if data.error
      $.addClass root, 'warning'
      root.textContent = data.error
      return

    # convert comment to html
    bq = $.el 'blockquote', textContent: data.comment # set this first to convert text to HTML entities
    # https://github.com/eksopl/fuuka/blob/master/Board/Yotsuba.pm#L413-452
    # https://github.com/eksopl/asagi/blob/master/src/main/java/net/easymodo/asagi/Yotsuba.java#L109-138
    bq.innerHTML = bq.innerHTML.replace ///
      \n
      | \[/?b\]
      | \[/?spoiler\]
      | \[/?code\]
      | \[/?moot\]
      | \[/?banned\]
      ///g, (text) ->
        switch text
          when '\n'
            '<br>'
          when '[b]'
            '<b>'
          when '[/b]'
            '</b>'
          when '[spoiler]'
            '<span class=spoiler>'
          when '[/spoiler]'
            '</span>'
          when '[code]'
            '<pre class=prettyprint>'
          when '[/code]'
            '</pre>'
          when '[moot]'
            '<div style="padding:5px;margin-left:.5em;border-color:#faa;border:2px dashed rgba(255,0,0,.1);border-radius:2px">'
          when '[/moot]'
            '</div>'
          when '[banned]'
            '<b style="color: red;">'
          when '[/banned]'
            '</b>'

    comment = bq.innerHTML
      # greentext
      .replace(/(^|>)(&gt;[^<$]*)(<|$)/g, '$1<span class=quote>$2</span>$3')
      # quotes
      .replace /((&gt;){2}(&gt;\/[a-z\d]+\/)?\d+)/g, '<span class=deadlink>$1</span>'

    threadID = data.thread_num
    o =
      # id
      postID:   "#{postID}"
      threadID: "#{threadID}"
      boardID:  boardID
      # info
      name:     data.name_processed
      capcode:  switch data.capcode
        when 'M' then 'mod'
        when 'A' then 'admin'
        when 'D' then 'developer'
      tripcode: data.trip
      uniqueID: data.poster_hash
      email:    if data.email then encodeURI data.email else ''
      subject:  data.title_processed
      flagCode: data.poster_country
      flagName: data.poster_country_name_processed
      date:     data.fourchan_date
      dateUTC:  data.timestamp
      comment:  comment
      # file
    if data.media?.media_filename
      o.file =
        name:      data.media.media_filename_processed
        timestamp: data.media.media_orig
        url:       data.media.media_link or data.media.remote_media_link
        height:    data.media.media_h
        width:     data.media.media_w
        MD5:       data.media.media_hash
        size:      data.media.media_size
        turl:      data.media.thumb_link or "//thumbs.4chan.org/#{boardID}/thumb/#{data.media.preview_orig}"
        theight:   data.media.preview_h
        twidth:    data.media.preview_w
        isSpoiler: data.media.spoiler is '1'

    board = g.boards[boardID] or
      new Board boardID
    thread = g.threads["#{boardID}.#{threadID}"] or
      new Thread threadID, board
    post = new Post Build.post(o, true), thread, board,
      isArchived: true
    Main.callbackNodes Post, [post]
    Get.insert post, root, context

Quotify =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Resurrect Quotes']

    Post::callbacks.push
      name: 'Resurrect Quotes'
      cb:   @node
  node: ->
    for deadlink in $$ '.deadlink', @nodes.comment
      if @isClone
        if $.hasClass deadlink, 'quotelink'
          @nodes.quotelinks.push deadlink
      else
        Quotify.parseDeadlink.call @, deadlink
    return

  parseDeadlink: (deadlink) ->
    if deadlink.parentNode.className is 'prettyprint'
      # Don't quotify deadlinks inside code tags,
      # un-`span` them.
      $.replace deadlink, [deadlink.childNodes...]
      return

    quote = deadlink.textContent
    return unless postID = quote.match(/\d+$/)?[0]
    boardID = if m = quote.match /^>>>\/([a-z\d]+)/
      m[1]
    else
      @board.ID
    quoteID = "#{boardID}.#{postID}"

    if post = g.posts[quoteID]
      unless post.isDead
        # Don't (Dead) when quotifying in an archived post,
        # and we know the post still exists.
        a = $.el 'a',
          href:        "/#{boardID}/#{post.thread}/res/#p#{postID}"
          className:   'quotelink'
          textContent: quote
      else
        # Replace the .deadlink span if we can redirect.
        a = $.el 'a',
          href:        "/#{boardID}/#{post.thread}/res/#p#{postID}"
          className:   'quotelink deadlink'
          target:      '_blank'
          textContent: "#{quote}\u00A0(Dead)"
        a.setAttribute 'data-boardid',  boardID
        a.setAttribute 'data-threadid', post.thread.ID
        a.setAttribute 'data-postid',   postID
    else if redirect = Redirect.to {boardID, threadID: 0, postID}
      # Replace the .deadlink span if we can redirect.
      a = $.el 'a',
        href:        redirect
        className:   'deadlink'
        target:      '_blank'
        textContent: "#{quote}\u00A0(Dead)"
      if Redirect.post boardID, postID
        # Make it function as a normal quote if we can fetch the post.
        $.addClass a,  'quotelink'
        a.setAttribute 'data-boardid', boardID
        a.setAttribute 'data-postid',  postID

    unless quoteID in @quotes
      @quotes.push quoteID

    unless a
      deadlink.textContent = "#{quote}\u00A0(Dead)"
      return

    $.replace deadlink, a
    if $.hasClass a, 'quotelink'
      @nodes.quotelinks.push a

QuoteInline =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Quote Inlining']

    Post::callbacks.push
      name: 'Quote Inlining'
      cb:   @node
  node: ->
    for link in @nodes.quotelinks.concat [@nodes.backlinks...]
      $.on link, 'click', QuoteInline.toggle
    return
  toggle: (e) ->
    return if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey or e.button isnt 0
    e.preventDefault()
    {boardID, threadID, postID} = Get.postDataFromLink @
    context = Get.contextFromLink @
    if $.hasClass @, 'inlined'
      QuoteInline.rm @, boardID, threadID, postID, context
    else
      return if $.x "ancestor::div[@id='p#{postID}']", @
      QuoteInline.add @, boardID, threadID, postID, context
    @classList.toggle 'inlined'

  findRoot: (quotelink, isBacklink) ->
    if isBacklink
      quotelink.parentNode.parentNode
    else
      $.x 'ancestor-or-self::*[parent::blockquote][1]', quotelink
  add: (quotelink, boardID, threadID, postID, context) ->
    isBacklink = $.hasClass quotelink, 'backlink'
    inline = $.el 'div',
      id: "i#{postID}"
      className: 'inline'
    $.after QuoteInline.findRoot(quotelink, isBacklink), inline
    Get.postClone boardID, threadID, postID, inline, context

    return unless (post = g.posts["#{boardID}.#{postID}"]) and
      context.thread is post.thread

    # Hide forward post if it's a backlink of a post in this thread.
    # Will only unhide if there's no inlined backlinks of it anymore.
    if isBacklink and Conf['Forward Hiding']
      $.addClass post.nodes.root, 'forwarded'
      post.forwarded++ or post.forwarded = 1

    # Decrease the unread count if this post
    # is in the array of unread posts.
    return unless Unread.posts
    Unread.readSinglePost post

  rm: (quotelink, boardID, threadID, postID, context) ->
    isBacklink = $.hasClass quotelink, 'backlink'
    # Select the corresponding inlined quote, and remove it.
    root = QuoteInline.findRoot quotelink, isBacklink
    root = $.x "following-sibling::div[@id='i#{postID}'][1]", root
    $.rm root

    # Stop if it only contains text.
    return unless el = root.firstElementChild

    # Dereference clone.
    post = g.posts["#{boardID}.#{postID}"]
    post.rmClone el.dataset.clone

    # Decrease forward count and unhide.
    if Conf['Forward Hiding'] and
      isBacklink and
      context.thread is g.threads["#{boardID}.#{threadID}"] and
      not --post.forwarded
        delete post.forwarded
        $.rmClass post.nodes.root, 'forwarded'

    # Repeat.
    while inlined = $ '.inlined', el
      {boardID, threadID, postID} = Get.postDataFromLink inlined
      QuoteInline.rm inlined, boardID, threadID, postID, context
      $.rmClass inlined, 'inlined'
    return

QuotePreview =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Quote Previewing']

    Post::callbacks.push
      name: 'Quote Previewing'
      cb:   @node
  node: ->
    for link in @nodes.quotelinks.concat [@nodes.backlinks...]
      $.on link, 'mouseover', QuotePreview.mouseover
    return
  mouseover: (e) ->
    return if $.hasClass @, 'inlined'

    {boardID, threadID, postID} = Get.postDataFromLink @

    qp = $.el 'div',
      id: 'qp'
      className: 'dialog'
    $.add d.body, qp
    Get.postClone boardID, threadID, postID, qp, Get.contextFromLink @

    UI.hover
      root: @
      el: qp
      latestEvent: e
      endEvents: 'mouseout click'
      cb: QuotePreview.mouseout
      asapTest: -> qp.firstElementChild

    return unless origin = g.posts["#{boardID}.#{postID}"]

    if Conf['Quote Highlighting']
      posts = [origin].concat origin.clones
      # Remove the clone that's in the qp from the array.
      posts.pop()
      for post in posts
        $.addClass post.nodes.post, 'qphl'

    quoterID = $.x('ancestor::*[@id][1]', @).id.match(/\d+$/)[0]
    clone = Get.postFromRoot qp.firstChild
    for quote in clone.nodes.quotelinks.concat [clone.nodes.backlinks...]
      if quote.hash[2..] is quoterID
        $.addClass quote, 'forwardlink'
    return
  mouseout: ->
    # Stop if it only contains text.
    return unless root = @el.firstElementChild

    clone = Get.postFromRoot root
    post  = clone.origin
    post.rmClone root.dataset.clone

    return unless Conf['Quote Highlighting']
    for post in [post].concat post.clones
      $.rmClass post.nodes.post, 'qphl'
    return

QuoteBacklink =
  # Backlinks appending need to work for:
  #  - previous, same, and following posts.
  #  - existing and yet-to-exist posts.
  #  - newly fetched posts.
  #  - in copies.
  # XXX what about order for fetched posts?
  #
  # First callback creates backlinks and add them to relevant containers.
  # Second callback adds relevant containers into posts.
  # This is is so that fetched posts can get their backlinks,
  # and that as much backlinks are appended in the background as possible.
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Quote Backlinks']

    format = Conf['backlink'].replace /%id/g, "' + id + '"
    @funk  = Function 'id', "return '#{format}'"
    @containers = {}
    Post::callbacks.push
      name: 'Quote Backlinking Part 1'
      cb:   @firstNode
    Post::callbacks.push
      name: 'Quote Backlinking Part 2'
      cb:   @secondNode
  firstNode: ->
    return if @isClone or !@quotes.length
    a = $.el 'a',
      href: "/#{@board}/res/#{@thread}#p#{@}"
      className: if @isHidden then 'filtered backlink' else 'backlink'
      textContent: QuoteBacklink.funk @ID
    for quote in @quotes
      containers = [QuoteBacklink.getContainer quote]
      if (post = g.posts[quote]) and post.nodes.backlinkContainer
        # Don't add OP clones when OP Backlinks is disabled,
        # as the clones won't have the backlink containers.
        for clone in post.clones
          containers.push clone.nodes.backlinkContainer
      for container in containers
        link = a.cloneNode true
        if Conf['Quote Previewing']
          $.on link, 'mouseover', QuotePreview.mouseover
        if Conf['Quote Inlining']
          $.on link, 'click', QuoteInline.toggle
        $.add container, [$.tn(' '), link]
    return
  secondNode: ->
    if @isClone and (@origin.isReply or Conf['OP Backlinks'])
      @nodes.backlinkContainer = $ '.container', @nodes.info
      return
    # Don't backlink the OP.
    return unless @isReply or Conf['OP Backlinks']
    container = QuoteBacklink.getContainer @fullID
    @nodes.backlinkContainer = container
    $.add @nodes.info, container
  getContainer: (id) ->
    @containers[id] or=
      $.el 'span', className: 'container'

QuoteYou =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Mark Quotes of You'] or !Conf['Quick Reply']

    # \u00A0 is nbsp
    @text = '\u00A0(You)'
    Post::callbacks.push
      name: 'Mark Quotes of You'
      cb:   @node
  node: ->
    # Stop there if it's a clone.
    return if @isClone
    # Stop there if there's no quotes in that post.
    return unless (quotes = @quotes).length
    {quotelinks} = @nodes

    for quotelink in quotelinks
      if QR.db.get Get.postDataFromLink quotelink
        $.add quotelink, $.tn QuoteYou.text
    return

QuoteOP =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Mark OP Quotes']

    # \u00A0 is nbsp
    @text = '\u00A0(OP)'
    Post::callbacks.push
      name: 'Mark OP Quotes'
      cb:   @node
  node: ->
    # Stop there if it's a clone of a post in the same thread.
    return if @isClone and @thread is @context.thread
    # Stop there if there's no quotes in that post.
    return unless (quotes = @quotes).length
    {quotelinks} = @nodes

    # rm (OP) from cross-thread quotes.
    if @isClone and @thread.fullID in quotes
      for quotelink in quotelinks
        quotelink.textContent = quotelink.textContent.replace QuoteOP.text, ''

    op = (if @isClone then @context else @).thread.fullID
    # add (OP) to quotes quoting this context's OP.
    return unless op in quotes
    for quotelink in quotelinks
      {boardID, postID} = Get.postDataFromLink quotelink
      if "#{boardID}.#{postID}" is op
        $.add quotelink, $.tn QuoteOP.text
    return

QuoteCT =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Mark Cross-thread Quotes']

    # \u00A0 is nbsp
    @text = '\u00A0(Cross-thread)'
    Post::callbacks.push
      name: 'Mark Cross-thread Quotes'
      cb:   @node
  node: ->
    # Stop there if it's a clone of a post in the same thread.
    return if @isClone and @thread is @context.thread
    # Stop there if there's no quotes in that post.
    return unless (quotes = @quotes).length
    {quotelinks} = @nodes

    {board, thread} = if @isClone then @context else @
    for quotelink in quotelinks
      {boardID, threadID} = Get.postDataFromLink quotelink
      continue unless threadID # deadlink
      if @isClone
        quotelink.textContent = quotelink.textContent.replace QuoteCT.text, ''
      if boardID is @board.ID and threadID isnt thread.ID
        $.add quotelink, $.tn QuoteCT.text
    return

Anonymize =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Anonymize']

    Post::callbacks.push
      name: 'Anonymize'
      cb:   @node
  node: ->
    return if @info.capcode or @isClone
    {name, tripcode, email} = @nodes
    if @info.name isnt 'Anonymous'
      name.textContent = 'Anonymous'
    if tripcode
      $.rm tripcode
      delete @nodes.tripcode
    if @info.email
      if /sage/i.test @info.email
        email.href = 'mailto:sage'
      else
        $.replace email, name
        delete @nodes.email

Time =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Time Formatting']

    @funk = @createFunc Conf['time']
    Post::callbacks.push
      name: 'Time Formatting'
      cb:   @node
  node: ->
    return if @isClone
    @nodes.date.textContent = Time.funk Time, @info.date
  createFunc: (format) ->
    code = format.replace /%([A-Za-z])/g, (s, c) ->
      if c of Time.formatters
        "' + Time.formatters.#{c}.call(date) + '"
      else
        s
    Function 'Time', 'date', "return '#{code}'"
  day: [
    'Sunday'
    'Monday'
    'Tuesday'
    'Wednesday'
    'Thursday'
    'Friday'
    'Saturday'
  ]
  month: [
    'January'
    'February'
    'March'
    'April'
    'May'
    'June'
    'July'
    'August'
    'September'
    'October'
    'November'
    'December'
  ]
  zeroPad: (n) -> if n < 10 then "0#{n}" else n
  formatters:
    a: -> Time.day[@getDay()][...3]
    A: -> Time.day[@getDay()]
    b: -> Time.month[@getMonth()][...3]
    B: -> Time.month[@getMonth()]
    d: -> Time.zeroPad @getDate()
    e: -> @getDate()
    H: -> Time.zeroPad @getHours()
    I: -> Time.zeroPad @getHours() % 12 or 12
    k: -> @getHours()
    l: -> @getHours() % 12 or 12
    m: -> Time.zeroPad @getMonth() + 1
    M: -> Time.zeroPad @getMinutes()
    p: -> if @getHours() < 12 then 'AM' else 'PM'
    P: -> if @getHours() < 12 then 'am' else 'pm'
    S: -> Time.zeroPad @getSeconds()
    y: -> @getFullYear() - 2000

RelativeDates =
  INTERVAL: $.MINUTE / 2
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Relative Post Dates']

    # Flush when page becomes visible again or when the thread updates.
    $.on d, 'visibilitychange ThreadUpdate', @flush

    # Start the timeout.
    @flush()

    Post::callbacks.push
      name: 'Relative Post Dates'
      cb:   @node
  node: ->
    return if @isClone

    # Show original absolute time as tooltip so users can still know exact times
    # Since "Time Formatting" runs its `node` before us, the title tooltip will
    # pick up the user-formatted time instead of 4chan time when enabled.
    dateEl = @nodes.date
    dateEl.title = dateEl.textContent

    RelativeDates.setUpdate @

  # diff is milliseconds from now.
  relative: (diff, now, date) ->
    unit = if (number = (diff / $.DAY)) >= 1
      years  = now.getYear()  - date.getYear()
      months = now.getMonth() - date.getMonth()
      days   = now.getDate()  - date.getDate()
      if years > 1
        number = years - (months < 0 or months is 0 and days < 0)
        'year'
      else if years is 1 and (months > 0 or months is 0 and days >= 0)
        number = years
        'year'
      else if (months = (months+12)%12 ) > 1
        number = months - (days < 0)
        'month'
      else if months is 1 and days >= 0
        number = months
        'month'
      else
        'day'
    else if (number = (diff / $.HOUR)) >= 1
      'hour'
    else if (number = (diff / $.MINUTE)) >= 1
      'minute'
    else
      # prevent "-1 seconds ago"
      number = Math.max(0, diff) / $.SECOND
      'second'

    rounded = Math.round number
    unit += 's' if rounded isnt 1 # pluralize

    "#{rounded} #{unit} ago"

  # Changing all relative dates as soon as possible incurs many annoying
  # redraws and scroll stuttering. Thus, sacrifice accuracy for UX/CPU economy,
  # and perform redraws when the DOM is otherwise being manipulated (and scroll
  # stuttering won't be noticed), falling back to INTERVAL while the page
  # is visible.
  #
  # Each individual dateTime element will add its update() function to the stale list
  # when it is to be called.
  stale: []
  flush: ->
    # No point in changing the dates until the user sees them.
    return if d.hidden

    now = new Date()
    update now for update in RelativeDates.stale
    RelativeDates.stale = []

    # Reset automatic flush.
    clearTimeout RelativeDates.timeout
    RelativeDates.timeout = setTimeout RelativeDates.flush, RelativeDates.INTERVAL

  # Create function `update()`, closed over post, that, when called
  # from `flush()`, updates the elements, and re-calls `setOwnTimeout()` to
  # re-add `update()` to the stale list later.
  setUpdate: (post) ->
    setOwnTimeout = (diff) ->
      delay = if diff < $.MINUTE
        $.SECOND - (diff + $.SECOND / 2) % $.SECOND
      else if diff < $.HOUR
        $.MINUTE - (diff + $.MINUTE / 2) % $.MINUTE
      else if diff < $.DAY
        $.HOUR - (diff + $.HOUR / 2) % $.HOUR
      else
        $.DAY - (diff + $.DAY / 2) % $.DAY
      setTimeout markStale, delay

    update = (now) ->
      {date} = post.info
      diff = now - date
      relative = RelativeDates.relative diff, now, date
      for singlePost in [post].concat post.clones
        singlePost.nodes.date.firstChild.textContent = relative
      setOwnTimeout diff

    markStale = -> RelativeDates.stale.push update

    # Kick off initial timeout.
    update new Date()

FileInfo =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['File Info Formatting']

    @funk = @createFunc Conf['fileInfo']
    Post::callbacks.push
      name: 'File Info Formatting'
      cb:   @node
  node: ->
    return if !@file or @isClone
    @file.text.innerHTML = FileInfo.funk FileInfo, @
  createFunc: (format) ->
    code = format.replace /%(.)/g, (s, c) ->
      if c of FileInfo.formatters
        "' + FileInfo.formatters.#{c}.call(post) + '"
      else
        s
    Function 'FileInfo', 'post', "return '#{code}'"
  convertUnit: (size, unit) ->
    if unit is 'B'
      return "#{size.toFixed()} Bytes"
    i = 1 + ['KB', 'MB'].indexOf unit
    size /= 1024 while i--
    size =
      if unit is 'MB'
        Math.round(size * 100) / 100
      else
        size.toFixed()
    "#{size} #{unit}"
  escape: (name) ->
    name.replace /<|>/g, (c) ->
      c is '<' and '&lt;' or '&gt;'
  formatters:
    t: -> @file.URL.match(/\d+\..+$/)[0]
    T: -> "<a href=#{@file.URL} target=_blank>#{FileInfo.formatters.t.call @}</a>"
    l: -> "<a href=#{@file.URL} target=_blank>#{FileInfo.formatters.n.call @}</a>"
    L: -> "<a href=#{@file.URL} target=_blank>#{FileInfo.formatters.N.call @}</a>"
    n: ->
      fullname  = @file.name
      shortname = Build.shortFilename @file.name, @isReply
      if fullname is shortname
        FileInfo.escape fullname
      else
        "<span class=fntrunc>#{FileInfo.escape shortname}</span><span class=fnfull>#{FileInfo.escape fullname}</span>"
    N: -> FileInfo.escape @file.name
    p: -> if @file.isSpoiler then 'Spoiler, ' else ''
    s: -> @file.size
    B: -> FileInfo.convertUnit @file.sizeInBytes, 'B'
    K: -> FileInfo.convertUnit @file.sizeInBytes, 'KB'
    M: -> FileInfo.convertUnit @file.sizeInBytes, 'MB'
    r: -> if @file.isImage then @file.dimensions else 'PDF'

Sauce =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Sauce']

    links = []
    for link in Conf['sauces'].split '\n'
      continue if link[0] is '#'
      links.push @createSauceLink link.trim()
    return unless links.length
    @links = links
    @link  = $.el 'a', target: '_blank'
    Post::callbacks.push
      name: 'Sauce'
      cb:   @node
  createSauceLink: (link) ->
    link = link.replace /%(T?URL|MD5|board)/g, (parameter) ->
      switch parameter
        when '%TURL'
          "' + encodeURIComponent(post.file.thumbURL) + '"
        when '%URL'
          "' + encodeURIComponent(post.file.URL) + '"
        when '%MD5'
          "' + encodeURIComponent(post.file.MD5) + '"
        when '%board'
          "' + encodeURIComponent(post.board) + '"
        else
          parameter
    text = if m = link.match(/;text:(.+)$/) then m[1] else link.match(/(\w+)\.\w+\//)[1]
    link = link.replace /;text:.+$/, ''
    Function 'post', 'a', """
      a.href = '#{link}';
      a.textContent = '#{text}';
      return a;
    """
  node: ->
    return if @isClone or !@file
    nodes = []
    for link in Sauce.links
      # \u00A0 is nbsp
      nodes.push $.tn('\u00A0'), link @, Sauce.link.cloneNode true
    $.add @file.info, nodes

ImageExpand =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Image Expansion']

    @EAI = $.el 'a',
      className: 'expand-all-shortcut'
      textContent: 'EAI'
      title: 'Expand All Images'
      href: 'javascript:;'
    $.on @EAI, 'click', ImageExpand.cb.toggleAll
    Header.addShortcut @EAI

    Post::callbacks.push
      name: 'Image Expansion'
      cb:   @node
  node: ->
    return unless @file?.isImage
    {thumb} = @file
    $.on thumb.parentNode, 'click', ImageExpand.cb.toggle
    if @isClone and $.hasClass thumb, 'expanding'
      # If we clone a post where the image is still loading,
      # make it loading in the clone too.
      ImageExpand.contract @
      ImageExpand.expand @
      return
    if ImageExpand.on and !@isHidden
      ImageExpand.expand @
  cb:
    toggle: (e) ->
      return if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey or e.button isnt 0
      e.preventDefault()
      ImageExpand.toggle Get.postFromNode @
    toggleAll: ->
      $.event 'CloseMenu'
      if ImageExpand.on = $.hasClass ImageExpand.EAI, 'expand-all-shortcut'
        ImageExpand.EAI.className = 'contract-all-shortcut'
        ImageExpand.EAI.title     = 'Contract All Images'
        func = ImageExpand.expand
      else
        ImageExpand.EAI.className = 'expand-all-shortcut'
        ImageExpand.EAI.title     = 'Expand All Images'
        func = ImageExpand.contract
      for ID, post of g.posts
        for post in [post].concat post.clones
          {file} = post
          continue unless file and file.isImage and doc.contains post.nodes.root
          if ImageExpand.on and
            (!Conf['Expand spoilers'] and file.isSpoiler or
            Conf['Expand from here'] and file.thumb.getBoundingClientRect().top < 0)
              continue
          $.queueTask func, post
      return
    setFitness: ->
      {checked} = @
      (if checked then $.addClass else $.rmClass) doc, @name.toLowerCase().replace /\s+/g, '-'
      return unless @name is 'Fit height'
      if checked
        $.on window, 'resize', ImageExpand.resize
        unless ImageExpand.style
          ImageExpand.style = $.addStyle null
        ImageExpand.resize()
      else
        $.off window, 'resize', ImageExpand.resize

  toggle: (post) ->
    {thumb} = post.file
    unless post.file.isExpanded or $.hasClass thumb, 'expanding'
      ImageExpand.expand post
      return
    ImageExpand.contract post
    rect = post.nodes.root.getBoundingClientRect()
    return unless rect.top <= 0 or rect.left <= 0
    # Scroll back to the thumbnail when contracting the image
    # to avoid being left miles away from the relevant post.
    {top} = rect
    unless Conf['Bottom header']
      headRect = Header.toggle.getBoundingClientRect()
      top += - headRect.top - headRect.height
    root = <% if (type === 'crx') { %>d.body<% } else { %>doc<% } %>
    root.scrollTop += top if rect.top  < 0
    root.scrollLeft = 0   if rect.left < 0

  contract: (post) ->
    $.rmClass post.nodes.root, 'expanded-image'
    $.rmClass post.file.thumb, 'expanding'
    post.file.isExpanded = false

  expand: (post, src) ->
    # Do not expand images of hidden/filtered replies, or already expanded pictures.
    {thumb} = post.file
    return if post.isHidden or post.file.isExpanded or $.hasClass thumb, 'expanding'
    $.addClass thumb, 'expanding'
    if post.file.fullImage
      # Expand already-loaded/ing picture.
      $.asap (-> post.file.fullImage.naturalHeight), ->
        ImageExpand.completeExpand post
      return
    post.file.fullImage = img = $.el 'img',
      className: 'full-image'
      src: src or post.file.URL
    $.on img, 'error', ImageExpand.error
    $.asap (-> post.file.fullImage.naturalHeight), ->
      ImageExpand.completeExpand post
    $.after thumb, img

  completeExpand: (post) ->
    {thumb} = post.file
    return unless $.hasClass thumb, 'expanding' # contracted before the image loaded
    post.file.isExpanded = true
    unless post.nodes.root.parentNode
      # Image might start/finish loading before the post is inserted.
      # Don't scroll when it's expanded in a QP for example.
      $.addClass post.nodes.root, 'expanded-image'
      $.rmClass  post.file.thumb, 'expanding'
      return
    prev = post.nodes.root.getBoundingClientRect()
    $.queueTask ->
      $.addClass post.nodes.root, 'expanded-image'
      $.rmClass  post.file.thumb, 'expanding'
      return unless prev.top + prev.height <= 0
      root = <% if (type === 'crx') { %>d.body<% } else { %>doc<% } %>
      curr = post.nodes.root.getBoundingClientRect()
      root.scrollTop += curr.height - prev.height + curr.top - prev.top

  error: ->
    post = Get.postFromNode @
    $.rm @
    delete post.file.fullImage
    # Images can error:
    #  - before the image started loading.
    #  - after the image started loading.
    unless $.hasClass(post.file.thumb, 'expanding') or $.hasClass post.nodes.root, 'expanded-image'
      # Don't try to re-expend if it was already contracted.
      return
    ImageExpand.contract post

    src = @src.split '/'
    if src[2] is 'images.4chan.org'
      if URL = Redirect.image src[3], src[5]
        setTimeout ImageExpand.expand, 10000, post, URL
        return
      if g.DEAD or post.isDead or post.file.isDead
        return

    timeoutID = setTimeout ImageExpand.expand, 10000, post
    # XXX CORS for images.4chan.org WHEN?
    $.ajax "//api.4chan.org/#{post.board}/res/#{post.thread}.json", onload: ->
      return if @status isnt 200
      for postObj in JSON.parse(@response).posts
        break if postObj.no is post.ID
      if postObj.no isnt post.ID
        clearTimeout timeoutID
        post.kill()
      else if postObj.filedeleted
        clearTimeout timeoutID
        post.kill true

  menu:
    init: ->
      return if g.VIEW is 'catalog' or !Conf['Image Expansion']

      el = $.el 'span',
        textContent: 'Image Expansion'
        className: 'image-expansion-link'

      {createSubEntry} = ImageExpand.menu
      subEntries = []
      for key, conf of Config.imageExpansion
        subEntries.push createSubEntry key, conf

      $.event 'AddMenuEntry',
        type: 'header'
        el: el
        order: 80
        subEntries: subEntries

    createSubEntry: (type, config) ->
      label = $.el 'label',
        innerHTML: "<input type=checkbox name='#{type}'> #{type}"
      input = label.firstElementChild
      if type in ['Fit width', 'Fit height']
        $.on input, 'change', ImageExpand.cb.setFitness
      if config
        label.title   = config[1]
        input.checked = Conf[type]
        $.event 'change', null, input
        $.on input, 'change', $.cb.checked
      el: label

  resize: ->
    ImageExpand.style.textContent = ":root.fit-height .full-image {max-height:#{doc.clientHeight}px}"

RevealSpoilers =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Reveal Spoilers']

    Post::callbacks.push
      name: 'Reveal Spoilers'
      cb:   @node
  node: ->
    return if @isClone or !@file?.isSpoiler
    {thumb} = @file
    thumb.removeAttribute 'style'
    thumb.src = @file.thumbURL

AutoGIF =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Auto-GIF'] or g.BOARD.ID in ['gif', 'wsg']

    Post::callbacks.push
      name: 'Auto-GIF'
      cb:   @node
  node: ->
    return if @isClone or @isHidden or @thread.isHidden or !@file?.isImage
    {thumb, URL} = @file
    return unless /gif$/.test(URL) and !/spoiler/.test thumb.src
    if @file.isSpoiler
      # Revealed spoilers do not have height/width set, this fixes auto-gifs dimensions.
      {style} = thumb
      style.maxHeight = style.maxWidth = if @isReply then '125px' else '250px'
    gif = $.el 'img'
    $.on gif, 'load', ->
      # Replace the thumbnail once the GIF has finished loading.
      thumb.src = URL
    gif.src = URL

ImageHover =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Image Hover']

    Post::callbacks.push
      name: 'Image Hover'
      cb:   @node
  node: ->
    return unless @file?.isImage
    $.on @file.thumb, 'mouseover', ImageHover.mouseover
  mouseover: (e) ->
    post = Get.postFromNode @
    el = $.el 'img',
      id: 'ihover'
      src: post.file.URL
    el.setAttribute 'data-fullid', post.fullID
    $.add d.body, el
    UI.hover
      root: @
      el: el
      latestEvent: e
      endEvents: 'mouseout click'
      asapTest: -> el.naturalHeight
    $.on el, 'error', ImageHover.error
  error: ->
    return unless doc.contains @
    post = g.posts[@dataset.fullid]

    src = @src.split '/'
    if src[2] is 'images.4chan.org'
      if URL = Redirect.image src[3], src[5].replace /\?.+$/, ''
        @src = URL
        return
      if g.DEAD or post.isDead or post.file.isDead
        return

    timeoutID = setTimeout (=> @src = post.file.URL + '?' + Date.now()), 3000
    # XXX CORS for images.4chan.org WHEN?
    $.ajax "//api.4chan.org/#{post.board}/res/#{post.thread}.json", onload: ->
      return if @status isnt 200
      for postObj in JSON.parse(@response).posts
        break if postObj.no is post.ID
      if postObj.no isnt post.ID
        clearTimeout timeoutID
        post.kill()
      else if postObj.filedeleted
        clearTimeout timeoutID
        post.kill true

ExpandComment =
  init: ->
    return if g.VIEW isnt 'index' or !Conf['Comment Expansion']

    Post::callbacks.push
      name: 'Comment Expansion'
      cb:   @node
  node: ->
    if a = $ '.abbr > a', @nodes.comment
      $.on a, 'click', ExpandComment.cb
  cb: (e) ->
    e.preventDefault()
    post = Get.postFromNode @
    ExpandComment.expand post
  expand: (post) ->
    if post.nodes.longComment and !post.nodes.longComment.parentNode
      $.replace post.nodes.shortComment, post.nodes.longComment
      post.nodes.comment = post.nodes.longComment
      return
    return unless a = $ '.abbr > a', post.nodes.comment
    a.textContent = "Post No.#{post} Loading..."
    $.cache "//api.4chan.org#{a.pathname}.json", -> ExpandComment.parse @, a, post
  contract: (post) ->
    return unless post.nodes.shortComment
    a = $ '.abbr > a', post.nodes.shortComment
    a.textContent = 'here'
    $.replace post.nodes.longComment, post.nodes.shortComment
    post.nodes.comment = post.nodes.shortComment
  parse: (req, a, post) ->
    {status} = req
    if status not in [200, 304]
      a.textContent = "Error #{req.statusText} (#{status})"
      return

    posts = JSON.parse(req.response).posts
    if spoilerRange = posts[0].custom_spoiler
      Build.spoilerRange[g.BOARD] = spoilerRange

    for postObj in posts
      break if postObj.no is post.ID
    if postObj.no isnt post.ID
      a.textContent = "Post No.#{post} not found."
      return

    {comment} = post.nodes
    clone = comment.cloneNode false
    clone.innerHTML = postObj.com
    for quote in $$ '.quotelink', clone
      href = quote.getAttribute 'href'
      continue if href[0] is '/' # Cross-board quote, or board link
      quote.href = "/#{post.board}/res/#{href}" # Fix pathnames
    post.nodes.shortComment = comment
    $.replace comment, clone
    post.nodes.comment = post.nodes.longComment = clone
    post.parseComment()
    post.parseQuotes()
    if Conf['Resurrect Quotes']
      Quotify.node.call      post
    if Conf['Quote Previewing']
      QuotePreview.node.call post
    if Conf['Quote Inlining']
      QuoteInline.node.call  post
    if Conf['Mark OP Quotes']
      QuoteOP.node.call      post
    if Conf['Mark Cross-thread Quotes']
      QuoteCT.node.call      post
    if g.BOARD.ID is 'g'
      Fourchan.code.call     post
    if g.BOARD.ID is 'sci'
      Fourchan.math.call     post

ExpandThread =
  init: ->
    return if g.VIEW isnt 'index' or !Conf['Thread Expansion']

    Thread::callbacks.push
      name: 'Thread Expansion'
      cb:   @node
  node: ->
    return unless span = $ '.summary', @OP.nodes.root.parentNode
    a = $.el 'a',
      textContent: "+ #{span.textContent}"
      className: 'summary'
      href: 'javascript:;'
    $.on a, 'click', ExpandThread.cbToggle
    $.replace span, a

  cbToggle: ->
    op = Get.postFromRoot @previousElementSibling
    ExpandThread.toggle op.thread

  toggle: (thread) ->
    threadRoot = thread.OP.nodes.root.parentNode
    a = $ '.summary', threadRoot

    switch thread.isExpanded
      when false, undefined
        thread.isExpanded = 'loading'
        for post in $$ '.thread > .postContainer', threadRoot
          ExpandComment.expand Get.postFromRoot post
        unless a
          thread.isExpanded = true
          return
        thread.isExpanded = 'loading'
        a.textContent = a.textContent.replace '+', '× Loading...'
        $.cache "//api.4chan.org/#{thread.board}/res/#{thread}.json", ->
          ExpandThread.parse @, thread, a

      when 'loading'
        thread.isExpanded = false
        return unless a
        a.textContent = a.textContent.replace '× Loading...', '+'

      when true
        thread.isExpanded = false
        if a
          a.textContent = a.textContent.replace '-', '+'
          #goddamit moot
          num = if thread.isSticky
            1
          else switch g.BOARD.ID
            # XXX boards config
            when 'b', 'vg', 'q' then 3
            when 't' then 1
            else 5
          replies = $$('.thread > .replyContainer', threadRoot)[...-num]
          for reply in replies
            if Conf['Quote Inlining']
              # rm clones
              inlined.click() while inlined = $ '.inlined', reply
            $.rm reply
        for post in $$ '.thread > .postContainer', threadRoot
          ExpandComment.contract Get.postFromRoot post
    return

  parse: (req, thread, a) ->
    return if a.textContent[0] is '+'
    {status} = req
    if status not in [200, 304]
      a.textContent = "Error #{req.statusText} (#{status})"
      $.off a, 'click', ExpandThread.cb.toggle
      return

    thread.isExpanded = true
    a.textContent = a.textContent.replace '× Loading...', '-'

    posts = JSON.parse(req.response).posts
    if spoilerRange = posts[0].custom_spoiler
      Build.spoilerRange[g.BOARD] = spoilerRange

    replies  = posts[1..]
    posts    = []
    nodes    = []
    for reply in replies
      if post = thread.posts[reply.no]
        nodes.push post.nodes.root
        continue
      node = Build.postFromObject reply, thread.board
      post = new Post node, thread, thread.board
      link = $ 'a[title="Highlight this post"]', node
      link.href = "res/#{thread}#p#{post}"
      link.nextSibling.href = "res/#{thread}#q#{post}"
      posts.push post
      nodes.push node
    Main.callbackNodes Post, posts
    $.after a, nodes

    # Enable 4chan features.
    if Conf['Enable 4chan\'s Extension']
      $.globalEval "Parser.parseThread(#{thread.ID}, 1, #{nodes.length})"
    else
      Fourchan.parseThread thread.ID, 1, nodes.length

ThreadExcerpt =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Thread Excerpt']

    Thread::callbacks.push
      name: 'Thread Excerpt'
      cb:   @node
  node: ->
    d.title = Get.threadExcerpt @

Unread =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Unread Count'] and !Conf['Unread Tab Icon']

    @db = new DataBoard 'lastReadPosts', @sync
    @hr = $.el 'hr',
      id: 'unread-line'
    @posts = []
    @postsQuotingYou = []

    Thread::callbacks.push
      name: 'Unread'
      cb:   @node

  node: ->
    Unread.thread = @
    Unread.title  = d.title
    posts = []
    for ID, post of @posts
      posts.push post if post.isReply
    Unread.lastReadPost = Unread.db.get
      boardID: @board.ID
      threadID: @ID
      defaultValue: 0
    Unread.addPosts posts
    $.on d, 'ThreadUpdate',            Unread.onUpdate
    $.on d, 'scroll visibilitychange', Unread.read
    $.on d, 'visibilitychange',        Unread.setLine if Conf['Unread Line']
    $.on window, 'load',               Unread.scroll  if Conf['Scroll to Last Read Post']

  scroll: ->
    # Let the header's onload callback handle it.
    return if (hash = location.hash.match /\d+/) and hash[0] of Unread.thread.posts
    if Unread.posts.length
      # Scroll to before the first unread post.
      while root = $.x 'preceding-sibling::div[contains(@class,"postContainer")][1]', Unread.posts[0].nodes.root
        break unless (Get.postFromRoot root).isHidden
      root.scrollIntoView false
      return
    # Scroll to the last read post.
    posts = Object.keys Unread.thread.posts
    Header.scrollToPost Unread.thread.posts[posts[posts.length - 1]].nodes.root

  sync: ->
    lastReadPost = Unread.db.get
      boardID: Unread.thread.board.ID
      threadID: Unread.thread.ID
      defaultValue: 0
    return unless Unread.lastReadPost < lastReadPost
    Unread.lastReadPost = lastReadPost
    Unread.readArray Unread.posts
    Unread.readArray Unread.postsQuotingYou
    Unread.setLine()
    Unread.update()

  addPosts: (newPosts) ->
    for post in newPosts
      {ID} = post
      if ID <= Unread.lastReadPost or post.isHidden
        continue
      if QR.db
        data =
          boardID:  post.board.ID
          threadID: post.thread.ID
          postID:   post.ID
        continue if QR.db.get data
      Unread.posts.push post
      Unread.addPostQuotingYou post
    if Conf['Unread Line']
      # Force line on visible threads if there were no unread posts previously.
      Unread.setLine Unread.posts[0] in newPosts
    Unread.read()
    Unread.update()

  addPostQuotingYou: (post) ->
    return unless QR.db
    for quotelink in post.nodes.quotelinks
      if QR.db.get Get.postDataFromLink quotelink
        Unread.postsQuotingYou.push post
    return

  onUpdate: (e) ->
    if e.detail[404]
      Unread.update()
    else
      Unread.addPosts e.detail.newPosts

  readSinglePost: (post) ->
    return if (i = Unread.posts.indexOf post) is -1
    Unread.posts.splice i, 1
    if i is 0
      Unread.lastReadPost = post.ID
      Unread.saveLastReadPost()
    if (i = Unread.postsQuotingYou.indexOf post) isnt -1
      Unread.postsQuotingYou.splice i, 1
    Unread.update()

  readArray: (arr) ->
    for post, i in arr
      break if post.ID > Unread.lastReadPost
    arr.splice 0, i

  read: (e) ->
    return if d.hidden or !Unread.posts.length
    height = doc.clientHeight
    for post, i in Unread.posts
      {bottom} = post.nodes.root.getBoundingClientRect()
      break if bottom > height # post is not completely read
    return unless i

    Unread.lastReadPost = Unread.posts[i - 1].ID
    Unread.saveLastReadPost()
    Unread.posts.splice 0, i
    Unread.readArray Unread.postsQuotingYou
    Unread.update() if e

  saveLastReadPost: ->
    Unread.db.set
      boardID:  Unread.thread.board.ID
      threadID: Unread.thread.ID
      val: Unread.lastReadPost

  setLine: (force) ->
    return unless d.hidden or force is true
    if post = Unread.posts[0]
      {root} = post.nodes
      if root isnt $ '.thread > .replyContainer', root.parentNode # not the first reply
        $.before root, Unread.hr
    else
      $.rm Unread.hr

  update: <% if (type === 'crx') { %>(dontrepeat) <% } %>->
    count = Unread.posts.length

    if Conf['Unread Count']
      d.title = "#{if count or !Conf['Hide Unread Count at (0)'] then "(#{count}) " else ''}#{if g.DEAD then "/#{g.BOARD}/ - 404" else "#{Unread.title}"}"
      <% if (type === 'crx') { %>
      # XXX Chrome bug where it doesn't always update the tab title.
      # crbug.com/124381
      # Call it one second later,
      # but don't display outdated unread count.
      unless dontrepeat
        setTimeout ->
          d.title = ''
          Unread.update true
        , $.SECOND
      <% } %>

    return unless Conf['Unread Tab Icon']

    Favicon.el.href =
      if g.DEAD
        if Unread.postsQuotingYou.length
          Favicon.unreadDeadY
        else if count
          Favicon.unreadDead
        else
          Favicon.dead
      else
        if count
          if Unread.postsQuotingYou.length
            Favicon.unreadY
          else
            Favicon.unread
        else
          Favicon.default

    <% if (type !== 'crx') { %>
    # `favicon.href = href` doesn't work on Firefox.
    # `favicon.href = href` isn't enough on Opera.
    # Opera won't always update the favicon if the href didn't change.
    $.add d.head, Favicon.el
    <% } %>

Favicon =
  init: ->
    $.ready ->
      Favicon.el      = $ 'link[rel="shortcut icon"]', d.head
      Favicon.el.type = 'image/x-icon'
      {href}          = Favicon.el
      Favicon.SFW     = /ws\.ico$/.test href
      Favicon.default = href
      Favicon.switch()

  switch: ->
    switch Conf['favicon']
      when 'ferongr'
        Favicon.unreadDead  = 'data:image/gif;base64,<%= grunt.file.read("img/favicons/ferongr/unreadDead.gif", {encoding: "base64"}) %>'
        Favicon.unreadDeadY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/ferongr/unreadDeadY.png", {encoding: "base64"}) %>'
        Favicon.unreadSFW   = 'data:image/gif;base64,<%= grunt.file.read("img/favicons/ferongr/unreadSFW.gif", {encoding: "base64"}) %>'
        Favicon.unreadSFWY  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/ferongr/unreadSFWY.png", {encoding: "base64"}) %>'
        Favicon.unreadNSFW  = 'data:image/gif;base64,<%= grunt.file.read("img/favicons/ferongr/unreadNSFW.gif", {encoding: "base64"}) %>'
        Favicon.unreadNSFWY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/ferongr/unreadNSFWY.png", {encoding: "base64"}) %>'
      when 'xat-'
        Favicon.unreadDead  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/xat-/unreadDead.png", {encoding: "base64"}) %>'
        Favicon.unreadDeadY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/xat-/unreadDeadY.png", {encoding: "base64"}) %>'
        Favicon.unreadSFW   = 'data:image/png;base64,<%= grunt.file.read("img/favicons/xat-/unreadSFW.png", {encoding: "base64"}) %>'
        Favicon.unreadSFWY  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/xat-/unreadSFWY.png", {encoding: "base64"}) %>'
        Favicon.unreadNSFW  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/xat-/unreadNSFW.png", {encoding: "base64"}) %>'
        Favicon.unreadNSFWY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/xat-/unreadNSFWY.png", {encoding: "base64"}) %>'
      when 'Mayhem'
        Favicon.unreadDead  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Mayhem/unreadDead.png", {encoding: "base64"}) %>'
        Favicon.unreadDeadY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Mayhem/unreadDeadY.png", {encoding: "base64"}) %>'
        Favicon.unreadSFW   = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Mayhem/unreadSFW.png", {encoding: "base64"}) %>'
        Favicon.unreadSFWY  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Mayhem/unreadSFWY.png", {encoding: "base64"}) %>'
        Favicon.unreadNSFW  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Mayhem/unreadNSFW.png", {encoding: "base64"}) %>'
        Favicon.unreadNSFWY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Mayhem/unreadNSFWY.png", {encoding: "base64"}) %>'
      when 'Original'
        Favicon.unreadDead  = 'data:image/gif;base64,<%= grunt.file.read("img/favicons/Original/unreadDead.gif", {encoding: "base64"}) %>'
        Favicon.unreadDeadY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Original/unreadDeadY.png", {encoding: "base64"}) %>'
        Favicon.unreadSFW   = 'data:image/gif;base64,<%= grunt.file.read("img/favicons/Original/unreadSFW.gif", {encoding: "base64"}) %>'
        Favicon.unreadSFWY  = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Original/unreadSFWY.png", {encoding: "base64"}) %>'
        Favicon.unreadNSFW  = 'data:image/gif;base64,<%= grunt.file.read("img/favicons/Original/unreadNSFW.gif", {encoding: "base64"}) %>'
        Favicon.unreadNSFWY = 'data:image/png;base64,<%= grunt.file.read("img/favicons/Original/unreadNSFWY.png", {encoding: "base64"}) %>'
    if Favicon.SFW
      Favicon.unread  = Favicon.unreadSFW
      Favicon.unreadY = Favicon.unreadSFWY
    else
      Favicon.unread  = Favicon.unreadNSFW
      Favicon.unreadY = Favicon.unreadNSFWY

  empty: 'data:image/gif;base64,<%= grunt.file.read("img/favicons/empty.gif", {encoding: "base64"}) %>'
  dead:  'data:image/gif;base64,<%= grunt.file.read("img/favicons/dead.gif",  {encoding: "base64"}) %>'


ThreadStats =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Thread Stats']
    @dialog = UI.dialog 'thread-stats', 'bottom: 0; left: 0;', """
      <div class=move><span id=post-count>0</span> / <span id=file-count>0</span></div>
      """

    @postCountEl = $ '#post-count', @dialog
    @fileCountEl = $ '#file-count', @dialog

    Thread::callbacks.push
      name: 'Thread Stats'
      cb:   @node
  node: ->
    postCount = 0
    fileCount = 0
    for ID, post of @posts
      postCount++
      fileCount++ if post.file
    ThreadStats.thread = @
    ThreadStats.update postCount, fileCount
    $.on d, 'ThreadUpdate', ThreadStats.onUpdate
    $.add d.body, ThreadStats.dialog
  onUpdate: (e) ->
    return if e.detail[404]
    {postCount, fileCount} = e.detail
    ThreadStats.update postCount, fileCount
  update: (postCount, fileCount) ->
    {thread, postCountEl, fileCountEl} = ThreadStats
    postCountEl.textContent = postCount
    fileCountEl.textContent = fileCount
    (if thread.postLimit and !thread.isSticky then $.addClass else $.rmClass) postCountEl, 'warning'
    (if thread.fileLimit and !thread.isSticky then $.addClass else $.rmClass) fileCountEl, 'warning'

ThreadUpdater =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Thread Updater']

    html = ''
    for name, conf of Config.updater.checkbox
      checked = if Conf[name] then 'checked' else ''
      html   += "<div><label title='#{conf[1]}'><input name='#{name}' type=checkbox #{checked}> #{name}</label></div>"

    html = """
      <div class=move><span id=update-status></span> <span id=update-timer></span></div>
      #{html}
      <div><label title='Controls whether *this* thread automatically updates or not'><input type=checkbox name='Auto Update This' #{if Conf['Auto Update'] then 'checked' else ''}> Auto Update This</label></div>
      <div><label><input type=number name=Interval class=field min=5 value=#{Conf['Interval']}> Refresh rate (s)</label></div>
      <div><input value='Update' type=button name='Update'></div>
      """

    @dialog = UI.dialog 'updater', 'bottom: 0; right: 0;', html
    @timer  = $ '#update-timer',  @dialog
    @status = $ '#update-status', @dialog
    @isUpdating = Conf['Auto Update']

    Thread::callbacks.push
      name: 'Thread Updater'
      cb:   @node

  node: ->
    ThreadUpdater.thread       = @
    ThreadUpdater.root         = @OP.nodes.root.parentNode
    ThreadUpdater.lastPost     = +ThreadUpdater.root.lastElementChild.id.match(/\d+/)[0]
    ThreadUpdater.outdateCount = 0
    ThreadUpdater.lastModified = '0'

    for input in $$ 'input', ThreadUpdater.dialog
      if input.type is 'checkbox'
        $.on input, 'change', $.cb.checked
      switch input.name
        when 'Scroll BG'
          $.on input, 'change', ThreadUpdater.cb.scrollBG
          ThreadUpdater.cb.scrollBG()
        when 'Auto Update This'
          $.off input, 'change', $.cb.checked
          $.on  input, 'change', ThreadUpdater.cb.autoUpdate
          $.event 'change', null, input
        when 'Interval'
          $.on input, 'change', ThreadUpdater.cb.interval
          ThreadUpdater.cb.interval.call input
        when 'Update'
          $.on input, 'click', ThreadUpdater.update

    $.on window, 'online offline',   ThreadUpdater.cb.online
    $.on d,      'QRPostSuccessful', ThreadUpdater.cb.post
    $.on d,      'visibilitychange', ThreadUpdater.cb.visibility

    ThreadUpdater.cb.online()
    $.add d.body, ThreadUpdater.dialog

  beep: 'data:audio/wav;base64,<%= grunt.file.read("audio/beep.wav", {encoding: "base64"}) %>'

  cb:
    online: ->
      if ThreadUpdater.online = navigator.onLine
        ThreadUpdater.outdateCount = 0
        ThreadUpdater.set 'timer', ThreadUpdater.getInterval()
        ThreadUpdater.update() if ThreadUpdater.isUpdating
        ThreadUpdater.set 'status', null, null
      else
        ThreadUpdater.set 'timer', null
        ThreadUpdater.set 'status', 'Offline', 'warning'
      ThreadUpdater.cb.autoUpdate()
    post: (e) ->
      return unless ThreadUpdater.isUpdating and e.detail.threadID is ThreadUpdater.thread.ID
      ThreadUpdater.outdateCount = 0
      setTimeout ThreadUpdater.update, 1000 if ThreadUpdater.seconds > 2
    visibility: ->
      return if d.hidden
      # Reset the counter when we focus this tab.
      ThreadUpdater.outdateCount = 0
      if ThreadUpdater.seconds > ThreadUpdater.interval
        ThreadUpdater.set 'timer', ThreadUpdater.getInterval()
    scrollBG: ->
      ThreadUpdater.scrollBG = if Conf['Scroll BG']
        -> true
      else
        -> not d.hidden
    autoUpdate: (e) ->
      ThreadUpdater.isUpdating = @checked if e
      if ThreadUpdater.isUpdating and ThreadUpdater.online
        ThreadUpdater.timeoutID = setTimeout ThreadUpdater.timeout, 1000
      else
        clearTimeout ThreadUpdater.timeoutID
    interval: (e) ->
      val = Math.max 5, parseInt @value, 10
      ThreadUpdater.interval = @value = val
      $.cb.value.call @ if e
    load: ->
      {req} = ThreadUpdater
      switch req.status
        when 200
          g.DEAD = false
          ThreadUpdater.parse JSON.parse(req.response).posts
          ThreadUpdater.lastModified = req.getResponseHeader 'Last-Modified'
          ThreadUpdater.set 'timer', ThreadUpdater.getInterval()
        when 404
          g.DEAD = true
          ThreadUpdater.set 'timer', null
          ThreadUpdater.set 'status', '404', 'warning'
          clearTimeout ThreadUpdater.timeoutID
          ThreadUpdater.thread.kill()
          $.event 'ThreadUpdate',
            404: true
            thread: ThreadUpdater.thread
        else
          ThreadUpdater.outdateCount++
          ThreadUpdater.set 'timer',  ThreadUpdater.getInterval()
          ###
          Status Code 304: Not modified
          By sending the `If-Modified-Since` header we get a proper status code, and no response.
          This saves bandwidth for both the user and the servers and avoid unnecessary computation.
          ###
          # XXX 304 -> 0 in Opera
          [text, klass] = if req.status in [0, 304]
            [null, null]
          else
            ["#{req.statusText} (#{req.status})", 'warning']
          ThreadUpdater.set 'status', text, klass
      delete ThreadUpdater.req

  getInterval: ->
    i = ThreadUpdater.interval
    j = Math.min ThreadUpdater.outdateCount, 10
    unless d.hidden
      # Lower the max refresh rate limit on visible tabs.
      j = Math.min j, 7
    ThreadUpdater.seconds = Math.max i, [0, 5, 10, 15, 20, 30, 60, 90, 120, 240, 300][j]

  set: (name, text, klass) ->
    el = ThreadUpdater[name]
    if node = el.firstChild
      # Prevent the creation of a new DOM Node
      # by setting the text node's data.
      node.data = text
    else
      el.textContent = text
    el.className = klass if klass isnt undefined

  timeout: ->
    ThreadUpdater.timeoutID = setTimeout ThreadUpdater.timeout, 1000
    unless n = --ThreadUpdater.seconds
      ThreadUpdater.update()
    else if n <= -60
      ThreadUpdater.set 'status', 'Retrying', null
      ThreadUpdater.update()
    else if n > 0
      ThreadUpdater.set 'timer', n

  update: ->
    return unless ThreadUpdater.online
    ThreadUpdater.seconds = 0
    ThreadUpdater.set 'timer', '...'
    if ThreadUpdater.req
      # abort() triggers onloadend, we don't want that.
      ThreadUpdater.req.onloadend = null
      ThreadUpdater.req.abort()
    url = "//api.4chan.org/#{ThreadUpdater.thread.board}/res/#{ThreadUpdater.thread}.json"
    ThreadUpdater.req = $.ajax url, onloadend: ThreadUpdater.cb.load,
      headers: 'If-Modified-Since': ThreadUpdater.lastModified

  updateThreadStatus: (title, OP) ->
    titleLC = title.toLowerCase()
    return if ThreadUpdater.thread["is#{title}"] is !!OP[titleLC]
    unless ThreadUpdater.thread["is#{title}"] = !!OP[titleLC]
      message = if title is 'Sticky'
        'The thread is not a sticky anymore.'
      else
        'The thread is not closed anymore.'
      new Notification 'info', message, 30
      $.rm $ ".#{titleLC}Icon", ThreadUpdater.thread.OP.nodes.info
      return
    message = if title is 'Sticky'
      'The thread is now a sticky.'
    else
      'The thread is now closed.'
    new Notification 'info', message, 30
    icon = $.el 'img',
      src: "//static.4chan.org/image/#{titleLC}.gif"
      alt: title
      title: title
      className: "#{titleLC}Icon"
    root = $ '[title="Quote this post"]', ThreadUpdater.thread.OP.nodes.info
    if title is 'Closed'
      root = $('.stickyIcon', ThreadUpdater.thread.OP.nodes.info) or root
    $.after root, [$.tn(' '), icon]

  parse: (postObjects) ->
    OP = postObjects[0]
    Build.spoilerRange[ThreadUpdater.thread.board] = OP.custom_spoiler

    ThreadUpdater.updateThreadStatus 'Sticky', OP
    ThreadUpdater.updateThreadStatus 'Closed', OP
    ThreadUpdater.thread.postLimit = !!OP.bumplimit
    ThreadUpdater.thread.fileLimit = !!OP.imagelimit

    nodes = [] # post container elements
    posts = [] # post objects
    index = [] # existing posts
    files = [] # existing files
    count = 0  # new posts count
    # Build the index, create posts.
    for postObject in postObjects
      num = postObject.no
      index.push num
      files.push num if postObject.fsize
      continue if num <= ThreadUpdater.lastPost
      # Insert new posts, not older ones.
      count++
      node = Build.postFromObject postObject, ThreadUpdater.thread.board
      nodes.push node
      posts.push new Post node, ThreadUpdater.thread, ThreadUpdater.thread.board

    deletedPosts = []
    deletedFiles = []
    # Check for deleted posts/files.
    for ID, post of ThreadUpdater.thread.posts
      # XXX tmp fix for 4chan's racing condition
      # giving us false-positive dead posts.
      # continue if post.isDead
      ID = +ID
      if post.isDead and ID in index
        post.resurrect()
      else unless ID in index
        post.kill()
        deletedPosts.push post
      else if post.file and !post.file.isDead and ID not in files
        post.kill true
        deletedFiles.push post

    unless count
      ThreadUpdater.set 'status', null, null
      ThreadUpdater.outdateCount++
    else
      ThreadUpdater.set 'status', "+#{count}", 'new'
      ThreadUpdater.outdateCount = 0
      if Conf['Beep'] and d.hidden and Unread.posts and !Unread.posts.length
        unless ThreadUpdater.audio
          ThreadUpdater.audio = $.el 'audio', src: ThreadUpdater.beep
        ThreadUpdater.audio.play()

      ThreadUpdater.lastPost = posts[count - 1].ID
      Main.callbackNodes Post, posts

      scroll = Conf['Auto Scroll'] and ThreadUpdater.scrollBG() and
        ThreadUpdater.root.getBoundingClientRect().bottom - doc.clientHeight < 25
      $.add ThreadUpdater.root, nodes
      if scroll
        if Conf['Bottom Scroll']
          <% if (type === 'crx') { %>d.body<% } else { %>doc<% } %>.scrollTop = d.body.clientHeight
        else
          Header.scrollToPost nodes[0]

      $.queueTask ->
        # Enable 4chan features.
        threadID = ThreadUpdater.thread.ID
        {length} = $$ '.thread > .postContainer', ThreadUpdater.root
        if Conf['Enable 4chan\'s Extension']
          $.globalEval "Parser.parseThread(#{threadID}, #{-count})"
        else
          Fourchan.parseThread threadID, length - count, length

    $.event 'ThreadUpdate',
      404: false
      thread: ThreadUpdater.thread
      newPosts: posts
      deletedPosts: deletedPosts
      deletedFiles: deletedFiles
      postCount: OP.replies + 1
      fileCount: OP.images + (!!ThreadUpdater.thread.OP.file and !ThreadUpdater.thread.OP.file.isDead)

ThreadWatcher =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Thread Watcher']
    @dialog = UI.dialog 'watcher', 'top: 50px; left: 0px;',
      '<div class=move>Thread Watcher</div>'

    $.on d, 'QRPostSuccessful',   @cb.post
    $.on d, '4chanXInitFinished', @ready
    $.sync  'WatchedThreads',     @refresh

    Thread::callbacks.push
      name: 'Thread Watcher'
      cb:   @node

  node: ->
    favicon = $.el 'img',
      className: 'favicon'
    $.on favicon, 'click', ThreadWatcher.cb.toggle
    $.before $('input', @OP.nodes.post), favicon
    return if g.VIEW isnt 'thread'
    $.get 'AutoWatch', 0, (item) =>
      return if item['AutoWatch'] isnt @ID
      ThreadWatcher.watch @
      $.delete 'AutoWatch'

  ready: ->
    $.off d, '4chanXInitFinished', ThreadWatcher.ready
    return unless Main.isThisPageLegit()
    ThreadWatcher.refresh()
    $.add d.body, ThreadWatcher.dialog

  refresh: (watched) ->
    unless watched
      $.get 'WatchedThreads', {}, (item) ->
        ThreadWatcher.refresh item['WatchedThreads']
      return
    nodes = [$('.move', ThreadWatcher.dialog)]
    for board of watched
      for id, props of watched[board]
        x = $.el 'a',
          textContent: '×'
          href: 'javascript:;'
        $.on x, 'click', ThreadWatcher.cb.x
        link = $.el 'a', props
        link.title = link.textContent

        div = $.el 'div'
        $.add div, [x, $.tn(' '), link]
        nodes.push div

    $.rmAll ThreadWatcher.dialog
    $.add ThreadWatcher.dialog, nodes

    watched = watched[g.BOARD] or {}
    for ID, thread of g.BOARD.threads
      favicon = $ '.favicon', thread.OP.nodes.post
      favicon.src = if ID of watched
        Favicon.default
      else
        Favicon.empty
    return

  cb:
    toggle: ->
      ThreadWatcher.toggle Get.postFromNode(@).thread
    x: ->
      thread = @nextElementSibling.pathname.split '/'
      ThreadWatcher.unwatch thread[1], thread[3]
    post: (e) ->
      {board, postID, threadID} = e.detail
      if postID is threadID
        if Conf['Auto Watch']
          $.set 'AutoWatch', threadID
      else if Conf['Auto Watch Reply']
        ThreadWatcher.watch board.threads[threadID]

  toggle: (thread) ->
    if $('.favicon', thread.OP.nodes.post).src is Favicon.empty
      ThreadWatcher.watch thread
    else
      ThreadWatcher.unwatch thread.board, thread.ID

  unwatch: (board, threadID) ->
    $.get 'WatchedThreads', {}, (item) ->
      watched = item['WatchedThreads']
      delete watched[board][threadID]
      delete watched[board] unless Object.keys(watched[board]).length
      ThreadWatcher.refresh watched
      $.set 'WatchedThreads', watched

  watch: (thread) ->
    $.get 'WatchedThreads', {}, (item) ->
      watched = item['WatchedThreads']
      watched[thread.board] or= {}
      watched[thread.board][thread] =
        href: "/#{thread.board}/res/#{thread}"
        textContent: Get.threadExcerpt thread
      ThreadWatcher.refresh watched
      $.set 'WatchedThreads', watched
