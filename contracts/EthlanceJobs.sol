pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./token/IERC20.sol";
import "./token/IERC721.sol";
import "./math/SafeMath.sol";


/// @title EthlanceJob
/// @dev A contract for issuing jobs on Ethereum paying in ETH, ERC20, or ERC721 tokens
/// @author Mark Beylin <mark.beylin@consensys.net>, Gonçalo Sá <goncalo.sa@consensys.net>, Kevin Owocki <kevin.owocki@consensys.net>, Ricardo Guilherme Schmidt (@3esmit), Matt Garnett <matt.garnett@consensys.net>, Craig Williams <craig.williams@consensys.net>
contract EthlanceJobs {

  using SafeMath for uint256;

  /*
   * Structs
   */

  struct Job {
    address payable[] issuers; // An array of individuals who have complete control over the job, and can edit any of its parameters
    address[] approvers; // An array of individuals who are allowed to accept the fulfillments for a particular job
    address token; // The address of the token associated with the job (should be disregarded if the tokenVersion is 0)
    uint tokenVersion; // The version of the token being used for the job (0 for ETH, 20 for ERC20, 721 for ERC721)
    uint balance; // The number of tokens which the job is able to pay out or refund
    bool hasPaidOut; // A boolean storing whether or not the job has paid out at least once, meaning refunds are no longer allowed
    Fulfillment[] fulfillments; // An array of Fulfillments which store the various submissions which have been made to the job
    Contribution[] contributions; // An array of Contributions which store the contributions which have been made to the job
    address[] hiredCandidates;
  }

  struct Fulfillment {
    address payable[] fulfillers; // An array of addresses who should receive payouts for a given submission
    address submitter; // The address of the individual who submitted the fulfillment, who is able to update the submission as needed
    uint amount;
  }

  struct Contribution {
    address payable contributor; // The address of the individual who contributed
    uint amount; // The amount of tokens the user contributed
    bool refunded; // A boolean storing whether or not the contribution has been refunded yet
  }

  /*
   * Storage
   */

  uint public numJobs; // An integer storing the total number of jobs in the contract
  mapping(uint => Job) public jobs; // A mapping of jobIDs to jobs
  mapping (uint => mapping (uint => bool)) public tokenBalances; // A mapping of jobIds to tokenIds to booleans, storing whether a given job has a given ERC721 token in its balance
  mapping (uint => address[]) public candidates; // A mapping of jobIds to candidates that have applied for the job

  address public owner; // The address of the individual who's allowed to set the metaTxRelayer address
  address public metaTxRelayer; // The address of the meta transaction relayer whose _sender is automatically trusted for all contract calls

  bool public callStarted; // Ensures mutex for the entire contract

  /*
   * Modifiers
   */

  modifier callNotStarted(){
    require(!callStarted);
    callStarted = true;
    _;
    callStarted = false;
  }

  modifier validateJobArrayIndex(
                                 uint _index)
  {
    require(_index < numJobs);
    _;
  }

  modifier validateContributionArrayIndex(
                                          uint _jobId,
                                          uint _index)
  {
    require(_index < jobs[_jobId].contributions.length);
    _;
  }

  modifier validateFulfillmentArrayIndex(
                                         uint _jobId,
                                         uint _index)
  {
    require(_index < jobs[_jobId].fulfillments.length);
    _;
  }

  modifier validateIssuerArrayIndex(
                                    uint _jobId,
                                    uint _index)
  {
    require(_index < jobs[_jobId].issuers.length);
    _;
  }

  modifier validateApproverArrayIndex(
                                      uint _jobId,
                                      uint _index)
  {
    require(_index < jobs[_jobId].approvers.length);
    _;
  }

  modifier onlyIssuer(
                      address _sender,
                      uint _jobId,
                      uint _issuerId)
  {
    require(_sender == jobs[_jobId].issuers[_issuerId]);
    _;
  }

  modifier onlySubmitter(
                         address _sender,
                         uint _jobId,
                         uint _fulfillmentId)
  {
    require(_sender ==
            jobs[_jobId].fulfillments[_fulfillmentId].submitter);
    _;
  }

  modifier onlyContributor(
                           address _sender,
                           uint _jobId,
                           uint _contributionId)
  {
    require(_sender ==
            jobs[_jobId].contributions[_contributionId].contributor);
    _;
  }

  modifier isApprover(
                      address _sender,
                      uint _jobId,
                      uint _approverId)
  {
    require(_sender == jobs[_jobId].approvers[_approverId]);
    _;
  }

  modifier hasNotPaid(
                      uint _jobId)
  {
    require(!jobs[_jobId].hasPaidOut);
    _;
  }

  modifier hasNotRefunded(
                          uint _jobId,
                          uint _contributionId)
  {
    require(!jobs[_jobId].contributions[_contributionId].refunded);
    _;
  }

  modifier senderIsValid(
                         address _sender)
  {
    require(msg.sender == _sender || msg.sender == metaTxRelayer);
    _;
  }

  /*
   * Public functions
   */

  constructor() public {
    // The owner of the contract is automatically designated to be the deployer of the contract
    owner = msg.sender;
  }

  /// @dev setMetaTxRelayer(): Sets the address of the meta transaction relayer
  /// @param _relayer the address of the relayer
  function setMetaTxRelayer(address _relayer)
    external
  {
    require(msg.sender == owner); // Checks that only the owner can call
    require(metaTxRelayer == address(0)); // Ensures the meta tx relayer can only be set once
    metaTxRelayer = _relayer;
  }

  function contains(address[] memory arr, address x) private returns(bool)
  {
    bool found=false;
    uint i = 0;
    while(i < arr.length && !found){
      found=arr[i]==x;
      i++;
    }
  }

  function selectCandidate(uint jobId, address candidate)
    public
  {
    // Validate that candidate is inside candidates that applied for this job
    require(contains(candidates[jobId], candidate), "The candidate you are trying to select didn't apply for this job");

    // Add the candidate as selected for the job
    jobs[jobId].hiredCandidates.push(candidate);

    emit CandidateSelected(jobId, candidate);
  }

  function applyAsCandidate(uint jobId, address candidate) public {
    // Check it didn't already apply
    require(!contains(candidates[jobId], candidate), "The candidate already applied for this job");

    // Add it as a candidate
    candidates[jobId].push(candidate);

    emit CandidateApplied(jobId, candidate);
  }

  /// @dev issueJob(): creates a new job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _issuers the array of addresses who will be the issuers of the job
  /// @param _approvers the array of addresses who will be the approvers of the job
  /// @param _data the IPFS hash representing the JSON object storing the details of the job (see docs for schema details)
  /// @param _token the address of the token which will be used for the job
  /// @param _tokenVersion the version of the token being used for the job (0 for ETH, 20 for ERC20, 721 for ERC721)
  function issueJob(
                    address payable _sender,
                    address payable[] memory _issuers,
                    address[] memory _approvers,
                    string memory _data,
                    address _token,
                    uint _tokenVersion)
    public
    senderIsValid(_sender)
    returns (uint)
  {
    require(_tokenVersion == 0 || _tokenVersion == 20 || _tokenVersion == 721); // Ensures a job can only be issued with a valid token version
    require(_issuers.length > 0 || _approvers.length > 0); // Ensures there's at least 1 issuer or approver, so funds don't get stuck

    uint jobId = numJobs; // The next job's index will always equal the number of existing jobs

    Job storage newJob = jobs[jobId];
    newJob.issuers = _issuers;
    newJob.approvers = _approvers;
    newJob.tokenVersion = _tokenVersion;

    if (_tokenVersion != 0){
      newJob.token = _token;
    }

    numJobs = numJobs.add(1); // Increments the number of jobs, since a new one has just been added

    emit JobIssued(jobId,
                   _sender,
                   _issuers,
                   _approvers,
                   _data, // Instead of storing the string on-chain, it is emitted within the event for easy off-chain consumption
                   _token,
                   _tokenVersion);

    return (jobId);
  }

  /// @param _depositAmount the amount of tokens being deposited to the job, which will create a new contribution to the job


  function issueAndContribute(
                              address payable _sender,
                              address payable[] memory _issuers,
                              address[] memory _approvers,
                              string memory _data,
                              address _token,
                              uint _tokenVersion,
                              uint _depositAmount)
    public
    payable
    returns(uint)
  {
    uint jobId = issueJob(_sender, _issuers, _approvers, _data, _token, _tokenVersion);

    contribute(_sender, jobId, _depositAmount);

    return (jobId);
  }


  /// @dev contribute(): Allows users to contribute tokens to a given job.
  ///                    Contributing merits no privelages to administer the
  ///                    funds in the job or accept submissions. Contributions
  ///                    has elapsed, and the job has not yet paid out any funds.
  ///                    All funds deposited in a job are at the mercy of a
  ///                    job's issuers and approvers, so please be careful!
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _amount the amount of tokens being contributed
  function contribute(
                      address payable _sender,
                      uint _jobId,
                      uint _amount)
    public
    payable
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    callNotStarted
  {
    require(_amount > 0); // Contributions of 0 tokens or token ID 0 should fail

    jobs[_jobId].contributions.push(
                                    Contribution(_sender, _amount, false)); // Adds the contribution to the job

    if (jobs[_jobId].tokenVersion == 0){

      jobs[_jobId].balance = jobs[_jobId].balance.add(_amount); // Increments the balance of the job

      require(msg.value == _amount);
    } else if (jobs[_jobId].tokenVersion == 20){

      jobs[_jobId].balance = jobs[_jobId].balance.add(_amount); // Increments the balance of the job

      require(msg.value == 0); // Ensures users don't accidentally send ETH alongside a token contribution, locking up funds
      require(IERC20(jobs[_jobId].token).transferFrom(_sender,
                                                      address(this),
                                                      _amount));
    } else if (jobs[_jobId].tokenVersion == 721){
      tokenBalances[_jobId][_amount] = true; // Adds the 721 token to the balance of the job


      require(msg.value == 0); // Ensures users don't accidentally send ETH alongside a token contribution, locking up funds
      IERC721(jobs[_jobId].token).transferFrom(_sender,
                                               address(this),
                                               _amount);
    } else {
      revert();
    }

    emit ContributionAdded(_jobId,
                           jobs[_jobId].contributions.length - 1, // The new contributionId
                           _sender,
                           _amount);
  }

  /// @dev refundContribution(): Allows users to refund the contributions they've
  ///                            made to a particular job, but only if the job
  ///                            has not yet paid out
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _contributionId the index of the contribution being refunded
  function refundContribution(
                              address _sender,
                              uint _jobId,
                              uint _contributionId)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateContributionArrayIndex(_jobId, _contributionId)
    onlyContributor(_sender, _jobId, _contributionId)
    hasNotPaid(_jobId)
    hasNotRefunded(_jobId, _contributionId)
    callNotStarted
  {

    Contribution storage contribution = jobs[_jobId].contributions[_contributionId];

    contribution.refunded = true;

    transferTokens(_jobId, contribution.contributor, contribution.amount); // Performs the disbursal of tokens to the contributor

    emit ContributionRefunded(_jobId, _contributionId);
  }

  /// @dev refundMyContributions(): Allows users to refund their contributions in bulk
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _contributionIds the array of indexes of the contributions being refunded
  function refundMyContributions(
                                 address _sender,
                                 uint _jobId,
                                 uint[] memory _contributionIds)
    public
    senderIsValid(_sender)
  {
    for (uint i = 0; i < _contributionIds.length; i++){
      refundContribution(_sender, _jobId, _contributionIds[i]);
    }
  }

  /// @dev refundContributions(): Allows users to refund their contributions in bulk
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is making the call
  /// @param _contributionIds the array of indexes of the contributions being refunded
  function refundContributions(
                               address _sender,
                               uint _jobId,
                               uint _issuerId,
                               uint[] memory _contributionIds)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    onlyIssuer(_sender, _jobId, _issuerId)
    callNotStarted
  {
    for (uint i = 0; i < _contributionIds.length; i++){
      require(_contributionIds[i] < jobs[_jobId].contributions.length);

      Contribution storage contribution = jobs[_jobId].contributions[_contributionIds[i]];

      require(!contribution.refunded);

      contribution.refunded = true;

      transferTokens(_jobId, contribution.contributor, contribution.amount); // Performs the disbursal of tokens to the contributor
    }

    emit ContributionsRefunded(_jobId, _sender, _contributionIds);
  }

  /// @dev drainJob(): Allows an issuer to drain the funds from the job
  /// @notice when using this function, if an issuer doesn't drain the entire balance, some users may be able to refund their contributions, while others may not (which is unfair to them). Please use it wisely, only when necessary
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is making the call
  /// @param _amounts an array of amounts of tokens to be sent. The length of the array should be 1 if the job is in ETH or ERC20 tokens. If it's an ERC721 job, the array should be the list of tokenIDs.
  function drainJob(
                    address payable _sender,
                    uint _jobId,
                    uint _issuerId,
                    uint[] memory _amounts)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    onlyIssuer(_sender, _jobId, _issuerId)
    callNotStarted
  {
    if (jobs[_jobId].tokenVersion == 0 || jobs[_jobId].tokenVersion == 20){
      require(_amounts.length == 1); // ensures there's only 1 amount of tokens to be returned
      require(_amounts[0] <= jobs[_jobId].balance); // ensures an issuer doesn't try to drain the job of more tokens than their balance permits
      transferTokens(_jobId, _sender, _amounts[0]); // Performs the draining of tokens to the issuer
    } else {
      for (uint i = 0; i < _amounts.length; i++){
        require(tokenBalances[_jobId][_amounts[i]]);// ensures an issuer doesn't try to drain the job of a token it doesn't have in its balance
        transferTokens(_jobId, _sender, _amounts[i]);
      }
    }

    emit JobDrained(_jobId, _sender, _amounts);
  }

  /// @dev performAction(): Allows users to perform any generalized action
  ///                       associated with a particular job, such as applying for it
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _data the IPFS hash corresponding to a JSON object which contains the details of the action being performed (see docs for schema details)
  function performAction(
                         address _sender,
                         uint _jobId,
                         string memory _data)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
  {
    emit ActionPerformed(_jobId, _sender, _data); // The _data string is emitted in an event for easy off-chain consumption
  }

  /// @dev fulfillJob(): Allows users to fulfill the job to get paid out
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _fulfillers the array of addresses which will receive payouts for the submission
  /// @param _data the IPFS hash corresponding to a JSON object which contains the details of the submission (see docs for schema details)
  function fulfillJob(
                      address _sender,
                      uint _jobId,
                      address payable[] memory  _fulfillers,
                      string memory _data,
                      uint _amount)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
  {
    require(contains(jobs[_jobId].hiredCandidates, _sender), "Can't fulfill the job. The sender was't selecte for the job");

    require(_fulfillers.length > 0); // Submissions with no fulfillers would mean no one gets paid out

    jobs[_jobId].fulfillments.push(Fulfillment(_fulfillers, _sender, _amount));

    emit JobFulfilled(_jobId,
                      (jobs[_jobId].fulfillments.length - 1),
                      _fulfillers,
                      _data, // The _data string is emitted in an event for easy off-chain consumption
                      _sender,
                      _amount);
  }

  /// @dev updateFulfillment(): Allows the submitter of a fulfillment to update their submission
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _fulfillmentId the index of the fulfillment
  /// @param _fulfillers the new array of addresses which will receive payouts for the submission
  /// @param _data the new IPFS hash corresponding to a JSON object which contains the details of the submission (see docs for schema details)
  function updateFulfillment(
                             address _sender,
                             uint _jobId,
                             uint _fulfillmentId,
                             address payable[] memory _fulfillers,
                             string memory _data)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateFulfillmentArrayIndex(_jobId, _fulfillmentId)
    onlySubmitter(_sender, _jobId, _fulfillmentId) // Only the original submitter of a fulfillment may update their submission
  {
    // TODO: require the sender to be the selected candidate for the _jobId
    jobs[_jobId].fulfillments[_fulfillmentId].fulfillers = _fulfillers;
    emit FulfillmentUpdated(_jobId,
                            _fulfillmentId,
                            _fulfillers,
                            _data); // The _data string is emitted in an event for easy off-chain consumption
  }

  /// @dev acceptFulfillment(): Allows any of the approvers to accept a given submission
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _fulfillmentId the index of the fulfillment to be accepted
  /// @param _approverId the index of the approver which is making the call
  /// @param _tokenAmounts the array of token amounts which will be paid to the
  ///                      fulfillers, whose length should equal the length of the
  ///                      _fulfillers array of the submission. If the job pays
  ///                      in ERC721 tokens, then these should be the token IDs
  ///                      being sent to each of the individual fulfillers
  function acceptFulfillment(
                             address _sender,
                             uint _jobId,
                             uint _fulfillmentId,
                             uint _approverId,
                             uint[] memory _tokenAmounts)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateFulfillmentArrayIndex(_jobId, _fulfillmentId)
    isApprover(_sender, _jobId, _approverId)
    callNotStarted
  {
    // now that the job has paid out at least once, refunds are no longer possible
    jobs[_jobId].hasPaidOut = true;

    Fulfillment storage fulfillment = jobs[_jobId].fulfillments[_fulfillmentId];

    require(_tokenAmounts.length == fulfillment.fulfillers.length); // Each fulfiller should get paid some amount of tokens (this can be 0)

    for (uint256 i = 0; i < fulfillment.fulfillers.length; i++){
      if (_tokenAmounts[i] > 0){
        // for each fulfiller associated with the submission
        transferTokens(_jobId, fulfillment.fulfillers[i], _tokenAmounts[i]);
      }
    }
    emit FulfillmentAccepted(_jobId,
                             _fulfillmentId,
                             _sender,
                             _tokenAmounts);
  }

  /// @dev fulfillAndAccept(): Allows any of the approvers to fulfill and accept a submission simultaneously
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _fulfillers the array of addresses which will receive payouts for the submission
  /// @param _data the IPFS hash corresponding to a JSON object which contains the details of the submission (see docs for schema details)
  /// @param _approverId the index of the approver which is making the call
  /// @param _tokenAmounts the array of token amounts which will be paid to the
  ///                      fulfillers, whose length should equal the length of the
  ///                      _fulfillers array of the submission. If the job pays
  ///                      in ERC721 tokens, then these should be the token IDs
  ///                      being sent to each of the individual fulfillers
  function fulfillAndAccept(
                            address _sender,
                            uint _jobId,
                            address payable[] memory _fulfillers,
                            string memory _data,
                            uint _approverId,
                            uint[] memory _tokenAmounts,
                            uint _amount)
    public
    senderIsValid(_sender)
  {
    // first fulfills the job on behalf of the fulfillers
    fulfillJob(_sender, _jobId, _fulfillers, _data, _amount);

    // then accepts the fulfillment
    acceptFulfillment(_sender,
                      _jobId,
                      jobs[_jobId].fulfillments.length - 1,
                      _approverId,
                      _tokenAmounts);
  }



  /// @dev changeJob(): Allows any of the issuers to change the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _issuers the new array of addresses who will be the issuers of the job
  /// @param _approvers the new array of addresses who will be the approvers of the job
  /// @param _data the new IPFS hash representing the JSON object storing the details of the job (see docs for schema details)
  function changeJob(
                     address _sender,
                     uint _jobId,
                     uint _issuerId,
                     address payable[] memory _issuers,
                     address payable[] memory _approvers,
                     string memory _data
                     )
    public
    senderIsValid(_sender)
  {
    require(_jobId < numJobs); // makes the validateJobArrayIndex modifier in-line to avoid stack too deep errors
    require(_issuerId < jobs[_jobId].issuers.length); // makes the validateIssuerArrayIndex modifier in-line to avoid stack too deep errors
    require(_sender == jobs[_jobId].issuers[_issuerId]); // makes the onlyIssuer modifier in-line to avoid stack too deep errors

    require(_issuers.length > 0 || _approvers.length > 0); // Ensures there's at least 1 issuer or approver, so funds don't get stuck

    jobs[_jobId].issuers = _issuers;
    jobs[_jobId].approvers = _approvers;
    emit JobChanged(_jobId,
                    _sender,
                    _issuers,
                    _approvers,
                    _data);
  }

  /// @dev changeIssuer(): Allows any of the issuers to change a particular issuer of the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _issuerIdToChange the index of the issuer who is being changed
  /// @param _newIssuer the address of the new issuer
  function changeIssuer(
                        address _sender,
                        uint _jobId,
                        uint _issuerId,
                        uint _issuerIdToChange,
                        address payable _newIssuer)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateIssuerArrayIndex(_jobId, _issuerIdToChange)
    onlyIssuer(_sender, _jobId, _issuerId)
  {
    require(_issuerId < jobs[_jobId].issuers.length || _issuerId == 0);

    jobs[_jobId].issuers[_issuerIdToChange] = _newIssuer;

    emit JobIssuersUpdated(_jobId, _sender, jobs[_jobId].issuers);
  }

  /// @dev changeApprover(): Allows any of the issuers to change a particular approver of the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _approverId the index of the approver who is being changed
  /// @param _approver the address of the new approver
  function changeApprover(
                          address _sender,
                          uint _jobId,
                          uint _issuerId,
                          uint _approverId,
                          address payable _approver)
    external
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    onlyIssuer(_sender, _jobId, _issuerId)
    validateApproverArrayIndex(_jobId, _approverId)
  {
    jobs[_jobId].approvers[_approverId] = _approver;

    emit JobApproversUpdated(_jobId, _sender, jobs[_jobId].approvers);
  }

  /// @dev changeData(): Allows any of the issuers to change the data the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _data the new IPFS hash representing the JSON object storing the details of the job (see docs for schema details)
  function changeData(
                      address _sender,
                      uint _jobId,
                      uint _issuerId,
                      string memory _data)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateIssuerArrayIndex(_jobId, _issuerId)
    onlyIssuer(_sender, _jobId, _issuerId)
  {
    emit JobDataChanged(_jobId, _sender, _data); // The new _data is emitted within an event rather than being stored on-chain for minimized gas costs
  }


  /// @dev addIssuers(): Allows any of the issuers to add more issuers to the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _issuers the array of addresses to add to the list of valid issuers
  function addIssuers(
                      address _sender,
                      uint _jobId,
                      uint _issuerId,
                      address payable[] memory _issuers)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateIssuerArrayIndex(_jobId, _issuerId)
    onlyIssuer(_sender, _jobId, _issuerId)
  {
    for (uint i = 0; i < _issuers.length; i++){
      jobs[_jobId].issuers.push(_issuers[i]);
    }

    emit JobIssuersUpdated(_jobId, _sender, jobs[_jobId].issuers);
  }

  /// @dev replaceIssuers(): Allows any of the issuers to replace the issuers of the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _issuers the array of addresses to replace the list of valid issuers
  function replaceIssuers(
                          address _sender,
                          uint _jobId,
                          uint _issuerId,
                          address payable[] memory _issuers)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateIssuerArrayIndex(_jobId, _issuerId)
    onlyIssuer(_sender, _jobId, _issuerId)
  {
    require(_issuers.length > 0 || jobs[_jobId].approvers.length > 0); // Ensures there's at least 1 issuer or approver, so funds don't get stuck

    jobs[_jobId].issuers = _issuers;

    emit JobIssuersUpdated(_jobId, _sender, jobs[_jobId].issuers);
  }

  /// @dev addApprovers(): Allows any of the issuers to add more approvers to the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _approvers the array of addresses to add to the list of valid approvers
  function addApprovers(
                        address _sender,
                        uint _jobId,
                        uint _issuerId,
                        address[] memory _approvers)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateIssuerArrayIndex(_jobId, _issuerId)
    onlyIssuer(_sender, _jobId, _issuerId)
  {
    for (uint i = 0; i < _approvers.length; i++){
      jobs[_jobId].approvers.push(_approvers[i]);
    }

    emit JobApproversUpdated(_jobId, _sender, jobs[_jobId].approvers);
  }

  /// @dev replaceApprovers(): Allows any of the issuers to replace the approvers of the job
  /// @param _sender the sender of the transaction issuing the job (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _jobId the index of the job
  /// @param _issuerId the index of the issuer who is calling the function
  /// @param _approvers the array of addresses to replace the list of valid approvers
  function replaceApprovers(
                            address _sender,
                            uint _jobId,
                            uint _issuerId,
                            address[] memory _approvers)
    public
    senderIsValid(_sender)
    validateJobArrayIndex(_jobId)
    validateIssuerArrayIndex(_jobId, _issuerId)
    onlyIssuer(_sender, _jobId, _issuerId)
  {
    require(jobs[_jobId].issuers.length > 0 || _approvers.length > 0); // Ensures there's at least 1 issuer or approver, so funds don't get stuck
    jobs[_jobId].approvers = _approvers;

    emit JobApproversUpdated(_jobId, _sender, jobs[_jobId].approvers);
  }

  /// @dev getJob(): Returns the details of the job
  /// @param _jobId the index of the job
  /// @return Returns a tuple for the job
  function getJob(uint _jobId)
    external
    view
    returns (Job memory)
  {
    return jobs[_jobId];
  }


  function transferTokens(uint _jobId, address payable _to, uint _amount)
    internal
  {
    if (jobs[_jobId].tokenVersion == 0){
      require(_amount > 0); // Sending 0 tokens should throw
      require(jobs[_jobId].balance >= _amount);

      jobs[_jobId].balance = jobs[_jobId].balance.sub(_amount);

      _to.transfer(_amount);
    } else if (jobs[_jobId].tokenVersion == 20){
      require(_amount > 0); // Sending 0 tokens should throw
      require(jobs[_jobId].balance >= _amount);

      jobs[_jobId].balance = jobs[_jobId].balance.sub(_amount);

      require(IERC20(jobs[_jobId].token).transfer(_to, _amount));
    } else if (jobs[_jobId].tokenVersion == 721){
      require(tokenBalances[_jobId][_amount]);

      tokenBalances[_jobId][_amount] = false; // Removes the 721 token from the balance of the job

      IERC721(jobs[_jobId].token).transferFrom(address(this),
                                               _to,
                                               _amount);
    } else {
      revert();
    }
  }

  /*
   * Events
   */

  event JobIssued(uint _jobId, address payable _creator, address payable[] _issuers, address[] _approvers, string _data, address _token, uint _tokenVersion);
  event ContributionAdded(uint _jobId, uint _contributionId, address payable _contributor, uint _amount);
  event ContributionRefunded(uint _jobId, uint _contributionId);
  event ContributionsRefunded(uint _jobId, address _issuer, uint[] _contributionIds);
  event JobDrained(uint _jobId, address _issuer, uint[] _amounts);
  event ActionPerformed(uint _jobId, address _fulfiller, string _data);
  event JobFulfilled(uint _jobId, uint _fulfillmentId, address payable[] _fulfillers, string _data, address _submitter, uint _amount);
  event FulfillmentUpdated(uint _jobId, uint _fulfillmentId, address payable[] _fulfillers, string _data);
  event FulfillmentAccepted(uint _jobId, uint  _fulfillmentId, address _approver, uint[] _tokenAmounts);
  event JobChanged(uint _jobId, address _changer, address payable[] _issuers, address payable[] _approvers, string _data);
  event JobIssuersUpdated(uint _jobId, address _changer, address payable[] _issuers);
  event JobApproversUpdated(uint _jobId, address _changer, address[] _approvers);
  event JobDataChanged(uint _jobId, address _changer, string _data);

  event CandidateSelected(uint jobId, address candidate);
  event CandidateApplied(uint jobId, address candidate);
}
