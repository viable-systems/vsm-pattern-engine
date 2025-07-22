defmodule VsmPatternEngine.Application do
  @moduledoc """
  Main application supervisor for VSM Pattern Engine.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Finch HTTP client for vector store communication
      {Finch, name: VsmPatternEngine.Finch},
      
      # Pattern detection supervisors
      VsmPatternEngine.Temporal.Supervisor,
      VsmPatternEngine.Correlation.Supervisor,
      VsmPatternEngine.Anomaly.Supervisor,
      
      # Vector store client
      VsmPatternEngine.VectorStore.Client,
      
      # Main pattern engine
      VsmPatternEngine.Engine,
      
      # Telemetry
      VsmPatternEngine.Telemetry
    ]

    opts = [strategy: :one_for_one, name: VsmPatternEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end