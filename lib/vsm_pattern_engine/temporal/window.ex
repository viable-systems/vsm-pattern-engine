defmodule VsmPatternEngine.Temporal.Window do
  @moduledoc """
  Sliding window utilities for temporal pattern detection.
  """
  
  def create_sliding_windows(data, window_size, slide_interval) do
    data
    |> Stream.chunk_every(window_size, slide_interval, :discard)
    |> Enum.map(&create_window/1)
  end
  
  def extract_data(window) do
    window.data
  end
  
  defp create_window(data) do
    %{
      data: data,
      start_index: 0,
      end_index: length(data) - 1,
      size: length(data),
      timestamp: DateTime.utc_now()
    }
  end
end