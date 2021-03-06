%
% reia: Interface between Erlang and Reia environments
% Copyright (C)2008-10 Tony Arcieri
%
% Redistribution is permitted under the MIT license. See LICENSE for details.
%

-module(reia).
-export([
	init/0, 
	load/1,
	parse/1,
	eval/2,
	inst/2, inst/3,
	invoke/3, invoke/4
]).
-include("reia_types.hrl").

% Initialize the Reia environment
init() -> 
  % Launch the Reia CodeServer
  'CodeServer':start(),
  
  % Load Reia builtins and other core modules
  reia_internal:load_core(),
  
  % Load the Reia standard library
  reia_internal:load_stdlib(), 
  ok.

% Load the given Reia source code file
load(Filename) ->
  SourcePath = filename:absname(Filename),
  BinPath = filename:rootname(SourcePath) ++ ".reb",
  
  case file:read_file_info(SourcePath) of
    {ok, SourceInfo} ->      
      case file:read_file_info(BinPath) of
        % If the binary already exists, load it
        {ok, BinInfo} ->
          SourceMtime = element(6, SourceInfo),
          BinMtime = element(6, BinInfo),
          
          % Ensure changes haven't been made to the sources
          if
            BinMtime > SourceMtime ->
              void;
            true ->
              reia_internal:compile(SourcePath, BinPath)
          end;
          
        % Otherwise compile the source code
        {error, _} ->
          reia_internal:compile(SourcePath, BinPath)
      end,
      reia_bytecode:load_file(BinPath);
    {error, _} = Error ->
      Error
  end.

% Parse the given string of Reia source code
parse(String) ->
	reia_compiler:parse(String).

% Evaluate the given string of Reia source code
eval(String, Binding) ->
	reia_eval:exprs(parse(String), Binding).
	
% Create a new instance of the given class
inst(Class, Arguments) -> inst(Class, Arguments, nil).
inst(Class, Arguments, Block) ->
	% FIXME: initial object construction should thunk to the metaclass, not be
	% spelled out explicitly here.
	Object = #reia_object{class=Class, ivars=dict:new()},
	Class:call({Object, initialize, Arguments}, Block).
	
% Invoke the given method on the given object
invoke(Receiver, Method, Arguments) -> invoke(Receiver, Method, Arguments, nil).
invoke(Receiver, Method, Arguments, Block) ->
	Arguments2 = if
		is_tuple(Arguments) -> Arguments;
		is_list(Arguments)  -> list_to_tuple(Arguments);
		true -> throw({error, "invalid type for arguments"})
	end,
			
	Class = Receiver#reia_object.class,
	Class:call({Receiver, Method, Arguments2}, Block).