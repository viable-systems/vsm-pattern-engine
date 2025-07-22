defmodule VsmPatternEngine.VectorStore.Encoder do
  @moduledoc """
  Encodes patterns, anomalies, and correlations into vectors for storage.
  """
  
  def encode_pattern(pattern, encoder_config) do
    # Extract features from pattern
    features = extract_pattern_features(pattern)
    
    # Convert to vector
    vectorize_features(features, encoder_config.dimensions)
  end
  
  def encode_anomaly(anomaly, encoder_config) do
    # Extract features from anomaly
    features = extract_anomaly_features(anomaly)
    
    # Convert to vector
    vectorize_features(features, encoder_config.dimensions)
  end
  
  def encode_correlation(correlation, encoder_config) do
    # Extract features from correlation
    features = extract_correlation_features(correlation)
    
    # Convert to vector
    vectorize_features(features, encoder_config.dimensions)
  end
  
  defp extract_pattern_features(pattern) do
    base_features = [
      pattern.confidence || 0.0,
      pattern.data_points || 0,
      length(pattern.patterns || [])
    ]
    
    # Add pattern-specific features
    pattern_features = if pattern.dominant_pattern do
      case pattern.dominant_pattern.type do
        :periodic -> [1.0, 0.0, 0.0, 0.0, 0.0, pattern.dominant_pattern.period || 0.0]
        :trend -> [0.0, 1.0, 0.0, 0.0, 0.0, pattern.dominant_pattern.metadata[:slope] || 0.0]
        :burst -> [0.0, 0.0, 1.0, 0.0, 0.0, length(pattern.dominant_pattern.instances || [])]
        :decay -> [0.0, 0.0, 0.0, 1.0, 0.0, pattern.dominant_pattern.decay_rate || 0.0]
        :cyclic -> [0.0, 0.0, 0.0, 0.0, 1.0, length(pattern.dominant_pattern.cycles || [])]
        _ -> [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      end
    else
      [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    end
    
    base_features ++ pattern_features
  end
  
  defp extract_anomaly_features(anomaly) do
    base_features = [
      if(anomaly.anomaly_detected, do: 1.0, else: 0.0),
      anomaly.anomaly_count || 0,
      severity_to_float(anomaly.severity),
      if(anomaly.critical, do: 1.0, else: 0.0)
    ]
    
    # Add method-specific features
    method_features = case anomaly.method do
      :statistical -> [1.0, 0.0, 0.0, 0.0]
      :isolation_forest -> [0.0, 1.0, 0.0, 0.0]
      :local_outlier_factor -> [0.0, 0.0, 1.0, 0.0]
      :vsm_based -> [0.0, 0.0, 0.0, 1.0]
      _ -> [0.0, 0.0, 0.0, 0.0]
    end
    
    base_features ++ method_features
  end
  
  defp extract_correlation_features(correlation) do
    base_features = [
      correlation.pattern_count || 0,
      if(correlation.significant, do: 1.0, else: 0.0),
      length(correlation.relationships || [])
    ]
    
    # Add relationship features
    rel_features = if correlation.strongest_correlation do
      [
        correlation.strongest_correlation.correlation || 0.0,
        correlation.strongest_correlation.strength || 0.0,
        if(correlation.strongest_correlation.direction == :positive, do: 1.0, else: -1.0)
      ]
    else
      [0.0, 0.0, 0.0]
    end
    
    # Add network metrics
    network_features = if correlation.network_metrics do
      [
        correlation.network_metrics.nodes || 0,
        correlation.network_metrics.edges || 0,
        correlation.network_metrics.density || 0.0,
        correlation.network_metrics.avg_correlation || 0.0
      ]
    else
      [0.0, 0.0, 0.0, 0.0]
    end
    
    base_features ++ rel_features ++ network_features
  end
  
  defp vectorize_features(features, target_dimensions) do
    current_size = length(features)
    
    # Pad or truncate to target dimensions
    vector = cond do
      current_size == target_dimensions ->
        features
      
      current_size < target_dimensions ->
        # Pad with zeros
        features ++ List.duplicate(0.0, target_dimensions - current_size)
      
      current_size > target_dimensions ->
        # Use feature hashing to reduce dimensions
        hash_features(features, target_dimensions)
    end
    
    # Normalize if configured
    normalize_vector(vector)
  end
  
  defp hash_features(features, target_dimensions) do
    # Simple feature hashing
    Enum.reduce(Enum.with_index(features), List.duplicate(0.0, target_dimensions), fn {value, idx}, acc ->
      hash_idx = rem(idx, target_dimensions)
      List.update_at(acc, hash_idx, &(&1 + value))
    end)
  end
  
  defp normalize_vector(vector) do
    magnitude = :math.sqrt(Enum.reduce(vector, 0, fn x, acc -> acc + x * x end))
    
    if magnitude > 0 do
      Enum.map(vector, &(&1 / magnitude))
    else
      vector
    end
  end
  
  defp severity_to_float(:critical), do: 1.0
  defp severity_to_float(:high), do: 0.75
  defp severity_to_float(:medium), do: 0.5
  defp severity_to_float(:low), do: 0.25
  defp severity_to_float(_), do: 0.0
end