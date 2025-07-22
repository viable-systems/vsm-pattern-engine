defmodule VsmPatternEngine.Telemetry do
  @moduledoc """
  Telemetry setup for monitoring and metrics collection.
  """
  
  use Supervisor
  import Telemetry.Metrics
  
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
  
  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  def metrics do
    [
      # Pattern Detection Metrics
      counter("vsm_pattern_engine.patterns.analyzed.count"),
      summary("vsm_pattern_engine.patterns.detection.duration",
        unit: {:native, :millisecond}
      ),
      last_value("vsm_pattern_engine.patterns.confidence.average"),
      
      # Anomaly Detection Metrics
      counter("vsm_pattern_engine.anomalies.detected.count"),
      counter("vsm_pattern_engine.anomalies.critical.count"),
      summary("vsm_pattern_engine.anomalies.severity.distribution"),
      
      # Correlation Metrics
      counter("vsm_pattern_engine.correlations.found.count"),
      summary("vsm_pattern_engine.correlations.strength.distribution"),
      
      # VSM Metrics
      last_value("vsm_pattern_engine.vsm.variety_ratio"),
      last_value("vsm_pattern_engine.vsm.viability_score"),
      counter("vsm_pattern_engine.vsm.algedonic_signals.count"),
      
      # System Metrics
      last_value("vsm_pattern_engine.system.memory.usage",
        unit: :byte
      ),
      summary("vsm_pattern_engine.system.processing.latency",
        unit: {:native, :millisecond}
      ),
      
      # Vector Store Metrics
      counter("vsm_pattern_engine.vector_store.operations.count"),
      summary("vsm_pattern_engine.vector_store.query.duration",
        unit: {:native, :millisecond}
      ),
      last_value("vsm_pattern_engine.vector_store.connection.status")
    ]
  end
  
  defp periodic_measurements do
    [
      {__MODULE__, :measure_system_metrics, []}
    ]
  end
  
  def measure_system_metrics do
    # Memory usage
    memory = :erlang.memory(:total)
    :telemetry.execute(
      [:vsm_pattern_engine, :system, :memory],
      %{usage: memory},
      %{}
    )
    
    # Get engine state if available
    case Process.whereis(VsmPatternEngine.Engine) do
      nil -> :ok
      pid when is_pid(pid) ->
        case GenServer.call(pid, :get_system_state, 5000) do
          {:ok, state} ->
            # VSM metrics
            :telemetry.execute(
              [:vsm_pattern_engine, :vsm],
              %{
                variety_ratio: state.viability_score,
                viability_score: state.viability_score
              },
              %{}
            )
          _ -> :ok
        end
    end
  end
  
  # Telemetry event handlers
  
  def handle_event([:vsm_pattern_engine, :pattern, :analyzed], measurements, metadata, _config) do
    :telemetry.execute(
      [:vsm_pattern_engine, :patterns, :analyzed],
      %{count: 1, duration: measurements.duration},
      metadata
    )
  end
  
  def handle_event([:vsm_pattern_engine, :anomaly, :detected], measurements, metadata, _config) do
    :telemetry.execute(
      [:vsm_pattern_engine, :anomalies, :detected],
      %{count: 1},
      metadata
    )
    
    if metadata.critical do
      :telemetry.execute(
        [:vsm_pattern_engine, :anomalies, :critical],
        %{count: 1},
        metadata
      )
    end
  end
  
  def handle_event([:vsm_pattern_engine, :critical_anomaly], _measurements, metadata, _config) do
    :telemetry.execute(
      [:vsm_pattern_engine, :vsm, :algedonic_signals],
      %{count: 1},
      metadata
    )
  end
end