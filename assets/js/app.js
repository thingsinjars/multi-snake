// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

////////

const boardId =
  window.location.hash.substring(1) ||
  `board-${Math.random().toString(36).substr(2, 8)}`;
const playerId = `player-${Math.floor(Math.random() * 10000)}`;

let socket = new Socket("/socket", { params: { player_id: playerId } });
socket.connect();
console.log(`Connecting to game:${boardId}`);

let channel = socket.channel(`game:${boardId}`, { player_id: playerId });
let gameBoard = document.getElementById("game");
let isEliminated = false;

// Add the start button and player count to the DOM
const startContainer = document.createElement("div");
startContainer.id = "start-container";

const startButton = document.createElement("button");
startButton.id = "start-button";
startButton.textContent = "Start";

const playerCount = document.createElement("div");
playerCount.id = "player-count";
playerCount.textContent = "Waiting for players...";

startContainer.appendChild(startButton);
startContainer.appendChild(playerCount);
document.body.appendChild(startContainer);

// Handle 'start' button click
startButton.addEventListener("click", () => {
  channel.push("start");
  startContainer.style.display = "none"; // Hide the start button
});

window.addEventListener("beforeunload", () => {
  channel.push("leave");
});

channel
  .join()
  .receive("ok", (resp) => {
    console.log("Joined game:", resp);
    window.location.hash = resp.board_id;
    renderBoard();
  })
  .receive("error", (resp) => {
    console.error("Unable to join:", resp);
  });

channel.on("update", (state) => {
  const count = Object.keys(state.players).length;
  playerCount.textContent = `Players: ${count}`;
  const player = state.players[playerId];
  if (!player && !isEliminated) {
    isEliminated = true; // Mark the player as eliminated
    showEliminationMessage();
  } else {
    renderBoard(state);
  }
});

channel.on("started", (state) => {
  startContainer.style.display = "none";
});

function showEliminationMessage() {
  const eliminationMessage = document.createElement("div");
  eliminationMessage.textContent = "You have been eliminated!";
  eliminationMessage.id = "elimination-message";
  document.body.appendChild(eliminationMessage);
}

// Handle player movement
document.addEventListener("keydown", (event) => {
  if (isEliminated) return;
  const direction = {
    ArrowUp: "up",
    ArrowDown: "down",
    ArrowLeft: "left",
    ArrowRight: "right",
  }[event.key];
  if (direction) channel.push("move", { direction });
});

// Render game board
function renderBoard(state) {
  if (!state || !state.players || !state.dot || !state.size) {
    console.log("Game not started yet");
    return;
  }
  const { players, dot, size } = state;
  const [cols, rows] = size;

  gameBoard.style.gridTemplateColumns = `repeat(${cols}, 1fr)`;
  gameBoard.style.gridTemplateRows = `repeat(${rows}, 1fr)`;

  // Clear the board
  gameBoard.innerHTML = "";

  // Render the cells
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      const cell = document.createElement("div");
      cell.classList.add("cell");

      // Check for player positions
      Object.values(players).forEach((player) => {
        player.body.forEach(([bx, by]) => {
          if (bx === x && by === y) {
            cell.classList.add("snake");
            cell.classList.add(`color-${player.color}`);
            // cell.style.backgroundColor = player.color;
          }
        });
      });

      // Check for dots
      if (dot[0] === x && dot[1] === y) {
        cell.classList.add("dot");
      }

      gameBoard.appendChild(cell);
    }
  }
}
