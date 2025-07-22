defmodule VsmPatternEngine.Correlation.Cache do
  @moduledoc """
  Cache for correlation analysis results.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end
  
  def put(key, value) do
    GenServer.cast(__MODULE__, {:put, key, value})
  end
  
  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end
  
  @impl true
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end