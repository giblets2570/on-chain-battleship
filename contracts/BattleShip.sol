pragma solidity ^0.4.2;

contract BattleShip {

    enum GameState { Created, SettingUp, Playing, Finished }

    struct Game {
        address player1;
        address player2;
        address currentPlayer;
        address winner;
        GameState gameState;
        uint pot;
        uint availablePot;
        mapping(address => int8[10][10]) playerGrids;
        mapping(address => bool[4]) playerShips;
    }

    mapping(bytes32 => Game) public games;
    mapping(address => bytes32[]) playerGames;

    uint8 maxBoatLength;
    uint8 minBoatLength;

    event GameInitialized(bytes32 gameId, address player1, bool player1GoesFirst);

    event HitBattleShip(address currentPlayer, uint8 x, uint8 y, int8 pieceHit);
    event WonChallenged(address player);
    event GameEnded(address winner);

    event IsStateCalled(GameState currentState, GameState comparingState, bool equal);
    event LogCurrentState(GameState state);

    modifier isPlayer(bytes32 gameId) {
        if(msg.sender == games[gameId].player1 || msg.sender == games[gameId].player2) _;
    }

    modifier isCurrentPlayer(bytes32 gameId) {
        if(msg.sender == games[gameId].currentPlayer) _;
    }

    modifier isWinner(bytes32 gameId) {
        if(msg.sender == games[gameId].currentPlayer) _;
    }

    modifier isState(bytes32 gameId, GameState state){
        if(state == games[gameId].gameState) _;
    }

    function abs(int number) internal constant returns(uint unumber) {
        if(number < 0) return uint(-1 * number);
        return uint(number);
    }

    function initialiseBoard(bytes32 gameId, address player) isState(gameId, GameState.Created) internal {
        for(uint8 i = 0; i < 10; i++) {
            for(uint8 j = 0; j < 10; j++) {
                games[gameId].playerGrids[player][i][j] = 0;
            }
        }
    }

    function findOtherPlayer(bytes32 gameId,address player) internal constant returns(address) {
        if(player == games[gameId].player1) return games[gameId].player2;
        return games[gameId].player1;
    }

    function BattleShip() {
        maxBoatLength = 5;
        minBoatLength = 2;
    }

    function findPot(bytes32 gameId) constant returns(uint){
        return games[gameId].pot;
    }

    function newGame(bool goFirst) payable returns(bytes32){
        // Generate game id based on player's addresses and current block number
        bytes32 gameId = sha3(msg.sender, block.number);
        playerGames[msg.sender].push(gameId);
        games[gameId] = Game(
            msg.sender, // address player1;
            address(0), // address player2;
            address(0), // address currentPlayer;
            address(0), // address winner;
            GameState.Created, // GameState gameState;
            msg.value * 2, // uint pot;
            msg.value * 2 // uint availablePot;
        );
        if(goFirst){
            games[gameId].currentPlayer = msg.sender;
        }
        GameInitialized(gameId,msg.sender,goFirst);
        initialiseBoard(gameId,msg.sender);
        return gameId;
    }

    function joinGame(bytes32 gameId) isState(gameId, GameState.Created) payable {
        require(games[gameId].player2 == address(0));
        require(msg.value == games[gameId].pot / 2);
        games[gameId].player2 = msg.sender;
        playerGames[msg.sender].push(gameId);
        if(games[gameId].currentPlayer == address(0)){
            games[gameId].currentPlayer = msg.sender;
        }
        initialiseBoard(gameId,msg.sender);
        games[gameId].gameState = GameState.SettingUp;
    }


    function showBoard(bytes32 gameId) isPlayer(gameId) constant returns(int8[10][10] board) {
        return games[gameId].playerGrids[msg.sender];
    }
    
    function placeShip(bytes32 gameId, uint8 startX, uint8 endX, uint8 startY, uint8 endY) isPlayer(gameId) isState(gameId,GameState.SettingUp) {
        require(startX == endX || startY == endY);
        require(startX < endX || startY < endY);
        require(startX  < 10 && startX  >= 0 &&
                endX    < 10 && endX    >= 0 &&
                startY  < 10 && startY  >= 0 &&
                endY    < 10 && endY    >= 0);
        uint8 boatLength;
        if(startX == endX) {
            boatLength = uint8(abs(int(startY) - int(endY)));
        }else if(startY == endY) {
            boatLength = uint8(abs(int(startX) - int(endX)));
        }
        require(boatLength <= maxBoatLength && boatLength >= minBoatLength);
        require(!(games[gameId].playerShips[msg.sender][boatLength - minBoatLength]));

        games[gameId].playerShips[msg.sender][boatLength - minBoatLength] = true;

        uint8 placements = 0;
        for(uint8 x = startX; x <= endX; x++) {
            for(uint8 y = startY; y <= endY; y++) {
                games[gameId].playerGrids[msg.sender][x][y] = int8(boatLength);
                placements += 1;
                if(placements == boatLength) return;
            }   
        }
    }

    function finishPlacing(bytes32 gameId) isPlayer(gameId) isState(gameId,GameState.SettingUp) {
        bool ready = true;
        for(uint8 i = 0; i <= maxBoatLength - minBoatLength; i++) {
            if(!games[gameId].playerShips[games[gameId].player1][i] 
                || !games[gameId].playerShips[games[gameId].player2][i]) {
                ready = false;
                break;
            }
        }
        require(ready);
        games[gameId].gameState = GameState.Playing;
    }

    function makeMove(bytes32 gameId, uint8 x, uint8 y) isState(gameId,GameState.Playing) isCurrentPlayer(gameId) {
        address otherPlayer = findOtherPlayer(gameId,msg.sender);
        require(games[gameId].playerGrids[otherPlayer][x][y] >= 0);
        if(games[gameId].playerGrids[otherPlayer][x][y] > 0) {
            HitBattleShip(msg.sender,x,y,games[gameId].playerGrids[otherPlayer][x][y]);
            games[gameId].playerGrids[otherPlayer][x][y] = -1 * games[gameId].playerGrids[otherPlayer][x][y];
        }
        games[gameId].currentPlayer = otherPlayer;
    }

    function sayWon(bytes32 gameId) isPlayer(gameId) isState(gameId,GameState.Playing) {
        WonChallenged(msg.sender);
        address otherPlayer = findOtherPlayer(gameId,msg.sender);
        uint8 requiredToWin = 0;
        for(uint8 i = minBoatLength; i <= maxBoatLength; i++){
            requiredToWin += i;
        }
        int8[10][10] otherPlayerGrid = games[gameId].playerGrids[otherPlayer];
        uint8 numberHit = 0;
        for(i = 0;  i < 10; i++) {
            for(uint j = 0;  j < 10; j++) {
                if(otherPlayerGrid[i][j] < 0){
                    numberHit += 1;
                }
            }    
        }
        if(numberHit >= requiredToWin){
            games[gameId].gameState = GameState.Finished;
            games[gameId].winner = msg.sender;
            GameEnded(msg.sender);
        }
    }

    function withdraw(bytes32 gameId) isState(gameId,GameState.Finished) isWinner(gameId) {
        uint amount = games[gameId].availablePot;
        games[gameId].availablePot = 0;
        msg.sender.transfer(amount);
    }
}