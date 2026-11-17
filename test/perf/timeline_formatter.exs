defmodule TimelineFormatter do
  @moduledoc false
  # Logs module and test start/finish wall times (ms since suite start) to $E2E_TIMELINE_OUT.
  use GenServer

  def init(_opts), do: {:ok, %{t0: System.monotonic_time(:millisecond), rows: []}}

  def handle_cast(event, state) do
    now = System.monotonic_time(:millisecond) - state.t0

    row =
      case event do
        {:module_started, %{name: m}} -> ["module_started", now, inspect(m), "", "", ""]
        {:module_finished, %{name: m}} -> ["module_finished", now, inspect(m), "", "", ""]
        {:test_started, t} -> ["test_started", now, inspect(t.module), t.name, "", ""]
        {:test_finished, t} -> ["test_finished", now, inspect(t.module), t.name, div(t.time, 1000), state_of(t)]
        _ -> nil
      end

    state = if row, do: %{state | rows: [row | state.rows]}, else: state

    case event do
      {:suite_finished, _} ->
        out = System.get_env("E2E_TIMELINE_OUT", "timeline.tsv")

        File.write!(
          out,
          state.rows
          |> Enum.reverse()
          |> Enum.map_join("\n", fn r -> Enum.map_join(r, "\t", &to_string/1) end)
        )

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp state_of(%{state: nil}), do: "passed"
  defp state_of(%{state: {s, _}}), do: s
  defp state_of(%{state: s}), do: s
end
