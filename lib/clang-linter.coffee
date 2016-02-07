Helpers = require 'atom-linter'

module.exports =
class ClangLinter
  name: 'Clang Linter'
  grammarScopes: ['source.c', 'source.cpp', 'source.objc', 'source.objcpp']
  scope: 'file'
  lintOnFly: false

  # FIXME: split line.
  regex = "(?<file>.+):(?<line>\\d+):(?<col>\\d+):(\{(?<lineStart>\\d+):(?<colStart>\\d+)\-(?<lineEnd>\\d+):(?<colEnd>\\d+)}.*:)? (?<type>[\\w \\-]+): (?<message>.*)"

  constructor: (ninja_project) ->
    @project = ninja_project

  lint: (editor) =>
    command = 'clang'

    if not @project.compdb[editor.getPath()]?
      atom.notifications.addWarning("File is not in project")
      return null

    args = [
      '-fsyntax-only',
      '-fno-caret-diagnostics',
      '-fno-diagnostics-fixit-info',
      '-fdiagnostics-print-source-range-info',
    ].concat @project.compdb[editor.getPath()].args

    # Linter activates after file save - append the file path.
    args.push editor.getPath()

    return Helpers.exec(command, args,
      {cwd: @project.compdb[editor.getPath()].cwd, stream: "stderr"})
      .then (output) -> Helpers.parse(output, regex)
