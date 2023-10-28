// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SystemeDeVote is Ownable(msg.sender) {
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    WorkflowStatus private status;
    mapping(address => Voter) private voters;
    Proposal[] private proposals;
    uint256 private winningProposalId;
    string public regles;
    string public dernierMessage;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    modifier onlyDuringStatus(WorkflowStatus _status) {
        require(status == _status, "Operation non autorisee a l'etat actuel du vote");
        _;
    }

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
        winningProposalId = 0;
    }

    function reinitialiser() public onlyOwner {
        status = WorkflowStatus.RegisteringVoters;
        for(uint i=0; i<proposals.length;i++){
            proposals[i] = proposals[proposals.length - 1];
            proposals.pop();
        }
        winningProposalId = 0;
    }

    function inscrireElecteur(address _electeur) public onlyOwner {
        require(status == WorkflowStatus.RegisteringVoters, "Impossible d'inscrire des electeurs a l'etat actuel du vote");
        require(!voters[_electeur].isRegistered, "L'electeur est deja inscrit");
        
        voters[_electeur].isRegistered = true;
        emit VoterRegistered(_electeur);
    }

    function ecrireRegles(string memory _regles) public onlyOwner {
        regles = _regles;
    }

    function ecrireMessage(string memory _message) public {
        dernierMessage = _message;
    }

    function demarrerSessionProposition() public onlyOwner {
        require(status == WorkflowStatus.RegisteringVoters, "Impossible de demarrer la session d'enregistrement a l'etat actuel du vote");
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function soumettreProposition(string memory _description) public onlyDuringStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        require(voters[msg.sender].isRegistered, "Vous n'etes pas autorise a soumettre une proposition");
        
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    function cloturerSessionProposition() public onlyOwner {
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "Impossible de terminer la session d'enregistrement a l'etat actuel du vote");
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function demarrerSessionVote() public onlyOwner {
        require(status == WorkflowStatus.ProposalsRegistrationEnded, "Impossible de demarrer la session de vote a l'etat actuel du vote");
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function voter(uint256 _proposalId) public onlyDuringStatus(WorkflowStatus.VotingSessionStarted) {
        require(status == WorkflowStatus.VotingSessionStarted, "Impossible de voter a l'etat actuel du vote");
        require(voters[msg.sender].isRegistered, "Vous n'etes pas autorise a voter");
        require(!voters[msg.sender].hasVoted, "Vous avez deja vote");
        require(_proposalId < proposals.length, "Indice de proposition invalide");
        
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function cloturerSessionVote() public onlyOwner {
        require(status == WorkflowStatus.VotingSessionStarted, "Impossible de terminer la session de vote a l'etat actuel du vote");
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function comptabiliserVotes() public onlyOwner {
        require(status == WorkflowStatus.VotingSessionEnded, "Impossible de comptabiliser les votes a l'etat actuel du vote");
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);

        uint256 winningVoteCount = 0;
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;
            }
        }
    }

    function obtenirGagnant() public view returns (string memory)
    {
        require(status == WorkflowStatus.VotesTallied, "Les votes n'ont pas encore ete comptabilises");

        Proposal storage winningProposal = proposals[winningProposalId];
        return string(abi.encodePacked(winningProposalId, winningProposal.description));
    }

    function voirPropositions() public view returns (string[] memory) {
        string[] memory str = new string[](proposals.length); // Créez un tableau de chaînes de la bonne taille
        for (uint i = 0; i < proposals.length; i++) {
            str[i] = string(abi.encodePacked(" ", uintToString(i), " : ", proposals[i].description));
        }
        return str;
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp > 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value > 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        
        return string(buffer);
    }
}