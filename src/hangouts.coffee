webdriver = require 'selenium-webdriver'
events = require('events')
_ = require('underscore')

{Robot, Adapter, EnterMessage, LeaveMessage, TextMessage} = require('hubot')

class Hangouts extends Adapter
  send: (envelope, strings...) ->
    if @last_message_id != envelope.message.id
      unless process.platform is 'win32'
        console.log "\x1b[01;32m#{str}\x1b[0m" for str in strings
      else
        console.log "#{str}" for str in strings

      @driver.findElement(webdriver.By.css("[contenteditable='true']")).then (editor) =>
        console.log("I tried to tell you #{strings[0]}")
        editor.getAttribute('outerHTML').then (html) ->
          console.log(html)
        if @last_message_id
          console.log('click!')
          editor.click()
        editor.sendKeys str for str in strings
        editor.sendKeys webdriver.Key.ENTER

    @last_message_id = envelope.message.id

  emote: (envelope, strings...) ->
    @send envelope, "* #{str}" for str in strings

  reply: (envelope, strings...) ->
    strings = strings.map (s) -> "#{envelope.user.name}: #{s}"
    @send envelope, strings...

  run: ->
    self = @
    @browserTest = process.env.DRIVER || 'chrome'

    if @browserTest == 'chrome'
      capability = webdriver.Capabilities.chrome()
    else # browserTest
      capability = webdriver.Capabilities.phantomjs()

    driver = new webdriver.Builder().withCapabilities(capability).build()

    greetRoom = =>
      user = @robot.brain.userForId '1'
      @receive new TextMessage user, "#{@robot.name} echo #{@robot.name} in da house!", 0

      driver.findElement(webdriver.By.tagName('body')).then (body) =>
        if @browserTest == 'chrome'
          body.getText().then (text) =>
            linez = text.split("\n")
            lines = _.reject linez, (line) ->
              line == 'Send a message...' ||
              line.match("is typing") ||
              line.match("is active") ||
              line.match("•")
            @lineLength = lines.length
            @listener.start()
        else
          body.getAttribute('innerHTML').then (html) =>
            linez = html.replace(/(<([^>]+)>)/ig, "|").split("|").filter(Boolean)
            lines = _.reject linez, (line) ->
              line == 'Send a message...' ||
              line.match("is typing") ||
              line.match("is active") ||
              line.match("mins") ||
              line.match("•") ||
              line == " " ||
              line == "  " ||
              line == "..." ||
              line.match("function init()") ||
              line.match('You blocked') ||
              line == "Message not delivered." ||
              line == "Send an SMS message..." ||
              line == "History is off" ||
              line == "Read up to here" ||
              line == "Now" ||
              line == "Hana"
            @lineLength = lines.length
            @listener.start()

    switchContentToChat = ->
      driver.findElements(webdriver.By.css('.talk_chat_widget')).then (widgets) =>
        widgets.map (widget) =>
          widget.getAttribute('id').then (id) =>
            iFrameId = id.replace('_m', '')
            driver.sleep(2000)
            driver.switchTo().frame(iFrameId)

            driver.isElementPresent(webdriver.By.css('[googlevoice="nolinks"]')).then (result) =>
              if result
                driver.findElement(webdriver.By.css('[googlevoice="nolinks"]')).then (element) =>
                  element.getAttribute('innerText').then (text) =>
                    if text == hangoutName
                      greetRoom()
                      true
                    else
                      driver.switchTo().defaultContent();
              else
                driver.switchTo().defaultContent();

    openChatFromRail = ->
      driver.isElementPresent(webdriver.By.css('[guidedhelpid="talkwithfriends"]')).then (result) ->
        unless result
          driver.findElement(webdriver.By.css('[title="Hangouts"]')).then (elem) ->
            elem.click();

        driver.switchTo().frame('gtn-roster-iframe-id-b')

        driver.findElement(webdriver.By.tagName('body')).then (rail) ->
          rail.findElements(webdriver.By.css('[aria-label]')).then (elements) ->
            elements.map (e) ->
              e.getText().then (text) ->
                if text == hangoutName
                  e.click()

            driver.switchTo().defaultContent();
            driver.sleep(3000)
            switchContentToChat()

    waitForPageLoad = ->
      (driver.wait ( ->
        driver.isElementPresent(webdriver.By.css('.talk_loading_msg')).then (result) ->
          result
      ), 20000, 'Unable to login to Google+.').then () ->
        console.log('Page loaded!')
        driver.sleep(3000)
        openChatFromRail()

    signIn = (email, password) ->
      driver.get('https://plus.google.com/settings').then () ->
        driver.findElement(webdriver.By.id('Email')).then (elem) ->
          elem.sendKeys(email)
          driver.findElement(webdriver.By.id('Passwd')).then (elem) ->
            elem.sendKeys(password)
            driver.findElement(webdriver.By.id('signIn')).then (elem) ->
              elem.click()
              waitForPageLoad()

    Listener = ->
    Listener.prototype = new events.EventEmitter;
    Listener.prototype.start = () ->
      self = this
      setInterval ->
        self.emit 'report'
      , 500

    self.emit 'connected'
    @last_message
    @listener = new Listener
    @listener.driver = @driver
    @count = 0
    @listener.on 'report', () =>
      driver.findElement(webdriver.By.tagName('body')).then (body) =>
        if @browserTest == 'chrome'
          body.getText().then (text) =>
            newLines = text.split("\n")
            newLinesClean = _.reject newLines, (line) ->
              line == 'Send a message...' ||
              line.match("is typing") ||
              line.match("is active") ||
              line.match("•")
            newLineLength = newLinesClean.length
            diff = newLinesClean.slice(@lineLength, newLineLength + 1)
            @lineLength = newLineLength

            if diff.length > 0
              regex = new RegExp(@robot.name, 'i')

              diff.map (line) =>
                if line.match(regex)
                  saysIndex = line.indexOf('says ')
                  if saysIndex > 0
                    line = line.substr(saysIndex + 5)
                  console.log("I heard you say '#{line}'")
                  user = @robot.brain.userForId '1'
                  @receive new TextMessage user, line, @id
                  @id += 1
        else
          body.getAttribute('innerHTML').then (html) =>
            linez = html.replace(/(<([^>]+)>)/ig, "|").split("|").filter(Boolean)
            newLinesClean = _.reject linez, (line) ->
              line == 'Send a message...' ||
              line.match("is typing") ||
              line.match("is active") ||
              line.match("mins") ||
              line.match("•") ||
              line == " " ||
              line == "  " ||
              line == "..." ||
              line.match("function init()") ||
              line.match('You blocked') ||
              line == "Message not delivered." ||
              line == "Send an SMS message..." ||
              line == "History is off" ||
              line == "Read up to here" ||
              line == "Now" ||
              line == "Hana"
            newLineLength = newLinesClean.length
            diff = newLinesClean.slice(@lineLength, newLineLength + 1)
            # console.log("linelengthold: #{@lineLength}")
            # console.log("newLineLength: #{newLineLength}")
            # console.log("diff: #{diff.length}")
            @lineLength = newLineLength

            if diff.length > 0
              regex = new RegExp(@robot.name, 'i')

              diff.map (line) =>
                if line.match(regex)
                  saysIndex = line.indexOf('says ')
                  if saysIndex > 0
                    line = line.substr(saysIndex + 5)
                  console.log("I heard you say '#{line}'")
                  user = @robot.brain.userForId '1'
                  @receive new TextMessage user, line, @id
                  @id += 1

    @driver = driver
    @id = 1
    hangoutName = process.env.HANGOUT_NAME
    email = process.env.HANGOUTS_EMAIL
    password = process.env.HANGOUTS_PASSWORD

    signIn(email, password)

exports.use = (robot) ->
  new Hangouts robot
