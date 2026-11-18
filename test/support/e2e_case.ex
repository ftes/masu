defmodule MasuE2E.Case do
  @moduledoc """
  The browser tests (test/e2e), a port of the Playwright suite in e2e/
  to ExUnit with playwright_ex: `mix test --only e2e`.

  Playwright Test's projects are `parameterize:` over `projects/0`, one
  for each engine with its desktop device, which picks the browser, and a
  `browser_name` parameter, Playwright Test's `browserName` fixture.
  E2E_BROWSERS picks some of them (comma-separated, for example "firefox"
  or "chromium,webkit"); the default is all three.
  """

  use ExUnit.CaseTemplate
  use Playwright.Test

  alias Playwright.{Browser, BrowserContext}
  alias Playwright.Test.BrowserPool

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

      name = String.to_atom(name)
      Map.put(Playwright.Test.parameters(Playwright.device(@devices[name])), :browser_name, name)
    end)
  end

  using opts do
    quote do
      use Playwright.Test, unquote(opts)

      import MasuE2E.Support

      alias Playwright.{
        Browser,
        BrowserContext,
        Download,
        Expect,
        Keyboard,
        Locator,
        Mouse,
        Page,
        Test
      }

      alias Playwright.{WebSocket, WebSocketRoute}

      @moduletag :e2e
    end
  end

  setup_all do
    %{browser: BrowserPool.browser()}
  end

  setup %{browser: browser} do
    context = Browser.new_context!(browser)
    %{context: context, page: BrowserContext.new_page!(context)}
  end
end
