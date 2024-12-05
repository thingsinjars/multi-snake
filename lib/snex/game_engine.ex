defmodule SnakeGame.GameEngine do
  use GenServer
  require Logger

  defstruct size: [20, 20], players: %{}, dot: nil, status: :waiting

  # Client API
  def start_link(board_id) do
    GenServer.start_link(__MODULE__, %{board_id: board_id, players: %{}, dot: nil, size: [20, 20], status: :waiting}, name: via_tuple(board_id))
  end

  def add_player(board_id, player_id) do
    GenServer.call(via_tuple(board_id), {:add_player, player_id})
  end

  def start_game(board_id) do
    GenServer.cast(via_tuple(board_id), :start_game)
  end

  def move_player(board_id, player_id, direction) do
    GenServer.cast(via_tuple(board_id), {:move_player, player_id, direction})
  end

  def get_state(board_id) do
    GenServer.call(via_tuple(board_id), :get_state)
  end

  def remove_player(board_id, player_id) do
    GenServer.cast(via_tuple(board_id), {:remove_player, player_id})
  end

  # Server API
  @impl true
  def init(state) do
    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_call({:add_player, player_id}, _from, state) do
    [x, y] = random_position(state.size)
    colors = [:red, :blue, :green, :yellow, :purple, :orange]
    color = Enum.at(colors, map_size(state.players), :black)

    new_player = %{direction: :up, color: color, length: 1, body: [[x, y]]}

    updated_players = Map.put(state.players, player_id, new_player)

    updated_state = %{state | players: updated_players}

    Phoenix.PubSub.broadcast!(
      SnakeGame.PubSub,
      "game:#{state.board_id}",
      {:update, updated_state}
    )
    {:reply, :ok, updated_state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast(:start_game, state) do
    dot = random_position(state.size)
    {:noreply, %{state | status: :started, dot: dot}}
  end

  @impl true
  def handle_cast({:move_player, player_id, direction}, state) do
    # Protect against updating a non-existent player
    updated_players = Map.update!(state.players, player_id, fn player -> %{player | direction: direction} end)
    {:noreply, %{state | players: updated_players}}
  end

  @impl true
  def handle_cast({:remove_player, player_id}, state) do
    updated_players = Map.delete(state.players, player_id)
    updated_state = %{state | players: updated_players}

    # Broadcast updated state
    Phoenix.PubSub.broadcast!(
      SnakeGame.PubSub,
      "game:#{state.board_id}",
      {:update, updated_state}
    )

    {:noreply, updated_state}
  end

  def update_and_send(state) do
      updated_state = update_game_state(state)
      Phoenix.PubSub.broadcast!(SnakeGame.PubSub, "game:#{state.board_id}", {:tick, updated_state})
      updated_state
  end

  @impl true
  def handle_info(:tick, state) do
    if state.status == :started do
      updated_state = update_and_send(state)
      schedule_tick()
      {:noreply, updated_state}
    else
      schedule_tick()
      {:noreply, state}
    end
  end

  # Game logic
  defp update_game_state(state) do
    updated_state =
      Enum.reduce(Map.keys(state.players), %{players: state.players, dot: state.dot}, fn player_id, acc ->
        move_player_and_check_dot(player_id, %{players: acc.players, dot: acc.dot, size: state.size})
      end)

    # Regenerate dot if consumed
    new_dot =
      if updated_state.dot == nil do
        random_position(state.size)
      else
        updated_state.dot
      end

    %{state | players: updated_state.players, dot: new_dot}
  end

  defp move_player_and_check_dot(player_id, %{players: players, dot: dot, size: [max_x, max_y]}) do
    player = Map.fetch!(players, player_id)
    [x, y] = hd(player.body)

    # Calculate the new head position
    new_head =
      case player.direction do
        :up -> [x, rem(y - 1 + max_y, max_y)]
        :down -> [x, rem(y + 1, max_y)]
        :left -> [rem(x - 1 + max_x, max_x), y]
        :right -> [rem(x + 1, max_x), y]
      end

    # Check collision (with self or other players)
    collision =
      Enum.any?(players, fn {_id, other_player} ->
        Enum.member?(other_player.body, new_head)
      end)

    cond do
      collision ->
        # Shorten the snake if a collision occurs
        new_body = Enum.slice(player.body, 0, player.length - 1)

        # Remove player if their body is fully consumed
        updated_players =
          if Enum.empty?(new_body) do
            Map.delete(players, player_id)
          else
            Map.put(players, player_id, %{player | body: new_body, length: player.length - 1})
          end

        %{players: updated_players, dot: dot}

      new_head == dot ->
        # Consume dot: grow the snake and increase length
        updated_players =
          Map.put(players, player_id, %{
            player
            | body: [new_head | player.body],
              length: player.length + 1
          })

        %{players: updated_players, dot: nil} # Dot will be regenerated

      true ->
        # Normal movement: shift the snake body
        new_body = [new_head | Enum.slice(player.body, 0, player.length - 1)]

        updated_players =
          Map.put(players, player_id, %{player | body: new_body})

        %{players: updated_players, dot: dot}
    end
  end


  defp random_position([cols, rows]) do
    [Enum.random(0..(cols - 1)), Enum.random(0..(rows - 1))]
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, 100) # Tick every 100ms
  end

  defp via_tuple(board_id), do: {:via, Registry, {SnakeGame.GameRegistry, board_id}}
end
