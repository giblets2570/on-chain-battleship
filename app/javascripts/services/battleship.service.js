// Import libraries we need.
import { default as Web3} from 'web3';
import { default as contract } from 'truffle-contract';

// Import our contract artifacts and turn them into usable abstractions.
import battleshipDef from '../../../build/contracts/Battleship.json'

// Battleship is our usable abstraction, which we'll use through the code below.
var Battleship = contract(battleshipDef);

// any web3 provider
var provider = new Web3.providers.HttpProvider("http://localhost:8545");

// give it web3 powers!
Battleship.setProvider(provider);

class BattleshipService {

	constructor($q,$timeout) {
		this.$timeout = $timeout

		this.loaded = $q.defer();

		this.data = {
			games: []
		};

		web3.eth.getAccounts((err,accs) => {
			if (err != null) {
				alert("There was an error fetching your accounts.");
				return;
			}

			if (accs.length == 0) {
				alert("Couldn't get any accounts! Make sure your Ethereum client is configured correctly.");
				return;
			}

			this.accounts = accs;
			this.account = this.accounts[0];
			angular.extend(this.data,{account: this.account});
			this.loaded.resolve();
			this.setUpWatch();
		});
	}
	
	async transaction(method,args=[],vars={}) {
		await this.loaded;
		let instance = await Battleship.deployed();
		angular.extend(vars,{from: this.account, gas: 2000000});
		console.log(method, args, vars);
		return await instance[method](...args,vars);
	}

	async call(attribute) {
		await this.loaded;
		let instance = await Battleship.deployed();
		console.log(attribute);
		return await instance[attribute].call();
	}

	async setUpWatch() {
		await this.loaded;
		
		let instance = await Battleship.deployed();
		instance
		.GameInitialized({},{fromBlock: 0, toBlock: 'pending'})
		.watch(async (err, result) => {
			let game = await instance.games.call(result.args.gameId);
			game = this.structToObject(game);
			game.id = result.args.gameId;
			this.$timeout(() => this.data.games.push(game));
		});
		instance
		.GameJoined({},{fromBlock: 0, toBlock: 'pending'})
		.watch(async (err, result) => {
			let game = await instance.games.call(result.args.gameId);
			game = this.structToObject(game);
			game.id = result.args.gameId;
			this.data.games = this.data.games.filter((_game) => _game.id != game.id);
			this.$timeout(() => this.data.games.push(game));
		});
	}

	structToObject(game){
		let result = [
			"player1",
			"player2",
			"currentPlayer",
			"winner",
			"gameState",
			"pot",
			"availablePot"
		].reduce((c,key,index) => {
			c[key] = game[index];
			return c;
		},{});
		return result;
	}
}

BattleshipService.$inject = ['$q','$timeout'];

export default BattleshipService;