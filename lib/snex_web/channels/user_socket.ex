defmodule SnakeGameWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "game:*", SnakeGameWeb.GameChannel

  # Connect function to authenticate users if necessary
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  # Identify socket by ID (optional, can be used for disconnecting specific users)
  def id(_socket), do: nil
end
