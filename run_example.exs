# Run with: mix run run_example.exs

IO.puts("=== VSM Pattern Engine Demo ===\n")

# 1. Temporal Pattern Detection
IO.puts("1. Temporal Pattern Detection")
IO.puts("----------------------------")

# Generate some sample data with a periodic pattern
periodic_data = for i <- 0..99, do: :math.sin(i * 2 * :math.pi / 10) + :rand.normal() * 0.1
IO.puts("Generated periodic data with period ~10")

{:ok, pattern_result} = VsmPatternEngine.Temporal.Detector.analyze(periodic_data)
IO.puts("Detected #{length(pattern_result.patterns)} patterns")

if pattern_result.dominant_pattern do
  IO.puts("Dominant pattern type: #{pattern_result.dominant_pattern.type}")
  IO.puts("Pattern strength: #{Float.round(pattern_result.dominant_pattern.strength, 2)}")
end

IO.puts("Confidence: #{Float.round(pattern_result.confidence, 2)}\n")

# 2. Anomaly Detection
IO.puts("2. Anomaly Detection")
IO.puts("-------------------")

# Create baseline and test data with anomaly
baseline = for _ <- 1..100, do: :rand.normal() * 2 + 10
test_data = [10, 11, 9, 50, 10, 11]  # 50 is an anomaly

{:ok, anomaly_result} = VsmPatternEngine.Anomaly.Detector.detect(test_data, baseline)
IO.puts("Anomaly detected: #{anomaly_result.anomaly_detected}")
IO.puts("Anomaly count: #{anomaly_result.anomaly_count}")
IO.puts("Severity: #{anomaly_result.severity}")
IO.puts("Description: #{anomaly_result.description}\n")

# 3. Correlation Analysis
IO.puts("3. Correlation Analysis")
IO.puts("----------------------")

# Create correlated patterns
base = for _ <- 1..50, do: :rand.normal()
pattern1 = %{id: "p1", data: base}
pattern2 = %{id: "p2", data: Enum.map(base, &(&1 * 2 + 1))}  # Linear transformation
pattern3 = %{id: "p3", data: Enum.map(base, fn _ -> :rand.normal() end)}  # Uncorrelated

{:ok, correlation_result} = VsmPatternEngine.Correlation.Analyzer.analyze([pattern1, pattern2, pattern3])
IO.puts("Significant correlations found: #{correlation_result.significant}")
IO.puts("Number of relationships: #{length(correlation_result.relationships)}")

if correlation_result.strongest_correlation do
  IO.puts("Strongest correlation: #{Float.round(correlation_result.strongest_correlation.correlation, 3)}")
  IO.puts("Direction: #{correlation_result.strongest_correlation.direction}")
end

# 4. VSM Viability (when running with full application)
IO.puts("\n4. VSM System State")
IO.puts("------------------")

# Since we're running without the full OTP app, we'll demonstrate the concepts
vsm_state = %{
  system_1: %{variety: 100, capacity: 150},
  system_2: %{variety: 80, capacity: 120},
  system_3: %{variety: 60, capacity: 100},
  system_4: %{variety: 40, capacity: 80},
  system_5: %{variety: 20, capacity: 50},
  environment: %{variety: 200, uncertainty: 0.3}
}

system_variety = Enum.reduce(1..5, 0, fn i, acc ->
  acc + vsm_state[:"system_#{i}"].variety
end)

variety_ratio = system_variety / vsm_state.environment.variety
IO.puts("Total System Variety: #{system_variety}")
IO.puts("Environment Variety: #{vsm_state.environment.variety}")
IO.puts("Variety Ratio: #{Float.round(variety_ratio, 2)}")
IO.puts("System Viable: #{variety_ratio >= 1.0}")

IO.puts("\n=== Demo Complete ===")
IO.puts("\nTo use the full engine with OTP supervision and vector store:")
IO.puts("1. Start the application: Application.ensure_all_started(:vsm_pattern_engine)")
IO.puts("2. Use VsmPatternEngine.Engine for coordinated analysis")
IO.puts("3. Configure vector store connection in config/config.exs")