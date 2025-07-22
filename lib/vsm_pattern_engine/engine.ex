defmodule VsmPatternEngine.Engine do
  @moduledoc """
  Main pattern recognition engine that coordinates temporal, correlation, 
  and anomaly detection modules.
  """
  use GenServer
  require Logger

  alias VsmPatternEngine.{Temporal, Correlation, Anomaly, VectorStore}

  @vsm_levels 1..5
  @detection_interval 5_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def analyze_pattern(data, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_pattern, data, opts})
  end

  def detect_anomaly(data, baseline \\ nil) do
    GenServer.call(__MODULE__, {:detect_anomaly, data, baseline})
  end

  def correlate_patterns(pattern_sets) do
    GenServer.call(__MODULE__, {:correlate_patterns, pattern_sets})
  end

  def get_system_state do
    GenServer.call(__MODULE__, :get_system_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("Starting VSM Pattern Engine")
    
    state = %{
      config: build_config(opts),
      patterns: %{},
      anomalies: [],
      correlations: %{},
      vsm_state: initialize_vsm_state(),
      metrics: %{
        patterns_analyzed: 0,
        anomalies_detected: 0,
        correlations_found: 0
      }
    }
    
    schedule_detection()
    {:ok, state}
  end

  @impl true
  def handle_call({:analyze_pattern, data, opts}, _from, state) do
    # Analyze temporal patterns
    temporal_result = Temporal.Detector.analyze(data, opts)
    
    # Store in vector store
    VectorStore.Client.store_pattern(temporal_result)
    
    # Update state
    new_state = update_pattern_state(state, temporal_result)
    
    {:reply, {:ok, temporal_result}, new_state}
  end

  @impl true
  def handle_call({:detect_anomaly, data, baseline}, _from, state) do
    # Detect anomalies using VSM principles
    anomaly_result = Anomaly.Detector.detect(data, baseline || state.vsm_state)
    
    # Check system viability
    viability = check_vsm_viability(anomaly_result, state.vsm_state)
    
    # Store anomaly if found
    if anomaly_result.anomaly_detected do
      VectorStore.Client.store_anomaly(anomaly_result)
    end
    
    new_state = update_anomaly_state(state, anomaly_result)
    
    {:reply, {:ok, anomaly_result, viability}, new_state}
  end

  @impl true
  def handle_call({:correlate_patterns, pattern_sets}, _from, state) do
    # Find correlations between patterns
    correlation_result = Correlation.Analyzer.analyze(pattern_sets)
    
    # Store significant correlations
    if correlation_result.significant do
      VectorStore.Client.store_correlation(correlation_result)
    end
    
    new_state = update_correlation_state(state, correlation_result)
    
    {:reply, {:ok, correlation_result}, new_state}
  end

  @impl true
  def handle_call(:get_system_state, _from, state) do
    system_info = %{
      vsm_state: state.vsm_state,
      metrics: state.metrics,
      pattern_count: map_size(state.patterns),
      anomaly_count: length(state.anomalies),
      correlation_count: map_size(state.correlations),
      viability_score: calculate_viability_score(state)
    }
    
    {:reply, {:ok, system_info}, state}
  end

  @impl true
  def handle_info(:run_detection, state) do
    # Periodic detection cycle
    Logger.debug("Running periodic pattern detection")
    
    # Get recent data from vector store
    {:ok, recent_data} = VectorStore.Client.get_recent_data()
    
    # Run detection pipeline
    pipeline_result = run_detection_pipeline(recent_data, state)
    
    # Update state with results
    new_state = update_detection_state(state, pipeline_result)
    
    schedule_detection()
    {:noreply, new_state}
  end

  # Private Functions

  defp build_config(opts) do
    %{
      detection_interval: opts[:detection_interval] || @detection_interval,
      anomaly_threshold: opts[:anomaly_threshold] || 0.8,
      correlation_threshold: opts[:correlation_threshold] || 0.7,
      vsm_config: build_vsm_config(opts)
    }
  end

  defp build_vsm_config(opts) do
    %{
      recursion_levels: opts[:recursion_levels] || 5,
      variety_management: opts[:variety_management] || :requisite,
      feedback_loops: opts[:feedback_loops] || true,
      algedonic_signals: opts[:algedonic_signals] || true
    }
  end

  defp initialize_vsm_state do
    %{
      system_1: %{variety: 100, capacity: 150},
      system_2: %{variety: 80, capacity: 120},
      system_3: %{variety: 60, capacity: 100},
      system_4: %{variety: 40, capacity: 80},
      system_5: %{variety: 20, capacity: 50},
      environment: %{variety: 200, uncertainty: 0.3},
      algedonic_channel: %{active: false, signal: nil}
    }
  end

  defp schedule_detection do
    Process.send_after(self(), :run_detection, @detection_interval)
  end

  defp run_detection_pipeline(data, state) do
    # Complex detection pipeline using all modules
    with {:ok, temporal} <- Temporal.Detector.analyze(data),
         {:ok, anomalies} <- Anomaly.Detector.detect_batch(data, state.vsm_state),
         {:ok, correlations} <- find_pattern_correlations(temporal, state.patterns) do
      %{
        temporal_patterns: temporal,
        anomalies: anomalies,
        correlations: correlations,
        timestamp: DateTime.utc_now()
      }
    end
  end

  defp find_pattern_correlations(new_patterns, existing_patterns) do
    pattern_sets = Map.values(existing_patterns) ++ [new_patterns]
    Correlation.Analyzer.analyze(pattern_sets)
  end

  defp check_vsm_viability(anomaly_result, vsm_state) do
    # Apply Ashby's Law of Requisite Variety
    variety_ratio = calculate_variety_ratio(vsm_state)
    
    %{
      viable: variety_ratio >= 1.0 and not anomaly_result.critical,
      variety_ratio: variety_ratio,
      recommendations: generate_recommendations(variety_ratio, anomaly_result)
    }
  end

  defp calculate_variety_ratio(vsm_state) do
    system_variety = Enum.reduce(@vsm_levels, 0, fn level, acc ->
      acc + vsm_state[:"system_#{level}"].variety
    end)
    
    system_variety / vsm_state.environment.variety
  end

  defp generate_recommendations(variety_ratio, anomaly_result) do
    recommendations = []
    
    recommendations = if variety_ratio < 1.0 do
      ["Increase system variety to match environmental complexity" | recommendations]
    else
      recommendations
    end
    
    recommendations = if anomaly_result.anomaly_detected do
      ["Investigate anomaly: #{anomaly_result.description}" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end

  defp calculate_viability_score(state) do
    # Complex viability calculation based on VSM principles
    variety_score = calculate_variety_ratio(state.vsm_state)
    anomaly_score = 1.0 - (length(state.anomalies) / 100)
    pattern_score = min(map_size(state.patterns) / 50, 1.0)
    
    (variety_score + anomaly_score + pattern_score) / 3
  end

  defp update_pattern_state(state, pattern_result) do
    %{state |
      patterns: Map.put(state.patterns, pattern_result.id, pattern_result),
      metrics: Map.update!(state.metrics, :patterns_analyzed, &(&1 + 1))
    }
  end

  defp update_anomaly_state(state, anomaly_result) do
    state = if anomaly_result.anomaly_detected do
      %{state |
        anomalies: [anomaly_result | Enum.take(state.anomalies, 99)],
        metrics: Map.update!(state.metrics, :anomalies_detected, &(&1 + 1))
      }
    else
      state
    end
    
    # Update VSM state based on anomaly
    update_vsm_state_from_anomaly(state, anomaly_result)
  end

  defp update_correlation_state(state, correlation_result) do
    if correlation_result.significant do
      %{state |
        correlations: Map.put(state.correlations, correlation_result.id, correlation_result),
        metrics: Map.update!(state.metrics, :correlations_found, &(&1 + 1))
      }
    else
      state
    end
  end

  defp update_detection_state(state, pipeline_result) do
    state
    |> update_pattern_state(pipeline_result.temporal_patterns)
    |> update_anomaly_batch(pipeline_result.anomalies)
    |> update_correlation_batch(pipeline_result.correlations)
  end

  defp update_anomaly_batch(state, anomalies) do
    Enum.reduce(anomalies, state, &update_anomaly_state(&2, &1))
  end

  defp update_correlation_batch(state, correlations) do
    Enum.reduce(correlations, state, &update_correlation_state(&2, &1))
  end

  defp update_vsm_state_from_anomaly(state, anomaly_result) do
    if anomaly_result.critical do
      # Activate algedonic channel for critical anomalies
      put_in(state, [:vsm_state, :algedonic_channel], %{
        active: true,
        signal: anomaly_result,
        timestamp: DateTime.utc_now()
      })
    else
      state
    end
  end
end