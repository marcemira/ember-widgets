module "Text editor integration tests",
  teardown: -> App.reset()
  setup: ->
    Ember.run(App, App.advanceReadiness)
    visit('/ember-widgets/textEditor')

KEY_CODES =
  BACKSPACE: 8,
  DELETE: 46,
  DOWN: 40,
  ENTER: 13,
  LEFT: 37,
  RIGHT: 39,
  SPACEBAR: 32,
  TAB: 9,
  UP: 38,
  ESCAPE: 27

insertNonEditableButton = -> find '.insert-non-editable-btn'

insertNonEditable = ->
  selectInChosen(insertNonEditableButton(), "Today's Date")

insertNonEditableWithText = (text="foobar") ->
  selectInChosen(insertNonEditableButton(), "Custom Text").then ->
    fillIn(find('.modal input'), text).then ->
      click find("button:contains('Insert')")

selectedRange = ->
  iframe = @$('iframe.text-editor-frame')[0]
  idocument = iframe.contentDocument || iframe.contentWindow.document
  if idocument.getSelection().rangeCount > 0 then idocument.getSelection().getRangeAt(0) else null

getTextEditor = ->
  find('iframe.text-editor-frame').contents().find('.text-editor')

placeCursorInTextEditor = ->
  range = document.createRange()
  # Select the entire contents of the element with the range
  element = getTextEditor().find('.non-editable-caret')[0]
  range.selectNodeContents(element)
  range.collapse(true)
  selection = window.getSelection()
  selection.removeAllRanges()
  selection.addRange(range)
  return range

selectIdInTextEditor = (eid, startOffset=0, endOffset=0) ->
  range = document.createRange()
  # Select the entire contents of the element with the range
  element = getTextEditor().find('#' + eid)[0].childNodes[0]
  range.selectNodeContents(element)
  range.setStart(element, startOffset)
  range.setEnd(element, element.length - endOffset)
  selection = window.getSelection()
  selection.removeAllRanges()
  selection.addRange(range)
  return range

placeCursorAfterElementInTextEditor = (eid, startOffset=0, endOffset=0) ->
  range = document.createRange()
  # Select the entire contents of the element with the range
  element = getTextEditor().find('#' + eid)[0].childNodes[0]
  range.selectNodeContents(element)
  range.collapse(false)
  selection = window.getSelection()
  selection.removeAllRanges()
  selection.addRange(range)
  return range

selectMatchingTextInTextEditor = (text) ->
  innerSelect = (node, pat) ->
    pat = pat.toLowerCase()
    if node.nodeType is 3
      pos = node.data.toLowerCase().indexOf(pat)
      if pos >= 0
        range = document.createRange()
        range.setStart(node, pos)
        range.setEnd(node, pos + pat.length)
        selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(range)
        return range
    else if node.nodeType is 1 and node.childNodes and not /(script|style)/i.test(node.tagName)
      i = 0
      while i < node.childNodes.length
        childNode = node.childNodes[i++]
        range = innerSelect(childNode, pat)
        return range if range isnt null
    return null
  innerSelect(getTextEditor()[0], text)

typeKeyInTextEditor = (keyCode) ->
  keyEvent('.text-editor', $('iframe.text-editor-frame').contents(), 'keydown', keyCode).then ->
  keyEvent('.text-editor', $('iframe.text-editor-frame').contents(), 'keypress', keyCode).then ->
  keyEvent('.text-editor', $('iframe.text-editor-frame').contents(), 'keyup', keyCode)


keyDownInTextEditor = (keyCode) ->
  keyEvent('.text-editor', $('iframe.text-editor-frame').contents(), 'keydown', keyCode)


test 'Text editor appears', ->
  ok isPresent('.text-editor-frame'), 'Text editor frame not found'
  ok getTextEditor().length > 0, 'Text editor not found'


test "Insert non-editable date pill in text editor", ->
  expect 3
  insertNonEditable().then ->
    textEditor = getTextEditor()
    pill = find('span.non-editable', textEditor)
    equal pill.attr('title'), "Today's Date"
    equal pill.attr('data-type'), "Ember.Widgets.TodaysDatePill"
    notEqual pill.attr('data-pill-id'), null


test "Insert custom text pill in text editor", ->
  expect 4
  insertNonEditableWithText('foobar').then ->
    textEditor = getTextEditor()
    pill = find('span.non-editable', textEditor)
    equal pill.attr('title'), "Custom Text"
    equal pill.attr('data-type'), "Ember.Widgets.NonEditableTextPill"
    equal pill.text(), 'foobar'
    notEqual pill.attr('data-pill-id'), null, 'Pill id is not set'


test "Left arrow selects non-editable pill", ->
  expect 3

  # Given a text editor with a non-editable pill inserted
  insertNonEditable()
  # When the left arrow is pressed immediately after
  .then ->
    typeKeyInTextEditor(KEY_CODES.LEFT)
  # Then the non-editable is selected
  .then ->
    range = selectedRange()
    pill = getTextEditor().find('.non-editable')
    equal range.startOffset, 0, 'Range start is not at beginning of pill, is instead at ' + range.startOffset
    equal range.endOffset, pill.text().length, 'Range end is not at end of pill, is instead at ' + range.endOffset
    equal range.startContainer.parentElement, pill[0]


test "Arrow behavior between pills", ->
  expect 4

  # Given a text editor with the following content
  text_editor_content = """
      <div><span class="non-editable-caret">﻿</span><span class="non-editable" data-pill-id="1">Factor 1</span>regular text<span class="non-editable" data-pill-id="2">Factor 2</span></div>
  """
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the cursor is placed in the text editor
  currentRange = placeCursorInTextEditor()
  ok(currentRange.startOffset is 0 and currentRange.endOffset is 0, "cursor is placed in beginning of text editor content")
  # And the right arrow is pressed
  typeKeyInTextEditor(KEY_CODES.RIGHT)
  # Then the first pill is selected
  .then ->
    range = selectedRange()
    equal range.startContainer.parentElement, find('span.non-editable[data-pill-id="1"]', $textEditor)[0]
    equal range.startOffset, 0
    equal range.endOffset, 8


test "Arrow behavior between pills on first line", ->
  expect 4

  # Given a text editor with the following content
  text_editor_content = """
      <span class="non-editable-caret">﻿</span><span class="non-editable" data-pill-id="1">Factor 1</span>regular text<span class="non-editable" data-pill-id="2">Factor 2</span>
  """
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the cursor is placed in the text editor
  currentRange = placeCursorInTextEditor()
  ok(currentRange.startOffset is 0 and currentRange.endOffset is 0, "cursor is placed in beginning of text editor content")
  # And the right arrow is pressed
  typeKeyInTextEditor(KEY_CODES.RIGHT)
  # Then the first pill is selected
  .then ->
    range = selectedRange()
    equal range.startContainer.parentElement, find('span.non-editable[data-pill-id="1"]', $textEditor)[0]
    equal range.startOffset, 0
    equal range.endOffset, 8


test "Select second pill and delete", ->
  expect 3

  # Given a text editor with two side by side pills
  text_editor_content = """
    <span class="non-editable" data-pill-id="1">Pill 1</span><span class="non-editable" data-pill-id="2" id="to-select">Pill 2</span>
  """
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the second pill is selected
  currentRange = selectIdInTextEditor("to-select")
  click(getTextEditor())
  .then ->
    currentRange = selectedRange()
    equal( getTextEditor().find('#to-select')[0], currentRange.startContainer.parentElement, "the correct pill element is not selected")
    ok(currentRange.startOffset is 0 and currentRange.endOffset is 6, "the correct pill element is not entirely selected")
  .then ->
    # And then the delete key is pressed
    typeKeyInTextEditor(KEY_CODES.DELETE)
  .then ->
    # Then the pill is entirely deleted
    textEditor = getTextEditor()[0]
    equal(textEditor.innerHTML.trim(), """
      <span class="non-editable" data-pill-id="1">Pill 1</span><span class="non-editable-caret">﻿</span>
    """.trim(), "Pill is entirely deleted from text editor")


test "Select first pill and delete", ->
  expect 3

  # Given a text editor with two side by side pills
  text_editor_content = """
    <span class="non-editable" data-pill-id="1"id="to-select">Pill 1</span><span class="non-editable" data-pill-id="2">Pill 2</span>
  """
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the first pill is selected
  currentRange = selectIdInTextEditor("to-select")
  click(getTextEditor())
  .then ->
    currentRange = selectedRange()
    equal( getTextEditor().find('#to-select')[0], currentRange.startContainer.parentElement, "the correct pill element is not selected")
    ok(currentRange.startOffset is 0 and currentRange.endOffset is 6, "the correct pill element is not entirely selected")
  .then ->
    # And then the delete key is pressed
    typeKeyInTextEditor(KEY_CODES.DELETE)
  .then ->
    # Then the pill is entirely deleted
    textEditor = getTextEditor()[0]
    equal(textEditor.innerHTML.trim(), """
      <span class="non-editable-caret">﻿</span><span class="non-editable" data-pill-id="2">Pill 2</span>
    """.trim(), "Pill is entirely deleted from text editor")


test "Bolding text preserves selection", ->
  expect 2

  # Given a text editor with some text
  text_editor_content = "hello world goodbye"
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the word "world" is selected
  currentRange = selectMatchingTextInTextEditor("world")
  click(getTextEditor())
  .then ->
    # And then bold is clicked
    click($('button .fa-bold').parent())
  .then ->
    # Then the word "world" is bolded
    equal($textEditor[0].innerHTML.trim(), 'hello <span style="font-weight: bold;">world</span> goodbye', "The word 'world' was not bolded")
    currentRange = selectedRange()
    # And it is still selected
    equal( currentRange.endOffset - currentRange.startOffset, 5, "The word 'world' is no longer selected")


test "Backspace with factors on many lines", ->
  expect 2

  # Given a text editor with some text
  text_editor_content = '<div><span class="non-editable" data-pill-id="2">and me</span></div><div><span class="non-editable" id="to-select" data-pill-id="4">Put cursor here and delete me--&gt;</span></div><div>hello</div>'
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the word "world" is selected
  currentRange = placeCursorAfterElementInTextEditor("to-select")
  click(getTextEditor())
  .then ->
    # And then the backspace key is pressed
    keyDownInTextEditor(KEY_CODES.BACKSPACE)
  .then ->
    # Then a non editable caret is inserted after the pill about to be deleted
    equal($textEditor[0].innerHTML.trim(), '<div><span class="non-editable" data-pill-id="2">and me</span></div><div><span class="non-editable" id="to-select" data-pill-id="4">Put cursor here and delete me--&gt;</span><span class="non-editable-caret">﻿</span></div><div>hello</div>', "The html content is incorrect")
    currentRange = selectedRange()
    # And the pill is selected
    equal(currentRange.endOffset - currentRange.startOffset, 32, "The pill is not selected")
    # At this point, the browser would finish the backspace event, though we can't test it


test "Non editable caret on it's own line is replaced with a break", ->
  # This test only applies to chrome...
  expect 1

  # Given a text editor with some text
  text_editor_content = '<div><span class="non-editable" data-pill-id="1">A pill</span></div><div><span class="non-editable-caret">﻿</span></div><div>hello</div>'
  $textEditor = getTextEditor()
  $textEditor[0].innerHTML = text_editor_content
  # When the the text editor is clicked
  currentRange = placeCursorInTextEditor()
  click(getTextEditor())
  .then ->
    # Then the caret is replaced with a break
    equal($textEditor[0].innerHTML.trim(), '<div><span class="non-editable" data-pill-id="1">A pill</span></div><div><br></div><div>hello</div>', "The html content is incorrect")