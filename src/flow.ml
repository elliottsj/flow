(**
 * Copyright (c) 2013-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(***********************************************************************)
(* flow shell is just a simple command-dispatching main *)
(***********************************************************************)

module FlowShell : sig
  val main : unit -> unit
end = struct

  (* normal commands *)
  let commands = [
    AstCommand.command;
    AutocompleteCommand.command;
    ServerCommands.Check.command;
    CheckContentsCommand.command;
    ConvertCommand.command;
    CoverageCommand.command;
    FindModuleCommand.command;
    ForceRecheckCommand.command;
    GetDefCommand.command;
    GetImportersCommand.command;
    GetImportsCommand.command;
    ConfigCommands.Init.command;
    LsCommand.command;
    PortCommand.command;
    ServerCommands.Server.command;
    SearchCommand.command;
    ServerCommands.Start.command;
    StopCommand.command;
    SuggestCommand.command;
    TypeAtPosCommand.command;
    DumpTypesCommand.command;
    VersionCommand.command;
  ]

  (* status commands, which need a list of other commands *)
  module StatusCommand = StatusCommands.Status(struct
    let commands = commands
  end)
  let commands = StatusCommand.command :: commands

  module DefaultCommand = StatusCommands.Default(struct
    let commands = commands
  end)
  let commands = DefaultCommand.command :: commands

  module ShellCommand = ShellCompleteCommand.Command(struct
    let commands = commands
  end)
  let commands = ShellCommand.command :: commands

  let main () =
    Daemon.check_entry_point (); (* this call might not return *)

    Sys_utils.set_signal Sys.sigpipe Sys.Signal_ignore;
    let default_command = DefaultCommand.command in
    let argv = Array.to_list Sys.argv in
    let default = CommandSpec.name default_command in
    let (command, argv) = match argv with
    | [] -> failwith "Expected command"
    | cmd::[] -> (default_command, cmd::default::[])
    | cmd::next::rest ->
        let subcmd = String.lowercase next in
        try
          let command = List.find (fun command ->
            (CommandSpec.name command) = subcmd
          ) commands in
          (command, argv)
        with Not_found ->
          (default_command, cmd::default::next::rest)
    in
    let command_string = CommandSpec.name command in
    FlowEventLogger.set_command (Some command_string);
    FlowEventLogger.init_flow_command ~version:FlowConfig.version;
    try
      CommandSpec.run command argv
    with
    | CommandSpec.Show_help ->
        print_endline (CommandSpec.string_of_usage command);
        FlowExitStatus.(exit Ok)
    | CommandSpec.Failed_to_parse msg ->
        let msg = Utils_js.spf
          "%s: %s\n%s"
          (Filename.basename Sys.executable_name)
          msg
          (CommandSpec.string_of_usage command)
        in
        FlowExitStatus.(exit ~msg Commandline_usage_error)
end

let _ = FlowShell.main ()
(* If we haven't exited yet, let's exit now for logging's sake *)
let _ = FlowExitStatus.(exit Ok)
