defmodule VsmPatternEngine.Anomaly.BaselineManager do
  @moduledoc """
  Manages baseline data for anomaly detection.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def update_baseline(data) do
    GenServer.cast(__MODULE__, {:update, data})
  end
  
  def get_baseline do
    GenServer.call(__MODULE__, :get_baseline)
  end
  
  @impl true
  def init(_opts) do
    {:ok, %{baseline: [], window_size: 1000}}
  end
  
  @impl true
  def handle_cast({:update, data}, state) do
    new_baseline = (state.baseline ++ data)
                   |> Enum.take(-state.window_size)
    
    {:noreply, %{state | baseline: new_baseline}}
  end
  
  @impl true
  def handle_call(:get_baseline, _from, state) do
    {:reply, state.baseline, state}
  end
end