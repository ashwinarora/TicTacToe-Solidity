**TicTacToe Ethereum**

This contract supports multiple games at a time and each player is supposed to deposit an escrow while creating a new game or while joining an already created game. The winner of each game gets the entire escrow. If any player abandons the game, the other player can claim the entire escrow.


**Here is the flow of the contract-**
  1. Any address creates a new game and returns the game ID. This address becomes player1
  2. A different address joins the game using the game ID. This address becomes player2. Incase player2 doesn’t join the game, player1 has the option to withdraw the ETH and close the game.
  3. After player2 has joined the game, player1 get the first turn and needs to make a move on the game matrix.
  4. After player1’s move, player2 can make a move and so on.
  5. After each move the contract checks if any player has won the game and if the matrix is full there is a tie.
  6. Incase there is a winner, the entire escrow is sent to the winner.
  7. Incase of a draw, both players are sent the refund of their respective escrow.
  8. If the players who is supposed to make the move is inactive for 5 minutes, then the other player can claim the entire escrow.


**Steps to run the contract on Remix IDE.**
  1. Open Remix IDE, select solidity and load the contract files (Tictactoe.sol and ownable.sol)
  2. From File explorer, go to Solidity Compiler and select the 0.4.25 compiler
  3. Go to ‘Deploy & run transactions’. Select environment as ‘JavaScript VM’. Select ‘Tictactoe’ as the contract. Hit ‘Deploy’. Pull up the console for verifying the progress.
  4. The contract is successfully deployed. In the Account drop down menu, select the 2nd address. In the Value field type 1 and select ‘ether’ from the dropdown menu.
  5. Now will we call the ‘newGame’ function. Here we are calling ‘newGame’ from the 2nd address in the list and sending 1 ether to the contract. The transaction is successful, hit the down arrow in the console to see the transaction details. Notice the decoded output is ‘1’. This is the game ID that is generated.
  6. We have successfully created a game. Now another address will join the game as an opponent. To do this select the second address from the list and type ‘1’ in the value field.
  7. Now the address which created the game is player1 and the address which joined the game is player2. We now make a move from player1’s account. The move is made to (1,1) which is the exact center of the matrix. Notice we get 2 outputs, the 1st is success is true, which means the function executed successfully. The 2nd output is the new matrix that is created after the move is made. The output matrix is ‘0,0,0,0,1,0,0,0,0’. Notice the ‘1’ exactly between the ‘0s’, this signifies that player1 has made a move at the exact center of the matrix.
  8. Now player2 will make a move to (0,0) i.e. the top left corner of the matrix. Again to do this _gameId=1, _x=0, _y=0.
  9. Now player1 will make a move to (1,0) i.e. the middle left of the matrix.
  10. Now player2 will make a move to (0,1) i.e. middle top of the matrix.
  11. Now player1 will make a move to (1,2) i.e. middle right of the matrix and win the game.
  12. Notice the player1’s account balance increase by 2 ether. He got his 1 ether back when he created the game and got 1 more ether from winning the game. Player2 didn’t get his 1 ether back as he lost the game.


**So what happens in case a player abandons the game?**

  The other player gets all the ether. Let’s see how-
  1. We create another game using the 4th address in the account list and send 1 ether to the contract. The game ID now is ‘2’.
  2. This game is joined by the 5th address in the account list and send 1 ether. ‘2’ is passed as the _gameId for joinGame function.
  3. Now 4th address is player1 and 5th address is player2. We now make a move from player1’s account. After this, player2 will abandon the game and NOT make any move.
  4. Since player2 has abandoned the game, player1 can claim the total reward using the claimReward() function after waiting for 5 minutes or more. Notice the time difference between screenshots.
  5. Notice the account balance, player1 successfully got all the ether in the bet.
  
  
**FAQs-**
  1. What if player2 never joins the game, will player1 just loose its money? => No, player1 can simply call the ‘claimRefund()’ function anytime before player2 joins to get his money back. claimRefund() function can only be called by player1 before player2 joins, else it will generate an error.
  2. Will player2 have to send same amount of ether as player1? => Yes, else the transaction will be reverted.
  3. What if someone tries to join a game that already has 2 players? => Transaction will be reverted.
  4. What if the loosing player tries to claim the reward? => You cannot call claimReward() if it is your turn to make a move. You can only claimReward() if it is not you turn and the other player has not made any move or is inactive for at least 5 Minutes.
  5. Can claimReward() be called after the game is ended? =>No, the games result will change from active to player1wins, player2win, draw or abandoned when the game ends. Games needs to be in active state to call claimReward().
  6. Can player1 make a move before player2 has even joined? =>No, the transaction will be reverted.
  7. Can players make move after game is ended? =>No, the transaction will be reverted.
  8. Can players make move to a matrix position which is already filled? =>No, the transaction will be reverted.


For any doubts and queries, feel free to mail at **ashwinarora48@gmail.com**
