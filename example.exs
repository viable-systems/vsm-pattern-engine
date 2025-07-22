# VSM Pattern Engine Example
# 
# This script demonstrates the basic functionality of the VSM Pattern Engine

IO.puts("=== VSM Pattern Engine Demo ===\n")

# Start the application (simplified, without full OTP supervision)
{:ok, _} = Finch.start_link(name: VsmPatternEngine.Finch)

# 1. Temporal Pattern Detection
IO.puts("1. Temporal Pattern Detection")
IO.puts("----------------------------")

# Generate some sample data with a periodic pattern
periodic_data = for i <- 0..99, do: :math.sin(i * 2 * :math.pi / 10) + :rand.normal() * 0.1
IO.puts("Generated periodic data with period ~10")

{:ok, pattern_result} = VsmPatternEngine.Temporal.Detector.analyze(periodic_data)
IO.puts("Detected #{length(pattern_result.patterns)} patterns")
IO.puts("Dominant pattern: #{inspect(pattern_result.dominant_pattern && pattern_result.dominant_pattern.type)}")
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
pattern3 = %{id: "p3", data: Enum.map(base, &(:rand.normal()))}  # Uncorrelated

{:ok, correlation_result} = VsmPatternEngine.Correlation.Analyzer.analyze([pattern1, pattern2, pattern3])
IO.puts("Significant correlations found: #{correlation_result.significant}")
IO.puts("Number of relationships: #{length(correlation_result.relationships)}")

if correlation_result.strongest_correlation do
  IO.puts("Strongest correlation: #{Float.round(correlation_result.strongest_correlation.correlation, 3)}")
  IO.puts("Direction: #{correlation_result.strongest_correlation.direction}")
end

IO.puts("\n=== Demo Complete ===")