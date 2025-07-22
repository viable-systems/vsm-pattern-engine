defmodule VsmPatternEngine.Temporal.Pattern do
  @moduledoc """
  Struct for temporal patterns detected by the engine.
  """
  
  defstruct [
    :type,
    :strength,
    :data,
    :metadata,
    :period,
    :subtype,
    :instances,
    :decay_rate,
    :cycles
  ]
  
  @type t :: %__MODULE__{
    type: atom(),
    strength: float(),
    data: list(),
    metadata: map(),
    period: float() | nil,
    subtype: atom() | nil,
    instances: list() | nil,
    decay_rate: float() | nil,
    cycles: list() | nil
  }
end