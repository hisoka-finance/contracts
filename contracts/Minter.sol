// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";

import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IRewardsDistributor.sol";
import "contracts/interfaces/IHisoka.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter {
    uint internal constant WEEK = 86400 * 7; // allows minting once per week
    uint public EMISSION = 990;
    uint internal constant MAX_EMISSION = 1980;
    uint internal constant MIN_EMISSION = 0; // 0
    uint internal constant TAIL_EMISSION = 2;
    uint internal constant PRECISION = 1000;
    IHisoka public immutable _hsk;
    IVoter public immutable _voter;
    IVotingEscrow public immutable _ve;
    IRewardsDistributor public immutable _rewards_distributor;
    uint public weekly = 68_000 * 1e18; // represents a starting weekly emission of 68k HSK (HSK has 18 decimals)
    uint public active_period;

    address internal initializer;
    address public team;
    address public pendingTeam;
    uint public teamRate;
    uint public constant MAX_TEAM_RATE = 100; // 10% max

    event Mint(
        address indexed sender,
        uint weekly,
        uint circulating_supply,
        uint circulating_emission
    );
    event EmissionSet(address indexed setter, uint256 emission);

    struct Claim {
        address claimant;
        uint256 amount;
        uint256 lockTime;
    }

    constructor(
        address __voter, // the voting & distribution system
        address __ve, // the ve(3,3) system that will be locked into
        address __rewards_distributor // the distribution system that ensures users aren't diluted
    ) {
        initializer = msg.sender;
        team = msg.sender;
        teamRate = 30; // 30 bps = 3%
        _hsk = IHisoka(IVotingEscrow(__ve).token());
        _voter = IVoter(__voter);
        _ve = IVotingEscrow(__ve);
        _rewards_distributor = IRewardsDistributor(__rewards_distributor);
        active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
    }

    function initialMintAndLock(
        Claim[] calldata claims,
        uint max // sum amounts / max = % ownership of top protocols, so if initial 20m is distributed, and target is 25% protocol ownership, then max - 4 x 20m = 80m
    ) external {
        require(initializer == msg.sender, "not initializer");
        _hsk.mint(address(this), max);
        _hsk.approve(address(_ve), max);
        uint256 length = claims.length;
        for (uint i = 0; i < length; ) {
            _ve.create_lock_for(
                claims[i].amount,
                claims[i].lockTime,
                claims[i].claimant
            );
            unchecked {
                ++i;
            }
        }
    }

    function startActivePeriod() external {
        require(initializer == msg.sender, "not initializer");
        initializer = address(0);
        // allow minter.update_period() to mint new emissions THIS Thursday
        active_period = ((block.timestamp) / WEEK) * WEEK;
    }

    function setTeam(address _team) external {
        require(msg.sender == team, "not team");
        pendingTeam = _team;
    }

    function acceptTeam() external {
        require(msg.sender == pendingTeam, "not pending team");
        team = pendingTeam;
    }

    function setTeamRate(uint _teamRate) external {
        require(msg.sender == team, "not team");
        require(_teamRate <= MAX_TEAM_RATE, "rate too high");
        teamRate = _teamRate;
    }

    function setEmission(uint _emission) external {
        require(msg.sender == team, "not team");
        require(
            _emission <= MAX_EMISSION && _emission >= MIN_EMISSION,
            "emission out of range"
        );
        EMISSION = _emission;

        emit EmissionSet(msg.sender, _emission);
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return _hsk.totalSupply() - _ve.totalSupply();
    }

    // emission calculation is 1% of available supply to mint adjusted by circulating / total supply
    function calculate_emission() public view returns (uint) {
        return (weekly * EMISSION) / PRECISION;
    }

    // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
    function weekly_emission() public view returns (uint) {
        return Math.max(calculate_emission(), circulating_emission());
    }

    // calculates tail end (infinity) emissions as 0.2% of total supply
    function circulating_emission() public view returns (uint) {
        return (circulating_supply() * TAIL_EMISSION) / PRECISION;
    }

    // calculate inflation and adjust ve balances accordingly
    function calculate_growth(uint _minted) public view returns (uint) {
        uint _veTotal = _ve.totalSupply();
        uint _hskTotal = _hsk.totalSupply();
        return
            (((((_minted * _veTotal) / _hskTotal) * _veTotal) / _hskTotal) *
                _veTotal) /
            _hskTotal /
            2;
    }

    // update period can only be called once per cycle (1 week)
    function update_period() external returns (uint) {
        uint _period = active_period;
        if (block.timestamp >= _period + WEEK && initializer == address(0)) {
            // only trigger if new week
            _period = (block.timestamp / WEEK) * WEEK;
            active_period = _period;
            weekly = weekly_emission();

            uint _growth = calculate_growth(weekly);
            uint _teamEmissions = (teamRate * (_growth + weekly)) /
                (PRECISION - teamRate);
            uint _required = _growth + weekly + _teamEmissions;
            uint _balanceOf = _hsk.balanceOf(address(this));
            if (_balanceOf < _required) {
                _hsk.mint(address(this), _required - _balanceOf);
            }

            require(_hsk.transfer(team, _teamEmissions));
            require(_hsk.transfer(address(_rewards_distributor), _growth));
            _rewards_distributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
            _rewards_distributor.checkpoint_total_supply(); // checkpoint supply

            _hsk.approve(address(_voter), weekly);
            _voter.notifyRewardAmount(weekly);

            emit Mint(
                msg.sender,
                weekly,
                circulating_supply(),
                circulating_emission()
            );
        }
        return _period;
    }
}
