defmodule VsmPatternEngine.Temporal.Supervisor do
  @moduledoc """
  Supervisor for temporal pattern detection components.
  """
  
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Workers for temporal detection
      {Task.Supervisor, name: VsmPatternEngine.Temporal.TaskSupervisor},
      {VsmPatternEngine.Temporal.Cache, []},
      {VsmPatternEngine.Temporal.StreamProcessor, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end