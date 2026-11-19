defmodule MasuE2E.Case do
  @moduledoc """
  The browser tests (test/e2e), with playwright_ex: `mix test --only e2e`.

  Each module is `parameterize:`d over `projects/0`, one project for each
  engine with its desktop device, which picks the browser. E2E_BROWSERS
  picks some of them (comma-separated, for example "firefox" or
  "chromium,webkit"); the default is all three. `Playwright.Case` gives
  each test a `context` and `page`, and the `browser_name`.
  """

  use ExUnit.CaseTemplate

  @devices %{chromium: "Desktop Chrome", firefox: "Desktop Firefox", webkit: "Desktop Safari"}

  @doc "The projects of the run, as `parameterize:` takes them."
  def projects do
    "E2E_BROWSERS"
    |> System.get_env("chromium,firefox,webkit")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn name ->
      if name not in ~w(chromium firefox webkit) do
        raise ~s(E2E_BROWSERS: unknown browser "#{name}", use chromium, firefox or webkit)
      end

      Playwright.Test.parameters(Playwright.device(@devices[String.to_atom(name)]))
    end)
  end

  using opts do
    quote do
      use Playwright.Case, unquote(opts)

      import MasuE2E.Support

      alias Playwright.{Download, WebSocket, WebSocketRoute}

      @moduletag :e2e
    end
  end
end
