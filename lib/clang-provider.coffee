Utils = require './utils'

module.exports =
class ClangProvider
  selector: '.source.cpp, .source.c, .source.objc, .source.objcpp'
  inclusionPriority: 1
  excludeLowerPriority: true

  scopeSource:
    'source.cpp': 'c++'
    'source.c': 'c'
    'source.objc': 'objective-c'
    'source.objcpp': 'objective-c++'

  constructor: (ninja_project) ->
    @project = ninja_project

  getSuggestions: ({editor, bufferPosition, scopeDescriptor}) ->
    prefix = @prefixAtPosition(editor, bufferPosition)
    [row, col] = @nearestSymbolPosition(editor, bufferPosition)

    command = 'clang'

    if not @project.compdb[editor.getPath()]?
      atom.notifications.addWarning("File is not in project")
      return null

    args =
      ['-fsyntax-only', '-Xclang', "-code-completion-at=-:#{row}:#{col}"]
      .concat @project.compdb[editor.getPath()].args

    # Clang can't detect language from stdin - provided it via arguments.
    args.push '-x'
    scopes = scopeDescriptor.getScopesArray()
    for source, lang of @scopeSource
      args.push lang if source == scopes[0]

    # Use stdin since editor may contain unsaved changes.
    args.push '-'

    @codeCompletionAt(editor, command, args).then (completions) ->
      filtered = []
      for entry in completions
        if (entry.snippet or entry.text).startsWith prefix
          entry.replacementPrefix = prefix
          filtered.push entry
      filtered

  codeCompletionAt: (editor, command, args) ->
    new Promise (resolve) =>
      Utils.RunCommand({
        command, args, cwd: @project.compdb[editor.getPath()].cwd,
        stdin: editor.getText()
      }).then ({code, stdout, stderr}) =>
        console.log stderr
        console.log("clang exited with code #{code}")
        if code is 0
          lines = stdout.trim().split '\n'
          parsed_completions = (@parseCompletion(line) for line in lines)
          resolve(entry for entry in parsed_completions when entry?)

  parseCompletion: (line) ->
    lineRegexp = /COMPLETION: ([^:]+)(?: : (.+))?$/
    returnTypeRegexp = /\[#([^#]+)#\]/ig
    argumentRegexp = /\<#([^#]+)#\>/ig
    commentSplitRegexp = /(?: : (.+))?$/

    match = line.match(lineRegexp)
    if match?
      [line, completion, pattern] = match
      unless pattern?
        return {snippet:completion, text:completion}
      [patternNoComment, briefComment] = pattern.split commentSplitRegexp
      returnType = null
      patternNoType =
        patternNoComment.replace returnTypeRegexp, (match, type) ->
          returnType = type
          ''
      index = 0
      replacement = patternNoType.replace argumentRegexp, (match, arg) ->
        index++
        "${#{index}:#{arg}}"

      suggestion = {}
      suggestion.rightLabel = returnType if returnType?
      if index > 0
        suggestion.snippet = replacement
      else
        suggestion.text = replacement
      suggestion.description = briefComment if briefComment?
      suggestion

  prefixAtPosition: (editor, bufferPosition) ->
    regex = /\w+$/
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    line.match(regex)?[0] or ''

  nearestSymbolPosition: (editor, bufferPosition) ->
    regex = /(\W+)\w*$/
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    matches = line.match(regex)
    if matches
      symbol = matches[1]
      symbolColumn = matches[0].indexOf(symbol) + symbol.length +
                     (line.length - matches[0].length)
      [bufferPosition.row + 1, symbolColumn + 1]
    else
      [bufferPosition.row + 1, bufferPosition.column + 1]
