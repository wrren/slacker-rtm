%%%----------------------------------------------------------------------------
%%% @author Martin Wiso <martin@wiso.cz>
%%% @doc
%%% Client wrapping websocket connection to Slack
%%% @end
%%%----------------------------------------------------------------------------
-module(sr_client).

-behaviour(websocket_client_handler).

-include("sr.hrl").

%% API
-export([ start_link/2
        , send/2
        ]).

%% websocket_client_handler callbacks
-export([ init/2
         , websocket_handle/3
         , websocket_info/3
         , websocket_terminate/3
        ]).

-define(SERVER, ?MODULE).

-record(state, {connected :: boolean(), caller_pid :: pid()}).

%%%============================================================================
%%% API
%%%============================================================================
-spec start_link(pid(), binary()) -> {ok, pid()} | {error, any()}.
start_link(Caller, WSS) ->
    websocket_client:start_link(?b2l(WSS), ?MODULE, [Caller]).

-spec send(pid(), binary()) -> ok.
send(Pid, Payload) ->
    websocket_client:cast(Pid, {text, Payload}).

%%%============================================================================
%%% websocket_client_handler callbacks
%%%============================================================================
init([Caller], _ConnState) ->
    {ok, #state{connected = false, caller_pid = Caller}}.

websocket_handle({text, JSON}, _ConnState, #state{caller_pid = Caller} = State) ->
    Map = parse_json(JSON),
    case maps:get(<<"type">>, Map) of
        <<"hello">> ->
            Caller ! connected,
            {ok, State#state{connected = true}};
        Event ->
            Caller ! {Event, Map},
            {ok, State}
    end;
websocket_handle({ping, _Msg}, _ConnState, State) ->
    {reply, {pong, <<>>}, State};
websocket_handle(_Msg, _ConnState, State) ->
    {ok, State}.

websocket_info(_Info, _ConnState, State) ->
    {reply, {text, <<>>}, State}.

websocket_terminate(_Reason, _ConnState, _State) ->
    ok.

%%%============================================================================
%%% Internal functions
%%%============================================================================
parse_json(Bin) ->
    jiffy:decode(Bin, [return_maps]).
