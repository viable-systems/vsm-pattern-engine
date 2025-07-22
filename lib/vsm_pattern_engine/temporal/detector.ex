defmodule VsmPatternEngine.Temporal.Detector do
  @moduledoc """
  Temporal pattern detection module for identifying patterns over time.
  Uses sliding windows, frequency analysis, and trend detection.
  """
  
  require Logger
  alias VsmPatternEngine.Temporal.{Window, Analyzer, Pattern}
  
  @default_window_size 100
  @default_slide_interval 10
  @pattern_types [:periodic, :trend, :burst, :decay, :cyclic]
  
  def analyze(data, opts \\ []) do
    window_size = opts[:window_size] || @default_window_size
    slide_interval = opts[:slide_interval] || @default_slide_interval
    
    # Create sliding windows
    windows = Window.create_sliding_windows(data, window_size, slide_interval)
    
    # Analyze each window for patterns
    patterns = Enum.flat_map(windows, &analyze_window/1)
    
    # Aggregate and classify patterns
    result = %{
      id: generate_pattern_id(),
      timestamp: DateTime.utc_now(),
      data_points: length(data),
      patterns: patterns,
      summary: summarize_patterns(patterns),
      dominant_pattern: find_dominant_pattern(patterns),
      confidence: calculate_confidence(patterns)
    }
    
    {:ok, result}
  end
  
  def analyze_stream(data_stream) do
    data_stream
    |> Stream.chunk_every(@default_window_size, @default_slide_interval)
    |> Stream.map(&analyze_window/1)
    |> Stream.filter(&significant_pattern?/1)
  end
  
  defp analyze_window(window) do
    window_data = Window.extract_data(window)
    
    Enum.reduce(@pattern_types, [], fn pattern_type, acc ->
      case detect_pattern_type(pattern_type, window_data) do
        nil -> acc
        pattern -> [pattern | acc]
      end
    end)
  end
  
  defp detect_pattern_type(:periodic, data) do
    # Detect periodic patterns using FFT or autocorrelation
    case Analyzer.detect_periodicity(data) do
      {:ok, period, strength} when strength > 0.7 ->
        %Pattern{
          type: :periodic,
          period: period,
          strength: strength,
          data: data,
          metadata: %{
            frequency: 1.0 / period,
            phase: Analyzer.calculate_phase(data, period)
          }
        }
      _ -> nil
    end
  end
  
  defp detect_pattern_type(:trend, data) do
    # Detect linear or exponential trends
    case Analyzer.detect_trend(data) do
      {:ok, trend_type, slope, r_squared} when r_squared > 0.8 ->
        %Pattern{
          type: :trend,
          subtype: trend_type,
          strength: r_squared,
          data: data,
          metadata: %{
            slope: slope,
            direction: if(slope > 0, do: :increasing, else: :decreasing),
            rate: abs(slope)
          }
        }
      _ -> nil
    end
  end
  
  defp detect_pattern_type(:burst, data) do
    # Detect sudden spikes or bursts
    case Analyzer.detect_bursts(data) do
      {:ok, bursts} when length(bursts) > 0 ->
        %Pattern{
          type: :burst,
          instances: bursts,
          strength: calculate_burst_strength(bursts, data),
          data: data,
          metadata: %{
            burst_count: length(bursts),
            avg_magnitude: average_burst_magnitude(bursts),
            burst_indices: Enum.map(bursts, & &1.index)
          }
        }
      _ -> nil
    end
  end
  
  defp detect_pattern_type(:decay, data) do
    # Detect exponential decay patterns
    case Analyzer.detect_decay(data) do
      {:ok, decay_rate, half_life, r_squared} when r_squared > 0.85 ->
        %Pattern{
          type: :decay,
          decay_rate: decay_rate,
          strength: r_squared,
          data: data,
          metadata: %{
            half_life: half_life,
            time_constant: 1.0 / decay_rate,
            projected_end: calculate_decay_end(data, decay_rate)
          }
        }
      _ -> nil
    end
  end
  
  defp detect_pattern_type(:cyclic, data) do
    # Detect complex cyclic patterns (non-sinusoidal)
    case Analyzer.detect_cycles(data) do
      {:ok, cycles} when length(cycles) > 1 ->
        %Pattern{
          type: :cyclic,
          cycles: cycles,
          strength: calculate_cycle_regularity(cycles),
          data: data,
          metadata: %{
            cycle_count: length(cycles),
            avg_duration: average_cycle_duration(cycles),
            variability: cycle_variability(cycles)
          }
        }
      _ -> nil
    end
  end
  
  defp significant_pattern?(patterns) do
    Enum.any?(patterns, fn pattern ->
      pattern.strength > 0.6
    end)
  end
  
  defp summarize_patterns(patterns) do
    patterns
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, type_patterns} ->
      {type, %{
        count: length(type_patterns),
        avg_strength: average_strength(type_patterns),
        max_strength: max_strength(type_patterns)
      }}
    end)
    |> Map.new()
  end
  
  defp find_dominant_pattern(patterns) do
    patterns
    |> Enum.max_by(& &1.strength, fn -> nil end)
  end
  
  defp calculate_confidence(patterns) do
    case patterns do
      [] -> 0.0
      _ ->
        strengths = Enum.map(patterns, & &1.strength)
        consistency = calculate_consistency(patterns)
        
        (Enum.sum(strengths) / length(strengths) + consistency) / 2
    end
  end
  
  defp calculate_consistency(patterns) do
    # Measure how consistent patterns are across the data
    grouped = Enum.group_by(patterns, & &1.type)
    
    consistencies = Enum.map(grouped, fn {_type, type_patterns} ->
      if length(type_patterns) > 1 do
        # Calculate variance in pattern parameters
        1.0 - calculate_parameter_variance(type_patterns)
      else
        0.5  # Neutral consistency for single patterns
      end
    end)
    
    if length(consistencies) > 0 do
      Enum.sum(consistencies) / length(consistencies)
    else
      0.0
    end
  end
  
  defp calculate_parameter_variance(patterns) do
    # Implementation depends on pattern type
    # This is a simplified version
    strengths = Enum.map(patterns, & &1.strength)
    Statistics.variance(strengths) / Statistics.mean(strengths)
  end
  
  defp calculate_burst_strength(bursts, data) do
    burst_energy = Enum.sum(Enum.map(bursts, & &1.magnitude))
    total_energy = Enum.sum(Enum.map(data, &abs/1))
    
    if total_energy > 0 do
      min(burst_energy / total_energy, 1.0)
    else
      0.0
    end
  end
  
  defp average_burst_magnitude(bursts) do
    magnitudes = Enum.map(bursts, & &1.magnitude)
    Enum.sum(magnitudes) / length(magnitudes)
  end
  
  defp calculate_cycle_regularity(cycles) do
    durations = Enum.map(cycles, & &1.duration)
    
    if length(durations) > 1 do
      mean = Statistics.mean(durations)
      std_dev = Statistics.standard_deviation(durations)
      
      # Coefficient of variation (lower is more regular)
      cv = std_dev / mean
      
      # Convert to regularity score (0-1, higher is more regular)
      1.0 / (1.0 + cv)
    else
      0.5
    end
  end
  
  defp average_cycle_duration(cycles) do
    durations = Enum.map(cycles, & &1.duration)
    Statistics.mean(durations)
  end
  
  defp cycle_variability(cycles) do
    durations = Enum.map(cycles, & &1.duration)
    Statistics.standard_deviation(durations)
  end
  
  defp average_strength(patterns) do
    strengths = Enum.map(patterns, & &1.strength)
    Enum.sum(strengths) / length(strengths)
  end
  
  defp max_strength(patterns) do
    patterns
    |> Enum.map(& &1.strength)
    |> Enum.max(fn -> 0.0 end)
  end
  
  defp calculate_decay_end(data, decay_rate) do
    # Estimate when signal will decay to ~1% of initial value
    initial = List.first(data, 0)
    if initial > 0 do
      -log(0.01) / decay_rate
    else
      nil
    end
  end
  
  defp generate_pattern_id do
    "pat_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end