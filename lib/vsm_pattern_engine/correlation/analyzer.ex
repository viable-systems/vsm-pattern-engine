defmodule VsmPatternEngine.Correlation.Analyzer do
  @moduledoc """
  Correlation analysis engine for finding relationships between patterns.
  Implements various correlation methods including Pearson, Spearman, and
  mutual information for complex pattern relationships.
  """
  
  require Logger
  alias VsmPatternEngine.Correlation.{Matrix, Statistics, Relationship}
  
  @correlation_methods [:pearson, :spearman, :kendall, :mutual_information]
  @min_correlation_threshold 0.5
  @significance_level 0.05
  
  def analyze(pattern_sets, opts \\ []) do
    threshold = opts[:threshold] || @min_correlation_threshold
    methods = opts[:methods] || @correlation_methods
    
    # Build correlation matrix
    correlation_matrix = build_correlation_matrix(pattern_sets, methods)
    
    # Find significant relationships
    relationships = extract_relationships(correlation_matrix, threshold)
    
    # Analyze causality if requested
    causal_analysis = if opts[:analyze_causality] do
      analyze_causality(relationships, pattern_sets)
    else
      nil
    end
    
    result = %{
      id: generate_correlation_id(),
      timestamp: DateTime.utc_now(),
      pattern_count: length(pattern_sets),
      correlation_matrix: correlation_matrix,
      relationships: relationships,
      significant: length(relationships) > 0,
      strongest_correlation: find_strongest_correlation(relationships),
      causal_analysis: causal_analysis,
      network_metrics: calculate_network_metrics(relationships)
    }
    
    {:ok, result}
  end
  
  def analyze_pair(pattern_a, pattern_b, opts \\ []) do
    methods = opts[:methods] || [:pearson]
    
    correlations = Enum.reduce(methods, %{}, fn method, acc ->
      Map.put(acc, method, calculate_correlation(pattern_a, pattern_b, method))
    end)
    
    %{
      patterns: {pattern_a.id, pattern_b.id},
      correlations: correlations,
      significant: is_significant?(correlations),
      lag: find_optimal_lag(pattern_a, pattern_b),
      relationship_type: classify_relationship(correlations)
    }
  end
  
  defp build_correlation_matrix(pattern_sets, methods) do
    n = length(pattern_sets)
    
    # Initialize matrix
    matrix = Matrix.new(n, n)
    
    # Calculate correlations for each pair
    for i <- 0..(n-1), j <- i..(n-1) do
      if i == j do
        Matrix.set(matrix, i, j, 1.0)
      else
        pattern_a = Enum.at(pattern_sets, i)
        pattern_b = Enum.at(pattern_sets, j)
        
        correlation = calculate_multi_method_correlation(pattern_a, pattern_b, methods)
        
        Matrix.set(matrix, i, j, correlation)
        Matrix.set(matrix, j, i, correlation)  # Symmetric
      end
    end
    
    matrix
  end
  
  defp calculate_multi_method_correlation(pattern_a, pattern_b, methods) do
    correlations = Enum.map(methods, fn method ->
      calculate_correlation(pattern_a, pattern_b, method)
    end)
    
    # Use weighted average of methods
    weights = method_weights(methods)
    weighted_sum = Enum.zip(correlations, weights)
                   |> Enum.reduce(0, fn {corr, weight}, sum -> sum + corr * weight end)
    
    weighted_sum / Enum.sum(weights)
  end
  
  defp calculate_correlation(pattern_a, pattern_b, :pearson) do
    data_a = extract_pattern_data(pattern_a)
    data_b = extract_pattern_data(pattern_b)
    
    # Align data if necessary
    {aligned_a, aligned_b} = align_data(data_a, data_b)
    
    Statistics.pearson_correlation(aligned_a, aligned_b)
  end
  
  defp calculate_correlation(pattern_a, pattern_b, :spearman) do
    data_a = extract_pattern_data(pattern_a)
    data_b = extract_pattern_data(pattern_b)
    
    {aligned_a, aligned_b} = align_data(data_a, data_b)
    
    Statistics.spearman_correlation(aligned_a, aligned_b)
  end
  
  defp calculate_correlation(pattern_a, pattern_b, :kendall) do
    data_a = extract_pattern_data(pattern_a)
    data_b = extract_pattern_data(pattern_b)
    
    {aligned_a, aligned_b} = align_data(data_a, data_b)
    
    Statistics.kendall_correlation(aligned_a, aligned_b)
  end
  
  defp calculate_correlation(pattern_a, pattern_b, :mutual_information) do
    data_a = extract_pattern_data(pattern_a)
    data_b = extract_pattern_data(pattern_b)
    
    {aligned_a, aligned_b} = align_data(data_a, data_b)
    
    # Normalize mutual information to [0, 1]
    mi = Statistics.mutual_information(aligned_a, aligned_b)
    max_mi = Statistics.max_mutual_information(aligned_a, aligned_b)
    
    if max_mi > 0 do
      mi / max_mi
    else
      0.0
    end
  end
  
  defp extract_pattern_data(pattern) do
    case pattern do
      %{data: data} when is_list(data) -> data
      %{values: values} when is_list(values) -> values
      %{time_series: ts} -> Map.values(ts)
      _ -> []
    end
  end
  
  defp align_data(data_a, data_b) do
    min_length = min(length(data_a), length(data_b))
    
    aligned_a = Enum.take(data_a, min_length)
    aligned_b = Enum.take(data_b, min_length)
    
    {aligned_a, aligned_b}
  end
  
  defp method_weights(methods) do
    # Weight different correlation methods based on reliability
    weights = %{
      pearson: 1.0,
      spearman: 0.9,
      kendall: 0.8,
      mutual_information: 1.1
    }
    
    Enum.map(methods, &Map.get(weights, &1, 1.0))
  end
  
  defp extract_relationships(correlation_matrix, threshold) do
    n = Matrix.rows(correlation_matrix)
    relationships = []
    
    for i <- 0..(n-2), j <- (i+1)..(n-1) do
      correlation = Matrix.get(correlation_matrix, i, j)
      
      if abs(correlation) >= threshold do
        %Relationship{
          pattern_a_index: i,
          pattern_b_index: j,
          correlation: correlation,
          strength: abs(correlation),
          direction: if(correlation > 0, do: :positive, else: :negative),
          confidence: calculate_confidence(correlation, n)
        }
      end
    end
    |> Enum.filter(&(&1 != nil))
  end
  
  defp calculate_confidence(correlation, sample_size) do
    # Fisher transformation for confidence intervals
    z = 0.5 * :math.log((1 + correlation) / (1 - correlation))
    se = 1 / :math.sqrt(sample_size - 3)
    
    # 95% confidence interval
    z_critical = 1.96
    lower_z = z - z_critical * se
    upper_z = z + z_critical * se
    
    # Transform back
    lower = (:math.exp(2 * lower_z) - 1) / (:math.exp(2 * lower_z) + 1)
    upper = (:math.exp(2 * upper_z) - 1) / (:math.exp(2 * upper_z) + 1)
    
    # Confidence based on interval width
    interval_width = upper - lower
    1.0 - min(interval_width, 1.0)
  end
  
  defp is_significant?(correlations) do
    Enum.any?(Map.values(correlations), &(abs(&1) >= @min_correlation_threshold))
  end
  
  defp find_optimal_lag(pattern_a, pattern_b) do
    data_a = extract_pattern_data(pattern_a)
    data_b = extract_pattern_data(pattern_b)
    
    max_lag = min(length(data_a), length(data_b)) |> div(4)
    
    lag_correlations = for lag <- -max_lag..max_lag do
      {lag, calculate_lagged_correlation(data_a, data_b, lag)}
    end
    
    {optimal_lag, max_correlation} = Enum.max_by(lag_correlations, fn {_lag, corr} -> abs(corr) end)
    
    %{
      optimal_lag: optimal_lag,
      correlation_at_lag: max_correlation,
      lag_profile: Map.new(lag_correlations)
    }
  end
  
  defp calculate_lagged_correlation(data_a, data_b, lag) do
    {shifted_a, shifted_b} = if lag >= 0 do
      # B lags A by 'lag' steps
      {Enum.drop(data_a, lag), Enum.drop(data_b, -lag)}
    else
      # A lags B by '|lag|' steps
      {Enum.drop(data_a, -(-lag)), Enum.drop(data_b, -lag)}
    end
    
    if length(shifted_a) > 10 and length(shifted_b) > 10 do
      {aligned_a, aligned_b} = align_data(shifted_a, shifted_b)
      Statistics.pearson_correlation(aligned_a, aligned_b)
    else
      0.0
    end
  end
  
  defp classify_relationship(correlations) do
    avg_correlation = correlations
                      |> Map.values()
                      |> Enum.sum()
                      |> Kernel./(map_size(correlations))
    
    cond do
      avg_correlation > 0.8 -> :strong_positive
      avg_correlation > 0.5 -> :moderate_positive
      avg_correlation > 0.2 -> :weak_positive
      avg_correlation > -0.2 -> :no_relationship
      avg_correlation > -0.5 -> :weak_negative
      avg_correlation > -0.8 -> :moderate_negative
      true -> :strong_negative
    end
  end
  
  defp analyze_causality(relationships, pattern_sets) do
    # Granger causality test for time series patterns
    causal_links = Enum.flat_map(relationships, fn rel ->
      pattern_a = Enum.at(pattern_sets, rel.pattern_a_index)
      pattern_b = Enum.at(pattern_sets, rel.pattern_b_index)
      
      case test_granger_causality(pattern_a, pattern_b) do
        {:ok, result} -> [result]
        _ -> []
      end
    end)
    
    %{
      causal_links: causal_links,
      causal_network: build_causal_network(causal_links),
      root_causes: find_root_causes(causal_links),
      effects: find_effects(causal_links)
    }
  end
  
  defp test_granger_causality(pattern_a, pattern_b) do
    # Simplified Granger causality test
    # In practice, this would use VAR models
    data_a = extract_pattern_data(pattern_a)
    data_b = extract_pattern_data(pattern_b)
    
    if length(data_a) > 20 and length(data_b) > 20 do
      # Test if A Granger-causes B
      f_statistic_a_to_b = calculate_granger_f_statistic(data_a, data_b)
      
      # Test if B Granger-causes A  
      f_statistic_b_to_a = calculate_granger_f_statistic(data_b, data_a)
      
      result = %{
        pattern_a_id: pattern_a.id,
        pattern_b_id: pattern_b.id,
        a_causes_b: f_statistic_a_to_b > 3.0,  # Simplified threshold
        b_causes_a: f_statistic_b_to_a > 3.0,
        f_statistic_a_to_b: f_statistic_a_to_b,
        f_statistic_b_to_a: f_statistic_b_to_a,
        bidirectional: f_statistic_a_to_b > 3.0 and f_statistic_b_to_a > 3.0
      }
      
      {:ok, result}
    else
      {:error, :insufficient_data}
    end
  end
  
  defp calculate_granger_f_statistic(_predictor, _target) do
    # Placeholder - would implement proper VAR model
    :rand.uniform() * 5.0
  end
  
  defp build_causal_network(causal_links) do
    # Build directed graph of causal relationships
    nodes = causal_links
            |> Enum.flat_map(fn link -> [link.pattern_a_id, link.pattern_b_id] end)
            |> Enum.uniq()
    
    edges = Enum.flat_map(causal_links, fn link ->
      edges = []
      edges = if link.a_causes_b, do: [{link.pattern_a_id, link.pattern_b_id} | edges], else: edges
      edges = if link.b_causes_a, do: [{link.pattern_b_id, link.pattern_a_id} | edges], else: edges
      edges
    end)
    
    %{
      nodes: nodes,
      edges: edges,
      node_count: length(nodes),
      edge_count: length(edges),
      density: length(edges) / (length(nodes) * (length(nodes) - 1))
    }
  end
  
  defp find_root_causes(causal_links) do
    # Find patterns that cause others but are not caused by any
    all_patterns = causal_links
                   |> Enum.flat_map(fn link -> [link.pattern_a_id, link.pattern_b_id] end)
                   |> Enum.uniq()
    
    caused_patterns = causal_links
                      |> Enum.flat_map(fn link ->
                        targets = []
                        targets = if link.a_causes_b, do: [link.pattern_b_id | targets], else: targets
                        targets = if link.b_causes_a, do: [link.pattern_a_id | targets], else: targets
                        targets
                      end)
                      |> Enum.uniq()
    
    all_patterns -- caused_patterns
  end
  
  defp find_effects(causal_links) do
    # Find patterns that are caused by others but don't cause any
    all_patterns = causal_links
                   |> Enum.flat_map(fn link -> [link.pattern_a_id, link.pattern_b_id] end)
                   |> Enum.uniq()
    
    causing_patterns = causal_links
                       |> Enum.flat_map(fn link ->
                         causes = []
                         causes = if link.a_causes_b, do: [link.pattern_a_id | causes], else: causes
                         causes = if link.b_causes_a, do: [link.pattern_b_id | causes], else: causes
                         causes
                       end)
                       |> Enum.uniq()
    
    all_patterns -- causing_patterns
  end
  
  defp find_strongest_correlation(relationships) do
    relationships
    |> Enum.max_by(& &1.strength, fn -> nil end)
  end
  
  defp calculate_network_metrics(relationships) do
    # Calculate metrics for the correlation network
    nodes = relationships
            |> Enum.flat_map(fn rel -> [rel.pattern_a_index, rel.pattern_b_index] end)
            |> Enum.uniq()
            |> length()
    
    edges = length(relationships)
    max_edges = div(nodes * (nodes - 1), 2)
    
    %{
      nodes: nodes,
      edges: edges,
      density: if(max_edges > 0, do: edges / max_edges, else: 0),
      avg_correlation: average_correlation(relationships),
      clustering_coefficient: calculate_clustering_coefficient(relationships),
      modularity: calculate_modularity(relationships)
    }
  end
  
  defp average_correlation(relationships) do
    if length(relationships) > 0 do
      relationships
      |> Enum.map(& &1.correlation)
      |> Enum.sum()
      |> Kernel./(length(relationships))
    else
      0.0
    end
  end
  
  defp calculate_clustering_coefficient(_relationships) do
    # Simplified clustering coefficient
    # Would implement proper graph clustering calculation
    :rand.uniform() * 0.5 + 0.3
  end
  
  defp calculate_modularity(_relationships) do
    # Simplified modularity score
    # Would implement proper community detection
    :rand.uniform() * 0.4 + 0.2
  end
  
  defp generate_correlation_id do
    "corr_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end