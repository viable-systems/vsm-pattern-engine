defmodule VsmPatternEngine.Anomaly.Supervisor do
  @moduledoc """
  Supervisor for anomaly detection components.
  """
  
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Workers for anomaly detection
      {Task.Supervisor, name: VsmPatternEngine.Anomaly.TaskSupervisor},
      {VsmPatternEngine.Anomaly.AlertManager, []},
      {VsmPatternEngine.Anomaly.BaselineManager, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end