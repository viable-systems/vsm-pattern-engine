defmodule VsmPatternEngine.Correlation.Supervisor do
  @moduledoc """
  Supervisor for correlation analysis components.
  """
  
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Workers for correlation analysis
      {Task.Supervisor, name: VsmPatternEngine.Correlation.TaskSupervisor},
      {VsmPatternEngine.Correlation.Cache, []},
      {VsmPatternEngine.Correlation.MatrixProcessor, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end