pragma solidity ^0.4.25;

import "./ownable.sol";

/// @title A TicTicToe Game
/// @author Ashwin Arora
/// @notice This contracts allow multiple instances of game to run at the same time. Players can bet ETH and winner takes the pot. A player can claim reward incase the other player abandons the game. 
/// @dev All functions are tested and working successfully
contract Tictactoe is Ownable{

  enum Chance{none, player1, player2}
  enum Result{none, active, player1Wins, player2Wins, draw, abandoned}

  struct Game{
    address player1;
    address player2;
    uint player1Escrow;
    uint player2Escrow;
    Chance currentChance;
    Result result;
    Chance[3][3] matrix;
    uint timeStamp;
  }

  mapping(uint => Game) games;
  uint private numberOfGames;
  uint timeout = 300;

  
  event NewGameCreated(uint gameId, address creator, uint timeStamp);

  event PlayerJoinedGame(uint gameId, address joinee, uint timeStamp);

  event MoveMade(uint gameId, address player, uint8 xAxis, uint yAxis, uint timeStamp);

  event GameEnded(uint gameId, Result result, uint timeStamp);

  modifier hasValue() {
    require(msg.value > 0, "Ether required");
    _;
  }
  
  modifier gameExists(uint _gameId){
    require(_gameId <= numberOfGames, "Invalid Game Id, No such game exists");
    _;
  }

  modifier isCalledByPlayer(uint _gameId){
    require(msg.sender == games[_gameId].player1 || msg.sender==games[_gameId].player2, "Your address is invalid");
    _;
  }
  
  modifier isGameActive(uint _gameId){
      require(games[_gameId].result == Result.active, "Game is no longer Active");
      _;
  }
  
  /// @notice Allows players to create a new game
  /// @dev new game is generated and values are initialized
  /// @return the ID of the game is returned
  function newGame() external payable hasValue returns(uint){
    ++numberOfGames;
    uint gameId = numberOfGames;
    games[gameId].player1 = msg.sender;
    games[gameId].player1Escrow = msg.value;
    games[gameId].currentChance = Chance.player1;
    games[gameId].result = Result.active;
    games[gameId].timeStamp = now;
    emit NewGameCreated(gameId, msg.sender, games[gameId].timeStamp);
    return gameId;
  }

  /// @notice Allows playes to join game already created by someone else
  /// @dev All necessary checks are performed before allowing player to join
  /// @param _gameId ID of the game which is to be joined
  /// @return success True on successful execution. Else the transaction is reverted.
  function joinGame(uint _gameId) external payable hasValue gameExists(_gameId) isGameActive(_gameId) returns(bool success){
    //require(_gameId < numberOfGames, "Invalid Game Id, No such game exists");
    require(games[_gameId].player2 == address(0), "Invalid Game Id, Someone has already joined");
    require(msg.sender != games[_gameId].player1, "You cannot play against yourself");
    require(msg.value == games[_gameId].player1Escrow, "Invalid amount of Ether sent");

    Game storage game = games[_gameId];

    game.player2 = msg.sender;
    game.player2Escrow = msg.value;
    game.timeStamp = now;

    emit PlayerJoinedGame(_gameId, msg.sender, game.timeStamp);

    return true;
  }

  /// @notice Players can make the move on the matrix
  /// @dev All necessary checks performed. After each move, winning and draw condition is checked
  /// @Param _gameId ID of the game on which the move is performed
  /// @param _x X coordinate of the matrix
  /// @param _y Y coordinate of the matrix
  /// @return success True on successful execution. Else the transaction is reverted.
  /// @return newMatrix matrix created after the more is made
  function makeMove(uint _gameId, uint8 _x, uint8 _y) external gameExists(_gameId) isCalledByPlayer(_gameId) isGameActive(_gameId) returns(bool success, Chance[3][3] newMatrix) {
    require(games[_gameId].player2 != address(0), "Player 2 has not joined yet");
    require(msg.sender == getCurrentPlayer(_gameId), "It is not your turn");
    require(games[_gameId].matrix[_x][_y] == Chance.none, "Invalid move, position already filled");

    Game storage game = games[_gameId];
    game.matrix[_x][_y] = game.currentChance;
    
    Chance winner = checkWinner(game.matrix);
    if(winner == Chance.none && isMatrixFull(game.matrix)){
        game.result = Result.draw;
        game.currentChance = Chance.none;
        //functionality to refund the escrow of the players
        game.player1.transfer(game.player1Escrow);
        game.player2.transfer(game.player2Escrow);
        game.timeStamp = now;
        emit GameEnded(_gameId, game.result, game.timeStamp);
    }else if(winner != Chance.none){

        if(winner == Chance.player1){
            game.result = Result.player1Wins;
            game.player1.transfer(game.player1Escrow + game.player2Escrow);
        }else if(winner == Chance.player2){
            game.result = Result.player2Wins;
            game.player2.transfer(game.player1Escrow + game.player2Escrow);
        }else{
            revert("Unexpected Error");
        }
        
        game.currentChance = Chance.none;
        game.timeStamp = now;
        emit GameEnded(_gameId, game.result, game.timeStamp);
    }else{
        game.currentChance = nextPlayer(game.currentChance);
        game.timeStamp = now;
        emit MoveMade(_gameId, msg.sender, _x, _y, game.timeStamp);
    }
    return (true, game.matrix);
  }

  /// @notice Used to claim all the escrow incase the opponent abandons the game
  /// @dev Can only be claimed after 5 minutes of inactivity. Cannot be claimed by the player who's turn it is.
  /// @Param _gameId ID of the game
  /// @return success True on succesful execution
  function claimReward(uint _gameId) external gameExists(_gameId) isCalledByPlayer(_gameId) isGameActive(_gameId) returns (bool success){
      require(msg.sender != getCurrentPlayer(_gameId), "Cannot claim reward when it is your chance. Please make a move");
      require(now - games[_gameId].timeStamp >= timeout, "Cannot claim reward before 5 minutes of inacticity");
      
      Game storage game = games[_gameId];
      msg.sender.transfer(game.player1Escrow + game.player2Escrow);
      game.result = Result.abandoned;
      game.timeStamp = now;
      emit GameEnded(_gameId, game.result, game.timeStamp);
      return true;
  }

  /// @notice Used claim refund incase player 2 dosn't join the game
  /// @dev Can only be claimed by player 1 before the player 2 has joined
  /// @Param _gameId ID of the game
  /// @return success True on successful execution
  function claimRefund(uint _gameId) external gameExists(_gameId) isCalledByPlayer(_gameId) isGameActive(_gameId) returns(bool success){
      require(games[_gameId].player2 == address(0), "Cannot claim refund, Player 2 has joined. Please make a move");
      
      Game storage game = games[_gameId];
      msg.sender.transfer(game.player1Escrow);
      game.result = Result.abandoned;
      game.timeStamp = now;
      emit GameEnded(_gameId, game.result, game.timeStamp);
      return true;
  }

  /// @dev get the current player address based on currentChance varible
  /// @Param _gameId Id of the game
  /// @return address of the current player
  function getCurrentPlayer(uint _gameId) private view returns(address){
    if(games[_gameId].currentChance == Chance.player1){
      return games[_gameId].player1;
    }else if(games[_gameId].currentChance == Chance.player2){
      return games[_gameId].player2;
    }else{
      revert("Unexpected Error");
    }
  }

  
  /// @dev get the Chance type of the next player
  /// @Param _currentchance players who's chance it is currently
  /// @return Chance of the next player
  function nextPlayer(Chance _currentchance) private pure returns(Chance){
    if(_currentchance == Chance.player1){
        return Chance.player2;
    }else if(_currentchance == Chance.player2){
        return Chance.player1;
    }else{
        revert("Unexpected Error");
    }
  }

  /// @dev Check if there is any winner yet. First checks the rows, then columns, then diagnols.
  /// @Param _matrix the games matrix which is to be checked
  /// @return the chances type of the winner, can be 'none'
  function checkWinner(Chance[3][3] memory _matrix) private pure returns (Chance) {
    Chance winner = checkRows(_matrix);
    if(winner != Chance.none){
      return winner;
    }

    winner = checkColumns(_matrix);
    if(winner != Chance.none){
      return winner;
    }

    winner = checkDiagnols(_matrix);
    if(winner != Chance.none){
      return winner;
    }
    return Chance.none;
  }

  /// @dev Checks each row for winners
  /// @Param _matrix the games matrix which is to checked
  /// @return the chance type of the winner, can be 'none'
  function checkRows(Chance[3][3] memory _matrix)private pure returns (Chance){
    for(uint8 x=0 ; x<3 ;x++){
      if(_matrix[x][0]!=Chance.none && _matrix[x][0]==_matrix[x][1] && _matrix[x][1]==_matrix[x][2]){
        return _matrix[x][0];
      }
    }
    return Chance.none;
  }
  
  /// @dev Checks each column for winners
  /// @Param _matrix the games matrix which is to checked
  /// @return the chance type of the winner, can be 'none'
  function checkColumns(Chance[3][3] memory _matrix)private pure returns (Chance){
    for(uint8 x=0 ; x<3 ;x++){
      if(_matrix[0][x]!=Chance.none && _matrix[0][x]==_matrix[1][x] && _matrix[1][x]==_matrix[2][x]){
        return _matrix[0][x];
      }
    }
    return Chance.none;
  }

  /// @dev Checks each diagnol for winners
  /// @Param _matrix the games matrix which is to checked
  /// @return the chance type of the winner, can be 'none'
  function checkDiagnols(Chance[3][3] memory _matrix)private pure returns (Chance){
    if(_matrix[0][0]!=Chance.none && _matrix[0][0]==_matrix[1][1] && _matrix[1][1]==_matrix[2][2]){
      return _matrix[1][1];
    }
    if(_matrix[0][2]!=Chance.none && _matrix[0][2]==_matrix[1][1] && _matrix[1][1]==_matrix[2][0]){
      return _matrix[1][1];
    }
    return Chance.none;
  }

  /// @dev checks if the matrix is full for draw condition
  /// @Param _matrix the game matrix which is to be checked
  /// @return True if the _matrix is full. False if _matrix is not full
  function isMatrixFull(Chance[3][3] memory _matrix)private pure returns (bool) {
    for (uint8 x = 0; x < 3; x++) {
      for (uint8 y = 0; y < 3; y++) {
        if (_matrix[x][y] == Chance.none) {
          return false;
        }
      }
    }
    return true;
  }
  
  /// @notice gets the number of games that have been created
  function getNumberOfGames() external view returns(uint){
    return numberOfGames;
  }
  
}
