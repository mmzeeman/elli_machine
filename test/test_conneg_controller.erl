%%
%% Module for testing content negotiation.
%%

-module(test_conneg_controller).

-export([init/1, 
	ping/2, 
	allowed_methods/2, 
        content_types_provided/2,

	process_request/2,

        to_html/2,
        to_plain/2,

	render_error/4, 
	handle_event/3]).

init(_Args) -> 
    {ok, undefined}.

ping(ReqData, Context) ->
    {pong, ReqData, Context}.

allowed_methods(ReqData, Context) ->
    {['POST', 'GET'], ReqData, Context}.

content_types_provided(ReqData, Context) ->
    {[{<<"text/html">>, to_html},
      {<<"text/plain">>, to_plain}], ReqData, Context}.

process_request(X, Context) ->
    X1 = hx:set_resp_body(<<"<html><head></head><body>thank-you</body></html>">>, X),
    {true, X1, Context}.

to_html(ReqData, Context) ->
    {<<"<html><head></head><body>html response</body></html>">>, ReqData, Context}.

to_plain(ReqData, Context) ->
    {<<"plain response">>, ReqData, Context}.

%% 
%%
render_error(Code, _Error, ReqData, Context) ->
    {<<"Error">>, ReqData, Context}.

%%
%%
handle_event(_, _, _) ->
	ok.
