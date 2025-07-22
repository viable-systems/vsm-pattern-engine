defmodule VsmPatternEngine.VectorStore.Client do
  @moduledoc """
  Client for integrating with VSM Vector Store.
  Handles pattern storage, retrieval, and vector similarity operations.
  """
  
  use GenServer
  require Logger
  
  alias VsmPatternEngine.VectorStore.{Encoder, Query, Connection}
  
  @default_url "http://localhost:4000/api"
  @default_timeout 5000
  @vector_dimensions 384  # Default embedding size
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def store_pattern(pattern) do
    GenServer.call(__MODULE__, {:store_pattern, pattern})
  end
  
  def store_anomaly(anomaly) do
    GenServer.call(__MODULE__, {:store_anomaly, anomaly})
  end
  
  def store_correlation(correlation) do
    GenServer.call(__MODULE__, {:store_correlation, correlation})
  end
  
  def search_similar_patterns(pattern, opts \\ []) do
    GenServer.call(__MODULE__, {:search_similar, pattern, opts})
  end
  
  def get_recent_data(opts \\ []) do
    GenServer.call(__MODULE__, {:get_recent, opts})
  end
  
  def query(query_params) do
    GenServer.call(__MODULE__, {:query, query_params})
  end
  
  def health_check do
    GenServer.call(__MODULE__, :health_check)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    config = build_config(opts)
    
    # Initialize HTTP client
    {:ok, _pid} = Connection.start_link(config)
    
    state = %{
      config: config,
      encoder: initialize_encoder(config),
      stats: %{
        patterns_stored: 0,
        anomalies_stored: 0,
        correlations_stored: 0,
        queries_executed: 0
      }
    }
    
    schedule_health_check()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:store_pattern, pattern}, _from, state) do
    Logger.debug("Storing pattern: #{pattern.id}")
    
    # Encode pattern to vector
    vector = Encoder.encode_pattern(pattern, state.encoder)
    
    # Prepare document for storage
    document = %{
      id: pattern.id,
      type: "pattern",
      timestamp: pattern.timestamp,
      vector: vector,
      metadata: %{
        pattern_type: pattern.dominant_pattern && pattern.dominant_pattern.type,
        confidence: pattern.confidence,
        data_points: pattern.data_points
      },
      content: Jason.encode!(pattern)
    }
    
    # Store in vector store
    case Connection.post("/vectors", document) do
      {:ok, response} ->
        new_state = update_stats(state, :patterns_stored)
        {:reply, {:ok, response}, new_state}
      
      {:error, reason} = error ->
        Logger.error("Failed to store pattern: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:store_anomaly, anomaly}, _from, state) do
    Logger.debug("Storing anomaly: #{anomaly.id}")
    
    # Encode anomaly to vector
    vector = Encoder.encode_anomaly(anomaly, state.encoder)
    
    # Prepare document
    document = %{
      id: anomaly.id,
      type: "anomaly",
      timestamp: anomaly.timestamp,
      vector: vector,
      metadata: %{
        severity: anomaly.severity,
        method: anomaly.method,
        critical: anomaly.critical,
        anomaly_count: anomaly.anomaly_count
      },
      content: Jason.encode!(anomaly)
    }
    
    # Store with high priority if critical
    priority = if anomaly.critical, do: :high, else: :normal
    
    case Connection.post("/vectors", document, priority: priority) do
      {:ok, response} ->
        new_state = update_stats(state, :anomalies_stored)
        
        # Trigger alert if critical
        if anomaly.critical do
          send_critical_alert(anomaly)
        end
        
        {:reply, {:ok, response}, new_state}
      
      {:error, reason} = error ->
        Logger.error("Failed to store anomaly: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:store_correlation, correlation}, _from, state) do
    Logger.debug("Storing correlation: #{correlation.id}")
    
    # Encode correlation to vector
    vector = Encoder.encode_correlation(correlation, state.encoder)
    
    # Prepare document
    document = %{
      id: correlation.id,
      type: "correlation",
      timestamp: correlation.timestamp,
      vector: vector,
      metadata: %{
        pattern_count: correlation.pattern_count,
        significant: correlation.significant,
        strongest_correlation: correlation.strongest_correlation && correlation.strongest_correlation.correlation
      },
      content: Jason.encode!(correlation)
    }
    
    case Connection.post("/vectors", document) do
      {:ok, response} ->
        new_state = update_stats(state, :correlations_stored)
        {:reply, {:ok, response}, new_state}
      
      {:error, reason} = error ->
        Logger.error("Failed to store correlation: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_similar, pattern, opts}, _from, state) do
    Logger.debug("Searching for similar patterns")
    
    # Encode pattern to vector
    query_vector = Encoder.encode_pattern(pattern, state.encoder)
    
    # Build search query
    search_params = %{
      vector: query_vector,
      k: opts[:k] || 10,
      filter: build_filter(opts),
      include_metadata: true
    }
    
    case Connection.post("/search", search_params) do
      {:ok, results} ->
        new_state = update_stats(state, :queries_executed)
        
        # Decode results
        decoded_results = Enum.map(results["matches"], &decode_result/1)
        
        {:reply, {:ok, decoded_results}, new_state}
      
      {:error, reason} = error ->
        Logger.error("Search failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_recent, opts}, _from, state) do
    Logger.debug("Getting recent data")
    
    # Build query for recent data
    query_params = %{
      filter: %{
        timestamp: %{
          "$gte": opts[:since] || DateTime.add(DateTime.utc_now(), -3600, :second)
        }
      },
      sort: %{timestamp: -1},
      limit: opts[:limit] || 100,
      types: opts[:types] || ["pattern", "anomaly", "correlation"]
    }
    
    case Connection.post("/query", query_params) do
      {:ok, results} ->
        new_state = update_stats(state, :queries_executed)
        
        # Group results by type
        grouped_results = results["documents"]
                          |> Enum.map(&decode_result/1)
                          |> Enum.group_by(& &1.type)
        
        {:reply, {:ok, grouped_results}, new_state}
      
      {:error, reason} = error ->
        Logger.error("Failed to get recent data: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:query, query_params}, _from, state) do
    Logger.debug("Executing custom query")
    
    case Connection.post("/query", query_params) do
      {:ok, results} ->
        new_state = update_stats(state, :queries_executed)
        {:reply, {:ok, results}, new_state}
      
      {:error, reason} = error ->
        Logger.error("Query failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:health_check, _from, state) do
    case Connection.get("/health") do
      {:ok, %{"status" => "healthy"} = response} ->
        {:reply, {:ok, response}, state}
      
      {:ok, response} ->
        {:reply, {:warning, response}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_info(:scheduled_health_check, state) do
    case Connection.get("/health") do
      {:ok, %{"status" => "healthy"}} ->
        Logger.debug("Vector store health check: OK")
      
      {:ok, response} ->
        Logger.warning("Vector store health check warning: #{inspect(response)}")
      
      {:error, reason} ->
        Logger.error("Vector store health check failed: #{inspect(reason)}")
    end
    
    schedule_health_check()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp build_config(opts) do
    %{
      url: opts[:url] || System.get_env("VSM_VECTOR_STORE_URL") || @default_url,
      timeout: opts[:timeout] || @default_timeout,
      api_key: opts[:api_key] || System.get_env("VSM_VECTOR_STORE_API_KEY"),
      encoder_model: opts[:encoder_model] || :default,
      vector_dimensions: opts[:vector_dimensions] || @vector_dimensions
    }
  end
  
  defp initialize_encoder(config) do
    %{
      model: config.encoder_model,
      dimensions: config.vector_dimensions,
      normalize: true
    }
  end
  
  defp build_filter(opts) do
    filter = %{}
    
    filter = if opts[:type] do
      Map.put(filter, :type, opts[:type])
    else
      filter
    end
    
    filter = if opts[:since] do
      Map.put(filter, :timestamp, %{"$gte" => opts[:since]})
    else
      filter
    end
    
    filter = if opts[:metadata_filter] do
      Map.merge(filter, opts[:metadata_filter])
    else
      filter
    end
    
    if map_size(filter) > 0, do: filter, else: nil
  end
  
  defp decode_result(result) do
    content = Jason.decode!(result["content"])
    
    Map.merge(content, %{
      score: result["score"],
      vector_id: result["id"],
      type: result["type"]
    })
  end
  
  defp send_critical_alert(anomaly) do
    # Send alert through configured channels
    Logger.alert("Critical anomaly detected: #{anomaly.description}")
    
    # Could integrate with:
    # - Slack/Discord webhooks
    # - Email notifications
    # - PagerDuty
    # - Custom alerting systems
    
    # Publish to event system
    :telemetry.execute(
      [:vsm_pattern_engine, :critical_anomaly],
      %{count: 1},
      %{anomaly: anomaly}
    )
  end
  
  defp update_stats(state, stat_key) do
    update_in(state, [:stats, stat_key], &(&1 + 1))
  end
  
  defp schedule_health_check do
    Process.send_after(self(), :scheduled_health_check, 60_000)  # Every minute
  end
end