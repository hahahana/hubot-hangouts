webdriver = require 'selenium-webdriver'
events = require('events')
_ = require('underscore')

{Robot, Adapter, EnterMessage, LeaveMessage, TextMessage} = require('hubot')

class Hangouts extends Adapter
  send: (envelope, strings...) ->
    unless process.platform is 'win32'
      console.log "\x1b[01;32m#{str}\x1b[0m" for str in strings
    else
      console.log "#{str}" for str in strings

    @driver.findElement(webdriver.By.className("editable")).then (editor) =>
      editor.sendKeys(str) for str in strings
      editor.sendKeys webdriver.Key.ENTER

  emote: (envelope, strings...) ->
    @send envelope, "* #{str}" for str in strings

  reply: (envelope, strings...) ->
    strings = strings.map (s) -> "#{envelope.user.name}: #{s}"
    @send envelope, strings...

  run: ->
    self = @

    driver = new webdriver.Builder().withCapabilities(webdriver.Capabilities.phantomjs()).build()

    greetRoom = =>
      @listener.start()
      @.emit 'connected'
      user = @robot.brain.userForId '1', name: 'Shell', room: 'Shell'
      @receive new TextMessage user, "#{@robot.name} echo #{@robot.name} in da house!", 'messageId'

    switchContentToChat = ->
      driver.findElements(webdriver.By.css('.talk_chat_widget')).then (widgets) ->
        widgets.map (widget) ->
          widget.getAttribute('id').then (id) ->
            iFrameId = id.replace('_m', '')
            driver.sleep(2000)
            driver.switchTo().frame(iFrameId)

            driver.isElementPresent(webdriver.By.css('[googlevoice="nolinks"]')).then (result) ->
              if result
                driver.findElement(webdriver.By.css('[googlevoice="nolinks"]')).then (element) ->
                  element.getAttribute('innerHTML').then (text) ->
                    if text == hangoutName
                      greetRoom()
                      true
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

    @listener = new Listener
    @listener.driver = @driver
    @listener.on 'report', () =>
      console.log("Listening!")

    @driver = driver

    hangoutName = process.env.HANGOUT_NAME
    email = process.env.HANGOUTS_EMAIL
    password = process.env.HANGOUTS_PASSWORD

    signIn(email, password)

exports.use = (robot) ->
  new Hangouts robot
