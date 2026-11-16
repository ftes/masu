defmodule MasuE2E.Case do
  @moduledoc """
  The browser tests (test/e2e), a port of the Playwright suite in e2e/
  to ExUnit with playwright_ex: `mix test --only e2e`.

  Playwright Test's projects are `parameterize:` over `projects/0`, one
  for each engine with its desktop device. E2E_BROWSERS picks some of
  them (comma-separated, for example "firefox" or "chromium,webkit"); the
  default is all three. A `@tag use: [...]` (or `@describetag`) is
  Playwright Test's `test.use({...})`: context options over the device's.
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

      %{browser_name: String.to_atom(name)}
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

  setup_all %{browser_name: name} do
    browser = BrowserPool.browser(browser_name: name)
    device = Map.fetch!(Playwright.devices(BrowserPool.playwright(browser)), @devices[name])
    %{browser: browser, device: Map.delete(device, :default_browser_type)}
  end

  setup %{browser: browser, device: device} = ctx do
    context = Browser.new_context!(browser, Map.merge(device, Map.new(ctx[:use] || [])))
    %{context: context, page: BrowserContext.new_page!(context)}
  end
end
