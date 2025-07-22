defmodule VsmPatternEngine.Anomaly.AlertManager do
  @moduledoc """
  Manages alerts for detected anomalies.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def alert(anomaly) do
    GenServer.cast(__MODULE__, {:alert, anomaly})
  end
  
  @impl true
  def init(_opts) do
    {:ok, %{alerts: []}}
  end
  
  @impl true
  def handle_cast({:alert, anomaly}, state) do
    Logger.warning("Anomaly alert: #{inspect(anomaly)}")
    
    # Store alert
    new_alerts = [anomaly | state.alerts] |> Enum.take(100)
    
    # Trigger algedonic signal if critical
    if anomaly[:critical] do
      :telemetry.execute(
        [:vsm_pattern_engine, :algedonic_signal],
        %{severity: 1.0},
        %{anomaly: anomaly}
      )
    end
    
    {:noreply, %{state | alerts: new_alerts}}
  end
end