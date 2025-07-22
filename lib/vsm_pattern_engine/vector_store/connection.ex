defmodule VsmPatternEngine.VectorStore.Connection do
  @moduledoc """
  HTTP connection management for Vector Store API.
  """
  
  use GenServer
  require Logger
  
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end
  
  def get(path) do
    GenServer.call(__MODULE__, {:get, path})
  end
  
  def post(path, body, opts \\ []) do
    GenServer.call(__MODULE__, {:post, path, body, opts})
  end
  
  @impl true
  def init(config) do
    # Configure Finch
    {:ok, %{config: config, base_url: config.url}}
  end
  
  @impl true
  def handle_call({:get, path}, _from, state) do
    url = state.base_url <> path
    
    request = Finch.build(:get, url, headers(state))
    
    case Finch.request(request, VsmPatternEngine.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:reply, {:ok, Jason.decode!(body)}, state}
      
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:reply, {:error, %{status: status, body: body}}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:post, path, body, opts}, _from, state) do
    url = state.base_url <> path
    json_body = Jason.encode!(body)
    
    request = Finch.build(:post, url, headers(state), json_body)
    
    case Finch.request(request, VsmPatternEngine.Finch) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:reply, {:ok, Jason.decode!(resp_body)}, state}
      
      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        {:reply, {:error, %{status: status, body: resp_body}}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  defp headers(state) do
    base_headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
    
    if state.config[:api_key] do
      [{"authorization", "Bearer #{state.config.api_key}"} | base_headers]
    else
      base_headers
    end
  end
end