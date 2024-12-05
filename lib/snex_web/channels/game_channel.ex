defmodule SnakeGameWeb.GameChannel do
  use SnakeGameWeb, :channel
  require Logger
  alias SnakeGame.GameEngine

  # Join the game channel and initialize the game engine (but don't start yet)
  def join("game:" <> board_id, %{"player_id" => player_id}, socket) do
    GameEngine.start_link(board_id)
    GameEngine.add_player(board_id, player_id)

    # Subscribe to PubSub for game updates
    Phoenix.PubSub.subscribe(SnakeGame.PubSub, "game:#{board_id}")

    {:ok, %{"board_id" => board_id},
     assign(socket, :board_id, board_id) |> assign(:player_id, player_id)}
  end

  # Handle the start event which starts the game
  def handle_in("start", _params, socket) do
    board_id = socket.assigns.board_id
    # Now start the game when 'start' event is received
    GameEngine.start_game(board_id)

    # Send a broadcast that the game has started
    broadcast!(socket, "started", %{board_id: board_id})

    # Send the updated game state to the client
    # board_state = GameEngine.get_state(board_id)
    {:reply, {:ok, %{status: "started"}}, socket}
  end

  # Handle the start event which starts the game
  def handle_in("leave", _params, socket) do
    board_id = socket.assigns.board_id
    player_id = socket.assigns.player_id
    GameEngine.remove_player(board_id, player_id)

    # # Send a broadcast that the game has started
    # broadcast!(socket, "started", %{board_id: board_id})

    # Send the updated game state to the client
    # board_state = GameEngine.get_state(board_id)
    {:reply, {:ok, %{status: "started"}}, socket}
  end

  # Handle player moves
  def handle_in("move", %{"direction" => direction}, socket) do
    GameEngine.move_player(
      socket.assigns.board_id,
      socket.assigns.player_id,
      String.to_atom(direction)
    )

    {:noreply, socket}
  end

  # Handle the game ticks to update the game state
  def handle_info({:tick, board_state}, socket) do
    push(socket, "update", board_state)
    {:noreply, socket}
  end

  def handle_info({:update, state}, socket) do
    push(socket, "update", state)
    {:noreply, socket}
  end

  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end
end
