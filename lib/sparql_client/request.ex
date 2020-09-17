defmodule SPARQL.Client.Request do
  @doc false

  defstruct [
    :sparql_operation,
    :sparql_operation_type,
    :sparql_operation_form,
    :sparql_endpoint,
    :sparql_protocol_version,
    :sparql_graph_params,
    :http_method,
    :http_headers,
    :http_content_type_header,
    :http_accept_header,
    :http_body,
    :http_status,
    :http_response_content_type,
    :http_response_body,
    :result
  ]

  @type protocol_version :: String.t()
  @type http_method :: :get | :post

  @type t :: %__MODULE__{
          sparql_operation: SPARQL.Query.t() | RDF.Data.t(),
          sparql_operation_type: module,
          sparql_operation_form: atom,
          sparql_endpoint: String.t(),
          sparql_protocol_version: protocol_version,
          sparql_graph_params: list,
          http_method: http_method,
          http_headers: map,
          http_content_type_header: String.t(),
          http_accept_header: String.t(),
          http_body: String.t() | nil,
          http_status: pos_integer,
          http_response_content_type: String.t(),
          http_response_body: String.t(),
          result: SPARQL.Query.Result.t() | RDF.Data.t()
        }

  def build(operation, endpoint, opts \\ [])

  def build(operation, endpoint, opts) do
    %__MODULE__{
      sparql_endpoint: endpoint,
      sparql_graph_params: graph_params(opts)
    }
    |> init_operation(operation, opts)
  end

  defp init_operation(request, %SPARQL.Query{} = query, opts) do
    SPARQL.Client.Query.init(request, query, opts)
  end

  defp init_operation(request, {update_data_form, _} = update_data, opts)
       when update_data_form in ~w[insert delete]a do
    SPARQL.Client.UpdateData.init(request, update_data, opts)
  end

  def operation_string(request, opts \\ []) do
    request.sparql_operation_type.operation_string(request, opts)
  end

  def query_parameter_key(request) do
    request.sparql_operation_type.query_parameter_key()
  end

  defp graph_params(opts) do
    opts
    |> Enum.reduce([], fn
      {:default_graph, graph_uris}, acc when is_list(graph_uris) ->
        Enum.reduce(graph_uris, acc, fn graph_uri, acc ->
          [{"default-graph-uri", graph_uri} | acc]
        end)

      {:default_graph, graph_uri}, acc ->
        [{"default-graph-uri", graph_uri} | acc]

      {:named_graph, graph_uris}, acc when is_list(graph_uris) ->
        Enum.reduce(graph_uris, acc, fn graph_uri, acc ->
          [{"named-graph-uri", graph_uri} | acc]
        end)

      {:named_graph, graph_uri}, acc ->
        [{"named-graph-uri", graph_uri} | acc]

      _, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  def call(%__MODULE__{} = request, opts) do
    case SPARQL.Client.Tesla.call(request, opts) do
      {:ok, %__MODULE__{http_status: status} = request} when status in 200..299 ->
        request.sparql_operation_type.evaluate_response(request, opts)

      {:ok, request} ->
        {:error, %SPARQL.Client.HTTPError{request: request, status: request.http_status}}

      error ->
        error
    end
  end
end