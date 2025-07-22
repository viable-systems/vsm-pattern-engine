defmodule VsmPatternEngine.Correlation.Matrix do
  @moduledoc """
  Matrix operations for correlation analysis.
  """
  
  def new(rows, cols) do
    for _ <- 1..rows do
      for _ <- 1..cols, do: 0.0
    end
  end
  
  def get(matrix, row, col) do
    matrix
    |> Enum.at(row, [])
    |> Enum.at(col, 0.0)
  end
  
  def set(matrix, row, col, value) do
    List.update_at(matrix, row, fn row_data ->
      List.update_at(row_data, col, fn _ -> value end)
    end)
  end
  
  def rows(matrix) do
    length(matrix)
  end
  
  def cols(matrix) do
    case matrix do
      [row | _] -> length(row)
      [] -> 0
    end
  end
end