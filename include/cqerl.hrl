-define(CQERL_CONSISTENCY_ANY,          0).
-define(CQERL_CONSISTENCY_ONE,          1).
-define(CQERL_CONSISTENCY_TWO,          2).
-define(CQERL_CONSISTENCY_THREE,        3).
-define(CQERL_CONSISTENCY_QUORUM,       4).
-define(CQERL_CONSISTENCY_ALL,          5).
-define(CQERL_CONSISTENCY_LOCAL_QUORUM, 6).
-define(CQERL_CONSISTENCY_EACH_QUORUM,  7).
-define(CQERL_CONSISTENCY_SERIAL,       8).
-define(CQERL_CONSISTENCY_LOCAL_SERIAL, 9).
-define(CQERL_CONSISTENCY_LOCAL_ONE,    10).

-define(CQERL_BATCH_LOGGED,   0).
-define(CQERL_BATCH_UNLOGGED, 1).
-define(CQERL_BATCH_COUNTER,  2).

-define(CQERL_EVENT_TOPOLOGY_CHANGE,  'TOPOLOGY_CHANGE').
-define(CQERL_EVENT_STATUS_CHANGE,    'STATUS_CHANGE').
-define(CQERL_EVENT_SCHEMA_CHANGE,    'SCHEMA_CHANGE').

-define(CQERL_IS_CLIENT(Client), 
    is_tuple(Client) andalso 
    tuple_size(Client) == 2 andalso 
    is_pid(element(1, Client)) andalso 
    is_reference(element(2, Client))
).

-define(CQERL_PARSE_ADDR (Addr), case erlang:function_exported(inet, parse_address, 1) of
    true -> inet:parse_address(Addr);
    false -> inet_parse:address(Addr)
  end).

-type consistency_level_int() :: ?CQERL_CONSISTENCY_ANY .. ?CQERL_CONSISTENCY_EACH_QUORUM | ?CQERL_CONSISTENCY_LOCAL_ONE.
-type consistency_level() :: any | one | two | three | quorum | all | local_quorum | each_quorum | local_one.

-type serial_consistency_int() :: ?CQERL_CONSISTENCY_SERIAL | ?CQERL_CONSISTENCY_LOCAL_SERIAL.
-type serial_consistency() :: serial | local_serial.

-type batch_mode_int() :: ?CQERL_BATCH_LOGGED | ?CQERL_BATCH_UNLOGGED | ?CQERL_BATCH_COUNTER.
-type batch_mode() :: logged | unlogged | counter.

-type column_type() ::
  {custom, binary()} |
  {map, column_type(), column_type()} |
  {set | list, column_type()} | datatype().

-type datatype() :: ascii | bigint | blob | boolean | counter | decimal | double | 
                    float | int | timestamp | uuid | varchar | varint | timeuuid | inet.
  
-type parameter_val() :: number() | binary() | list() | atom() | boolean().
-type parameter() :: { datatype(), parameter_val() }.
-type named_parameter() :: { atom(), parameter_val() }.

-record(cql_query, {
    statement   = <<>>      :: iodata(),
    values      = []        :: [ parameter() | named_parameter() ] | maps:map(),

    reusable    = undefined :: undefined | boolean(),
    named       = false     :: boolean(),
    
    page_size   = 100       :: integer(),
    page_state              :: binary() | undefined,
    
    consistency = one :: consistency_level() | consistency_level_int(),
    serial_consistency = undefined :: serial_consistency() | serial_consistency_int() | undefined,

    value_encode_handler = undefined :: function() | undefined
}).

-record(cql_call, {
    type :: sync | async,
    caller :: {pid(), reference()},
    client :: reference()
}).

-record(cql_query_batch, {
    consistency         = one :: consistency_level() | consistency_level_int(),
    mode                = logged :: batch_mode() | batch_mode_int(),
    queries             = [] :: list(tuple())
}).

-record(cql_result, {
    columns         = []        :: list(tuple()),
    dataset         = []        :: list(list(term())),
    cql_query                   :: #cql_query{},
    client                      :: {pid(), reference()}
}).

-record(cql_schema_changed, {
    change_type :: created | updated | dropped,
    target      :: atom(),
    keyspace    :: binary(),
    name        :: binary(),
    args        :: [ binary() ]
}).
