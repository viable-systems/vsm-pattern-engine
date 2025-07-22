# VSM Pattern Engine

An Elixir-based pattern recognition and anomaly detection engine implementing Viable System Model (VSM) principles. This engine provides sophisticated temporal pattern detection, correlation analysis, and anomaly detection capabilities with deep integration to the VSM Vector Store.

## Features

### Core Capabilities

- **Temporal Pattern Detection**: Identifies periodic, trend, burst, decay, and cyclic patterns in time-series data
- **Correlation Analysis**: Discovers relationships between patterns using multiple correlation methods
- **Anomaly Detection**: Multi-method anomaly detection including statistical, isolation forest, and VSM-based approaches
- **VSM Integration**: Built on Viable System Model principles with variety engineering and recursive system analysis

### VSM-Specific Features

- **Variety Management**: Monitors and manages system variety according to Ashby's Law
- **Recursion Level Analysis**: Tracks VSM's 5 levels of recursion
- **Algedonic Signals**: Critical anomaly detection through VSM pain/pleasure channels
- **Viability Assessment**: Continuous system viability scoring

### Technical Features

- **High Performance**: Built with Elixir/OTP for concurrent processing
- **Vector Store Integration**: Seamless integration with VSM Vector Store for pattern persistence
- **Real-time Processing**: Stream processing capabilities for live data
- **Telemetry**: Comprehensive metrics and monitoring
- **Fault Tolerance**: Supervised processes with automatic recovery

## Installation

Add `vsm_pattern_engine` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vsm_pattern_engine, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Start the pattern engine
{:ok, _} = VsmPatternEngine.Application.start(:normal, [])

# Analyze patterns in data
data = [1.0, 2.1, 3.0, 3.9, 5.1, 6.0, 7.1, 8.0]
{:ok, pattern_result} = VsmPatternEngine.Engine.analyze_pattern(data)

# Detect anomalies
baseline = [1.0, 1.1, 0.9, 1.0, 1.2, 0.8, 1.1]
new_data = [1.0, 1.1, 5.0, 1.0]  # Contains anomaly
{:ok, anomaly_result} = VsmPatternEngine.Engine.detect_anomaly(new_data, baseline)

# Find correlations between pattern sets
pattern_sets = [pattern1, pattern2, pattern3]
{:ok, correlation_result} = VsmPatternEngine.Engine.correlate_patterns(pattern_sets)
```

## Configuration

Configure the engine in your `config.exs`:

```elixir
config :vsm_pattern_engine,
  vector_store_url: "http://localhost:4000/api",
  vector_store_api_key: "your-api-key",
  detection_interval: 5000,
  anomaly_threshold: 0.8,
  correlation_threshold: 0.7

# VSM-specific configuration
config :vsm_pattern_engine, :vsm,
  recursion_levels: 5,
  variety_management: :requisite,
  feedback_loops: true,
  algedonic_signals: true
```

## Architecture

### Module Structure

```
lib/vsm_pattern_engine/
├── application.ex          # Main application supervisor
├── engine.ex              # Core pattern engine
├── telemetry.ex           # Metrics and monitoring
├── temporal/              # Temporal pattern detection
│   ├── detector.ex
│   ├── window.ex
│   ├── analyzer.ex
│   └── pattern.ex
├── correlation/           # Correlation analysis
│   ├── analyzer.ex
│   ├── matrix.ex
│   ├── statistics.ex
│   └── relationship.ex
├── anomaly/              # Anomaly detection
│   ├── detector.ex
│   ├── algorithms.ex
│   ├── threshold.ex
│   └── classification.ex
└── vector_store/         # Vector store integration
    ├── client.ex
    ├── encoder.ex
    ├── query.ex
    └── connection.ex
```

### VSM Integration

The engine implements VSM principles through:

1. **System Levels**: Monitors patterns at different recursion levels
2. **Variety Engineering**: Balances system variety with environmental complexity
3. **Feedback Loops**: Continuous adaptation based on detected patterns
4. **Algedonic Channel**: Fast-track critical anomaly alerts

## Pattern Detection

### Temporal Patterns

The engine detects various temporal patterns:

- **Periodic**: Regular repeating patterns (e.g., daily cycles)
- **Trend**: Linear or exponential trends
- **Burst**: Sudden spikes or activity bursts
- **Decay**: Exponential decay patterns
- **Cyclic**: Complex non-sinusoidal cycles

### Example

```elixir
# Detect periodic patterns
hourly_data = generate_hourly_data(7 * 24)  # One week
{:ok, result} = VsmPatternEngine.Temporal.Detector.analyze(hourly_data, 
  window_size: 24,
  slide_interval: 1
)

# Access detected patterns
periodic_patterns = Enum.filter(result.patterns, &(&1.type == :periodic))
```

## Anomaly Detection

### Detection Methods

1. **Statistical**: Z-score and IQR-based detection
2. **Isolation Forest**: Tree-based anomaly isolation
3. **Local Outlier Factor**: Density-based detection
4. **VSM-Based**: Variety and recursion anomalies

### Example

```elixir
# Configure anomaly detection
opts = [
  method: :vsm_based,
  threshold: 0.9
]

{:ok, result, viability} = VsmPatternEngine.Engine.detect_anomaly(data, baseline, opts)

if result.critical do
  Logger.alert("Critical anomaly detected: #{result.description}")
  # Algedonic signal triggered automatically
end
```

## Correlation Analysis

### Correlation Methods

- **Pearson**: Linear correlation
- **Spearman**: Rank correlation
- **Kendall**: Concordance correlation
- **Mutual Information**: Non-linear relationships

### Example

```elixir
# Analyze correlations with causality
opts = [
  methods: [:pearson, :mutual_information],
  analyze_causality: true,
  threshold: 0.6
]

{:ok, result} = VsmPatternEngine.Correlation.Analyzer.analyze(pattern_sets, opts)

# Access causal relationships
causal_links = result.causal_analysis.causal_links
root_causes = result.causal_analysis.root_causes
```

## Vector Store Integration

The engine integrates with VSM Vector Store for:

- Pattern persistence and retrieval
- Similarity search
- Historical analysis
- Distributed pattern matching

### Example

```elixir
# Search for similar patterns
{:ok, similar} = VsmPatternEngine.VectorStore.Client.search_similar_patterns(
  pattern,
  k: 10,
  type: "periodic"
)

# Query recent anomalies
{:ok, recent_data} = VsmPatternEngine.VectorStore.Client.get_recent_data(
  types: ["anomaly"],
  since: ~U[2024-01-01 00:00:00Z],
  limit: 100
)
```

## Monitoring and Metrics

The engine provides comprehensive telemetry:

```elixir
# Available metrics
metrics = [
  "vsm_pattern_engine.patterns.analyzed.count",
  "vsm_pattern_engine.anomalies.detected.count",
  "vsm_pattern_engine.correlations.found.count",
  "vsm_pattern_engine.vsm.variety_ratio",
  "vsm_pattern_engine.vsm.viability_score"
]

# Subscribe to events
:telemetry.attach(
  "my-handler",
  [:vsm_pattern_engine, :critical_anomaly],
  &MyHandler.handle_critical_anomaly/4,
  nil
)
```

## Performance Optimization

### Concurrent Processing

```elixir
# Process multiple streams concurrently
streams = %{
  sensor_1: data_1,
  sensor_2: data_2,
  sensor_3: data_3
}

{:ok, results} = VsmPatternEngine.Engine.detect_batch(streams, baseline)
```

### Stream Processing

```elixir
# Real-time pattern detection
data_stream
|> VsmPatternEngine.Temporal.Detector.analyze_stream()
|> Stream.filter(&(&1.confidence > 0.8))
|> Stream.each(&process_pattern/1)
|> Stream.run()
```

## Development

### Running Tests

```bash
mix test
```

### Code Quality

```bash
mix credo
mix dialyzer
```

### Documentation

```bash
mix docs
```

## Examples

See the `examples/` directory for:

- Financial market pattern detection
- IoT sensor anomaly detection
- System performance correlation analysis
- VSM viability monitoring

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Based on Stafford Beer's Viable System Model
- Implements Ashby's Law of Requisite Variety
- Inspired by cybernetic management principles

## Support

For issues, questions, or contributions, please visit:
https://github.com/viable-systems/vsm-pattern-engine