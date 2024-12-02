defmodule SnakeGame.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the Phoenix PubSub system
      {Phoenix.PubSub, name: SnakeGame.PubSub},
      SnakeGameWeb.Endpoint,
      {Registry, keys: :unique, name: SnakeGame.GameRegistry}
    ]

    opts = [strategy: :one_for_one, name: SnakeGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
