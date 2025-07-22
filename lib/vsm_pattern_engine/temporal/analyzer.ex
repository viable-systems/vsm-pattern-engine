defmodule VsmPatternEngine.Temporal.Analyzer do
  @moduledoc """
  Analysis functions for temporal pattern detection.
  """
  
  def detect_periodicity(data) do
    # Simplified periodicity detection using autocorrelation
    case autocorrelation(data) do
      {:ok, correlations} ->
        # Find the first significant peak after lag 0
        case find_period(correlations) do
          nil -> {:error, :no_periodicity}
          {period, strength} -> {:ok, period, strength}
        end
      error -> error
    end
  end
  
  def detect_trend(data) do
    # Linear regression for trend detection
    n = length(data)
    x = Enum.to_list(0..(n-1))
    
    {slope, intercept, r_squared} = linear_regression(x, data)
    
    trend_type = cond do
      abs(slope) < 0.01 -> :flat
      slope > 0 -> :linear_increasing
      slope < 0 -> :linear_decreasing
    end
    
    {:ok, trend_type, slope, r_squared}
  end
  
  def detect_bursts(data) do
    # Detect sudden spikes using z-score
    mean = Enum.sum(data) / length(data)
    std_dev = :math.sqrt(Enum.reduce(data, 0, fn x, acc -> 
      acc + :math.pow(x - mean, 2) 
    end) / length(data))
    
    threshold = mean + 2 * std_dev
    
    bursts = data
             |> Enum.with_index()
             |> Enum.filter(fn {value, _index} -> value > threshold end)
             |> Enum.map(fn {value, index} -> 
               %{index: index, magnitude: value - mean}
             end)
    
    {:ok, bursts}
  end
  
  def detect_decay(data) do
    # Exponential decay detection
    # Fit y = a * exp(-b * x)
    n = length(data)
    x = Enum.to_list(0..(n-1))
    
    # Linearize by taking log
    log_data = Enum.map(data, fn y -> 
      if y > 0, do: :math.log(y), else: 0.0
    end)
    
    {slope, _intercept, r_squared} = linear_regression(x, log_data)
    
    if slope < -0.01 and r_squared > 0.85 do
      decay_rate = -slope
      half_life = :math.log(2) / decay_rate
      {:ok, decay_rate, half_life, r_squared}
    else
      {:error, :no_decay}
    end
  end
  
  def detect_cycles(data) do
    # Detect cycles by finding zero crossings
    mean = Enum.sum(data) / length(data)
    centered = Enum.map(data, &(&1 - mean))
    
    zero_crossings = find_zero_crossings(centered)
    
    if length(zero_crossings) >= 2 do
      cycles = zero_crossings
               |> Enum.chunk_every(2, 1, :discard)
               |> Enum.map(fn [start_idx, end_idx] ->
                 %{
                   start: start_idx,
                   end: end_idx,
                   duration: end_idx - start_idx
                 }
               end)
      
      {:ok, cycles}
    else
      {:error, :no_cycles}
    end
  end
  
  def calculate_phase(data, period) do
    # Calculate phase offset for periodic signal
    n = length(data)
    
    # Generate reference sine wave
    reference = for i <- 0..(n-1), do: :math.sin(2 * :math.pi * i / period)
    
    # Cross-correlation to find phase
    max_lag = round(period / 4)
    correlations = for lag <- -max_lag..max_lag do
      shifted_ref = if lag >= 0 do
        Enum.drop(reference, lag) ++ List.duplicate(0, lag)
      else
        List.duplicate(0, -lag) ++ Enum.drop(reference, n + lag)
      end
      
      correlation = pearson_correlation(data, shifted_ref)
      {lag, correlation}
    end
    
    {best_lag, _} = Enum.max_by(correlations, fn {_lag, corr} -> corr end)
    
    # Convert lag to phase
    2 * :math.pi * best_lag / period
  end
  
  # Helper functions
  
  defp autocorrelation(data) do
    n = length(data)
    max_lag = div(n, 2)
    
    correlations = for lag <- 0..max_lag do
      if lag == 0 do
        {0, 1.0}
      else
        data1 = Enum.take(data, n - lag)
        data2 = Enum.drop(data, lag)
        corr = pearson_correlation(data1, data2)
        {lag, corr}
      end
    end
    
    {:ok, correlations}
  end
  
  defp find_period(correlations) do
    # Skip lag 0 and find first significant peak
    correlations
    |> Enum.drop(1)
    |> Enum.filter(fn {_lag, corr} -> corr > 0.5 end)
    |> Enum.find(fn {lag, corr} ->
      # Check if it's a local maximum
      prev = Enum.find(correlations, fn {l, _} -> l == lag - 1 end)
      next = Enum.find(correlations, fn {l, _} -> l == lag + 1 end)
      
      case {prev, next} do
        {{_, prev_corr}, {_, next_corr}} ->
          corr > prev_corr and corr > next_corr
        _ ->
          false
      end
    end)
  end
  
  defp linear_regression(x, y) do
    n = length(x)
    sum_x = Enum.sum(x)
    sum_y = Enum.sum(y)
    sum_xy = Enum.zip(x, y) |> Enum.map(fn {xi, yi} -> xi * yi end) |> Enum.sum()
    sum_x2 = Enum.map(x, &(&1 * &1)) |> Enum.sum()
    sum_y2 = Enum.map(y, &(&1 * &1)) |> Enum.sum()
    
    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    intercept = (sum_y - slope * sum_x) / n
    
    # Calculate R-squared
    y_mean = sum_y / n
    ss_tot = Enum.map(y, fn yi -> :math.pow(yi - y_mean, 2) end) |> Enum.sum()
    ss_res = Enum.zip(x, y) 
             |> Enum.map(fn {xi, yi} -> 
               y_pred = slope * xi + intercept
               :math.pow(yi - y_pred, 2)
             end) 
             |> Enum.sum()
    
    r_squared = if ss_tot > 0, do: 1 - ss_res / ss_tot, else: 0
    
    {slope, intercept, r_squared}
  end
  
  defp pearson_correlation(data1, data2) do
    n = min(length(data1), length(data2))
    
    if n < 2 do
      0.0
    else
      data1 = Enum.take(data1, n)
      data2 = Enum.take(data2, n)
      
      mean1 = Enum.sum(data1) / n
      mean2 = Enum.sum(data2) / n
      
      covariance = Enum.zip(data1, data2)
                   |> Enum.map(fn {x, y} -> (x - mean1) * (y - mean2) end)
                   |> Enum.sum()
                   |> Kernel./(n)
      
      std1 = :math.sqrt(Enum.map(data1, fn x -> :math.pow(x - mean1, 2) end) |> Enum.sum() |> Kernel./(n))
      std2 = :math.sqrt(Enum.map(data2, fn x -> :math.pow(x - mean2, 2) end) |> Enum.sum() |> Kernel./(n))
      
      if std1 > 0 and std2 > 0 do
        covariance / (std1 * std2)
      else
        0.0
      end
    end
  end
  
  defp find_zero_crossings(data) do
    data
    |> Enum.with_index()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [{v1, _}, {v2, _}] ->
      (v1 >= 0 and v2 < 0) or (v1 < 0 and v2 >= 0)
    end)
    |> Enum.map(fn [{_, idx1}, _] -> idx1 end)
  end
end