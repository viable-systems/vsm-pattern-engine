defmodule VsmPatternEngine.Correlation.Statistics do
  @moduledoc """
  Statistical functions for correlation analysis.
  """
  
  def pearson_correlation(data1, data2) do
    n = min(length(data1), length(data2))
    
    if n < 2 do
      0.0
    else
      data1 = Enum.take(data1, n)
      data2 = Enum.take(data2, n)
      
      mean1 = mean(data1)
      mean2 = mean(data2)
      
      covariance = Enum.zip(data1, data2)
                   |> Enum.map(fn {x, y} -> (x - mean1) * (y - mean2) end)
                   |> Enum.sum()
                   |> Kernel./(n)
      
      std1 = standard_deviation(data1)
      std2 = standard_deviation(data2)
      
      if std1 > 0 and std2 > 0 do
        covariance / (std1 * std2)
      else
        0.0
      end
    end
  end
  
  def spearman_correlation(data1, data2) do
    # Convert to ranks
    ranks1 = to_ranks(data1)
    ranks2 = to_ranks(data2)
    
    # Calculate Pearson correlation on ranks
    pearson_correlation(ranks1, ranks2)
  end
  
  def kendall_correlation(data1, data2) do
    n = min(length(data1), length(data2))
    data1 = Enum.take(data1, n)
    data2 = Enum.take(data2, n)
    
    pairs = for i <- 0..(n-2), j <- (i+1)..(n-1), do: {i, j}
    
    {concordant, discordant} = Enum.reduce(pairs, {0, 0}, fn {i, j}, {c, d} ->
      x1 = Enum.at(data1, i)
      x2 = Enum.at(data1, j)
      y1 = Enum.at(data2, i)
      y2 = Enum.at(data2, j)
      
      sign_x = sign(x2 - x1)
      sign_y = sign(y2 - y1)
      
      if sign_x * sign_y > 0 do
        {c + 1, d}
      else
        {c, d + 1}
      end
    end)
    
    total_pairs = div(n * (n - 1), 2)
    
    if total_pairs > 0 do
      (concordant - discordant) / total_pairs
    else
      0.0
    end
  end
  
  def mutual_information(data1, data2) do
    # Simplified mutual information calculation
    # In practice, would use binning or kernel density estimation
    n = min(length(data1), length(data2))
    
    if n < 10 do
      0.0
    else
      # Simple binning approach
      bins = 10
      h1 = entropy(data1, bins)
      h2 = entropy(data2, bins)
      h12 = joint_entropy(data1, data2, bins)
      
      h1 + h2 - h12
    end
  end
  
  def max_mutual_information(data1, data2) do
    # Maximum possible mutual information
    bins = 10
    h1 = entropy(data1, bins)
    h2 = entropy(data2, bins)
    
    min(h1, h2)
  end
  
  def mean(data) do
    if length(data) > 0 do
      Enum.sum(data) / length(data)
    else
      0.0
    end
  end
  
  def variance(data) do
    m = mean(data)
    
    if length(data) > 1 do
      Enum.map(data, fn x -> :math.pow(x - m, 2) end)
      |> Enum.sum()
      |> Kernel./(length(data) - 1)
    else
      0.0
    end
  end
  
  def standard_deviation(data) do
    :math.sqrt(variance(data))
  end
  
  # Helper functions
  
  defp to_ranks(data) do
    indexed = Enum.with_index(data)
    sorted = Enum.sort_by(indexed, fn {value, _} -> value end)
    
    ranks = sorted
            |> Enum.with_index(1)
            |> Enum.map(fn {{_value, orig_idx}, rank} -> {orig_idx, rank} end)
            |> Enum.sort_by(fn {idx, _} -> idx end)
            |> Enum.map(fn {_, rank} -> rank end)
    
    ranks
  end
  
  defp sign(x) when x > 0, do: 1
  defp sign(x) when x < 0, do: -1
  defp sign(_), do: 0
  
  defp entropy(data, bins) do
    {min_val, max_val} = Enum.min_max(data)
    bin_width = (max_val - min_val) / bins
    
    if bin_width == 0 do
      0.0
    else
      counts = count_bins(data, min_val, bin_width, bins)
      n = length(data)
      
      counts
      |> Enum.filter(&(&1 > 0))
      |> Enum.map(fn count ->
        p = count / n
        -p * :math.log2(p)
      end)
      |> Enum.sum()
    end
  end
  
  defp joint_entropy(data1, data2, bins) do
    n = min(length(data1), length(data2))
    data1 = Enum.take(data1, n)
    data2 = Enum.take(data2, n)
    
    {min1, max1} = Enum.min_max(data1)
    {min2, max2} = Enum.min_max(data2)
    
    bin_width1 = (max1 - min1) / bins
    bin_width2 = (max2 - min2) / bins
    
    if bin_width1 == 0 or bin_width2 == 0 do
      0.0
    else
      # Count joint occurrences
      joint_counts = Enum.zip(data1, data2)
                     |> Enum.reduce(%{}, fn {x, y}, acc ->
                       bin1 = min(div(trunc((x - min1) / bin_width1), bins - 1), bins - 1)
                       bin2 = min(div(trunc((y - min2) / bin_width2), bins - 1), bins - 1)
                       Map.update(acc, {bin1, bin2}, 1, &(&1 + 1))
                     end)
      
      joint_counts
      |> Map.values()
      |> Enum.map(fn count ->
        p = count / n
        -p * :math.log2(p)
      end)
      |> Enum.sum()
    end
  end
  
  defp count_bins(data, min_val, bin_width, bins) do
    Enum.reduce(data, List.duplicate(0, bins), fn value, counts ->
      bin = min(div(trunc((value - min_val) / bin_width), bins - 1), bins - 1)
      List.update_at(counts, bin, &(&1 + 1))
    end)
  end
end