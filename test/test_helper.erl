-module(test_helper).

-include("cqerl.hrl").

-export([standard_setup/2,
         get_client/1,
         maybe_get_client/1,
         create_keyspace/2,
         requirements/0,
         set_mode/2
        ]).


standard_setup(Keyspace, Config) ->
    application:ensure_all_started(cqerl),
    application:start(sasl),
    RawSSL = ct:get_config(ssl),
    DataDir = proplists:get_value(data_dir, Config),
    SSL = case RawSSL of
        undefined -> false;
        false -> false;
        _ ->
            %% To relative file paths for SSL, prepend the path of
            %% the test data directory. To bypass this behavior, provide
            %% an absolute path.
            lists:map(fun
                ({FileOpt, Path}) when FileOpt == cacertfile;
                                       FileOpt == certfile;
                                       FileOpt == keyfile ->
                    case Path of
                        [$/ | _Rest] -> {FileOpt, Path};
                        _ -> {FileOpt, filename:join([DataDir, Path])}
                    end;

                (Opt) -> Opt
            end, RawSSL)
    end,
    [ {auth, ct:get_config(auth)},
      {ssl, RawSSL},
      {prepared_ssl, SSL},
      {keyspace, Keyspace},
      {host, ct:get_config(host)},
      {pool_min_size, ct:get_config(pool_min_size)},
      {pool_max_size, ct:get_config(pool_max_size)},
      {protocol_version, ct:get_config(protocol_version)} ] ++ Config.

% Call when you're expecting a valid client
get_client(Config) ->
    {ok, Client} = maybe_get_client(Config),
    Client.

% Call to test new_client/get_client error cases
maybe_get_client(Config) ->
    Host = proplists:get_value(host, Config),
    SSL = proplists:get_value(prepared_ssl, Config),
    Auth = proplists:get_value(auth, Config, undefined),
    Keyspace = proplists:get_value(keyspace, Config),
    PoolMinSize = proplists:get_value(pool_min_size, Config),
    PoolMaxSize = proplists:get_value(pool_max_size, Config),
    ProtocolVersion = proplists:get_value(protocol_version, Config),


%    io:format("Options : ~w~n", [[
%        {ssl, SSL}, {auth, Auth}, {keyspace, Keyspace},
%        {pool_min_size, PoolMinSize}, {pool_max_size, PoolMaxSize}
%        ]]),

    Fun = case proplists:get_value(mode, Config, pooler) of
              pooler -> fun cqerl:new_client/2;
              hash -> fun cqerl:get_client/2
          end,

    Fun(Host, [{ssl, SSL}, {auth, Auth}, {keyspace, Keyspace},
               {pool_min_size, PoolMinSize}, {pool_max_size, PoolMaxSize}, 
               {protocol_version, ProtocolVersion} ]).

create_keyspace(KS, Config) ->
    Client = get_client([{keyspace, undefined} | Config]),
    Q = <<"CREATE KEYSPACE ", KS/binary, " WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};">>,
    D = <<"DROP KEYSPACE ", KS/binary>>,
    case cqerl:run_query(Client, #cql_query{statement=Q}) of
        {ok, #cql_schema_changed{change_type=created, keyspace = KS}} -> ok;
        {error, {16#2400, _, {key_space, KS}}} ->
            {ok, #cql_schema_changed{change_type=dropped, keyspace = KS}} = cqerl:run_query(Client, D),
            {ok, #cql_schema_changed{change_type=created, keyspace = KS}} = cqerl:run_query(Client, Q)
    end,
    cqerl:close_client(Client).

requirements() ->
    [
     {require, ssl, cqerl_test_ssl},
     {require, protocol_version, cqerl_protocol_version},
     {require, auth, cqerl_test_auth},
     % {require, keyspace, cqerl_test_keyspace},
     {require, host, cqerl_host},
     {require, pool_min_size, pool_min_size},
     {require, pool_max_size, pool_max_size}
    ].

set_mode(Mode, Config) ->
    application:stop(cqerl),
    application:set_env(cqerl, mode, Mode),
    application:start(cqerl),
    [{mode, Mode} | proplists:delete(mode, Config)].
