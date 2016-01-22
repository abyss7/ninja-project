{BufferedProcess} = require 'atom'

module.exports =

RunCommand: ({command, args, cwd, stdin}) ->
  new Promise (resolve) ->
    stderr_all = []
    stdout_all = []
    stderr = (output) -> stderr_all.push output
    stdout = (output) -> stdout_all.push output
    exit = (code) ->
      resolve {code, stdout: stdout_all.join '\n', stderr: stderr_all.join '\n'}

    options = {}
    if cwd?
      options['cwd'] = cwd

    if args?
      command += ' ' + args.join ' '

    process =
      new BufferedProcess({command: 'bash', args: ['-c', command],
                           options, stdout, stderr, exit})
    if stdin?
      process.process.stdin.setEncoding = 'utf-8'
      process.process.stdin.write stdin
      process.process.stdin.end()
