%% common_test suite for test

-module(integrity_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-include("cqerl.hrl").
-include("cqerl_protocol.hrl").

-compile(export_all).

%%--------------------------------------------------------------------
%% Function: suite() -> Info
%%
%% Info = [tuple()]
%%   List of key/value pairs.
%%
%% Description: Returns list of tuples to set default properties
%%              for the suite.
%%
%% Note: The suite/0 function is only meant to be used to return
%% default data values, not perform any other operations.
%%--------------------------------------------------------------------
suite() ->
  [{timetrap, {seconds, 40}} | test_helper:requirements()].

%%--------------------------------------------------------------------
%% Function: groups() -> [Group]
%%
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%%   The name of the group.
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%%   Group properties that may be combined.
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%%   The name of a test case.
%% Shuffle = shuffle | {shuffle,Seed}
%%   To get cases executed in random order.
%% Seed = {integer(),integer(),integer()}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%%   To get execution of cases repeated.
%% N = integer() | forever
%%
%% Description: Returns a list of test case group definitions.
%%--------------------------------------------------------------------

connection_tests() ->
    [
     create_keyspace
    ].

database_tests() ->
    [
     create_table,
     simple_insertion_roundtrip,
     async_insertion_roundtrip,
     emptiness,
     missing_prepared_query,
     missing_prepared_batch,
     options,
     {transactions,
      [
       {types,
        [
         all_datatypes,
         % custom_encoders,
         collection_types,
         counter_type,
         varint_type,
         decimal_type
        ]},
       batches_and_pages
      ]}
    ].


groups() ->
    [
     {init, [], connection_tests()},
     {main_tests, [], database_tests()}
    ].

%%--------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases
%%
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%%   Name of a test case group.
%% TestCase = atom()
%%   Name of a test case.
%%
%% Description: Returns the list of groups and test cases that
%%              are to be executed.
%%
%%      NB: By default, we export all 1-arity user defined functions
%%--------------------------------------------------------------------
all() ->
    [datatypes_test,
     protocol_test,
     {group, init},
     {group, main_tests}
    ].

%%--------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the suite.
%%
%% Description: Initialization before the suite.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    application:ensure_started(cqerl),
    Config2 = test_helper:standard_setup(Config),
    Config2.

%%--------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%%
%% Description: Cleanup after the suite.
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
    ok.

%%--------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%% Reason = term()
%%   The reason for skipping all test cases and subgroups in the group.
%%
%% Description: Initialization before each test case group.
%%--------------------------------------------------------------------

init_per_group(init, Config) ->
    Hosts = ct:get_config(cqerl_hosts),
    cqerl:add_group(Hosts, Config, 10),
    Config;
init_per_group(main_tests, Config) ->
    NewConfig = [{keyspace, "test_keyspace_2"} | Config],
    Hosts = ct:get_config(cqerl_hosts),
    cqerl:add_group(Hosts, NewConfig, 10),
    NewConfig;
init_per_group(_, Config) ->
    Config.

%%--------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%               void() | {save_config,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%%
%% Description: Cleanup after each test case group.
%%--------------------------------------------------------------------
end_per_group(_, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% Function: init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% TestCase = atom()
%%   Name of the test case that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%%
%% Description: Initialization before each test case.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    Config.

%%--------------------------------------------------------------------
%% Function: end_per_testcase(TestCase, Config0) ->
%%               void() | {save_config,Config1} | {fail,Reason}
%%
%% TestCase = atom()
%%   Name of the test case that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for failing the test case.
%%
%% Description: Cleanup after each test case.
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, Config) ->
    Config.

datatypes_test(_Config) ->
    ok = eunit:test(cqerl_datatypes).

protocol_test(_Config) ->
    ok = eunit:test(cqerl_protocol).

create_keyspace(Config) ->
    test_helper:create_keyspace(<<"test_keyspace_2">>, Config).

create_table(_Config) ->
    Q = "CREATE TABLE entries1(id varchar, age int, email varchar, PRIMARY KEY(id));",
    {ok, #cql_schema_changed{change_type=created, keyspace = <<"test_keyspace_2">>, name = <<"entries1">>}} =
    cqerl:run_query(#cql_query{statement = Q, keyspace = test_keyspace_2}),
    ct:log("Agreement wait: ~p", [timer:tc(fun cqerl:wait_for_schema_agreement/0)]),
    ct:log("Schemas: ~p", [ets:tab2list(cqerl_nodes)]).

simple_insertion_roundtrip(_Config) ->
    timer:sleep(3000),
    ct:log("Schemas: ~p", [ets:tab2list(cqerl_nodes)]),
    Q = <<"INSERT INTO entries1(id, age, email) VALUES (?, ?, ?)">>,
    {ok, void} = cqerl:run_query(#cql_query{
                                    statement=Q,
                                    keyspace = test_keyspace_2,
                                    values= #{id => "hello",
                                              age => 18,
                                              email => <<"mathieu@damours.org">>}
                                   }),
    {ok, Result=#cql_result{}} = cqerl:run_query(#cql_query{statement = <<"SELECT * FROM entries1;">>, keyspace = test_keyspace_2}),
    Row = cqerl:head(Result),
    <<"hello">> = maps:get(id, Row),
    18 = maps:get(age, Row),
    <<"mathieu@damours.org">> = maps:get(email, Row),
    Result.

emptiness(_Config) ->
    {ok, void} = cqerl:run_query(test_keyspace_2, "update entries1 set email = null where id = 'hello';"),
    {ok, Result} = cqerl:run_query(test_keyspace_2, "select * from entries1 where id = 'hello';"),
    Row = cqerl:head(Result),
    null = maps:get(email, Row),
    {ok, void} = cqerl:run_query(#cql_query{statement="update entries1 set age = ? where id = 'hello';",
                                            values= #{age => null},
                                            keyspace=test_keyspace_2
                                           }),
    {ok, Result2} = cqerl:run_query(test_keyspace_2, "select * from entries1 where id = 'hello';"),
    Row2 = cqerl:head(Result2),
    null = maps:get(age, Row2).

missing_prepared_query(_Config) ->
    Q = <<"INSERT INTO entries1(id, age, email) VALUES (?, ?, ?)">>,
    {ok, _Result} = cqerl:run_query(#cql_query{statement = Q,
                                               values = #{id => "abc",
                                                          age => 22,
                                                          email => "me@here.com"},
                                               keyspace = test_keyspace_2}),
    %% This query causes prepared queries on the table to be invalidated:
    {ok, _} = cqerl:run_query(test_keyspace_2, "ALTER TABLE entries1 ADD newcol int"),
    cqerl:wait_for_schema_agreement(),
    %% This query will attempt to use the prepared query and fail, falling back to re-preparing it:
    {ok, _Result2} = cqerl:run_query(#cql_query{statement = Q,
                                                values = #{id => "def",
                                                           age => 22,
                                                           email => "me@here.com"},
                                                keyspace = test_keyspace_2}).

missing_prepared_batch(_Config) ->
    S1 = <<"INSERT INTO entries1(id, age, email) VALUES (?, ?, ?)">>,
    V1 = maps:from_list([{id, "abc"}, {age, 22}, {email, "me@here.com"}]),
    Q1 = #cql_query{statement = S1, values = V1},


    S2 = "INSERT INTO entries1(id, age) VALUES (?, ?)",
    V2 = maps:from_list([ {id, "fff"}, {age, 66} ]),
    Q2 = #cql_query{statement = S2, values = V2},

    Batch = #cql_query_batch{queries = [Q1, Q2], keyspace = test_keyspace_2},
    {ok, _Result} = cqerl:run_query(Batch),
    %% This query causes prepared queries on the table to be invalidated:
    {ok, _} = cqerl:run_query(test_keyspace_2, "ALTER TABLE entries1 ADD newcol2 int"),
    cqerl:wait_for_schema_agreement(),
    %% This query will attempt to use the prepared queries and fail, falling back to re-preparing them:
    {ok, _Result} = cqerl:run_query(Batch).

async_insertion_roundtrip(_Config) ->
    {ok, Ref} = cqerl:send_query(#cql_query{
        statement = <<"INSERT INTO entries1(id, age, email) VALUES (?, ?, ?)">>,
        values = maps:from_list([
            {id, "1234123"},
            {age, 45},
            {email, <<"yvon@damours.org">>}
        ]),
        keyspace = test_keyspace_2
    }),
    receive {cqerl_result, Ref, void} -> ok end,

    {ok, Ref2} = cqerl:send_query(#cql_query{statement = <<"SELECT * FROM entries1;">>, keyspace = test_keyspace_2}),
    receive
        {cqerl_result, Ref2, Result=#cql_result{}} ->
            {_Row, Result2} = cqerl:next(Result),
            Row = cqerl:head(Result2),
            <<"1234123">> = maps:get(id, Row),
            45 = maps:get(age, Row),
            <<"yvon@damours.org">> = maps:get(email, Row);
        Other ->
            ct:fail("Received: ~p~n", [Other])
    end.

%cache_cleanup(_Config) ->
%    Q = <<"INSERT INTO entries1(id, age, email) VALUES (?, ?, ?)">>,
%    CQLQuery = #cql_query{statement = Q, values = [{id, "abc"}, {age, 22}, {email, "me@here.com"}]},
%    {ok, _Result} = cqerl:run_query(CQLQuery),
%    % Query should now be cached:
%    ?assertMatch(#cqerl_cached_query{}, cqerl_cache:lookup(ClientPID, CQLQuery)),
%    exit(ClientPID, crash),
%    timer:sleep(250),
%    ?assertEqual(queued, cqerl_cache:lookup(ClientPID, CQLQuery)).

datatypes_columns(Cols) ->
    datatypes_columns(1, Cols, <<>>).

datatypes_columns(_I, [], Bin) -> Bin;
datatypes_columns(I, [ColumnType|Rest], Bin) ->
    Column = list_to_binary(io_lib:format("col~B ~s, ", [I, ColumnType])),
    datatypes_columns(I+1, Rest, << Bin/binary, Column/binary >>).

all_datatypes(Config) ->
    Time = {23, 4, 123},
    Date = {1970, 1, 1},
    AbsTime = (12 * 3600 + 4 * 60 + 123) * math:pow(10, 9),

    {Cols, InsQ, RRow1, RRow2} = case proplists:get_value(protocol_version, Config) of
        3 ->
            {
                datatypes_columns([ascii, bigint, blob, boolean, decimal, double,
                                  float, int, timestamp, uuid, varchar,
                                  timeuuid, inet, varint]),

                #cql_query{statement = <<"INSERT INTO entries2(col1, col2, col3,
                                    col4, col5, col6, col7, col8, col9, col10,
                                    col11, col12, col13, col14
                                    ) VALUES (?, ?, ?, ?, ?, ?, ?,
                                    ?, ?, ?, ?, ?, ?, ?)">>,
                           keyspace = test_keyspace_2
                          },

                maps:from_list([
                    {col1, "hello"},
                    {col2, 9223372036854775807},
                    {col3, <<1,2,3,4,5,6,7,8,9,10>>},
                    {col4, true},
                    {col5, {1234, 5}},
                    {col6, 5.1235131241221e-6},
                    {col7, 5.12351e-6},
                    {col8, 2147483647},
                    {col9, now},
                    {col10, new},
                    {col11, <<"Юникод"/utf8>>},
                    {col12, now},
                    {col13, {127, 0, 0, 1}},
                    {col14, 666}
                ]),
                maps:from_list([
                    {col1, <<"foobar">>},
                    {col2, -9223372036854775806},
                    {col3, <<1,2,3,4,5,6,7,8,9,10>>},
                    {col4, false},
                    {col5, {1234, -5}},
                    {col6, -5.1235131241220e-6},
                    {col7, -5.12351e-6},
                    {col8, -2147483646},
                    {col9, 1984336643},
                    {col10, <<22,6,195,126,110,122,64,242,135,15,38,179,46,108,22,64>>},
                    {col11, <<"åäö"/utf8>>},
                    {col12, <<250,10,224,94,87,197,17,227,156,99,146,79,0,0,0,195>>},
                    {col13, {0,0,0,0,0,0,0,0}},
                    {col14, 666}
                ])
            };

        _ ->
            {
                datatypes_columns([ascii, bigint, blob, boolean, decimal, double,
                                  float, int, timestamp, uuid, varchar, timeuuid, inet, varint, 
                                  tinyint, smallint, date, time]),

                #cql_query{statement = <<"INSERT INTO entries2(col1, col2, col3,
                                        col4, col5, col6, col7, col8, col9, col10,
                                        col11, col12, col13, col14, col15, col16,
                                        col17, col18) VALUES (?, ?, ?, ?, ?, ?, ?,
                                        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)">>,
                           keyspace = test_keyspace_2
                          },
                maps:from_list([
                    {col1, "hello"},
                    {col2, 9223372036854775807},
                    {col3, <<1,2,3,4,5,6,7,8,9,10>>},
                    {col4, true},
                    {col5, {1234, 5}},
                    {col6, 5.1235131241221e-6},
                    {col7, 5.12351e-6},
                    {col8, 2147483647},
                    {col9, now},
                    {col10, new},
                    {col11, <<"Юникод"/utf8>>},
                    {col12, now},
                    {col13, {127, 0, 0, 1}},
                    {col14, 666},
                    {col15, 120},
                    {col16, 1200},
                    {col17, Date},
                    {col18, Time}
                ]),
                maps:from_list([
                    {col1, <<"foobar">>},
                    {col2, -9223372036854775806},
                    {col3, <<1,2,3,4,5,6,7,8,9,10>>},
                    {col4, false},
                    {col5, {1234, -5}},
                    {col6, -5.1235131241220e-6},
                    {col7, -5.12351e-6},
                    {col8, -2147483646},
                    {col9, 1984336643},
                    {col10, <<22,6,195,126,110,122,64,242,135,15,38,179,46,108,22,64>>},
                    {col11, <<"åäö"/utf8>>},
                    {col12, <<250,10,224,94,87,197,17,227,156,99,146,79,0,0,0,195>>},
                    {col13, {0,0,0,0,0,0,0,0}},
                    {col14, 666},
                    {col15, -120},
                    {col16, -1200},
                    {col17, Date},
                    {col18, AbsTime}
                ])
            }
    end,

    CreationQ = <<"CREATE TABLE entries2(",  Cols/binary, " PRIMARY KEY(col1));">>,
    ct:log("Executing : ~s~n", [CreationQ]),
    {ok, #cql_schema_changed{change_type=created, keyspace = <<"test_keyspace_2">>, name = <<"entries2">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    {ok, void} = cqerl:run_query(InsQ#cql_query{values=RRow2}),
    {ok, void} = cqerl:run_query(InsQ#cql_query{values=RRow1}),
    {ok, void} = cqerl:run_query(InsQ#cql_query{
        statement="INSERT INTO entries2(col1, col11) values (?, ?);",
        values=RRow3=maps:from_list([ {col1, foobaz}, {col11, 'åäö'} ])
    }),

    {ok, Result=#cql_result{}} = cqerl:run_query(#cql_query{statement = <<"SELECT * FROM entries2;">>, keyspace = test_keyspace_2}),
    {Row1, Result1} = cqerl:next(Result),
    {Row2, Result2} = cqerl:next(Result1),
    {Row3, _Result3} = cqerl:next(Result2),
    lists:foreach(fun
        (Row) -> 
            ReferenceRow = case maps:get(col1, Row) of
                <<"hello">> -> RRow1;
                <<"foobar">> -> RRow2;
                <<"foobaz">> -> RRow3
            end,
            lists:foreach(fun
                ({col12, _}) -> true = uuid:is_v1(maps:get(col12, Row));
                ({col10, _}) -> true = uuid:is_v4(maps:get(col10, Row));
                ({col9, _}) -> ok; %% Yeah, I know...
                
                ({col16, {Y, M, D}}) ->
                    {Y, M, D} = maps:get(col16, Row);

                ({col18, _}) -> maps:get(col18, Row) == AbsTime;

                ({col1, Key}) when is_list(Key) ->
                    Val = list_to_binary(Key),
                    Val = maps:get(col1, Row);

                ({Col, Key}) when is_atom(Key), Col == col1 orelse Col == col11 ->
                    Val = atom_to_binary(Key, utf8),
                    Val = maps:get(Col, Row);
                    
                ({col7, Val0}) ->
                    Val = round(Val0 * 1.0e11),
                    Val = round(maps:get(col7, Row) * 1.0e11);

                ({Key, Val}) ->
                    Val = maps:get(Key, Row, null)
            end, maps:to_list(ReferenceRow))
    end, [Row1, Row2, Row3]),
    [Row1, Row2, Row3].

custom_encoders(_Config) ->

    Cols = datatypes_columns([varchar, varchar, varchar]),
    CreationQ = <<"CREATE TABLE entries2_1(",  Cols/binary, " PRIMARY KEY(col1, col2, col3));">>,
    ct:log("Executing : ~s~n", [CreationQ]),
    {ok, #cql_schema_changed{change_type=created, keyspace = <<"test_keyspace_2">>, name = <<"entries2_1">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    InsQ = #cql_query{statement = <<"INSERT INTO entries2_1(col1, col2, col3) VALUES (?, ?, ?)">>, keyspace = test_keyspace_2},
    {ok, void} = cqerl:run_query(InsQ#cql_query{values=RRow1=maps:from_list([
        {col1, <<"test">>},
        {col2, <<"hello">>},
        {col3, <<"testing tuples">>}
    ])}),
    {ok, void} = cqerl:run_query(InsQ#cql_query{values=RRow2=maps:from_list([
        {col1, <<"test">>},
        {col2, <<"nice to have">>},
        {col3, <<"custom encoder">>}
    ])}),

    {ok, Result=#cql_result{}} = cqerl:run_query(#cql_query{
        statement = <<"SELECT * FROM entries2_1 WHERE col1 = ? AND (col2,col3) IN ?;">>,
        keyspace = test_keyspace_2,
        values = maps:from_list([
            {col1, <<"test">>},
            {'in(col2,col3)', [
                {<<"hello">>,<<"testing tuples">>},
                {<<"nice to have">>,<<"custom encoder">>}
            ]}
        ]),

        % provide custom encoder for TupleType
        value_encode_handler = fun({{custom, <<"org.apache.cassandra.db.marshal.TupleType", _Rest/binary>>}, Tuple}, Query) ->
            GetElementBinary = fun(Value) -> 
                Bin = cqerl_datatypes:encode_data({text, Value}, Query),
                Size = size(Bin),
                <<Size:32/big-signed-integer, Bin/binary>>
            end,

            << << (GetElementBinary(Value))/binary >> || Value <- tuple_to_list(Tuple) >>
        end
    }),

    [RRow1, RRow2] = cqerl:all_rows(Result),

    ok.

options(_Config) ->
    application:set_env(cqerl, maps, true),
    application:set_env(cqerl, text_uuids, true),
    Cols = datatypes_columns([timeuuid, uuid]),
    CreationQ = <<"CREATE TABLE entries2_2(",  Cols/binary, " PRIMARY KEY(col1));">>,
    ct:log("Executing : ~s~n", [CreationQ]),
    {ok, #cql_schema_changed{change_type=created, keyspace = <<"test_keyspace_2">>, name = <<"entries2_2">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    UUIDState = uuid:new(self()),
    {TimeUUID, _} = uuid:get_v1(UUIDState),
    UUID = uuid:get_v4(),

    InsQ = #cql_query{statement = <<"INSERT INTO entries2_2(col1, col2) VALUES (?, ?)">>,
                      keyspace = test_keyspace_2},
    {ok, void} = cqerl:run_query(InsQ#cql_query{values=maps:from_list([
        {col1, TimeUUID},
        {col2, UUID}
    ])}),

    {ok, Result=#cql_result{}} = cqerl:run_query(#cql_query{statement = <<"SELECT * FROM entries2_2;">>,
                                                            keyspace = test_keyspace_2}),

    TextTimeUUID = uuid:uuid_to_string(TimeUUID, binary_standard),
    TextUUID = uuid:uuid_to_string(UUID, binary_standard),

    [#{col1 := TextTimeUUID,
       col2 := TextUUID}] = cqerl:all_rows(Result),

    application:unset_env(cqerl, maps),
    application:unset_env(cqerl, text_uuids).

collection_types(_Config) ->
    CreationQ = <<"CREATE TABLE entries3(key varchar, numbers list<int>, names set<varchar>, phones map<varchar, varchar>, PRIMARY KEY(key));">>,
    ct:log("Executing : ~s~n", [CreationQ]),
    {ok, #cql_schema_changed{change_type=created, keyspace = <<"test_keyspace_2">>, name = <<"entries3">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    {ok, void} = cqerl:run_query(#cql_query{
        statement = <<"INSERT INTO entries3(key, numbers, names, phones) values (?, ?, ?, ?);">>,
        values = maps:from_list([
            {key, "First collection"},
            {numbers, [1,2,3,4,5]},
            {names, ["matt", "matt", "yvon"]},
            {phones, [{<<"home">>, <<"418-123-4545">>}, {"work", "555-555-5555"}]}
        ]),
         keyspace = test_keyspace_2
    }),

    {ok, void} = cqerl:run_query(#cql_query{
        statement = "UPDATE entries3 SET names = names + {'martin'} WHERE key = ?",
        values = #{key => "First collection"},
         keyspace = test_keyspace_2
    }),

    {ok, Result=#cql_result{}} = cqerl:run_query(#cql_query{statement = "SELECT * FROM entries3;",
                                                            keyspace = test_keyspace_2}),
    Row = cqerl:head(Result),
    <<"First collection">> = maps:get(key, Row),
    [1,2,3,4,5] = maps:get(numbers, Row),
    Names = maps:get(names, Row),
    3 = length(Names),
    true = lists:member(<<"matt">>, Names),
    true = lists:member(<<"yvon">>, Names),
    true = lists:member(<<"martin">>, Names),
    #{<<"home">> := <<"418-123-4545">>, <<"work">> := <<"555-555-5555">>} = maps:get(phones, Row),
    Row.

counter_type(_Config) ->

    CreationQ = <<"CREATE TABLE entries4(key varchar, count counter, PRIMARY KEY(key));">>,
    ct:log("Executing : ~s~n", [CreationQ]),
    {ok, #cql_schema_changed{change_type=created, keyspace = <<"test_keyspace_2">>, name = <<"entries4">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    {ok, void} = cqerl:run_query(#cql_query{
        statement = <<"UPDATE entries4 SET count = count + ? WHERE key = ?;">>,
        values = maps:from_list([
            {key, "First counter"},
            {count, 18}
        ]),
         keyspace = test_keyspace_2
    }),

    {ok, void} = cqerl:run_query(#cql_query{
        statement = "UPDATE entries4 SET count = count + 10 WHERE key = ?;",
        values = #{key => "First counter"},
         keyspace = test_keyspace_2
    }),

    {ok, Result=#cql_result{}} = cqerl:run_query(#cql_query{statement = "SELECT * FROM entries4;",
                                                            keyspace = test_keyspace_2}),
    Row = cqerl:head(Result),
    <<"First counter">> = maps:get(key, Row),
    28 = maps:get(count, Row),
    Row.


varint_type(_Config) ->

    CreationQ = "CREATE TABLE varint_test (key varint PRIMARY KEY, sval text)",
    ct:log("Executing : ~s~n", [CreationQ]),

    {ok, #cql_schema_changed{change_type=created,
                             keyspace = <<"test_keyspace_2">>,
                             name = <<"varint_test">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    Statement = "INSERT INTO varint_test(key, sval) VALUES (?, ?)",

    TestVals = varint_test_ranges(),
    lists:foreach(fun(K) ->
                          ct:log("Running for ~p", [K]),
      {ok, void} =
      cqerl:run_query( #cql_query{statement = Statement,
                                 values = maps:from_list(
                                            [{key, K},
                                             {sval, integer_to_list(K)}
                                            ]),
                                  keyspace = test_keyspace_2})
      end,
      TestVals),

    Statement2 = "SELECT * FROM varint_test",
    {ok, Result} = cqerl:run_query(#cql_query{statement = Statement2,
                                              page_size = 2000,
                                              keyspace = test_keyspace_2}),
    Rows = cqerl:all_rows(Result),
    Vals = lists:sort(check_extract_varints(Rows)),
    ct:log("Vals ~p ~p: ~p", [length(Rows), length(Vals), Vals]),
    Vals = lists:sort(TestVals).

varint_test_ranges() ->
    Ranges = [
              % Small ints:
              {0, 300},
              % Signed 16-bit:
              {32700, 32800},
              % Unsigned 16-bit:
              {65530, 65540},
              % Huge ints:
              {100000000000000000000000, 100000000000000000000099},
              % Super Huge ints - way more than 2^64:
              {100000000000000000000000000000000000000000000000,
               100000000000000000000000000000000000000000000099},
              % Small negative:
              {-5, -1},
              {-133, -125},
              % Signed 16-bit
              {-32780, -32760},
              % Signed 32-bit
              {-65544, -65531},
              {-100000000000000000000099, -100000000000000000000000},
              % Super Huge -ve ints - way more than 2^64:
              {-100000000000000000000000000000000000000000000111,
               -100000000000000000000000000000000000000000000005}
             ],
    lists:flatten([lists:seq(L, H) || {L, H} <- Ranges]).

check_extract_varints(Rows) ->
    Ints = [maps:get(key, Row) || Row <- Rows],
    CheckInts = [binary_to_integer(maps:get(sval, Row))
                 || Row <- Rows],
    Ints = CheckInts,
    Ints.

decimal_type(_Config) ->

    CreationQ = "CREATE TABLE decimal_test (key decimal PRIMARY KEY,
                 scale int, unscaled varint)",
    ct:log("Executing : ~s~n", [CreationQ]),

    {ok, #cql_schema_changed{change_type=created,
                             keyspace = <<"test_keyspace_2">>,
                             name = <<"decimal_test">>}} =
        cqerl:run_query(test_keyspace_2, CreationQ),
    cqerl:wait_for_schema_agreement(),

    Statement = "INSERT INTO decimal_test(key, scale, unscaled)
                 VALUES (?, ?, ?)",

    TestVals = decimal_test_ranges(),
    lists:foreach(fun({U, S}) ->
      {ok, void} =
      cqerl:run_query(#cql_query{statement = Statement,
                                 values = maps:from_list(
                                            [{key, {U, S}},
                                             {unscaled, U},
                                             {scale, S}
                                          ]),
                                 keyspace = test_keyspace_2})
      end,
      TestVals),

    Statement2 = "SELECT * FROM decimal_test",
    {ok, Result} = cqerl:run_query(#cql_query{statement =
                                                      Statement2,
                                                     page_size = 20000,
                                              keyspace = test_keyspace_2}),
    Rows = cqerl:all_rows(Result),
    Vals = lists:sort(check_extract_decimals(Rows)),
    ct:log("Vals ~p ~p: ~p", [length(TestVals), length(Vals), Vals]),
    Vals = lists:sort(TestVals).

decimal_test_ranges() ->
    [{U, S} || U <- varint_test_ranges(),
               S <- lists:seq(-5, 5) ++ [2147483647, -2147483648]].

check_extract_decimals(Rows) ->
    Decimals = [maps:get(key, Row) || Row <- Rows],
    CheckUnScales = [maps:get(unscaled, Row) || Row <- Rows],
    CheckScales = [maps:get(scale, Row) || Row <- Rows],
    {Unscales, Scales} = lists:unzip(Decimals),
    ct:log("Unscales: ~p~n", [Unscales]),
    Unscales = CheckUnScales,
    ct:log("Scales: ~p~n", [Scales]),
    Scales = CheckScales,
    Decimals.

inserted_rows(0, _Q, Acc) ->
    lists:reverse(Acc);
inserted_rows(N, Q, Acc) ->
    ID = list_to_binary(io_lib:format("~B", [N])),
    inserted_rows(N-1, Q, [ Q#cql_query{values=
                                        maps:from_list(
                                          [
                                           {id, ID}, 
                                           {age, 10+N}, 
                                           {email, list_to_binary(["test", ID, "@gmail.com"])}
                                          ])} | Acc ]).

batches_and_pages(_Config) ->
    T1 = os:timestamp(),
    N = 80,
    Bsz = 25,
    {ok, void} = cqerl:run_query(test_keyspace_2, "TRUNCATE entries1;"),
    Q = #cql_query{statement = <<"INSERT INTO entries1(id, age, email) VALUES (?, ?, ?)">>},
    Batch = #cql_query_batch{queries=inserted_rows(N, Q, []), keyspace = test_keyspace_2},
    ct:log("Batch : ~w~n", [Batch]),
    {ok, void} = cqerl:run_query(Batch),
    AddIDs = fun (Result, IDs0) ->
        lists:foldr(fun (Row, IDs) ->
                        ID = maps:get(id, Row),
                        {IDint, _} = string:to_integer(binary_to_list(ID)),
                        IDint = maps:get(age, Row) - 10,
                        IDsize = size(ID),
                        << _:4/binary, ID:IDsize/binary, _Rest/binary >> = maps:get(email, Row),
                        gb_sets:add(ID, IDs) 
                    end, 
                    IDs0, cqerl:all_rows(Result))
    end,
    {ok, Result} = cqerl:run_query(#cql_query{page_size=Bsz, statement="SELECT * FROM entries1;",
                                              keyspace = test_keyspace_2}),
    IDs1 = AddIDs(Result, gb_sets:new()),

    {ok, Result2} = cqerl:fetch_more(Result),
    Ref1 = cqerl:fetch_more_async(Result2),
    IDs2 = AddIDs(Result2, IDs1),
    {FetchMoreRef, IDs3} = receive
        {cqerl_result, Ref1, Result3} ->
            Ref2 = cqerl:fetch_more_async(Result3),
            {Ref2, AddIDs(Result3, IDs2)}
    end,
    receive
        {cqerl_result, FetchMoreRef, Result4} ->
            IDs4 = AddIDs(Result4, IDs3),
            N = gb_sets:size(IDs4)
    end,
    ct:log("Time elapsed inserting ~B entries and fetching in batches of ~B: ~B ms",
           [N, Bsz, round(timer:now_diff(os:timestamp(), T1)/1000)]).
