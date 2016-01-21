ClangProvider = require './clang-provider'

{BufferedProcess} = require 'atom'
{CompositeDisposable} = require 'atom'
CSON = require 'cson'
FileSystem = require 'fs'
Path = require 'path'

module.exports = NinjaProject =
  subscriptions: null
  compdb: {}

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a
    # CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ninja-project:regenerate': => @regenerate()

  deactivate: ->
    @subscriptions.dispose()

  provide: ->
    new ClangProvider(@)

  regenerate: ->
    command = 'ninja'  # TODO: take it from package settings.

    for path in atom.project.getPaths()
      config_path = Path.resolve(path, '.atom')
      if not FileSystem.existsSync(config_path)
        atom.notifications.addInfo("Configuration file not found in #{path}")
        continue
      config = CSON.load(config_path)

      console.log(config)

      compdb_string = ''

      args = ['-C', config['build_path'], '-t', 'compdb'].concat config['rules']
      options = { cwd: path }

      # FIXME: find the most efficient way to read stdout.
      stdout = (output) -> compdb_string += output

      exit = (code) =>
        if code is not 0
          atom.notifications.addError("Failed to parse project")
          return
        atom.notifications.addSuccess("Project parsed successfully")

        for entry in JSON.parse(compdb_string)
          # TODO: leave only required arguments for proper code-completion.
          args = (entry.command.split ' ')[1..]

          # FIXME: it's a hack!
          c_index = args.indexOf '-c'
          if (c_index != -1)
            args.splice c_index, 2

          # FIXME: it's a hack!
          o_index = args.indexOf '-o'
          if (o_index != -1)
            args.splice o_index, 2

          @compdb[Path.resolve(entry.directory, entry.file)] = {
            args: args
            cwd: entry.directory
          }

      process = new BufferedProcess({command, args, options, stdout, exit})
