defmodule VsmPatternEngine.Anomaly.Detector do
  @moduledoc """
  Anomaly detection module using statistical methods and VSM principles.
  Implements multiple detection algorithms including statistical, density-based,
  and machine learning approaches.
  """
  
  require Logger
  alias VsmPatternEngine.Anomaly.{Algorithms, Threshold, Classification}
  
  @detection_methods [:statistical, :isolation_forest, :local_outlier_factor, :vsm_based]
  @default_contamination 0.1  # Expected proportion of anomalies
  
  def detect(data, baseline, opts \\ []) do
    method = opts[:method] || :vsm_based
    threshold = opts[:threshold] || calculate_dynamic_threshold(baseline)
    
    # Run detection
    anomalies = case method do
      :statistical -> detect_statistical_anomalies(data, baseline, threshold)
      :isolation_forest -> detect_isolation_forest(data, baseline)
      :local_outlier_factor -> detect_lof_anomalies(data, baseline)
      :vsm_based -> detect_vsm_anomalies(data, baseline)
      _ -> []
    end
    
    # Classify anomalies
    classified_anomalies = Enum.map(anomalies, &classify_anomaly/1)
    
    result = %{
      id: generate_anomaly_id(),
      timestamp: DateTime.utc_now(),
      method: method,
      data_points: length(data),
      anomaly_detected: length(anomalies) > 0,
      anomaly_count: length(anomalies),
      anomalies: classified_anomalies,
      severity: calculate_severity(classified_anomalies),
      critical: any_critical?(classified_anomalies),
      description: describe_anomalies(classified_anomalies),
      recommendations: generate_recommendations(classified_anomalies, baseline)
    }
    
    {:ok, result}
  end
  
  def detect_batch(data_batch, baseline) do
    # Process multiple data streams in parallel
    tasks = Enum.map(data_batch, fn {stream_id, data} ->
      Task.async(fn ->
        case detect(data, baseline) do
          {:ok, result} -> Map.put(result, :stream_id, stream_id)
          error -> error
        end
      end)
    end)
    
    results = Task.await_many(tasks, 5000)
    
    {:ok, Enum.filter(results, &match?(%{anomaly_detected: true}, &1))}
  end
  
  defp detect_statistical_anomalies(data, baseline, threshold) do
    # Z-score based anomaly detection
    mean = calculate_baseline_mean(baseline)
    std_dev = calculate_baseline_std(baseline)
    
    if std_dev > 0 do
      data
      |> Enum.with_index()
      |> Enum.filter(fn {value, _index} ->
        z_score = abs((value - mean) / std_dev)
        z_score > threshold
      end)
      |> Enum.map(fn {value, index} ->
        z_score = (value - mean) / std_dev
        %{
          index: index,
          value: value,
          z_score: z_score,
          deviation: abs(value - mean),
          type: :statistical
        }
      end)
    else
      []
    end
  end
  
  defp detect_isolation_forest(data, baseline) do
    # Simplified Isolation Forest implementation
    forest = build_isolation_forest(baseline)
    
    data
    |> Enum.with_index()
    |> Enum.filter(fn {value, _index} ->
      anomaly_score = calculate_isolation_score(value, forest)
      anomaly_score > 0.6  # Threshold for isolation forest
    end)
    |> Enum.map(fn {value, index} ->
      %{
        index: index,
        value: value,
        isolation_score: calculate_isolation_score(value, forest),
        type: :isolation_forest
      }
    end)
  end
  
  defp detect_lof_anomalies(data, baseline) do
    # Local Outlier Factor detection
    k = min(20, div(length(baseline), 10))  # Number of neighbors
    
    data
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      lof = calculate_local_outlier_factor(value, baseline, k)
      {value, index, lof}
    end)
    |> Enum.filter(fn {_value, _index, lof} -> lof > 1.5 end)
    |> Enum.map(fn {value, index, lof} ->
      %{
        index: index,
        value: value,
        lof_score: lof,
        type: :local_outlier_factor
      }
    end)
  end
  
  defp detect_vsm_anomalies(data, baseline) do
    # VSM-based anomaly detection using variety engineering
    vsm_baseline = build_vsm_baseline(baseline)
    
    data
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      variety = calculate_variety(value)
      expected_variety = vsm_baseline.expected_variety
      variety_ratio = variety / expected_variety
      
      anomaly = %{
        index: index,
        value: value,
        variety: variety,
        variety_ratio: variety_ratio,
        type: :vsm_based
      }
      
      # Check VSM anomaly conditions
      cond do
        variety_ratio < 0.5 ->
          Map.put(anomaly, :vsm_violation, :insufficient_variety)
        variety_ratio > 2.0 ->
          Map.put(anomaly, :vsm_violation, :excessive_variety)
        check_recursion_anomaly(value, vsm_baseline) ->
          Map.put(anomaly, :vsm_violation, :recursion_breakdown)
        check_algedonic_signal(value, vsm_baseline) ->
          Map.put(anomaly, :vsm_violation, :algedonic_alert)
        true ->
          nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
  
  defp calculate_dynamic_threshold(baseline) do
    # Dynamic threshold based on baseline characteristics
    std_dev = calculate_baseline_std(baseline)
    iqr = calculate_iqr(baseline)
    
    # Combine multiple factors
    base_threshold = 3.0  # 3 standard deviations
    
    # Adjust based on data distribution
    adjustment = cond do
      iqr / std_dev > 1.5 -> 0.5   # Heavy-tailed distribution
      iqr / std_dev < 0.8 -> -0.5  # Light-tailed distribution
      true -> 0.0
    end
    
    base_threshold + adjustment
  end
  
  defp build_isolation_forest(baseline) do
    # Build simplified isolation trees
    n_trees = 100
    sample_size = min(256, length(baseline))
    
    trees = for _ <- 1..n_trees do
      sample = Enum.take_random(baseline, sample_size)
      build_isolation_tree(sample, 0)
    end
    
    %{
      trees: trees,
      sample_size: sample_size,
      n_trees: n_trees
    }
  end
  
  defp build_isolation_tree(data, depth) when length(data) <= 1 or depth > 10 do
    %{type: :leaf, size: length(data), depth: depth}
  end
  
  defp build_isolation_tree(data, depth) do
    # Random split
    values = Enum.uniq(data)
    
    if length(values) == 1 do
      %{type: :leaf, size: length(data), depth: depth}
    else
      min_val = Enum.min(values)
      max_val = Enum.max(values)
      split_value = min_val + :rand.uniform() * (max_val - min_val)
      
      {left_data, right_data} = Enum.split_with(data, &(&1 < split_value))
      
      %{
        type: :internal,
        split_value: split_value,
        left: build_isolation_tree(left_data, depth + 1),
        right: build_isolation_tree(right_data, depth + 1),
        depth: depth
      }
    end
  end
  
  defp calculate_isolation_score(value, forest) do
    path_lengths = Enum.map(forest.trees, fn tree ->
      path_length(value, tree, 0)
    end)
    
    avg_path_length = Enum.sum(path_lengths) / length(path_lengths)
    expected_length = expected_path_length(forest.sample_size)
    
    :math.pow(2, -avg_path_length / expected_length)
  end
  
  defp path_length(_value, %{type: :leaf, depth: depth}, current_depth) do
    current_depth + depth
  end
  
  defp path_length(value, %{type: :internal} = node, current_depth) do
    if value < node.split_value do
      path_length(value, node.left, current_depth + 1)
    else
      path_length(value, node.right, current_depth + 1)
    end
  end
  
  defp expected_path_length(n) when n > 2 do
    2 * (:math.log(n - 1) + 0.5772156649) - (2 * (n - 1) / n)
  end
  defp expected_path_length(_), do: 1.0
  
  defp calculate_local_outlier_factor(value, baseline, k) do
    # Calculate k-nearest neighbors
    distances = Enum.map(baseline, fn baseline_value ->
      abs(value - baseline_value)
    end)
    
    k_distances = distances
                  |> Enum.sort()
                  |> Enum.take(k)
    
    if length(k_distances) >= k do
      # Local reachability density
      lrd = calculate_lrd(value, baseline, k_distances)
      
      # LOF score
      neighbor_lrds = Enum.map(Enum.take(baseline, k), fn neighbor ->
        neighbor_distances = Enum.map(baseline, &abs(neighbor - &1))
                            |> Enum.sort()
                            |> Enum.take(k)
        calculate_lrd(neighbor, baseline, neighbor_distances)
      end)
      
      avg_neighbor_lrd = Enum.sum(neighbor_lrds) / length(neighbor_lrds)
      
      if lrd > 0 do
        avg_neighbor_lrd / lrd
      else
        2.0  # High anomaly score for zero density
      end
    else
      1.0  # Normal score if not enough neighbors
    end
  end
  
  defp calculate_lrd(value, baseline, k_distances) do
    reach_distances = Enum.map(k_distances, fn dist ->
      max(dist, Enum.at(k_distances, -1))
    end)
    
    sum_reach = Enum.sum(reach_distances)
    
    if sum_reach > 0 do
      length(k_distances) / sum_reach
    else
      0.0
    end
  end
  
  defp build_vsm_baseline(baseline) do
    variety_values = Enum.map(baseline, &calculate_variety/1)
    
    %{
      expected_variety: Statistics.mean(variety_values),
      variety_std: Statistics.stdev(variety_values),
      recursion_levels: analyze_recursion_levels(baseline),
      algedonic_threshold: calculate_algedonic_threshold(baseline),
      viable_range: calculate_viable_range(baseline)
    }
  end
  
  defp calculate_variety(value) when is_number(value) do
    # Simplified variety calculation
    # In practice, this would analyze the complexity/information content
    abs(value) * :math.log(abs(value) + 1)
  end
  
  defp calculate_variety(value) when is_list(value) do
    length(Enum.uniq(value))
  end
  
  defp calculate_variety(_), do: 1.0
  
  defp check_recursion_anomaly(value, vsm_baseline) do
    # Check if recursion levels are violated
    current_recursion = analyze_value_recursion(value)
    expected_levels = vsm_baseline.recursion_levels
    
    abs(current_recursion - expected_levels) > 2
  end
  
  defp check_algedonic_signal(value, vsm_baseline) do
    # Check for pain/pleasure signals indicating critical anomaly
    abs(value) > vsm_baseline.algedonic_threshold
  end
  
  defp analyze_recursion_levels(baseline) do
    # Analyze typical recursion depth in the system
    # Simplified implementation
    5  # Typical VSM has 5 recursion levels
  end
  
  defp analyze_value_recursion(value) when is_number(value) do
    # Estimate recursion level from value characteristics
    :math.log(abs(value) + 1) / :math.log(2)
  end
  
  defp analyze_value_recursion(_), do: 1
  
  defp calculate_algedonic_threshold(baseline) do
    # Calculate threshold for algedonic (pain/pleasure) signals
    values = Enum.map(baseline, &abs/1)
    mean = Statistics.mean(values)
    std = Statistics.stdev(values)
    
    mean + 4 * std  # Very high threshold for critical signals
  end
  
  defp calculate_viable_range(baseline) do
    sorted = Enum.sort(baseline)
    q1 = Enum.at(sorted, div(length(sorted), 4))
    q3 = Enum.at(sorted, div(3 * length(sorted), 4))
    iqr = q3 - q1
    
    %{
      min: q1 - 1.5 * iqr,
      max: q3 + 1.5 * iqr
    }
  end
  
  defp classify_anomaly(anomaly) do
    severity = case anomaly do
      %{vsm_violation: :algedonic_alert} -> :critical
      %{vsm_violation: :recursion_breakdown} -> :high
      %{z_score: z} when abs(z) > 4 -> :high
      %{isolation_score: score} when score > 0.8 -> :high
      %{lof_score: lof} when lof > 2.0 -> :medium
      _ -> :low
    end
    
    Map.put(anomaly, :severity, severity)
  end
  
  defp calculate_severity(classified_anomalies) do
    severities = Enum.map(classified_anomalies, & &1.severity)
    
    cond do
      :critical in severities -> :critical
      :high in severities -> :high
      :medium in severities -> :medium
      length(severities) > 0 -> :low
      true -> :none
    end
  end
  
  defp any_critical?(classified_anomalies) do
    Enum.any?(classified_anomalies, &(&1.severity == :critical))
  end
  
  defp describe_anomalies(anomalies) do
    descriptions = Enum.map(anomalies, &describe_single_anomaly/1)
    
    case length(descriptions) do
      0 -> "No anomalies detected"
      1 -> List.first(descriptions)
      n -> "#{n} anomalies detected: #{Enum.join(descriptions, "; ")}"
    end
  end
  
  defp describe_single_anomaly(anomaly) do
    base = "Anomaly at index #{anomaly.index}"
    
    details = case anomaly do
      %{vsm_violation: violation} ->
        "VSM violation: #{violation}"
      %{z_score: z} ->
        "Statistical outlier (z-score: #{Float.round(z, 2)})"
      %{isolation_score: score} ->
        "Isolated point (score: #{Float.round(score, 2)})"
      %{lof_score: lof} ->
        "Local outlier (LOF: #{Float.round(lof, 2)})"
      _ ->
        "Unknown type"
    end
    
    "#{base} - #{details}"
  end
  
  defp generate_recommendations(anomalies, baseline) do
    recommendations = []
    
    # VSM-specific recommendations
    vsm_violations = Enum.filter(anomalies, &Map.has_key?(&1, :vsm_violation))
    
    recommendations = if Enum.any?(vsm_violations, &(&1.vsm_violation == :insufficient_variety)) do
      ["Increase system variety to handle environmental complexity" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(vsm_violations, &(&1.vsm_violation == :excessive_variety)) do
      ["Apply variety filters to reduce unnecessary complexity" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(vsm_violations, &(&1.vsm_violation == :recursion_breakdown)) do
      ["Check communication channels between recursion levels" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(anomalies, &(&1.severity == :critical)) do
      ["URGENT: Activate algedonic response - system viability threatened" | recommendations]
    else
      recommendations
    end
    
    # General recommendations
    if length(anomalies) > length(baseline) * 0.2 do
      ["High anomaly rate detected - review baseline parameters" | recommendations]
    else
      recommendations
    end
  end
  
  defp calculate_baseline_mean(baseline) do
    Enum.sum(baseline) / length(baseline)
  end
  
  defp calculate_baseline_std(baseline) do
    mean = calculate_baseline_mean(baseline)
    variance = Enum.map(baseline, fn x -> :math.pow(x - mean, 2) end)
               |> Enum.sum()
               |> Kernel./(length(baseline))
    
    :math.sqrt(variance)
  end
  
  defp calculate_iqr(baseline) do
    sorted = Enum.sort(baseline)
    q1_index = div(length(sorted), 4)
    q3_index = div(3 * length(sorted), 4)
    
    q1 = Enum.at(sorted, q1_index)
    q3 = Enum.at(sorted, q3_index)
    
    q3 - q1
  end
  
  defp generate_anomaly_id do
    "anom_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end