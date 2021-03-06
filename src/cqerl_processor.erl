-module(cqerl_processor).
-include("cqerl_protocol.hrl").

-define(INT,   32/big-signed-integer).

-export([start_link/5, process/5]).

-type processor_message() :: {prepared | rows, binary()} |
                             {send, #cqerl_frame{}, map(), #cql_query{},
                              boolean(), boolean()}.

-export_type([processor_message/0]).

start_link(ClientPid, Node, UserQuery, Msg, ProtocolVersion) ->
    Pid = spawn_link(?MODULE, process, [ClientPid, Node, UserQuery, Msg, ProtocolVersion]),
    {ok, Pid}.

-spec process(ClientPid :: pid(),
              Node :: cqerl:cqerl_node(),
              UserQuery :: term(),
              Msg :: cqerl_processor:processor_message(),
              ProtocolVersion :: non_neg_integer()) -> any().

process(ClientPid, Node, UserQuery, Msg, ProtocolVersion) ->
    cqerl:put_protocol_version(ProtocolVersion),
    try do_process(ClientPid, Node, UserQuery, Msg) of
        Result -> Result
    catch
        ErrorClass:Error ->
            ClientPid ! {processor_threw,
                         {{ErrorClass, {Error, erlang:get_stacktrace()}},
                          {UserQuery, Msg}}}
    end.

do_process(_ClientPid, Node, UserQuery, { prepared, Msg }) ->
    {ok, QueryID, Rest0} = cqerl_datatypes:decode_short_bytes(Msg),
    {ok, QueryMetadata, Rest1} = cqerl_protocol:decode_prepared_metadata(Rest0),
    {ok, ResultMetadata, _Rest} = cqerl_protocol:decode_result_metadata(Rest1),
    cqerl_cache:query_was_prepared(Node, UserQuery,
                                   {QueryID, QueryMetadata, ResultMetadata}),
    ok;

do_process(ClientPid, _Node, UserQuery, { rows, Msg }) ->
    {Call=#cql_call{client=ClientRef}, {Query, ColumnSpecs}} = UserQuery,
    {ok, Metadata, << RowsCount:?INT, Rest0/binary >>} = cqerl_protocol:decode_result_metadata(Msg),
    {ok, ResultSet, _Rest} = cqerl_protocol:decode_result_matrix(RowsCount, Metadata#cqerl_result_metadata.columns_count, Rest0, []),
    ResultMetadata = Metadata#cqerl_result_metadata{rows_count=RowsCount},
    Result = #cql_result{
        client = {ClientPid, ClientRef},
        cql_query = Query#cql_query{page_state = ResultMetadata#cqerl_result_metadata.page_state},
        columns = case ColumnSpecs of
            undefined   -> ResultMetadata#cqerl_result_metadata.columns;
            []          -> ResultMetadata#cqerl_result_metadata.columns;
            _           -> ColumnSpecs
        end,
        dataset = ResultSet
    },
    ClientPid ! {rows, Call, Result},
    ok;

do_process(_ClientPid, _Node, {Trans, Socket, CachedResult},
           { send, BaseFrame, Values, Query, SkipMetadata, Tracing }) ->
    {ok, Frame} = case CachedResult of
        uncached ->
            cqerl_protocol:query_frame(BaseFrame,
                #cqerl_query_parameters{
                    skip_metadata       = SkipMetadata,
                    consistency         = Query#cql_query.consistency,
                    page_state          = Query#cql_query.page_state,
                    page_size           = Query#cql_query.page_size,
                    serial_consistency  = Query#cql_query.serial_consistency
                },
                #cqerl_query{
                    kind    = normal,
                    statement = Query#cql_query.statement,
                    values  = cqerl_protocol:encode_query_values(Values, Query),
                    tracing = Tracing
                }
            );

        #cqerl_cached_query{query_ref=Ref, result_metadata=#cqerl_result_metadata{columns=CachedColumnSpecs}, params_metadata=PMetadata} ->
            cqerl_protocol:execute_frame(BaseFrame,
                #cqerl_query_parameters{
                    skip_metadata       = length(CachedColumnSpecs) > 0,
                    consistency         = Query#cql_query.consistency,
                    page_state          = Query#cql_query.page_state,
                    page_size           = Query#cql_query.page_size,
                    serial_consistency  = Query#cql_query.serial_consistency
                },
                #cqerl_query{
                    kind    = prepared,
                    statement = Ref,
                    values  = cqerl_protocol:encode_query_values(Values, Query, PMetadata#cqerl_result_metadata.columns),
                    tracing = Tracing
                }
            )
    end,
    case Trans of
        tcp -> gen_tcp:send(Socket, Frame);
        ssl -> ssl:send(Socket, Frame)
    end.
