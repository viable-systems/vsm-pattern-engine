defmodule VsmPatternEngine.Temporal.StreamProcessor do
  @moduledoc """
  Stream processing for real-time temporal pattern detection.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def process(data) do
    GenServer.cast(__MODULE__, {:process, data})
  end
  
  @impl true
  def init(_opts) do
    {:ok, %{buffer: []}}
  end
  
  @impl true
  def handle_cast({:process, data}, state) do
    # Add to buffer and process if window is full
    new_buffer = state.buffer ++ [data]
    
    if length(new_buffer) >= 100 do
      # Process the window
      Task.start(fn ->
        VsmPatternEngine.Temporal.Detector.analyze(new_buffer)
      end)
      
      # Slide the window
      {:noreply, %{state | buffer: Enum.drop(new_buffer, 10)}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end
end