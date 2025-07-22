defmodule VsmPatternEngine.Correlation.Relationship do
  @moduledoc """
  Struct for correlation relationships between patterns.
  """
  
  defstruct [
    :pattern_a_index,
    :pattern_b_index,
    :correlation,
    :strength,
    :direction,
    :confidence
  ]
  
  @type t :: %__MODULE__{
    pattern_a_index: integer(),
    pattern_b_index: integer(),
    correlation: float(),
    strength: float(),
    direction: :positive | :negative,
    confidence: float()
  }
end