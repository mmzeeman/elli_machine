%% @author Maas-Maarten Zeeman <mmzeeman@xs4all.nl>
%% @copyright 2013, 2014 Maas-Maarten Zeeman
%%
%% @doc Hedgy 
%%
%% Copyright 2013 Maas-Maarten Zeeman
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(hedgy).
-author("Maas-Maarten Zeeman <mmzeeman@xs4all.nl>").

-include_lib("elli/include/elli.hrl").

-include("hedgy.hrl").
-include("hedgy_internal.hrl").


-export([preprocess/2, handle/2, handle_event/3]).

-export_type([exchange/0]).
-type exchange() :: record(hedgy_exchange).
-type flow_state() :: record(hedgy_flow_state).

-behaviour(elli_handler).

%
% Webmachine like middleware for Elli.
% 
    
% @doc Preprocess the request, call the dispatcher and return a controller 
% reqdata.
%
-spec preprocess(elli:req(), any()) -> flow_state().
preprocess(Req, Args) ->
    {Mod, ModArgs} = dispatcher(Args),
    dispatch(Req, Mod, ModArgs).

% @doc Handle the request. Call the decision core which calls the callbacks
% of the controller.
handle({no_dispatch_match, _ReqData}, _Args) ->
    ignore; 
handle(FlowState, _Args) ->
    case hedgy_flow:handle_request(FlowState) of
        {_, FlowFin} ->
            hx:response(FlowFin#hedgy_flow_state.exchange);
        {upgrade, _UpgradeFun, _ControllerFin, _ReqDataFin} ->
            %% TODO: websocket upgrade will be done differently
            {501, [], <<"Upgrade not implemented">>}
    end.    

% @doc Handle event
%
handle_event(_Name, _EventArgs, _) -> 
    ok.

%%
%% Helpers
%%

dispatch(Req, Dispatcher, DispatchArgs) ->
    case Dispatcher:dispatch(Req, DispatchArgs) of
        {{no_dispatch_match, _Host, _PathSpec}, ReqData} ->
            {no_dispatch_match, ReqData};
        {{ControllerMod, ControllerOpts, _HostRemainder, _Port, _PathRemainder, _PathBindings, _AppRoot, _StringPath}, Exchange} ->
            {ok, ControllerState} =  hedgy_controller:init(ControllerMod, ControllerOpts),
            #hedgy_flow_state{exchange=Exchange, controller_mod=ControllerMod, controller_state=ControllerState}
    end.

dispatcher(Args) ->
    proplists:get_value(dispatcher, Args).

%%
%% Tests
%%

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

config() ->
    MachineConfig = [
        {dispatcher, {hedgy_dispatcher, [
            {dispatch_list, [
                {[<<"hello">>, '*'], example_controller, []}
            ]}
        ]}}
    ], 

    MiddlewareConfig = [
        {mods, [
            {hedgy, MachineConfig}
        ]}
    ],

    [{callback, elli_middleware},
     {callback_args, MiddlewareConfig}, {port, 8000}].

not_found_test() ->
    Config = config(),
    ?assertEqual({404, [], <<"Not Found">>},
                 elli_test:call('GET', <<"/not_found">>, 
                    [{<<"Host">>, <<"example.com">>}], <<>>, Config)),
    ?assertEqual({404, [], <<"Not Found">>}, elli_test:call('GET', <<"/not_found">>, [], <<>>, Config)),
    ok.

hello_world_test() ->
    Config = config(),
    ?assertEqual({200, [{<<"Content-Type">>, <<"text/html">>}], <<"Hello, new world">>},
                 elli_test:call('GET', <<"/hello">>, 
                    [{<<"Host">>, <<"example.com">>}], <<>>, Config)),

    ?assertEqual({200, [{<<"Content-Type">>, <<"text/html">>}], <<"Hello, new world">>},
                 elli_test:call('GET', <<"/hello">>, [], <<>>, Config)),

    ok.

% head_test() ->
%     %% Note: elli removes the body.
%     Config = config(),
%     ?assertEqual({200, [{<<"Content-Type">>, <<"text/html">>}], <<"Hello, new world">>},
%                  elli_test:call('HEAD', <<"/hello">>, 
%                     [{<<"Host">>, <<"example.com">>}], <<>>, Config)),
%     ok.

four_o_five_test() ->
    Config = config(),

    ?assertEqual({405, [{<<"Allow">>, <<"GET, HEAD">>}], <<>>},
                 elli_test:call('POST', <<"/hello">>, 
                    [{<<"Host">>, <<"example.com">>}], <<"test=123">>, Config)),

    ok.

    
-endif. %% TEST
    

